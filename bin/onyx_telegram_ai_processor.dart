import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

const Duration _defaultPollInterval = Duration(seconds: 2);

Future<void> main() async {
  final supabaseUrl = Platform.environment['ONYX_SUPABASE_URL'] ?? '';
  final serviceKey = Platform.environment['ONYX_SUPABASE_SERVICE_KEY'] ?? '';
  final botToken = Platform.environment['ONYX_TELEGRAM_BOT_TOKEN'] ?? '';
  final pollIntervalSeconds =
      int.tryParse(
        Platform.environment['ONYX_TELEGRAM_AI_PROCESSOR_POLL_SECONDS'] ?? '',
      ) ??
      _defaultPollInterval.inSeconds;

  if (supabaseUrl.trim().isEmpty ||
      serviceKey.trim().isEmpty ||
      botToken.trim().isEmpty) {
    stderr.writeln(
      '[ONYX] ERROR: ONYX_SUPABASE_URL, ONYX_SUPABASE_SERVICE_KEY, and '
      'ONYX_TELEGRAM_BOT_TOKEN are required.',
    );
    exit(1);
  }

  final apiBaseRaw = (Platform.environment['ONYX_TELEGRAM_API_BASE'] ?? '')
      .trim();
  final apiBaseUri = apiBaseRaw.isEmpty ? null : Uri.tryParse(apiBaseRaw);
  final httpClient = http.Client();
  final supabase = SupabaseClient(supabaseUrl, serviceKey);
  final aiConfig = OpenAiRuntimeConfig.resolve(
    primaryApiKey:
        Platform.environment['ONYX_TELEGRAM_AI_OPENAI_API_KEY'] ?? '',
    primaryModel:
        Platform.environment['ONYX_TELEGRAM_AI_OPENAI_MODEL'] ?? 'gpt-4.1-mini',
    primaryEndpoint:
        Platform.environment['ONYX_TELEGRAM_AI_OPENAI_ENDPOINT'] ?? '',
    genericApiKey: Platform.environment['OPENAI_API_KEY'] ?? '',
    genericModel: Platform.environment['OPENAI_MODEL'] ?? 'gpt-4.1-mini',
    genericBaseUrl: Platform.environment['OPENAI_BASE_URL'] ?? '',
  );

  final aiAssistant = aiConfig.isConfigured
      ? OpenAiTelegramAiAssistantService(
          client: httpClient,
          apiKey: aiConfig.apiKey,
          model: aiConfig.model,
          endpoint: aiConfig.endpoint,
        )
      : const UnconfiguredTelegramAiAssistantService();

  final processor = _OnyxTelegramAiProcessor(
    supabase: supabase,
    telegramBridge: HttpTelegramBridgeService(
      client: httpClient,
      botToken: botToken,
      apiBaseUri: apiBaseUri,
    ),
    aiAssistant: aiAssistant,
    router: const OnyxTelegramCommandRouter(),
    pollInterval: Duration(seconds: math.max(1, pollIntervalSeconds)),
  );

  stdout.writeln(
    '[ONYX] Telegram AI processor started '
    '(poll ${processor.pollInterval.inSeconds}s, '
    'ai=${aiAssistant.isConfigured ? 'configured' : 'fallback-only'})',
  );
  await processor.run();
}

class _OnyxTelegramAiProcessor {
  final SupabaseClient supabase;
  final TelegramBridgeService telegramBridge;
  final TelegramAiAssistantService aiAssistant;
  final OnyxTelegramCommandRouter router;
  final Duration pollInterval;

  const _OnyxTelegramAiProcessor({
    required this.supabase,
    required this.telegramBridge,
    required this.aiAssistant,
    required this.router,
    required this.pollInterval,
  });

