import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '_logging.dart';
import 'package:http/http.dart' as http;
import 'package:omnix_dashboard/application/zara/allowance_metering.dart';
import 'package:omnix_dashboard/application/zara/llm_provider.dart';
import 'package:omnix_dashboard/application/zara/openai_responses_llm_provider.dart';
import 'package:omnix_dashboard/application/zara/tools/fetch_peak_occupancy_tool.dart';
import 'package:omnix_dashboard/application/zara/tools/zara_tool.dart';
import 'package:omnix_dashboard/application/zara/tools/zara_tool_registry.dart';
import 'package:omnix_dashboard/application/zara/zara_runtime_scope_resolver.dart';
import 'package:omnix_dashboard/application/zara/zara_service.dart';
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

  // Construct LlmProvider for Zara. Reuses existing OpenAI Responses provider
  // from lib/application/zara. Anthropic provider is available in the
  // foundation but is not selected by default in this runtime.
  //
  // TODO(zara): extract runtime provider selection into a small factory when
  // there is a second runtime caller beyond Telegram.
  final LlmProvider llmProvider =
      aiConfig.isConfigured && aiConfig.endpoint != null
      ? OpenAiResponsesLlmProvider(
          client: httpClient,
          config: OpenAiResponsesLlmProviderConfig(
            apiKey: aiConfig.apiKey,
            primaryModel: aiConfig.model,
            escalatedModel: aiConfig.model,
            endpoint: aiConfig.endpoint!,
          ),
        )
      : const UnconfiguredLlmProvider();

  final toolRegistry = ZaraToolRegistry(
    toolsByName: <String, ZaraTool>{
      'fetch_peak_occupancy': FetchPeakOccupancyTool(supabase: supabase),
    },
    capabilityToToolNames: <String, List<String>>{
      'peak_occupancy': <String>['fetch_peak_occupancy'],
    },
  );

  final ZaraService zara = llmProvider.isConfigured
      ? ProviderBackedZaraService(
          llmProvider: llmProvider,
          toolRegistry: toolRegistry,
        )
      : const UnconfiguredZaraService();
  final zaraScopeResolver = ZaraRuntimeScopeResolver(
    dataSource: SupabaseZaraRuntimeScopeDataSource(supabase: supabase),
  );

  final aiAssistant = zara.isConfigured
      ? ZaraTelegramAiAssistantService(
          zara: zara,
          scopeResolver: zaraScopeResolver,
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
  final Duration pollInterval;

  const _OnyxTelegramAiProcessor({
    required this.supabase,
    required this.telegramBridge,
    required this.aiAssistant,
    required this.pollInterval,
  });

  Future<void> run() async {
    while (true) {
      var processedCount = 0;
      try {
        processedCount = await _pollOnce();
      } catch (error, stackTrace) {
        logError(
          'Telegram AI processor poll failed.',
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

    logInfo('Fetched ${rows.length} unprocessed inbound Telegram row(s).');
    var processedCount = 0;
    for (final rawRow in rows) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final rowId = (row['id'] ?? '').toString().trim();
      if (rowId.isEmpty) {
        continue;
      }
      final rowChatId = (row['chat_id'] ?? '').toString().trim();
      logInfo(
        'Processing row $rowId from ${rowChatId.isEmpty ? 'unknown-chat' : rowChatId}',
      );
      try {
        final update = _parseInboundMessage(row);
        if (update == null) {
          logInfo('Row $rowId has no usable Telegram message payload.');
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }
        if (update.fromIsBot || update.text.trim().isEmpty) {
          logInfo(
            'Row $rowId ignored (from bot=${update.fromIsBot}, emptyText=${update.text.trim().isEmpty}).',
          );
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        final isOnyxAlertCallback = _isOnyxAlertCallbackData(update.text);
        if ((update.callbackQueryId ?? '').trim().isNotEmpty &&
            !isOnyxAlertCallback) {
          final answered = await telegramBridge.answerCallbackQuery(
            callbackQueryId: update.callbackQueryId!.trim(),
          );
          if (!answered) {
            logError(
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
          logInfo(message);
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        logInfo('Sending row $rowId to AI/reply builder...');
        final String reply;
        if (isOnyxAlertCallback) {
          reply = await _handleOnyxAlertCallback(
            update: update,
            target: target,
          );
        } else if (_isVisitorRegistrationMessage(update.text)) {
          reply = await _handleVisitorRegistration(
            siteId: target.siteId,
            prompt: update.text,
          );
        } else {
          reply = await _buildReply(update: update, target: target);
        }
        logInfo('AI response for row $rowId: ${_preview(reply)}');
        if (reply.trim().isEmpty) {
          logInfo('Row $rowId produced an empty reply.');
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed.');
          processedCount++;
          continue;
        }

        logInfo('Sending Telegram reply for row $rowId...');
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
          logError('Telegram AI send failed for row $rowId: $failure');
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed after send failure.');
          processedCount++;
          continue;
        }

        await _markProcessed(rowId);
        logInfo('Row $rowId marked processed.');
        processedCount++;
      } catch (error, stackTrace) {
        logError('ERROR processing row $rowId: $error', stackTrace: stackTrace);
        try {
          await _markProcessed(rowId);
          logInfo('Row $rowId marked processed after failure.');
          processedCount++;
        } catch (markError, markStackTrace) {
          logError(
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
    final zaraCapability = classifyZaraCapability(update.text);
    if (zaraCapability != null) {
      logInfo('Zara handling capability ${zaraCapability.capabilityKey}');
      return _buildAiFallbackReply(update: update, target: target);
    }

    if (_isFrOnboardingMessage(update.text)) {
      return Future<String>.value(
        'To add someone to ONYX recognition:\n'
        '1. Send 3-5 clear face photos\n'
        "2. I'll enroll them to the site gallery\n"
        '3. ONYX will then recognise them on site',
      );
    }

    return _buildAiFallbackReply(update: update, target: target);
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
    final response = await switch (callback.action) {
      _OnyxAlertCallbackAction.view => _handleViewCallback(
        update: update,
        target: target,
        callback: callback,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.dispatch => _handleDispatchCallback(
        update: update,
        target: target,
        callback: callback,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.acknowledge => _handleAcknowledgeCallback(
        update: update,
        target: target,
        callback: callback,
        nowUtc: nowUtc,
      ),
      _OnyxAlertCallbackAction.dismiss => _handleDismissCallback(
        update: update,
        target: target,
        callback: callback,
        nowUtc: nowUtc,
      ),
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
    if (response.trim().isNotEmpty) {
      await _answerCallbackQuerySafe(
        callbackQueryId: update.callbackQueryId,
        text: response.length > 180 ? 'Action recorded.' : response,
      );
    }
    return response;
  }

  Future<String> _handleViewCallback({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    final channelId = callback.channelId.trim().isEmpty
        ? '0'
        : callback.channelId.trim();
    final responseText =
        '📷 Camera $channelId — tap the RTSP link to view live: '
        '${_telegramCameraViewUrl(channelId)}';
    await _answerCallbackQuerySafe(
      callbackQueryId: update.callbackQueryId,
      text: responseText,
    );
    await _recordAlertActionEvent(
      siteId: target.siteId,
      channelId: channelId,
      zoneName: null,
      eventType: 'telegram_view_camera',
      occurredAtUtc: nowUtc,
      rawPayload: <String, Object?>{
        'source': 'telegram_inline_button',
        'alert_id': callback.alertId.trim().isEmpty ? null : callback.alertId,
        'operator_id': _telegramOperatorLabel(update),
        'chat_id': update.chatId,
        'message_id': update.messageId,
      },
    );
    await _sendCameraViewReply(
      update: update,
      channelId: channelId,
      responseText: responseText,
    );
    return '';
  }

  Future<String> _handleDispatchCallback({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    final siteId = callback.siteId.trim().isEmpty
        ? target.siteId
        : callback.siteId.trim();
    try {
      final alertContext = await _lookupActiveAlert(
        siteId: siteId,
        alertId: callback.alertId,
      );
      final incidentId = await _upsertIncidentRow(
        alertId: callback.alertId,
        siteId: siteId,
        clientId: target.clientId,
        status: 'dispatched',
        actionTimestampColumn: 'dispatch_time',
        nowUtc: nowUtc,
        alertContext: alertContext,
        update: update,
        actionLabel: 'dispatch',
      );
      if (!await _dispatchActiveForIncident(incidentId)) {
        final priority = (alertContext?['priority'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final nowIso = nowUtc.toUtc().toIso8601String();
        await supabase.from('dispatch_intents').insert(<String, Object?>{
          'action_type': 'armed_response',
          'risk_level': switch (priority) {
            'critical' || 'high' => 'HIGH',
            'low' => 'LOW',
            _ => 'MEDIUM',
          },
          'risk_score': 0.5,
          'confidence': 1.0,
          'decision_trace': <String, Object?>{
            'incident_id': incidentId,
            'alert_id': callback.alertId,
            'source': 'telegram_button',
            'operator': _telegramOperatorLabel(update),
          },
          'geo_scope': const <String, Object?>{},
          'dcw_seconds': 0,
          'decided_at': nowIso,
          'execute_after': nowIso,
          'ati_snapshot': <String, Object?>{
            'site_id': siteId,
            'incident_id': incidentId,
          },
        });
      }
      await _finalizeAlertButtonAction(
        update: update,
        callback: callback,
        alertContext: alertContext,
        siteId: siteId,
        nowUtc: nowUtc,
        eventType: 'telegram_dispatch_requested',
        removeSnapshotAlert: false,
        callbackReplyText: '🚨 Dispatch logged for $siteId. Guard notified.',
        editActionLine:
            '🚨 Dispatch logged by operator — ${_formatLocalTime(nowUtc)}',
        incidentId: incidentId,
      );
    } catch (error, stackTrace) {
      await _failActionToast(
        update: update,
        logMessage: 'Telegram dispatch callback failed.',
        failureToast: 'Dispatch could not be logged right now.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return '';
  }

  Future<String> _handleAcknowledgeCallback({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    final siteId = target.siteId;
    try {
      final alertContext = await _lookupActiveAlert(
        siteId: siteId,
        alertId: callback.alertId,
      );
      await _upsertIncidentRow(
        alertId: callback.alertId,
        siteId: siteId,
        clientId: target.clientId,
        status: 'acknowledged',
        actionTimestampColumn: 'acknowledged_at',
        nowUtc: nowUtc,
        alertContext: alertContext,
        update: update,
        actionLabel: 'acknowledge',
      );
      await _finalizeAlertButtonAction(
        update: update,
        callback: callback,
        alertContext: alertContext,
        siteId: siteId,
        nowUtc: nowUtc,
        eventType: 'telegram_acknowledged',
        removeSnapshotAlert: false,
        callbackReplyText: '✅ Acknowledged.',
        editActionLine:
            '✅ Acknowledged by operator — ${_formatLocalTime(nowUtc)}',
      );
    } catch (error, stackTrace) {
      await _failActionToast(
        update: update,
        logMessage: 'Telegram acknowledge callback failed.',
        failureToast: 'Acknowledgement could not be saved right now.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return '';
  }

  Future<String> _handleDismissCallback({
    required TelegramBridgeInboundMessage update,
    required _ProcessorTarget target,
    required _OnyxAlertCallback callback,
    required DateTime nowUtc,
  }) async {
    final siteId = target.siteId;
    try {
      final alertContext = await _lookupActiveAlert(
        siteId: siteId,
        alertId: callback.alertId,
      );
      await _upsertIncidentRow(
        alertId: callback.alertId,
        siteId: siteId,
        clientId: target.clientId,
        status: 'false_alarm',
        actionTimestampColumn: 'resolution_time',
        nowUtc: nowUtc,
        alertContext: alertContext,
        update: update,
        actionLabel: 'false_alarm',
        controllerNotes: 'Marked as false alarm via Telegram operator action',
      );
      await _finalizeAlertButtonAction(
        update: update,
        callback: callback,
        alertContext: alertContext,
        siteId: siteId,
        nowUtc: nowUtc,
        eventType: 'telegram_false_alarm',
        removeSnapshotAlert: true,
        callbackReplyText: '🔕 Marked as false alarm.',
        editActionLine:
            '🔕 Marked as false alarm — ${_formatLocalTime(nowUtc)}',
      );
    } catch (error, stackTrace) {
      await _failActionToast(
        update: update,
        logMessage: 'Telegram false-alarm callback failed.',
        failureToast: 'False alarm could not be saved right now.',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return '';
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

  Future<void> _answerCallbackQuerySafe({
    required String? callbackQueryId,
    required String text,
  }) async {
    final normalized = (callbackQueryId ?? '').trim();
    if (normalized.isEmpty) {
      return;
    }
    try {
      await telegramBridge.answerCallbackQuery(
        callbackQueryId: normalized,
        text: text,
      );
    } catch (error, stackTrace) {
      logError(
        'Failed to answer Telegram callback query.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _sendCameraViewReply({
    required TelegramBridgeInboundMessage update,
    required String channelId,
    required String responseText,
  }) async {
    final snapshotBytes = await _fetchLatestSnapshotBytes(channelId);
    final message = TelegramBridgeMessage(
      messageKey:
          'telegram-view-${update.updateId}-${channelId.trim().isEmpty ? '0' : channelId.trim()}',
      chatId: update.chatId,
      messageThreadId: update.messageThreadId,
      replyToMessageId: update.messageId,
      text: snapshotBytes == null || snapshotBytes.isEmpty
          ? '📷 Camera ${channelId.trim().isEmpty ? '0' : channelId.trim()} snapshot unavailable right now.\n$responseText'
          : responseText,
      photoBytes: snapshotBytes,
      photoFilename: snapshotBytes == null || snapshotBytes.isEmpty
          ? null
          : 'onyx-camera-${channelId.trim().isEmpty ? '0' : channelId.trim()}.jpg',
    );
    await telegramBridge.sendMessages(
      messages: <TelegramBridgeMessage>[message],
    );
  }

  Future<List<int>?> _fetchLatestSnapshotBytes(String channelId) async {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return null;
    }
    const base = String.fromEnvironment(
      'ONYX_RTSP_FRAME_SERVER_BASE_URL',
      defaultValue: 'http://127.0.0.1:11638',
    );
    final baseUri = Uri.tryParse(base);
    if (baseUri == null) {
      return null;
    }
    final frameUri = baseUri.replace(
      path:
          '${baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path}/frame/$normalizedChannelId',
    );
    final client = http.Client();
    try {
      final response = await client
          .get(frameUri, headers: const <String, String>{'Accept': 'image/*'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.bodyBytes.isEmpty ? null : response.bodyBytes;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  Future<Map<String, Object?>?> _lookupActiveAlert({
    required String siteId,
    required String alertId,
  }) async {
    final rows = await supabase
        .from('site_awareness_snapshots')
        .select('active_alerts')
        .eq('site_id', siteId.trim())
        .limit(1);
    if (rows.isEmpty) return null;
    final raw = (rows.first as Map)['active_alerts'];
    if (raw is! List) return null;
    final needle = alertId.trim();
    for (final entry in raw) {
      if (entry is! Map) continue;
      final entryAlertId = (entry['alert_id'] ?? '').toString().trim();
      if (entryAlertId == needle) {
        return Map<String, Object?>.from(entry.cast<Object?, Object?>());
      }
    }
    return null;
  }

  Future<String> _upsertIncidentRow({
    required String alertId,
    required String siteId,
    required String clientId,
    required String status,
    required String actionTimestampColumn,
    required DateTime nowUtc,
    required Map<String, Object?>? alertContext,
    required TelegramBridgeInboundMessage update,
    required String actionLabel,
    String? controllerNotes,
  }) async {
    final nowIso = nowUtc.toUtc().toIso8601String();
    final detectedAtIso =
        DateTime.tryParse(
          (alertContext?['detected_at'] ?? '').toString().trim(),
        )?.toUtc().toIso8601String() ??
        nowIso;
    final zoneName = _contextZone(alertContext);
    final channel = _contextChannel(alertContext, '');
    final priorityRaw = (alertContext?['priority'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final priority =
        const {'critical', 'high', 'medium', 'low'}.contains(priorityRaw)
        ? priorityRaw
        : 'medium';
    final values = <String, Object?>{
      'event_uid': alertId,
      'site_id': siteId,
      'client_id': clientId,
      'status': status,
      'incident_type': 'breach',
      'source': 'ops',
      'scope': 'AREA',
      'priority': priority,
      'signal_received_at': detectedAtIso,
      'occurred_at': detectedAtIso,
      'description': 'Telegram $actionLabel: ${zoneName ?? 'alert $alertId'}',
      'zone_name': ?zoneName,
      if (channel.isNotEmpty) 'channel': channel,
      actionTimestampColumn: nowIso,
      'controller_notes': ?controllerNotes,
      'metadata': <String, Object?>{
        'telegram': <String, Object?>{
          'operator': _telegramOperatorLabel(update),
          'chat_id': update.chatId,
          'message_id': update.messageId,
          'action': actionLabel,
          'action_at': nowIso,
        },
      },
    };
    final row = await supabase
        .from('incidents')
        .upsert(values, onConflict: 'event_uid')
        .select('id')
        .single();
    return (row['id'] ?? '').toString();
  }

  Future<bool> _dispatchActiveForIncident(String incidentId) async {
    final trimmed = incidentId.trim();
    if (trimmed.isEmpty) return false;
    final intents = await supabase
        .from('dispatch_intents')
        .select('dispatch_id')
        .contains('decision_trace', <String, Object?>{'incident_id': trimmed})
        .limit(10);
    if (intents.isEmpty) return false;
    final dispatchIds = intents
        .map((row) => (row['dispatch_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (dispatchIds.isEmpty) return false;
    final states = await supabase
        .from('dispatch_current_state')
        .select('current_state')
        .inFilter('dispatch_id', dispatchIds)
        .limit(10);
    const terminal = {'EXECUTED', 'ABORTED', 'OVERRIDDEN', 'FAILED'};
    return states.any((entry) {
      final state = (entry['current_state'] ?? '').toString().trim();
      return state.isNotEmpty && !terminal.contains(state);
    });
  }

  Future<void> _failActionToast({
    required TelegramBridgeInboundMessage update,
    required String logMessage,
    required String failureToast,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    logError(logMessage, error: error, stackTrace: stackTrace);
    await _answerCallbackQuerySafe(
      callbackQueryId: update.callbackQueryId,
      text: failureToast,
    );
  }

  String? _contextZone(Map<String, Object?>? context) {
    final raw = (context?['zone_name'] ?? '').toString().trim();
    return raw.isEmpty ? null : raw;
  }

  String _contextChannel(
    Map<String, Object?>? context,
    String fallbackChannelId,
  ) {
    final raw = (context?['channel_id'] ?? '').toString().trim();
    return raw.isNotEmpty ? raw : fallbackChannelId.trim();
  }

  Future<void> _finalizeAlertButtonAction({
    required TelegramBridgeInboundMessage update,
    required _OnyxAlertCallback callback,
    required Map<String, Object?>? alertContext,
    required String siteId,
    required DateTime nowUtc,
    required String eventType,
    required bool removeSnapshotAlert,
    required String callbackReplyText,
    required String editActionLine,
    String? incidentId,
  }) async {
    await _markSnapshotAlertHandled(
      siteId: siteId,
      alertId: callback.alertId,
      removeAlert: removeSnapshotAlert,
    );
    await _recordAlertActionEvent(
      siteId: siteId,
      channelId: _contextChannel(alertContext, callback.channelId),
      zoneName: _contextZone(alertContext),
      eventType: eventType,
      occurredAtUtc: nowUtc,
      rawPayload: <String, Object?>{
        'source': 'telegram_inline_button',
        'alert_id': callback.alertId,
        'operator_id': _telegramOperatorLabel(update),
        'chat_id': update.chatId,
        'message_id': update.messageId,
        'incident_id': ?incidentId,
      },
    );
    await _answerCallbackQuerySafe(
      callbackQueryId: update.callbackQueryId,
      text: callbackReplyText,
    );
    await _editAlertMessageForAction(
      update: update,
      actionLine: editActionLine,
      removeInlineKeyboard: true,
    );
  }

  Future<void> _markSnapshotAlertHandled({
    required String siteId,
    required String alertId,
    required bool removeAlert,
  }) async {
    final rows = await supabase
        .from('site_awareness_snapshots')
        .select('site_id,active_alerts')
        .eq('site_id', siteId.trim())
        .limit(1);
    if (rows.isEmpty) {
      return;
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    final rawAlerts = row['active_alerts'];
    if (rawAlerts is! List) {
      return;
    }
    final updatedAlerts = <Object?>[];
    for (final entry in rawAlerts) {
      if (entry is! Map) {
        updatedAlerts.add(entry);
        continue;
      }
      final alertMap = Map<String, Object?>.from(
        entry.cast<Object?, Object?>(),
      );
      final entryAlertId = (alertMap['alert_id'] ?? '').toString().trim();
      if (entryAlertId != alertId.trim()) {
        updatedAlerts.add(alertMap);
        continue;
      }
      if (removeAlert) {
        continue;
      }
      updatedAlerts.add(<String, Object?>{
        ...alertMap,
        'is_acknowledged': true,
      });
    }
    await supabase
        .from('site_awareness_snapshots')
        .update(<String, Object?>{'active_alerts': updatedAlerts})
        .eq('site_id', row['site_id']);
  }

  Future<void> _editAlertMessageForAction({
    required TelegramBridgeInboundMessage update,
    required String actionLine,
    required bool removeInlineKeyboard,
  }) async {
    final messageId = update.messageId;
    final originalText = (update.messageText ?? '').trim();
    if (messageId == null || messageId <= 0 || originalText.isEmpty) {
      return;
    }
    final updatedText = _appendActionLine(
      originalText: originalText,
      actionLine: actionLine,
    );
    final replyMarkup = removeInlineKeyboard
        ? const <String, Object?>{
            'inline_keyboard': <List<Map<String, String>>>[],
          }
        : null;
    if (update.messageHasPhoto) {
      await telegramBridge.editMessageCaption(
        chatId: update.chatId,
        messageId: messageId,
        caption: updatedText,
        replyMarkup: replyMarkup,
      );
      return;
    }
    await telegramBridge.editMessageText(
      chatId: update.chatId,
      messageId: messageId,
      text: updatedText,
      replyMarkup: replyMarkup,
    );
  }

  String _appendActionLine({
    required String originalText,
    required String actionLine,
  }) {
    final normalizedOriginal = originalText.trimRight();
    final normalizedActionLine = actionLine.trim();
    if (normalizedOriginal.isEmpty || normalizedActionLine.isEmpty) {
      return normalizedOriginal;
    }
    if (normalizedOriginal
        .split('\n')
        .map((line) => line.trimRight())
        .contains(normalizedActionLine)) {
      return normalizedOriginal;
    }
    return '$normalizedOriginal\n\n$normalizedActionLine';
  }

  String _telegramCameraViewUrl(String channelId) {
    final normalizedChannelId = channelId.trim().isEmpty
        ? '0'
        : channelId.trim();
    return 'http://192.168.0.67:11638/snapshot/$normalizedChannelId';
  }

  String _telegramOperatorLabel(TelegramBridgeInboundMessage update) {
    final userId = update.fromUserId?.toString().trim() ?? '';
    if (userId.isNotEmpty) {
      return 'tg:$userId';
    }
    final username = update.fromUsername?.trim() ?? '';
    if (username.isNotEmpty) {
      return '@$username';
    }
    return 'telegram';
  }

  String _formatLocalTime(DateTime instantUtc) {
    final local = instantUtc.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
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
    logInfo(
      'AI draft provider=${draft.providerLabel} fallback=${draft.usedFallback}: ${_preview(draft.text)}',
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
  String? messageText;
  var messageHasPhoto = false;
  Map<Object?, Object?> from = const <Object?, Object?>{};

  final messageRaw = telegramUpdate['message'];
  if (messageRaw is Map) {
    message = messageRaw.cast<Object?, Object?>();
    text = (message['text'] ?? '').toString().trim();
    messageText = text;
    messageHasPhoto =
        message['photo'] is List && (message['photo'] as List).isNotEmpty;
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
    messageText = (message['caption'] ?? message['text'] ?? '')
        .toString()
        .trim();
    messageHasPhoto =
        message['photo'] is List && (message['photo'] as List).isNotEmpty;
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
    messageText: messageText,
    messageHasPhoto: messageHasPhoto,
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
  final normalized = text.trim().toLowerCase();
  return normalized.startsWith('oa|') ||
      normalized.startsWith('view:') ||
      normalized.startsWith('dispatch:') ||
      normalized.startsWith('ack:') ||
      normalized.startsWith('dismiss:') ||
      normalized.startsWith('view_cam_') ||
      normalized.startsWith('dispatch_') ||
      normalized.startsWith('ack_') ||
      normalized.startsWith('dismiss_');
}

String _normalizeRoutingText(String message) {
  return message
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const Set<String> _visitorRegistrationPhrases = <String>{
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

bool _isVisitorRegistrationMessage(String text) {
  final normalized = _normalizeRoutingText(text);
  if (normalized.isEmpty) {
    return false;
  }
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
  if (_visitorRegistrationPhrases.any(normalized.contains)) {
    return true;
  }
  final isArrivalPhrase = normalized.contains(' is here') ||
      normalized.contains(' are here') ||
      normalized.contains(' just arrived') ||
      normalized.contains(' came in') ||
      normalized.contains(' arrived') ||
      normalized.contains(' letting in') ||
      normalized.contains(' opening for');
  final isDeparturePhrase = normalized.contains(' leaving now') ||
      normalized.contains(' just left') ||
      normalized.contains(' gone now') ||
      normalized.contains(' visitor gone') ||
      normalized.contains(' cleaner leaving');
  if (isDeparturePhrase) {
    return true;
  }
  final mentionsVisitorRole = normalized.contains('cleaner') ||
      normalized.contains('gardener') ||
      normalized.contains('contractor') ||
      normalized.contains('visitor') ||
      normalized.contains('delivery');
  final hasDurationHint = normalized.contains(' until ') ||
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

const Set<String> _frOnboardingPhrases = <String>{
  'add to the system',
  'add to onyx',
  'register as a resident',
  'register as resident',
  'register in the system',
  'enrol in the system',
  'enroll in the system',
  'add resident',
};

bool _isFrOnboardingMessage(String text) {
  final normalized = _normalizeRoutingText(text);
  if (normalized.isEmpty) {
    return false;
  }
  if (_frOnboardingPhrases.any(normalized.contains)) {
    return true;
  }
  final includesAdd = normalized.contains('add ');
  final includesRegister =
      normalized.contains('register ') || normalized.contains('enroll ');
  final includesPersonContext = normalized.contains('resident') ||
      normalized.contains('staff') ||
      normalized.contains('guard') ||
      normalized.contains('visitor') ||
      normalized.contains('system') ||
      normalized.contains('recognition');
  return (includesAdd || includesRegister) && includesPersonContext;
}

enum _OnyxAlertCallbackAction {
  view,
  dispatch,
  acknowledge,
  dismiss,
  armedResponse,
  soundWarning,
  falseAlarm,
  keepWatching,
  registerVehicle,
}

class _OnyxAlertCallback {
  final _OnyxAlertCallbackAction action;
  final String alertId;
  final String siteId;
  final String channelId;

  const _OnyxAlertCallback({
    required this.action,
    this.alertId = '',
    this.siteId = '',
    this.channelId = '',
  });
}

_OnyxAlertCallback? _parseOnyxAlertCallback(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('view:')) {
    final parts = trimmed.split(':');
    if (parts.length != 3) {
      return null;
    }
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.view,
      alertId: parts[1].trim(),
      channelId: parts[2].trim(),
    );
  }
  if (trimmed.startsWith('dispatch:')) {
    final parts = trimmed.split(':');
    if (parts.length != 3) {
      return null;
    }
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.dispatch,
      alertId: parts[1].trim(),
      siteId: parts[2].trim(),
    );
  }
  if (trimmed.startsWith('ack:')) {
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.acknowledge,
      alertId: trimmed.substring('ack:'.length).trim(),
    );
  }
  if (trimmed.startsWith('dismiss:')) {
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.dismiss,
      alertId: trimmed.substring('dismiss:'.length).trim(),
    );
  }
  if (trimmed.startsWith('view_cam_')) {
    final rawValue = trimmed.substring('view_cam_'.length);
    final separator = rawValue.indexOf('_');
    if (separator <= 0 || separator >= rawValue.length - 1) {
      return null;
    }
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.view,
      channelId: rawValue.substring(0, separator),
      siteId: rawValue.substring(separator + 1),
    );
  }
  if (trimmed.startsWith('dispatch_')) {
    final rawValue = trimmed.substring('dispatch_'.length);
    final separator = rawValue.lastIndexOf('_');
    if (separator <= 0 || separator >= rawValue.length - 1) {
      return null;
    }
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.dispatch,
      siteId: rawValue.substring(0, separator),
      alertId: rawValue.substring(separator + 1),
    );
  }
  if (trimmed.startsWith('ack_')) {
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.acknowledge,
      alertId: trimmed.substring('ack_'.length).trim(),
    );
  }
  if (trimmed.startsWith('dismiss_')) {
    return _OnyxAlertCallback(
      action: _OnyxAlertCallbackAction.dismiss,
      alertId: trimmed.substring('dismiss_'.length).trim(),
    );
  }
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

class ZaraTelegramAiAssistantService implements TelegramAiAssistantService {
  final ZaraService zara;
  final ZaraRuntimeScopeResolver scopeResolver;

  const ZaraTelegramAiAssistantService({
    required this.zara,
    required this.scopeResolver,
  });

  @override
  bool get isConfigured => zara.isConfigured;

  @override
  Future<TelegramAiDraftReply> draftReply({
    required TelegramAiAudience audience,
    required String messageText,
    String? clientId,
    String? siteId,
    TelegramAiDeliveryMode deliveryMode = TelegramAiDeliveryMode.telegramLive,
    TelegramAiSiteAwarenessSummary? siteAwarenessSummary,
  }) async {
    final allowanceContext = await scopeResolver.resolveAllowanceContext(
      clientId,
    );
    final activeDataSources = await scopeResolver.resolveActiveDataSources(
      clientId,
      siteId,
    );

    final result = await zara.handleTurn(
      ZaraTurnRequest(
        userMessage: messageText,
        audience: _audienceFrom(audience),
        clientId: clientId,
        siteId: siteId,
        allowanceTier: allowanceContext.plan.tier,
        activeDataSources: activeDataSources,
        siteContext: _siteContextFrom(siteAwarenessSummary),
      ),
    );

    var replyText = result.text;
    final normalizedClientId = clientId?.trim() ?? '';
    if (normalizedClientId.isNotEmpty) {
      final isEmergency = zaraMessageLooksEmergency(messageText);
      final billableUnits = zaraBillableUnitsForTurn(
        decisionLabel: result.decision.name,
        usedFallback: result.usedFallback,
        capabilityKey: result.capabilityKey,
      );
      final createdAtUtc = DateTime.now().toUtc();
      try {
        await scopeResolver.recordUsageEntry(
          ZaraUsageLedgerEntry(
            clientId: normalizedClientId,
            siteId: siteId,
            audienceLabel: audience.name,
            deliveryModeLabel: deliveryMode.name,
            allowanceTier: allowanceContext.plan.tier,
            capabilityKey: result.capabilityKey,
            decisionLabel: result.decision.name,
            providerLabel: result.providerLabel,
            usedFallback: result.usedFallback,
            isEmergency: isEmergency,
            billableUnits: billableUnits,
            createdAtUtc: createdAtUtc,
            metadata: <String, Object?>{
              'site_context_available': siteAwarenessSummary != null,
            },
          ),
        );
        if (billableUnits > 0) {
          final afterUsage = await scopeResolver.resolveMonthlyUsage(
            normalizedClientId,
            nowUtc: createdAtUtc,
            allowancePlan: allowanceContext.plan,
          );
          final warningEvent = zaraAllowanceWarningEventForTransition(
            beforeUsage: allowanceContext.usage,
            afterUsage: afterUsage,
          );
          final warningText = buildZaraAllowanceWarningText(
            event: warningEvent,
            usage: afterUsage,
            isEmergency: isEmergency,
          );
          if (warningText != null) {
            logInfo(
              'Zara allowance warning ${warningEvent.name} for '
              '$normalizedClientId used=${afterUsage.usedUnits}/'
              '${afterUsage.includedUnits} emergency=$isEmergency',
            );
            replyText = _appendAllowanceNotice(replyText, warningText);
          }
        }
      } catch (error, stackTrace) {
        logError(
          'Failed to meter Zara allowance usage for $normalizedClientId.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return TelegramAiDraftReply(
      text: replyText,
      usedFallback: result.usedFallback,
      providerLabel: result.providerLabel,
    );
  }

  static ZaraAudience _audienceFrom(TelegramAiAudience audience) {
    switch (audience) {
      case TelegramAiAudience.admin:
        return ZaraAudience.admin;
      case TelegramAiAudience.client:
        return ZaraAudience.client;
    }
  }

  static ZaraSiteContext? _siteContextFrom(
    TelegramAiSiteAwarenessSummary? summary,
  ) {
    if (summary == null) {
      return null;
    }
    return ZaraSiteContext(
      observedAtUtc: summary.observedAtUtc,
      perimeterClear: summary.perimeterClear,
      humanCount: summary.humanCount,
      vehicleCount: summary.vehicleCount,
      animalCount: summary.animalCount,
      motionCount: summary.motionCount,
      activeAlertCount: summary.activeAlertCount,
      knownFaultChannels: summary.knownFaultChannels,
      contextSummary: summary.contextSummary,
    );
  }
}

String _appendAllowanceNotice(String replyText, String warningText) {
  final normalizedReply = replyText.trim();
  final normalizedWarning = warningText.trim();
  if (normalizedWarning.isEmpty) {
    return normalizedReply;
  }
  if (normalizedReply.isEmpty) {
    return normalizedWarning;
  }
  return '$normalizedReply\n\n$normalizedWarning';
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
  final int? replyToMessageId;
  final String text;
  final List<int>? photoBytes;
  final String? photoFilename;
  final Map<String, Object?>? replyMarkup;
  final String? parseMode;

  const TelegramBridgeMessage({
    required this.messageKey,
    required this.chatId,
    this.messageThreadId,
    this.replyToMessageId,
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
  final String? messageText;
  final bool messageHasPhoto;
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
    this.messageText,
    this.messageHasPhoto = false,
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

  Future<bool> editMessageText({
    required String chatId,
    required int messageId,
    required String text,
    String? parseMode,
    Map<String, Object?>? replyMarkup,
  });

  Future<bool> editMessageCaption({
    required String chatId,
    required int messageId,
    required String caption,
    String? parseMode,
    Map<String, Object?>? replyMarkup,
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
                      if (message.replyToMessageId != null)
                        'reply_to_message_id': message.replyToMessageId,
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
    if (message.replyToMessageId != null) {
      request.fields['reply_to_message_id'] = '${message.replyToMessageId!}';
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

  @override
  Future<bool> editMessageText({
    required String chatId,
    required int messageId,
    required String text,
    String? parseMode,
    Map<String, Object?>? replyMarkup,
  }) {
    return _editMessage(
      method: 'editMessageText',
      chatId: chatId,
      messageId: messageId,
      bodyKey: 'text',
      bodyValue: text,
      parseMode: parseMode,
      replyMarkup: replyMarkup,
    );
  }

  @override
  Future<bool> editMessageCaption({
    required String chatId,
    required int messageId,
    required String caption,
    String? parseMode,
    Map<String, Object?>? replyMarkup,
  }) {
    return _editMessage(
      method: 'editMessageCaption',
      chatId: chatId,
      messageId: messageId,
      bodyKey: 'caption',
      bodyValue: caption,
      parseMode: parseMode,
      replyMarkup: replyMarkup,
    );
  }

  Future<bool> _editMessage({
    required String method,
    required String chatId,
    required int messageId,
    required String bodyKey,
    required String bodyValue,
    String? parseMode,
    Map<String, Object?>? replyMarkup,
  }) async {
    if (!isConfigured || chatId.trim().isEmpty || messageId <= 0) {
      return false;
    }
    final normalizedBody = bodyValue.trim();
    if (normalizedBody.isEmpty) {
      return false;
    }
    final payload = <String, Object?>{
      'chat_id': chatId.trim(),
      'message_id': messageId,
      bodyKey: normalizedBody,
      if ((parseMode ?? '').trim().isNotEmpty) 'parse_mode': parseMode!.trim(),
    };
    if (replyMarkup != null) {
      payload['reply_markup'] = replyMarkup;
    }
    try {
      final response = await client
          .post(
            _buildEndpoint(method),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
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
