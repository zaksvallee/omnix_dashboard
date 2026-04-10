import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import 'package:omnix_dashboard/application/openai_runtime_config.dart';
import 'package:omnix_dashboard/application/telegram_ai_assistant_service.dart';
import 'package:omnix_dashboard/application/telegram_bridge_service.dart';
import 'package:omnix_dashboard/application/telegram_command_router.dart';
import 'package:omnix_dashboard/application/telegram_endpoint_scope_resolution.dart';

const Duration _defaultPollInterval = Duration(seconds: 5);

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

  final apiBaseUri = Uri.tryParse(
    (Platform.environment['ONYX_TELEGRAM_API_BASE'] ?? '').trim(),
  );
  final httpClient = http.Client();
  final supabase = SupabaseClient(supabaseUrl, serviceKey);
  final aiConfig = OpenAiRuntimeConfig.resolve(
    primaryApiKey: Platform.environment['ONYX_TELEGRAM_AI_OPENAI_API_KEY'] ?? '',
    primaryModel:
        Platform.environment['ONYX_TELEGRAM_AI_OPENAI_MODEL'] ??
        'gpt-4.1-mini',
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

    var processedCount = 0;
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final rowId = (row['id'] ?? '').toString().trim();
      if (rowId.isEmpty) {
        continue;
      }
      final update = _parseInboundMessage(row);
      if (update == null) {
        await _markProcessed(rowId);
        processedCount++;
        continue;
      }
      if (update.fromIsBot || update.text.trim().isEmpty) {
        await _markProcessed(rowId);
        processedCount++;
        continue;
      }

      final target = await _resolveInboundClientTarget(
        chatId: update.chatId,
        messageThreadId: update.messageThreadId,
      );
      if (target == null) {
        developer.log(
          'Skipping inbound Telegram update ${update.updateId} — no active client endpoint binding.',
          name: 'OnyxTelegramAiProcessor',
        );
        await _markProcessed(rowId);
        processedCount++;
        continue;
      }

      final reply = await _buildReply(update: update, target: target);
      if (reply.trim().isEmpty) {
        await _markProcessed(rowId);
        processedCount++;
        continue;
      }

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
            sendResult.failureReasonsByMessageKey['telegram-ai-${update.updateId}'] ??
            'unknown send failure';
        developer.log(
          'Telegram AI send failed for update ${update.updateId}: $failure',
          name: 'OnyxTelegramAiProcessor',
        );
        continue;
      }

      await _markProcessed(rowId);
      processedCount++;
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
      OnyxTelegramCommandType.report => _buildReportReply(siteId: target.siteId),
      OnyxTelegramCommandType.guard => _buildGuardReply(siteId: target.siteId),
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
    final config = await _readOccupancyConfig(siteId);
    final incidents = await _readActiveIncidents(siteId);
    if (snapshot == null) {
      return '$siteLabel — monitoring limited right now. No fresh site snapshot is available.';
    }

    final summary = _siteAwarenessSummaryFromRow(snapshot);
    final expected = _asInt(config?['expected_occupancy']) ?? 0;
    final occupancyPeak = await _readOccupancyPeak(siteId, config);
    final displayedCount = expected > 0
        ? math.min(math.max(summary.humanCount, occupancyPeak), expected)
        : math.max(summary.humanCount, occupancyPeak);
    final lines = <String>[
      '${summary.perimeterClear && incidents == 0 ? '🟢' : '🟠'} $siteLabel',
      'Perimeter: ${summary.perimeterClear ? 'Clear' : 'Alert active'}',
      expected > 0
          ? 'On site: $displayedCount of $expected residents detected'
          : 'On site: $displayedCount people detected',
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
    final startLocal = DateTime(todayStart.year, todayStart.month, todayStart.day);
    final startUtc = startLocal.toUtc();
    final filtered = incidentRows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) {
          final when = _asDateTimeUtc(
            row['signal_received_at'] ?? row['occurred_at'] ?? row['created_at'],
          );
          return when != null && !when.isBefore(startUtc);
        })
        .toList(growable: false);
    if (filtered.isEmpty) {
      return 'No incidents recorded today at $siteLabel.';
    }
    final lines = <String>['Incidents today at $siteLabel:'];
    for (final row in filtered.take(5)) {
      final reference =
          (row['event_uid'] ?? row['id'] ?? 'incident').toString().trim();
      final status = (row['status'] ?? 'open').toString().trim();
      final incidentType = (row['incident_type'] ?? 'incident').toString().trim();
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

  Future<String> _handleVisitorRegistration({
    required String siteId,
    required String prompt,
  }) async {
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
    final inferred = _inferVisitor(prompt);
    final endLocal = _visitorEndTime(prompt, nowLocal);
    await supabase.from('site_expected_visitors').insert(<String, Object?>{
      'site_id': siteId,
      'visitor_name': inferred.$1,
      'visitor_role': inferred.$2,
      'visit_type': 'on_demand',
      'visit_days': const <String>[],
      'visit_start': _clockValue(nowLocal),
      'visit_end': _clockValue(endLocal),
      'visit_date': _dateValue(nowLocal),
      'expires_at': endLocal.toUtc().toIso8601String(),
      'is_active': true,
      'notes': 'Server-side AI processor registration',
    });
    return 'Got it. Visitor access noted until ${_clockLabel(endLocal.toUtc())}.\n'
        'I won’t alert for movement until then.\n'
        'Let me know when they leave.';
  }

  Future<String> _buildAiFallbackReply({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
  }) async {
    final snapshot = await _readLatestSnapshot(target.siteId);
    final summary = snapshot == null ? null : _siteAwarenessSummaryFromRow(snapshot);
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

  Future<Map<String, dynamic>?> _readOccupancyConfig(String siteId) async {
    final rows = await supabase
        .from('site_occupancy_config')
        .select('expected_occupancy,reset_hour')
        .eq('site_id', siteId)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<int> _readOccupancyPeak(
    String siteId,
    Map<String, dynamic>? config,
  ) async {
    final nowLocal = DateTime.now().toLocal();
    final resetHour = _asInt(config?['reset_hour']) ?? 3;
    final sessionDate = _sessionDateValue(nowLocal, resetHour);
    final rows = await supabase
        .from('site_occupancy_sessions')
        .select('peak_detected')
        .eq('site_id', siteId)
        .eq('session_date', sessionDate)
        .limit(1);
    if (rows.isEmpty) {
      return 0;
    }
    return _asInt(Map<String, dynamic>.from(rows.first as Map)['peak_detected']) ??
        0;
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
    humanCount: _asInt(detections?['human_count'] ?? detections?['humanCount']) ?? 0,
    vehicleCount:
        _asInt(detections?['vehicle_count'] ?? detections?['vehicleCount']) ?? 0,
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

String _sessionDateValue(DateTime observedAtLocal, int resetHour) {
  final normalizedResetHour = resetHour.clamp(0, 23);
  final dayStart = DateTime(
    observedAtLocal.year,
    observedAtLocal.month,
    observedAtLocal.day,
    normalizedResetHour,
  );
  final sessionLocalDate = observedAtLocal.isBefore(dayStart)
      ? dayStart.subtract(const Duration(days: 1))
      : dayStart;
  return _dateValue(sessionLocalDate);
}

bool _visitorDepartureRequested(String prompt) {
  final normalized = prompt.trim().toLowerCase();
  return normalized.contains('leaving now') ||
      normalized.contains('leaving') ||
      normalized.contains('just left') ||
      normalized.contains('gone now') ||
      normalized.contains('visitor gone');
}

(String, String) _inferVisitor(String prompt) {
  final normalized = prompt.trim().toLowerCase();
  if (normalized.contains('jonathan')) {
    return ('Jonathan', 'regular_visitor');
  }
  if (normalized.contains('cleaner')) {
    return ('Cleaner', 'cleaner');
  }
  if (normalized.contains('gardener')) {
    return ('Gardener', 'gardener');
  }
  if (normalized.contains('contractor')) {
    return ('Contractor', 'contractor');
  }
  if (normalized.contains('delivery')) {
    return ('Delivery', 'delivery');
  }
  return ('Visitor', 'visitor');
}

DateTime _visitorEndTime(String prompt, DateTime nowLocal) {
  final normalized = prompt.trim().toLowerCase();
  final forHoursMatch = RegExp(r'for\s+(\d+)\s+hour').firstMatch(normalized);
  if (forHoursMatch != null) {
    final hours = int.tryParse(forHoursMatch.group(1)!);
    if (hours != null && hours > 0) {
      return nowLocal.add(Duration(hours: hours));
    }
  }
  if (normalized.contains('until lunchtime')) {
    return DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      13,
      0,
    );
  }
  final untilMatch = RegExp(
    r'until\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?',
  ).firstMatch(normalized);
  if (untilMatch != null) {
    final hourRaw = int.tryParse(untilMatch.group(1)!);
    final minuteRaw = int.tryParse(untilMatch.group(2) ?? '0') ?? 0;
    final meridiem = untilMatch.group(3)?.toLowerCase();
    if (hourRaw != null) {
      var hour = hourRaw;
      if (meridiem == 'pm' && hour < 12) {
        hour += 12;
      } else if (meridiem == 'am' && hour == 12) {
        hour = 0;
      }
      return DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        hour.clamp(0, 23),
        minuteRaw.clamp(0, 59),
      );
    }
  }
  final defaultHour = nowLocal.hour < 17 ? 17 : 23;
  final defaultMinute = nowLocal.hour < 17 ? 0 : 59;
  return DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
    defaultHour,
    defaultMinute,
  );
}