  Future<void> run() async {
    while (true) {
      var processedCount = 0;
      try {
        processedCount = await _pollOnce();
      } catch (error, stackTrace) {
        _logError(
          'Telegram AI processor poll failed.',
          error: error,
          stackTrace: stackTrace,
        );
        developer.log(
          'Telegram AI processor poll failed.',
          name: 'OnyxTelegramAiProcessor',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (processedCount <= 0) {
        await Future<void>.delayed(pollInterval);
      }
    }
  }

  Future<int> _pollOnce() async {
    final rows = await supabase
        .from('telegram_inbound_updates')
        .select('id,update_id,chat_id,update_json,received_at,processed')
        .eq('processed', false)
        .order('received_at', ascending: true)
        .limit(20);
    if (rows.isEmpty) {
      return 0;
    }

    _logInfo('Fetched ${rows.length} unprocessed inbound Telegram row(s).');
    var processedCount = 0;
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final rowId = (row['id'] ?? '').toString().trim();
      if (rowId.isEmpty) {
        continue;
      }
      final rowChatId = (row['chat_id'] ?? '').toString().trim();
      _logInfo(
        'Processing row $rowId from ${rowChatId.isEmpty ? 'unknown-chat' : rowChatId}',
      );
      try {
        final update = _parseInboundMessage(row);
        if (update == null) {
          _logInfo('Row $rowId has no usable Telegram message payload.');
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }
        if (update.fromIsBot || update.text.trim().isEmpty) {
          _logInfo(
            'Row $rowId ignored (from bot=${update.fromIsBot}, emptyText=${update.text.trim().isEmpty}).',
          );
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        if ((update.callbackQueryId ?? '').trim().isNotEmpty) {
          final answered = await telegramBridge.answerCallbackQuery(
            callbackQueryId: update.callbackQueryId!.trim(),
          );
          if (!answered) {
            _logError(
              'Failed to answer Telegram callback query for row $rowId.',
            );
          }
        }

        final target = await _resolveInboundClientTarget(
          chatId: update.chatId,
          messageThreadId: update.messageThreadId,
        );
        if (target == null) {
          final message =
              'Skipping inbound Telegram update ${update.updateId} — no active client endpoint binding.';
          _logInfo(message);
          developer.log(message, name: 'OnyxTelegramAiProcessor');
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        _logInfo('Sending row $rowId to AI/reply builder...');
        final reply = _isOnyxAlertCallbackData(update.text)
            ? await _handleOnyxAlertCallback(update: update, target: target)
            : await _buildReply(update: update, target: target);
        _logInfo('AI response for row $rowId: ${_preview(reply)}');
        if (reply.trim().isEmpty) {
          _logInfo('Row $rowId produced an empty reply.');
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        _logInfo('Sending Telegram reply for row $rowId...');
        final sendResult = await telegramBridge.sendMessages(
          messages: <TelegramBridgeMessage>[
            TelegramBridgeMessage(
              messageKey: 'telegram-ai-${update.updateId}',
              chatId: update.chatId,
              messageThreadId: update.messageThreadId,
              text: reply,
            ),
          ],
        );
        if (sendResult.sentCount <= 0) {
          final failure =
              sendResult
                  .failureReasonsByMessageKey['telegram-ai-${update.updateId}'] ??
              'unknown send failure';
          _logError('Telegram AI send failed for row $rowId: $failure');
          developer.log(
            'Telegram AI send failed for update ${update.updateId}: $failure',
            name: 'OnyxTelegramAiProcessor',
          );
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed after send failure.');
          processedCount++;
          continue;
        }

        await _markProcessed(rowId);
        _logInfo('Row $rowId marked processed.');
        processedCount++;
      } catch (error, stackTrace) {
        _logError(
          'ERROR processing row $rowId: $error',
          stackTrace: stackTrace,
        );
        developer.log(
          'Telegram AI row processing failed for $rowId.',
          name: 'OnyxTelegramAiProcessor',
          error: error,
          stackTrace: stackTrace,
        );
        try {
          await _markProcessed(rowId);
          _logInfo('Row $rowId marked processed after failure.');
          processedCount++;
        } catch (markError, markStackTrace) {
          _logError(
            'Failed to mark row $rowId processed after error: $markError',
            stackTrace: markStackTrace,
          );
        }
      }
    }

    return processedCount;
  }

  Future<void> _markProcessed(String rowId) {
    return supabase
        .from('telegram_inbound_updates')
        .update(<String, Object?>{'processed': true})
        .eq('id', rowId);
  }

  Future<_ProcessorTarget?> _resolveInboundClientTarget({
    required String chatId,
    required int? messageThreadId,
  }) async {
    final normalizedChatId = chatId.trim();
    if (normalizedChatId.isEmpty) {
      return null;
    }
    final rowsRaw = await supabase
        .from('client_messaging_endpoints')
        .select(
          'id, client_id, site_id, display_label, telegram_thread_id, endpoint_role',
        )
        .eq('provider', 'telegram')
        .eq('is_active', true)
        .eq('telegram_chat_id', normalizedChatId)
        .order('verified_at', ascending: false)
        .order('created_at', ascending: false);
    final rows = rowsRaw
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              !_isPartnerEndpointLabel((row['display_label'] ?? '').toString()),
        )
        .toList(growable: false);
    if (rows.isEmpty) {
      return null;
    }
    final pick = resolveUniqueTelegramEndpointRow(
      rows: rows,
      messageThreadId: messageThreadId,
    );
    if (pick == null) {
      return null;
    }
    final endpointId = (pick['id'] ?? '').toString().trim();
    final clientId = (pick['client_id'] ?? '').toString().trim();
    if (endpointId.isEmpty || clientId.isEmpty) {
      return null;
    }
    final rawSiteId = (pick['site_id'] ?? '').toString().trim();
    return _ProcessorTarget(
      endpointId: endpointId,
      clientId: clientId,
      siteId: rawSiteId.isEmpty ? 'default' : rawSiteId,
      displayLabel: (pick['display_label'] ?? '').toString().trim(),
      endpointRole: _normalizeEndpointRole(
        (pick['endpoint_role'] ?? '').toString(),
      ),
    );
  }

  Future<String> _buildReply({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
  }) async {
    final commandType = router.classify(update.text);
    return switch (commandType) {
      OnyxTelegramCommandType.liveStatus => _buildLiveStatusReply(
        siteId: target.siteId,
      ),
      OnyxTelegramCommandType.incident => _buildIncidentReply(
        siteId: target.siteId,
        prompt: update.text,
      ),
      OnyxTelegramCommandType.dispatch => _buildDispatchReply(
        siteId: target.siteId,
        prompt: update.text,
      ),
      OnyxTelegramCommandType.report => _buildReportReply(
        siteId: target.siteId,
      ),
      OnyxTelegramCommandType.guard => _buildGuardReply(siteId: target.siteId),
      OnyxTelegramCommandType.camera => _buildCameraReply(
        siteId: target.siteId,
      ),
      OnyxTelegramCommandType.intelligence => _buildIntelligenceReply(
        siteId: target.siteId,
      ),
      OnyxTelegramCommandType.actionRequest => _buildActionRequestReply(
        siteId: target.siteId,
        prompt: update.text,
      ),
      OnyxTelegramCommandType.visitorRegistration => _handleVisitorRegistration(
        siteId: target.siteId,
        prompt: update.text,
      ),
      OnyxTelegramCommandType.clientStatement => Future<String>.value(
        'Understood. I’ve noted that update and monitoring continues.',
      ),
      OnyxTelegramCommandType.frOnboarding => Future<String>.value(
        'To add someone to ONYX recognition:\n'
        '1. Send 3-5 clear face photos\n'
        '2. I’ll enroll them to the site gallery\n'
        '3. ONYX will then recognise them on site',
      ),
      _ => _buildAiFallbackReply(update: update, target: target),
    };
  }

  Future<String> _buildLiveStatusReply({required String siteId}) async {
    final siteLabel = _siteLabel(siteId);
    final snapshot = await _readLatestSnapshot(siteId);
    final incidents = await _readActiveIncidents(siteId);
    final activeOnDemandVisitors = await _readActiveOnDemandVisitors(siteId);
    if (snapshot == null) {
      return '$siteLabel — monitoring limited right now. No fresh site snapshot is available.';
    }

    final summary = _siteAwarenessSummaryFromRow(snapshot);
    final displayedCount = math.max(summary.humanCount, 0);
    final onDemandVisitorLine = _onDemandVisitorStatusLine(
      activeOnDemandVisitors,
    );
    final lines = <String>[
      '${summary.perimeterClear && incidents == 0 ? '🟢' : '🟠'} $siteLabel',
      'Perimeter: ${summary.perimeterClear ? 'Clear' : 'Alert active'}',
      displayedCount > 0
          ? 'Movement detected — $displayedCount ${displayedCount == 1 ? 'person' : 'people'} on site (identity unconfirmed)'
          : 'No movement detected on site',
      ?onDemandVisitorLine,
      'Active incidents: $incidents',
      'Last update: ${_relativeAgeLabel(summary.observedAtUtc)}',
    ];
    final knownFaults = summary.knownFaultChannels
        .where(_isValidChannelLabel)
        .toList(growable: false);
    if (knownFaults.isNotEmpty) {
      lines.addAll(
        knownFaults.map((channel) => 'Channel $channel: Offline (known fault)'),
      );
    }
    return lines.join('\n');
  }

  Future<String> _buildIncidentReply({
    required String siteId,
    required String prompt,
  }) async {
    final siteLabel = _siteLabel(siteId);
    final incidentRows = await supabase
        .from('incidents')
        .select(
          'id,event_uid,status,incident_type,created_at,occurred_at,signal_received_at',
        )
        .eq('site_id', siteId)
        .order('created_at', ascending: false)
        .limit(20);
    final todayStart = DateTime.now().toLocal();
    final startLocal = DateTime(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    );
    final startUtc = startLocal.toUtc();
    final filtered = incidentRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) {
          final when = _asDateTimeUtc(
            row['signal_received_at'] ??
                row['occurred_at'] ??
                row['created_at'],
          );
          return when != null && !when.isBefore(startUtc);
        })
        .toList(growable: false);
    if (filtered.isEmpty) {
      return 'No incidents recorded today at $siteLabel.';
    }
    final lines = <String>['Incidents today at $siteLabel:'];
    for (final row in filtered.take(5)) {
      final reference = (row['event_uid'] ?? row['id'] ?? 'incident')
          .toString()
          .trim();
      final status = (row['status'] ?? 'open').toString().trim();
      final incidentType = (row['incident_type'] ?? 'incident')
          .toString()
          .trim();
      final when = _asDateTimeUtc(
        row['signal_received_at'] ?? row['occurred_at'] ?? row['created_at'],
      );
      lines.add(
        '- $reference — ${_humanizeLabel(incidentType)} • ${_humanizeLabel(status)} • ${_clockLabel(when)}',
      );
    }
    return lines.join('\n');
  }

  Future<String> _buildReportReply({required String siteId}) async {
    final siteLabel = _siteLabel(siteId);
    final status = await _buildLiveStatusReply(siteId: siteId);
    final incidents = await _readActiveIncidents(siteId);
    final guardAssignments = await supabase
        .from('guard_assignments')
        .select('guard_name,shift_start,shift_end')
        .eq('site_id', siteId)
        .eq('is_active', true)
        .limit(5);
    final lines = <String>[
      'Report — $siteLabel',
      status,
      'Today’s incidents: $incidents',
    ];
    if (guardAssignments.isEmpty) {
      lines.add('Guard coverage: none configured');
    } else {
      for (final row in guardAssignments.take(2)) {
        final assignment = Map<String, dynamic>.from(row as Map);
        lines.add(
          'Guard: ${(assignment['guard_name'] ?? 'Guard').toString().trim()} '
          '(${(assignment['shift_start'] ?? '').toString().trim()} - ${(assignment['shift_end'] ?? '').toString().trim()})',
        );
      }
    }
    return lines.join('\n');
  }

  Future<String> _buildDispatchReply({
    required String siteId,
    required String prompt,
  }) async {
    final siteLabel = _siteLabel(siteId);
    final incidentRows = await supabase
        .from('incidents')
        .select(
          'id,event_uid,status,incident_type,created_at,occurred_at,signal_received_at,dispatch_time,arrival_time',
        )
        .eq('site_id', siteId)
        .order('created_at', ascending: false)
        .limit(20);
    final dispatchedRows = incidentRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where(
          (row) =>
              _asDateTimeUtc(row['dispatch_time']) != null ||
              _asDateTimeUtc(row['arrival_time']) != null ||
              _incidentIsActive((row['status'] ?? '').toString()),
        )
        .toList(growable: false);
    if (dispatchedRows.isEmpty) {
      return 'Dispatch summary: $siteLabel\n• No dispatch records are attached to this site yet.';
    }
    final lines = <String>['Dispatch summary: $siteLabel'];
    for (final row in dispatchedRows.take(4)) {
      final reference = (row['event_uid'] ?? row['id'] ?? 'incident')
          .toString()
          .trim();
      final status = _humanizeLabel((row['status'] ?? 'open').toString());
      final dispatchAt = _asDateTimeUtc(
        row['dispatch_time'] ?? row['signal_received_at'] ?? row['occurred_at'],
      );
      final arrivalAt = _asDateTimeUtc(row['arrival_time']);
      final parts = <String>[
        reference,
        'dispatched ${_clockLabel(dispatchAt)}',
        'status $status',
      ];
      if (arrivalAt != null) {
        parts.add('arrived ${_clockLabel(arrivalAt)}');
      }
      lines.add('• ${parts.join(' • ')}');
    }
    return lines.join('\n');
  }

  Future<String> _buildGuardReply({required String siteId}) async {
    final siteLabel = _siteLabel(siteId);
    final assignments = await supabase
        .from('guard_assignments')
        .select('guard_id,guard_name,shift_start,shift_end')
        .eq('site_id', siteId)
        .eq('is_active', true)
        .limit(10);
    if (assignments.isEmpty) {
      return 'No guard is assigned at $siteLabel.';
    }
    final latestScanRows = await supabase
        .from('patrol_scans')
        .select('guard_id,checkpoint_name,scanned_at')
        .eq('site_id', siteId)
        .order('scanned_at', ascending: false)
        .limit(20);
    final latestByGuard = <String, Map<String, dynamic>>{};
    for (final row in latestScanRows) {
      final map = Map<String, dynamic>.from(row as Map);
      final guardId = (map['guard_id'] ?? '').toString().trim();
      if (guardId.isEmpty) {
        continue;
      }
      latestByGuard.putIfAbsent(guardId, () => map);
    }
    final lines = <String>['Guard status — $siteLabel'];
    for (final row in assignments) {
      final assignment = Map<String, dynamic>.from(row as Map);
      final guardId = (assignment['guard_id'] ?? '').toString().trim();
      final guardName = (assignment['guard_name'] ?? 'Guard').toString().trim();
      final latest = latestByGuard[guardId];
      if (latest == null) {
        lines.add('- $guardName — on duty, no patrol scan recorded yet');
        continue;
      }
      lines.add(
        '- $guardName — last checkpoint ${(latest['checkpoint_name'] ?? 'unknown').toString().trim()} at ${_clockLabel(_asDateTimeUtc(latest['scanned_at']))}',
      );
    }
    return lines.join('\n');
  }

  Future<String> _buildCameraReply({required String siteId}) async {
    final siteLabel = _siteLabel(siteId);
    final snapshot = await _readLatestSnapshot(siteId);
    if (snapshot == null) {
      return 'Visual status: $siteLabel\n• No fresh camera snapshot is available right now.';
    }
    final summary = _siteAwarenessSummaryFromRow(snapshot);
    final knownFaults = summary.knownFaultChannels
        .where(_isValidChannelLabel)
        .toList(growable: false);
    return <String>[
      'Visual status: $siteLabel',
      '• Snapshot time: ${_clockLabel(summary.observedAtUtc)}',
      '• Perimeter: ${summary.perimeterClear ? 'Clear' : 'Alert active'}',
      '• Snapshot counts: ${summary.humanCount} people • ${summary.vehicleCount} vehicles • ${summary.animalCount} animals',
      '• Active alerts: ${summary.activeAlertCount}',
      '• Channel status: ${knownFaults.isEmpty ? 'All reported channels online' : knownFaults.map((channel) => 'CH$channel offline').join(', ')}',
    ].join('\n');
  }

  Future<String> _buildIntelligenceReply({required String siteId}) async {
    final siteLabel = _siteLabel(siteId);
    final snapshot = await _readLatestSnapshot(siteId);
    final incidents = await _readActiveIncidents(siteId);
    if (snapshot == null) {
      return 'Risk intelligence: $siteLabel\n• Not enough site telemetry is available yet.';
    }
    final summary = _siteAwarenessSummaryFromRow(snapshot);
    final unusualLine = summary.activeAlertCount > 0
        ? '${summary.activeAlertCount} active alert markers need review.'
        : summary.humanCount > 0
        ? 'Human movement is present, but no active alert markers are elevated.'
        : 'No unusual activity pattern is standing out right now.';
    return <String>[
      'Risk intelligence: $siteLabel',
      '• Current pattern: ${summary.humanCount} people • ${summary.vehicleCount} vehicles • ${summary.animalCount} animals',
      '• Perimeter: ${summary.perimeterClear ? 'holding clear' : 'requires review'}',
      '• Active incidents: $incidents',
      '• Unusual marker: $unusualLine',
    ].join('\n');
  }

  Future<String> _buildActionRequestReply({
    required String siteId,
    required String prompt,
  }) async {
    final siteLabel = _siteLabel(siteId);
    final normalized = prompt.toLowerCase();
    final actionLabel = normalized.contains('guard')
        ? 'call the assigned guard unit'
        : normalized.contains('escalate')
        ? 'escalate the site for response'
        : 'dispatch armed response';
    return 'Action request: $siteLabel\n'
        '• This will $actionLabel.\n'
        '• Confirm before ONYX takes any action.';
  }

  Future<String> _handleVisitorRegistration({
    required String siteId,
    required String prompt,
  }) async {
    if (_visitorLeaveNotificationRequested(prompt)) {
      final activeVisitors = await _readActiveOnDemandVisitors(siteId);
      if (activeVisitors.isEmpty) {
        return 'I don’t have any on-demand visitors marked on site right now. Send "2 visitors arrived" or "[name] is here" first.';
      }
      await _markOnDemandVisitorsForLeaveNotification(activeVisitors);
      return 'Will do. I\'ll alert you when movement stops or you can send \'visitors left\' to clear them.';
    }

    if (_visitorDepartureRequested(prompt)) {
      final today = _dateValue(DateTime.now().toLocal());
      await supabase
          .from('site_expected_visitors')
          .update(<String, Object?>{'is_active': false})
          .eq('site_id', siteId)
          .eq('visit_type', 'on_demand')
          .eq('visit_date', today)
          .eq('is_active', true);
      return 'Visitor access removed.\nNormal monitoring resumed.';
    }

    final nowLocal = DateTime.now().toLocal();
    final registration = _visitorRegistrationDetails(
      prompt: prompt,
      nowLocal: nowLocal,
    );
    final rows = List<Map<String, Object?>>.generate(
      registration.visitorCount,
      (index) {
        final visitorName =
            registration.visitorCount > 1 &&
                _isGenericAnonymousVisitorName(registration.visitorName)
            ? 'Visitor'
            : registration.visitorName;
        return <String, Object?>{
          'site_id': siteId,
          'visitor_name': visitorName,
          'visitor_role': registration.visitorRole,
          'visit_type': 'on_demand',
          'visit_days': const <String>[],
          'visit_start': _clockValue(nowLocal),
          'visit_end': _clockValue(registration.endLocal),
          'visit_date': _dateValue(nowLocal),
          'is_active': true,
          'notes': _onDemandVisitorNotes(
            sourceLabel: 'Hetzner AI processor registration',
            groupSize: registration.visitorCount,
          ),
        };
      },
    );
    await supabase.from('site_expected_visitors').insert(rows);
    if (registration.visitorCount > 1 &&
        registration.visitorRole == 'visitor' &&
        _isGenericAnonymousVisitorName(registration.visitorName)) {
      return 'Got it. ${registration.visitorCount} visitors noted on site.\n'
          'I\'ll suppress alerts for their movement.\n'
          'Let me know when they leave.';
    }
    return 'Got it. ${_visitorPossessiveLabel(registration.visitorName)} visit noted until ${_clockValue(registration.endLocal)}.\n'
        'I won’t alert for movement until then.';
  }

  Future<String> _handleOnyxAlertCallback({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
  }) async {
    final callback = _parseOnyxAlertCallback(update.text);
    if (callback == null) {
      return 'I couldn’t understand that alert action. Monitoring continues.';
    }
    final nowUtc = DateTime.now().toUtc();
    final cameraLabel = await _readAlertCameraLabel(
      siteId: target.siteId,
      channelId: callback.channelId,
    );
    return switch (callback.action) {
      _OnyxAlertCallbackAction.armedResponse => _handleArmedResponseCallback(
        target: target,
        callback: callback,
        cameraLabel: cameraLabel,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.soundWarning => _handleSoundWarningCallback(
        target: target,
        callback: callback,
        cameraLabel: cameraLabel,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.falseAlarm => _handleFalseAlarmCallback(
        target: target,
        callback: callback,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.keepWatching => Future<String>.value(
        '👁 Noted. I\'ll update you if situation changes.',
      ),
      _OnyxAlertCallbackAction.registerVehicle =>
        _handleRegisterVehicleCallback(
          target: target,
          callback: callback,
          nowUtc: nowUtc,
        ),
    };
  }

  Future<String> _handleArmedResponseCallback({
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required String cameraLabel,
    required DateTime nowUtc,
  }) async {
    final incidentId = _telegramInlineIncidentId(nowUtc);
    await _recordAlertActionEvent(
      siteId: target.siteId,
      channelId: callback.channelId,
      zoneName: cameraLabel,
      eventType: 'armed_response_requested',
      occurredAtUtc: nowUtc,
      rawPayload: <String, Object?>{
        'source': 'telegram_inline_button',
        'incident_id': incidentId,
        'camera_name': cameraLabel,
      },
    );
    return '📞 Armed response notified.\nIncident #$incidentId logged.';
  }

  Future<String> _handleSoundWarningCallback({
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required String cameraLabel,
    required DateTime nowUtc,
  }) async {
    await _recordAlertActionEvent(
      siteId: target.siteId,
      channelId: callback.channelId,
      zoneName: cameraLabel,
      eventType: 'voice_warning_requested',
      occurredAtUtc: nowUtc,
      rawPayload: <String, Object?>{
        'source': 'telegram_inline_button',
        'camera_name': cameraLabel,
      },
    );
    return '🔊 Voice warning requested on $cameraLabel.';
  }

  Future<String> _handleFalseAlarmCallback({
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    await supabase
        .from('site_awareness_snapshots')
        .update(<String, Object?>{'active_alerts': <Object?>[]})
        .eq('site_id', target.siteId);
    await _recordAlertActionEvent(
      siteId: target.siteId,
      channelId: callback.channelId,
      zoneName: null,
      eventType: 'false_alarm_cleared',
      occurredAtUtc: nowUtc,
      rawPayload: const <String, Object?>{'source': 'telegram_inline_button'},
    );
    return '✅ False alarm cleared. Monitoring continues.';
  }

  Future<String> _handleRegisterVehicleCallback({
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    final endLocal = _vehicleRegistrationEndTime(nowUtc.toLocal());
    await supabase.from('site_expected_visitors').insert(<String, Object?>{
      'site_id': target.siteId,
      'visitor_name': 'Expected Vehicle',
      'visitor_role': 'vehicle',
      'visit_type': 'on_demand',
      'visit_days': const <String>[],
      'visit_start': _clockValue(nowUtc.toLocal()),
      'visit_end': _clockValue(endLocal),
      'visit_date': _dateValue(nowUtc.toLocal()),
      'is_active': true,
      'notes': 'Telegram inline vehicle registration',
    });
    await _recordAlertActionEvent(
      siteId: target.siteId,
      channelId: callback.channelId,
      zoneName: null,
      eventType: 'vehicle_registered_expected',
      occurredAtUtc: nowUtc,
      rawPayload: const <String, Object?>{'source': 'telegram_inline_button'},
    );
    return '✅ Vehicle registered as expected visitor.';
  }

  Future<void> _recordAlertActionEvent({
    required String siteId,
    required String channelId,
    required String? zoneName,
    required String eventType,
    required DateTime occurredAtUtc,
    required Map<String, Object?> rawPayload,
  }) async {
    await supabase.from('site_alarm_events').insert(<String, Object?>{
      'site_id': siteId.trim(),
      'device_id': channelId.trim().isEmpty
          ? 'telegram-inline'
          : 'camera-ch${channelId.trim()}',
      'event_type': eventType,
      'zone_name': (zoneName ?? '').trim().isEmpty ? null : zoneName!.trim(),
      'occurred_at': occurredAtUtc.toUtc().toIso8601String(),
      'raw_payload': rawPayload,
    });
  }

  Future<String> _readAlertCameraLabel({
    required String siteId,
    required String channelId,
  }) async {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return 'site';
    }
    final rows = await supabase
        .from('site_awareness_snapshots')
        .select('active_alerts')
        .eq('site_id', siteId)
        .order('snapshot_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      return 'Channel $normalizedChannelId';
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    final activeAlerts = row['active_alerts'];
    if (activeAlerts is! List) {
      return 'Channel $normalizedChannelId';
    }
    for (final entry in activeAlerts) {
      final alert = _asObjectMap(entry);
      if (alert == null) {
        continue;
      }
      final entryChannelId = (alert['channel_id'] ?? alert['channelId'] ?? '')
          .toString()
          .trim();
      if (entryChannelId != normalizedChannelId) {
        continue;
      }
      final zoneName = (alert['zone_name'] ?? alert['zoneName'] ?? '')
          .toString()
          .trim();
      if (zoneName.isNotEmpty) {
        return zoneName;
      }
    }
    return 'Channel $normalizedChannelId';
  }

  Future<String> _buildAiFallbackReply({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
  }) async {
    final snapshot = await _readLatestSnapshot(target.siteId);
    final summary = snapshot == null
        ? null
        : _siteAwarenessSummaryFromRow(snapshot);
    final draft = await aiAssistant.draftReply(
      audience: TelegramAiAudience.client,
      messageText: update.text,
      clientId: target.clientId,
      siteId: target.siteId,
      deliveryMode: TelegramAiDeliveryMode.telegramLive,
      siteAwarenessSummary: summary,
    );
    return draft.text.trim().isEmpty
        ? 'Message received. Monitoring continues.'
        : draft.text.trim();
  }

  Future<Map<String, dynamic>?> _readLatestSnapshot(String siteId) async {
    final rows = await supabase
        .from('site_awareness_snapshots')
        .select(
          'site_id,snapshot_at,perimeter_clear,detections,known_faults,active_alerts',
        )
        .eq('site_id', siteId)
        .order('snapshot_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<List<Map<String, dynamic>>> _readActiveOnDemandVisitors(
    String siteId,
  ) async {
    final nowLocal = DateTime.now().toLocal();
    final todayValue = _dateValue(nowLocal);
    final rows = await supabase
        .from('site_expected_visitors')
        .select(
          'id,visitor_name,visitor_role,visit_type,visit_end,visit_date,is_active,notes',
        )
        .eq('site_id', siteId)
        .eq('visit_type', 'on_demand')
        .eq('visit_date', todayValue)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(20);
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) {
          final visitEndLocal = _visitEndDateTimeLocal(
            row['visit_end'],
            onDateLocal: nowLocal,
          );
          final notEnded =
              visitEndLocal == null ||
              visitEndLocal.isAfter(nowLocal) ||
              visitEndLocal.isAtSameMomentAs(nowLocal);
          return notEnded;
        })
        .toList(growable: false);
  }

  Future<void> _markOnDemandVisitorsForLeaveNotification(
    List<Map<String, dynamic>> activeVisitors,
  ) async {
    final requestedAtUtc = DateTime.now().toUtc().toIso8601String();
    for (final visitor in activeVisitors) {
      final visitorId = (visitor['id'] ?? '').toString().trim();
      if (visitorId.isEmpty) {
        continue;
      }
      await supabase
          .from('site_expected_visitors')
          .update(<String, Object?>{
            'notes': _withLeaveNotificationRequestNote(
              existingNotes: visitor['notes'],
              requestedAtUtc: requestedAtUtc,
            ),
          })
          .eq('id', visitorId);
    }
  }

  Future<int> _readActiveIncidents(String siteId) async {
    final rows = await supabase
        .from('incidents')
        .select('status')
        .eq('site_id', siteId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => _incidentIsActive((row['status'] ?? '').toString()))
        .length;
  }
}

class _ProcessorTarget {
  final String endpointId;
  final String clientId;
  final String siteId;
  final String displayLabel;
  final String endpointRole;

  const _ProcessorTarget({
    required this.endpointId,
    required this.clientId,
    required this.siteId,
    required this.displayLabel,
    required this.endpointRole,
  });
}

TelegramBridgeInboundMessage? _parseInboundMessage(Map<String, dynamic> row) {
  final updateJson = row['update_json'];
  if (updateJson is! Map) {
    return null;
  }
  final telegramUpdate = updateJson.cast<Object?, Object?>();
  final rawUpdateId = row['update_id'] ?? telegramUpdate['update_id'];
  final updateId = _asInt(rawUpdateId);
  if (updateId == null) {
    return null;
  }
  Map<Object?, Object?>? message;
  String? callbackQueryId;
  String text = '';
  Map<Object?, Object?> from = const <Object?, Object?>{};

  final messageRaw = telegramUpdate['message'];
  if (messageRaw is Map) {
    message = messageRaw.cast<Object?, Object?>();
    text = (message['text'] ?? '').toString().trim();
    final fromRaw = message['from'];
    if (fromRaw is Map) {
      from = fromRaw.cast<Object?, Object?>();
    }
  } else {
    final callbackRaw = telegramUpdate['callback_query'];
    if (callbackRaw is! Map) {
      return null;
    }
    final callback = callbackRaw.cast<Object?, Object?>();
    callbackQueryId = (callback['id'] ?? '').toString().trim();
    text = (callback['data'] ?? '').toString().trim();
    final fromRaw = callback['from'];
    if (fromRaw is Map) {
      from = fromRaw.cast<Object?, Object?>();
    }
    final callbackMessageRaw = callback['message'];
    if (callbackMessageRaw is! Map) {
      return null;
    }
    message = callbackMessageRaw.cast<Object?, Object?>();
  }

  if (text.isEmpty) {
    return null;
  }
  final chatRaw = message['chat'];
  if (chatRaw is! Map) {
    return null;
  }
  final chat = chatRaw.cast<Object?, Object?>();
  final chatId = (chat['id'] ?? '').toString().trim();
  if (chatId.isEmpty) {
    return null;
  }
  final replyToRaw = message['reply_to_message'];
  final replyTo = replyToRaw is Map
      ? replyToRaw.cast<Object?, Object?>()
      : const <Object?, Object?>{};
  final sentAtSeconds = _asInt(message['date']);
  return TelegramBridgeInboundMessage(
    updateId: updateId,
    callbackQueryId: callbackQueryId,
    messageId: _asInt(message['message_id']),
    chatId: chatId,
    chatType: (chat['type'] ?? '').toString().trim(),
    chatTitle: (chat['title'] ?? '').toString().trim().isEmpty
        ? null
        : (chat['title'] ?? '').toString().trim(),
    messageThreadId: _asInt(message['message_thread_id']),
    replyToMessageId: _asInt(replyTo['message_id']),
    replyToText: (replyTo['text'] ?? '').toString().trim().isEmpty
        ? null
        : (replyTo['text'] ?? '').toString().trim(),
    fromUserId: _asInt(from['id']),
    fromUsername: (from['username'] ?? '').toString().trim().isEmpty
        ? null
        : (from['username'] ?? '').toString().trim(),
    fromIsBot: from['is_bot'] == true,
    text: text,
    sentAtUtc: sentAtSeconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            sentAtSeconds * 1000,
            isUtc: true,
          ),
  );
}

TelegramAiSiteAwarenessSummary _siteAwarenessSummaryFromRow(
  Map<String, dynamic> row,
) {
  final detections = _asObjectMap(row['detections']);
  final activeAlerts = row['active_alerts'];
  final knownFaults = row['known_faults'];
  final snapshotAt =
      _asDateTimeUtc(row['snapshot_at']) ?? DateTime.now().toUtc();
  return TelegramAiSiteAwarenessSummary(
    observedAtUtc: snapshotAt,
    perimeterClear: row['perimeter_clear'] == true,
    humanCount:
        _asInt(detections?['human_count'] ?? detections?['humanCount']) ?? 0,
    vehicleCount:
        _asInt(detections?['vehicle_count'] ?? detections?['vehicleCount']) ??
        0,
    animalCount:
        _asInt(detections?['animal_count'] ?? detections?['animalCount']) ?? 0,
    motionCount:
        _asInt(detections?['motion_count'] ?? detections?['motionCount']) ?? 0,
    activeAlertCount: activeAlerts is List ? activeAlerts.length : 0,
    knownFaultChannels: knownFaults is List
        ? knownFaults
              .map((value) => value.toString().trim())
              .where(_isValidChannelLabel)
              .toList(growable: false)
        : const <String>[],
  );
}

Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, entryValue) => MapEntry(key.toString(), entryValue as Object?),
  );
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _asDateTimeUtc(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

bool _incidentIsActive(String value) {
  switch (value.trim().toLowerCase()) {
    case 'closed':
    case 'resolved':
    case 'all_clear':
    case 'all clear':
    case 'cancelled':
    case 'canceled':
      return false;
    default:
      return true;
  }
}

String _normalizeEndpointRole(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ? 'client' : normalized;
}

bool _isPartnerEndpointLabel(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.contains('partner');
}

bool _isValidChannelLabel(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed != null && parsed > 0;
}

String _siteLabel(String siteId) {
  final trimmed = siteId.trim();
  if (trimmed.isEmpty) {
    return 'the site';
  }
  final normalized = trimmed
      .replaceFirst(RegExp(r'^SITE-'), '')
      .toLowerCase()
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  return normalized.isEmpty ? trimmed : normalized;
}

String _humanizeLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'unknown';
  }
  return trimmed
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _relativeAgeLabel(DateTime observedAtUtc) {
  final difference = DateTime.now().toUtc().difference(observedAtUtc).abs();
  if (difference < const Duration(minutes: 1)) {
    return 'just now';
  }
  if (difference < const Duration(hours: 1)) {
    final minutes = difference.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (difference < const Duration(days: 1)) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = difference.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

String _clockLabel(DateTime? instantUtc) {
  if (instantUtc == null) {
    return 'n/a';
  }
  final local = instantUtc.toLocal();
  return _clockValue(local);
}

String _clockValue(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _dateValue(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-${two(value.day)}';
}

DateTime? _visitEndDateTimeLocal(
  Object? rawValue, {
  required DateTime onDateLocal,
}) {
  final raw = (rawValue ?? '').toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(raw);
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  final second = int.tryParse(match.group(3) ?? '0') ?? 0;
  if (hour == null || minute == null) {
    return null;
  }
  return DateTime(
    onDateLocal.year,
    onDateLocal.month,
    onDateLocal.day,
    hour.clamp(0, 23),
    minute.clamp(0, 59),
    second.clamp(0, 59),
  );
}

String? _onDemandVisitorStatusLine(List<Map<String, dynamic>> visitors) {
  if (visitors.isEmpty) {
    return null;
  }
  final primary = visitors.first;
  final visitEnd = (primary['visit_end'] ?? '').toString().trim();
  final untilLabel = visitEnd.isEmpty ? 'end of day' : visitEnd;
  if (visitors.length == 1) {
    final visitorName = (primary['visitor_name'] ?? '').toString().trim();
    if (visitorName.isNotEmpty &&
        visitorName.toLowerCase() != 'visitor' &&
        visitorName.toLowerCase() != 'delivery') {
      return '1 unregistered visitor on site ($visitorName) until $untilLabel';
    }
    return '1 unregistered visitor on site until $untilLabel';
  }
  return '${visitors.length} unregistered visitors on site until $untilLabel';
}

bool _visitorDepartureRequested(String prompt) {
  final normalized = prompt.trim().toLowerCase();
  return normalized.contains('leaving now') ||
      normalized.contains('visitors left') ||
      normalized.contains('visitor left') ||
      normalized.contains('leaving') ||
      normalized.contains('just left') ||
      normalized.contains('gone now') ||
      normalized.contains('visitor gone');
}

bool _visitorLeaveNotificationRequested(String prompt) {
  final normalized = prompt.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('let me know when they leave') ||
      normalized.contains('tell me when they leave') ||
      normalized.contains('notify me when they leave') ||
      normalized.contains('alert me when they leave') ||
      normalized.contains('let me know when visitors leave') ||
      normalized.contains('tell me when visitors leave') ||
      normalized.contains('notify me when visitors leave');
}

bool _isOnyxAlertCallbackData(String text) {
  return text.trim().toLowerCase().startsWith('oa|');
}

enum _OnyxAlertCallbackAction {
  armedResponse,
  soundWarning,
  falseAlarm,
  keepWatching,
  registerVehicle,
}

class _OnyxAlertCallback {
  final _OnyxAlertCallbackAction action;
  final String channelId;

  const _OnyxAlertCallback({required this.action, required this.channelId});
}

_OnyxAlertCallback? _parseOnyxAlertCallback(String raw) {
  final parts = raw
      .trim()
      .split('|')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length < 3 || parts.first.toLowerCase() != 'oa') {
    return null;
  }
  final action = switch (parts[1].toLowerCase()) {
    'armed_response' => _OnyxAlertCallbackAction.armedResponse,
    'sound_warning' => _OnyxAlertCallbackAction.soundWarning,
    'false_alarm' || 'all_good' => _OnyxAlertCallbackAction.falseAlarm,
    'keep_watching' || 'i_see_them' => _OnyxAlertCallbackAction.keepWatching,
    'register_vehicle' ||
    'expected_vehicle' => _OnyxAlertCallbackAction.registerVehicle,
    _ => null,
  };
  if (action == null) {
    return null;
  }
  return _OnyxAlertCallback(action: action, channelId: parts[2]);
}

class _VisitorRegistrationDetails {
  final String visitorName;
  final String visitorRole;
  final int visitorCount;
  final DateTime endLocal;

  const _VisitorRegistrationDetails({
    required this.visitorName,
    required this.visitorRole,
    required this.visitorCount,
    required this.endLocal,
  });
}

_VisitorRegistrationDetails _visitorRegistrationDetails({
  required String prompt,
  required DateTime nowLocal,
}) {
  final normalized = prompt.trim().toLowerCase();
  return _VisitorRegistrationDetails(
    visitorName: _visitorNameForPrompt(prompt, normalized),
    visitorRole: _visitorRoleForPrompt(normalized),
    visitorCount: _visitorCountForPrompt(normalized),
    endLocal: _visitorEndTime(
      prompt: prompt,
      normalized: normalized,
      nowLocal: nowLocal,
    ),
  );
}

int _visitorCountForPrompt(String normalized) {
  final numericMatch = RegExp(
    r'\b(\d+)\s+(?:anonymous\s+)?(?:visitor|visitors|guest|guests|people)\b',
  ).firstMatch(normalized);
  if (numericMatch != null) {
    final parsed = int.tryParse(numericMatch.group(1) ?? '');
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  final wordMatch = RegExp(
    r'\b(one|two|three|four|five|six|seven|eight|nine|ten)\s+(?:anonymous\s+)?(?:visitor|visitors|guest|guests|people)\b',
  ).firstMatch(normalized);
  if (wordMatch == null) {
    return 1;
  }
  return switch (wordMatch.group(1)) {
    'one' => 1,
    'two' => 2,
    'three' => 3,
    'four' => 4,
    'five' => 5,
    'six' => 6,
    'seven' => 7,
    'eight' => 8,
    'nine' => 9,
    'ten' => 10,
    _ => 1,
  };
}

bool _isGenericAnonymousVisitorName(String visitorName) {
  final normalized = visitorName.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'visitor' ||
      normalized == 'visitors' ||
      normalized == 'guest' ||
      normalized == 'guests';
}

String _visitorRoleForPrompt(String normalized) {
  if (normalized.contains('cleaner')) {
    return 'cleaner';
  }
  if (normalized.contains('gardener')) {
    return 'gardener';
  }
  if (normalized.contains('contractor')) {
    return 'contractor';
  }
  if (normalized.contains('delivery')) {
    return 'delivery';
  }
  if (normalized.contains('jonathan')) {
    return 'regular_visitor';
  }
  return 'visitor';
}

String _visitorNameForPrompt(String prompt, String normalized) {
  if (normalized.contains('cleaner')) {
    return 'Cleaner';
  }
  if (normalized.contains('gardener')) {
    return 'Gardener';
  }
  if (normalized.contains('contractor')) {
    return 'Contractor';
  }
  if (normalized.contains('delivery')) {
    return 'Delivery';
  }
  final patterns = <RegExp>[
    RegExp(
      r"^\s*([A-Za-z][A-Za-z'-]*(?:\s+[A-Za-z][A-Za-z'-]*)?)\s+is\s+here\b",
      caseSensitive: false,
    ),
    RegExp(
      r"^\s*([A-Za-z][A-Za-z'-]*(?:\s+[A-Za-z][A-Za-z'-]*)?)\s+just\s+arrived\b",
      caseSensitive: false,
    ),
    RegExp(
      r"^\s*([A-Za-z][A-Za-z'-]*(?:\s+[A-Za-z][A-Za-z'-]*)?)\s+came\s+in\b",
      caseSensitive: false,
    ),
    RegExp(
      r"letting in\s+([A-Za-z][A-Za-z'-]*(?:\s+[A-Za-z][A-Za-z'-]*)?)",
      caseSensitive: false,
    ),
    RegExp(
      r"opening for\s+([A-Za-z][A-Za-z'-]*(?:\s+[A-Za-z][A-Za-z'-]*)?)",
      caseSensitive: false,
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(prompt);
    if (match == null) {
      continue;
    }
    final candidate = (match.group(1) ?? '').trim();
    if (candidate.isNotEmpty) {
      return _humanizeVisitorName(candidate);
    }
  }
  if (normalized.contains('jonathan')) {
    return 'Jonathan';
  }
  return 'Visitor';
}

String _humanizeVisitorName(String raw) {
  return raw
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _visitorPossessiveLabel(String visitorName) {
  final trimmed = visitorName.trim();
  if (trimmed.isEmpty) {
    return 'Visitor\'s';
  }
  if (trimmed.toLowerCase().endsWith('s')) {
    return '$trimmed\'';
  }
  return '$trimmed\'s';
}

String _onDemandVisitorNotes({
  required String sourceLabel,
  required int groupSize,
}) {
  final parts = <String>[sourceLabel.trim()];
  if (groupSize > 1) {
    parts.add('anonymous_group_size=$groupSize');
  }
  return parts.join(' | ');
}

String _withLeaveNotificationRequestNote({
  required Object? existingNotes,
  required String requestedAtUtc,
}) {
  final parts = (existingNotes ?? '')
      .toString()
      .split('|')
      .map((value) => value.trim())
      .where(
        (value) =>
            value.isNotEmpty &&
            value != 'notify_when_left=true' &&
            !value.startsWith('notify_requested_at='),
      )
      .toList(growable: true);
  parts.add('notify_when_left=true');
  parts.add('notify_requested_at=$requestedAtUtc');
  return parts.join(' | ');
}

DateTime _vehicleRegistrationEndTime(DateTime nowLocal) {
  final endOfDay = DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
    23,
    59,
  );
  if (!endOfDay.isBefore(nowLocal)) {
    return endOfDay;
  }
  return nowLocal.add(const Duration(hours: 4));
}

String _telegramInlineIncidentId(DateTime nowUtc) {
  final millis = nowUtc.toUtc().millisecondsSinceEpoch.toString();
  return 'INC-${millis.substring(math.max(0, millis.length - 6))}';
}

DateTime _visitorEndTime({
  required String prompt,
  required String normalized,
  required DateTime nowLocal,
}) {
  final forHoursMatch = RegExp(
    r'\bfor\s+(\d+)\s+hours?\b',
  ).firstMatch(normalized);
  if (forHoursMatch != null) {
    final hours = int.tryParse(forHoursMatch.group(1) ?? '');
    if (hours != null && hours > 0) {
      return nowLocal.add(Duration(hours: hours));
    }
  }
  if (normalized.contains('until lunchtime') ||
      normalized.contains('until lunch')) {
    return DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 13, 0);
  }
  final untilMatch = RegExp(
    r'until\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
    caseSensitive: false,
  ).firstMatch(prompt);
  if (untilMatch != null) {
    final hourRaw = int.tryParse(untilMatch.group(1) ?? '');
    final minuteRaw = int.tryParse(untilMatch.group(2) ?? '0') ?? 0;
    final meridiem = untilMatch.group(3)?.toLowerCase();
    if (hourRaw != null) {
      var hour = hourRaw;
      if (meridiem == 'pm' && hour < 12) {
        hour += 12;
      } else if (meridiem == 'am' && hour == 12) {
        hour = 0;
      }
      final parsed = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        hour.clamp(0, 23),
        minuteRaw.clamp(0, 59),
      );
      if (!parsed.isBefore(nowLocal)) {
        return parsed;
      }
    }
  }
  final defaultEnd = DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
    17,
    0,
  );
  if (!defaultEnd.isBefore(nowLocal)) {
    return defaultEnd;
  }
  return DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 23, 59);
}

void _logInfo(String message) {
  stdout.writeln('[ONYX] $message');
}

void _logError(String message, {Object? error, StackTrace? stackTrace}) {
  stderr.writeln('[ONYX] $message');
  if (error != null) {
    stderr.writeln('[ONYX]   error: $error');
  }
  if (stackTrace != null) {
    stderr.writeln('[ONYX]   stack: $stackTrace');
  }
}

String _preview(String value, {int maxLength = 220}) {
  final trimmed = value.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}...';
}

class OpenAiRuntimeConfig {
  final String apiKey;
  final String model;
  final Uri? endpoint;

