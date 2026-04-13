import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'client_messaging_bridge_repository.dart';
import 'telegram_bridge_service.dart';

class OnyxSiteProvisioningRequest {
  final String clientId;
  final String clientName;
  final String regionId;
  final String siteId;
  final String siteName;
  final String dvrHost;
  final String dvrUsername;
  final String dvrPassword;
  final String telegramChatId;
  final String telegramBotToken;
  final int channelCount;

  const OnyxSiteProvisioningRequest({
    required this.clientId,
    required this.clientName,
    required this.regionId,
    required this.siteId,
    required this.siteName,
    required this.dvrHost,
    required this.dvrUsername,
    required this.dvrPassword,
    required this.telegramChatId,
    this.telegramBotToken = '',
    required this.channelCount,
  });
}

class OnyxSiteProvisioningResult {
  final String clientId;
  final String siteId;
  final String galleryPath;
  final String configPath;
  final bool welcomeDelivered;

  const OnyxSiteProvisioningResult({
    required this.clientId,
    required this.siteId,
    required this.galleryPath,
    required this.configPath,
    required this.welcomeDelivered,
  });
}

class OnyxSiteProvisioningService {
  final SupabaseClient supabase;
  final String workspaceRootPath;
  final String defaultTelegramBotToken;
  final http.Client httpClient;
  final DateTime Function() nowUtc;