  const OpenAiRuntimeConfig({
    required this.apiKey,
    required this.model,
    required this.endpoint,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  static OpenAiRuntimeConfig resolve({
    required String primaryApiKey,
    required String primaryModel,
    required String primaryEndpoint,
    String secondaryApiKey = '',
    String secondaryModel = '',
    String secondaryEndpoint = '',
    String genericApiKey = '',
    String genericModel = '',
    String genericBaseUrl = '',
  }) {
    final apiKey = _firstNonEmpty(
      primaryApiKey,
      secondaryApiKey,
      genericApiKey,
    );
    final model = _firstNonEmpty(primaryModel, secondaryModel, genericModel);
    final endpointRaw = _firstNonEmpty(
      primaryEndpoint,
      secondaryEndpoint,
      genericBaseUrl,
    );
    return OpenAiRuntimeConfig(
      apiKey: apiKey,
      model: model,
      endpoint: _resolveResponsesEndpoint(endpointRaw),
    );
  }

  static String _firstNonEmpty(String first, String second, String third) {
    if (first.trim().isNotEmpty) {
      return first.trim();
    }
    if (second.trim().isNotEmpty) {
      return second.trim();
    }
    return third.trim();
  }

  static Uri? _resolveResponsesEndpoint(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return Uri.parse('https://api.openai.com/v1/responses');
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }
    final normalizedPath = parsed.path.trim();
    if (normalizedPath.isEmpty || normalizedPath == '/') {
      return parsed.replace(path: '/v1/responses');
    }
    if (normalizedPath.endsWith('/responses') ||
        normalizedPath == '/responses') {
      return parsed;
    }
    if (normalizedPath == '/v1' || normalizedPath == 'v1') {
      return parsed.replace(path: '/v1/responses');
    }
    return parsed;
  }
}

enum TelegramAiAudience { admin, client }

enum TelegramAiDeliveryMode { telegramLive, approvalDraft, smsFallback }

class TelegramAiDraftReply {
  final String text;
  final bool usedFallback;
  final String providerLabel;

  const TelegramAiDraftReply({
    required this.text,
    this.usedFallback = false,
    this.providerLabel = 'fallback',
  });
}

class TelegramAiSiteAwarenessSummary {
  final DateTime observedAtUtc;
  final bool perimeterClear;
  final int humanCount;
  final int vehicleCount;
  final int animalCount;
  final int motionCount;
  final int activeAlertCount;
  final List<String> knownFaultChannels;

  const TelegramAiSiteAwarenessSummary({
    required this.observedAtUtc,
    required this.perimeterClear,
    required this.humanCount,
    required this.vehicleCount,
    required this.animalCount,
    required this.motionCount,
    required this.activeAlertCount,
    this.knownFaultChannels = const <String>[],
  });

  String get contextSummary {
    final faults = knownFaultChannels.isEmpty
        ? 'all reporting channels healthy'
        : knownFaultChannels
              .map((value) => 'Channel $value offline')
              .join(', ');
    return '${perimeterClear ? 'perimeter clear' : 'perimeter alert active'}, '
        '$humanCount people, $vehicleCount vehicles, $animalCount animals, '
        '$activeAlertCount active alerts, $faults';
  }
}

abstract class TelegramAiAssistantService {
  bool get isConfigured;

  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  });
}

class UnconfiguredTelegramAiAssistantService
    implements TelegramAiAssistantService {
  const UnconfiguredTelegramAiAssistantService();

  @override
  bool get isConfigured => false;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    final siteLabel = _siteLabel(siteId ?? '');
    final summary = siteAwarenessSummary?.contextSummary;
    final text = summary == null
        ? 'Message received for $siteLabel. Monitoring continues.'
        : 'Message received for $siteLabel. Current status: $summary.';
    return TelegramAiDraftReply(
      text: text,
      usedFallback: true,
      providerLabel: 'fallback',
    );
  }
}