  const OnyxSiteProvisioningService({
    required this.supabase,
    required this.workspaceRootPath,
    required this.defaultTelegramBotToken,
    required this.httpClient,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? _defaultNowUtc;

  Future<OnyxSiteProvisioningResult> provisionSite(
    OnyxSiteProvisioningRequest request,
  ) async {
    final clientId = request.clientId.trim().toUpperCase();
    final clientName = request.clientName.trim().isEmpty
        ? clientId
        : request.clientName.trim();
    final regionId = request.regionId.trim().isEmpty
        ? 'REGION-GAUTENG'
        : request.regionId.trim().toUpperCase();
    final siteId = request.siteId.trim().toUpperCase();
    final siteName = request.siteName.trim().isEmpty
        ? siteId
        : request.siteName.trim();
    final dvrHost = request.dvrHost.trim();
    final dvrUsername = request.dvrUsername.trim().isEmpty
        ? 'admin'
        : request.dvrUsername.trim();
    final dvrPassword = request.dvrPassword;
    final telegramChatId = request.telegramChatId.trim();
    final telegramBotToken = request.telegramBotToken.trim().isEmpty
        ? defaultTelegramBotToken.trim()
        : request.telegramBotToken.trim();
    final channelCount = request.channelCount < 1 ? 1 : request.channelCount;
    final now = nowUtc().toUtc();

    if (clientId.isEmpty ||
        siteId.isEmpty ||
        dvrHost.isEmpty ||
        telegramChatId.isEmpty) {
      throw ArgumentError(
        'clientId, siteId, dvrHost, and telegramChatId are required.',
      );
    }

    await _upsertClient(
      clientId: clientId,
      clientName: clientName,
      regionId: regionId,
      nowUtc: now,
    );
    await _upsertSite(
      clientId: clientId,
      clientName: clientName,
      regionId: regionId,
      siteId: siteId,
      siteName: siteName,
      dvrHost: dvrHost,
      channelCount: channelCount,
      nowUtc: now,
    );
    await _seedSiteAwarenessSnapshot(
      clientId: clientId,
      siteId: siteId,
      occurredAtUtc: now,
    );
    await _upsertShiftSchedule(
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      timezone: 'Africa/Johannesburg',
      nowUtc: now,
    );
    final galleryPath = await _ensureFaceGallery(
      siteId: siteId,
      siteName: siteName,
    );
    await _registerTelegramBinding(
      clientId: clientId,
      siteId: siteId,
      chatId: telegramChatId,
    );
    final configPath = await _writeSiteConfig(
      clientId: clientId,
      clientName: clientName,
      regionId: regionId,
      siteId: siteId,
      siteName: siteName,
      dvrHost: dvrHost,
      dvrUsername: dvrUsername,
      dvrPassword: dvrPassword,
      telegramChatId: telegramChatId,
      telegramBotToken: telegramBotToken,
      channelCount: channelCount,
      galleryPath: galleryPath,
    );
    final welcomeDelivered = await _sendWelcomeMessage(
      telegramChatId: telegramChatId,
      telegramBotToken: telegramBotToken,
      siteName: siteName,
    );
    developer.log(
      '[ONYX] Site provisioned: $siteId for $clientName',
      name: 'OnyxSiteProvisioningService',
    );
    return OnyxSiteProvisioningResult(
      clientId: clientId,
      siteId: siteId,
      galleryPath: galleryPath,
      configPath: configPath,
      welcomeDelivered: welcomeDelivered,
    );
  }

  Future<void> _upsertClient({
    required String clientId,
    required String clientName,
    required String regionId,
    required DateTime nowUtc,
  }) async {
    await supabase.from('clients').upsert(<String, Object?>{
      'client_id': clientId,
      'display_name': clientName,
      'legal_name': clientName,
      'client_type': 'guarding',
      'contact_name': 'ONYX Provisioning',
      'metadata': <String, Object?>{
        'region_id': regionId,
        'provisioned_by': 'onyx_site_provisioning_service',
        'provisioned_at': nowUtc.toIso8601String(),
      },
      'is_active': true,
    }, onConflict: 'client_id');
  }

  Future<void> _upsertSite({
    required String clientId,
    required String clientName,
    required String regionId,
    required String siteId,
    required String siteName,
    required String dvrHost,
    required int channelCount,
    required DateTime nowUtc,
  }) async {
    await supabase.from('sites').upsert(<String, Object?>{
      'site_id': siteId,
      'client_id': clientId,
      'site_name': siteName,
      'site_code': siteId,
      'timezone': 'Africa/Johannesburg',
      'physical_address': siteName,
      'risk_profile': 'residential',
      'risk_rating': 'medium',
      'guard_nudge_frequency_minutes': 30,
      'escalation_trigger_minutes': 10,
      'metadata': <String, Object?>{
        'region_id': regionId,
        'client_name': clientName,
        'dvr_host': dvrHost,
        'channel_count': channelCount,
        'provisioned_by': 'onyx_site_provisioning_service',
        'provisioned_at': nowUtc.toIso8601String(),
      },
      'is_active': true,
    }, onConflict: 'site_id');
  }

  Future<void> _seedSiteAwarenessSnapshot({
    required String clientId,
    required String siteId,
    required DateTime occurredAtUtc,
  }) async {
    await supabase.from('site_awareness_snapshots').upsert(<String, Object?>{
      'site_id': siteId,
      'client_id': clientId,
      'snapshot_at': occurredAtUtc.toIso8601String(),
      'channels': <String, Object?>{},
      'detections': <String, Object?>{},
      'perimeter_clear': true,
      'known_faults': <Object?>[],
      'active_alerts': <Object?>[],
    }, onConflict: 'site_id');
  }

  Future<void> _upsertShiftSchedule({
    required String clientId,
    required String regionId,
    required String siteId,
    required String timezone,
    required DateTime nowUtc,
  }) async {
    await supabase.from('site_shift_schedules').upsert(<String, Object?>{
      'site_id': siteId,
      'client_id': clientId,
      'region_id': regionId,
      'timezone': timezone,
      'enabled': true,
      'start_hour': 18,
      'start_minute': 0,
      'end_hour': 18,
      'end_minute': 0,
      'metadata': <String, Object?>{
        'provisioned_by': 'onyx_site_provisioning_service',
        'provisioned_at': nowUtc.toIso8601String(),
      },
      'updated_at': nowUtc.toIso8601String(),
    }, onConflict: 'site_id');
  }

  Future<String> _ensureFaceGallery({
    required String siteId,
    required String siteName,
  }) async {
    final galleryDir = Directory(
      '$workspaceRootPath/tool/face_gallery/${siteId.trim()}',
    );
    await galleryDir.create(recursive: true);
    final readme = File('${galleryDir.path}/README.md');
    const content = '''
# ONYX Face Gallery

Use one folder per enrolled person inside this site directory.

Naming convention:
- `SITEPREFIX_RESIDENT_NAME`
- `SITEPREFIX_VISITOR_NAME`
- `SITEPREFIX_FLAGGED_NAME`

Examples:
- `MSVALLEE_RESIDENT_JANE_DOE`
- `MSVALLEE_VISITOR_CONTRACTOR_01`
- `MSVALLEE_FLAGGED_TRESPASS_WARNING`

Store one or more face images inside each folder. Residents are suppressible, visitors are informational, and flagged entries escalate immediately.
''';
    await readme.writeAsString(content);
    return galleryDir.path;
  }

  Future<void> _registerTelegramBinding({
    required String clientId,
    required String siteId,
    required String chatId,
  }) async {
    final repository = SupabaseClientMessagingBridgeRepository(supabase);
    await repository.upsertOnboardingSetup(
      ClientMessagingOnboardingSetup(
        clientId: clientId,
        siteId: siteId,
        contactName: 'ONYX Provisioned Channel',
        contactRole: 'sovereign_contact',
        contactConsentConfirmed: false,
        provider: 'telegram',
        endpointLabel: 'Provisioned Telegram Bridge',
        telegramChatId: chatId,
      ),
    );
  }

  Future<String> _writeSiteConfig({
    required String clientId,
    required String clientName,
    required String regionId,
    required String siteId,
    required String siteName,
    required String dvrHost,
    required String dvrUsername,
    required String dvrPassword,
    required String telegramChatId,
    required String telegramBotToken,
    required int channelCount,
    required String galleryPath,
  }) async {
    final configDir = Directory('$workspaceRootPath/config/sites');
    await configDir.create(recursive: true);
    final configFile = File('${configDir.path}/$siteId.json');
    final payload = <String, Object?>{
      'client': <String, Object?>{
        'client_id': clientId,
        'client_name': clientName,
        'region_id': regionId,
      },
      'site': <String, Object?>{
        'site_id': siteId,
        'site_name': siteName,
        'timezone': 'Africa/Johannesburg',
      },
      'dvr': <String, Object?>{
        'provider': 'hikvision_dvr_monitor_only',
        'host': dvrHost,
        'username': dvrUsername,
        'password': dvrPassword,
        'channel_count': channelCount,
        'events_url': 'http://$dvrHost/ISAPI/Event/notification/alertStream',
        'auth_mode': 'digest',
      },
      'telegram': <String, Object?>{
        'enabled': true,
        'chat_id': telegramChatId,
        'bot_token': telegramBotToken,
      },
      'yolo': <String, Object?>{
        'enabled': true,
        'endpoint': 'http://127.0.0.1:11636/detect',
        'confidence': 0.55,
        'minimum_confidence': 0.55,
      },
      'monitoring_shift': <String, Object?>{
        'enabled': true,
        'start_hour': 18,
        'start_minute': 0,
        'end_hour': 18,
        'end_minute': 0,
      },
      'face_gallery': <String, Object?>{'path': galleryPath},
    };
    final encoder = const JsonEncoder.withIndent('  ');
    await configFile.writeAsString('${encoder.convert(payload)}\n');
    return configFile.path;
  }

  Future<bool> _sendWelcomeMessage({
    required String telegramChatId,
    required String telegramBotToken,
    required String siteName,
  }) async {
    if (telegramBotToken.trim().isEmpty) {
      return false;
    }
    final bridge = HttpTelegramBridgeService(
      client: httpClient,
      botToken: telegramBotToken.trim(),
    );
    final result = await bridge.sendMessages(
      messages: <TelegramBridgeMessage>[
        TelegramBridgeMessage(
          messageKey:
              'site-provisioned-${siteName.trim()}-${DateTime.now().microsecondsSinceEpoch}',
          chatId: telegramChatId,
          text:
              '✅ ONYX is now active for $siteName.\nYour site is being monitored.',
          source: TelegramBridgeMessageSource.system,
          audience: TelegramBridgeMessageAudience.client,
        ),
      ],
    );
    return result.failedCount == 0;
  }
}

DateTime _defaultNowUtc() => DateTime.now().toUtc();