class OpenAiTelegramAiAssistantService implements TelegramAiAssistantService {
  final http.Client client;
  final String apiKey;
  final String model;
  final Uri? endpoint;

  const OpenAiTelegramAiAssistantService({
    required this.client,
    required this.apiKey,
    required this.model,
    required this.endpoint,
  });

  @override
  bool get isConfigured =>
      apiKey.trim().isNotEmpty && model.trim().isNotEmpty && endpoint != null;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    if (!isConfigured) {
      return const TelegramAiDraftReply(
        text: 'Message received. Monitoring continues.',
        usedFallback: true,
        providerLabel: 'fallback',
      );
    }
    final siteLabel = _siteLabel(siteId ?? '');
    final summary =
        siteAwarenessSummary?.contextSummary ?? 'no fresh site summary';
    final systemPrompt =
        'You are ONYX, a concise security operations assistant. '
        'Reply for a ${audience.name} Telegram audience. '
        'Keep replies short, practical, and specific. '
        'Do not invent incidents, dispatches, guards, or camera facts.';
    final userPrompt =
        'Site: $siteLabel\n'
        'Client ID: ${(clientId ?? '').trim()}\n'
        'Delivery mode: ${deliveryMode.name}\n'
        'Site summary: $summary\n'
        'User message: ${messageText.trim()}';
    try {
      final response = await client
          .post(
            endpoint!,
            headers: <String, String>{
              'Authorization': 'Bearer ${apiKey.trim()}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'model': model.trim(),
              'input': <Map<String, Object?>>[
                <String, Object?>{
                  'role': 'system',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'type': 'input_text',
                      'text': systemPrompt,
                    },
                  ],
                },
                <String, Object?>{
                  'role': 'user',
                  'content': <Map<String, String>>[
                    <String, String>{'type': 'input_text', 'text': userPrompt},
                  ],
                },
              ],
              'max_output_tokens': 220,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return TelegramAiDraftReply(
          text: 'Message received for $siteLabel. Monitoring continues.',
          usedFallback: true,
          providerLabel: 'fallback',
        );
      }
      final text = _extractResponseText(response.body);
      if (text.trim().isEmpty) {
        return TelegramAiDraftReply(
          text: 'Message received for $siteLabel. Monitoring continues.',
          usedFallback: true,
          providerLabel: 'fallback',
        );
      }
      return TelegramAiDraftReply(text: text.trim(), providerLabel: 'openai');
    } catch (_) {
      return TelegramAiDraftReply(
        text: 'Message received for $siteLabel. Monitoring continues.',
        usedFallback: true,
        providerLabel: 'fallback',
      );
    }
  }

  String _extractResponseText(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map) {
        return '';
      }
      final outputText = (decoded['output_text'] ?? '').toString().trim();
      if (outputText.isNotEmpty) {
        return outputText;
      }
      final output = decoded['output'];
      if (output is List) {
        final buffer = StringBuffer();
        for (final item in output.whereType<Map>()) {
          final content = item['content'];
          if (content is! List) {
            continue;
          }
          for (final entry in content.whereType<Map>()) {
            final text = (entry['text'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              if (buffer.isNotEmpty) {
                buffer.writeln();
              }
              buffer.write(text);
            }
          }
        }
        return buffer.toString().trim();
      }
    } catch (_) {
      return '';
    }
    return '';
  }
}

class TelegramBridgeMessage {
  final String messageKey;
  final String chatId;
  final int? messageThreadId;
  final String text;
  final List<int>? photoBytes;
  final String? photoFilename;
  final Map<String, Object?>? replyMarkup;
  final String? parseMode;

  const TelegramBridgeMessage({
    required this.messageKey,
    required this.chatId,
    this.messageThreadId,
    required this.text,
    this.photoBytes,
    this.photoFilename,
    this.replyMarkup,
    this.parseMode,
  });

  bool get isPhoto => photoBytes != null && photoBytes!.isNotEmpty;
}

class TelegramBridgeInboundMessage {
  final int updateId;
  final String? callbackQueryId;
  final int? messageId;
  final String chatId;
  final String chatType;
  final String? chatTitle;
  final int? messageThreadId;
  final int? replyToMessageId;
  final String? replyToText;
  final int? fromUserId;
  final String? fromUsername;
  final bool fromIsBot;
  final String text;
  final DateTime? sentAtUtc;

  const TelegramBridgeInboundMessage({
    required this.updateId,
    this.callbackQueryId,
    this.messageId,
    required this.chatId,
    required this.chatType,
    this.chatTitle,
    this.messageThreadId,
    this.replyToMessageId,
    this.replyToText,
    this.fromUserId,
    this.fromUsername,
    this.fromIsBot = false,
    required this.text,
    this.sentAtUtc,
  });
}

class TelegramBridgeSendResult {
  final List<TelegramBridgeMessage> sent;
  final List<TelegramBridgeMessage> failed;
  final Map<String, String> failureReasonsByMessageKey;

  const TelegramBridgeSendResult({
    required this.sent,
    required this.failed,
    this.failureReasonsByMessageKey = const <String, String>{},
  });

  int get sentCount => sent.length;
}

abstract class TelegramBridgeService {
  bool get isConfigured;

  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  });

  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  });
}

class HttpTelegramBridgeService implements TelegramBridgeService {
  final http.Client client;
  final String botToken;
  final Uri? apiBaseUri;
  final Duration requestTimeout;

  const HttpTelegramBridgeService({
    required this.client,
    required this.botToken,
    this.apiBaseUri,
    this.requestTimeout = const Duration(seconds: 12),
  });

  @override
  bool get isConfigured => botToken.trim().isNotEmpty;

  @override
  Future<TelegramBridgeSendResult> sendMessages({
    required List<TelegramBridgeMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return const TelegramBridgeSendResult(sent: [], failed: []);
    }
    if (!isConfigured) {
      return TelegramBridgeSendResult(
        sent: const [],
        failed: messages,
        failureReasonsByMessageKey: {
          for (final message in messages)
            message.messageKey: 'Telegram bridge not configured.',
        },
      );
    }
    final sent = <TelegramBridgeMessage>[];
    final failed = <TelegramBridgeMessage>[];
    final failureReasons = <String, String>{};
    for (final message in messages) {
      final chatId = message.chatId.trim();
      if (chatId.isEmpty) {
        failed.add(message);
        failureReasons[message.messageKey] = 'Missing Telegram chat_id.';
        continue;
      }
      try {
        final response = message.isPhoto
            ? await _sendPhotoMessage(message).timeout(requestTimeout)
            : await client
                  .post(
                    _buildEndpoint('sendMessage'),
                    headers: const <String, String>{
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    body: jsonEncode(<String, Object?>{
                      'chat_id': chatId,
                      if (message.messageThreadId != null)
                        'message_thread_id': message.messageThreadId,
                      'text': message.text,
                      if ((message.parseMode ?? '').trim().isNotEmpty)
                        'parse_mode': message.parseMode!.trim(),
                      if (message.replyMarkup != null)
                        'reply_markup': message.replyMarkup,
                      'disable_web_page_preview': true,
                    }),
                  )
                  .timeout(requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractTelegramErrorDescription(response.body) ??
              'HTTP ${response.statusCode}';
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map || decoded['ok'] != true) {
          failed.add(message);
          failureReasons[message.messageKey] =
              _extractTelegramErrorDescription(response.body) ??
              'Telegram response invalid';
          continue;
        }
        sent.add(message);
      } catch (error) {
        failed.add(message);
        failureReasons[message.messageKey] = error.toString();
      }
    }
    return TelegramBridgeSendResult(
      sent: sent,
      failed: failed,
      failureReasonsByMessageKey: failureReasons,
    );
  }

  Future<http.Response> _sendPhotoMessage(TelegramBridgeMessage message) async {
    final endpoint = _buildEndpoint('sendPhoto');
    final request = http.MultipartRequest('POST', endpoint)
      ..fields['chat_id'] = message.chatId.trim();
    if (message.messageThreadId != null) {
      request.fields['message_thread_id'] = '${message.messageThreadId!}';
    }
    if (message.text.trim().isNotEmpty) {
      request.fields['caption'] = message.text.trim();
    }
    if ((message.parseMode ?? '').trim().isNotEmpty) {
      request.fields['parse_mode'] = message.parseMode!.trim();
    }
    if (message.replyMarkup != null) {
      request.fields['reply_markup'] = jsonEncode(message.replyMarkup);
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'photo',
        message.photoBytes!,
        filename: (message.photoFilename ?? '').trim().isEmpty
            ? 'snapshot.jpg'
            : message.photoFilename!.trim(),
      ),
    );
    final streamed = await client.send(request);
    return http.Response.fromStream(streamed);
  }

  @override
  Future<bool> answerCallbackQuery({
    required String callbackQueryId,
    String? text,
  }) async {
    if (!isConfigured || callbackQueryId.trim().isEmpty) {
      return false;
    }
    final endpoint = _buildEndpoint('answerCallbackQuery');
    try {
      final response = await client
          .post(
            endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, Object?>{
              'callback_query_id': callbackQueryId.trim(),
              if ((text ?? '').trim().isNotEmpty) 'text': text!.trim(),
            }),
          )
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map && decoded['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  String? _extractTelegramErrorDescription(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final description = (decoded['description'] ?? '').toString().trim();
        if (description.isNotEmpty) {
          return description;
        }
      }
    } catch (_) {}
    return null;
  }

  Uri _buildEndpoint(String method, {Map<String, String>? queryParameters}) {
    final normalizedToken = botToken.trim();
    final normalizedMethod = method.trim();
    final baseUri = apiBaseUri;
    if (baseUri == null) {
      return Uri.https(
        'api.telegram.org',
        '/bot$normalizedToken/$normalizedMethod',
        queryParameters,
      );
    }
    return baseUri.replace(
      path:
          '${baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path}/bot$normalizedToken/$normalizedMethod',
      queryParameters: queryParameters,
    );
  }
}

enum OnyxTelegramCommandType {
  liveStatus,
  gateAccess,
  incident,
  dispatch,
  guard,
  report,
  camera,
  intelligence,
  actionRequest,
  visitorRegistration,
  frOnboarding,
  clientStatement,
  unknown,
}

class OnyxTelegramCommandRouter {
  const OnyxTelegramCommandRouter();

  static const Set<String> _liveStatusTriggers = <String>{
    'status',
    "what's happening",
    'whats happening',
    'any activity',
    'everything okay',
    'all good',
    'whats on site',
    "what's on site",
    'how many people',
    'how many',
    'count',
    'people on site',
    'anyone on site',
    'who is on site',
    'occupancy',
    'how many residents',
    'anyone home',
    'anyone there',
    'who is home',
    'whos home',
    'which cars are home',
    'which car is home',
  };

  static const Set<String> _gateAccessTriggers = <String>{
    'gate',
    'door',
    'locked',
    'closed',
    'open',
    'access',
    'entry',
  };

  static const Set<String> _incidentTriggers = <String>{
    'incident',
    'what happened',
    'last night',
    'today',
    'yesterday',
    'show incident',
  };

  static const Set<String> _dispatchTriggers = <String>{
    'response',
    'dispatch',
    'eta',
    'arrived',
    'who responded',
  };

  static const Set<String> _guardTriggers = <String>{
    'guard',
    'patrol',
    'checkpoint',
    'guard on site',
    'missed patrol',
    'did guard patrol',
    'guard status',
  };

  static const Set<String> _reportTriggers = <String>{
    'report',
    'summary',
    'weekly',
    'monthly',
    'send report',
    'patrol report',
  };

  static const Set<String> _cameraTriggers = <String>{
    'show me',
    'camera',
    'visual',
    'clip',
    'what triggered',
  };

  static const Set<String> _intelligenceTriggers = <String>{
    'most risky',
    'worst day',
    'getting worse',
    'trends',
    'patterns',
    'unusual',
  };

  static const Set<String> _actionRequestTriggers = <String>{
    'send response',
    'escalate',
    'call guard',
    'dispatch',
  };

  static const Set<String> _visitorRegistrationTriggers = <String>{
    'cleaner is coming',
    'cleaner is here',
    'there is a cleaner',
    'cleaner on site',
    'expecting a visitor',
    'contractor coming tomorrow',
    'contractor is here',
    'gardener today',
    'cleaner came',
    'someone is working on site',
    'visitor coming',
    'delivery coming',
    'cleaner coming',
    'gardener coming',
    'contractor coming',
    'is here',
    'are here',
    'just arrived',
    'came in',
    'letting in',
    'opening for',
    'leaving now',
    'just left',
    'gone now',
  };

  static const Set<String> _frOnboardingTriggers = <String>{
    'add to the system',
    'add to onyx',
    'register as a resident',
    'register as resident',
    'register in the system',
    'enrol in the system',
    'enroll in the system',
    'add resident',
  };

  static const Set<String> _identityPhrases = <String>{
    'is my',
    'are my',
    'is our',
    'are our',
    'that was my',
    'that was our',
    'this is my',
    'that is my',
    'those are my',
    'those are our',
  };

  static const Set<String> _statementPrefixes = <String>{
    'the ',
    "that's ",
    'thats ',
    "it's ",
    'its ',
    'they ',
    'he ',
    'she ',
    'we ',
    'everyone ',
    'everyone is',
    'all ',
    'i have ',
    "i've ",
    'there is ',
    'there are ',
    'there will ',
    "there'll ",
  };

  static const Set<String> _skipClassificationPhrases = <String>{
    'yes',
    'no',
    'ok',
    'okay',
    'sure',
    'thanks',
    'thank you',
    'got it',
    'understood',
  };

  OnyxTelegramCommandType classify(String message) {
    final normalized = _normalize(message);
    if (normalized.isEmpty) {
      return OnyxTelegramCommandType.unknown;
    }
    if (_shouldSkipClassification(normalized)) {
      return OnyxTelegramCommandType.unknown;
    }
    if (_looksLikeFrOnboarding(normalized)) {
      return OnyxTelegramCommandType.frOnboarding;
    }
    if (_looksLikeVisitorRegistration(normalized)) {
      return OnyxTelegramCommandType.visitorRegistration;
    }
    if (_looksLikeClientStatement(normalized)) {
      return OnyxTelegramCommandType.clientStatement;
    }
    if (_looksLikeActionRequest(normalized)) {
      return OnyxTelegramCommandType.actionRequest;
    }
    if (_matchesAny(normalized, _intelligenceTriggers)) {
      return OnyxTelegramCommandType.intelligence;
    }
    if (_matchesAny(normalized, _cameraTriggers)) {
      return OnyxTelegramCommandType.camera;
    }
    if (_looksLikeDispatchQuery(normalized)) {
      return OnyxTelegramCommandType.dispatch;
    }
    if (_looksLikeGateAccessQuery(normalized)) {
      return OnyxTelegramCommandType.gateAccess;
    }
    if (_looksLikeIncidentQuery(normalized)) {
      return OnyxTelegramCommandType.incident;
    }
    if (_matchesAny(normalized, _reportTriggers)) {
      return OnyxTelegramCommandType.report;
    }
    if (_looksLikeLiveStatusQuery(normalized)) {
      return OnyxTelegramCommandType.liveStatus;
    }
    if (_looksLikeGuardQuery(normalized)) {
      return OnyxTelegramCommandType.guard;
    }
    return OnyxTelegramCommandType.unknown;
  }

  bool _looksLikeActionRequest(String normalized) {
    if (_matchesAny(normalized, _actionRequestTriggers)) {
      if (normalized == 'dispatch') {
        return true;
      }
      if (normalized.contains('send response') ||
          normalized.contains('send armed response') ||
          normalized.contains('call guard') ||
          normalized.contains('escalate')) {
        return true;
      }
    }
    return normalized.startsWith('dispatch ') ||
        normalized.contains('dispatch now') ||
        normalized.contains('dispatch response') ||
        normalized.contains('call the guard') ||
        normalized.contains('armed response');
  }

  bool _looksLikeDispatchQuery(String normalized) {
    if (normalized.contains('who responded') ||
        normalized.contains('response eta') ||
        normalized.contains('dispatch eta') ||
        normalized.contains('when did') && normalized.contains('arriv')) {
      return true;
    }
    if (_matchesAny(normalized, _dispatchTriggers)) {
      return normalized.contains('response') ||
          normalized.contains('dispatch') ||
          normalized.contains('eta') ||
          normalized.contains('arriv') ||
          normalized.contains('respond');
    }
    return false;
  }

  bool _looksLikeGuardQuery(String normalized) {
    if (normalized.contains('guard on site')) {
      return true;
    }
    return _matchesAny(normalized, _guardTriggers);
  }

  bool _looksLikeLiveStatusQuery(String normalized) {
    if (_matchesAny(normalized, _liveStatusTriggers)) {
      return true;
    }
    if (normalized == 'how many') {
      return true;
    }
    if (normalized.contains('how many') &&
        (normalized.contains('people') ||
            normalized.contains('resident') ||
            normalized.contains('occupancy') ||
            normalized.contains('anyone') ||
            normalized.contains('home') ||
            normalized.contains('there') ||
            normalized.contains('on site'))) {
      return true;
    }
    if (normalized.contains('which cars are home') ||
        normalized.contains('which car is home') ||
        normalized.contains('whos home')) {
      return true;
    }
    if (normalized.startsWith('is ') && normalized.endsWith(' home')) {
      return true;
    }
    if (normalized.startsWith('did ') && normalized.contains(' arrive')) {
      return true;
    }
    return false;
  }

  bool _looksLikeGateAccessQuery(String normalized) {
    if (_matchesAny(normalized, _gateAccessTriggers)) {
      final hasGateNoun =
          normalized.contains('gate') ||
          normalized.contains('door') ||
          normalized.contains('access') ||
          normalized.contains('entry');
      if (hasGateNoun) {
        return true;
      }
      return normalized.split(' ').where((value) => value.isNotEmpty).length <=
          2;
    }
    final hasGateNoun =
        normalized.contains('gate') ||
        normalized.contains('door') ||
        normalized.contains('access') ||
        normalized.contains('entry');
    if (hasGateNoun) {
      return true;
    }
    final hasStateWord =
        normalized.contains('locked') ||
        normalized.contains('closed') ||
        normalized.contains('open');
    if (!hasStateWord) {
      return false;
    }
    return normalized.split(' ').where((value) => value.isNotEmpty).length <= 2;
  }

  bool _looksLikeIncidentQuery(String normalized) {
    if (_matchesAny(normalized, _incidentTriggers)) {
      return true;
    }
    return normalized.contains('what happened') ||
        normalized.contains('show incident') ||
        normalized.contains('incident history');
  }

  bool _looksLikeClientStatement(String normalized) {
    if (normalized.contains('?')) return false;
    const questionStarters = <String>[
      'what ',
      'when ',
      'where ',
      'who ',
      'why ',
      'how ',
      'is ',
      'are ',
      'was ',
      'were ',
      'can ',
      'could ',
      'did ',
      'does ',
      'do ',
      'will ',
      'would ',
      'should ',
      'have ',
      'has ',
      'had ',
    ];
    for (final starter in questionStarters) {
      if (normalized.startsWith(starter)) return false;
    }
    for (final prefix in _statementPrefixes) {
      if (normalized.startsWith(prefix)) return true;
    }
    if (_matchesAny(normalized, _identityPhrases)) return true;
    if ((normalized.contains('coming') ||
            normalized.contains('arriving') ||
            normalized.contains('visitor') ||
            normalized.contains('dropping by')) &&
        !normalized.startsWith('is ') &&
        !normalized.startsWith('are ')) {
      return true;
    }
    return false;
  }

  bool _looksLikeVisitorRegistration(String normalized) {
    const questionStarters = <String>[
      'what ',
      'when ',
      'where ',
      'who ',
      'why ',
      'how ',
      'is ',
      'are ',
      'was ',
      'were ',
      'can ',
      'could ',
      'did ',
      'does ',
      'do ',
      'will ',
      'would ',
      'should ',
      'have ',
      'has ',
      'had ',
    ];
    for (final starter in questionStarters) {
      if (normalized.startsWith(starter)) {
        return false;
      }
    }
    if (_matchesAny(normalized, _visitorRegistrationTriggers)) {
      return true;
    }
    final isArrivalPhrase =
        normalized.contains(' is here') ||
        normalized.contains(' are here') ||
        normalized.contains(' just arrived') ||
        normalized.contains(' came in') ||
        normalized.contains(' arrived') ||
        normalized.contains(' letting in') ||
        normalized.contains(' opening for');
    final isDeparturePhrase =
        normalized.contains(' leaving now') ||
        normalized.contains(' just left') ||
        normalized.contains(' gone now') ||
        normalized.contains(' visitor gone') ||
        normalized.contains(' cleaner leaving');
    if (isDeparturePhrase) {
      return true;
    }
    final mentionsVisitorRole =
        normalized.contains('cleaner') ||
        normalized.contains('gardener') ||
        normalized.contains('contractor') ||
        normalized.contains('visitor') ||
        normalized.contains('delivery');
    final hasDurationHint =
        normalized.contains(' until ') ||
        RegExp(r'\bfor\s+\d+\s+hours?\b').hasMatch(normalized) ||
        normalized.contains('lunchtime');
    if (mentionsVisitorRole) {
      return normalized.contains('coming') ||
          normalized.contains('expecting') ||
          normalized.contains('today') ||
          normalized.contains('tomorrow') ||
          normalized.contains('arriving') ||
          normalized.contains('here') ||
          normalized.contains('on site') ||
          normalized.contains('working') ||
          hasDurationHint;
    }
    if (hasDurationHint && isArrivalPhrase) {
      return true;
    }
    return RegExp(
          r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)?\s+is\s+here\b",
        ).hasMatch(normalized) ||
        RegExp(
          r"^[a-z][a-z'-]*(?:\s+[a-z][a-z'-]*)?\s+just\s+arrived\b",
        ).hasMatch(normalized);
  }

  bool _looksLikeFrOnboarding(String normalized) {
    if (_matchesAny(normalized, _frOnboardingTriggers)) {
      return true;
    }
    final includesAdd = normalized.contains('add ');
    final includesRegister =
        normalized.contains('register ') || normalized.contains('enroll ');
    final includesPersonContext =
        normalized.contains('resident') ||
        normalized.contains('staff') ||
        normalized.contains('guard') ||
        normalized.contains('visitor') ||
        normalized.contains('system') ||
        normalized.contains('recognition');
    return (includesAdd || includesRegister) && includesPersonContext;
  }

  bool _matchesAny(String normalized, Set<String> phrases) {
    for (final phrase in phrases) {
      if (normalized.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldSkipClassification(String normalized) {
    if (_skipClassificationPhrases.contains(normalized)) {
      return true;
    }
    final words = normalized.split(' ').where((value) => value.isNotEmpty);
    return words.length == 1 && _skipClassificationPhrases.contains(normalized);
  }

  String _normalize(String message) {
    return message
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

Map<String, dynamic>? resolveUniqueTelegramEndpointRow({
  required List<Map<String, dynamic>> rows,
  required int? messageThreadId,
  String threadField = 'telegram_thread_id',
}) {
  int? rowThread(Map<String, dynamic> row) {
    final raw = (row[threadField] ?? '').toString().trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  final materializedRows = rows.toList(growable: false);
  if (messageThreadId != null) {
    final threadMatches = materializedRows
        .where((row) => rowThread(row) == messageThreadId)
        .toList(growable: false);
    if (threadMatches.length == 1) {
      return threadMatches.single;
    }
    if (threadMatches.length > 1) {
      return null;
    }
  }
  final nonThreadRows = materializedRows
      .where((row) => rowThread(row) == null)
      .toList(growable: false);
  if (nonThreadRows.length != 1) {
    return null;
  }
  return nonThreadRows.single;
}
