import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/browser_link_service.dart';
import '../application/client_camera_health_fact_packet_service.dart';
import '../application/client_delivery_message_formatter.dart';
import '../application/hazard_response_directive_service.dart';
import '../application/morning_sovereign_report_service.dart';
import '../application/monitoring_global_posture_service.dart';
import '../application/monitoring_orchestrator_service.dart';
import '../application/onyx_agent_client_draft_service.dart';
import '../application/onyx_command_brain_orchestrator.dart';
import '../application/onyx_command_parser.dart';
import '../application/onyx_command_specialist_assessment_service.dart';
import '../application/onyx_operator_orchestrator.dart';
import '../application/onyx_tool_bridge.dart';
import '../application/monitoring_synthetic_war_room_service.dart';
import '../domain/authority/onyx_command_intent.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/response_arrived.dart';
import '../domain/authority/onyx_task_protocol.dart';
import '../application/monitoring_scene_review_store.dart';
import '../application/site_activity_intelligence_service.dart';
import '../application/synthetic_promotion_summary_formatter.dart';
import '../application/monitoring_watch_action_plan.dart';
import '../application/shadow_mo_dossier_contract.dart';
import '../application/simulation/scenario_replay_history_signal_service.dart';
import '../domain/authority/onyx_command_brain_contract.dart';
import 'components/onyx_status_banner.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'operator_stream_embed_view.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

enum _IncidentPriority { p1Critical, p2High, p3Medium, p4Low }

enum _IncidentStatus { triaging, dispatched, investigating, resolved }

enum _LadderStepStatus { completed, active, thinking, pending, blocked }

enum _ContextTab { details, voip, visual }

enum _FocusLinkState { none, exact, scopeBacked, seeded }

enum _LedgerType { aiAction, humanOverride, systemEvent, escalation }

enum _ControlInboxDraftCueKind {
  timing,
  sensitive,
  detail,
  validation,
  reassurance,
  formal,
  concise,
  defaultReassurance,
}

const _commandPanelColor = OnyxDesignTokens.cardSurface;
const _commandPanelTintColor = OnyxDesignTokens.backgroundSecondary;
const _commandPanelAltColor = OnyxColorTokens.surfaceInset;
const _commandBorderColor = OnyxDesignTokens.borderSubtle;
const _commandBorderStrongColor = OnyxDesignTokens.borderStrong;
const _commandTitleColor = OnyxDesignTokens.textPrimary;
const _commandBodyColor = OnyxDesignTokens.textSecondary;
const _commandMutedColor = OnyxDesignTokens.textMuted;
const _commandShadowColor = Color(0x33000000);

typedef LiveOpsStageClientDraftCallback =
    void Function({
      required String clientId,
      required String siteId,
      required String draftText,
      required String originalDraftText,
      String room,
      String incidentReference,
    });

typedef LiveOpsCameraHealthLoader =
    Future<ClientCameraHealthFactPacket?> Function(
      String clientId,
      String siteId,
    );

typedef LiveOpsExternalUriOpener = Future<bool> Function(Uri uri);

class _ClientLaneLiveViewDialog extends StatefulWidget {
  final Uri snapshotUri;
  final String siteReference;
  final String? cameraId;
  final String verificationLabel;
  final bool streamRelayReady;
  final Future<void> Function()? onCopyFrameUrl;
  final Future<void> Function()? onOpenStreamPlayer;

  const _ClientLaneLiveViewDialog({
    required this.snapshotUri,
    required this.siteReference,
    required this.cameraId,
    required this.verificationLabel,
    this.streamRelayReady = false,
    this.onCopyFrameUrl,
    this.onOpenStreamPlayer,
  });

  @override
  State<_ClientLaneLiveViewDialog> createState() =>
      _ClientLaneLiveViewDialogState();
}

class _ClientLaneStreamRelayDialog extends StatelessWidget {
  final Uri playerUri;
  final Uri streamUri;
  final String siteReference;
  final String? cameraId;
  final String verificationLabel;
  final String relayStatusLabel;
  final Color relayStatusAccent;
  final String relayStatusSummary;
  final String relayIssue;
  final Future<void> Function()? onCopyPlayerUrl;
  final Future<void> Function()? onOpenInBrowser;

  const _ClientLaneStreamRelayDialog({
    required this.playerUri,
    required this.streamUri,
    required this.siteReference,
    required this.cameraId,
    required this.verificationLabel,
    required this.relayStatusLabel,
    required this.relayStatusAccent,
    required this.relayStatusSummary,
    this.relayIssue = '',
    this.onCopyPlayerUrl,
    this.onOpenInBrowser,
  });

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.sizeOf(context).height - 48;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: const Color(0xFFF8FBFF),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1180, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STREAM RELAY PLAYER',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0F766E),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          siteReference,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF172638),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Operator-only MJPEG relay over the temporary local Hikvision bridge. This helps the control room watch current video in-browser without claiming a native recorder live stream to residents.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF556B80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('client-lane-stream-relay-close-icon'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF4D657C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LiveViewInfoChip(
                    icon: Icons.stream_rounded,
                    label: 'Relay ${relayStatusLabel.toUpperCase()}',
                    accent: relayStatusAccent,
                  ),
                  if ((cameraId ?? '').trim().isNotEmpty)
                    _LiveViewInfoChip(
                      icon: Icons.videocam_rounded,
                      label: cameraId!.trim(),
                      accent: const Color(0xFF67E8F9),
                    ),
                  if (verificationLabel.trim().isNotEmpty)
                    _LiveViewInfoChip(
                      icon: Icons.image_rounded,
                      label: verificationLabel.trim(),
                      accent: const Color(0xFF8FD1FF),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                relayStatusSummary,
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 11.4,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (relayIssue.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  relayIssue.trim(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7A3A3A),
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: const Color(0xFF08111B),
                  constraints: const BoxConstraints(minHeight: 360),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: OperatorStreamEmbedView(
                      key: ValueKey(
                        'client-lane-stream-relay-embed-${playerUri.toString()}',
                      ),
                      uri: playerUri,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Player URL: ${playerUri.toString()}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Relay URL: ${streamUri.toString()}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey(
                      'client-lane-stream-relay-open-browser',
                    ),
                    onPressed: onOpenInBrowser == null
                        ? null
                        : () => unawaited(onOpenInBrowser!.call()),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      'OPEN IN BROWSER',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('client-lane-stream-relay-copy-url'),
                    onPressed: onCopyPlayerUrl == null
                        ? null
                        : () => unawaited(onCopyPlayerUrl!.call()),
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(
                      'COPY PLAYER URL',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('client-lane-stream-relay-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'CLOSE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientLaneLiveViewDialogState extends State<_ClientLaneLiveViewDialog> {
  static const Duration _refreshInterval = Duration(seconds: 2);

  Timer? _timer;
  bool _autoRefresh = true;
  int _nonce = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_autoRefresh) {
      return;
    }
    _timer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _nonce = DateTime.now().millisecondsSinceEpoch;
      });
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    _syncTimer();
  }

  void _refreshFrame() {
    setState(() {
      _nonce = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Uri get _resolvedUri {
    final query = Map<String, String>.from(widget.snapshotUri.queryParameters);
    query['onyx_live_view_ts'] = '$_nonce';
    return widget.snapshotUri.replace(queryParameters: query);
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.sizeOf(context).height - 48;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: const Color(0xFFF8FBFF),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1100, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE VIEW (REFRESHING STILLS)',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF2E6EA8),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.siteReference,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF172638),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Operator-only browser preview using refreshing stills. This is not a continuous stream.',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF556B80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('client-lane-live-view-close-icon'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF4D657C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LiveViewInfoChip(
                    icon: _autoRefresh
                        ? Icons.play_circle_fill_rounded
                        : Icons.pause_circle_outline_rounded,
                    label: _autoRefresh
                        ? 'Refreshing every ${_refreshInterval.inSeconds}s'
                        : 'Manual refresh only',
                    accent: _autoRefresh
                        ? const Color(0xFF34D399)
                        : const Color(0xFFF59E0B),
                  ),
                  if ((widget.cameraId ?? '').trim().isNotEmpty)
                    _LiveViewInfoChip(
                      icon: Icons.videocam_rounded,
                      label: widget.cameraId!.trim(),
                      accent: const Color(0xFF67E8F9),
                    ),
                  if (widget.verificationLabel.trim().isNotEmpty)
                    _LiveViewInfoChip(
                      icon: Icons.image_rounded,
                      label: widget.verificationLabel.trim(),
                      accent: const Color(0xFF8FD1FF),
                    ),
                  if (widget.streamRelayReady)
                    const _LiveViewInfoChip(
                      icon: Icons.stream_rounded,
                      label: 'Stream relay ready',
                      accent: Color(0xFF34D399),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    _resolvedUri.toString(),
                    key: ValueKey('client-lane-live-view-image-$_nonce'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFEFF5FA),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'The latest frame could not be rendered here. Refresh the frame or copy the URL for direct inspection.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF556B80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('client-lane-live-view-refresh'),
                    onPressed: _refreshFrame,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'REFRESH FRAME',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('client-lane-live-view-toggle'),
                    onPressed: _toggleAutoRefresh,
                    icon: Icon(
                      _autoRefresh
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _autoRefresh ? 'PAUSE LIVE VIEW' : 'RESUME LIVE VIEW',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('client-lane-live-view-copy'),
                    onPressed: widget.onCopyFrameUrl == null
                        ? null
                        : () => unawaited(widget.onCopyFrameUrl!.call()),
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(
                      'COPY FRAME URL',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.onOpenStreamPlayer != null)
                    OutlinedButton.icon(
                      key: const ValueKey('client-lane-live-view-open-stream'),
                      onPressed: () =>
                          unawaited(widget.onOpenStreamPlayer!.call()),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: Text(
                        'OPEN STREAM PLAYER',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    key: const ValueKey('client-lane-live-view-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'CLOSE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveViewInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _LiveViewInfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOpsReplayHistoryMemory {
  final OnyxCommandSurfaceMemory commandSurfaceMemory;

  const _LiveOpsReplayHistoryMemory({
    this.commandSurfaceMemory = const OnyxCommandSurfaceMemory(),
  });

  OnyxCommandSurfaceContinuityView commandContinuityView({
    bool preferRememberedContinuity = false,
  }) {
    return commandSurfaceMemory.continuityView(
      preferRememberedContinuity: preferRememberedContinuity,
    );
  }

  _LiveOpsReplayHistoryMemory copyWith({
    OnyxCommandSurfaceMemory? commandSurfaceMemory,
  }) {
    return _LiveOpsReplayHistoryMemory(
      commandSurfaceMemory: commandSurfaceMemory ?? this.commandSurfaceMemory,
    );
  }

  bool get hasData => commandSurfaceMemory.hasData;
}

String _liveOpsReplayHistoryMemoryScopeKey({
  String? clientId,
  String? siteId,
  String? focusIncidentReference,
}) {
  final normalizedClientId = (clientId ?? '').trim();
  final normalizedSiteId = (siteId ?? '').trim();
  final normalizedFocusIncidentReference = (focusIncidentReference ?? '')
      .trim();
  if (normalizedClientId.isNotEmpty) {
    if (normalizedSiteId.isNotEmpty) {
      return 'scope:$normalizedClientId|$normalizedSiteId';
    }
    return 'scope:$normalizedClientId|all-sites';
  }
  if (normalizedFocusIncidentReference.isNotEmpty) {
    return 'incident:$normalizedFocusIncidentReference';
  }
  return 'global';
}

class _IncidentRecord {
  final String id;
  final String clientId;
  final String regionId;
  final String siteId;
  final _IncidentPriority priority;
  final String type;
  final String site;
  final String timestamp;
  final _IncidentStatus status;
  final String? latestIntelHeadline;
  final String? latestIntelSummary;
  final String? latestSceneReviewLabel;
  final String? latestSceneReviewSummary;
  final String? latestSceneDecisionLabel;
  final String? latestSceneDecisionSummary;
  final String? snapshotUrl;
  final String? clipUrl;

  const _IncidentRecord({
    required this.id,
    this.clientId = '',
    this.regionId = '',
    this.siteId = '',
    required this.priority,
    required this.type,
    required this.site,
    required this.timestamp,
    required this.status,
    this.latestIntelHeadline,
    this.latestIntelSummary,
    this.latestSceneReviewLabel,
    this.latestSceneReviewSummary,
    this.latestSceneDecisionLabel,
    this.latestSceneDecisionSummary,
    this.snapshotUrl,
    this.clipUrl,
  });

  _IncidentRecord copyWith({
    String? id,
    String? clientId,
    String? regionId,
    String? siteId,
    _IncidentPriority? priority,
    String? type,
    String? site,
    String? timestamp,
    _IncidentStatus? status,
    String? latestIntelHeadline,
    String? latestIntelSummary,
    String? latestSceneReviewLabel,
    String? latestSceneReviewSummary,
    String? latestSceneDecisionLabel,
    String? latestSceneDecisionSummary,
    String? snapshotUrl,
    String? clipUrl,
  }) {
    return _IncidentRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      regionId: regionId ?? this.regionId,
      siteId: siteId ?? this.siteId,
      priority: priority ?? this.priority,
      type: type ?? this.type,
      site: site ?? this.site,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      latestIntelHeadline: latestIntelHeadline ?? this.latestIntelHeadline,
      latestIntelSummary: latestIntelSummary ?? this.latestIntelSummary,
      latestSceneReviewLabel:
          latestSceneReviewLabel ?? this.latestSceneReviewLabel,
      latestSceneReviewSummary:
          latestSceneReviewSummary ?? this.latestSceneReviewSummary,
      latestSceneDecisionLabel:
          latestSceneDecisionLabel ?? this.latestSceneDecisionLabel,
      latestSceneDecisionSummary:
          latestSceneDecisionSummary ?? this.latestSceneDecisionSummary,
      snapshotUrl: snapshotUrl ?? this.snapshotUrl,
      clipUrl: clipUrl ?? this.clipUrl,
    );
  }
}

const _hazardDirectiveService = HazardResponseDirectiveService();
const _globalPostureService = MonitoringGlobalPostureService();
const _syntheticWarRoomService = MonitoringSyntheticWarRoomService();

class _LadderStep {
  final String id;
  final String name;
  final _LadderStepStatus status;
  final String? timestamp;
  final String? details;
  final String? metadata;
  final String? thinkingMessage;

  const _LadderStep({
    required this.id,
    required this.name,
    required this.status,
    this.timestamp,
    this.details,
    this.metadata,
    this.thinkingMessage,
  });
}

class _LedgerEntry {
  final String id;
  final DateTime timestamp;
  final _LedgerType type;
  final String description;
  final String? actor;
  final String hash;
  final bool verified;
  final String? reasonCode;

  const _LedgerEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.description,
    this.actor,
    required this.hash,
    required this.verified,
    this.reasonCode,
  });
}

class _LiveOpsCommandReceipt {
  final Color accent;
  final OnyxCommandSurfaceContinuityView continuityView;

  const _LiveOpsCommandReceipt({
    required this.accent,
    this.continuityView = const OnyxCommandSurfaceContinuityView(),
  });

  String get label => continuityView.receiptLabel;

  String get headline => continuityView.receiptHeadline;

  String get detail => continuityView.receiptDetail;

  OnyxCommandBrainSnapshot? get commandBrainSnapshot =>
      continuityView.commandBrainSnapshot;
}

class LiveOpsAutoAuditReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const LiveOpsAutoAuditReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class _GuardVigilance {
  final String callsign;
  final int decayLevel;
  final String lastCheckIn;
  final List<int> sparkline;

  const _GuardVigilance({
    required this.callsign,
    required this.decayLevel,
    required this.lastCheckIn,
    required this.sparkline,
  });
}

class _SuppressedSceneReviewContext {
  final IntelligenceReceived intelligence;
  final MonitoringSceneReviewRecord review;

  const _SuppressedSceneReviewContext({
    required this.intelligence,
    required this.review,
  });
}

class _PartnerLiveProgressSummary {
  final String dispatchId;
  final String clientId;
  final String siteId;
  final String partnerLabel;
  final PartnerDispatchStatus latestStatus;
  final DateTime latestOccurredAt;
  final int declarationCount;
  final Map<PartnerDispatchStatus, DateTime> firstOccurrenceByStatus;

  const _PartnerLiveProgressSummary({
    required this.dispatchId,
    required this.clientId,
    required this.siteId,
    required this.partnerLabel,
    required this.latestStatus,
    required this.latestOccurredAt,
    required this.declarationCount,
    required this.firstOccurrenceByStatus,
  });
}

class _PartnerLiveTrendSummary {
  final int reportDays;
  final String currentScoreLabel;
  final String trendLabel;
  final String trendReason;

  const _PartnerLiveTrendSummary({
    required this.reportDays,
    required this.currentScoreLabel,
    required this.trendLabel,
    required this.trendReason,
  });
}

class LiveClientCommsSnapshot {
  final String clientId;
  final String siteId;
  final String clientVoiceProfileLabel;
  final int learnedApprovalStyleCount;
  final String learnedApprovalStyleExample;
  final int pendingLearnedStyleDraftCount;
  final int totalMessages;
  final int clientInboundCount;
  final int pendingApprovalCount;
  final int queuedPushCount;
  final String telegramHealthLabel;
  final String? telegramHealthDetail;
  final bool telegramFallbackActive;
  final String pushSyncStatusLabel;
  final String? pushSyncFailureReason;
  final String smsFallbackLabel;
  final bool smsFallbackReady;
  final bool smsFallbackEligibleNow;
  final String voiceReadinessLabel;
  final String? deliveryReadinessDetail;
  final String? latestSmsFallbackStatus;
  final DateTime? latestSmsFallbackAtUtc;
  final String? latestVoipStageStatus;
  final DateTime? latestVoipStageAtUtc;
  final List<String> recentDeliveryHistoryLines;
  final String? latestClientMessage;
  final DateTime? latestClientMessageAtUtc;
  final String? latestOnyxReply;
  final DateTime? latestOnyxReplyAtUtc;
  final String? latestPendingDraft;
  final DateTime? latestPendingDraftAtUtc;

  const LiveClientCommsSnapshot({
    required this.clientId,
    required this.siteId,
    this.clientVoiceProfileLabel = 'Auto',
    this.learnedApprovalStyleCount = 0,
    this.learnedApprovalStyleExample = '',
    this.pendingLearnedStyleDraftCount = 0,
    this.totalMessages = 0,
    this.clientInboundCount = 0,
    this.pendingApprovalCount = 0,
    this.queuedPushCount = 0,
    this.telegramHealthLabel = 'disabled',
    this.telegramHealthDetail,
    this.telegramFallbackActive = false,
    this.pushSyncStatusLabel = 'idle',
    this.pushSyncFailureReason,
    this.smsFallbackLabel = 'SMS not ready',
    this.smsFallbackReady = false,
    this.smsFallbackEligibleNow = false,
    this.voiceReadinessLabel = 'VoIP staging',
    this.deliveryReadinessDetail,
    this.latestSmsFallbackStatus,
    this.latestSmsFallbackAtUtc,
    this.latestVoipStageStatus,
    this.latestVoipStageAtUtc,
    this.recentDeliveryHistoryLines = const <String>[],
    this.latestClientMessage,
    this.latestClientMessageAtUtc,
    this.latestOnyxReply,
    this.latestOnyxReplyAtUtc,
    this.latestPendingDraft,
    this.latestPendingDraftAtUtc,
  });
}

class LiveControlInboxDraft {
  final int updateId;
  final String clientId;
  final String siteId;
  final String clientVoiceProfileLabel;
  final String sourceText;
  final String draftText;
  final String providerLabel;
  final bool usesLearnedApprovalStyle;
  final DateTime createdAtUtc;
  final bool matchesSelectedScope;

  const LiveControlInboxDraft({
    required this.updateId,
    required this.clientId,
    required this.siteId,
    this.clientVoiceProfileLabel = 'Auto',
    required this.sourceText,
    required this.draftText,
    required this.providerLabel,
    this.usesLearnedApprovalStyle = false,
    required this.createdAtUtc,
    this.matchesSelectedScope = false,
  });
}

class LiveControlInboxClientAsk {
  final String clientId;
  final String siteId;
  final String author;
  final String body;
  final String messageProvider;
  final DateTime occurredAtUtc;
  final bool matchesSelectedScope;

  const LiveControlInboxClientAsk({
    required this.clientId,
    required this.siteId,
    required this.author,
    required this.body,
    required this.messageProvider,
    required this.occurredAtUtc,
    this.matchesSelectedScope = false,
  });
}

class LiveControlInboxSnapshot {
  final String selectedClientId;
  final String selectedSiteId;
  final String selectedScopeClientVoiceProfileLabel;
  final int pendingApprovalCount;
  final int selectedScopePendingCount;
  final int awaitingResponseCount;
  final String telegramHealthLabel;
  final String? telegramHealthDetail;
  final bool telegramFallbackActive;
  final List<LiveControlInboxDraft> pendingDrafts;
  final List<LiveControlInboxClientAsk> liveClientAsks;

  const LiveControlInboxSnapshot({
    required this.selectedClientId,
    required this.selectedSiteId,
    this.selectedScopeClientVoiceProfileLabel = 'Auto',
    this.pendingApprovalCount = 0,
    this.selectedScopePendingCount = 0,
    this.awaitingResponseCount = 0,
    this.telegramHealthLabel = 'disabled',
    this.telegramHealthDetail,
    this.telegramFallbackActive = false,
    this.pendingDrafts = const <LiveControlInboxDraft>[],
    this.liveClientAsks = const <LiveControlInboxClientAsk>[],
  });
}

enum _CommandDecisionSeverity { critical, actionRequired, review }

class _CommandDecisionAction {
  final Key? key;
  final String label;
  final IconData icon;
  final Color accent;
  final Future<void> Function()? onPressed;

  const _CommandDecisionAction({
    this.key,
    required this.label,
    required this.icon,
    required this.accent,
    this.onPressed,
  });
}

class _CommandDecisionItem {
  final Key? key;
  final _CommandDecisionSeverity severity;
  final String title;
  final String detail;
  final String context;
  final IconData icon;
  final String label;
  final Color accent;
  final List<_CommandDecisionAction> actions;
  final Future<void> Function()? onTap;

  const _CommandDecisionItem({
    this.key,
    required this.severity,
    required this.title,
    required this.detail,
    required this.context,
    required this.icon,
    required this.accent,
    required this.label,
    this.actions = const <_CommandDecisionAction>[],
    this.onTap,
  });

  String get _keyValue {
    final currentKey = key;
    if (currentKey is ValueKey<Object?>) {
      return '${currentKey.value}';
    }
    return '';
  }

  bool get isClientComms => _keyValue.contains('command-item-comms-');
}

class _CommandCenterModule {
  final String label;
  final String countLabel;
  final String metricLabel;
  final IconData icon;
  final Color accent;
  final Color surface;
  final Color border;
  final LinearGradient? gradient;
  final Future<void> Function()? onTap;

  const _CommandCenterModule({
    required this.label,
    required this.countLabel,
    required this.metricLabel,
    required this.icon,
    required this.accent,
    required this.surface,
    required this.border,
    this.gradient,
    this.onTap,
  });
}

class LiveOperationsPage extends StatefulWidget {
  final List<DispatchEvent> events;
  final List<SovereignReport> morningSovereignReportHistory;
  final List<String> historicalSyntheticLearningLabels;
  final List<String> historicalShadowMoLabels;
  final List<String> historicalShadowStrengthLabels;
  final String previousTomorrowUrgencySummary;
  final String focusIncidentReference;
  final String? agentReturnIncidentReference;
  final ValueChanged<String>? onConsumeAgentReturnIncidentReference;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final String videoOpsLabel;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final LiveClientCommsSnapshot? clientCommsSnapshot;
  final LiveControlInboxSnapshot? controlInboxSnapshot;
  final OnyxAgentClientDraftService? clientDraftService;
  final LiveOpsCameraHealthLoader? onLoadCameraHealthFactPacketForScope;
  final LiveOpsExternalUriOpener? onOpenExternalUri;
  final VoidCallback? onOpenClientView;
  final void Function(String clientId, String siteId)? onOpenClientViewForScope;
  final LiveOpsStageClientDraftCallback? onStageClientDraftForScope;
  final Future<void> Function(String clientId, String siteId)?
  onClearLearnedLaneStyleForScope;
  final Future<void> Function(
    String clientId,
    String siteId,
    String? profileSignal,
  )?
  onSetLaneVoiceProfileForScope;
  final Future<void> Function(int updateId, String draftText)?
  onUpdateClientReplyDraftText;
  final Future<String> Function(int updateId, {String? approvedText})?
  onApproveClientReplyDraft;
  final Future<String> Function(int updateId)? onRejectClientReplyDraft;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;
  final VoidCallback? onOpenAlarms;
  final void Function(String incidentReference)? onOpenAlarmsForIncident;
  final void Function(String incidentReference)? onOpenAgentForIncident;
  final VoidCallback? onOpenGuards;
  final VoidCallback? onOpenRosterPlanner;
  final VoidCallback? onOpenRosterAudit;
  final VoidCallback? onOpenLatestAudit;
  final void Function(String action, String detail)? onAutoAuditAction;
  final LiveOpsAutoAuditReceipt? latestAutoAuditReceipt;
  final VoidCallback? onOpenCctv;
  final void Function(String incidentReference)? onOpenCctvForIncident;
  final void Function(String incidentReference)? onOpenTrackForIncident;
  final VoidCallback? onOpenVipProtection;
  final VoidCallback? onOpenRiskIntel;
  final bool queueStateHintSeen;
  final VoidCallback? onQueueStateHintSeen;
  final VoidCallback? onQueueStateHintReset;
  final String? guardRosterSignalLabel;
  final String? guardRosterSignalHeadline;
  final String? guardRosterSignalDetail;
  final Color? guardRosterSignalAccent;
  final bool guardRosterSignalNeedsAttention;
  final ScenarioReplayHistorySignalService scenarioReplayHistorySignalService;

  const LiveOperationsPage({
    super.key,
    required this.events,
    this.morningSovereignReportHistory = const <SovereignReport>[],
    this.historicalSyntheticLearningLabels = const <String>[],
    this.historicalShadowMoLabels = const <String>[],
    this.historicalShadowStrengthLabels = const <String>[],
    this.previousTomorrowUrgencySummary = '',
    this.focusIncidentReference = '',
    this.agentReturnIncidentReference,
    this.onConsumeAgentReturnIncidentReference,
    this.initialScopeClientId,
    this.initialScopeSiteId,
    this.videoOpsLabel = 'CCTV',
    this.sceneReviewByIntelligenceId = const {},
    this.clientCommsSnapshot,
    this.controlInboxSnapshot,
    this.clientDraftService,
    this.onLoadCameraHealthFactPacketForScope,
    this.onOpenExternalUri,
    this.onOpenClientView,
    this.onOpenClientViewForScope,
    this.onStageClientDraftForScope,
    this.onClearLearnedLaneStyleForScope,
    this.onSetLaneVoiceProfileForScope,
    this.onUpdateClientReplyDraftText,
    this.onApproveClientReplyDraft,
    this.onRejectClientReplyDraft,
    this.onOpenEventsForScope,
    this.onOpenAlarms,
    this.onOpenAlarmsForIncident,
    this.onOpenAgentForIncident,
    this.onOpenGuards,
    this.onOpenRosterPlanner,
    this.onOpenRosterAudit,
    this.onOpenLatestAudit,
    this.onAutoAuditAction,
    this.latestAutoAuditReceipt,
    this.onOpenCctv,
    this.onOpenCctvForIncident,
    this.onOpenTrackForIncident,
    this.onOpenVipProtection,
    this.onOpenRiskIntel,
    this.queueStateHintSeen = false,
    this.onQueueStateHintSeen,
    this.onQueueStateHintReset,
    this.guardRosterSignalLabel,
    this.guardRosterSignalHeadline,
    this.guardRosterSignalDetail,
    this.guardRosterSignalAccent,
    this.guardRosterSignalNeedsAttention = false,
    this.scenarioReplayHistorySignalService =
        const LocalScenarioReplayHistorySignalService(),
  });

  @override
  State<LiveOperationsPage> createState() => _LiveOperationsPageState();

  /// No-op after migration to instance fields. Each widget construction
  /// starts with fresh session state; tests no longer need a manual reset.
  static void debugResetQueueStateHintSession() {}

  /// No-op after migration to instance fields. Each widget construction
  /// starts with fresh session state; tests no longer need a manual reset.
  static void debugResetReplayHistoryMemorySession() {}
}

class _LiveOperationsPageState extends State<LiveOperationsPage> {
  static const _siteActivityService = SiteActivityIntelligenceService();
  static const _orchestratorService = MonitoringOrchestratorService();
  static const _commandParser = OnyxCommandParser();
  static const _onyxCommandBrainOrchestrator = OnyxCommandBrainOrchestrator(
    operatorOrchestrator: OnyxOperatorOrchestrator(),
  );
  static const _onyxCommandSpecialistAssessmentService =
      OnyxCommandSpecialistAssessmentService();
  static const _overrideReasonCodes = [
    'DUPLICATE_SIGNAL',
    'FALSE_ALARM',
    'TEST_EVENT',
    'CLIENT_VERIFIED_SAFE',
    'HARDWARE_FAULT',
  ];
  bool _queueStateHintSeenThisSession = false;
  Map<String, _LiveOpsReplayHistoryMemory>
  _replayHistoryMemoryByScopeThisSession =
      <String, _LiveOpsReplayHistoryMemory>{};
  static const _defaultCommandReceipt = _LiveOpsCommandReceipt(
    accent: Color(0xFF8FD1FF),
    continuityView: OnyxCommandSurfaceContinuityView(
      commandReceipt: OnyxCommandSurfaceReceiptMemory(
        label: 'LIVE COMMAND',
        headline: 'Workspace ready',
        detail:
            'Operator feedback, queue actions, and scoped handoffs stay visible in the desktop context rail.',
      ),
    ),
  );
  static const Duration _clientLaneCameraPreviewRefreshInterval = Duration(
    seconds: 5,
  );

  List<_IncidentRecord> _incidents = const [];
  List<_LedgerEntry> _projectedLedger = const [];
  List<_GuardVigilance> _vigilance = const [];
  final List<_LedgerEntry> _manualLedger = [];
  final Map<String, _IncidentStatus> _statusOverrides = {};
  Set<int> _controlInboxBusyDraftIds = <int>{};
  Set<int> _controlInboxDraftEditBusyIds = <int>{};
  Set<String> _learnedStyleBusyScopeKeys = <String>{};
  Set<String> _laneVoiceBusyScopeKeys = <String>{};
  final GlobalKey _controlInboxPanelGlobalKey = GlobalKey();
  final GlobalKey _actionLadderPanelGlobalKey = GlobalKey();
  final GlobalKey _contextAndVigilancePanelGlobalKey = GlobalKey();
  final TextEditingController _commandPromptController =
      TextEditingController();
  bool _controlInboxPriorityOnly = false;
  _ControlInboxDraftCueKind? _controlInboxCueOnlyKind;
  late bool _showQueueStateHint;
  String? _activeIncidentId;
  String _resolvedFocusReference = '';
  ScenarioReplayHistorySignal? _replayHistorySignal;
  List<ScenarioReplayHistorySignal> _replayHistorySignalStack =
      const <ScenarioReplayHistorySignal>[];
  _FocusLinkState _focusLinkState = _FocusLinkState.none;
  _ContextTab _activeTab = _ContextTab.details;
  String? _focusedVigilanceCallsign;
  Set<String> _verifiedLedgerEntryIds = <String>{};
  DateTime? _lastLedgerVerificationAt;
  _LiveOpsCommandReceipt _commandReceipt = _defaultCommandReceipt;
  bool _desktopWorkspaceActive = false;
  bool _showDetailedWorkspace = false;
  String _lastPlainLanguageCommand = '';
  OnyxCommandSurfacePreview? _lastPlainLanguagePreview;
  String _rememberedReplayHistorySummary = '';
  ClientCameraHealthFactPacket? _clientLaneCameraHealthFactPacket;
  bool _clientLaneCameraHealthLoading = false;
  bool _clientLaneCameraHealthLoadFailed = false;
  String _clientLaneCameraHealthScopeKey = '';
  int _clientLaneCameraHealthRequestSerial = 0;
  int _clientLaneCameraPreviewNonce = 0;
  bool _clientLaneCameraPreviewAutoRefresh = true;
  Timer? _clientLaneCameraPreviewTimer;

  VoidCallback? _openClientLaneAction({
    required String clientId,
    required String siteId,
  }) {
    if (widget.onOpenClientViewForScope == null &&
        widget.onOpenClientView == null) {
      return null;
    }
    return () {
      _openCommandClientLane(
        clientId: clientId,
        siteId: siteId,
        clientCommsSnapshot: _matchingClientCommsSnapshotForScope(
          clientId: clientId,
          siteId: siteId,
        ),
      );
    };
  }

  LiveClientCommsSnapshot? _matchingClientCommsSnapshotForScope({
    required String clientId,
    required String siteId,
  }) {
    final snapshot = widget.clientCommsSnapshot;
    if (snapshot == null) {
      return null;
    }
    if (snapshot.clientId.trim() != clientId.trim() ||
        snapshot.siteId.trim() != siteId.trim()) {
      return null;
    }
    return snapshot;
  }

  String _scopeBusyKey(String clientId, String siteId) =>
      '${clientId.trim()}|${siteId.trim()}';

  ClientCameraHealthFactPacket? _clientLaneCameraPacketForScope(
    LiveClientCommsSnapshot snapshot,
  ) {
    final scopeKey = _scopeBusyKey(snapshot.clientId, snapshot.siteId);
    if (_clientLaneCameraHealthScopeKey != scopeKey) {
      return null;
    }
    return _clientLaneCameraHealthFactPacket;
  }

  Future<void> _loadClientLaneCameraHealth({bool showFeedback = false}) async {
    final loader = widget.onLoadCameraHealthFactPacketForScope;
    final snapshot = widget.clientCommsSnapshot;
    if (loader == null || snapshot == null) {
      if (!mounted) {
        _clientLaneCameraHealthFactPacket = null;
        _clientLaneCameraHealthLoading = false;
        _clientLaneCameraHealthLoadFailed = false;
        _clientLaneCameraHealthScopeKey = '';
        return;
      }
      setState(() {
        _clientLaneCameraHealthFactPacket = null;
        _clientLaneCameraHealthLoading = false;
        _clientLaneCameraHealthLoadFailed = false;
        _clientLaneCameraHealthScopeKey = '';
      });
      return;
    }
    final scopeKey = _scopeBusyKey(snapshot.clientId, snapshot.siteId);
    final requestSerial = ++_clientLaneCameraHealthRequestSerial;
    if (mounted) {
      setState(() {
        _clientLaneCameraHealthLoading = true;
        _clientLaneCameraHealthLoadFailed = false;
        _clientLaneCameraHealthScopeKey = scopeKey;
      });
    } else {
      _clientLaneCameraHealthLoading = true;
      _clientLaneCameraHealthLoadFailed = false;
      _clientLaneCameraHealthScopeKey = scopeKey;
    }

    ClientCameraHealthFactPacket? packet;
    var loadFailed = false;
    try {
      packet = await loader(snapshot.clientId, snapshot.siteId);
    } catch (error, stackTrace) {
      loadFailed = true;
      debugPrint(
        'LiveOperationsPage._loadClientLaneCameraHealth failed for '
        '${snapshot.clientId}/${snapshot.siteId}: $error\n$stackTrace',
      );
      packet = null;
    }
    if (!mounted || requestSerial != _clientLaneCameraHealthRequestSerial) {
      return;
    }
    setState(() {
      _clientLaneCameraHealthFactPacket = packet;
      _clientLaneCameraHealthLoading = false;
      _clientLaneCameraHealthLoadFailed = loadFailed;
      _clientLaneCameraPreviewNonce =
          packet?.hasCurrentVisualConfirmation == true
          ? DateTime.now().millisecondsSinceEpoch
          : 0;
    });
    if (!showFeedback) {
      return;
    }
    final message = switch (packet) {
      final packet? when packet.hasCurrentVisualConfirmation =>
        'Current camera frame refreshed for ${packet.siteReference}.',
      final packet? => 'Camera health refreshed for ${packet.siteReference}.',
      null when loadFailed =>
        'Camera health check failed for the selected scope.',
      null => 'No current camera packet is available for the selected scope.',
    };
    _showLiveOpsFeedback(
      message,
      label: 'CAMERA CHECK',
      detail:
          'Use current visual confirmation when it is available, and keep event-only telemetry separate from visual claims.',
      accent: const Color(0xFF67E8F9),
    );
  }

  Future<void> _copyClientLaneCameraPreviewUrl(
    ClientCameraHealthFactPacket packet,
  ) async {
    final uri = packet.currentVisualSnapshotUri;
    if (uri == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) {
      return;
    }
    _showLiveOpsFeedback(
      'Current frame URL copied for ${packet.siteReference}.',
      label: 'CAMERA CHECK',
      detail:
          'The copied URL points to the latest verified proxy-backed frame for the selected scope.',
      accent: const Color(0xFF8FD1FF),
    );
  }

  Future<void> _openClientLaneStreamPlayer(
    ClientCameraHealthFactPacket packet,
  ) async {
    final uri =
        packet.currentVisualRelayPlayerUri ??
        packet.currentVisualRelayStreamUri;
    if (uri == null) {
      return;
    }
    final opener = widget.onOpenExternalUri;
    final opened = opener != null
        ? await opener(uri)
        : await const BrowserLinkService().open(uri);
    if (!mounted) {
      return;
    }
    if (opened) {
      _showLiveOpsFeedback(
        'Stream player opened for ${packet.siteReference}.',
        label: 'CAMERA CHECK',
        detail:
            'This browser page is an operator-only relay over the temporary local bridge, not a resident-facing proof of a native recorder live stream.',
        accent: const Color(0xFF34D399),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) {
      return;
    }
    _showLiveOpsFeedback(
      'Stream player URL copied for ${packet.siteReference}.',
      label: 'CAMERA CHECK',
      detail:
          'Open the copied URL in a browser to view the operator-only stream relay.',
      accent: const Color(0xFF8FD1FF),
    );
  }

  Future<void> _copyClientLaneStreamPlayerUrl(
    ClientCameraHealthFactPacket packet,
  ) async {
    final uri = packet.currentVisualRelayPlayerUri;
    if (uri == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) {
      return;
    }
    _showLiveOpsFeedback(
      'Stream player URL copied for ${packet.siteReference}.',
      label: 'CAMERA CHECK',
      detail:
          'The copied URL opens the operator-only relay player for the selected scope.',
      accent: const Color(0xFF8FD1FF),
    );
  }

  Future<void> _showClientLaneStreamRelayDialog(
    ClientCameraHealthFactPacket packet,
  ) async {
    final playerUri = packet.currentVisualRelayPlayerUri;
    final streamUri = packet.currentVisualRelayStreamUri;
    if (playerUri == null || streamUri == null || !mounted) {
      return;
    }
    final verificationLabel = _commsMomentLabel(
      packet.currentVisualVerifiedAtUtc ?? packet.lastSuccessfulVisualAtUtc,
    );
    final relayFrameLabel = _commsMomentLabel(
      packet.currentVisualRelayLastFrameAtUtc,
    );
    final relayCheckLabel = _commsMomentLabel(
      packet.currentVisualRelayCheckedAtUtc,
    );
    final relayIssue = _humanizeClientLaneRelayIssue(
      packet.currentVisualRelayLastError,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ClientLaneStreamRelayDialog(
          playerUri: playerUri,
          streamUri: streamUri,
          siteReference: packet.siteReference,
          cameraId: packet.currentVisualCameraId,
          verificationLabel: verificationLabel,
          relayStatusLabel: _clientLaneRelayStatusLabel(
            packet.currentVisualRelayStatus,
          ),
          relayStatusAccent: _clientLaneRelayStatusAccent(
            packet.currentVisualRelayStatus,
          ),
          relayStatusSummary: _clientLaneRelaySummary(
            packet.currentVisualRelayStatus,
            relayFrameLabel: relayFrameLabel,
            relayCheckLabel: relayCheckLabel,
            activeClientCount: packet.currentVisualRelayActiveClientCount ?? 0,
          ),
          relayIssue: relayIssue,
          onCopyPlayerUrl: () => _copyClientLaneStreamPlayerUrl(packet),
          onOpenInBrowser: () => _openClientLaneStreamPlayer(packet),
        );
      },
    );
  }

  Uri _cacheBustedPreviewUri(Uri uri) {
    final query = Map<String, String>.from(uri.queryParameters);
    query['onyx_preview_ts'] = '$_clientLaneCameraPreviewNonce';
    return uri.replace(queryParameters: query);
  }

  Future<void> _openClientLaneLiveView(
    ClientCameraHealthFactPacket packet,
  ) async {
    final snapshotUri = packet.currentVisualSnapshotUri;
    if (snapshotUri == null || !mounted) {
      return;
    }
    final verificationLabel = _commsMomentLabel(
      packet.currentVisualVerifiedAtUtc ?? packet.lastSuccessfulVisualAtUtc,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _ClientLaneLiveViewDialog(
          snapshotUri: snapshotUri,
          siteReference: packet.siteReference,
          cameraId: packet.currentVisualCameraId,
          verificationLabel: verificationLabel,
          streamRelayReady: packet.hasCurrentVisualStreamRelay,
          onCopyFrameUrl: () => _copyClientLaneCameraPreviewUrl(packet),
          onOpenStreamPlayer: packet.hasCurrentVisualStreamRelay
              ? () => _openClientLaneStreamPlayer(packet)
              : null,
        );
      },
    );
  }

  void _syncClientLaneCameraPreviewTimer() {
    _clientLaneCameraPreviewTimer?.cancel();
    _clientLaneCameraPreviewTimer = null;
    if (!_clientLaneCameraPreviewAutoRefresh ||
        widget.onLoadCameraHealthFactPacketForScope == null ||
        widget.clientCommsSnapshot == null) {
      return;
    }
    _clientLaneCameraPreviewTimer = Timer.periodic(
      _clientLaneCameraPreviewRefreshInterval,
      (_) {
        if (!mounted || _clientLaneCameraHealthLoading) {
          return;
        }
        unawaited(_loadClientLaneCameraHealth());
      },
    );
  }

  void _toggleClientLaneCameraPreviewAutoRefresh() {
    setState(() {
      _clientLaneCameraPreviewAutoRefresh =
          !_clientLaneCameraPreviewAutoRefresh;
    });
    _syncClientLaneCameraPreviewTimer();
  }

  void debugResetQueueStateHintSession() {
    _queueStateHintSeenThisSession = false;
  }

  void debugResetReplayHistoryMemorySession() {
    _replayHistoryMemoryByScopeThisSession =
        <String, _LiveOpsReplayHistoryMemory>{};
  }

  void _markQueueStateHintSeen() {
    _queueStateHintSeenThisSession = true;
    _showQueueStateHint = false;
    widget.onQueueStateHintSeen?.call();
  }

  void _restoreQueueStateHint() {
    _queueStateHintSeenThisSession = false;
    _showQueueStateHint = true;
    widget.onQueueStateHintReset?.call();
  }

  Future<void> _clearLearnedLaneStyle(LiveClientCommsSnapshot snapshot) async {
    final callback = widget.onClearLearnedLaneStyleForScope;
    if (callback == null) {
      return;
    }
    final clientId = snapshot.clientId.trim();
    final siteId = snapshot.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return;
    }
    final key = _scopeBusyKey(clientId, siteId);
    if (_learnedStyleBusyScopeKeys.contains(key)) {
      return;
    }
    setState(() {
      _learnedStyleBusyScopeKeys = <String>{..._learnedStyleBusyScopeKeys, key};
    });
    try {
      await callback(clientId, siteId);
    } finally {
      if (mounted) {
        setState(() {
          _learnedStyleBusyScopeKeys = Set<String>.from(
            _learnedStyleBusyScopeKeys,
          )..remove(key);
        });
      }
    }
  }

  Future<void> _setLaneVoiceProfile(
    LiveClientCommsSnapshot snapshot,
    String? profileSignal,
  ) async {
    final callback = widget.onSetLaneVoiceProfileForScope;
    if (callback == null) {
      return;
    }
    final clientId = snapshot.clientId.trim();
    final siteId = snapshot.siteId.trim();
    if (clientId.isEmpty || siteId.isEmpty) {
      return;
    }
    final key = _scopeBusyKey(clientId, siteId);
    if (_laneVoiceBusyScopeKeys.contains(key)) {
      return;
    }
    setState(() {
      _laneVoiceBusyScopeKeys = <String>{..._laneVoiceBusyScopeKeys, key};
    });
    try {
      await callback(clientId, siteId, profileSignal);
    } finally {
      if (mounted) {
        setState(() {
          _laneVoiceBusyScopeKeys = Set<String>.from(_laneVoiceBusyScopeKeys)
            ..remove(key);
        });
      }
    }
  }

  Future<void> _jumpToControlInboxPanel() async {
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final priorityDraftCount = controlInboxSnapshot == null
        ? 0
        : _controlInboxPriorityDraftCount(
            _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts),
          );
    if (priorityDraftCount > 0 &&
        (!_controlInboxPriorityOnly || _controlInboxCueOnlyKind != null) &&
        mounted) {
      setState(() {
        _controlInboxPriorityOnly = true;
        _controlInboxCueOnlyKind = null;
      });
      await Future<void>.delayed(Duration.zero);
    }
    await _ensureControlInboxPanelVisible();
  }

  Future<void> _cycleControlInboxTopBarCueFilter() async {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null &&
        _isControlInboxPriorityCueKind(filteredCueKind) &&
        mounted) {
      setState(() {
        _controlInboxPriorityOnly = true;
        _controlInboxCueOnlyKind = null;
      });
      await Future<void>.delayed(Duration.zero);
    }
    await _ensureControlInboxPanelVisible();
  }

  Future<void> _toggleTopBarPriorityFilter() async {
    if (_controlInboxPriorityOnly &&
        _controlInboxCueOnlyKind == null &&
        mounted) {
      setState(() {
        _controlInboxPriorityOnly = false;
      });
      await Future<void>.delayed(Duration.zero);
      await _ensureControlInboxPanelVisible();
      return;
    }
    await _jumpToControlInboxPanel();
  }

  Future<void> _cycleControlInboxQueueStateChip() async {
    if (_controlInboxCueOnlyKind != null) {
      if (mounted) {
        setState(() {
          _markQueueStateHintSeen();
        });
      }
      await _cycleControlInboxTopBarCueFilter();
      return;
    }
    if (_controlInboxPriorityOnly && mounted) {
      setState(() {
        _controlInboxPriorityOnly = false;
        _markQueueStateHintSeen();
      });
      await Future<void>.delayed(Duration.zero);
      await _ensureControlInboxPanelVisible();
      return;
    }
    if (mounted) {
      setState(() {
        _markQueueStateHintSeen();
      });
    }
    await _jumpToControlInboxPanel();
  }

  void _dismissQueueStateHint() {
    if (!_showQueueStateHint) {
      return;
    }
    setState(() {
      _markQueueStateHintSeen();
    });
  }

  Future<void> _ensureControlInboxPanelVisible() async {
    final panelContext = _controlInboxPanelGlobalKey.currentContext;
    if (panelContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      panelContext,
      alignment: 0.04,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _ensureActionLadderPanelVisible() async {
    final panelContext = _actionLadderPanelGlobalKey.currentContext;
    if (panelContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      panelContext,
      alignment: 0.08,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _ensureContextAndVigilancePanelVisible() async {
    final panelContext = _contextAndVigilancePanelGlobalKey.currentContext;
    if (panelContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      panelContext,
      alignment: 0.06,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openPendingActionsRecovery() async {
    if (_incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    if (mounted) {
      setState(() {
        _activeTab = _ContextTab.details;
        _controlInboxPriorityOnly = false;
        _controlInboxCueOnlyKind = null;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureActionLadderPanelVisible();
    _showLiveOpsFeedback(
      'Pending actions recovery opened.',
      label: 'PENDING ACTIONS',
      detail:
          'Live Ops kept the action ladder centered and reset queue-only filters while the control inbox snapshot reconnects.',
      accent: const Color(0xFFF59E0B),
    );
  }

  Future<void> _openClientLaneRecovery(
    LiveClientCommsSnapshot? snapshot,
  ) async {
    _IncidentRecord? linkedIncident;
    if (snapshot != null) {
      final clientId = snapshot.clientId.trim();
      final siteId = snapshot.siteId.trim();
      for (final incident in _incidents) {
        if (incident.clientId.trim() == clientId &&
            incident.siteId.trim() == siteId) {
          linkedIncident = incident;
          break;
        }
      }
    }
    if (linkedIncident != null) {
      _focusIncidentFromBanner(linkedIncident);
    } else if (_incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    if (mounted) {
      setState(() {
        _activeTab = _ContextTab.voip;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureContextAndVigilancePanelVisible();
    _showLiveOpsFeedback(
      snapshot == null
          ? 'Client Comms fallback opened in place.'
          : 'Client Comms fallback opened in place.',
      label: 'ACTIVE LANES',
      detail: snapshot == null
          ? 'Live Ops kept the selected incident and VoIP readiness visible while the Client Comms watch reconnects.'
          : 'The separate Client Comms handoff was unavailable, so the scoped comms posture stayed active in the current workspace.',
      accent: const Color(0xFF22D3EE),
    );
  }

  void _toggleControlInboxPriorityOnly() {
    setState(() {
      _controlInboxPriorityOnly = !_controlInboxPriorityOnly;
      _controlInboxCueOnlyKind = null;
    });
  }

  void _clearControlInboxPriorityOnly() {
    if (!_controlInboxPriorityOnly && _controlInboxCueOnlyKind == null) {
      return;
    }
    setState(() {
      _controlInboxPriorityOnly = false;
      _controlInboxCueOnlyKind = null;
    });
  }

  void _toggleControlInboxCueOnlyKind(_ControlInboxDraftCueKind kind) {
    setState(() {
      if (_controlInboxCueOnlyKind == kind) {
        _controlInboxCueOnlyKind = null;
      } else {
        _controlInboxCueOnlyKind = kind;
        _controlInboxPriorityOnly = false;
      }
    });
  }

  bool _laneVoiceOptionSelected(
    LiveClientCommsSnapshot snapshot,
    String? signal,
  ) {
    return _laneVoiceOptionSelectedForLabel(
      snapshot.clientVoiceProfileLabel,
      signal,
    );
  }

  bool _laneVoiceOptionSelectedForLabel(String profileLabel, String? signal) {
    final normalizedLabel = profileLabel.trim().toLowerCase();
    return switch (signal) {
      null => normalizedLabel == 'auto',
      'concise-updates' => normalizedLabel == 'concise',
      'reassurance-forward' => normalizedLabel == 'reassuring',
      'validation-heavy' => normalizedLabel == 'validation-heavy',
      _ => false,
    };
  }

  bool _liveClientLaneCueContainsAny(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  _ControlInboxDraftCueKind _liveClientLaneCueKind(
    LiveClientCommsSnapshot snapshot,
  ) {
    final source = (snapshot.latestClientMessage ?? '').trim().toLowerCase();
    final reply =
        ((snapshot.latestPendingDraft ?? '').trim().isNotEmpty
                ? snapshot.latestPendingDraft
                : snapshot.latestOnyxReply)
            .toString()
            .trim()
            .toLowerCase();
    final learnedSignals =
        '${snapshot.clientVoiceProfileLabel.trim().toLowerCase()}\n${snapshot.learnedApprovalStyleExample.trim().toLowerCase()}';
    if (source.contains('eta') || source.contains('arrival')) {
      return _ControlInboxDraftCueKind.timing;
    }
    if (source.contains('panic') ||
        source.contains('armed') ||
        source.contains('medical') ||
        source.contains('fire')) {
      return _ControlInboxDraftCueKind.sensitive;
    }
    if (reply.contains('?')) {
      return _ControlInboxDraftCueKind.detail;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'camera',
      'daylight',
      'visual',
      'camera check',
      'validation',
    ])) {
      return _ControlInboxDraftCueKind.validation;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'reassuring',
      'reassurance',
      'comfort',
      'you are not alone',
      'treating this as live',
      'stay close',
      'protective',
    ])) {
      return _ControlInboxDraftCueKind.reassurance;
    }
    if (_liveClientLaneCueContainsAny(learnedSignals, const [
      'operations formal',
      'actively checking',
      'operations',
      'formal',
      'close review',
      'monitoring',
    ])) {
      return _ControlInboxDraftCueKind.formal;
    }
    return _ControlInboxDraftCueKind.defaultReassurance;
  }

  String _liveClientLaneCueMessage(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing =>
        'Check that timing is not over-promised before sending.',
      _ControlInboxDraftCueKind.sensitive =>
        'High-sensitivity message. Keep the tone calm and do not imply resolution unless control confirmed it.',
      _ControlInboxDraftCueKind.detail =>
        'The reply asks for one missing detail, which is good when the scope is unclear.',
      _ControlInboxDraftCueKind.validation =>
        'Keep the camera wording concrete and make sure the exact check is clear before sending.',
      _ControlInboxDraftCueKind.reassurance =>
        'Lead with calm reassurance first, then the next confirmed step.',
      _ControlInboxDraftCueKind.formal =>
        'Keep the wording composed and operations-grade without slipping into robotic language.',
      _ControlInboxDraftCueKind.concise =>
        'Keep the reply short and make the next confirmed step clear.',
      _ControlInboxDraftCueKind.defaultReassurance =>
        'This draft is shaped for reassurance first, then the next confirmed step.',
    };
  }

  String _liveClientLaneCue(LiveClientCommsSnapshot snapshot) {
    return _liveClientLaneCueMessage(_liveClientLaneCueKind(snapshot));
  }

  _ControlInboxDraftCueKind _controlInboxDraftCueKindForSignals({
    required String sourceText,
    required String replyText,
    required String clientVoiceProfileLabel,
    required bool usesLearnedApprovalStyle,
  }) {
    final source = sourceText.trim().toLowerCase();
    final reply = replyText.trim().toLowerCase();
    final signals =
        '${clientVoiceProfileLabel.trim().toLowerCase()}\n$reply${usesLearnedApprovalStyle ? '\nlearned approval style' : ''}';
    if (source.contains('eta') ||
        source.contains('arrival') ||
        source.contains('arrived') ||
        source.contains('how long') ||
        reply.contains('eta') ||
        reply.contains('arrival') ||
        reply.contains('arrived')) {
      return _ControlInboxDraftCueKind.timing;
    }
    if (source.contains('panic') ||
        source.contains('armed') ||
        source.contains('medical') ||
        source.contains('fire')) {
      return _ControlInboxDraftCueKind.sensitive;
    }
    if (reply.contains('?')) {
      return _ControlInboxDraftCueKind.detail;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'validation-heavy',
      'camera',
      'daylight',
      'visual',
      'validation',
      'verified position',
      'confirmed position',
    ])) {
      return _ControlInboxDraftCueKind.validation;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'reassuring',
      'reassurance',
      'comfort',
      'you are not alone',
      'treating this as live',
      'stay close',
      'protective',
    ])) {
      return _ControlInboxDraftCueKind.reassurance;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'operations formal',
      'actively checking',
      'operations',
      'formal',
      'close review',
      'monitoring',
    ])) {
      return _ControlInboxDraftCueKind.formal;
    }
    if (_liveClientLaneCueContainsAny(signals, const [
      'concise',
      'concise-updates',
      'short',
      'brief',
    ])) {
      return _ControlInboxDraftCueKind.concise;
    }
    return _ControlInboxDraftCueKind.defaultReassurance;
  }

  String _controlInboxDraftCueMessage(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing =>
        'Check that timing is not over-promised before sending.',
      _ControlInboxDraftCueKind.sensitive =>
        'High-sensitivity message. Keep the tone calm and do not imply resolution unless control confirmed it.',
      _ControlInboxDraftCueKind.detail =>
        'The reply asks for one missing detail, which is good when the scope is unclear.',
      _ControlInboxDraftCueKind.validation =>
        'Keep the exact check concrete and make sure the next confirmed step is clear before sending.',
      _ControlInboxDraftCueKind.reassurance =>
        'Lead with calm reassurance first, then the next confirmed step.',
      _ControlInboxDraftCueKind.formal =>
        'Keep the wording composed and operations-grade without slipping into robotic language.',
      _ControlInboxDraftCueKind.concise =>
        'Keep the reply short and make the next confirmed step clear.',
      _ControlInboxDraftCueKind.defaultReassurance =>
        'This draft is shaped for reassurance first, then the next confirmed step.',
    };
  }

  String _controlInboxDraftCueForSignals({
    required String sourceText,
    required String replyText,
    required String clientVoiceProfileLabel,
    required bool usesLearnedApprovalStyle,
  }) {
    return _controlInboxDraftCueMessage(
      _controlInboxDraftCueKindForSignals(
        sourceText: sourceText,
        replyText: replyText,
        clientVoiceProfileLabel: clientVoiceProfileLabel,
        usesLearnedApprovalStyle: usesLearnedApprovalStyle,
      ),
    );
  }

  String _controlInboxDraftCueChipLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => 'Cue Timing',
      _ControlInboxDraftCueKind.sensitive => 'Cue Sensitive',
      _ControlInboxDraftCueKind.detail => 'Cue Detail',
      _ControlInboxDraftCueKind.validation => 'Cue Validation',
      _ControlInboxDraftCueKind.reassurance => 'Cue Reassurance',
      _ControlInboxDraftCueKind.formal => 'Cue Formal',
      _ControlInboxDraftCueKind.concise => 'Cue Concise',
      _ControlInboxDraftCueKind.defaultReassurance => 'Cue Next Step',
    };
  }

  IconData _controlInboxDraftCueChipIcon(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => Icons.schedule_rounded,
      _ControlInboxDraftCueKind.sensitive => Icons.warning_amber_rounded,
      _ControlInboxDraftCueKind.detail => Icons.help_outline_rounded,
      _ControlInboxDraftCueKind.validation => Icons.visibility_rounded,
      _ControlInboxDraftCueKind.reassurance => Icons.favorite_border_rounded,
      _ControlInboxDraftCueKind.formal => Icons.business_center_rounded,
      _ControlInboxDraftCueKind.concise => Icons.short_text_rounded,
      _ControlInboxDraftCueKind.defaultReassurance => Icons.flag_outlined,
    };
  }

  Color _controlInboxDraftCueChipAccent(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.timing => const Color(0xFFF59E0B),
      _ControlInboxDraftCueKind.sensitive => const Color(0xFFEF4444),
      _ControlInboxDraftCueKind.detail => const Color(0xFF60A5FA),
      _ControlInboxDraftCueKind.validation => const Color(0xFF22D3EE),
      _ControlInboxDraftCueKind.reassurance => const Color(0xFF34D399),
      _ControlInboxDraftCueKind.formal => const Color(0xFF4B6B8F),
      _ControlInboxDraftCueKind.concise => const Color(0xFF8B5CF6),
      _ControlInboxDraftCueKind.defaultReassurance => const Color(0xFF9AB1CF),
    };
  }

  int _controlInboxDraftCuePriority(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 0,
      _ControlInboxDraftCueKind.timing => 1,
      _ControlInboxDraftCueKind.detail => 2,
      _ControlInboxDraftCueKind.validation => 3,
      _ControlInboxDraftCueKind.formal => 4,
      _ControlInboxDraftCueKind.reassurance => 5,
      _ControlInboxDraftCueKind.concise => 6,
      _ControlInboxDraftCueKind.defaultReassurance => 7,
    };
  }

  List<LiveControlInboxDraft> _sortedControlInboxDrafts(
    List<LiveControlInboxDraft> drafts,
  ) {
    final sorted = List<LiveControlInboxDraft>.from(drafts);
    sorted.sort((a, b) {
      final cueCompare =
          _controlInboxDraftCuePriority(
            _controlInboxDraftCueKindForSignals(
              sourceText: a.sourceText,
              replyText: a.draftText,
              clientVoiceProfileLabel: a.clientVoiceProfileLabel,
              usesLearnedApprovalStyle: a.usesLearnedApprovalStyle,
            ),
          ).compareTo(
            _controlInboxDraftCuePriority(
              _controlInboxDraftCueKindForSignals(
                sourceText: b.sourceText,
                replyText: b.draftText,
                clientVoiceProfileLabel: b.clientVoiceProfileLabel,
                usesLearnedApprovalStyle: b.usesLearnedApprovalStyle,
              ),
            ),
          );
      if (cueCompare != 0) {
        return cueCompare;
      }
      if (a.matchesSelectedScope != b.matchesSelectedScope) {
        return a.matchesSelectedScope ? -1 : 1;
      }
      return b.createdAtUtc.compareTo(a.createdAtUtc);
    });
    return sorted;
  }

  String _controlInboxCueSummaryLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 'sensitive',
      _ControlInboxDraftCueKind.timing => 'timing',
      _ControlInboxDraftCueKind.detail => 'detail',
      _ControlInboxDraftCueKind.validation => 'validation',
      _ControlInboxDraftCueKind.reassurance => 'reassurance',
      _ControlInboxDraftCueKind.formal => 'formal',
      _ControlInboxDraftCueKind.concise => 'concise',
      _ControlInboxDraftCueKind.defaultReassurance => 'next step',
    };
  }

  String _controlInboxTopBarFilterLabel(_ControlInboxDraftCueKind kind) {
    return switch (kind) {
      _ControlInboxDraftCueKind.sensitive => 'Sensitive only',
      _ControlInboxDraftCueKind.timing => 'Timing only',
      _ControlInboxDraftCueKind.detail => 'Detail only',
      _ControlInboxDraftCueKind.validation => 'Validation only',
      _ControlInboxDraftCueKind.reassurance => 'Reassurance only',
      _ControlInboxDraftCueKind.formal => 'Formal only',
      _ControlInboxDraftCueKind.concise => 'Concise only',
      _ControlInboxDraftCueKind.defaultReassurance => 'Next step only',
    };
  }

  String _controlInboxTopBarQueueStateLabel() {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return 'Queue ${_controlInboxTopBarFilterLabel(filteredCueKind)}';
    }
    if (_controlInboxPriorityOnly) {
      return 'Queue High priority';
    }
    return 'Queue Full';
  }

  Color _controlInboxTopBarQueueStateForeground(
    bool hasSensitivePriorityDraft,
  ) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(filteredCueKind);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0xFFEF4444)
          : const Color(0xFFF59E0B);
    }
    return const Color(0xFF9AB1CF);
  }

  Color _controlInboxTopBarQueueStateBackground(
    bool hasSensitivePriorityDraft,
  ) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(
        filteredCueKind,
      ).withValues(alpha: 0.2);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0x33EF4444)
          : const Color(0x33F59E0B);
    }
    return const Color(0x334B6B8F);
  }

  Color _controlInboxTopBarQueueStateBorder(bool hasSensitivePriorityDraft) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipAccent(
        filteredCueKind,
      ).withValues(alpha: 0.45);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? const Color(0x66EF4444)
          : const Color(0x66F59E0B);
    }
    return const Color(0x664B6B8F);
  }

  IconData _controlInboxTopBarQueueStateIcon(bool hasSensitivePriorityDraft) {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return _controlInboxDraftCueChipIcon(filteredCueKind);
    }
    if (_controlInboxPriorityOnly) {
      return hasSensitivePriorityDraft
          ? Icons.warning_amber_rounded
          : Icons.priority_high_rounded;
    }
    return Icons.inbox_rounded;
  }

  String _controlInboxQueueStateTooltip() {
    final filteredCueKind = _controlInboxCueOnlyKind;
    if (filteredCueKind != null) {
      return '${_controlInboxTopBarQueueStateLabel()} is showing only ${_controlInboxCueSummaryLabel(filteredCueKind)} replies. Tap to widen back to the high-priority queue.';
    }
    if (_controlInboxPriorityOnly) {
      return 'Queue High priority is showing only sensitive and timing replies. Tap to return to the full queue.';
    }
    return 'Queue Full is showing every pending reply. Tap to narrow the inbox to the high-priority queue.';
  }

  List<(_ControlInboxDraftCueKind, int)> _controlInboxCueSummaryItems(
    List<LiveControlInboxDraft> drafts,
  ) {
    final counts = <_ControlInboxDraftCueKind, int>{};
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return const <(_ControlInboxDraftCueKind, int)>[];
    }
    final orderedKinds = counts.keys.toList()
      ..sort(
        (a, b) => _controlInboxDraftCuePriority(
          a,
        ).compareTo(_controlInboxDraftCuePriority(b)),
      );
    return orderedKinds
        .map((kind) => (kind, counts[kind] ?? 0))
        .toList(growable: false);
  }

  String _controlInboxCueSummaryText(List<LiveControlInboxDraft> drafts) {
    final items = _controlInboxCueSummaryItems(drafts);
    if (items.isEmpty) {
      return '';
    }
    final parts = items
        .map((item) => '${item.$2} ${_controlInboxCueSummaryLabel(item.$1)}')
        .toList(growable: false);
    return 'Queue shape: ${parts.join(' • ')}';
  }

  bool _isControlInboxPriorityCueKind(_ControlInboxDraftCueKind kind) {
    return kind == _ControlInboxDraftCueKind.sensitive ||
        kind == _ControlInboxDraftCueKind.timing;
  }

  int _controlInboxPriorityDraftCount(List<LiveControlInboxDraft> drafts) {
    var count = 0;
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (_isControlInboxPriorityCueKind(kind)) {
        count += 1;
      }
    }
    return count;
  }

  int _controlInboxCueKindCount(
    List<LiveControlInboxDraft> drafts,
    _ControlInboxDraftCueKind kind,
  ) {
    var count = 0;
    for (final draft in drafts) {
      final draftKind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (draftKind == kind) {
        count += 1;
      }
    }
    return count;
  }

  bool _controlInboxHasSensitivePriorityDraft(
    List<LiveControlInboxDraft> drafts,
  ) {
    for (final draft in drafts) {
      final kind = _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      );
      if (kind == _ControlInboxDraftCueKind.sensitive) {
        return true;
      }
    }
    return false;
  }

  String _controlInboxDraftCue(LiveControlInboxDraft draft) {
    return _controlInboxDraftCueMessage(
      _controlInboxDraftCueKindForSignals(
        sourceText: draft.sourceText,
        replyText: draft.draftText,
        clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
        usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _applyRememberedReplayHistoryMemory();
    if (widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = true;
    }
    _showQueueStateHint = !_queueStateHintSeenThisSession;
    _projectFromEvents();
    _ingestAgentReturnIncidentReference(fromInit: true);
    _syncClientLaneCameraPreviewTimer();
    unawaited(_loadClientLaneCameraHealth());
    final latestAutoAuditReceipt = widget.latestAutoAuditReceipt;
    if (latestAutoAuditReceipt != null &&
        (widget.agentReturnIncidentReference?.trim().isEmpty ?? true)) {
      _commandReceipt = _liveOpsCommandReceiptFromAutoAudit(
        latestAutoAuditReceipt,
      );
    }
    unawaited(_loadReplayHistorySignals());
  }

  @override
  void dispose() {
    _clientLaneCameraPreviewTimer?.cancel();
    _commandPromptController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveOperationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final replayHistoryMemoryScopeChanged =
        _liveOpsReplayHistoryMemoryScopeKey(
          clientId: oldWidget.initialScopeClientId,
          siteId: oldWidget.initialScopeSiteId,
          focusIncidentReference: oldWidget.focusIncidentReference,
        ) !=
        _liveOpsReplayHistoryMemoryScopeKey(
          clientId: widget.initialScopeClientId,
          siteId: widget.initialScopeSiteId,
          focusIncidentReference: widget.focusIncidentReference,
        );
    if (!oldWidget.queueStateHintSeen && widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = true;
      _showQueueStateHint = false;
    } else if (oldWidget.queueStateHintSeen && !widget.queueStateHintSeen) {
      _queueStateHintSeenThisSession = false;
      _showQueueStateHint = true;
    }
    if (_projectedEventInputsChanged(oldWidget.events, widget.events) ||
        oldWidget.sceneReviewByIntelligenceId !=
            widget.sceneReviewByIntelligenceId ||
        oldWidget.initialScopeClientId?.trim() !=
            widget.initialScopeClientId?.trim() ||
        oldWidget.initialScopeSiteId?.trim() !=
            widget.initialScopeSiteId?.trim() ||
        oldWidget.focusIncidentReference.trim() !=
            widget.focusIncidentReference.trim()) {
      _projectFromEvents();
    }
    if (replayHistoryMemoryScopeChanged) {
      setState(() {
        _applyRememberedReplayHistoryMemory(clearLiveReplayHistory: true);
      });
      unawaited(_loadReplayHistorySignals());
    }
    if (oldWidget.agentReturnIncidentReference?.trim() !=
        widget.agentReturnIncidentReference?.trim()) {
      _ingestAgentReturnIncidentReference();
    }
    if (oldWidget.latestAutoAuditReceipt?.auditId !=
            widget.latestAutoAuditReceipt?.auditId &&
        widget.latestAutoAuditReceipt != null &&
        (widget.agentReturnIncidentReference?.trim().isEmpty ?? true)) {
      setState(() {
        _commandReceipt = _liveOpsCommandReceiptFromAutoAudit(
          widget.latestAutoAuditReceipt!,
        );
      });
    }
    if (oldWidget.scenarioReplayHistorySignalService !=
        widget.scenarioReplayHistorySignalService) {
      unawaited(_loadReplayHistorySignals());
    }
    if (oldWidget.clientCommsSnapshot?.clientId.trim() !=
            widget.clientCommsSnapshot?.clientId.trim() ||
        oldWidget.clientCommsSnapshot?.siteId.trim() !=
            widget.clientCommsSnapshot?.siteId.trim() ||
        oldWidget.onLoadCameraHealthFactPacketForScope !=
            widget.onLoadCameraHealthFactPacketForScope) {
      _syncClientLaneCameraPreviewTimer();
    }
    if (oldWidget.clientCommsSnapshot?.clientId.trim() !=
            widget.clientCommsSnapshot?.clientId.trim() ||
        oldWidget.clientCommsSnapshot?.siteId.trim() !=
            widget.clientCommsSnapshot?.siteId.trim() ||
        oldWidget.onLoadCameraHealthFactPacketForScope !=
            widget.onLoadCameraHealthFactPacketForScope) {
      unawaited(_loadClientLaneCameraHealth());
    }
  }

  bool _projectedEventInputsChanged(
    List<DispatchEvent> previous,
    List<DispatchEvent> next,
  ) {
    if (identical(previous, next)) {
      return false;
    }
    if (previous.length != next.length) {
      return true;
    }
    for (var index = 0; index < previous.length; index += 1) {
      final oldEvent = previous[index];
      final newEvent = next[index];
      if (oldEvent.runtimeType != newEvent.runtimeType ||
          oldEvent.eventId != newEvent.eventId ||
          oldEvent.sequence != newEvent.sequence ||
          oldEvent.version != newEvent.version ||
          oldEvent.occurredAt != newEvent.occurredAt) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadReplayHistorySignals() async {
    try {
      final stack = await widget.scenarioReplayHistorySignalService
          .loadSignalStack(limit: 3);
      final replayHistorySummary =
          summarizeReplayHistorySignalStack(stack) ?? '';
      _rememberReplayHistorySummary(replayHistorySummary);
      if (!mounted) {
        return;
      }
      setState(() {
        _replayHistorySignalStack = stack;
        _replayHistorySignal = stack.isEmpty ? null : stack.first;
        _rememberedReplayHistorySummary = replayHistorySummary.trim();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _replayHistorySignalStack = const <ScenarioReplayHistorySignal>[];
        _replayHistorySignal = null;
        _rememberedReplayHistorySummary = _rememberedReplayHistoryMemory()
            .commandContinuityView()
            .replayHistorySummary
            .trim();
      });
    }
  }

  String _replayHistoryMemoryScopeKey() => _liveOpsReplayHistoryMemoryScopeKey(
    clientId: widget.initialScopeClientId,
    siteId: widget.initialScopeSiteId,
    focusIncidentReference: widget.focusIncidentReference,
  );

  _LiveOpsReplayHistoryMemory _rememberedReplayHistoryMemory() =>
      _replayHistoryMemoryByScopeThisSession[_replayHistoryMemoryScopeKey()] ??
      const _LiveOpsReplayHistoryMemory();

  void _storeReplayHistoryMemory(_LiveOpsReplayHistoryMemory memory) {
    final key = _replayHistoryMemoryScopeKey();
    if (memory.hasData) {
      _replayHistoryMemoryByScopeThisSession =
          <String, _LiveOpsReplayHistoryMemory>{
            ..._replayHistoryMemoryByScopeThisSession,
            key: memory,
          };
      return;
    }
    if (!_replayHistoryMemoryByScopeThisSession.containsKey(key)) {
      return;
    }
    final next = Map<String, _LiveOpsReplayHistoryMemory>.from(
      _replayHistoryMemoryByScopeThisSession,
    )..remove(key);
    _replayHistoryMemoryByScopeThisSession = next;
  }

  void _applyRememberedReplayHistoryMemory({
    bool clearLiveReplayHistory = false,
  }) {
    final rememberedReplayHistoryMemory = _rememberedReplayHistoryMemory();
    final rememberedCommandContinuity = rememberedReplayHistoryMemory
        .commandContinuityView();
    _rememberedReplayHistorySummary = rememberedCommandContinuity
        .replayHistorySummary
        .trim();
    _lastPlainLanguageCommand = '';
    _lastPlainLanguagePreview = rememberedCommandContinuity.hasPreview
        ? rememberedCommandContinuity.commandPreview
        : null;
    if (clearLiveReplayHistory) {
      _replayHistorySignalStack = const <ScenarioReplayHistorySignal>[];
      _replayHistorySignal = null;
    }
    if (widget.agentReturnIncidentReference?.trim().isNotEmpty == true) {
      _commandReceipt = _defaultCommandReceipt;
      return;
    }
    if (widget.latestAutoAuditReceipt case final receipt?) {
      _commandReceipt = _liveOpsCommandReceiptFromAutoAudit(receipt);
      return;
    }
    _commandReceipt =
        _liveOpsCommandReceiptFromContinuityView(rememberedCommandContinuity) ??
        _defaultCommandReceipt;
  }

  void _rememberReplayHistorySummary(String summary) {
    final rememberedReplayHistoryMemory = _rememberedReplayHistoryMemory();
    _storeReplayHistoryMemory(
      rememberedReplayHistoryMemory.copyWith(
        commandSurfaceMemory:
            OnyxCommandSurfaceMemoryAdapter.rememberReplayHistorySummary(
              rememberedReplayHistoryMemory.commandSurfaceMemory,
              summary,
            ),
      ),
    );
  }

  void _rememberCommandPreview(OnyxCommandSurfacePreview? preview) {
    final rememberedReplayHistoryMemory = _rememberedReplayHistoryMemory();
    _storeReplayHistoryMemory(
      rememberedReplayHistoryMemory.copyWith(
        commandSurfaceMemory:
            OnyxCommandSurfaceMemoryAdapter.rememberCommandPreview(
              rememberedReplayHistoryMemory.commandSurfaceMemory,
              preview,
            ),
      ),
    );
  }

  void _setPlainLanguagePreview(
    String prompt,
    OnyxCommandSurfacePreview preview, {
    VoidCallback? extraState,
  }) {
    _rememberCommandPreview(preview);
    setState(() {
      _lastPlainLanguageCommand = prompt;
      _lastPlainLanguagePreview = preview;
      _commandPromptController.clear();
      extraState?.call();
    });
  }

  void _rememberReplayBackedCommandReceipt(_LiveOpsCommandReceipt receipt) {
    final continuityView = receipt.continuityView;
    final commandReceipt = continuityView.commandReceipt;
    if (continuityView.commandBrainSnapshot == null ||
        commandReceipt?.hasData != true) {
      return;
    }
    final rememberedReplayHistoryMemory = _rememberedReplayHistoryMemory();
    _storeReplayHistoryMemory(
      rememberedReplayHistoryMemory.copyWith(
        commandSurfaceMemory:
            OnyxCommandSurfaceMemoryAdapter.rememberCommandReceipt(
              rememberedReplayHistoryMemory.commandSurfaceMemory,
              commandReceipt,
              replaceCommandBrainSnapshot: true,
              commandBrainSnapshot: continuityView.commandBrainSnapshot,
              commandOutcome: continuityView.commandOutcome,
            ),
      ),
    );
  }

  String? _commandReplayHistoryLine() {
    final liveReplayHistorySummary = summarizeReplayHistorySignalStack(
      _replayHistorySignalStack,
    );
    if (liveReplayHistorySummary != null &&
        liveReplayHistorySummary.trim().isNotEmpty) {
      return liveReplayHistorySummary;
    }
    final rememberedReplayHistorySummary = _rememberedReplayHistorySummary
        .trim();
    if (rememberedReplayHistorySummary.isEmpty) {
      return null;
    }
    return rememberedReplayHistorySummary;
  }

  String? _commandMemoryReplayContextLine() {
    final continuityView = _commandReceipt.continuityView;
    if (continuityView.replayContextLine case final line?) {
      return line;
    }
    final snapshot =
        continuityView.commandBrainSnapshot ??
        _lastPlainLanguagePreview?.commandBrainSnapshot;
    if (snapshot == null) {
      return null;
    }
    return OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
      snapshot,
      rememberedReplayHistorySummary: _replayHistorySignalStack.isEmpty
          ? _rememberedReplayHistorySummary.trim()
          : '',
      preferRememberedContinuity: _replayHistorySignalStack.isEmpty,
    ).replayContextLine;
  }

  String? _commandReceiptReplayContextLine() {
    return _commandReceipt.continuityView.replayContextLine;
  }

  _LiveOpsCommandReceipt? _liveOpsCommandReceiptFromContinuityView(
    OnyxCommandSurfaceContinuityView continuityView,
  ) {
    if (!continuityView.hasReceipt) {
      return null;
    }
    final target = continuityView.target;
    return _LiveOpsCommandReceipt(
      accent: target == null
          ? const Color(0xFF8FD1FF)
          : _commandRecommendationAccent(target),
      continuityView: continuityView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty;
    final activeIncident = _activeIncident;
    final clientCommsSnapshot = widget.clientCommsSnapshot;
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final ledger = [..._manualLedger, ..._projectedLedger]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final handsetLayout = isHandsetLayout(context);
    final viewportSize = MediaQuery.sizeOf(context);
    final viewportWidth = viewportSize.width;
    final wide = allowEmbeddedPanelScroll(context);
    final showPageTopBar = viewportWidth < 980 || handsetLayout;
    final showCommandReceiptBanner =
        _hasAgentReturnReceipt || _hasAutoAuditReceipt;

    return OnyxPageScaffold(
      child: Column(
        children: [
          if (showPageTopBar) _topBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, bodyConstraints) {
                  final canUseEmbeddedDesktopLayout =
                      _showDetailedWorkspace &&
                      wide &&
                      bodyConstraints.maxWidth >= 2200 &&
                      bodyConstraints.maxHeight >= 1120;
                  final autoShowDetailedWorkspace = handsetLayout;
                  final showDetailedWorkspace =
                      autoShowDetailedWorkspace || _showDetailedWorkspace;
                  final surfaceMaxWidth = canUseEmbeddedDesktopLayout
                      ? (bodyConstraints.maxWidth > 1880
                            ? 1880.0
                            : bodyConstraints.maxWidth)
                      : (bodyConstraints.maxWidth > 1460
                            ? 1460.0
                            : bodyConstraints.maxWidth);
                  _desktopWorkspaceActive = canUseEmbeddedDesktopLayout;
                  return OnyxCommandSurface(
                    compactDesktopWidth: surfaceMaxWidth,
                    viewportWidth: bodyConstraints.maxWidth,
                    child: canUseEmbeddedDesktopLayout
                        ? Column(
                            children: [
                              _commandWorkspaceToggle(
                                showDetailedWorkspace: true,
                                canCollapse: true,
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: _desktopWorkspaceShell(
                                  hasScopeFocus: hasScopeFocus,
                                  scopeClientId: scopeClientId,
                                  scopeSiteId: scopeSiteId,
                                  activeIncident: activeIncident,
                                  clientCommsSnapshot: clientCommsSnapshot,
                                  controlInboxSnapshot: controlInboxSnapshot,
                                  ledger: ledger,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                if (_criticalAlertIncident != null &&
                                    showDetailedWorkspace) ...[
                                  _criticalAlertBanner(_criticalAlertIncident!),
                                  const SizedBox(height: 20),
                                ],
                                _commandCenterHero(
                                  activeIncident: activeIncident,
                                  clientCommsSnapshot: clientCommsSnapshot,
                                  controlInboxSnapshot: controlInboxSnapshot,
                                  ledger: ledger,
                                ),
                                if (showCommandReceiptBanner) ...[
                                  const SizedBox(height: 20),
                                  _liveOpsCommandReceiptCard(),
                                ],
                                if (!canUseEmbeddedDesktopLayout &&
                                    !autoShowDetailedWorkspace) ...[
                                  const SizedBox(height: 20),
                                  _commandWorkspaceToggle(
                                    showDetailedWorkspace:
                                        showDetailedWorkspace,
                                    canCollapse: !autoShowDetailedWorkspace,
                                  ),
                                ],
                                if (!showDetailedWorkspace) ...[
                                  const SizedBox(height: 20),
                                  _commandOverviewDeck(
                                    activeIncident: activeIncident,
                                    clientCommsSnapshot: clientCommsSnapshot,
                                    controlInboxSnapshot: controlInboxSnapshot,
                                    ledger: ledger,
                                  ),
                                ],
                                if (showDetailedWorkspace) ...[
                                  const SizedBox(height: 20),
                                  if (hasScopeFocus) ...[
                                    _scopeFocusBanner(
                                      clientId: scopeClientId,
                                      siteId: scopeSiteId,
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (controlInboxSnapshot != null ||
                                      ledger.isNotEmpty) ...[
                                    _operationsDecisionDeck(
                                      controlInboxSnapshot:
                                          controlInboxSnapshot,
                                      activeIncident: activeIncident,
                                      ledger: ledger,
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  if (clientCommsSnapshot != null) ...[
                                    _clientLaneWatchPanel(
                                      clientCommsSnapshot,
                                      activeIncident,
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                  _incidentQueuePanel(embeddedScroll: false),
                                  const SizedBox(height: 20),
                                  _actionLadderPanel(
                                    activeIncident,
                                    embeddedScroll: false,
                                  ),
                                  const SizedBox(height: 20),
                                  _contextAndVigilancePanel(
                                    activeIncident,
                                    embeddedScroll: false,
                                  ),
                                ],
                              ],
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopWorkspaceShell({
    required bool hasScopeFocus,
    required String scopeClientId,
    required String scopeSiteId,
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required List<_LedgerEntry> ledger,
  }) {
    final criticalAlertIncident = _criticalAlertIncident;
    final showDecisionDeck = controlInboxSnapshot != null || ledger.isNotEmpty;
    // The embedded workspace already exposes the same command posture through
    // its rail/banner shell. Only show the compact hero when there is ample
    // vertical headroom, otherwise it pushes the interactive panels off-screen.
    final showCompactHero = MediaQuery.sizeOf(context).height >= 1700;
    final workspaceBanner = _workspaceStatusBanner(
      hasScopeFocus: hasScopeFocus,
      scopeClientId: scopeClientId,
      scopeSiteId: scopeSiteId,
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
      controlInboxSnapshot: controlInboxSnapshot,
      criticalAlertIncident: criticalAlertIncident,
      shellless: true,
      summaryOnly: true,
    );
    return Column(
      children: [
        if (showCompactHero) ...[
          _commandCenterHero(
            activeIncident: activeIncident,
            clientCommsSnapshot: clientCommsSnapshot,
            controlInboxSnapshot: controlInboxSnapshot,
            ledger: ledger,
            compact: true,
          ),
          const SizedBox(height: 2.2),
        ],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 22,
                child: _workspaceShellColumn(
                  key: const ValueKey('live-operations-workspace-panel-rail'),
                  title: 'War Room Rail',
                  subtitle:
                      'Incident selection, scope posture, and live command counts stay pinned on the left.',
                  shellless: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      workspaceBanner,
                      const SizedBox(height: 2.2),
                      if (criticalAlertIncident != null) ...[
                        _criticalAlertBanner(criticalAlertIncident),
                        const SizedBox(height: 2.2),
                      ],
                      _commandOverviewGrid(
                        activeIncident: activeIncident,
                        clientCommsSnapshot: clientCommsSnapshot,
                        controlInboxSnapshot: controlInboxSnapshot,
                        gridKey: const ValueKey(
                          'live-operations-command-overview-rail',
                        ),
                      ),
                      const SizedBox(height: 2.2),
                      Expanded(
                        child: _incidentQueuePanel(embeddedScroll: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 1.7),
              Expanded(
                flex: 92,
                child: _workspaceShellColumn(
                  key: const ValueKey('live-operations-workspace-panel-board'),
                  title: 'Active Board',
                  subtitle:
                      'The selected incident, execution ladder, and operator decision queue stay centered.',
                  shellless: true,
                  child: Column(
                    children: [
                      Expanded(
                        flex: showDecisionDeck ? 5 : 1,
                        child: _actionLadderPanel(
                          activeIncident,
                          embeddedScroll: true,
                        ),
                      ),
                      if (showDecisionDeck) ...[
                        const SizedBox(height: 2.2),
                        Expanded(
                          flex: 4,
                          child: _operationsDecisionDeck(
                            controlInboxSnapshot: controlInboxSnapshot,
                            activeIncident: activeIncident,
                            ledger: ledger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 1.7),
              Expanded(
                flex: 22,
                child: _workspaceShellColumn(
                  key: const ValueKey(
                    'live-operations-workspace-panel-context',
                  ),
                  title: 'Context Rail',
                  subtitle:
                      'Context tabs, vigilance, and Client Comms delivery posture stay visible.',
                  shellless: true,
                  child: Column(
                    children: [
                      if (clientCommsSnapshot != null) ...[
                        _clientLaneWatchPanel(
                          clientCommsSnapshot,
                          activeIncident,
                        ),
                        const SizedBox(height: 2.2),
                      ],
                      _liveOpsCommandReceiptCard(),
                      const SizedBox(height: 2.2),
                      Expanded(
                        child: _contextAndVigilancePanel(
                          activeIncident,
                          embeddedScroll: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commandWorkspaceToggle({
    required bool showDetailedWorkspace,
    required bool canCollapse,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        key: const ValueKey('live-operations-toggle-detailed-workspace'),
        onPressed: () {
          setState(() {
            if (showDetailedWorkspace && canCollapse) {
              _showDetailedWorkspace = false;
            } else {
              _showDetailedWorkspace = true;
            }
          });
        },
        icon: Icon(
          showDetailedWorkspace && canCollapse
              ? Icons.visibility_off_rounded
              : Icons.open_in_new_rounded,
          size: 15,
        ),
        label: Text(
          showDetailedWorkspace && canCollapse
              ? 'Hide Detailed Workspace'
              : 'Open Detailed Workspace',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: OnyxDesignTokens.cyanInteractive,
          side: const BorderSide(color: _commandBorderStrongColor),
          backgroundColor: _commandPanelColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _commandCenterHero({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required List<_LedgerEntry> ledger,
    bool compact = false,
  }) {
    final rosterSignalHeadline = (widget.guardRosterSignalHeadline ?? '')
        .trim();
    final rosterSignalVisible = rosterSignalHeadline.isNotEmpty;
    final modules = _commandCenterModules(
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
      controlInboxSnapshot: controlInboxSnapshot,
      ledger: ledger,
    );
    return Container(
      key: const ValueKey('live-operations-command-center-hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _commandBorderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rosterSignalVisible) ...[
                  _guardRosterSignalBanner(compact: true),
                  const SizedBox(height: 8),
                ],
                _commandFullGrid(modules: modules, compact: true),
              ],
            );
          }

          final attentionCount = modules
              .where(
                (m) =>
                    m.accent != OnyxDesignTokens.textMuted &&
                    m.accent != OnyxDesignTokens.greenNominal,
              )
              .fold(0, (sum, m) => sum + (int.tryParse(m.countLabel) ?? 0));
          // Reserve space for header (~56), banner (~44), spacers (~52),
          // optional roster signal (~36), recent activity (~164), container
          // padding (20). Cards fill the remaining viewport height.
          final reservedHeight =
              56 + 44 + 52 + (rosterSignalVisible ? 50 : 0) + 164 + 20;
          final gridTargetHeight =
              (MediaQuery.sizeOf(context).height - reservedHeight).clamp(
                200.0,
                double.infinity,
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnyxPageHeader(
                title: 'Command Center',
                subtitle: 'Operational overview.',
                icon: Icons.dashboard_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              OnyxStatusBanner(
                message: attentionCount > 0
                    ? '$attentionCount items need attention'
                    : 'All clear',
                severity: attentionCount > 0
                    ? OnyxSeverity.warning
                    : OnyxSeverity.success,
              ),
              const SizedBox(height: 14),
              if (rosterSignalVisible) ...[
                _guardRosterSignalBanner(),
                const SizedBox(height: 14),
              ],
              _commandFullGrid(
                modules: modules,
                targetGridHeight: gridTargetHeight,
              ),
              const SizedBox(height: 14),
              _commandRecentActivity(ledger),
            ],
          );
        },
      ),
    );
  }

  Widget _commandOverviewDeck({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required List<_LedgerEntry> ledger,
  }) {
    final modules = _commandCenterModules(
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
      controlInboxSnapshot: controlInboxSnapshot,
      ledger: ledger,
    );
    final decisionItems = _commandDecisionItems(
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
      controlInboxSnapshot: controlInboxSnapshot,
      ledger: ledger,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideDeck = constraints.maxWidth >= 1380;
        final compactPanels = constraints.maxWidth < 1200;
        final focusAndQuickOpen = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _commandCurrentFocusPanel(
              activeIncident: activeIncident,
              clientCommsSnapshot: clientCommsSnapshot,
              streamlined: compactPanels,
            ),
            const SizedBox(height: 8),
            _commandQuickOpenPanel(modules: modules, compact: compactPanels),
          ],
        );
        final queuePanel = _commandDecisionQueuePanel(
          items: decisionItems,
          streamlined: compactPanels,
        );
        final memoryPanel = _commandMemoryPanel(ledger);

        if (!wideDeck) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              focusAndQuickOpen,
              const SizedBox(height: 8),
              queuePanel,
              const SizedBox(height: 8),
              memoryPanel,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 38, child: focusAndQuickOpen),
            const SizedBox(width: 8),
            Expanded(flex: 34, child: queuePanel),
            const SizedBox(width: 8),
            Expanded(flex: 28, child: memoryPanel),
          ],
        );
      },
    );
  }

  // ignore: unused_element
  Widget _commandIntentBar({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    bool compact = false,
  }) {
    final preview = _lastPlainLanguagePreview;
    final rememberedReplayHistorySummary = _replayHistorySignalStack.isEmpty
        ? _rememberedReplayHistorySummary.trim()
        : '';
    final previewStatusLines =
        preview?.commandBrainStatusLines(
          rememberedReplayHistorySummary: rememberedReplayHistorySummary,
        ) ??
        const <String>[];
    final commandHint = preview == null
        ? 'One move only. ONYX will do the next step.'
        : preview.headline;
    final commandDetail =
        preview?.detailLine(
          lastCommand: _lastPlainLanguageCommand,
          emptyDetail:
              'Try: "review cctv", "check guard route", "draft a client update", or "one next move".',
          restoredDetail: 'Last command preview restored from command memory.',
        ) ??
        'Try: "review cctv", "check guard route", "draft a client update", or "one next move".';
    return Container(
      key: const ValueKey('live-operations-command-intent-bar'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _commandPanelAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _commandBorderStrongColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = compact || constraints.maxWidth < 860;
          final inputField = TextField(
            key: const ValueKey('live-operations-command-input'),
            controller: _commandPromptController,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _submitPlainLanguageCommand(
              activeIncident: activeIncident,
              clientCommsSnapshot: clientCommsSnapshot,
            ),
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText:
                  'Type the next move: "open dispatch", "draft a client update", "show CCTV".',
              hintStyle: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 11.6,
                fontWeight: FontWeight.w600,
              ),
              isDense: true,
              filled: true,
              fillColor: _commandPanelColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _commandBorderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: OnyxDesignTokens.cyanInteractive,
                ),
              ),
            ),
          );
          final routeButton = FilledButton.tonalIcon(
            key: const ValueKey('live-operations-command-submit'),
            onPressed: () => _submitPlainLanguageCommand(
              activeIncident: activeIncident,
              clientCommsSnapshot: clientCommsSnapshot,
            ),
            icon: const Icon(Icons.keyboard_command_key_rounded, size: 14),
            label: const Text('Route'),
            style: FilledButton.styleFrom(
              backgroundColor: OnyxDesignTokens.cyanSurface,
              foregroundColor: OnyxDesignTokens.cyanInteractive,
              side: const BorderSide(color: OnyxDesignTokens.cyanBorder),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'TELL ONYX',
                    style: GoogleFonts.inter(
                      color: OnyxDesignTokens.cyanInteractive,
                      fontSize: 9.6,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.82,
                    ),
                  ),
                  Text(
                    commandHint,
                    style: GoogleFonts.inter(
                      color: _commandTitleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                commandDetail,
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              if (stacked) ...[
                inputField,
                const SizedBox(height: 10),
                routeButton,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: inputField),
                    const SizedBox(width: 10),
                    routeButton,
                  ],
                ),
              if (preview != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const ValueKey('live-operations-command-intent-preview'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _commandPanelColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _commandBorderColor),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        preview.eyebrow,
                        style: GoogleFonts.inter(
                          color: OnyxDesignTokens.cyanInteractive,
                          fontSize: 9.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.74,
                        ),
                      ),
                      Text(
                        preview.label,
                        style: GoogleFonts.inter(
                          color: _commandTitleColor,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        preview.summary,
                        style: GoogleFonts.inter(
                          color: _commandBodyColor,
                          fontSize: 10.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (previewStatusLines.isNotEmpty)
                        Text(
                          previewStatusLines.first,
                          style: GoogleFonts.inter(
                            color: OnyxDesignTokens.cyanInteractive,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      for (final statusLine in previewStatusLines.skip(1))
                        Text(
                          statusLine,
                          style: GoogleFonts.inter(
                            color: _commandMutedColor,
                            fontSize: 9.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _commandCurrentFocusPanel({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    bool streamlined = false,
  }) {
    final rosterSignalHeadline = (widget.guardRosterSignalHeadline ?? '')
        .trim();
    final rosterSignalDetail = (widget.guardRosterSignalDetail ?? '').trim();
    final rosterAttentionFocus =
        activeIncident == null &&
        widget.guardRosterSignalNeedsAttention &&
        rosterSignalHeadline.isNotEmpty;
    final rosterSignalLabel =
        (widget.guardRosterSignalLabel ?? '').trim().isEmpty
        ? 'ROSTER WATCH'
        : widget.guardRosterSignalLabel!.trim();
    final rosterAccent =
        widget.guardRosterSignalAccent ?? OnyxDesignTokens.amberWarning;
    final openClientLaneAction = clientCommsSnapshot == null
        ? null
        : _openClientLaneAction(
            clientId: clientCommsSnapshot.clientId,
            siteId: clientCommsSnapshot.siteId,
          );
    final scopeLabel = rosterAttentionFocus
        ? rosterSignalLabel
        : activeIncident == null
        ? 'Board clear'
        : _humanizeOpsScopeLabel(
            activeIncident.siteId,
            fallback: activeIncident.site,
          );
    final statusLabel = rosterAttentionFocus
        ? 'AMBER'
        : activeIncident == null
        ? 'READY'
        : _statusLabel(activeIncident.status).toUpperCase();
    final detail = rosterAttentionFocus
        ? (rosterSignalDetail.isEmpty
              ? 'Open the planner and close the uncovered posts before the next handoff.'
              : rosterSignalDetail)
        : activeIncident == null
        ? 'Board clear. Hold watch here until the next surfaced exception lands.'
        : _commandIncidentDetail(
            activeIncident,
            critical: activeIncident.priority == _IncidentPriority.p1Critical,
          );
    final focusAccent = rosterAttentionFocus
        ? rosterAccent
        : activeIncident == null
        ? OnyxDesignTokens.cyanInteractive
        : _priorityStyle(activeIncident.priority).foreground;
    final focusBackground = rosterAttentionFocus
        ? Color.alphaBlend(
            rosterAccent.withValues(alpha: 0.12),
            _commandPanelColor,
          )
        : activeIncident == null
        ? _commandPanelColor
        : Color.alphaBlend(
            focusAccent.withValues(alpha: 0.12),
            _commandPanelColor,
          );
    final focusBackgroundHigh = rosterAttentionFocus
        ? Color.alphaBlend(
            rosterAccent.withValues(alpha: 0.24),
            _commandPanelTintColor,
          )
        : activeIncident == null
        ? _commandPanelTintColor
        : Color.alphaBlend(
            focusAccent.withValues(alpha: 0.24),
            _commandPanelTintColor,
          );
    final focusBorder = rosterAttentionFocus
        ? rosterAccent.withValues(alpha: 0.55)
        : activeIncident == null
        ? _commandBorderStrongColor
        : focusAccent.withValues(alpha: 0.55);
    final typedDecision = rosterAttentionFocus || activeIncident == null
        ? null
        : _commandDecisionForIncident(activeIncident, incidentDetail: detail);
    final typedRecommendation = typedDecision?.toRecommendation();
    final replayPriorityActive = typedDecision?.decisionBias != null;
    final replayPolicyEscalationActive =
        typedDecision?.decisionBias?.isPolicyEscalatedSequenceFallback ?? false;
    final focusLead = rosterAttentionFocus
        ? 'Coverage is slipping.'
        : replayPriorityActive
        ? replayPolicyEscalationActive
              ? 'Honor the replay policy escalation first.'
              : 'Clear replay risk first.'
        : activeIncident == null
        ? 'Board is clear.'
        : activeIncident.priority == _IncidentPriority.p1Critical
        ? 'Do this first.'
        : 'Start here.';
    final focusTone = rosterAttentionFocus
        ? 'Roster gap'
        : replayPriorityActive
        ? replayPolicyEscalationActive
              ? 'Policy escalation'
              : 'Replay recovery'
        : activeIncident == null
        ? 'Hold watch'
        : activeIncident.priority == _IncidentPriority.p1Critical
        ? 'Immediate action'
        : 'Next action';
    final displayedRecommendation = typedRecommendation;
    final recommendationSummary = rosterAttentionFocus
        ? 'Open the planner now and fill the open posts before the next guard handoff.'
        : activeIncident == null
        ? 'Hold watch. Wait for the next incident.'
        : displayedRecommendation != null
        ? displayedRecommendation.summary
        : activeIncident.priority == _IncidentPriority.p1Critical
        ? 'Open the dispatch board and push the response forward now.'
        : 'Open the dispatch board and confirm the next response step.';
    final primaryActionLabel = rosterAttentionFocus
        ? 'OPEN MONTH PLANNER'
        : activeIncident == null
        ? 'Open Board'
        : displayedRecommendation?.nextMoveLabel ?? 'OPEN DISPATCH BOARD';
    final primaryActionAccent = rosterAttentionFocus
        ? rosterAccent
        : activeIncident == null
        ? OnyxDesignTokens.redCritical
        : displayedRecommendation == null
        ? OnyxDesignTokens.redCritical
        : _commandRecommendationAccent(displayedRecommendation.target);
    final primaryActionIcon = rosterAttentionFocus
        ? Icons.calendar_month_rounded
        : activeIncident == null
        ? Icons.open_in_full_rounded
        : displayedRecommendation == null
        ? Icons.warning_amber_rounded
        : _commandRecommendationIcon(displayedRecommendation.target);
    final rememberedReplayHistorySummary = _replayHistorySignalStack.isEmpty
        ? _rememberedReplayHistorySummary.trim()
        : '';
    final commandBrainSnapshot = typedDecision?.toSnapshot();
    final commandBrainLine = typedDecision == null
        ? null
        : OnyxCommandSurfaceMemoryAdapter.continuityViewForSnapshot(
            commandBrainSnapshot!,
            rememberedReplayHistorySummary: rememberedReplayHistorySummary,
          ).commandBrainSummaryLine();
    final replayHistoryLine = _commandReplayHistoryLine();
    return Container(
      key: const ValueKey('live-operations-command-current-focus'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [focusBackgroundHigh, focusBackground],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focusBorder),
        boxShadow: [
          BoxShadow(
            color: focusAccent.withValues(
              alpha: activeIncident == null ? 0.08 : 0.16,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: rosterAttentionFocus
                      ? focusAccent
                      : activeIncident == null
                      ? focusAccent.withValues(alpha: 0.16)
                      : focusAccent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: rosterAttentionFocus
                        ? focusAccent.withValues(alpha: 0.86)
                        : activeIncident == null
                        ? focusAccent.withValues(alpha: 0.38)
                        : focusAccent.withValues(alpha: 0.86),
                  ),
                ),
                child: Text(
                  rosterAttentionFocus
                      ? 'Priority'
                      : activeIncident == null
                      ? 'READY'
                      : 'Priority',
                  style: GoogleFonts.inter(
                    color: rosterAttentionFocus
                        ? OnyxDesignTokens.backgroundPrimary
                        : activeIncident == null
                        ? focusAccent
                        : OnyxDesignTokens.textPrimary,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              if (!streamlined)
                Text(
                  'Focus',
                  style: GoogleFonts.inter(
                    color: _commandTitleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
          if (!streamlined) ...[
            const SizedBox(height: 4),
            Text(
              focusLead,
              style: GoogleFonts.inter(
                color: focusAccent,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 2),
          ] else
            const SizedBox(height: 8),
          Text(
            rosterAttentionFocus
                ? rosterSignalHeadline
                : activeIncident == null
                ? 'No incident in focus.'
                : '${activeIncident.id} • ${activeIncident.type}',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: statusLabel,
                foreground: rosterAttentionFocus
                    ? focusAccent
                    : activeIncident == null
                    ? OnyxDesignTokens.textMuted
                    : focusAccent,
                background: rosterAttentionFocus
                    ? focusAccent.withValues(alpha: 0.14)
                    : activeIncident == null
                    ? _commandPanelTintColor
                    : focusAccent.withValues(alpha: 0.14),
                border: rosterAttentionFocus
                    ? focusAccent.withValues(alpha: 0.35)
                    : activeIncident == null
                    ? _commandBorderColor
                    : focusAccent.withValues(alpha: 0.35),
              ),
              _chip(
                label: focusTone,
                foreground: _commandTitleColor,
                background: _commandPanelTintColor,
                border: _commandBorderColor,
                leadingIcon: Icons.bolt_rounded,
              ),
              _chip(
                label: scopeLabel,
                foreground: OnyxDesignTokens.textSecondary,
                background: _commandPanelTintColor,
                border: _commandBorderColor,
                leadingIcon: Icons.place_outlined,
              ),
            ],
          ),
          SizedBox(height: streamlined ? 10 : 12),
          Text(
            streamlined ? 'NEXT MOVE' : 'RECOMMENDED NEXT MOVE',
            style: GoogleFonts.inter(
              color: focusAccent.withValues(alpha: 0.96),
              fontSize: 9.1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.72,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            recommendationSummary,
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (commandBrainLine != null) ...[
            const SizedBox(height: 4),
            Text(
              commandBrainLine,
              style: GoogleFonts.inter(
                color: OnyxDesignTokens.cyanInteractive,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (replayHistoryLine != null) ...[
            const SizedBox(height: 4),
            Text(
              replayHistoryLine,
              key: const ValueKey('live-operations-command-replay-history'),
              style: GoogleFonts.inter(
                color: OnyxDesignTokens.textSecondary,
                fontSize: 10.2,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          if (!streamlined) ...[
            const SizedBox(height: 6),
            Text(
              displayedRecommendation?.detail ?? detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: _commandBodyColor,
                fontSize: 10.3,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: streamlined ? 10 : 12),
          FilledButton.tonalIcon(
            key: const ValueKey('live-operations-command-open-board'),
            onPressed: rosterAttentionFocus
                ? _openRosterPlannerFromCommand
                : activeIncident == null
                ? () {
                    setState(() {
                      _showDetailedWorkspace = true;
                    });
                  }
                : () async {
                    if (typedDecision != null) {
                      await _executeTypedCommandDecision(
                        incident: activeIncident,
                        decision: typedDecision,
                        clientCommsSnapshot: clientCommsSnapshot,
                      );
                      return;
                    }
                    await _openCommandAlarmBoard(activeIncident);
                  },
            icon: Icon(primaryActionIcon, size: 14),
            label: Text(primaryActionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: rosterAttentionFocus
                  ? rosterAccent.withValues(alpha: 0.18)
                  : activeIncident == null
                  ? OnyxDesignTokens.redSurface
                  : primaryActionAccent.withValues(
                      alpha:
                          primaryActionAccent == OnyxDesignTokens.redCritical
                          ? 1
                          : 0.94,
                    ),
              foregroundColor: rosterAttentionFocus
                  ? rosterAccent
                  : activeIncident == null
                  ? OnyxDesignTokens.redCritical
                  : primaryActionAccent.computeLuminance() > 0.55
                  ? OnyxDesignTokens.backgroundPrimary
                  : OnyxDesignTokens.textPrimary,
              side: BorderSide(
                color: rosterAttentionFocus
                    ? rosterAccent.withValues(alpha: 0.52)
                    : activeIncident == null
                    ? OnyxDesignTokens.redBorder
                    : primaryActionAccent.withValues(alpha: 0.62),
              ),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if ((activeIncident != null &&
                  widget.onOpenAgentForIncident != null) ||
              openClientLaneAction != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (activeIncident != null &&
                    widget.onOpenAgentForIncident != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey('live-operations-command-open-agent'),
                    onPressed: () => _openAgentFromWarRoom(activeIncident.id),
                    icon: const Icon(Icons.psychology_alt_rounded, size: 14),
                    label: const Text('Ask Agent'),
                    style: FilledButton.styleFrom(
                      backgroundColor: OnyxDesignTokens.purpleSurface,
                      foregroundColor: OnyxDesignTokens.purpleAdmin,
                      side: const BorderSide(
                        color: OnyxDesignTokens.purpleBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.2,
                        fontWeight: FontWeight.w800,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (openClientLaneAction != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey(
                      'live-operations-command-open-client-lane',
                    ),
                    onPressed: openClientLaneAction,
                    icon: const Icon(Icons.mark_chat_read_rounded, size: 14),
                    label: const Text('Client Comms'),
                    style: FilledButton.styleFrom(
                      backgroundColor: OnyxDesignTokens.cyanSurface,
                      foregroundColor: OnyxDesignTokens.cyanInteractive,
                      side: const BorderSide(
                        color: OnyxDesignTokens.cyanBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.0,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _commandFullGrid({
    required List<_CommandCenterModule> modules,
    bool compact = false,
    double? targetGridHeight,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute childAspectRatio so the 2-row grid fills the target height.
        // Falls back to a fixed ratio for compact / unconstrained cases.
        final cardWidth = (constraints.maxWidth - 16) / 3; // 2 × 8px spacing
        final double childAspectRatio;
        if (targetGridHeight != null && targetGridHeight > 0) {
          final cardHeight = (targetGridHeight - 8) / 2; // 1 × 8px row spacing
          childAspectRatio = cardHeight > 0
              ? cardWidth / cardHeight
              : (compact ? 1.1 : 1.4);
        } else {
          childAspectRatio = compact ? 1.1 : 1.4;
        }

        return GridView.builder(
          key: const ValueKey('live-operations-command-full-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: modules.length,
          itemBuilder: (context, index) {
            final m = modules[index];
            return GestureDetector(
              onTap: m.onTap != null ? () => m.onTap!() : null,
              child: LayoutBuilder(
                builder: (context, cardConstraints) {
                  final denseCard = compact || cardConstraints.maxHeight < 118;
                  final contentPadding = denseCard ? 12.0 : 20.0;
                  final iconContainerSize = denseCard ? 30.0 : 40.0;
                  final iconSize = denseCard ? 22.0 : 32.0;
                  final countFontSize = denseCard
                      ? 24.0
                      : (compact ? 32.0 : 48.0);
                  final metricFontSize = denseCard ? 9.0 : 11.0;
                  final labelFontSize = denseCard ? 11.0 : 13.0;
                  final badgeOffset = denseCard ? 6.0 : 8.0;

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          gradient: m.gradient,
                          color: m.gradient == null ? m.surface : null,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: m.border),
                        ),
                        padding: EdgeInsets.all(contentPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: iconContainerSize,
                              height: iconContainerSize,
                              decoration: BoxDecoration(
                                color: m.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  denseCard ? 8 : 10,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  m.icon,
                                  size: iconSize,
                                  color: m.accent,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        m.countLabel,
                                        style: TextStyle(
                                          fontSize: countFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: m.accent,
                                          height: 1,
                                        ),
                                      ),
                                      SizedBox(height: denseCard ? 2 : 3),
                                      Text(
                                        m.metricLabel,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: metricFontSize,
                                          color: _commandMutedColor,
                                          letterSpacing: denseCard ? 0.45 : 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              m.label,
                              maxLines: denseCard ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w600,
                                color: _commandTitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: badgeOffset,
                        right: badgeOffset,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: m.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: m.accent.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _commandRecentActivity(List<_LedgerEntry> ledger) {
    final recent = ledger.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _commandMutedColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No recent activity',
              style: TextStyle(fontSize: 13, color: _commandMutedColor),
            ),
          )
        else
          ...recent.map((e) => _commandRecentActivityRow(e)),
      ],
    );
  }

  Widget _commandRecentActivityRow(_LedgerEntry entry) {
    final timeStr =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    final (badgeLabel, badgeColor) = switch (entry.type) {
      _LedgerType.aiAction => ('AI', OnyxDesignTokens.accentPurple),
      _LedgerType.humanOverride => ('NOTE', OnyxDesignTokens.textSecondary),
      _LedgerType.systemEvent => ('SYS', _commandMutedColor),
      _LedgerType.escalation => ('DISPATCH', OnyxDesignTokens.amberWarning),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              timeStr,
              style: const TextStyle(fontSize: 11, color: _commandMutedColor),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.description,
              style: const TextStyle(fontSize: 12, color: _commandBodyColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _commandQuickOpenPanel({
    required List<_CommandCenterModule> modules,
    bool compact = false,
  }) {
    return Container(
      key: const ValueKey('live-operations-command-quick-open'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _commandBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JUMP TO',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 13.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use only if the next move is wrong.',
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 9.8,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            itemCount: modules.length,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: compact ? 1.9 : 2.2,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  key: ValueKey(
                    'live-operations-quick-open-${module.label.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onTap: module.onTap == null
                      ? null
                      : () async {
                          await module.onTap!.call();
                        },
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          gradient:
                              module.gradient ??
                              LinearGradient(
                                colors: [
                                  Color.alphaBlend(
                                    module.accent.withValues(alpha: 0.18),
                                    module.surface,
                                  ),
                                  module.surface,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: module.border),
                          boxShadow: [
                            BoxShadow(
                              color: module.accent.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top row: icon
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: module.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: module.accent.withValues(alpha: 0.36),
                                ),
                              ),
                              child: Icon(
                                module.icon,
                                size: 14,
                                color: module.accent,
                              ),
                            ),
                            // Middle: large count + metric label
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  module.countLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: module.accent,
                                    fontSize: compact ? 26 : 32,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  module.metricLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: _commandMutedColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                            // Bottom: module name
                            Text(
                              module.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: _commandTitleColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: module.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: module.accent.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              'Fast jumps only. Everything else lives in the queue or board.',
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 8.9,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_CommandCenterModule> _commandCenterModules({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required List<_LedgerEntry> ledger,
  }) {
    final unresolvedIncidents = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .toList(growable: false);
    final onDutyCount = _vigilance.length;
    final visualAlertCount = widget.sceneReviewByIntelligenceId.isNotEmpty
        ? widget.sceneReviewByIntelligenceId.length
        : _incidents
              .where(
                (incident) =>
                    (incident.latestSceneReviewLabel ?? '').trim().isNotEmpty ||
                    (incident.snapshotUrl ?? '').trim().isNotEmpty ||
                    (incident.clipUrl ?? '').trim().isNotEmpty,
              )
              .length;
    var pendingDraftCount = _visibleControlInboxDraftCount(
      controlInboxSnapshot,
    );
    if (controlInboxSnapshot != null &&
        controlInboxSnapshot.pendingApprovalCount > pendingDraftCount) {
      pendingDraftCount = controlInboxSnapshot.pendingApprovalCount;
    }
    var liveAskCount = controlInboxSnapshot?.liveClientAsks.length ?? 0;
    if (controlInboxSnapshot != null &&
        controlInboxSnapshot.awaitingResponseCount > liveAskCount) {
      liveAskCount = controlInboxSnapshot.awaitingResponseCount;
    }
    final pendingMessageCount = pendingDraftCount + liveAskCount;
    final clientLaneAction = clientCommsSnapshot == null
        ? widget.onOpenClientView
        : _openClientLaneAction(
            clientId: clientCommsSnapshot.clientId,
            siteId: clientCommsSnapshot.siteId,
          );

    return [
      _CommandCenterModule(
        label: 'ALARMS',
        countLabel: '${unresolvedIncidents.length}',
        metricLabel: 'ACTIVE ALARMS',
        icon: Icons.warning_amber_rounded,
        accent: unresolvedIncidents.isNotEmpty
            ? OnyxDesignTokens.redCritical
            : OnyxDesignTokens.textMuted,
        surface: unresolvedIncidents.isNotEmpty
            ? OnyxDesignTokens.redSurface
            : _commandPanelTintColor,
        border: unresolvedIncidents.isNotEmpty
            ? OnyxDesignTokens.redBorder
            : _commandBorderColor,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1515), Color(0xFF1A0A0A)],
        ),
        onTap: () async {
          if (widget.onOpenAlarms != null) {
            widget.onOpenAlarms!.call();
            return;
          }
          if (unresolvedIncidents.isEmpty) {
            return;
          }
          _focusLeadIncident();
          if (!_showDetailedWorkspace) {
            setState(() {
              _showDetailedWorkspace = true;
            });
          }
        },
      ),
      _CommandCenterModule(
        label: 'GUARDS',
        countLabel: '$onDutyCount',
        metricLabel: onDutyCount == 0
            ? 'NO GUARDS ON DUTY'
            : 'ON DUTY ($onDutyCount TOTAL)',
        icon: Icons.groups_2_rounded,
        accent: OnyxDesignTokens.greenNominal,
        surface: OnyxDesignTokens.cardSurface,
        border: OnyxDesignTokens.borderSubtle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2D1A), Color(0xFF0A1A0F)],
        ),
        onTap: () async {
          if (widget.onOpenGuards != null) {
            widget.onOpenGuards!.call();
            return;
          }
          if (!_showDetailedWorkspace) {
            setState(() {
              _showDetailedWorkspace = true;
            });
          }
          await Future<void>.delayed(Duration.zero);
          await _ensureContextAndVigilancePanelVisible();
        },
      ),
      _CommandCenterModule(
        label: widget.videoOpsLabel.toUpperCase(),
        countLabel: '$visualAlertCount',
        metricLabel: 'AI ALERTS',
        icon: Icons.videocam_outlined,
        accent: visualAlertCount > 0
            ? OnyxDesignTokens.amberWarning
            : OnyxDesignTokens.textMuted,
        surface: visualAlertCount > 0
            ? OnyxDesignTokens.amberSurface
            : _commandPanelTintColor,
        border: visualAlertCount > 0
            ? OnyxDesignTokens.amberBorder
            : _commandBorderColor,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1E0A), Color(0xFF1A1205)],
        ),
        onTap: () async {
          if (widget.onOpenCctv != null) {
            widget.onOpenCctv!.call();
            return;
          }
          if (_activeTab != _ContextTab.visual || !_showDetailedWorkspace) {
            setState(() {
              _activeTab = _ContextTab.visual;
              _showDetailedWorkspace = true;
            });
          }
          await Future<void>.delayed(Duration.zero);
          await _ensureContextAndVigilancePanelVisible();
        },
      ),
      _CommandCenterModule(
        label: 'VIP PROTECTION',
        countLabel: '0',
        metricLabel: 'ACTIVE CONVOYS',
        icon: Icons.shield_outlined,
        accent: OnyxDesignTokens.greenNominal,
        surface: OnyxDesignTokens.cardSurface,
        border: OnyxDesignTokens.borderSubtle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2D1A), Color(0xFF0A1A0F)],
        ),
        onTap: () async {
          if (widget.onOpenVipProtection != null) {
            widget.onOpenVipProtection!.call();
            return;
          }
          _showLiveOpsFeedback(
            'No active VIP details right now.',
            label: 'VIP',
            detail:
                'VIP protection stays quiet until a convoy or close-protection detail becomes active.',
            accent: OnyxDesignTokens.greenNominal,
          );
        },
      ),
      _CommandCenterModule(
        label: 'RISK INTEL',
        countLabel: '0',
        metricLabel: 'THREAT LEVEL: LOW',
        icon: Icons.trending_up_rounded,
        accent: OnyxDesignTokens.accentTeal,
        surface: const Color(0xFF0D2420),
        border: const Color(0xFF1A4A40),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2020), Color(0xFF051515)],
        ),
        onTap: () async {
          if (widget.onOpenRiskIntel != null) {
            widget.onOpenRiskIntel!.call();
            return;
          }
          _showLiveOpsFeedback(
            'Threat posture remains low.',
            label: 'INTEL',
            detail:
                'No elevated risk signal is asking for controller action right now.',
            accent: OnyxDesignTokens.greenNominal,
          );
        },
      ),
      _CommandCenterModule(
        label: 'CLIENT COMMS',
        countLabel: '$pendingMessageCount',
        metricLabel: 'PENDING MESSAGES',
        icon: Icons.chat_bubble_outline_rounded,
        accent: pendingMessageCount > 0
            ? OnyxDesignTokens.redCritical
            : OnyxDesignTokens.textMuted,
        surface: pendingMessageCount > 0
            ? OnyxDesignTokens.redSurface
            : _commandPanelTintColor,
        border: pendingMessageCount > 0
            ? OnyxDesignTokens.redBorder
            : _commandBorderColor,
        gradient: pendingMessageCount > 0
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D1515), Color(0xFF1A0A0A)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2D1A), Color(0xFF0A1A0F)],
              ),
        onTap: () async {
          if (clientLaneAction != null) {
            clientLaneAction();
            return;
          }
          if (!_showDetailedWorkspace) {
            setState(() {
              _showDetailedWorkspace = true;
            });
          }
          await Future<void>.delayed(Duration.zero);
          await _ensureControlInboxPanelVisible();
        },
      ),
    ];
  }

  // ignore: unused_element
  List<_CommandCenterModule> _quickOpenModules(
    List<_CommandCenterModule> modules,
  ) {
    const quickOpenLabels = <String>{'ALARMS', 'GUARDS', 'CLIENT COMMS'};
    final videoOpsLabel = widget.videoOpsLabel.toUpperCase();
    return modules
        .where((module) {
          return quickOpenLabels.contains(module.label) ||
              module.label == videoOpsLabel;
        })
        .toList(growable: false);
  }

  Widget _guardRosterSignalBanner({bool compact = false}) {
    final headline = (widget.guardRosterSignalHeadline ?? '').trim();
    if (headline.isEmpty) {
      return const SizedBox.shrink();
    }
    final accent =
        widget.guardRosterSignalAccent ?? OnyxDesignTokens.amberWarning;
    final label = (widget.guardRosterSignalLabel ?? '').trim().isEmpty
        ? 'ROSTER WATCH'
        : widget.guardRosterSignalLabel!.trim();
    final detail = (widget.guardRosterSignalDetail ?? '').trim();
    final urgent = widget.guardRosterSignalNeedsAttention;
    return Container(
      key: const ValueKey('live-operations-roster-signal-banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: urgent ? 0.24 : 0.18),
              _commandPanelColor,
            ),
            Color.alphaBlend(
              accent.withValues(alpha: urgent ? 0.1 : 0.06),
              _commandPanelTintColor,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: urgent ? 0.22 : 0.14),
            blurRadius: urgent ? 18 : 12,
            spreadRadius: urgent ? 1 : 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Icon(
              urgent ? Icons.event_busy_rounded : Icons.event_available_rounded,
              size: compact ? 17 : 19,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.32,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Text(
                        urgent ? 'ACT NOW' : 'WATCH READY',
                        style: GoogleFonts.inter(
                          color: _commandTitleColor,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  headline,
                  style: GoogleFonts.inter(
                    color: _commandTitleColor,
                    fontSize: compact ? 12.2 : 12.8,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: _commandBodyColor,
                      fontSize: compact ? 10.1 : 10.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _commandDecisionMiniChip({
    required String label,
    required int count,
    required _CommandDecisionSeverity severity,
  }) {
    final (accent, surface, _, _) = _commandDecisionTone(severity);
    final foreground = count > 0 ? accent : _commandMutedColor;
    final activeSurface = Color.alphaBlend(accent.withValues(alpha: 0.14), surface);
    return Container(
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: count > 0 ? activeSurface : _commandPanelTintColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: count > 0
              ? accent.withValues(alpha: 0.42)
              : _commandBorderColor,
        ),
        boxShadow: count > 0
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 0.96,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: count > 0 ? _commandTitleColor : _commandMutedColor,
              fontSize: 8.8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.28,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _commandDecisionQueuePanel({
    required List<_CommandDecisionItem> items,
    bool streamlined = false,
  }) {
    const maxVisibleItems = 3;
    final visibleItems = items.take(maxVisibleItems).toList(growable: true);
    if (items.length > maxVisibleItems &&
        visibleItems.every((item) => !item.isClientComms)) {
      final firstClientCommsIndex = items.indexWhere(
        (item) => item.isClientComms,
      );
      if (firstClientCommsIndex >= maxVisibleItems) {
        visibleItems[maxVisibleItems - 1] = items[firstClientCommsIndex];
      }
    }
    final hiddenCount = items.length - visibleItems.length;
    final criticalCount = items
        .where((item) => item.severity == _CommandDecisionSeverity.critical)
        .length;
    final actionRequiredCount = items
        .where(
          (item) => item.severity == _CommandDecisionSeverity.actionRequired,
        )
        .length;
    final watchCount = items
        .where((item) => item.severity == _CommandDecisionSeverity.review)
        .length;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!streamlined) ...[
          Text(
            'QUEUE',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pick one.',
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _commandDecisionMiniChip(
                label: 'RED',
                count: criticalCount,
                severity: _CommandDecisionSeverity.critical,
              ),
              _commandDecisionMiniChip(
                label: 'ACT',
                count: actionRequiredCount,
                severity: _CommandDecisionSeverity.actionRequired,
              ),
              _commandDecisionMiniChip(
                label: 'WATCH',
                count: watchCount,
                severity: _CommandDecisionSeverity.review,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OnyxDesignTokens.cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OnyxDesignTokens.borderSubtle),
            ),
            child: Text(
              'Queue clear. Hold watch.',
              style: GoogleFonts.inter(
                color: OnyxDesignTokens.greenNominal,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < visibleItems.length; index++) ...[
                _commandDecisionCard(visibleItems[index], priorityRank: index),
                if (index != visibleItems.length - 1) const SizedBox(height: 8),
              ],
              if (hiddenCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _commandPanelTintColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _commandBorderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$hiddenCount more in full queue.',
                          style: GoogleFonts.inter(
                            color: _commandBodyColor,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        key: const ValueKey(
                          'live-operations-command-open-full-queue',
                        ),
                        onPressed: () async {
                          await _openIncidentQueueQueueFocus();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OnyxDesignTokens.cyanInteractive,
                          side: const BorderSide(
                            color: _commandBorderStrongColor,
                          ),
                          backgroundColor: _commandPanelColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.queue_rounded, size: 14),
                        label: const Text('OPEN FULL QUEUE'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
      ],
    );

    if (streamlined) {
      return KeyedSubtree(
        key: const ValueKey('live-operations-command-queue'),
        child: content,
      );
    }

    return Container(
      key: const ValueKey('live-operations-command-queue'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _commandBorderColor),
      ),
      child: content,
    );
  }

  // ignore: unused_element
  Widget _commandDecisionCard(
    _CommandDecisionItem item, {
    int priorityRank = 999,
  }) {
    final featured = priorityRank == 0;
    final emphasized = priorityRank < 3;
    final (accent, surface, border, text) = _commandDecisionTone(item.severity);
    final nextMove = item.actions.isEmpty ? null : item.actions.first.label;
    final detailMaxLines = featured
        ? 1
        : emphasized
        ? 1
        : 4;
    final card = Container(
      key: item.key,
      width: double.infinity,
      padding: EdgeInsets.all(featured ? 12 : 10),
      decoration: BoxDecoration(
        gradient: emphasized
            ? LinearGradient(
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: featured ? 0.28 : 0.18),
                    surface,
                  ),
                  surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: emphasized ? null : surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: emphasized
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: featured ? 0.16 : 0.10),
                  blurRadius: featured ? 22 : 16,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (emphasized) ...[
            Container(
              width: featured ? 8 : 6,
              height: item.actions.isEmpty ? 96 : 132,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: featured ? 0.55 : 0.32),
                    blurRadius: featured ? 22 : 14,
                    spreadRadius: featured ? 1.5 : 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (priorityRank < 3) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: featured ? accent : accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: featured
                            ? accent.withValues(alpha: 0.92)
                            : accent.withValues(alpha: 0.36),
                      ),
                    ),
                    child: Text(
                      switch (priorityRank) {
                        0 => 'Priority',
                        1 => 'UP NEXT',
                        _ => 'THEN',
                      },
                      style: GoogleFonts.inter(
                        color: featured
                            ? OnyxDesignTokens.backgroundPrimary
                            : accent,
                        fontSize: 8.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        item.label.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 8.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.context,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.inter(
                          color: text,
                          fontSize: 9.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: featured
                            ? accent.withValues(alpha: 0.22)
                            : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accent.withValues(
                            alpha: featured ? 0.44 : 0.22,
                          ),
                        ),
                      ),
                      child: Icon(item.icon, size: 18, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              color: _commandTitleColor,
                              fontSize: featured ? 15.5 : 14.2,
                              fontWeight: FontWeight.w700,
                              height: 1.08,
                            ),
                          ),
                          if (nextMove != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'NEXT MOVE: ${nextMove.toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: accent.withValues(alpha: 0.96),
                                fontSize: featured ? 10.1 : 9.8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.16,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            item.detail,
                            maxLines: detailMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: _commandBodyColor,
                              fontSize: featured ? 11.6 : 10.8,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (item.actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  if (emphasized) ...[
                    _commandDecisionActionButton(
                      item.actions.first,
                      emphasized: emphasized,
                      primary: true,
                    ),
                    if (item.actions.length > 1) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List<Widget>.generate(
                          item.actions.length - 1,
                          (actionIndex) {
                            return _commandDecisionActionButton(
                              item.actions[actionIndex + 1],
                              emphasized: emphasized,
                              primary: false,
                            );
                          },
                        ),
                      ),
                    ],
                  ] else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(item.actions.length, (
                        actionIndex,
                      ) {
                        return _commandDecisionActionButton(
                          item.actions[actionIndex],
                          emphasized: emphasized,
                          primary: actionIndex == 0,
                        );
                      }),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (item.onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await item.onTap!.call();
        },
        child: card,
      ),
    );
  }

  // ignore: unused_element
  Widget _commandDecisionActionButton(
    _CommandDecisionAction action, {
    bool emphasized = false,
    bool primary = false,
  }) {
    final highEmphasis = emphasized && primary;
    final highEmphasisForeground = action.accent.computeLuminance() > 0.55
        ? OnyxDesignTokens.backgroundPrimary
        : OnyxDesignTokens.textPrimary;
    return FilledButton.tonalIcon(
      key: action.key,
      onPressed: action.onPressed == null
          ? null
          : () async {
              await action.onPressed!.call();
            },
      icon: Icon(action.icon, size: 14),
      label: Text(action.label),
      style: FilledButton.styleFrom(
        backgroundColor: highEmphasis
            ? action.accent
            : Color.alphaBlend(
                action.accent.withValues(alpha: 0.12),
                _commandPanelColor,
              ),
        foregroundColor: highEmphasis ? highEmphasisForeground : action.accent,
        disabledBackgroundColor: _commandPanelTintColor,
        disabledForegroundColor: OnyxDesignTokens.textMuted.withValues(
          alpha: 0.6,
        ),
        side: BorderSide(
          color: action.accent.withValues(alpha: highEmphasis ? 0.62 : 0.24),
        ),
        minimumSize: const Size(0, 36),
        padding: EdgeInsets.symmetric(
          horizontal: highEmphasis ? 14 : 10,
          vertical: 8,
        ),
        textStyle: GoogleFonts.inter(
          fontSize: highEmphasis ? 13 : 11,
          fontWeight: highEmphasis ? FontWeight.w700 : FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _commandMemoryPanel(List<_LedgerEntry> ledger) {
    final visibleEntries = ledger.take(4).toList(growable: false);
    final verifiedCount = ledger.where((entry) => entry.verified).length;
    final commandReplayContextLine = _commandMemoryReplayContextLine();
    final replayHistoryLine = _commandReplayHistoryLine();
    return Container(
      key: const ValueKey('live-operations-command-memory'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _commandBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOVEREIGN LEDGER',
                      style: GoogleFonts.inter(
                        color: OnyxDesignTokens.cyanInteractive,
                        fontSize: 8.6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.82,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Clean Record',
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    ledger.isEmpty
                        ? '0 sealed'
                        : '$verifiedCount/${ledger.length} sealed',
                    style: GoogleFonts.inter(
                      color: _commandMutedColor,
                      fontSize: 9.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: OnyxDesignTokens.greenNominal.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: OnyxDesignTokens.greenNominal.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                    child: Text(
                      'Chain Intact',
                      style: GoogleFonts.inter(
                        color: OnyxDesignTokens.greenNominal,
                        fontSize: 8.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Sovereign Ledger notes and linked events keep every decision attached to the shift story.',
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (commandReplayContextLine != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey(
                'live-operations-command-memory-command-brain-replay',
              ),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _commandPanelTintColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _commandBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMAND BRAIN REPLAY',
                    style: GoogleFonts.inter(
                      color: OnyxDesignTokens.cyanInteractive,
                      fontSize: 8.4,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.72,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    commandReplayContextLine,
                    style: GoogleFonts.inter(
                      color: _commandMutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (replayHistoryLine != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey(
                'live-operations-command-memory-replay-history',
              ),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _commandPanelTintColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _commandBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REPLAY CONTINUITY',
                    style: GoogleFonts.inter(
                      color: OnyxDesignTokens.cyanInteractive,
                      fontSize: 8.4,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.72,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    replayHistoryLine,
                    style: GoogleFonts.inter(
                      color: _commandMutedColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (visibleEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OnyxDesignTokens.cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OnyxDesignTokens.borderSubtle),
              ),
              child: Text(
                'AUTO-AUDIT ARMED. The next controller decision will seal here automatically.',
                style: GoogleFonts.inter(
                  color: OnyxDesignTokens.greenNominal,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < visibleEntries.length; index++) ...[
                  Builder(
                    builder: (context) {
                      final entry = visibleEntries[index];
                      final tag = switch (entry.type) {
                        _LedgerType.aiAction => 'AI',
                        _LedgerType.humanOverride => 'NOTE',
                        _LedgerType.systemEvent => 'SYS',
                        _LedgerType.escalation => 'DISPATCH',
                      };
                      final accent = switch (entry.type) {
                        _LedgerType.aiAction =>
                          OnyxDesignTokens.cyanInteractive,
                        _LedgerType.humanOverride =>
                          OnyxDesignTokens.purpleAdmin,
                        _LedgerType.systemEvent => OnyxDesignTokens.textMuted,
                        _LedgerType.escalation => OnyxDesignTokens.amberWarning,
                      };
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _commandPanelTintColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _commandBorderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tag,
                                    style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 8.4,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _hhmm(entry.timestamp.toLocal()),
                                  style: GoogleFonts.robotoMono(
                                    color: _commandMutedColor,
                                    fontSize: 9.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              entry.description,
                              style: GoogleFonts.inter(
                                color: _commandTitleColor,
                                fontSize: 11.1,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            if ((entry.actor ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.actor!,
                                style: GoogleFonts.inter(
                                  color: _commandMutedColor,
                                  fontSize: 9.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  if (index != visibleEntries.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('live-operations-command-verify-ledger'),
            onPressed: ledger.isEmpty ? null : () => _verifyLedgerChain(ledger),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E6EA8),
              side: const BorderSide(color: _commandBorderStrongColor),
              backgroundColor: _commandPanelColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: GoogleFonts.inter(
                fontSize: 10.6,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.verified_rounded, size: 15),
            label: const Text('Verify Chain'),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  List<_CommandDecisionItem> _commandDecisionItems({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required List<_LedgerEntry> ledger,
  }) {
    final items = <_CommandDecisionItem>[];
    final usedIncidentIds = <String>{};
    final unresolvedIncidents = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .toList(growable: false);

    for (final incident
        in unresolvedIncidents
            .where(
              (incident) => incident.priority == _IncidentPriority.p1Critical,
            )
            .take(2)) {
      usedIncidentIds.add(incident.id);
      items.add(
        _CommandDecisionItem(
          key: ValueKey('live-operations-command-item-incident-${incident.id}'),
          severity: _CommandDecisionSeverity.critical,
          label: 'Critical',
          title: '${incident.type} - ${incident.site}',
          detail: _commandIncidentDetail(incident, critical: true),
          context: '${incident.timestamp} • ${_statusLabel(incident.status)}',
          icon: Icons.warning_amber_rounded,
          accent: OnyxDesignTokens.redCritical,
          onTap: () => _openCommandAlarmBoard(incident),
          actions: [
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-dispatch-${incident.id}',
              ),
              label: 'Dispatch',
              icon: Icons.send_rounded,
              accent: OnyxDesignTokens.redCritical,
              onPressed: () async {
                if (widget.onOpenAlarmsForIncident != null) {
                  _appendCommandLedgerEntry(
                    'Dispatch staged for ${incident.id}',
                    type: _LedgerType.escalation,
                  );
                  widget.onOpenAlarmsForIncident!(incident.id);
                  return;
                }
                _focusIncidentFromBanner(incident);
                await _ensureActionLadderPanelVisible();
                _appendCommandLedgerEntry(
                  'Dispatch staged for ${incident.id}',
                  type: _LedgerType.escalation,
                );
                _showLiveOpsFeedback(
                  'Dispatch staged for ${incident.site}.',
                  label: 'DISPATCH',
                  detail:
                      'Assign the nearest officer, then keep the action ladder pinned until the incident is closed.',
                  accent: OnyxDesignTokens.redCritical,
                );
              },
            ),
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-track-${incident.id}',
              ),
              label: 'Track',
              icon: Icons.near_me_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                await _openCommandTrackBoard(incident);
              },
            ),
          ],
        ),
      );
    }

    final rosterSignalHeadline = (widget.guardRosterSignalHeadline ?? '')
        .trim();
    final rosterSignalDetail = (widget.guardRosterSignalDetail ?? '').trim();
    if (widget.guardRosterSignalNeedsAttention &&
        rosterSignalHeadline.isNotEmpty) {
      final rosterAccent =
          widget.guardRosterSignalAccent ?? OnyxDesignTokens.amberWarning;
      final rosterLabel = (widget.guardRosterSignalLabel ?? '').trim().isEmpty
          ? 'Roster Watch'
          : widget.guardRosterSignalLabel!.trim();
      items.add(
        _CommandDecisionItem(
          key: const ValueKey('live-operations-command-item-roster-signal'),
          severity: _CommandDecisionSeverity.actionRequired,
          label: 'Action Required',
          title: rosterSignalHeadline,
          detail: rosterSignalDetail.isEmpty
              ? 'Open the month planner now and fill the uncovered posts before the next handoff.'
              : rosterSignalDetail,
          context: '${rosterLabel.toUpperCase()} • MONTH PLANNER',
          icon: Icons.event_note_rounded,
          accent: rosterAccent,
          onTap: () => _openCommandGuardsBoard(null),
          actions: [
            _CommandDecisionAction(
              key: const ValueKey(
                'live-operations-command-action-roster-open-planner',
              ),
              label: 'OPEN MONTH PLANNER',
              icon: Icons.calendar_month_rounded,
              accent: rosterAccent,
              onPressed: _openRosterPlannerFromCommand,
            ),
            if (widget.onOpenRosterAudit != null)
              _CommandDecisionAction(
                key: const ValueKey(
                  'live-operations-command-action-roster-view-audit',
                ),
                label: 'OPEN SIGNED AUDIT',
                icon: Icons.menu_book_rounded,
                accent: OnyxDesignTokens.greenNominal,
                onPressed: _openRosterAuditFromCommand,
              ),
          ],
        ),
      );
    }

    final distressedGuards =
        _vigilance
            .where((guard) => guard.decayLevel >= 85)
            .toList(growable: false)
          ..sort((a, b) => b.decayLevel.compareTo(a.decayLevel));
    if (distressedGuards.isNotEmpty) {
      final guard = distressedGuards.first;
      items.add(
        _CommandDecisionItem(
          key: ValueKey('live-operations-command-item-guard-${guard.callsign}'),
          severity: _CommandDecisionSeverity.actionRequired,
          label: 'Action Required',
          title: 'Possible Guard Distress - ${guard.callsign}',
          detail:
              'No recent movement or check-in has been confirmed. Verify the patrol and decide whether support should be dispatched.',
          context:
              'Last check-in ${guard.lastCheckIn} • signal ${guard.decayLevel}%',
          icon: Icons.health_and_safety_rounded,
          accent: OnyxDesignTokens.amberWarning,
          onTap: () => _openCommandGuardsBoard(guard),
          actions: [
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-guard-call-${guard.callsign}',
              ),
              label: 'Call',
              icon: Icons.call_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                if (widget.onOpenGuards != null) {
                  widget.onOpenGuards!.call();
                  return;
                }
                _showLiveOpsFeedback(
                  'Calling ${guard.callsign} to verify patrol status.',
                  label: 'GUARD CHECK',
                  detail:
                      'If the guard does not clear the exception, dispatch support and link the note to the Sovereign Ledger.',
                  accent: OnyxDesignTokens.amberWarning,
                );
              },
            ),
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-guard-dispatch-${guard.callsign}',
              ),
              label: 'Dispatch',
              icon: Icons.send_rounded,
              accent: OnyxDesignTokens.amberWarning,
              onPressed: () async {
                if (widget.onOpenGuards != null) {
                  _appendCommandLedgerEntry(
                    'Support dispatch considered for ${guard.callsign}',
                    type: _LedgerType.escalation,
                  );
                  widget.onOpenGuards!.call();
                  return;
                }
                _appendCommandLedgerEntry(
                  'Support dispatch considered for ${guard.callsign}',
                  type: _LedgerType.escalation,
                );
                _showLiveOpsFeedback(
                  'Dispatch option staged for ${guard.callsign}.',
                  label: 'GUARD DISTRESS',
                  detail:
                      'Escalate to the nearest response unit or supervisor if the patrol does not recover.',
                  accent: OnyxDesignTokens.amberWarning,
                );
              },
            ),
          ],
        ),
      );
    }

    final liveClientAsk =
        controlInboxSnapshot == null ||
            controlInboxSnapshot.liveClientAsks.isEmpty
        ? null
        : controlInboxSnapshot.liveClientAsks.first;
    if (liveClientAsk != null) {
      final scopeLabel = _humanizeOpsScopeLabel(
        liveClientAsk.siteId,
        fallback: liveClientAsk.siteId,
      );
      items.add(
        _CommandDecisionItem(
          key: ValueKey(
            'live-operations-command-item-comms-${liveClientAsk.siteId}',
          ),
          severity: _CommandDecisionSeverity.actionRequired,
          label: 'Action Required',
          title: 'Client Update Needed - $scopeLabel',
          detail:
              'Client is asking for a live update from $scopeLabel. Open Client Comms to respond or log the note to the Sovereign Ledger.',
          context:
              '${_hhmm(liveClientAsk.occurredAtUtc.toLocal())} • ${liveClientAsk.author}',
          icon: Icons.call_rounded,
          accent: OnyxDesignTokens.cyanInteractive,
          onTap: () => _openCommandClientLane(
            clientId: liveClientAsk.clientId,
            siteId: liveClientAsk.siteId,
            clientCommsSnapshot: clientCommsSnapshot,
          ),
          actions: [
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-open-comms-${liveClientAsk.siteId}',
              ),
              label: 'OPEN CLIENT COMMS',
              icon: Icons.mark_chat_read_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                await _openCommandClientLane(
                  clientId: liveClientAsk.clientId,
                  siteId: liveClientAsk.siteId,
                  clientCommsSnapshot: clientCommsSnapshot,
                );
              },
            ),
            _CommandDecisionAction(
              label: 'Log to Ledger',
              icon: Icons.edit_note_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                _appendCommandLedgerEntry(
                  'Client update note saved for $scopeLabel',
                  type: _LedgerType.humanOverride,
                );
                _showLiveOpsFeedback(
                  'Client update linked to the Sovereign Ledger.',
                  label: 'LEDGER NOTE',
                  detail:
                      'Client Comms and the shift story stay synchronized without reopening the full workspace.',
                  accent: OnyxDesignTokens.cyanInteractive,
                );
              },
            ),
          ],
        ),
      );
    } else {
      final pendingDrafts = controlInboxSnapshot == null
          ? const <LiveControlInboxDraft>[]
          : _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts);
      final pendingDraft = pendingDrafts.isEmpty ? null : pendingDrafts.first;
      if (pendingDraft != null) {
        final scopeLabel = _humanizeOpsScopeLabel(
          pendingDraft.siteId,
          fallback: pendingDraft.siteId,
        );
        items.add(
          _CommandDecisionItem(
            key: ValueKey(
              'live-operations-command-item-comms-${pendingDraft.siteId}',
            ),
            severity: _CommandDecisionSeverity.actionRequired,
            label: 'Action Required',
            title: 'Client Comms Draft Ready - $scopeLabel',
            detail:
                'A shaped client reply is waiting for controller approval before it leaves Client Comms.',
            context:
                '${_hhmm(pendingDraft.createdAtUtc.toLocal())} • ${pendingDraft.providerLabel}',
            icon: Icons.mark_chat_read_rounded,
            accent: OnyxDesignTokens.cyanInteractive,
            onTap: () => _openCommandClientLane(
              clientId: pendingDraft.clientId,
              siteId: pendingDraft.siteId,
              clientCommsSnapshot: clientCommsSnapshot,
            ),
            actions: [
              _CommandDecisionAction(
                key: ValueKey(
                  'live-operations-command-action-open-comms-${pendingDraft.siteId}',
                ),
                label: 'OPEN CLIENT COMMS',
                icon: Icons.mark_chat_read_rounded,
                accent: OnyxDesignTokens.cyanInteractive,
                onPressed: () async {
                  await _openCommandClientLane(
                    clientId: pendingDraft.clientId,
                    siteId: pendingDraft.siteId,
                    clientCommsSnapshot: clientCommsSnapshot,
                  );
                },
              ),
              _CommandDecisionAction(
                label: 'Log to Ledger',
                icon: Icons.edit_note_rounded,
                accent: OnyxDesignTokens.cyanInteractive,
                onPressed: () async {
                  _appendCommandLedgerEntry(
                    'Drafted client update recorded for $scopeLabel',
                    type: _LedgerType.humanOverride,
                  );
                  _showLiveOpsFeedback(
                    'Draft handoff linked to the clean record.',
                    label: 'LEDGER NOTE',
                    detail:
                        'The client draft remains queued for approval while the controller record stays complete.',
                    accent: OnyxDesignTokens.cyanInteractive,
                  );
                },
              ),
            ],
          ),
        );
      } else if (clientCommsSnapshot != null) {
        final scopeLabel = _humanizeOpsScopeLabel(
          clientCommsSnapshot.siteId,
          fallback: clientCommsSnapshot.siteId,
        );
        final latestClientMessage =
            (clientCommsSnapshot.latestClientMessage ?? '').trim();
        final latestPendingDraft =
            (clientCommsSnapshot.latestPendingDraft ?? '').trim();
        final latestReply = (clientCommsSnapshot.latestOnyxReply ?? '').trim();
        final fallbackDetail = latestClientMessage.isNotEmpty
            ? latestClientMessage
            : latestPendingDraft.isNotEmpty
            ? 'Latest draft: $latestPendingDraft'
            : latestReply.isNotEmpty
            ? 'Latest reply: $latestReply'
            : 'Client Comms is live for this scope. Open Client Comms to respond, review history, or stage the next update.';
        final latestContextAt =
            clientCommsSnapshot.latestClientMessageAtUtc ??
            clientCommsSnapshot.latestPendingDraftAtUtc ??
            clientCommsSnapshot.latestOnyxReplyAtUtc;
        final fallbackContext = latestContextAt == null
            ? 'Client Comms activity • ${clientCommsSnapshot.telegramHealthLabel}'
            : '${_hhmm(latestContextAt.toLocal())} • ${clientCommsSnapshot.telegramHealthLabel}';
        items.add(
          _CommandDecisionItem(
            key: ValueKey(
              'live-operations-command-item-comms-${clientCommsSnapshot.siteId}',
            ),
            severity: _CommandDecisionSeverity.actionRequired,
            label: 'Action Required',
            title: 'Client Comms Active - $scopeLabel',
            detail: fallbackDetail,
            context: fallbackContext,
            icon: Icons.mark_chat_read_rounded,
            accent: OnyxDesignTokens.cyanInteractive,
            onTap: () => _openCommandClientLane(
              clientId: clientCommsSnapshot.clientId,
              siteId: clientCommsSnapshot.siteId,
              clientCommsSnapshot: clientCommsSnapshot,
            ),
            actions: [
              _CommandDecisionAction(
                key: ValueKey(
                  'live-operations-command-action-open-comms-${clientCommsSnapshot.siteId}',
                ),
                label: 'OPEN CLIENT COMMS',
                icon: Icons.mark_chat_read_rounded,
                accent: OnyxDesignTokens.cyanInteractive,
                onPressed: () async {
                  await _openCommandClientLane(
                    clientId: clientCommsSnapshot.clientId,
                    siteId: clientCommsSnapshot.siteId,
                    clientCommsSnapshot: clientCommsSnapshot,
                  );
                },
              ),
              _CommandDecisionAction(
                label: 'Log to Ledger',
                icon: Icons.edit_note_rounded,
                accent: OnyxDesignTokens.cyanInteractive,
                onPressed: () async {
                  _appendCommandLedgerEntry(
                    'Client Comms activity logged for $scopeLabel',
                    type: _LedgerType.humanOverride,
                  );
                  _showLiveOpsFeedback(
                    'Client Comms activity linked to the clean record.',
                    label: 'LEDGER NOTE',
                    detail:
                        'You can keep the command board simple while the ledger history stays attached to the shift story.',
                    accent: OnyxDesignTokens.cyanInteractive,
                  );
                },
              ),
            ],
          ),
        );
      }
    }

    final visualIncident = unresolvedIncidents
        .cast<_IncidentRecord?>()
        .firstWhere(
          (incident) =>
              incident != null &&
              !usedIncidentIds.contains(incident.id) &&
              ((incident.latestSceneReviewLabel ?? '').trim().isNotEmpty ||
                  (incident.snapshotUrl ?? '').trim().isNotEmpty ||
                  (incident.clipUrl ?? '').trim().isNotEmpty),
          orElse: () => null,
        );
    if (visualIncident != null) {
      usedIncidentIds.add(visualIncident.id);
      items.add(
        _CommandDecisionItem(
          key: ValueKey(
            'live-operations-command-item-review-${visualIncident.id}',
          ),
          severity: _CommandDecisionSeverity.review,
          label: 'Review',
          title:
              '${visualIncident.latestSceneReviewLabel ?? '${widget.videoOpsLabel} Review'} - ${visualIncident.site}',
          detail:
              (visualIncident.latestSceneReviewSummary ?? '').trim().isNotEmpty
              ? visualIncident.latestSceneReviewSummary!
              : 'Visual context is ready for controller review before you ignore, escalate, or log a ledger note.',
          context: '${visualIncident.timestamp} • ${widget.videoOpsLabel}',
          icon: Icons.videocam_outlined,
          accent: OnyxDesignTokens.amberWarning,
          onTap: () => _openCommandCctvBoard(visualIncident),
          actions: [
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-review-${visualIncident.id}',
              ),
              label: 'Review',
              icon: Icons.play_circle_outline_rounded,
              accent: OnyxDesignTokens.amberWarning,
              onPressed: () => _openCommandCctvBoard(visualIncident),
            ),
            _CommandDecisionAction(
              label: 'Log to Ledger',
              icon: Icons.edit_note_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                _appendCommandLedgerEntry(
                  'Scene review noted for ${visualIncident.id}',
                  type: _LedgerType.humanOverride,
                );
                _showLiveOpsFeedback(
                  'Scene review linked to the clean record.',
                  label: 'LEDGER NOTE',
                  detail:
                      'The controller decision stays tied to the clip and incident history.',
                  accent: OnyxDesignTokens.cyanInteractive,
                );
              },
            ),
          ],
        ),
      );
    }

    final nextIncident =
        (activeIncident != null &&
            activeIncident.status != _IncidentStatus.resolved &&
            !usedIncidentIds.contains(activeIncident.id))
        ? activeIncident
        : unresolvedIncidents.cast<_IncidentRecord?>().firstWhere(
            (incident) =>
                incident != null && !usedIncidentIds.contains(incident.id),
            orElse: () => null,
          );
    if (nextIncident != null) {
      items.add(
        _CommandDecisionItem(
          key: ValueKey(
            'live-operations-command-item-incident-${nextIncident.id}',
          ),
          severity: nextIncident.priority == _IncidentPriority.p2High
              ? _CommandDecisionSeverity.actionRequired
              : _CommandDecisionSeverity.review,
          label: nextIncident.priority == _IncidentPriority.p2High
              ? 'Action Required'
              : 'Review',
          title: '${nextIncident.type} - ${nextIncident.site}',
          detail: _commandIncidentDetail(
            nextIncident,
            critical: nextIncident.priority == _IncidentPriority.p1Critical,
          ),
          context:
              '${nextIncident.timestamp} • ${_statusLabel(nextIncident.status)}',
          icon: nextIncident.priority == _IncidentPriority.p2High
              ? Icons.assignment_late_rounded
              : Icons.visibility_rounded,
          accent: nextIncident.priority == _IncidentPriority.p2High
              ? OnyxDesignTokens.amberWarning
              : OnyxDesignTokens.cyanInteractive,
          onTap: () => _openCommandAlarmBoard(nextIncident),
          actions: [
            _CommandDecisionAction(
              key: ValueKey(
                'live-operations-command-action-review-${nextIncident.id}',
              ),
              label: 'Review',
              icon: Icons.open_in_new_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                if (widget.onOpenAlarmsForIncident != null) {
                  widget.onOpenAlarmsForIncident!(nextIncident.id);
                  return;
                }
                _focusIncidentFromBanner(nextIncident);
                await _ensureActionLadderPanelVisible();
                _showLiveOpsFeedback(
                  'Incident board focused on ${nextIncident.id}.',
                  label: 'REVIEW',
                  detail:
                      'The action ladder is now centered on the selected incident so the controller can decide quickly.',
                  accent: OnyxDesignTokens.cyanInteractive,
                );
              },
            ),
            _CommandDecisionAction(
              label: 'Log to Ledger',
              icon: Icons.edit_note_rounded,
              accent: OnyxDesignTokens.cyanInteractive,
              onPressed: () async {
                _appendCommandLedgerEntry(
                  'Controller note saved for ${nextIncident.id}',
                  type: _LedgerType.humanOverride,
                );
                _showLiveOpsFeedback(
                  'Controller note added to the clean record.',
                  label: 'LEDGER NOTE',
                  detail:
                      'The shift story now includes the controller note without opening a separate logging flow.',
                  accent: OnyxDesignTokens.cyanInteractive,
                );
              },
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _CommandDecisionItem(
          severity: _CommandDecisionSeverity.review,
          label: 'Review',
          title: 'Shift is quiet',
          detail:
              'Nothing urgent is waiting on command. Review the clean record and stay ready for the next surfaced exception.',
          context: 'LIVE • command ready',
          icon: Icons.check_circle_rounded,
          accent: const Color(0xFF10B981),
          actions: [
            _CommandDecisionAction(
              label: 'Verify Chain',
              icon: Icons.verified_rounded,
              accent: const Color(0xFF8FD1FF),
              onPressed: ledger.isEmpty
                  ? null
                  : () async {
                      _verifyLedgerChain(ledger);
                    },
            ),
          ],
        ),
      );
    }

    return items.take(5).toList(growable: false);
  }

  String _commandIncidentDetail(
    _IncidentRecord incident, {
    required bool critical,
  }) {
    final candidates = [
      incident.latestIntelSummary,
      incident.latestSceneDecisionSummary,
      incident.latestSceneReviewSummary,
    ];
    for (final candidate in candidates) {
      final trimmed = (candidate ?? '').trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    if (critical) {
      return 'Confirmed alarm or escalated signal is waiting for controller dispatch and tracking.';
    }
    if (incident.priority == _IncidentPriority.p2High) {
      return 'A controller follow-up is still needed before this incident can move out of the active shift queue.';
    }
    return 'Review the surfaced context, decide the next step, and keep the clean record attached.';
  }

  Future<void> _openCommandAlarmBoard(_IncidentRecord incident) async {
    widget.onAutoAuditAction?.call(
      'dispatch_handoff_opened',
      'Opened dispatch board from the live operations war room for ${incident.id}.',
    );
    if (widget.onOpenAlarmsForIncident != null) {
      widget.onOpenAlarmsForIncident!(incident.id);
      return;
    }
    _focusIncidentFromBanner(incident);
    await _ensureActionLadderPanelVisible();
  }

  BrainDecision _commandDecisionForIncident(
    _IncidentRecord incident, {
    required String incidentDetail,
  }) {
    final workItem = OnyxWorkItem(
      id: 'live-ops-${incident.id}-${incident.siteId}',
      intent: OnyxWorkIntent.triageIncident,
      prompt: _commandTriagePromptForIncident(
        incident,
        incidentDetail: incidentDetail,
      ),
      clientId: incident.clientId,
      siteId: incident.siteId,
      incidentReference: incident.id,
      sourceRouteLabel: 'Command',
      createdAt: DateTime.now(),
    );
    return _commandBrainDecisionForWorkItem(workItem);
  }

  BrainDecision _commandDecisionForPrompt(
    String prompt, {
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) {
    final resolvedClientId = activeIncident?.clientId.trim().isNotEmpty ?? false
        ? activeIncident!.clientId
        : (clientCommsSnapshot?.clientId ?? widget.initialScopeClientId ?? '')
              .trim();
    final resolvedSiteId = activeIncident?.siteId.trim().isNotEmpty ?? false
        ? activeIncident!.siteId
        : (clientCommsSnapshot?.siteId ?? widget.initialScopeSiteId ?? '')
              .trim();
    final incidentReference =
        (activeIncident?.id ?? widget.focusIncidentReference).trim();
    final workItem = OnyxWorkItem(
      id: 'live-ops-command-${DateTime.now().microsecondsSinceEpoch}',
      intent: OnyxWorkIntent.triageIncident,
      prompt: prompt.trim(),
      clientId: resolvedClientId,
      siteId: resolvedSiteId,
      incidentReference: incidentReference,
      sourceRouteLabel: 'Command',
      createdAt: DateTime.now(),
    );
    return _commandBrainDecisionForWorkItem(workItem);
  }

  BrainDecision _commandBrainDecisionForWorkItem(OnyxWorkItem workItem) {
    final deterministicRecommendation = _onyxCommandBrainOrchestrator
        .operatorOrchestrator
        .recommend(workItem);
    return _onyxCommandBrainOrchestrator.decide(
      item: workItem,
      decisionBias: _replayHistorySignal?.toBrainDecisionBias(),
      replayBiasStack: _replayHistoryBiasStack,
      specialistAssessments: _onyxCommandSpecialistAssessmentService.assess(
        item: workItem,
        deterministicRecommendation: deterministicRecommendation,
      ),
    );
  }

  List<BrainDecisionBias> get _replayHistoryBiasStack =>
      _replayHistorySignalStack
          .map((signal) => signal.toBrainDecisionBias())
          .whereType<BrainDecisionBias>()
          .toList(growable: false);

  Future<bool> _stageClientDraftCommandForPrompt(
    String prompt, {
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) async {
    final clientDraftService = widget.clientDraftService;
    final stageDraftForScope = widget.onStageClientDraftForScope;
    if (clientDraftService == null ||
        !clientDraftService.isConfigured ||
        stageDraftForScope == null) {
      return false;
    }
    final resolvedClientId = activeIncident?.clientId.trim().isNotEmpty ?? false
        ? activeIncident!.clientId.trim()
        : (clientCommsSnapshot?.clientId ?? widget.initialScopeClientId ?? '')
              .trim();
    final resolvedSiteId = activeIncident?.siteId.trim().isNotEmpty ?? false
        ? activeIncident!.siteId.trim()
        : (clientCommsSnapshot?.siteId ?? widget.initialScopeSiteId ?? '')
              .trim();
    if (resolvedClientId.isEmpty || resolvedSiteId.isEmpty) {
      _showLiveOpsFeedback(
        'Scope one client before drafting an update.',
        label: 'CLIENT DRAFT',
        detail:
            'ONYX needs a scoped client and site before it can stage a client update inside Client Comms.',
        accent: const Color(0xFF8EC8FF),
      );
      return true;
    }
    final incidentReference =
        (activeIncident?.id ?? widget.focusIncidentReference).trim();
    final scopeLabel = _humanizeOpsScopeLabel(
      resolvedSiteId,
      fallback: resolvedSiteId,
    );
    final draftResult = await clientDraftService.draft(
      prompt: prompt,
      clientId: resolvedClientId,
      siteId: resolvedSiteId,
      incidentReference: incidentReference,
    );
    if (!mounted) {
      return true;
    }
    stageDraftForScope(
      clientId: resolvedClientId,
      siteId: resolvedSiteId,
      draftText: draftResult.telegramDraft,
      originalDraftText: draftResult.telegramDraft,
      room: 'Residents',
      incidentReference: incidentReference,
    );
    widget.onAutoAuditAction?.call(
      'client_draft_staged',
      'Staged a client update from the live operations war room for $scopeLabel.',
    );
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.clientDraftStaged(),
    );
    _appendCommandLedgerEntry(
      'Client update staged in Client Comms from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    final openScopedLane = widget.onOpenClientViewForScope;
    if (openScopedLane != null) {
      openScopedLane(resolvedClientId, resolvedSiteId);
    } else {
      await _openClientLaneRecovery(clientCommsSnapshot);
    }
    _showLiveOpsFeedback(
      'Client update staged in Client Comms for $scopeLabel.',
      label: 'CLIENT DRAFT',
      detail:
          'ONYX drafted the next scoped update and reopened Client Comms with the message ready for controller review.',
      accent: const Color(0xFF22D3EE),
    );
    return true;
  }

  Future<bool> _answerGuardStatusCommand(String prompt) async {
    final guard = _resolveGuardForPrompt(prompt);
    if (guard == null) {
      if (!mounted) {
        return true;
      }
      _setPlainLanguagePreview(
        prompt,
        OnyxCommandSurfacePreview.answered(
          headline: 'No scoped guard is available yet',
          label: 'GUARD STATUS',
          summary:
              'ONYX needs a scoped guard check-in stream before it can answer a guard-status command.',
        ),
      );
      _appendCommandLedgerEntry(
        'Guard status requested from plain-language command',
        type: _LedgerType.systemEvent,
        actor: 'ONYX',
      );
      _showLiveOpsFeedback(
        'No scoped guard is available yet.',
        label: 'GUARD STATUS',
        detail:
            'Command stayed in place because the current scope does not have a guard vigilance signal to answer from.',
        accent: const Color(0xFF8EC8FF),
      );
      return true;
    }
    final headline = '${guard.callsign} is still active in Command.';
    final summary =
        'Last check-in ${guard.lastCheckIn}. Vigilance decay ${guard.decayLevel}%.';
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'GUARD STATUS',
        summary: summary,
      ),
      extraState: () {
        _focusedVigilanceCallsign = guard.callsign;
      },
    );
    _appendCommandLedgerEntry(
      'Guard status answered for ${guard.callsign} from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'GUARD STATUS',
      detail:
          '${guard.callsign} shows last check-in ${guard.lastCheckIn} and is carrying ${guard.decayLevel}% vigilance decay in the live rail.',
      accent: _guardStatusAccent(guard),
    );
    return true;
  }

  Future<bool> _answerPatrolReportCommand(String prompt) async {
    final patrol = _resolvePatrolReportForPrompt(prompt);
    if (patrol == null) {
      if (!mounted) {
        return true;
      }
      _setPlainLanguagePreview(
        prompt,
        OnyxCommandSurfacePreview.answered(
          headline: 'No patrol report is attached yet',
          label: 'PATROL REPORT',
          summary:
              'ONYX needs one scoped patrol completion before it can answer a patrol-report lookup.',
        ),
      );
      _appendCommandLedgerEntry(
        'Patrol report requested without scoped patrol completion',
        type: _LedgerType.systemEvent,
        actor: 'ONYX',
      );
      _showLiveOpsFeedback(
        'No patrol report is attached yet.',
        label: 'PATROL REPORT',
        detail:
            'Command stayed in place because the current scope does not have a patrol completion record to summarize.',
        accent: const Color(0xFF8EC8FF),
      );
      return true;
    }
    final guardLabel = patrol.guardId.trim().isEmpty
        ? 'The scoped guard'
        : patrol.guardId.trim();
    final routeLabel = _humanizeOpsScopeLabel(
      patrol.routeId,
      fallback: patrol.routeId,
    );
    final siteLabel = _humanizeOpsScopeLabel(
      patrol.siteId,
      fallback: patrol.siteId,
    );
    final durationMinutes = patrol.durationSeconds ~/ 60;
    final headline =
        '$guardLabel completed the last patrol at ${_hhmm(patrol.occurredAt.toLocal())}.';
    final summary = '$routeLabel • $siteLabel • Duration $durationMinutes min.';
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'PATROL REPORT',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      'Patrol report answered for $guardLabel from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'PATROL REPORT',
      detail:
          '$guardLabel completed $routeLabel in $durationMinutes minutes for $siteLabel.',
      accent: const Color(0xFF8EC8FF),
    );
    return true;
  }

  Future<bool> _answerIncidentSummaryCommand(
    String prompt, {
    required _IncidentRecord? activeIncident,
  }) async {
    final incident = activeIncident ?? _activeIncident;
    if (incident == null) {
      if (!mounted) {
        return true;
      }
      _setPlainLanguagePreview(
        prompt,
        OnyxCommandSurfacePreview.answered(
          headline: 'No active incident is pinned yet',
          label: 'INCIDENT SUMMARY',
          summary:
              'Select or seed one incident first so ONYX can summarize the current signal cleanly.',
        ),
      );
      _appendCommandLedgerEntry(
        'Incident summary requested without active incident',
        type: _LedgerType.systemEvent,
        actor: 'ONYX',
      );
      _showLiveOpsFeedback(
        'No active incident is pinned yet.',
        label: 'INCIDENT SUMMARY',
        detail:
            'Command stayed in place because there is no active incident to summarize from the current scope.',
        accent: const Color(0xFF8EC8FF),
      );
      return true;
    }
    final latestContext =
        incident.latestSceneReviewSummary?.trim().isNotEmpty ?? false
        ? incident.latestSceneReviewSummary!.trim()
        : incident.latestIntelSummary?.trim().isNotEmpty ?? false
        ? incident.latestIntelSummary!.trim()
        : 'No supporting intel summary is attached yet.';
    final headline =
        '${incident.id} is ${_statusLabel(incident.status).toLowerCase()} at ${incident.site}.';
    final summary =
        '${incident.type} with ${_incidentPriorityPromptLabel(incident.priority)} priority. $latestContext';
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'INCIDENT SUMMARY',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      'Incident summary answered for ${incident.id} from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      'Incident summary ready for ${incident.id}.',
      label: 'INCIDENT SUMMARY',
      detail:
          '${incident.id} is ${_statusLabel(incident.status).toLowerCase()} at ${incident.site} with ${_incidentPriorityPromptLabel(incident.priority).toLowerCase()} priority. $latestContext',
      accent: _incidentSummaryAccent(incident),
    );
    return true;
  }

  Future<bool> _answerUnresolvedIncidentsCommand(String prompt) async {
    final unresolvedIncidents = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .toList(growable: false);
    final headline = unresolvedIncidents.isEmpty
        ? 'No unresolved incidents are live in Command.'
        : '${unresolvedIncidents.length} unresolved incidents are live in Command.';
    final summary = unresolvedIncidents.isEmpty
        ? 'The current scope is clear. No incident is waiting for the next move.'
        : unresolvedIncidents
              .take(3)
              .map(
                (incident) =>
                    '${incident.id} • ${_statusLabel(incident.status)} • ${incident.site}',
              )
              .join('  |  ');
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'UNRESOLVED INCIDENTS',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      unresolvedIncidents.isEmpty
          ? 'Unresolved incident list answered with clear scope'
          : 'Unresolved incident list answered from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'UNRESOLVED INCIDENTS',
      detail: unresolvedIncidents.isEmpty
          ? 'Command stayed in place because there are no unresolved incidents in the current scope.'
          : 'ONYX kept the board in place and summarized the unresolved incident stack for the current scope.',
      accent: unresolvedIncidents.isEmpty
          ? const Color(0xFF10B981)
          : const Color(0xFF8EC8FF),
    );
    return true;
  }

  Future<bool> _answerTodayDispatchesCommand(String prompt) async {
    final now = DateTime.now().toLocal();
    final todayDispatches =
        _eventsInCommandScope()
            .whereType<DecisionCreated>()
            .where((event) {
              final occurredAt = event.occurredAt.toLocal();
              return occurredAt.year == now.year &&
                  occurredAt.month == now.month &&
                  occurredAt.day == now.day;
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final headline = todayDispatches.isEmpty
        ? 'No dispatches were created today.'
        : '${todayDispatches.length} dispatch${todayDispatches.length == 1 ? '' : 'es'} were created today.';
    final summary = todayDispatches.isEmpty
        ? 'The current scope has no dispatch creation events stamped for today.'
        : todayDispatches
              .take(3)
              .map(
                (dispatch) =>
                    '${dispatch.dispatchId} • ${dispatch.siteId} • ${_hhmm(dispatch.occurredAt.toLocal())}',
              )
              .join('  |  ');
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'TODAY\'S DISPATCHES',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      todayDispatches.isEmpty
          ? 'Today dispatch query answered with clear scope'
          : 'Today dispatch query answered from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'TODAY\'S DISPATCHES',
      detail: todayDispatches.isEmpty
          ? 'Command stayed in place because there are no dispatch creation events for today in the current scope.'
          : 'ONYX kept the board in place and summarized today\'s dispatch creation events for the current scope.',
      accent: todayDispatches.isEmpty
          ? const Color(0xFF10B981)
          : const Color(0xFF8EC8FF),
    );
    return true;
  }

  Future<bool> _answerSiteMostAlertsThisWeekCommand(String prompt) async {
    final window = _thisWeekWindowLocal();
    final alertCountsBySite = <String, int>{};
    for (final alert in _eventsInCommandScope(
      includeAllSitesForClient: true,
    ).whereType<IntelligenceReceived>()) {
      final occurredAt = alert.occurredAt.toLocal();
      if (occurredAt.isBefore(window.start) || occurredAt.isAfter(window.end)) {
        continue;
      }
      final siteId = alert.siteId.trim();
      if (siteId.isEmpty) {
        continue;
      }
      alertCountsBySite.update(siteId, (count) => count + 1, ifAbsent: () => 1);
    }
    final rankedSites = alertCountsBySite.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.key.compareTo(b.key);
      });
    final headline = rankedSites.isEmpty
        ? 'No alert activity landed this week.'
        : '${_humanizeOpsScopeLabel(rankedSites.first.key, fallback: rankedSites.first.key)} leads this week with ${rankedSites.first.value} alert${rankedSites.first.value == 1 ? '' : 's'}.';
    final summary = rankedSites.isEmpty
        ? 'No scoped alert intelligence landed since Monday 00:00 local time.'
        : rankedSites
              .take(3)
              .map(
                (entry) =>
                    '${_humanizeOpsScopeLabel(entry.key, fallback: entry.key)} • ${entry.value} alert${entry.value == 1 ? '' : 's'}',
              )
              .join('  |  ');
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'THIS WEEK\'S ALERT LEADER',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      rankedSites.isEmpty
          ? 'Weekly alert leader query answered with clear scope'
          : 'Weekly alert leader query answered from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'THIS WEEK\'S ALERT LEADER',
      detail: rankedSites.isEmpty
          ? 'Command stayed in place because no alert intelligence landed since Monday 00:00 local time.'
          : 'ONYX compared alert volume by site for this week and kept the board in place.',
      accent: rankedSites.isEmpty
          ? const Color(0xFF10B981)
          : const Color(0xFF8EC8FF),
    );
    return true;
  }

  Future<bool> _answerLastNightIncidentsCommand(String prompt) async {
    final window = _lastNightWindowLocal();
    final lastNightIncidents =
        _eventsInCommandScope()
            .whereType<DecisionCreated>()
            .where((event) {
              final occurredAt = event.occurredAt.toLocal();
              return !occurredAt.isBefore(window.start) &&
                  occurredAt.isBefore(window.end);
            })
            .toList(growable: false)
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final headline = lastNightIncidents.isEmpty
        ? 'No incidents were created last night.'
        : '${lastNightIncidents.length} incident${lastNightIncidents.length == 1 ? '' : 's'} landed last night.';
    final summary = lastNightIncidents.isEmpty
        ? 'No scoped incident creation events landed between 18:00 and 06:00 local time.'
        : lastNightIncidents
              .take(3)
              .map(
                (incident) =>
                    '${_incidentIdForDispatch(incident.dispatchId)} • ${incident.siteId} • ${_hhmm(incident.occurredAt.toLocal())}',
              )
              .join('  |  ');
    if (!mounted) {
      return true;
    }
    _setPlainLanguagePreview(
      prompt,
      OnyxCommandSurfacePreview.answered(
        headline: headline,
        label: 'LAST NIGHT\'S INCIDENTS',
        summary: summary,
      ),
    );
    _appendCommandLedgerEntry(
      lastNightIncidents.isEmpty
          ? 'Last night incident query answered with clear scope'
          : 'Last night incident query answered from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      headline,
      label: 'LAST NIGHT\'S INCIDENTS',
      detail: lastNightIncidents.isEmpty
          ? 'Command stayed in place because there were no incident creation events between 18:00 and 06:00 local time.'
          : 'ONYX kept the board in place and summarized the incident stack from the local 18:00 to 06:00 window.',
      accent: lastNightIncidents.isEmpty
          ? const Color(0xFF10B981)
          : const Color(0xFF8EC8FF),
    );
    return true;
  }

  _GuardVigilance? _resolveGuardForPrompt(String prompt) {
    if (_vigilance.isEmpty) {
      return null;
    }
    final normalizedPrompt = _normalizedCommandToken(prompt);
    for (final guard in _vigilance) {
      final normalizedCallsign = _normalizedCommandToken(guard.callsign);
      if (normalizedCallsign.isNotEmpty &&
          normalizedPrompt.contains(normalizedCallsign)) {
        return guard;
      }
    }
    return _focusedVigilanceGuard ?? _guardAttentionLeadFrom(_vigilance);
  }

  PatrolCompleted? _resolvePatrolReportForPrompt(String prompt) {
    final patrols = _eventsInCommandScope().whereType<PatrolCompleted>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (patrols.isEmpty) {
      return null;
    }
    final normalizedPrompt = _normalizedCommandToken(prompt);
    for (final patrol in patrols) {
      final normalizedGuard = _normalizedCommandToken(patrol.guardId);
      final normalizedRoute = _normalizedCommandToken(patrol.routeId);
      if ((normalizedGuard.isNotEmpty &&
              normalizedPrompt.contains(normalizedGuard)) ||
          (normalizedRoute.isNotEmpty &&
              normalizedPrompt.contains(normalizedRoute))) {
        return patrol;
      }
    }
    final focusedGuard = _focusedVigilanceGuard;
    if (focusedGuard != null) {
      final normalizedFocusedGuard = _normalizedCommandToken(
        focusedGuard.callsign,
      );
      for (final patrol in patrols) {
        if (_normalizedCommandToken(patrol.guardId) == normalizedFocusedGuard) {
          return patrol;
        }
      }
    }
    return patrols.first;
  }

  String _normalizedCommandToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  List<DispatchEvent> _eventsInCommandScope({
    bool includeAllSitesForClient = false,
  }) {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty;
    if (!hasScopeFocus) {
      return widget.events;
    }
    return widget.events
        .where((event) {
          final clientId = switch (event) {
            DecisionCreated value => value.clientId.trim(),
            ResponseArrived value => value.clientId.trim(),
            PartnerDispatchStatusDeclared value => value.clientId.trim(),
            GuardCheckedIn value => value.clientId.trim(),
            ExecutionCompleted value => value.clientId.trim(),
            IntelligenceReceived value => value.clientId.trim(),
            PatrolCompleted value => value.clientId.trim(),
            IncidentClosed value => value.clientId.trim(),
            _ => '',
          };
          final siteId = switch (event) {
            DecisionCreated value => value.siteId.trim(),
            ResponseArrived value => value.siteId.trim(),
            PartnerDispatchStatusDeclared value => value.siteId.trim(),
            GuardCheckedIn value => value.siteId.trim(),
            ExecutionCompleted value => value.siteId.trim(),
            IntelligenceReceived value => value.siteId.trim(),
            PatrolCompleted value => value.siteId.trim(),
            IncidentClosed value => value.siteId.trim(),
            _ => '',
          };
          if (clientId != scopeClientId) {
            return false;
          }
          if (scopeSiteId.isEmpty || includeAllSitesForClient) {
            return true;
          }
          return siteId == scopeSiteId;
        })
        .toList(growable: false);
  }

  ({DateTime start, DateTime end}) _lastNightWindowLocal() {
    final now = DateTime.now().toLocal();
    final end = DateTime(now.year, now.month, now.day, 6);
    final start = DateTime(
      end.year,
      end.month,
      end.day,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 18));
    return (start: start, end: end);
  }

  ({DateTime start, DateTime end}) _thisWeekWindowLocal() {
    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final start = todayStart.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    return (start: start, end: now);
  }

  String _incidentPriorityPromptLabel(_IncidentPriority priority) {
    return switch (priority) {
      _IncidentPriority.p1Critical => 'critical',
      _IncidentPriority.p2High => 'high',
      _IncidentPriority.p3Medium => 'medium',
      _IncidentPriority.p4Low => 'low',
    };
  }

  Color _guardStatusAccent(_GuardVigilance guard) {
    if (guard.decayLevel >= 90) {
      return const Color(0xFFEF4444);
    }
    if (guard.decayLevel >= 75) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF10B981);
  }

  Color _incidentSummaryAccent(_IncidentRecord incident) {
    return switch (incident.priority) {
      _IncidentPriority.p1Critical => const Color(0xFFEF4444),
      _IncidentPriority.p2High => const Color(0xFFF59E0B),
      _IncidentPriority.p3Medium => const Color(0xFF22D3EE),
      _IncidentPriority.p4Low => const Color(0xFF10B981),
    };
  }

  String _commandTriagePromptForIncident(
    _IncidentRecord incident, {
    required String incidentDetail,
  }) {
    return 'Triage incident ${incident.id} for ${incident.site}. '
        'Incident type: ${incident.type}. '
        'Priority: ${incident.priority.name}. '
        'Summary: $incidentDetail';
  }

  Color _commandRecommendationAccent(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => OnyxDesignTokens.redCritical,
      OnyxToolTarget.tacticalTrack => OnyxDesignTokens.redCritical,
      OnyxToolTarget.cctvReview => OnyxDesignTokens.amberWarning,
      OnyxToolTarget.clientComms => OnyxDesignTokens.cyanInteractive,
      OnyxToolTarget.reportsWorkspace => OnyxDesignTokens.purpleAdmin,
    };
  }

  IconData _commandRecommendationIcon(OnyxToolTarget target) {
    return switch (target) {
      OnyxToolTarget.dispatchBoard => Icons.warning_amber_rounded,
      OnyxToolTarget.tacticalTrack => Icons.monitor_heart_rounded,
      OnyxToolTarget.cctvReview => Icons.videocam_rounded,
      OnyxToolTarget.clientComms => Icons.mark_chat_read_rounded,
      OnyxToolTarget.reportsWorkspace => Icons.description_rounded,
    };
  }

  Future<void> _executeTypedCommandDecision({
    required _IncidentRecord incident,
    required BrainDecision decision,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) async {
    final recommendation = decision.toRecommendation();
    await _executeSurfaceRecommendation(
      incident: incident,
      recommendation: recommendation,
      clientCommsSnapshot: clientCommsSnapshot,
      sourceLabel:
          decision.decisionBias?.executionSourceLabel ?? 'typed triage',
      commandBrainSnapshot: decision.toSnapshot(),
    );
  }

  Future<void> _executeSurfaceRecommendation({
    required _IncidentRecord incident,
    required OnyxRecommendation recommendation,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required String sourceLabel,
    OnyxCommandBrainSnapshot? commandBrainSnapshot,
  }) async {
    final result = _commandToolBridgeForIncident(
      incident: incident,
      clientCommsSnapshot: clientCommsSnapshot,
    ).executeRecommendation(recommendation);
    final commandOutcome = OnyxCommandSurfaceOutcomeMemory(
      headline: result.headline,
      label: recommendation.nextMoveLabel,
      summary: result.summary,
    );
    _appendCommandLedgerEntry(
      result.executed
          ? '${recommendation.nextMoveLabel} opened from $sourceLabel'
          : '${recommendation.nextMoveLabel} staged from $sourceLabel',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      result.receipt.headline,
      label: result.receipt.label,
      detail: result.receipt.detail,
      accent: _commandRecommendationAccent(recommendation.target),
      commandBrainSnapshot: commandBrainSnapshot,
      commandOutcome: commandOutcome,
    );
  }

  OnyxToolBridge _commandToolBridgeForIncident({
    required _IncidentRecord incident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) {
    return _commandToolBridge(
      activeIncident: incident,
      clientCommsSnapshot: clientCommsSnapshot,
    );
  }

  OnyxToolBridge _commandToolBridge({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) {
    final resolvedClientId = activeIncident?.clientId.trim().isNotEmpty ?? false
        ? activeIncident!.clientId
        : (clientCommsSnapshot?.clientId ?? widget.initialScopeClientId ?? '')
              .trim();
    final resolvedSiteId = activeIncident?.siteId.trim().isNotEmpty ?? false
        ? activeIncident!.siteId
        : (clientCommsSnapshot?.siteId ?? widget.initialScopeSiteId ?? '')
              .trim();
    final openClientComms = resolvedClientId.isEmpty || resolvedSiteId.isEmpty
        ? null
        : _openClientLaneAction(
            clientId: resolvedClientId,
            siteId: resolvedSiteId,
          );
    final scopeLabel = resolvedSiteId.isNotEmpty
        ? _humanizeOpsScopeLabel(resolvedSiteId, fallback: resolvedSiteId)
        : resolvedClientId.isNotEmpty
        ? '$resolvedClientId • all sites'
        : 'Global controller scope';
    final incidentReference =
        (activeIncident?.id ?? widget.focusIncidentReference).trim();
    return OnyxToolBridge(
      scopeLabel: scopeLabel,
      incidentReference: incidentReference,
      openDispatchBoard: activeIncident == null
          ? null
          : () {
              unawaited(_openCommandAlarmBoard(activeIncident));
              return true;
            },
      openTacticalTrack: activeIncident == null
          ? null
          : () {
              unawaited(_openCommandTrackBoard(activeIncident));
              return true;
            },
      openCctvReview: activeIncident == null
          ? null
          : () {
              unawaited(_openCommandCctvBoard(activeIncident));
              return true;
            },
      openClientComms: openClientComms == null
          ? null
          : () {
              unawaited(
                _openCommandClientLane(
                  clientId: resolvedClientId,
                  siteId: resolvedSiteId,
                  clientCommsSnapshot: clientCommsSnapshot,
                ),
              );
              return true;
            },
    );
  }

  Future<void> _submitPlainLanguageCommand({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) async {
    final prompt = _commandPromptController.text.trim();
    if (prompt.isEmpty) {
      _showLiveOpsFeedback(
        'Type one command first.',
        label: 'COMMAND INPUT',
        detail:
            'Ask for one outcome, like "review cctv", "check guard route", or "open client comms".',
        accent: const Color(0xFF8EC8FF),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final parsedCommand = _commandParser.parse(prompt);
    if (parsedCommand.intent == OnyxCommandIntent.draftClientUpdate) {
      final handled = await _stageClientDraftCommandForPrompt(
        parsedCommand.prompt,
        activeIncident: activeIncident,
        clientCommsSnapshot: clientCommsSnapshot,
      );
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.patrolReportLookup) {
      final handled = await _answerPatrolReportCommand(parsedCommand.prompt);
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.guardStatusLookup) {
      final handled = await _answerGuardStatusCommand(parsedCommand.prompt);
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.showSiteMostAlertsThisWeek) {
      final handled = await _answerSiteMostAlertsThisWeekCommand(
        parsedCommand.prompt,
      );
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.showIncidentsLastNight) {
      final handled = await _answerLastNightIncidentsCommand(
        parsedCommand.prompt,
      );
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.showDispatchesToday) {
      final handled = await _answerTodayDispatchesCommand(parsedCommand.prompt);
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.showUnresolvedIncidents) {
      final handled = await _answerUnresolvedIncidentsCommand(
        parsedCommand.prompt,
      );
      if (handled) {
        return;
      }
    }
    if (parsedCommand.intent == OnyxCommandIntent.summarizeIncident) {
      final handled = await _answerIncidentSummaryCommand(
        parsedCommand.prompt,
        activeIncident: activeIncident,
      );
      if (handled) {
        return;
      }
    }
    final decision = _commandDecisionForPrompt(
      prompt,
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
    );
    final commandBrainSnapshot = decision.toSnapshot();
    final recommendation = decision.toRecommendation();
    if (mounted) {
      _setPlainLanguagePreview(
        prompt,
        OnyxCommandSurfacePreview.routed(commandBrainSnapshot),
      );
    }
    final result = _commandToolBridge(
      activeIncident: activeIncident,
      clientCommsSnapshot: clientCommsSnapshot,
    ).executeRecommendation(recommendation);
    final commandOutcome = OnyxCommandSurfaceOutcomeMemory(
      headline: result.headline,
      label: recommendation.nextMoveLabel,
      summary: result.summary,
    );
    _appendCommandLedgerEntry(
      result.executed
          ? '${recommendation.nextMoveLabel} opened from plain-language command'
          : '${recommendation.nextMoveLabel} staged from plain-language command',
      type: _LedgerType.aiAction,
      actor: 'ONYX',
    );
    _showLiveOpsFeedback(
      result.receipt.headline,
      label: result.receipt.label,
      detail: '${result.receipt.detail} Last command: "$prompt".',
      accent: _commandRecommendationAccent(recommendation.target),
      commandBrainSnapshot: commandBrainSnapshot,
      commandOutcome: commandOutcome,
    );
  }

  Future<void> _openCommandTrackBoard(_IncidentRecord incident) async {
    widget.onAutoAuditAction?.call(
      'track_handoff_opened',
      'Opened tactical track from the live operations war room for ${incident.id}.',
    );
    if (widget.onOpenTrackForIncident != null) {
      widget.onOpenTrackForIncident!(incident.id);
      return;
    }
    _focusIncidentFromBanner(incident);
    await _ensureContextAndVigilancePanelVisible();
  }

  Future<void> _openCommandCctvBoard(_IncidentRecord incident) async {
    widget.onAutoAuditAction?.call(
      'cctv_handoff_opened',
      'Opened CCTV review from the live operations war room for ${incident.id}.',
    );
    if (widget.onOpenCctvForIncident != null) {
      widget.onOpenCctvForIncident!(incident.id);
      return;
    }
    if (widget.onOpenCctv != null) {
      widget.onOpenCctv!.call();
      return;
    }
    _focusIncidentFromBanner(incident);
    if (mounted) {
      setState(() {
        _activeTab = _ContextTab.visual;
      });
    }
    await _ensureContextAndVigilancePanelVisible();
  }

  Future<void> _openCommandGuardsBoard(_GuardVigilance? guard) async {
    if (widget.onOpenGuards != null) {
      widget.onOpenGuards!.call();
      return;
    }
    if (!_showDetailedWorkspace && mounted) {
      setState(() {
        _showDetailedWorkspace = true;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureContextAndVigilancePanelVisible();
    if (guard != null) {
      _showLiveOpsFeedback(
        'Opening guard board for ${guard.callsign}.',
        label: 'GUARDS',
        detail:
            'The simplified guards page is not connected here yet, so command restored the live vigilance context instead.',
        accent: const Color(0xFFF59E0B),
      );
    }
  }

  Future<void> _openRosterPlannerFromCommand() async {
    widget.onAutoAuditAction?.call(
      'roster_planner_opened',
      'Opened the month planner from the live operations war room to close a live coverage gap.',
    );
    _appendCommandLedgerEntry(
      'Month planner opened from war room',
      type: _LedgerType.escalation,
    );
    _showLiveOpsFeedback(
      'Month planner warmed from war room.',
      label: 'ROSTER WATCH',
      detail:
          'ONYX pinned the roster gap and opened the month planner so coverage can be closed before handoff.',
      accent: widget.guardRosterSignalAccent ?? const Color(0xFFF59E0B),
    );
    if (widget.onOpenRosterPlanner != null) {
      widget.onOpenRosterPlanner!.call();
      return;
    }
    await _openCommandGuardsBoard(null);
  }

  Future<void> _openRosterAuditFromCommand() async {
    _appendCommandLedgerEntry(
      'Signed audit opened from war room',
      type: _LedgerType.systemEvent,
    );
    _showLiveOpsFeedback(
      'Signed roster audit opened from war room.',
      label: 'AUTO-AUDIT',
      detail:
          'ONYX opened the signed occurrence-book record for the planner handoff so command can verify the chain without losing the live board.',
      accent: const Color(0xFF63E6A1),
    );
    widget.onOpenRosterAudit?.call();
  }

  void _openAgentFromWarRoom(String incidentReference) {
    final normalizedIncidentReference = incidentReference.trim();
    if (normalizedIncidentReference.isEmpty) {
      return;
    }
    widget.onAutoAuditAction?.call(
      'agent_handoff_opened',
      'Opened AI Copilot from the live operations war room for $normalizedIncidentReference.',
    );
    widget.onOpenAgentForIncident?.call(normalizedIncidentReference);
  }

  Future<void> _openCommandClientLane({
    required String clientId,
    required String siteId,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) async {
    final scopeLabel = _humanizeOpsScopeLabel(siteId, fallback: siteId);
    widget.onAutoAuditAction?.call(
      'client_handoff_opened',
      'Opened Client Comms from the live operations war room for $scopeLabel.',
    );
    final openScopedLane = widget.onOpenClientViewForScope;
    if (openScopedLane != null) {
      openScopedLane(clientId, siteId);
      _showLiveOpsFeedback(
        'Opening Client Comms for $scopeLabel.',
        label: 'CLIENT COMMS',
        detail:
            'The dedicated client communications page is opening with the same scope already attached to the shift story.',
        accent: const Color(0xFF22D3EE),
      );
      return;
    }
    if (clientCommsSnapshot != null) {
      await _openClientLaneRecovery(clientCommsSnapshot);
      return;
    }
    await _openClientLaneRecovery(clientCommsSnapshot);
  }

  (Color, Color, Color, Color) _commandDecisionTone(
    _CommandDecisionSeverity severity,
  ) {
    return switch (severity) {
      _CommandDecisionSeverity.critical => (
        OnyxDesignTokens.redCritical,
        OnyxDesignTokens.redSurface,
        OnyxDesignTokens.redBorder,
        OnyxDesignTokens.redCritical,
      ),
      _CommandDecisionSeverity.actionRequired => (
        OnyxDesignTokens.amberWarning,
        OnyxDesignTokens.amberSurface,
        OnyxDesignTokens.amberBorder,
        OnyxDesignTokens.amberWarning,
      ),
      _CommandDecisionSeverity.review => (
        OnyxDesignTokens.cyanInteractive,
        OnyxDesignTokens.cyanSurface,
        OnyxDesignTokens.cyanBorder,
        OnyxDesignTokens.cyanInteractive,
      ),
    };
  }

  Widget _workspaceStatusBanner({
    required bool hasScopeFocus,
    required String scopeClientId,
    required String scopeSiteId,
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required _IncidentRecord? criticalAlertIncident,
    bool shellless = false,
    bool summaryOnly = false,
  }) {
    final queueLabel = _controlInboxTopBarQueueStateLabel();
    final contextLabel = _tabLabel(_activeTab);
    final scopeLabel = hasScopeFocus
        ? scopeSiteId.isEmpty
              ? '$scopeClientId/all sites'
              : '$scopeClientId/$scopeSiteId'
        : 'Global operations focus';
    final openClientLaneAction = clientCommsSnapshot == null
        ? null
        : _openClientLaneAction(
            clientId: clientCommsSnapshot.clientId,
            siteId: clientCommsSnapshot.siteId,
          );
    final queueFilterActive =
        _controlInboxPriorityOnly || _controlInboxCueOnlyKind != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1260;
        final desktopControls = [
          _chip(
            label: activeIncident == null
                ? 'No incident selected'
                : 'Active ${activeIncident.id}',
            foreground: OnyxDesignTokens.cyanInteractive,
            background: OnyxDesignTokens.cyanInteractive.withValues(
              alpha: 0.12,
            ),
            border: OnyxDesignTokens.cyanBorder,
            leadingIcon: Icons.hub_rounded,
          ),
          _chip(
            label: scopeLabel,
            foreground: OnyxDesignTokens.textSecondary,
            background: _commandPanelTintColor,
            border: _commandBorderColor,
            leadingIcon: Icons.map_outlined,
          ),
          _chip(
            label:
                '${_incidents.length} live incident${_incidents.length == 1 ? '' : 's'}',
            foreground: OnyxDesignTokens.textPrimary,
            background: _commandPanelTintColor,
            border: _commandBorderColor,
            leadingIcon: Icons.view_agenda_outlined,
          ),
        ];
        final actionChips = Wrap(
          spacing: 1.55,
          runSpacing: 1.55,
          children: [
            _chip(
              key: const ValueKey('live-operations-workspace-focus-lead'),
              label: activeIncident == null
                  ? 'Focus lead incident'
                  : activeIncident.id,
              foreground: OnyxDesignTokens.cyanInteractive,
              background: OnyxDesignTokens.cyanInteractive.withValues(
                alpha: 0.12,
              ),
              border: OnyxDesignTokens.cyanBorder,
              leadingIcon: Icons.center_focus_strong_rounded,
              onTap: _incidents.isEmpty ? null : _focusLeadIncident,
            ),
            if (criticalAlertIncident != null)
              _chip(
                key: const ValueKey('live-operations-workspace-focus-critical'),
                label: 'Focus critical',
                foreground: OnyxDesignTokens.redCritical,
                background: OnyxDesignTokens.redCritical.withValues(
                  alpha: 0.12,
                ),
                border: OnyxDesignTokens.redBorder,
                leadingIcon: Icons.warning_amber_rounded,
                onTap: () => _focusIncidentFromBanner(criticalAlertIncident),
              ),
            if (controlInboxSnapshot != null)
              _chip(
                key: const ValueKey('live-operations-workspace-toggle-queue'),
                label: queueFilterActive ? 'Show all replies' : queueLabel,
                foreground: OnyxDesignTokens.amberWarning,
                background: OnyxDesignTokens.amberWarning.withValues(
                  alpha: 0.12,
                ),
                border: OnyxDesignTokens.amberBorder,
                leadingIcon: Icons.schedule_rounded,
                onTap: queueFilterActive
                    ? _clearControlInboxPriorityOnly
                    : _toggleControlInboxPriorityOnly,
              ),
            if (hasScopeFocus)
              _scopeFocusBanner(
                clientId: scopeClientId,
                siteId: scopeSiteId,
                compact: true,
              ),
            if (activeIncident != null && widget.onOpenAgentForIncident != null)
              _chip(
                key: const ValueKey('live-operations-workspace-open-agent'),
                label: 'Ask Agent',
                foreground: OnyxDesignTokens.purpleAdmin,
                background: OnyxDesignTokens.purpleAdmin.withValues(
                  alpha: 0.16,
                ),
                border: OnyxDesignTokens.purpleBorder,
                leadingIcon: Icons.psychology_alt_rounded,
                onTap: () => _openAgentFromWarRoom(activeIncident.id),
              ),
            _workspaceContextChip(_ContextTab.details),
            _workspaceContextChip(_ContextTab.voip),
            _workspaceContextChip(_ContextTab.visual),
            if (openClientLaneAction != null)
              _chip(
                key: const ValueKey(
                  'live-operations-workspace-open-client-lane',
                ),
                label: 'OPEN CLIENT COMMS',
                foreground: OnyxDesignTokens.cyanInteractive,
                background: OnyxDesignTokens.cyanInteractive.withValues(
                  alpha: 0.12,
                ),
                border: OnyxDesignTokens.cyanBorder,
                leadingIcon: Icons.open_in_new_rounded,
                onTap: openClientLaneAction,
              ),
          ],
        );
        final summaryMessage = activeIncident == null
            ? 'Lead-incident recovery, queue triage, Client Comms handoff, and details, VoIP, or visual pivots stay pinned in the rail and context boards below.'
            : '${activeIncident.id} stays active while $queueLabel and $contextLabel controls remain anchored to the incident rail, reply inbox, and context board below.';
        final bannerChild = compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 15.6,
                        height: 15.6,
                        decoration: BoxDecoration(
                          color: const Color(0x1A22D3EE),
                          borderRadius: BorderRadius.circular(5.4),
                          border: Border.all(color: const Color(0x3322D3EE)),
                        ),
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Color(0xFF8FD1FF),
                          size: 8.8,
                        ),
                      ),
                      const SizedBox(width: 2.7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIVE OPERATIONS WORKSPACE',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8FAFD4),
                                fontSize: 7.1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.85,
                              ),
                            ),
                            const SizedBox(height: 0.52),
                            Text(
                              activeIncident == null
                                  ? 'No incident is selected. The rail can pin the lead incident back into the board.'
                                  : '${activeIncident.id} is active in the board while $queueLabel and $contextLabel context stay available without leaving the page.',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFEAF4FF),
                                fontSize: 8.2,
                                fontWeight: FontWeight.w700,
                                height: 1.24,
                              ),
                            ),
                            const SizedBox(height: 0.52),
                            Text(
                              '$scopeLabel • ${_incidents.length} live incident${_incidents.length == 1 ? '' : 's'} in view',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFB4C8E1),
                                fontSize: 7.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1.5),
                  actionChips,
                ],
              )
            : summaryOnly
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 1.25,
                    runSpacing: 1.0,
                    children: desktopControls,
                  ),
                  const SizedBox(height: 1.05),
                  Text(
                    summaryMessage,
                    style: GoogleFonts.inter(
                      color: _commandBodyColor,
                      fontSize: 6.5,
                      fontWeight: FontWeight.w600,
                      height: 1.32,
                    ),
                  ),
                ],
              )
            : Wrap(
                spacing: 1.25,
                runSpacing: 1.0,
                children: [...desktopControls, ...actionChips.children],
              );
        if (shellless) {
          return KeyedSubtree(
            key: const ValueKey('live-operations-workspace-status-banner'),
            child: bannerChild,
          );
        }

        return Container(
          key: const ValueKey('live-operations-workspace-status-banner'),
          width: double.infinity,
          padding: const EdgeInsets.all(1.45),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.2),
            gradient: const LinearGradient(
              colors: [Color(0xFF13131E), Color(0xFF1A1A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _commandBorderStrongColor),
            boxShadow: const [
              BoxShadow(
                color: _commandShadowColor,
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: bannerChild,
        );
      },
    );
  }

  Widget _liveOpsCommandReceiptCard() {
    final receipt = _commandReceipt;
    final canOpenLatestAudit =
        widget.latestAutoAuditReceipt != null &&
        widget.onOpenLatestAudit != null;
    final receiptReplayContextLine = _commandReceiptReplayContextLine();
    final receiptOutcomeSummary =
        receipt.continuityView.preferredOutcomeSummaryText ?? '';
    final replayHistoryLine = _commandReplayHistoryLine();
    return Container(
      key: const ValueKey('live-operations-command-receipt'),
      width: double.infinity,
      padding: const EdgeInsets.all(3.3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          receipt.accent.withValues(alpha: 0.08),
          _commandPanelColor,
        ),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: receipt.accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LATEST COMMAND',
            style: GoogleFonts.inter(
              color: const Color(0xFF4D7FAE),
              fontSize: 6.8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.46,
            ),
          ),
          const SizedBox(height: 1.5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.8, vertical: 1.5),
            decoration: BoxDecoration(
              color: receipt.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: receipt.accent.withValues(alpha: 0.45)),
            ),
            child: Text(
              receipt.label,
              style: GoogleFonts.inter(
                color: receipt.accent,
                fontSize: 7.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 1.5),
          Text(
            receipt.headline,
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 12.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 0.9),
          Text(
            receipt.detail,
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 7.4,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          if (receiptOutcomeSummary.isNotEmpty) ...[
            const SizedBox(height: 1.4),
            Text(
              receiptOutcomeSummary,
              key: const ValueKey(
                'live-operations-command-receipt-command-outcome',
              ),
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 7.1,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ],
          if (receiptReplayContextLine != null) ...[
            const SizedBox(height: 2.2),
            Text(
              'Command brain replay',
              style: GoogleFonts.inter(
                color: const Color(0xFF4D7FAE),
                fontSize: 6.8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.42,
              ),
            ),
            const SizedBox(height: 0.8),
            Text(
              receiptReplayContextLine,
              key: const ValueKey(
                'live-operations-command-receipt-command-brain-replay',
              ),
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 7.1,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ],
          if (replayHistoryLine != null) ...[
            const SizedBox(height: 2.2),
            Text(
              'Replay continuity',
              style: GoogleFonts.inter(
                color: const Color(0xFF4D7FAE),
                fontSize: 6.8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.42,
              ),
            ),
            const SizedBox(height: 0.8),
            Text(
              replayHistoryLine,
              key: const ValueKey(
                'live-operations-command-receipt-replay-history',
              ),
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 7.1,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ],
          if (canOpenLatestAudit) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey(
                  'live-operations-command-view-latest-audit',
                ),
                onPressed: widget.onOpenLatestAudit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF63E6A1),
                  side: const BorderSide(color: Color(0xFF63E6A1)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.verified_rounded, size: 14),
                label: const Text('OPEN SIGNED AUDIT'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasAgentReturnReceipt => _commandReceipt.label == 'AGENT RETURN';
  bool get _hasAutoAuditReceipt => _commandReceipt.label == 'AUTO-AUDIT';

  _LiveOpsCommandReceipt _liveOpsCommandReceiptFromAutoAudit(
    LiveOpsAutoAuditReceipt receipt,
  ) {
    return _LiveOpsCommandReceipt(
      accent: receipt.accent,
      continuityView: OnyxCommandSurfaceContinuityView(
        commandReceipt: OnyxCommandSurfaceReceiptMemory(
          label: receipt.label,
          headline: receipt.headline,
          detail: receipt.detail,
        ),
      ),
    );
  }

  void _ingestAgentReturnIncidentReference({bool fromInit = false}) {
    final ref = (widget.agentReturnIncidentReference ?? '').trim();
    if (ref.isEmpty) {
      return;
    }
    final receipt = _LiveOpsCommandReceipt(
      accent: const Color(0xFF8B5CF6),
      continuityView: OnyxCommandSurfaceContinuityView(
        commandReceipt: OnyxCommandSurfaceReceiptMemory(
          label: 'AGENT RETURN',
          headline: 'Returned from Agent for $ref.',
          detail:
              'The live operations board stayed pinned so controllers can continue from the same incident without reopening the legacy workspace.',
        ),
      ),
    );
    if (fromInit) {
      _commandReceipt = receipt;
    } else if (mounted) {
      setState(() {
        _commandReceipt = receipt;
      });
    } else {
      _commandReceipt = receipt;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onConsumeAgentReturnIncidentReference?.call(ref);
    });
  }

  Widget _workspaceContextChip(_ContextTab tab) {
    final selected = _activeTab == tab;
    return _chip(
      key: ValueKey('live-operations-workspace-tab-${tab.name}'),
      label: _tabLabel(tab),
      foreground: selected ? const Color(0xFF245A69) : const Color(0xFF556B80),
      background: selected ? const Color(0x1A9D4BFF) : const Color(0xFF1A1A2E),
      border: selected ? const Color(0xFFBEDAE1) : const Color(0xFFD4DFEA),
      leadingIcon: switch (tab) {
        _ContextTab.details => Icons.article_outlined,
        _ContextTab.voip => Icons.call_rounded,
        _ContextTab.visual => Icons.videocam_outlined,
      },
      onTap: () {
        setState(() {
          _activeTab = tab;
        });
      },
    );
  }

  Widget _workspaceShellColumn({
    required Key key,
    required String title,
    required String subtitle,
    required Widget child,
    bool shellless = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (shellless) {
          return KeyedSubtree(key: key, child: child);
        }
        return Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.all(4.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.5),
            color: const Color(0xFF13131E),
            border: Border.all(color: const Color(0xFFD6E1EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 6.9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.42,
                ),
              ),
              const SizedBox(height: 1.4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: const Color(0xFF7A8FA4),
                  fontSize: 6.9,
                  fontWeight: FontWeight.w600,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 3),
              if (boundedHeight) Expanded(child: child) else child,
            ],
          ),
        );
      },
    );
  }

  Widget _operationsDecisionDeck({
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    required _IncidentRecord? activeIncident,
    required List<_LedgerEntry> ledger,
  }) {
    final hasInbox = controlInboxSnapshot != null;
    final hasLedger = ledger.isNotEmpty;
    if (!hasInbox && !hasLedger) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 1180;
        final inboxPanel = hasInbox
            ? _controlInboxPanel(controlInboxSnapshot, compactPreview: !stack)
            : const SizedBox.shrink();
        final ledgerPanel = hasLedger
            ? _ledgerPanel(ledger, embeddedScroll: false)
            : const SizedBox.shrink();
        if (!hasInbox) {
          return ledgerPanel;
        }
        if (!hasLedger) {
          return inboxPanel;
        }
        if (stack) {
          return Column(
            children: [inboxPanel, const SizedBox(height: 4), ledgerPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 9, child: inboxPanel),
            const SizedBox(width: 4),
            Expanded(flex: 4, child: ledgerPanel),
          ],
        );
      },
    );
  }

  _IncidentRecord? get _criticalAlertIncident {
    for (final incident in _incidents) {
      if (incident.status != _IncidentStatus.resolved &&
          incident.priority == _IncidentPriority.p1Critical) {
        return incident;
      }
    }
    return null;
  }

  void _appendCommandLedgerEntry(
    String description, {
    _LedgerType type = _LedgerType.humanOverride,
    String? actor,
    String? reasonCode,
  }) {
    final entry = _LedgerEntry(
      id: 'CMD-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      description: description,
      actor: actor ?? (type == _LedgerType.humanOverride ? 'Controller' : null),
      hash: _hashFor(
        'cmd-$description-${DateTime.now().microsecondsSinceEpoch}',
      ),
      verified: true,
      reasonCode: reasonCode,
    );
    setState(() {
      _manualLedger.add(entry);
    });
    logUiAction(
      'live_operations.command_record_created',
      context: {'type': type.name, 'description': description},
    );
  }

  void _showLiveOpsFeedback(
    String message, {
    String label = 'LIVE COMMAND',
    String? detail,
    Color accent = const Color(0xFF8FD1FF),
    OnyxCommandBrainSnapshot? commandBrainSnapshot,
    OnyxCommandSurfaceOutcomeMemory? commandOutcome,
  }) {
    if (!mounted) {
      return;
    }
    final normalizedDetail =
        detail ??
        'The latest live-operations action stays pinned in the context rail while the active incident remains in focus.';
    final continuityView = OnyxCommandSurfaceMemory(
      commandBrainSnapshot: commandBrainSnapshot,
      commandReceipt: OnyxCommandSurfaceReceiptMemory(
        label: label,
        headline: message,
        detail: normalizedDetail,
        target: commandBrainSnapshot?.target,
      ),
      commandOutcome: commandOutcome,
    ).continuityView();
    final receipt = _LiveOpsCommandReceipt(
      accent: accent,
      continuityView: continuityView,
    );
    _rememberReplayBackedCommandReceipt(receipt);
    if (_desktopWorkspaceActive || commandBrainSnapshot != null) {
      if (mounted) {
        setState(() {
          _commandReceipt = receipt;
        });
      } else {
        _commandReceipt = receipt;
      }
    }
    if (_desktopWorkspaceActive) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF13131E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFD6E1EC)),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: const Color(0xFF172638),
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _visibleControlInboxDraftCount(LiveControlInboxSnapshot? snapshot) {
    if (snapshot == null) {
      return 0;
    }
    final sortedPendingDrafts = _sortedControlInboxDrafts(
      snapshot.pendingDrafts,
    );
    if (_controlInboxCueOnlyKind != null) {
      return sortedPendingDrafts.where((draft) {
        final kind = _controlInboxDraftCueKindForSignals(
          sourceText: draft.sourceText,
          replyText: draft.draftText,
          clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
          usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
        );
        return kind == _controlInboxCueOnlyKind;
      }).length;
    }
    if (_controlInboxPriorityOnly) {
      return sortedPendingDrafts.where((draft) {
        final kind = _controlInboxDraftCueKindForSignals(
          sourceText: draft.sourceText,
          replyText: draft.draftText,
          clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
          usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
        );
        return _isControlInboxPriorityCueKind(kind);
      }).length;
    }
    return sortedPendingDrafts.length;
  }

  int _sitesUnderWatchCount(LiveClientCommsSnapshot? clientCommsSnapshot) {
    final liveSites = <String>{};
    for (final incident in _incidents) {
      if (incident.status == _IncidentStatus.resolved) {
        continue;
      }
      final normalizedSiteId = incident.siteId.trim();
      final fallbackSite = incident.site.trim();
      if (normalizedSiteId.isNotEmpty) {
        liveSites.add(normalizedSiteId);
      } else if (fallbackSite.isNotEmpty) {
        liveSites.add(fallbackSite);
      }
    }
    final snapshotSiteId = clientCommsSnapshot?.siteId.trim() ?? '';
    if (snapshotSiteId.isNotEmpty) {
      liveSites.add(snapshotSiteId);
    }
    return liveSites.length;
  }

  void _focusLeadIncident() {
    if (_incidents.isEmpty) {
      return;
    }
    final leadIncident = _criticalAlertIncident ?? _incidents.first;
    if (_activeIncidentId == leadIncident.id) {
      return;
    }
    setState(() {
      _activeIncidentId = leadIncident.id;
    });
  }

  void _focusIncidentFromBanner(_IncidentRecord incident) {
    if (_activeIncidentId != incident.id) {
      setState(() {
        _activeIncidentId = incident.id;
      });
    }
  }

  Widget _criticalAlertBanner(_IncidentRecord incident) {
    final statusLabel = _statusLabel(incident.status).toUpperCase();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final detailsButton = FilledButton(
          key: const ValueKey('live-operations-critical-alert-view-details'),
          onPressed: () => _focusIncidentFromBanner(incident),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFF7F7),
            foregroundColor: const Color(0xFFB91C1C),
            side: const BorderSide(color: Color(0x66EF4444)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: Text(
            'VIEW DETAILS',
            style: GoogleFonts.inter(
              fontSize: 9.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        );
        return Container(
          key: const ValueKey('live-operations-critical-alert-banner'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF1F1), Color(0xFFFFF7F7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0x66EF4444)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14EF4444),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CRITICAL ALERT',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFB91C1C),
                            fontSize: 9.6,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${incident.id} • ${incident.type} • ${incident.site}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF172638),
                        fontSize: 10.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$statusLabel ${incident.timestamp}',
                          style: GoogleFonts.robotoMono(
                            color: const Color(0xFFB45309),
                            fontSize: 8.9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        detailsButton,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CRITICAL ALERT',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB91C1C),
                        fontSize: 9.6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0x55FFD6D6),
                    ),
                    Expanded(
                      child: Text(
                        '${incident.id} • ${incident.type} • ${incident.site}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF172638),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$statusLabel ${incident.timestamp}',
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFFB45309),
                        fontSize: 8.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    detailsButton,
                  ],
                ),
        );
      },
    );
  }

  Widget _commandOverviewGrid({
    required _IncidentRecord? activeIncident,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
    required LiveControlInboxSnapshot? controlInboxSnapshot,
    Key? gridKey,
  }) {
    final activeIncidentCount = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .length;
    final resolvedCount = _incidents
        .where((incident) => incident.status == _IncidentStatus.resolved)
        .length;
    final pendingActionCount = _visibleControlInboxDraftCount(
      controlInboxSnapshot,
    );
    final activeLaneCount = clientCommsSnapshot == null ? 0 : 1;
    final watchCount = _sitesUnderWatchCount(clientCommsSnapshot);
    final rosterAttention =
        widget.guardRosterSignalNeedsAttention &&
        (widget.guardRosterSignalHeadline ?? '').trim().isNotEmpty;
    final displayedWatchCount = watchCount > 0
        ? watchCount
        : rosterAttention
        ? 1
        : 0;
    final highPriorityCount = controlInboxSnapshot == null
        ? 0
        : _controlInboxPriorityDraftCount(
            _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts),
          );
    final leadIncident =
        _criticalAlertIncident ??
        (_incidents.isEmpty ? null : _incidents.first);
    final queueFilterActive =
        _controlInboxPriorityOnly || _controlInboxCueOnlyKind != null;
    final openClientLaneAction = clientCommsSnapshot == null
        ? null
        : _openClientLaneAction(
            clientId: clientCommsSnapshot.clientId,
            siteId: clientCommsSnapshot.siteId,
          );
    final clientLaneOverviewAction =
        openClientLaneAction ??
        () {
          _openClientLaneRecovery(clientCommsSnapshot);
        };

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth < 940 ? 2 : 4;
        final childAspectRatio = constraints.maxWidth < 520
            ? 1.12
            : constraints.maxWidth < 940
            ? 1.72
            : 2.78;
        return GridView.count(
          key: gridKey ?? const ValueKey('live-operations-command-overview'),
          crossAxisCount: columnCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _commandOverviewCard(
              key: const ValueKey(
                'live-operations-command-card-active-incidents',
              ),
              icon: Icons.graphic_eq_rounded,
              iconAccent: const Color(0xFFEF4444),
              statusLabel: 'Live',
              statusAccent: const Color(0xFFEF4444),
              value: '$activeIncidentCount',
              title: 'Alarms',
              footnote: resolvedCount > 0
                  ? '$resolvedCount cleared'
                  : 'Nothing cleared',
              footnoteIcon: Icons.trending_up_rounded,
              footnoteAccent: const Color(0xFF34D399),
              selected:
                  activeIncident != null &&
                  leadIncident != null &&
                  _activeIncidentId == leadIncident.id,
              onTap: _incidents.isEmpty ? null : _focusLeadIncident,
            ),
            _commandOverviewCard(
              key: const ValueKey(
                'live-operations-command-card-pending-actions',
              ),
              icon: Icons.schedule_rounded,
              iconAccent: const Color(0xFFF59E0B),
              statusLabel: 'Queue',
              statusAccent: const Color(0xFFF59E0B),
              value: '$pendingActionCount',
              title: 'Queue',
              footnote: controlInboxSnapshot == null
                  ? 'Inbox offline'
                  : highPriorityCount > 0
                  ? '$highPriorityCount hot'
                  : 'All clear',
              footnoteIcon: controlInboxSnapshot == null
                  ? Icons.cloud_off_rounded
                  : highPriorityCount > 0
                  ? Icons.priority_high_rounded
                  : Icons.check_circle_rounded,
              footnoteAccent: controlInboxSnapshot == null
                  ? const Color(0xFF9AB1CF)
                  : highPriorityCount > 0
                  ? const Color(0xFFF87171)
                  : const Color(0xFF34D399),
              selected: queueFilterActive,
              onTap: controlInboxSnapshot == null
                  ? () {
                      _openPendingActionsRecovery();
                    }
                  : () {
                      if (queueFilterActive) {
                        _clearControlInboxPriorityOnly();
                        return;
                      }
                      _jumpToControlInboxPanel();
                    },
            ),
            _commandOverviewCard(
              key: const ValueKey('live-operations-command-card-active-lanes'),
              icon: Icons.chat_bubble_outline_rounded,
              iconAccent: const Color(0xFF22D3EE),
              statusLabel: activeLaneCount > 0 ? 'Ready' : 'Idle',
              statusAccent: activeLaneCount > 0
                  ? const Color(0xFF22D3EE)
                  : const Color(0xFF4B6B8F),
              value: '$activeLaneCount',
              title: 'Client Comms',
              footnote: clientCommsSnapshot == null
                  ? 'Client Comms offline'
                  : 'Telegram ${clientCommsSnapshot.telegramHealthLabel}',
              footnoteIcon: clientCommsSnapshot == null
                  ? Icons.remove_circle_outline_rounded
                  : Icons.check_circle_rounded,
              footnoteAccent: clientCommsSnapshot == null
                  ? const Color(0xFF9AB1CF)
                  : _telegramHealthAccent(
                      clientCommsSnapshot.telegramHealthLabel,
                    ),
              selected: openClientLaneAction == null
                  ? _activeTab == _ContextTab.voip
                  : clientCommsSnapshot != null &&
                        activeIncident != null &&
                        activeIncident.clientId.trim() ==
                            clientCommsSnapshot.clientId.trim() &&
                        activeIncident.siteId.trim() ==
                            clientCommsSnapshot.siteId.trim(),
              onTap: clientLaneOverviewAction,
            ),
            _commandOverviewCard(
              key: const ValueKey(
                'live-operations-command-card-sites-under-watch',
              ),
              icon: Icons.visibility_rounded,
              iconAccent: rosterAttention
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981),
              statusLabel: rosterAttention
                  ? 'Gap'
                  : watchCount > 0
                  ? 'Active'
                  : 'Idle',
              statusAccent: rosterAttention
                  ? const Color(0xFFF59E0B)
                  : watchCount > 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFF4B6B8F),
              value: '$displayedWatchCount',
              title: 'Watch',
              footnote: rosterAttention
                  ? 'Roster hot'
                  : watchCount > 0
                  ? 'Coverage live'
                  : 'Coverage idle',
              footnoteIcon: rosterAttention
                  ? Icons.event_busy_rounded
                  : Icons.shield_outlined,
              footnoteAccent: rosterAttention
                  ? const Color(0xFFF59E0B)
                  : watchCount > 0
                  ? const Color(0xFF34D399)
                  : const Color(0xFF9AB1CF),
              selected: _activeTab == _ContextTab.visual,
              onTap: displayedWatchCount == 0
                  ? null
                  : () {
                      if ((_activeIncidentId ?? '').isEmpty &&
                          _incidents.isNotEmpty) {
                        _focusLeadIncident();
                      }
                      setState(() {
                        _activeTab = _ContextTab.visual;
                      });
                    },
            ),
          ],
        );
      },
    );
  }

  Widget _commandOverviewCard({
    Key? key,
    required IconData icon,
    required Color iconAccent,
    required String statusLabel,
    required Color statusAccent,
    required String value,
    required String title,
    required String footnote,
    required IconData footnoteIcon,
    required Color footnoteAccent,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final interactive = onTap != null;
    final emphasize =
        interactive &&
        value.trim() != '0' &&
        statusLabel.trim().toUpperCase() != 'CLEAR';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 140;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(compact ? 12 : 16),
              decoration: BoxDecoration(
                color: selected
                    ? Color.alphaBlend(
                        iconAccent.withValues(alpha: 0.18),
                        _commandPanelColor,
                      )
                    : emphasize
                    ? Color.alphaBlend(
                        iconAccent.withValues(alpha: 0.12),
                        _commandPanelColor,
                      )
                    : _commandPanelColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? iconAccent.withValues(alpha: 0.56)
                      : emphasize
                      ? iconAccent.withValues(alpha: 0.28)
                      : interactive
                      ? _commandBorderStrongColor
                      : _commandBorderColor,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: iconAccent.withValues(alpha: 0.18),
                          blurRadius: 14,
                          spreadRadius: 0.3,
                        ),
                      ]
                    : emphasize
                    ? [
                        BoxShadow(
                          color: iconAccent.withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusAccent,
                      shape: BoxShape.circle,
                      boxShadow: emphasize
                          ? [
                              BoxShadow(
                                color: statusAccent.withValues(alpha: 0.38),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  SizedBox(height: compact ? 7 : 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        icon,
                        size: compact ? 11 : 12,
                        color: iconAccent.withValues(alpha: 0.88),
                      ),
                      SizedBox(width: compact ? 4 : 5),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: OnyxTypographyTokens.sansFamily,
                            color: emphasize
                                ? iconAccent.withValues(alpha: 0.98)
                                : _commandMutedColor,
                            fontSize: 11,
                            fontWeight: OnyxTypographyTokens.semibold,
                            letterSpacing: 1.5,
                            height: 1.04,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 4.5 : 5.5,
                          vertical: compact ? 2.0 : 2.4,
                        ),
                        decoration: BoxDecoration(
                          color: statusAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(compact ? 6 : 7),
                          border: Border.all(
                            color: statusAccent.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Text(
                          statusLabel.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: statusAccent,
                            fontSize: compact ? 6.8 : 7.4,
                            fontWeight: FontWeight.w700,
                            letterSpacing: compact ? 0.34 : 0.46,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: OnyxTypographyTokens.sansFamily,
                      color: emphasize ? iconAccent : _commandTitleColor,
                      fontSize: 48,
                      fontWeight: OnyxTypographyTokens.extrabold,
                      height: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        footnoteIcon,
                        size: compact ? 10 : 11,
                        color: footnoteAccent,
                      ),
                      SizedBox(width: compact ? 3 : 4),
                      Expanded(
                        child: Text(
                          footnote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: footnoteAccent,
                            fontSize: compact ? 7.3 : 7.8,
                            fontWeight: FontWeight.w600,
                            height: 1.18,
                          ),
                        ),
                      ),
                      if (interactive) ...[
                        SizedBox(width: compact ? 2 : 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: compact ? 12 : 14,
                          color: OnyxDesignTokens.borderSubtle,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _topBar() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final clientCommsSnapshot = widget.clientCommsSnapshot;
    final controlInboxSnapshot = widget.controlInboxSnapshot;
    final sortedInboxDrafts = controlInboxSnapshot == null
        ? const <LiveControlInboxDraft>[]
        : _sortedControlInboxDrafts(controlInboxSnapshot.pendingDrafts);
    final priorityDraftCount = _controlInboxPriorityDraftCount(
      sortedInboxDrafts,
    );
    final filteredReplyCount = _controlInboxCueOnlyKind == null
        ? (_controlInboxPriorityOnly ? priorityDraftCount : 0)
        : _controlInboxCueKindCount(
            sortedInboxDrafts,
            _controlInboxCueOnlyKind!,
          );
    final filteredCueKind = _controlInboxCueOnlyKind;
    final hasSensitivePriorityDraft = _controlInboxHasSensitivePriorityDraft(
      sortedInboxDrafts,
    );
    final priorityChipForeground = hasSensitivePriorityDraft
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final priorityChipBackground = hasSensitivePriorityDraft
        ? const Color(0x33EF4444)
        : const Color(0x33F59E0B);
    final priorityChipBorder = hasSensitivePriorityDraft
        ? const Color(0x66EF4444)
        : const Color(0x66F59E0B);
    final focusReference = _resolvedFocusReference;
    final hasFocusReference = focusReference.isNotEmpty;
    final focusState = _focusLinkState;
    final activeCount = _incidents
        .where((incident) => incident.status != _IncidentStatus.resolved)
        .length;
    final compact = isHandsetLayout(context);
    if (compact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: _commandPanelColor,
          border: Border(bottom: BorderSide(color: _commandBorderColor)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$hh:$mm',
                  style: GoogleFonts.inter(
                    color: _commandTitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 16, color: _commandBorderColor),
                const SizedBox(width: 10),
                Text(
                  'Combat Window Active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(
                  label: '$activeCount Incidents',
                  foreground: const Color(0xFFEF4444),
                  background: const Color(0x33EF4444),
                  border: const Color(0x66EF4444),
                ),
                _chip(
                  label: _clientLaneTopBarLabel(clientCommsSnapshot),
                  foreground: _clientLaneTopBarForeground(clientCommsSnapshot),
                  background: _clientLaneTopBarBackground(clientCommsSnapshot),
                  border: _clientLaneTopBarBorder(clientCommsSnapshot),
                ),
                _chip(
                  key: const ValueKey('top-bar-queue-state-chip'),
                  label: _controlInboxTopBarQueueStateLabel(),
                  leadingIcon: _controlInboxTopBarQueueStateIcon(
                    hasSensitivePriorityDraft,
                  ),
                  tooltipMessage: _controlInboxQueueStateTooltip(),
                  foreground: _controlInboxTopBarQueueStateForeground(
                    hasSensitivePriorityDraft,
                  ),
                  background: _controlInboxTopBarQueueStateBackground(
                    hasSensitivePriorityDraft,
                  ),
                  border: _controlInboxTopBarQueueStateBorder(
                    hasSensitivePriorityDraft,
                  ),
                ),
                if (priorityDraftCount > 0)
                  _chip(
                    key: const ValueKey('top-bar-priority-chip'),
                    label: hasSensitivePriorityDraft
                        ? (priorityDraftCount == 1
                              ? '1 Sensitive Reply'
                              : '$priorityDraftCount Sensitive Replies')
                        : (priorityDraftCount == 1
                              ? '1 High-priority Reply'
                              : '$priorityDraftCount High-priority Replies'),
                    foreground: priorityChipForeground,
                    background: priorityChipBackground,
                    border: priorityChipBorder,
                    onTap: _toggleTopBarPriorityFilter,
                  ),
                if (filteredCueKind != null)
                  _chip(
                    key: const ValueKey('top-bar-cue-filter-chip'),
                    label: _controlInboxTopBarFilterLabel(filteredCueKind),
                    foreground: _controlInboxDraftCueChipAccent(
                      filteredCueKind,
                    ),
                    background: _controlInboxDraftCueChipAccent(
                      filteredCueKind,
                    ).withValues(alpha: 0.2),
                    border: _controlInboxDraftCueChipAccent(
                      filteredCueKind,
                    ).withValues(alpha: 0.45),
                    onTap: _cycleControlInboxTopBarCueFilter,
                  ),
                if (_controlInboxPriorityOnly || filteredCueKind != null)
                  _chip(
                    key: const ValueKey('top-bar-show-all-chip'),
                    label: filteredReplyCount == 1
                        ? 'Show all replies (1)'
                        : 'Show all replies ($filteredReplyCount)',
                    foreground: const Color(0xFF3F6587),
                    background: const Color(0xFFEFF4FA),
                    border: _commandBorderStrongColor,
                    onTap: _clearControlInboxPriorityOnly,
                  ),
                _chip(
                  label: '${_vigilance.length} Guards Online',
                  foreground: const Color(0xFF10B981),
                  background: const Color(0x3310B981),
                  border: const Color(0x6610B981),
                ),
                if (hasFocusReference)
                  _chip(
                    label:
                        'Focus ${_focusStateLabel(focusState)}: $focusReference',
                    foreground: _focusStateForeground(focusState),
                    background: _focusStateBackground(focusState),
                    border: _focusStateBorder(focusState),
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: _commandPanelColor,
        border: Border(bottom: BorderSide(color: _commandBorderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$hh:$mm',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 16, color: _commandBorderColor),
          const SizedBox(width: 8),
          Text(
            'Combat Window Active',
            style: GoogleFonts.inter(
              color: const Color(0xFFF59E0B),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          _chip(
            label: '$activeCount Active Incidents',
            foreground: const Color(0xFFEF4444),
            background: const Color(0x33EF4444),
            border: const Color(0x66EF4444),
          ),
          const SizedBox(width: 6),
          _chip(
            label: _clientLaneTopBarLabel(clientCommsSnapshot),
            foreground: _clientLaneTopBarForeground(clientCommsSnapshot),
            background: _clientLaneTopBarBackground(clientCommsSnapshot),
            border: _clientLaneTopBarBorder(clientCommsSnapshot),
          ),
          const SizedBox(width: 6),
          _chip(
            key: const ValueKey('top-bar-queue-state-chip'),
            label: _controlInboxTopBarQueueStateLabel(),
            leadingIcon: _controlInboxTopBarQueueStateIcon(
              hasSensitivePriorityDraft,
            ),
            tooltipMessage: _controlInboxQueueStateTooltip(),
            foreground: _controlInboxTopBarQueueStateForeground(
              hasSensitivePriorityDraft,
            ),
            background: _controlInboxTopBarQueueStateBackground(
              hasSensitivePriorityDraft,
            ),
            border: _controlInboxTopBarQueueStateBorder(
              hasSensitivePriorityDraft,
            ),
          ),
          if (priorityDraftCount > 0) ...[
            const SizedBox(width: 6),
            _chip(
              key: const ValueKey('top-bar-priority-chip'),
              label: hasSensitivePriorityDraft
                  ? (priorityDraftCount == 1
                        ? '1 Sensitive Reply'
                        : '$priorityDraftCount Sensitive Replies')
                  : (priorityDraftCount == 1
                        ? '1 High-priority Reply'
                        : '$priorityDraftCount High-priority Replies'),
              foreground: priorityChipForeground,
              background: priorityChipBackground,
              border: priorityChipBorder,
              onTap: _toggleTopBarPriorityFilter,
            ),
          ],
          if (filteredCueKind != null) ...[
            const SizedBox(width: 6),
            _chip(
              key: const ValueKey('top-bar-cue-filter-chip'),
              label: _controlInboxTopBarFilterLabel(filteredCueKind),
              foreground: _controlInboxDraftCueChipAccent(filteredCueKind),
              background: _controlInboxDraftCueChipAccent(
                filteredCueKind,
              ).withValues(alpha: 0.2),
              border: _controlInboxDraftCueChipAccent(
                filteredCueKind,
              ).withValues(alpha: 0.45),
              onTap: _cycleControlInboxTopBarCueFilter,
            ),
          ],
          if (_controlInboxPriorityOnly || filteredCueKind != null) ...[
            const SizedBox(width: 6),
            _chip(
              key: const ValueKey('top-bar-show-all-chip'),
              label: filteredReplyCount == 1
                  ? 'Show all replies (1)'
                  : 'Show all replies ($filteredReplyCount)',
              foreground: const Color(0xFF3F6587),
              background: const Color(0xFFEFF4FA),
              border: _commandBorderStrongColor,
              onTap: _clearControlInboxPriorityOnly,
            ),
          ],
          const SizedBox(width: 6),
          _chip(
            label: '${_vigilance.length} Guards Online',
            foreground: const Color(0xFF10B981),
            background: const Color(0x3310B981),
            border: const Color(0x6610B981),
          ),
          if (hasFocusReference) ...[
            const SizedBox(width: 6),
            _chip(
              label: 'Focus ${_focusStateLabel(focusState)}: $focusReference',
              foreground: _focusStateForeground(focusState),
              background: _focusStateBackground(focusState),
              border: _focusStateBorder(focusState),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clientLaneWatchPanel(
    LiveClientCommsSnapshot snapshot,
    _IncidentRecord? activeIncident,
  ) {
    final cueKind = _liveClientLaneCueKind(snapshot);
    final learnedStyleBusy = _learnedStyleBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final accent = _clientCommsAccent(snapshot);
    final linkedToActiveIncident =
        activeIncident != null &&
        activeIncident.clientId.trim() == snapshot.clientId.trim() &&
        activeIncident.siteId.trim() == snapshot.siteId.trim();
    final scopeFallback = activeIncident?.site ?? snapshot.siteId;
    final scopeLabel = _humanizeOpsScopeLabel(
      snapshot.siteId,
      fallback: scopeFallback,
    );
    final latestClientMessage = (snapshot.latestClientMessage ?? '').trim();
    final responseLabel = snapshot.pendingApprovalCount > 0
        ? 'Next ONYX reply waiting sign-off'
        : 'Latest Client Comms reply';
    final responseText = snapshot.pendingApprovalCount > 0
        ? (snapshot.latestPendingDraft ?? '').trim()
        : (snapshot.latestOnyxReply ?? '').trim();
    final responseMoment = _commsMomentLabel(
      snapshot.pendingApprovalCount > 0
          ? snapshot.latestPendingDraftAtUtc
          : snapshot.latestOnyxReplyAtUtc,
    );

    return Container(
      key: const ValueKey('client-lane-watch-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.14),
              _commandPanelColor,
            ),
            _commandPanelTintColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.8),
        border: Border.all(color: accent.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 15.2,
                height: 15.2,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4.1),
                  border: Border.all(color: accent.withValues(alpha: 0.34)),
                ),
                child: Icon(
                  Icons.mark_chat_read_rounded,
                  size: 9.0,
                  color: accent,
                ),
              ),
              const SizedBox(width: 3.6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CLIENT COMMS WATCH',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF4D7FAE),
                        fontSize: 7.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.85,
                      ),
                    ),
                    const SizedBox(height: 0.85),
                    Text(
                      '$scopeLabel • ${_clientCommsNarrative(snapshot)}',
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 8.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 0.85),
                    Text(
                      linkedToActiveIncident
                          ? 'Linked to active incident ${activeIncident.id}, so control can feel client pressure without leaving the board.'
                          : 'Watching the selected Client Comms flow so operator approval and delivery health stay visible before the next escalation.',
                      style: GoogleFonts.inter(
                        color: _commandBodyColor,
                        fontSize: 7.4,
                        fontWeight: FontWeight.w600,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
              ),
              if (_openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ) !=
                  null) ...[
                const SizedBox(width: 6),
                _compactCommandActionChip(
                  key: const ValueKey('client-lane-watch-open-client-comms'),
                  label: 'OPEN CLIENT COMMS',
                  foregroundColor: accent,
                  borderColor: accent.withValues(alpha: 0.42),
                  onTap: _openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ),
                  icon: Icons.open_in_new_rounded,
                  fontSize: 8.0,
                  minHeight: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4.25,
                  ),
                ),
              ],
              if (snapshot.learnedApprovalStyleCount > 0 &&
                  widget.onClearLearnedLaneStyleForScope != null) ...[
                const SizedBox(width: 5),
                _compactCommandActionChip(
                  key: ValueKey(
                    'client-lane-watch-clear-learned-style-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  label: 'Clear Learned Style',
                  foregroundColor: const Color(0xFF2E6EA8),
                  borderColor: _commandBorderStrongColor,
                  onTap: learnedStyleBusy
                      ? null
                      : () => _clearLearnedLaneStyle(snapshot),
                  leading: learnedStyleBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E6EA8),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  fontSize: 8.0,
                  minHeight: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4.25,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2.2),
          Wrap(
            spacing: 1.9,
            runSpacing: 1.9,
            children: [
              if (linkedToActiveIncident)
                _commsChip(
                  icon: Icons.link_rounded,
                  label: activeIncident.id,
                  accent: accent,
                ),
              _commsChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '${snapshot.clientInboundCount} client msg',
                accent: const Color(0xFF22D3EE),
              ),
              _commsChip(
                icon: Icons.verified_user_rounded,
                label: '${snapshot.pendingApprovalCount} approval',
                accent: snapshot.pendingApprovalCount > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF34D399),
              ),
              _commsChip(
                icon: Icons.tune_rounded,
                label: 'Client voice ${snapshot.clientVoiceProfileLabel}',
                accent: const Color(0xFF4B6B8F),
              ),
              _commsChip(
                icon: _controlInboxDraftCueChipIcon(cueKind),
                label: _controlInboxDraftCueChipLabel(cueKind),
                accent: _controlInboxDraftCueChipAccent(cueKind),
              ),
              if (snapshot.learnedApprovalStyleCount > 0)
                _commsChip(
                  icon: Icons.school_rounded,
                  label: 'Learned style ${snapshot.learnedApprovalStyleCount}',
                  accent: const Color(0xFF22D3EE),
                ),
              if (snapshot.pendingLearnedStyleDraftCount > 0)
                _commsChip(
                  icon: Icons.psychology_alt_rounded,
                  label: snapshot.pendingLearnedStyleDraftCount == 1
                      ? 'ONYX using learned style'
                      : 'ONYX using learned style on ${snapshot.pendingLearnedStyleDraftCount} drafts',
                  accent: const Color(0xFF67E8F9),
                ),
              _commsChip(
                icon: Icons.telegram_rounded,
                label: 'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
              ),
              _commsChip(
                icon: Icons.sms_rounded,
                label: snapshot.smsFallbackLabel,
                accent: _smsFallbackAccent(
                  snapshot.smsFallbackLabel,
                  ready: snapshot.smsFallbackReady,
                  eligibleNow: snapshot.smsFallbackEligibleNow,
                ),
              ),
              _commsChip(
                icon: Icons.phone_forwarded_rounded,
                label: snapshot.voiceReadinessLabel,
                accent: _voiceReadinessAccent(snapshot.voiceReadinessLabel),
              ),
              _commsChip(
                icon: Icons.outbox_rounded,
                label: 'Push ${snapshot.pushSyncStatusLabel.toUpperCase()}',
                accent: _pushSyncAccent(snapshot.pushSyncStatusLabel),
              ),
            ],
          ),
          if (widget.onSetLaneVoiceProfileForScope != null) ...[
            const SizedBox(height: 2.6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (laneVoiceBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8FD1FF),
                    ),
                  ),
                for (final option in const <(String, String?)>[
                  ('Auto', null),
                  ('Concise', 'concise-updates'),
                  ('Reassuring', 'reassurance-forward'),
                  ('Validation-heavy', 'validation-heavy'),
                ])
                  OutlinedButton(
                    onPressed: laneVoiceBusy
                        ? null
                        : () => _setLaneVoiceProfile(snapshot, option.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFF2E6EA8)
                          : _commandMutedColor,
                      backgroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFFEAF1FA)
                          : _commandPanelColor,
                      side: BorderSide(
                        color: _laneVoiceOptionSelected(snapshot, option.$2)
                            ? const Color(0xFF9EBBDA)
                            : _commandBorderColor,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5.0,
                        vertical: 4.0,
                      ),
                    ),
                    child: Text(
                      option.$1,
                      style: GoogleFonts.inter(
                        fontSize: 8.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 2.2),
          Text(
            _liveClientLaneCue(snapshot),
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 7.4,
              fontWeight: FontWeight.w600,
              height: 1.24,
            ),
          ),
          if (widget.onLoadCameraHealthFactPacketForScope != null ||
              _clientLaneCameraPacketForScope(snapshot) != null) ...[
            const SizedBox(height: 2.6),
            _clientLaneCameraPreviewPanel(snapshot, accent: accent),
          ],
          if (latestClientMessage.isNotEmpty) ...[
            const SizedBox(height: 2.8),
            _clientCommsTextBlock(
              label: 'Latest client ask',
              text:
                  '$latestClientMessage${_commsMomentLabel(snapshot.latestClientMessageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestClientMessageAtUtc)}'}',
              borderColor: const Color(0xFF31506F),
              textColor: _commandTitleColor,
            ),
          ],
          if (responseText.isNotEmpty) ...[
            const SizedBox(height: 2.2),
            _clientCommsTextBlock(
              label: responseLabel,
              text:
                  '$responseText${responseMoment.isEmpty ? '' : ' • $responseMoment'}',
              borderColor: accent,
              textColor: _commandTitleColor,
            ),
          ],
          if ((snapshot.latestSmsFallbackStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 2.2),
            _clientCommsTextBlock(
              label: 'Latest SMS fallback',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestSmsFallbackStatus!.trim())}${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc)}'}',
              borderColor: const Color(0xFF2E7D68),
              textColor: _commandTitleColor,
            ),
          ],
          if ((snapshot.latestVoipStageStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 2.2),
            _clientCommsTextBlock(
              label: 'Latest VoIP stage',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestVoipStageStatus!.trim())}${_commsMomentLabel(snapshot.latestVoipStageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestVoipStageAtUtc)}'}',
              borderColor: const Color(0xFF3E6AA6),
              textColor: _commandTitleColor,
            ),
          ],
          if (snapshot.recentDeliveryHistoryLines.isNotEmpty) ...[
            const SizedBox(height: 2.2),
            _clientCommsTextBlock(
              label: 'Recent delivery history',
              text: snapshot.recentDeliveryHistoryLines.join('\n'),
              borderColor: const Color(0xFF35506F),
              textColor: _commandTitleColor,
            ),
          ],
          if (snapshot.learnedApprovalStyleExample.trim().isNotEmpty) ...[
            const SizedBox(height: 2.2),
            _clientCommsTextBlock(
              label: 'Learned approval style',
              text: snapshot.learnedApprovalStyleExample.trim(),
              borderColor: const Color(0xFF245B72),
              textColor: _commandTitleColor,
            ),
          ],
          if (_clientCommsOpsFootnote(snapshot).isNotEmpty) ...[
            const SizedBox(height: 2.6),
            Text(
              _clientCommsOpsFootnote(snapshot),
              style: GoogleFonts.inter(
                color: _commandBodyColor,
                fontSize: 7.7,
                fontWeight: FontWeight.w600,
                height: 1.24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _clientLaneCameraPreviewPanel(
    LiveClientCommsSnapshot snapshot, {
    required Color accent,
  }) {
    final packet = _clientLaneCameraPacketForScope(snapshot);
    final loadFailed =
        _clientLaneCameraHealthLoadFailed &&
        _clientLaneCameraHealthScopeKey ==
            _scopeBusyKey(snapshot.clientId, snapshot.siteId);
    final loading =
        _clientLaneCameraHealthLoading &&
        _clientLaneCameraHealthScopeKey ==
            _scopeBusyKey(snapshot.clientId, snapshot.siteId);
    final previewUri = packet?.currentVisualSnapshotUri == null
        ? null
        : _cacheBustedPreviewUri(packet!.currentVisualSnapshotUri!);
    final verificationLabel = _commsMomentLabel(
      packet?.currentVisualVerifiedAtUtc ?? packet?.lastSuccessfulVisualAtUtc,
    );
    final lastProbeLabel = _commsMomentLabel(
      packet?.lastSuccessfulUpstreamProbeAtUtc,
    );
    final relayCheckLabel = _commsMomentLabel(
      packet?.currentVisualRelayCheckedAtUtc,
    );
    final relayFrameLabel = _commsMomentLabel(
      packet?.currentVisualRelayLastFrameAtUtc,
    );
    final continuousWatchStatus = (packet?.continuousVisualWatchStatus ?? '')
        .trim();
    final continuousWatchPostureLabel =
        (packet?.continuousVisualWatchPostureLabel ?? '').trim();
    final continuousWatchAttentionLabel =
        (packet?.continuousVisualWatchAttentionLabel ?? '').trim();
    final continuousWatchSourceLabel =
        (packet?.continuousVisualWatchSourceLabel ?? '').trim();
    final continuousWatchSweepLabel = _commsMomentLabel(
      packet?.continuousVisualWatchLastSweepAtUtc,
    );
    final continuousWatchCandidateLabel = _commsMomentLabel(
      packet?.continuousVisualWatchLastCandidateAtUtc,
    );
    final continuousWatchHotCameraLabel =
        (packet?.continuousVisualWatchHotCameraLabel ??
                packet?.continuousVisualWatchHotCameraId ??
                '')
            .trim();
    final continuousWatchHotZoneLabel =
        (packet?.continuousVisualWatchHotZoneLabel ?? '').trim();
    final continuousWatchHotAreaLabel =
        (packet?.continuousVisualWatchHotAreaLabel ?? '').trim();
    final continuousWatchHotPriorityLabel =
        (packet?.continuousVisualWatchHotWatchPriorityLabel ?? '').trim();
    final continuousWatchHotStreak =
        packet?.continuousVisualWatchHotCameraChangeStreakCount ?? 0;
    final continuousWatchHotStage =
        (packet?.continuousVisualWatchHotCameraChangeStage ?? '').trim();
    final continuousWatchHotSinceLabel = _commsMomentLabel(
      packet?.continuousVisualWatchHotCameraChangeActiveSinceUtc,
    );
    final continuousWatchHotScore =
        packet?.continuousVisualWatchHotCameraSceneDeltaScore;
    final correlatedContextLabel =
        (packet?.continuousVisualWatchCorrelatedContextLabel ?? '').trim();
    final correlatedPriorityLabel =
        (packet?.continuousVisualWatchCorrelatedWatchPriorityLabel ?? '')
            .trim();
    final correlatedStage =
        (packet?.continuousVisualWatchCorrelatedChangeStage ?? '').trim();
    final correlatedCameraCount =
        packet?.continuousVisualWatchCorrelatedCameraCount ?? 0;
    final correlatedSinceLabel = _commsMomentLabel(
      packet?.continuousVisualWatchCorrelatedActiveSinceUtc,
    );
    final correlatedCameraLabels =
        packet?.continuousVisualWatchCorrelatedCameraLabels ?? const <String>[];
    final relayIssue = _humanizeClientLaneRelayIssue(
      packet?.currentVisualRelayLastError,
    );
    final relayStatus = packet?.currentVisualRelayStatus;
    final localProxyStatus = packet?.scopedLocalProxyStatusLabel ?? 'unknown';
    final localProxyUpstreamStatus =
        (packet?.localProxyUpstreamStreamStatus ?? '').trim().toLowerCase();
    final localProxyLastAlertLabel = _commsMomentLabel(
      packet?.localProxyLastAlertAtUtc,
    );
    final localProxyLastSuccessLabel = _commsMomentLabel(
      packet?.localProxyLastSuccessAtUtc,
    );
    final localProxyBufferedAlertCount =
        packet?.localProxyBufferedAlertCount ?? 0;
    final localProxyIssue = _humanizeClientLaneLocalProxyIssue(
      packet?.localProxyLastError,
    );
    final previewModeLabel = _clientLaneCameraPreviewAutoRefresh
        ? 'Refreshing stills every ${_clientLaneCameraPreviewRefreshInterval.inSeconds}s'
        : 'Manual frame refresh';

    return Container(
      key: const ValueKey('client-lane-camera-preview-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT CAMERA CHECK',
                      style: GoogleFonts.inter(
                        color: accent,
                        fontSize: 7.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.85,
                      ),
                    ),
                    const SizedBox(height: 1.2),
                    Text(
                      packet == null
                          ? loadFailed
                                ? 'The scoped camera health check failed. ONYX could not verify visual confirmation for this site on the last attempt.'
                                : 'Refresh the scoped camera packet to verify whether ONYX has current visual confirmation or only recorder events.'
                          : packet.safeClientExplanation,
                      style: GoogleFonts.inter(
                        color: _commandBodyColor,
                        fontSize: 7.4,
                        fontWeight: FontWeight.w600,
                        height: 1.24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _commsChip(
                          icon: _clientLaneCameraPreviewAutoRefresh
                              ? Icons.play_circle_fill_rounded
                              : Icons.pause_circle_outline_rounded,
                          label: previewModeLabel,
                          accent: _clientLaneCameraPreviewAutoRefresh
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF59E0B),
                        ),
                        if (_clientLaneCameraPreviewAutoRefresh && !loading)
                          _commsChip(
                            icon: Icons.timelapse_rounded,
                            label: 'Operator preview only',
                            accent: const Color(0xFF8FD1FF),
                          ),
                        if (packet == null && loadFailed)
                          _commsChip(
                            icon: Icons.error_outline_rounded,
                            label: 'Load failed',
                            accent: const Color(0xFFEF4444),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _compactCommandActionChip(
                    key: ValueKey(
                      'client-lane-camera-refresh-${snapshot.clientId}-${snapshot.siteId}',
                    ),
                    label: packet?.hasCurrentVisualConfirmation == true
                        ? 'REFRESH FRAME'
                        : 'REFRESH CHECK',
                    foregroundColor: accent,
                    borderColor: accent.withValues(alpha: 0.42),
                    onTap: loading
                        ? null
                        : () => unawaited(
                            _loadClientLaneCameraHealth(showFeedback: true),
                          ),
                    leading: loading
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 14),
                    fontSize: 7.8,
                    minHeight: 26,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _compactCommandActionChip(
                    key: ValueKey(
                      'client-lane-camera-toggle-${snapshot.clientId}-${snapshot.siteId}',
                    ),
                    label: _clientLaneCameraPreviewAutoRefresh
                        ? 'PAUSE PREVIEW'
                        : 'RESUME PREVIEW',
                    foregroundColor: _clientLaneCameraPreviewAutoRefresh
                        ? const Color(0xFF2E6EA8)
                        : const Color(0xFF9A6700),
                    borderColor: _clientLaneCameraPreviewAutoRefresh
                        ? const Color(0xFFBDD0E3)
                        : const Color(0xFFE9D19A),
                    onTap: _toggleClientLaneCameraPreviewAutoRefresh,
                    leading: Icon(
                      _clientLaneCameraPreviewAutoRefresh
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 14,
                    ),
                    fontSize: 7.8,
                    minHeight: 26,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (packet != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _commsChip(
                  icon: Icons.visibility_rounded,
                  label: 'Camera ${packet.status.wireValue.toUpperCase()}',
                  accent: switch (packet.status) {
                    ClientCameraHealthStatus.live => const Color(0xFF34D399),
                    ClientCameraHealthStatus.limited => const Color(0xFFF59E0B),
                    ClientCameraHealthStatus.offline => const Color(0xFFEF4444),
                  },
                ),
                _commsChip(
                  icon: Icons.hub_rounded,
                  label:
                      'Path ${packet.path.wireValue.replaceAll('_', ' ').toUpperCase()}',
                  accent: const Color(0xFF67E8F9),
                ),
                if (packet.hasScopedLocalProxyHealth)
                  _commsChip(
                    icon: Icons.router_rounded,
                    label: _clientLaneLocalProxyChipLabel(localProxyStatus),
                    accent: _clientLaneLocalProxyStatusAccent(localProxyStatus),
                  ),
                if (packet.localProxyUpstreamStreamConnected == true ||
                    localProxyUpstreamStatus == 'connected')
                  _commsChip(
                    icon: Icons.link_rounded,
                    label: 'Upstream CONNECTED',
                    accent: const Color(0xFF34D399),
                  ),
                if (localProxyUpstreamStatus == 'reconnecting')
                  _commsChip(
                    icon: Icons.link_rounded,
                    label: 'Upstream RECONNECTING...',
                    accent: const Color(0xFFF59E0B),
                  ),
                if (localProxyBufferedAlertCount > 0)
                  _commsChip(
                    icon: Icons.notifications_active_rounded,
                    label: 'Buffered alerts $localProxyBufferedAlertCount',
                    accent: const Color(0xFF8FD1FF),
                  ),
                if (verificationLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.image_rounded,
                    label: 'Visual $verificationLabel',
                    accent: const Color(0xFF8FD1FF),
                  ),
                if (lastProbeLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.router_rounded,
                    label: 'Probe $lastProbeLabel',
                    accent: const Color(0xFFB9C8D8),
                  ),
                if (packet.hasCurrentVisualStreamRelay)
                  _commsChip(
                    icon: Icons.stream_rounded,
                    label:
                        'Relay ${_clientLaneRelayStatusLabel(relayStatus).toUpperCase()}',
                    accent: _clientLaneRelayStatusAccent(relayStatus),
                  ),
                if (packet.hasCurrentVisualConfirmation &&
                    !packet.hasCurrentVisualStreamRelay &&
                    packet.currentVisualRelayCheckedAtUtc != null)
                  _commsChip(
                    icon: Icons.stream_rounded,
                    label: 'Stream relay unavailable',
                    accent: const Color(0xFFF59E0B),
                  ),
                if (continuousWatchStatus.isNotEmpty)
                  _commsChip(
                    icon: Icons.radar_rounded,
                    label:
                        'Watch ${_clientLaneContinuousVisualWatchLabel(continuousWatchStatus).toUpperCase()}',
                    accent: _clientLaneContinuousVisualWatchAccent(
                      continuousWatchStatus,
                    ),
                  ),
                if (continuousWatchPostureLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.visibility_rounded,
                    label:
                        'Posture ${continuousWatchPostureLabel.toUpperCase()}',
                    accent: _clientLaneContinuousVisualAttentionAccent(
                      continuousWatchAttentionLabel,
                    ),
                  ),
                if (continuousWatchAttentionLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.notification_important_rounded,
                    label:
                        'Attention ${continuousWatchAttentionLabel.toUpperCase()}',
                    accent: _clientLaneContinuousVisualAttentionAccent(
                      continuousWatchAttentionLabel,
                    ),
                  ),
                if (continuousWatchSourceLabel.isNotEmpty)
                  _commsChip(
                    icon: continuousWatchSourceLabel == 'cross_camera'
                        ? Icons.account_tree_rounded
                        : Icons.center_focus_strong_rounded,
                    label: continuousWatchSourceLabel == 'cross_camera'
                        ? 'Source CROSS-CAMERA'
                        : 'Source SINGLE-CAMERA',
                    accent: continuousWatchSourceLabel == 'cross_camera'
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF67E8F9),
                  ),
                if (continuousWatchHotCameraLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.videocam_rounded,
                    label: continuousWatchHotZoneLabel.isEmpty
                        ? 'Hot $continuousWatchHotCameraLabel'
                        : 'Hot $continuousWatchHotCameraLabel • $continuousWatchHotZoneLabel',
                    accent: const Color(0xFF8FD1FF),
                  ),
                if (continuousWatchHotAreaLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.place_rounded,
                    label: 'Area ${continuousWatchHotAreaLabel.toUpperCase()}',
                    accent: const Color(0xFF67E8F9),
                  ),
                if (continuousWatchHotPriorityLabel.isNotEmpty)
                  _commsChip(
                    icon: Icons.priority_high_rounded,
                    label:
                        'Rule ${continuousWatchHotPriorityLabel.toUpperCase()} PRIORITY',
                    accent: _clientLaneContinuousVisualPriorityAccent(
                      continuousWatchHotPriorityLabel,
                    ),
                  ),
                if (continuousWatchHotStreak > 0)
                  _commsChip(
                    icon: Icons.timeline_rounded,
                    label: 'Streak x$continuousWatchHotStreak',
                    accent: continuousWatchStatus == 'alerting'
                        ? const Color(0xFFEF4444)
                        : const Color(0xFFF59E0B),
                  ),
                if (continuousWatchHotStage.isNotEmpty)
                  _commsChip(
                    icon: Icons.policy_rounded,
                    label:
                        'Deviation ${_clientLaneContinuousVisualStageLabel(continuousWatchHotStage).toUpperCase()}',
                    accent: _clientLaneContinuousVisualStageAccent(
                      continuousWatchHotStage,
                    ),
                  ),
                if (correlatedContextLabel.isNotEmpty &&
                    correlatedCameraCount > 1)
                  _commsChip(
                    icon: Icons.hub_rounded,
                    label:
                        'Correlation ${correlatedContextLabel.toUpperCase()} x$correlatedCameraCount',
                    accent: const Color(0xFF8B5CF6),
                  ),
                if (correlatedPriorityLabel.isNotEmpty &&
                    correlatedCameraCount > 1)
                  _commsChip(
                    icon: Icons.account_tree_rounded,
                    label:
                        'Cross-camera ${correlatedPriorityLabel.toUpperCase()}',
                    accent: _clientLaneContinuousVisualPriorityAccent(
                      correlatedPriorityLabel,
                    ),
                  ),
                if (correlatedStage.isNotEmpty && correlatedCameraCount > 1)
                  _commsChip(
                    icon: Icons.call_split_rounded,
                    label:
                        'Stage ${_clientLaneContinuousVisualStageLabel(correlatedStage).toUpperCase()}',
                    accent: _clientLaneContinuousVisualStageAccent(
                      correlatedStage,
                    ),
                  ),
              ],
            ),
            if ((packet.continuousVisualWatchSummary ?? '')
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                packet.continuousVisualWatchSummary!.trim(),
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 7.4,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
            ],
            if (continuousWatchHotCameraLabel.isNotEmpty ||
                continuousWatchPostureLabel.isNotEmpty ||
                correlatedContextLabel.isNotEmpty ||
                continuousWatchSweepLabel.isNotEmpty ||
                continuousWatchCandidateLabel.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                [
                  if (continuousWatchPostureLabel.isNotEmpty)
                    'Watch posture: $continuousWatchPostureLabel${continuousWatchAttentionLabel.isEmpty ? '' : ' • ${continuousWatchAttentionLabel.toLowerCase()} attention'}${continuousWatchSourceLabel.isEmpty ? '' : ' • ${continuousWatchSourceLabel == 'cross_camera' ? 'cross-camera' : 'single-camera'}'}',
                  if (correlatedContextLabel.isNotEmpty &&
                      correlatedCameraCount > 1)
                    'Cross-camera focus: $correlatedContextLabel • $correlatedCameraCount cameras${correlatedSinceLabel.isEmpty ? '' : ' • active $correlatedSinceLabel'}',
                  if (continuousWatchHotCameraLabel.isNotEmpty)
                    'Focus camera: $continuousWatchHotCameraLabel${continuousWatchHotAreaLabel.isEmpty ? '' : ' • $continuousWatchHotAreaLabel'}${continuousWatchHotScore == null ? '' : ' • delta ${(continuousWatchHotScore * 100).round()}%'}',
                  if (correlatedCameraLabels.isNotEmpty)
                    'Linked cameras: ${correlatedCameraLabels.join(', ')}.',
                  if (continuousWatchHotSinceLabel.isNotEmpty)
                    'Change since $continuousWatchHotSinceLabel.',
                  if (continuousWatchSweepLabel.isNotEmpty)
                    'Last watch sweep $continuousWatchSweepLabel.',
                  if (continuousWatchCandidateLabel.isNotEmpty)
                    'Last watch alert $continuousWatchCandidateLabel.',
                ].join(' '),
                style: GoogleFonts.inter(
                  color: _commandMutedColor,
                  fontSize: 7.1,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
            ],
            if (packet.hasScopedLocalProxyHealth) ...[
              const SizedBox(height: 5),
              Text(
                _clientLaneLocalProxySummary(
                  packet,
                  lastAlertLabel: localProxyLastAlertLabel,
                  lastSuccessLabel: localProxyLastSuccessLabel,
                ),
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 7.4,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
              if (localProxyIssue.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  localProxyIssue,
                  style: GoogleFonts.inter(
                    color: _commandMutedColor,
                    fontSize: 7.1,
                    fontWeight: FontWeight.w600,
                    height: 1.24,
                  ),
                ),
              ],
            ],
            if (packet.hasCurrentVisualStreamRelay) ...[
              const SizedBox(height: 5),
              Text(
                _clientLaneRelaySummary(
                  relayStatus,
                  relayFrameLabel: relayFrameLabel,
                  relayCheckLabel: relayCheckLabel,
                  activeClientCount:
                      packet.currentVisualRelayActiveClientCount ?? 0,
                ),
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 7.4,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                relayIssue.isNotEmpty
                    ? relayIssue
                    : 'A browser-safe player URL is ready for operator use if this stream needs to be opened outside the current surface.',
                style: GoogleFonts.inter(
                  color: _commandMutedColor,
                  fontSize: 7.1,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
            ] else if (packet.hasCurrentVisualConfirmation &&
                (relayCheckLabel.isNotEmpty || relayIssue.isNotEmpty)) ...[
              const SizedBox(height: 5),
              Text(
                [
                  'A current frame is verified, but the operator stream relay is not ready yet.',
                  if (relayCheckLabel.isNotEmpty)
                    'Last relay check: $relayCheckLabel.',
                ].join(' '),
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 7.4,
                  fontWeight: FontWeight.w600,
                  height: 1.24,
                ),
              ),
              if (relayIssue.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  relayIssue,
                  style: GoogleFonts.inter(
                    color: _commandMutedColor,
                    fontSize: 7.1,
                    fontWeight: FontWeight.w600,
                    height: 1.24,
                  ),
                ),
              ],
            ],
          ],
          if (previewUri != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  previewUri.toString(),
                  key: ValueKey(
                    'client-lane-camera-preview-image-${snapshot.clientId}-${snapshot.siteId}-$_clientLaneCameraPreviewNonce',
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1A1A2E),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'The latest frame could not be rendered in the browser. Refresh the check or copy the frame URL for direct inspection.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: _commandBodyColor,
                          fontSize: 7.6,
                          fontWeight: FontWeight.w600,
                          height: 1.24,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    [
                      'Current visual confirmation',
                      if ((packet?.currentVisualCameraId ?? '')
                          .trim()
                          .isNotEmpty)
                        packet!.currentVisualCameraId!.trim(),
                      if (verificationLabel.isNotEmpty) verificationLabel,
                    ].join(' • '),
                    style: GoogleFonts.inter(
                      color: _commandTitleColor,
                      fontSize: 7.7,
                      fontWeight: FontWeight.w700,
                      height: 1.24,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-lane-camera-copy-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: packet?.currentVisualSnapshotUri == null
                      ? null
                      : () =>
                            unawaited(_copyClientLaneCameraPreviewUrl(packet!)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E6EA8),
                    side: const BorderSide(color: _commandBorderStrongColor),
                    backgroundColor: _commandPanelColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 26),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 14),
                  label: Text(
                    'COPY FRAME URL',
                    style: GoogleFonts.inter(
                      fontSize: 7.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (packet?.hasCurrentVisualStreamRelay == true)
                  OutlinedButton.icon(
                    key: ValueKey(
                      'client-lane-camera-copy-player-${snapshot.clientId}-${snapshot.siteId}',
                    ),
                    onPressed: () =>
                        unawaited(_copyClientLaneStreamPlayerUrl(packet!)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF99F6E4)),
                      backgroundColor: _commandPanelColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      minimumSize: const Size(0, 26),
                    ),
                    icon: const Icon(Icons.stream_rounded, size: 14),
                    label: Text(
                      'COPY PLAYER URL',
                      style: GoogleFonts.inter(
                        fontSize: 7.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-lane-camera-open-live-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: packet?.currentVisualSnapshotUri == null
                      ? null
                      : () => unawaited(_openClientLaneLiveView(packet!)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2E6EA8),
                    side: const BorderSide(color: _commandBorderStrongColor),
                    backgroundColor: _commandPanelColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 26),
                  ),
                  icon: const Icon(Icons.open_in_full_rounded, size: 14),
                  label: Text(
                    'OPEN LIVE VIEW',
                    style: GoogleFonts.inter(
                      fontSize: 7.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-lane-camera-open-stream-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: packet?.hasCurrentVisualStreamRelay == true
                      ? () =>
                            unawaited(_showClientLaneStreamRelayDialog(packet!))
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF99F6E4)),
                    backgroundColor: _commandPanelColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 26),
                  ),
                  icon: const Icon(Icons.stream_rounded, size: 14),
                  label: Text(
                    'OPEN STREAM PLAYER',
                    style: GoogleFonts.inter(
                      fontSize: 7.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (!loading && packet != null) ...[
            const SizedBox(height: 6),
            Text(
              packet.hasLiveVisualAccess
                  ? 'ONYX has visual confirmation on record for this scope, but a current proxy-backed frame is not available in the browser right now.'
                  : 'No current frame is available yet. Treat this scope as event-backed or limited until a fresh visual confirmation is recorded.',
              style: GoogleFonts.inter(
                color: _commandBodyColor,
                fontSize: 7.4,
                fontWeight: FontWeight.w600,
                height: 1.24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _controlInboxPanel(
    LiveControlInboxSnapshot snapshot, {
    bool compactPreview = false,
  }) {
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.selectedClientId, snapshot.selectedSiteId),
    );
    final sortedPendingDrafts = _sortedControlInboxDrafts(
      snapshot.pendingDrafts,
    );
    final priorityDraftCount = _controlInboxPriorityDraftCount(
      sortedPendingDrafts,
    );
    final hasSensitivePriorityDraft = _controlInboxHasSensitivePriorityDraft(
      sortedPendingDrafts,
    );
    final displayedPendingDrafts = _controlInboxCueOnlyKind != null
        ? sortedPendingDrafts
              .where((draft) {
                final kind = _controlInboxDraftCueKindForSignals(
                  sourceText: draft.sourceText,
                  replyText: draft.draftText,
                  clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
                  usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
                );
                return kind == _controlInboxCueOnlyKind;
              })
              .toList(growable: false)
        : _controlInboxPriorityOnly
        ? sortedPendingDrafts
              .where((draft) {
                final kind = _controlInboxDraftCueKindForSignals(
                  sourceText: draft.sourceText,
                  replyText: draft.draftText,
                  clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
                  usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
                );
                return _isControlInboxPriorityCueKind(kind);
              })
              .toList(growable: false)
        : sortedPendingDrafts;
    final cueSummaryItems = _controlInboxCueSummaryItems(
      displayedPendingDrafts,
    );
    final cueSummaryText = _controlInboxCueSummaryText(displayedPendingDrafts);
    final accent = _controlInboxAccent(snapshot);
    final visiblePendingDrafts = compactPreview
        ? displayedPendingDrafts.take(1).toList(growable: false)
        : displayedPendingDrafts.take(3).toList(growable: false);
    final visibleClientAsks = compactPreview
        ? snapshot.liveClientAsks.take(1).toList(growable: false)
        : snapshot.liveClientAsks.take(2).toList(growable: false);
    final selectedScopeLabel = _humanizeOpsScopeLabel(
      snapshot.selectedSiteId,
      fallback: snapshot.selectedSiteId,
    );
    final selectedScopeNarrative = snapshot.selectedScopePendingCount > 0
        ? '${snapshot.selectedScopePendingCount} pending in the selected scope'
        : snapshot.awaitingResponseCount > 0
        ? '${snapshot.awaitingResponseCount} fresh client ask${snapshot.awaitingResponseCount == 1 ? '' : 's'} waiting for ONYX shaping'
        : 'selected scope is clear right now';

    return KeyedSubtree(
      key: _controlInboxPanelGlobalKey,
      child: Container(
        key: const ValueKey('control-inbox-panel'),
        width: double.infinity,
        padding: const EdgeInsets.all(4.3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.12),
                _commandPanelColor,
              ),
              _commandPanelTintColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(5.5),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: accent.withValues(alpha: 0.34)),
                  ),
                  child: Icon(Icons.inbox_rounded, size: 11.5, color: accent),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'CONTROL INBOX',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF4D7FAE),
                              fontSize: 8.6,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          if (priorityDraftCount > 0) ...[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey(
                                  'control-inbox-priority-badge',
                                ),
                                borderRadius: BorderRadius.circular(999),
                                onTap: _toggleControlInboxPriorityOnly,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _controlInboxPriorityOnly
                                        ? const Color(0x44F59E0B)
                                        : const Color(0x33F59E0B),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: _controlInboxPriorityOnly
                                          ? const Color(0x99F59E0B)
                                          : const Color(0x66F59E0B),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.priority_high_rounded,
                                        size: 10,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hasSensitivePriorityDraft
                                            ? (priorityDraftCount == 1
                                                  ? 'Sensitive 1'
                                                  : 'Sensitive $priorityDraftCount')
                                            : (priorityDraftCount == 1
                                                  ? 'High priority 1'
                                                  : 'High priority $priorityDraftCount'),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF8A5A00),
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_controlInboxPriorityOnly ||
                              _controlInboxCueOnlyKind != null) ...[
                            Container(
                              key: const ValueKey(
                                'control-inbox-filtered-chip',
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _commandPanelColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _commandBorderStrongColor,
                                ),
                              ),
                              child: Text(
                                'Filtered ${displayedPendingDrafts.length}',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF3F6587),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          Tooltip(
                            message: _controlInboxQueueStateTooltip(),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey(
                                  'control-inbox-queue-state-chip',
                                ),
                                borderRadius: BorderRadius.circular(999),
                                onTap: _cycleControlInboxQueueStateChip,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        _controlInboxTopBarQueueStateBackground(
                                          hasSensitivePriorityDraft,
                                        ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          _controlInboxTopBarQueueStateBorder(
                                            hasSensitivePriorityDraft,
                                          ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _controlInboxTopBarQueueStateIcon(
                                          hasSensitivePriorityDraft,
                                        ),
                                        size: 11,
                                        color:
                                            _controlInboxTopBarQueueStateForeground(
                                              hasSensitivePriorityDraft,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _controlInboxTopBarQueueStateLabel(),
                                        style: GoogleFonts.inter(
                                          color:
                                              _controlInboxTopBarQueueStateForeground(
                                                hasSensitivePriorityDraft,
                                              ),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!_showQueueStateHint)
                            TextButton(
                              key: const ValueKey(
                                'control-inbox-show-queue-hint',
                              ),
                              onPressed: () {
                                setState(() {
                                  _restoreQueueStateHint();
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2E6EA8),
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Show tip again',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_showQueueStateHint) ...[
                        const SizedBox(height: 6),
                        Container(
                          key: const ValueKey('control-inbox-queue-hint'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBDD6EA)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF7DD3FC),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Tip: tap the queue chip to move between full and high-priority views. Long press it for a quick explanation of the current mode.',
                                  style: GoogleFonts.inter(
                                    color: _commandBodyColor,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TextButton(
                                onPressed: _dismissQueueStateHint,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF2E6EA8),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Hide tip',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        snapshot.pendingApprovalCount > 0
                            ? '${snapshot.pendingApprovalCount} client repl${snapshot.pendingApprovalCount == 1 ? 'y' : 'ies'} waiting for operator judgement'
                            : snapshot.awaitingResponseCount > 0
                            ? '${snapshot.awaitingResponseCount} live client ask${snapshot.awaitingResponseCount == 1 ? '' : 's'} waiting for response shaping'
                            : 'No client replies are waiting for approval',
                        style: GoogleFonts.inter(
                          color: _commandTitleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$selectedScopeLabel • $selectedScopeNarrative',
                        style: GoogleFonts.inter(
                          color: _commandBodyColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_openClientLaneAction(
                      clientId: snapshot.selectedClientId,
                      siteId: snapshot.selectedSiteId,
                    ) !=
                    null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openClientLaneAction(
                      clientId: snapshot.selectedClientId,
                      siteId: snapshot.selectedSiteId,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      backgroundColor: _commandPanelColor,
                      side: BorderSide(color: accent.withValues(alpha: 0.42)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 15),
                    label: Text(
                      'OPEN CLIENT COMMS',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                _commsChip(
                  icon: Icons.verified_user_rounded,
                  label: '${snapshot.pendingApprovalCount} waiting',
                  accent: snapshot.pendingApprovalCount > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF34D399),
                ),
                _commsChip(
                  icon: Icons.mark_chat_unread_rounded,
                  label: '${snapshot.awaitingResponseCount} live ask',
                  accent: snapshot.awaitingResponseCount > 0
                      ? const Color(0xFF22D3EE)
                      : const Color(0xFF4B6B8F),
                ),
                _commsChip(
                  icon: Icons.pin_drop_rounded,
                  label:
                      '$selectedScopeLabel • ${snapshot.selectedScopePendingCount}',
                  accent: snapshot.selectedScopePendingCount > 0
                      ? accent
                      : const Color(0xFF4B6B8F),
                ),
                _commsChip(
                  icon: Icons.tune_rounded,
                  label:
                      'Client voice ${snapshot.selectedScopeClientVoiceProfileLabel}',
                  accent: const Color(0xFF4B6B8F),
                ),
                _commsChip(
                  icon: Icons.telegram_rounded,
                  label:
                      'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                  accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
                ),
                if (snapshot.telegramFallbackActive)
                  _commsChip(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Fallback active',
                    accent: const Color(0xFFF97316),
                  ),
              ],
            ),
            if (cueSummaryItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Semantics(
                label: cueSummaryText,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queue shape',
                      style: GoogleFonts.inter(
                        color: _commandMutedColor,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w700,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final item in cueSummaryItems)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: ValueKey(
                                'control-inbox-summary-pill-${_controlInboxCueSummaryLabel(item.$1)}',
                              ),
                              borderRadius: BorderRadius.circular(999),
                              onTap: () =>
                                  _toggleControlInboxCueOnlyKind(item.$1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_controlInboxCueOnlyKind == item.$1
                                              ? _controlInboxDraftCueChipAccent(
                                                  item.$1,
                                                )
                                              : _controlInboxDraftCueChipAccent(
                                                  item.$1,
                                                ))
                                          .withValues(
                                            alpha:
                                                _controlInboxCueOnlyKind ==
                                                    item.$1
                                                ? 0.26
                                                : 0.16,
                                          ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        _controlInboxDraftCueChipAccent(
                                          item.$1,
                                        ).withValues(
                                          alpha:
                                              _controlInboxCueOnlyKind ==
                                                  item.$1
                                              ? 0.74
                                              : 0.48,
                                        ),
                                  ),
                                ),
                                child: Text(
                                  '${item.$2} ${_controlInboxCueSummaryLabel(item.$1)}',
                                  style: GoogleFonts.inter(
                                    color: _controlInboxDraftCueChipAccent(
                                      item.$1,
                                    ),
                                    fontSize: 9.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_controlInboxCueOnlyKind != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Showing ${_controlInboxCueSummaryLabel(_controlInboxCueOnlyKind!)} only. Tap the same pill again or use Show all replies to return to the full queue.',
                  style: GoogleFonts.inter(
                    color: _controlInboxDraftCueChipAccent(
                      _controlInboxCueOnlyKind!,
                    ),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ] else if (_controlInboxPriorityOnly) ...[
                const SizedBox(height: 3),
                Text(
                  'Showing high-priority only. Tap the badge again to return to the full queue.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFE1A8),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                  ),
                ),
              ],
            ],
            if (widget.onSetLaneVoiceProfileForScope != null &&
                !compactPreview) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (laneVoiceBusy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8FD1FF),
                      ),
                    ),
                  for (final option in const <(String, String?)>[
                    ('Auto', null),
                    ('Concise', 'concise-updates'),
                    ('Reassuring', 'reassurance-forward'),
                    ('Validation-heavy', 'validation-heavy'),
                  ])
                    OutlinedButton(
                      onPressed: laneVoiceBusy
                          ? null
                          : () => _setLaneVoiceProfile(
                              LiveClientCommsSnapshot(
                                clientId: snapshot.selectedClientId,
                                siteId: snapshot.selectedSiteId,
                                clientVoiceProfileLabel: snapshot
                                    .selectedScopeClientVoiceProfileLabel,
                              ),
                              option.$2,
                            ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _laneVoiceOptionSelectedForLabel(
                              snapshot.selectedScopeClientVoiceProfileLabel,
                              option.$2,
                            )
                            ? const Color(0xFF245A86)
                            : const Color(0xFF6C8198),
                        backgroundColor:
                            _laneVoiceOptionSelectedForLabel(
                              snapshot.selectedScopeClientVoiceProfileLabel,
                              option.$2,
                            )
                            ? const Color(0xFFEAF4FF)
                            : Colors.transparent,
                        side: BorderSide(
                          color:
                              _laneVoiceOptionSelectedForLabel(
                                snapshot.selectedScopeClientVoiceProfileLabel,
                                option.$2,
                              )
                              ? const Color(0xFF9FC3E6)
                              : const Color(0xFFD6E4F2),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      child: Text(
                        option.$1,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (snapshot.pendingDrafts.isEmpty)
              Text(
                visibleClientAsks.isEmpty
                    ? 'The inbox is clear. New client questions and approval drafts will stage here for command.'
                    : 'Client questions are active even though no reply drafts are waiting yet.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF9FB7D5),
                  fontSize: 10.2,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              )
            else
              Column(
                children: visiblePendingDrafts
                    .map(_controlInboxDraftCard)
                    .toList(growable: false),
              ),
            if (visibleClientAsks.isNotEmpty) ...[
              if (visiblePendingDrafts.isNotEmpty) const SizedBox(height: 3),
              Text(
                'LIVE CLIENT ASKS',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FAFD4),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: visibleClientAsks
                    .map(_controlInboxClientAskCard)
                    .toList(growable: false),
              ),
            ],
            if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty &&
                !compactPreview) ...[
              const SizedBox(height: 6),
              Text(
                ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
                  snapshot.telegramHealthDetail!.trim(),
                ),
                style: GoogleFonts.inter(
                  color: const Color(0xFF8FA7C8),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlInboxClientAskCard(LiveControlInboxClientAsk ask) {
    final accent = ask.matchesSelectedScope
        ? const Color(0xFF22D3EE)
        : const Color(0xFF4B6B8F);
    final scopeLabel = _humanizeOpsScopeLabel(ask.siteId, fallback: ask.siteId);
    final providerLabel = ask.messageProvider.trim().isEmpty
        ? 'Client Comms'
        : ask.messageProvider.trim();

    return Container(
      key: ValueKey(
        'control-inbox-ask-${ask.clientId}-${ask.siteId}-${ask.occurredAtUtc.toIso8601String()}',
      ),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$scopeLabel • ${ask.author.trim().isEmpty ? 'Client' : ask.author.trim()}',
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$providerLabel • ${_commsMomentLabel(ask.occurredAtUtc)}',
                      style: GoogleFonts.inter(
                        color: _commandMutedColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_openClientLaneAction(
                    clientId: ask.clientId,
                    siteId: ask.siteId,
                  ) !=
                  null)
                _compactCommandActionChip(
                  label: 'Shape Reply',
                  foregroundColor: accent,
                  borderColor: accent.withValues(alpha: 0.42),
                  onTap: _openClientLaneAction(
                    clientId: ask.clientId,
                    siteId: ask.siteId,
                  ),
                  icon: Icons.open_in_new_rounded,
                  fontSize: 10.5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _commsChip(
                icon: ask.matchesSelectedScope
                    ? Icons.my_location_rounded
                    : Icons.travel_explore_rounded,
                label: ask.matchesSelectedScope
                    ? 'Selected scope'
                    : 'Other scope',
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _clientCommsTextBlock(
            label: 'Client asked',
            text: ask.body.trim(),
            borderColor: accent,
            textColor: _commandTitleColor,
          ),
        ],
      ),
    );
  }

  Widget _controlInboxDraftCard(LiveControlInboxDraft draft) {
    final accent = draft.matchesSelectedScope
        ? const Color(0xFF22D3EE)
        : const Color(0xFFF59E0B);
    final cueKind = _controlInboxDraftCueKindForSignals(
      sourceText: draft.sourceText,
      replyText: draft.draftText,
      clientVoiceProfileLabel: draft.clientVoiceProfileLabel,
      usesLearnedApprovalStyle: draft.usesLearnedApprovalStyle,
    );
    final scopeLabel = _humanizeOpsScopeLabel(
      draft.siteId,
      fallback: draft.siteId,
    );
    final busy = _controlInboxBusyDraftIds.contains(draft.updateId);

    return Container(
      key: ValueKey('control-inbox-draft-${draft.updateId}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$scopeLabel • Draft #${draft.updateId}',
                style: GoogleFonts.inter(
                  color: _commandTitleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${draft.providerLabel.trim().isEmpty ? 'AI provider' : draft.providerLabel.trim()} • ${_commsMomentLabel(draft.createdAtUtc)}',
                style: GoogleFonts.inter(
                  color: _commandMutedColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _commsChip(
                    icon: draft.matchesSelectedScope
                        ? Icons.my_location_rounded
                        : Icons.travel_explore_rounded,
                    label: draft.matchesSelectedScope
                        ? 'Selected scope'
                        : 'Other scope',
                    accent: accent,
                  ),
                  _commsChip(
                    icon: Icons.tune_rounded,
                    label: 'Voice ${draft.clientVoiceProfileLabel}',
                    accent: const Color(0xFF4B6B8F),
                  ),
                  _commsChip(
                    icon: _controlInboxDraftCueChipIcon(cueKind),
                    label: _controlInboxDraftCueChipLabel(cueKind),
                    accent: _controlInboxDraftCueChipAccent(cueKind),
                  ),
                  if (draft.clientVoiceProfileLabel.trim().toLowerCase() !=
                      'auto')
                    _commsChip(
                      icon: Icons.auto_fix_high_rounded,
                      label: 'Voice-adjusted',
                      accent: const Color(0xFF34D399),
                    ),
                  if (draft.usesLearnedApprovalStyle)
                    _commsChip(
                      icon: Icons.psychology_alt_rounded,
                      label: 'Uses learned approval style',
                      accent: const Color(0xFF67E8F9),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _clientCommsTextBlock(
            label: 'Client asked',
            text: draft.sourceText.trim(),
            borderColor: const Color(0xFF31465F),
            textColor: _commandTitleColor,
          ),
          const SizedBox(height: 6),
          _clientCommsTextBlock(
            label: 'ONYX draft',
            text: draft.draftText.trim(),
            borderColor: accent,
            textColor: _commandTitleColor,
          ),
          const SizedBox(height: 6),
          Text(
            _controlInboxDraftCue(draft),
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              height: 1.32,
            ),
          ),
          if (draft.usesLearnedApprovalStyle) ...[
            const SizedBox(height: 6),
            Text(
              'This draft is already leaning on learned approval wording from this Client Comms flow.',
              style: GoogleFonts.inter(
                color: _commandBodyColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilledButton.icon(
                onPressed: widget.onApproveClientReplyDraft == null || busy
                    ? null
                    : () => _approveControlInboxDraft(draft),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D5B),
                  foregroundColor: const Color(0xFFF8FBFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 13),
                label: Text(
                  'Approve + Send',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    widget.onUpdateClientReplyDraftText == null ||
                        busy ||
                        _controlInboxDraftEditBusyIds.contains(draft.updateId)
                    ? null
                    : () => _editControlInboxDraft(draft),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E6EA8),
                  backgroundColor: _commandPanelColor,
                  side: const BorderSide(color: _commandBorderStrongColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.edit_rounded, size: 13),
                label: Text(
                  'Edit Draft',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: widget.onRejectClientReplyDraft == null || busy
                    ? null
                    : () => _rejectControlInboxDraft(draft),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171),
                  backgroundColor: _commandPanelColor,
                  side: const BorderSide(color: Color(0xFFE4B5BB)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 13),
                label: Text(
                  'Reject',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_openClientLaneAction(
                    clientId: draft.clientId,
                    siteId: draft.siteId,
                  ) !=
                  null)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : _openClientLaneAction(
                          clientId: draft.clientId,
                          siteId: draft.siteId,
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    backgroundColor: _commandPanelColor,
                    side: BorderSide(color: accent.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 13),
                  label: Text(
                    'OPEN CLIENT COMMS',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _incidentQueuePanel({required bool embeddedScroll}) {
    final wide = embeddedScroll;
    final activeIncident = _activeIncident;
    final criticalIncident = _criticalAlertIncident;
    Widget incidentTile(int index) {
      final incident = _incidents[index];
      final priority = _priorityStyle(incident.priority);
      final isActive = incident.id == _activeIncidentId;
      final isP1 = incident.priority == _IncidentPriority.p1Critical;
      final railAccent = isActive
          ? const Color(0xFF22D3EE)
          : priority.foreground;
      final queueToneLabel = switch (incident.priority) {
        _IncidentPriority.p1Critical => 'DO NOW',
        _IncidentPriority.p2High => 'HOT',
        _ => priority.label.toUpperCase(),
      };
      final actionHintLabel = switch (incident.status) {
        _IncidentStatus.triaging => isP1 ? 'OPEN BOARD NOW' : 'OPEN BOARD',
        _IncidentStatus.dispatched => 'TRACK UNIT',
        _IncidentStatus.investigating => 'CHECK VISUAL',
        _IncidentStatus.resolved => 'HOLD WATCH',
      };
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 180 + (index * 50)),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset((1 - value) * 12, 0),
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          key: Key('incident-card-${incident.id}'),
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive
                ? const Color(0x4422D3EE)
                : isP1
                ? const Color(0x24EF4444)
                : const Color(0xFF13131E),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF4FDFFF)
                  : priority.border.withValues(alpha: 0.55),
            ),
            boxShadow: [
              if (isActive)
                const BoxShadow(
                  color: Color(0x5522D3EE),
                  blurRadius: 24,
                  spreadRadius: 1.5,
                ),
              if (isP1)
                const BoxShadow(
                  color: Color(0x30EF4444),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4.5, color: railAccent),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  key: ValueKey('live-operations-incident-tile-${incident.id}'),
                  onTap: () {
                    setState(() {
                      _activeIncidentId = incident.id;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 250;
                        final statusRow = Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: _statusChipColor(
                                  incident.status,
                                ).withValues(alpha: 0.16),
                                border: Border.all(
                                  color: _statusChipColor(
                                    incident.status,
                                  ).withValues(alpha: 0.44),
                                ),
                              ),
                              child: Text(
                                _statusLabel(incident.status),
                                style: GoogleFonts.inter(
                                  color: _statusChipColor(incident.status),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: railAccent.withValues(alpha: 0.14),
                                border: Border.all(
                                  color: railAccent.withValues(alpha: 0.38),
                                ),
                              ),
                              child: Text(
                                'NEXT $actionHintLabel',
                                style: GoogleFonts.inter(
                                  color: railAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (isActive)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22D3EE),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'YOU',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF22D3EE),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                        final priorityChip = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: priority.background,
                            border: Border.all(color: priority.border),
                          ),
                          child: Text(
                            queueToneLabel,
                            style: GoogleFonts.inter(
                              color: priority.foreground,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  priority.icon,
                                  color: priority.foreground,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              incident.id,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.robotoMono(
                                                color: const Color(0xFF22D3EE),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            incident.timestamp,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF8BA3C4),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        incident.type,
                                        maxLines: compact ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF172638),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SITE ${incident.site}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF556B80),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      statusRow,
                                    ],
                                  ),
                                ),
                                if (!compact) ...[
                                  const SizedBox(width: 6),
                                  priorityChip,
                                ],
                              ],
                            ),
                            if (compact) ...[
                              const SizedBox(height: 8),
                              priorityChip,
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final queueSummaryHeader = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 260;
        Widget summaryChip({
          required String label,
          required String value,
          required Color foreground,
          required Color background,
          required Color border,
        }) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 0.92,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE6F0FF),
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
              ],
            ),
          );
        }

        final content = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            summaryChip(
              label: 'LIVE',
              value: '${_incidents.length}',
              foreground: const Color(0xFF4ADE80),
              background: const Color(0x1A10B981),
              border: const Color(0x6610B981),
            ),
            summaryChip(
              label: 'RED',
              value:
                  '${_incidents.where((incident) => incident.priority == _IncidentPriority.p1Critical).length}',
              foreground: const Color(0xFFF87171),
              background: const Color(0x1AEF4444),
              border: const Color(0x66EF4444),
            ),
            summaryChip(
              label: 'HOT',
              value:
                  '${_incidents.where((incident) => incident.priority == _IncidentPriority.p2High).length}',
              foreground: const Color(0xFFFBBF24),
              background: const Color(0x1AF59E0B),
              border: const Color(0x66F59E0B),
            ),
          ],
        );

        return compact
            ? content
            : Align(alignment: Alignment.centerLeft, child: content);
      },
    );

    if (wide) {
      return _panel(
        title: 'Incident Queue',
        subtitle: 'Tap one incident. Work one move.',
        shellless: true,
        child: ListView(
          key: const ValueKey('live-operations-incident-queue-scroll-view'),
          children: [
            _incidentQueueFocusCard(
              activeIncident: activeIncident,
              criticalIncident: criticalIncident,
            ),
            const SizedBox(height: 10),
            queueSummaryHeader,
            const SizedBox(height: 8),
            for (var i = 0; i < _incidents.length; i++) ...[
              incidentTile(i),
              if (i < _incidents.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      );
    }

    return _panel(
      title: 'Incident Queue',
      subtitle: 'Tap one incident. Work one move.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          queueSummaryHeader,
          const SizedBox(height: 8),
          Column(
            children: [
              for (var i = 0; i < _incidents.length; i++) ...[
                incidentTile(i),
                if (i < _incidents.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _incidentQueueFocusCard({
    required _IncidentRecord? activeIncident,
    required _IncidentRecord? criticalIncident,
  }) {
    final queueLabel = _controlInboxTopBarQueueStateLabel();
    final selectedIncident =
        activeIncident ?? (_incidents.isEmpty ? null : _incidents.first);
    final priorityStyle = selectedIncident == null
        ? null
        : _priorityStyle(selectedIncident.priority);
    final focusInstruction = switch (selectedIncident?.status) {
      _IncidentStatus.triaging
          when selectedIncident?.priority == _IncidentPriority.p1Critical =>
        'Critical incident live. Move now.',
      _IncidentStatus.triaging => 'Board is ready. Make the next call.',
      _IncidentStatus.dispatched => 'Unit is moving. Track and verify.',
      _IncidentStatus.investigating => 'Visual proof is up. Check it now.',
      _IncidentStatus.resolved => 'Hold watch. Keep the record clean.',
      null => 'Pick the lead incident or open the full queue.',
    };
    final focusContext =
        selectedIncident?.latestIntelHeadline?.trim().isNotEmpty == true
        ? selectedIncident!.latestIntelHeadline!.trim()
        : selectedIncident == null
        ? 'Queue ready.'
        : '${selectedIncident.site} is the live incident in hand.';
    final criticalCount = _incidents
        .where((incident) => incident.priority == _IncidentPriority.p1Critical)
        .length;

    return Container(
      key: const ValueKey('live-operations-incident-focus-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          colors: [
            if (selectedIncident?.priority == _IncidentPriority.p1Critical)
              const Color(0xFFFFF3F3)
            else if (selectedIncident != null)
              const Color(0xFFF3F9FD)
            else
              _commandPanelTintColor,
            _commandPanelColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: selectedIncident?.priority == _IncidentPriority.p1Critical
              ? const Color(0xFFE6B5B5)
              : selectedIncident != null
              ? const Color(0xFFBFD7E6)
              : _commandBorderStrongColor,
        ),
        boxShadow: [
          BoxShadow(
            color: selectedIncident?.priority == _IncidentPriority.p1Critical
                ? const Color(0x12EF4444)
                : selectedIncident != null
                ? const Color(0x1222D3EE)
                : _commandShadowColor,
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final actionWrap = Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _chip(
                key: const ValueKey(
                  'live-operations-incident-focus-open-board',
                ),
                label: 'Board',
                foreground: const Color(0xFF0F6D84),
                background: const Color(0xFFEAF8FB),
                border: const Color(0xFF9DD3E4),
                leadingIcon: Icons.view_compact_alt_outlined,
                onTap: () => _openIncidentQueueBoardFocus(selectedIncident),
              ),
              _chip(
                key: const ValueKey(
                  'live-operations-incident-focus-open-details',
                ),
                label: 'Details',
                foreground: _activeTab == _ContextTab.details
                    ? const Color(0xFF0F6D84)
                    : _commandMutedColor,
                background: _activeTab == _ContextTab.details
                    ? const Color(0xFFEAF8FB)
                    : _commandPanelColor,
                border: _activeTab == _ContextTab.details
                    ? const Color(0xFF9DD3E4)
                    : _commandBorderColor,
                leadingIcon: Icons.article_outlined,
                onTap: () => _openIncidentQueueContextFocus(
                  selectedIncident,
                  _ContextTab.details,
                ),
              ),
              _chip(
                key: const ValueKey(
                  'live-operations-incident-focus-open-queue',
                ),
                label: 'Queue',
                foreground: const Color(0xFF8A6500),
                background: const Color(0xFFFFF7E8),
                border: const Color(0xFFE6D2A2),
                leadingIcon: Icons.schedule_rounded,
                onTap: _openIncidentQueueQueueFocus,
              ),
              _chip(
                key: const ValueKey('live-operations-incident-focus-lead'),
                label: selectedIncident == null
                    ? 'Lead lane'
                    : selectedIncident.id,
                foreground: const Color(0xFF0F6D84),
                background: const Color(0xFFEFF7FD),
                border: const Color(0xFFB7D6EB),
                leadingIcon: Icons.center_focus_strong_rounded,
                onTap: _incidents.isEmpty ? null : _focusLeadIncident,
              ),
              if (criticalIncident != null)
                _chip(
                  key: const ValueKey(
                    'live-operations-incident-focus-focus-critical',
                  ),
                  label: 'Critical',
                  foreground: const Color(0xFFB93838),
                  background: const Color(0xFFFFF0F0),
                  border: const Color(0xFFE6B5B5),
                  leadingIcon: Icons.warning_amber_rounded,
                  onTap: () =>
                      _focusCriticalIncidentFromQueue(criticalIncident),
                ),
            ],
          );

          final summaryColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          priorityStyle?.background ?? const Color(0x1422D3EE),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: priorityStyle?.border ?? const Color(0x3322D3EE),
                      ),
                    ),
                    child: Icon(
                      priorityStyle?.icon ?? Icons.hub_rounded,
                      color:
                          priorityStyle?.foreground ?? const Color(0xFF8FD1FF),
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOU ARE HERE',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF0F6D84),
                            fontSize: 8.8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedIncident == null
                              ? 'QUEUE READY'
                              : selectedIncident.id,
                          style: GoogleFonts.inter(
                            color: _commandMutedColor,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.55,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedIncident?.type ?? 'War room queue ready',
                          style: GoogleFonts.inter(
                            color: _commandTitleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color:
                      selectedIncident?.priority == _IncidentPriority.p1Critical
                      ? const Color(0xFFFFF4F4)
                      : selectedIncident != null
                      ? const Color(0xFFEAF8FB)
                      : const Color(0xFFEFFAF4),
                  border: Border.all(
                    color:
                        selectedIncident?.priority ==
                            _IncidentPriority.p1Critical
                        ? const Color(0xFFE6B5B5)
                        : selectedIncident != null
                        ? const Color(0xFFB7DCE8)
                        : const Color(0xFFCBE4D6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DO THIS',
                      style: GoogleFonts.inter(
                        color:
                            selectedIncident?.priority ==
                                _IncidentPriority.p1Critical
                            ? const Color(0xFFB93838)
                            : selectedIncident != null
                            ? const Color(0xFF0F6D84)
                            : const Color(0xFF1D7A52),
                        fontSize: 8.6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      focusInstruction,
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      focusContext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: _commandBodyColor,
                        fontSize: 9.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _chip(
                    label: 'LIVE ${_incidents.length}',
                    foreground: const Color(0xFF0F6D84),
                    background: const Color(0xFFEAF8FB),
                    border: const Color(0xFF9DD3E4),
                    leadingIcon: Icons.hub_rounded,
                  ),
                  _chip(
                    label: 'RED $criticalCount',
                    foreground: const Color(0xFFB93838),
                    background: const Color(0xFFFFF0F0),
                    border: const Color(0xFFE6B5B5),
                    leadingIcon: Icons.priority_high_rounded,
                  ),
                  _chip(
                    label: queueLabel.toUpperCase(),
                    foreground: const Color(0xFF8A6500),
                    background: const Color(0xFFFFF7E8),
                    border: const Color(0xFFE6D2A2),
                    leadingIcon: Icons.schedule_rounded,
                  ),
                  if (selectedIncident != null)
                    _chip(
                      key: const ValueKey(
                        'live-operations-incident-focus-active-chip',
                      ),
                      label:
                          '${selectedIncident.site} • ${_statusLabel(selectedIncident.status)}',
                      foreground: _statusChipColor(selectedIncident.status),
                      background: _statusChipColor(
                        selectedIncident.status,
                      ).withValues(alpha: 0.16),
                      border: _statusChipColor(
                        selectedIncident.status,
                      ).withValues(alpha: 0.42),
                      leadingIcon: Icons.location_on_outlined,
                    ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summaryColumn, const SizedBox(height: 6), actionWrap],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: summaryColumn),
              const SizedBox(width: 6),
              Expanded(flex: 8, child: actionWrap),
            ],
          );
        },
      ),
    );
  }

  Widget _actionLadderPanel(
    _IncidentRecord? activeIncident, {
    required bool embeddedScroll,
  }) {
    final steps = _ladderStepsFor(activeIncident);
    final wide = embeddedScroll;
    Widget stepTile(int index) {
      final step = steps[index];
      final isActive = step.status == _LadderStepStatus.active;
      final statusColor = _stepColor(step.status);
      return Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: isActive
              ? statusColor.withValues(alpha: 0.08)
              : const Color(0xFF1A1A2E),
          border: Border.all(
            color: isActive
                ? statusColor.withValues(alpha: 0.32)
                : const Color(0xFFD6E1EC),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 52,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF22D3EE)
                    : const Color(0x0022D3EE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 6),
            Icon(_stepIcon(step.status), color: statusColor, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.name,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF172638),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        _stepLabel(step.status),
                        style: GoogleFonts.inter(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if ((step.timestamp ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.timestamp!,
                      style: GoogleFonts.robotoMono(
                        color: const Color(0xFF7A8FA4),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((step.details ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.details!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF556B80),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if ((step.metadata ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.metadata!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF8ED3FF),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if ((step.thinkingMessage ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.thinkingMessage!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF22D3EE),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (step.status == _LadderStepStatus.active ||
                      step.status == _LadderStepStatus.thinking) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        OutlinedButton(
                          onPressed: activeIncident == null
                              ? null
                              : () => _openOverrideDialog(activeIncident),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x66EF4444)),
                            foregroundColor: const Color(0xFFEF4444),
                            backgroundColor: const Color(0xFFFFF7F7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Override'),
                        ),
                        OutlinedButton(
                          onPressed: activeIncident == null
                              ? null
                              : () => _pauseAutomation(activeIncident),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0x333B82F6)),
                            foregroundColor: const Color(0xFF315A86),
                            backgroundColor: const Color(0xFF13131E),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Pause'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Widget stepsList;
    if (steps.isEmpty) {
      stepsList = Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.playlist_add_check_rounded,
              color: _commandMutedColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Pin the lead incident to load the action steps.',
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      stepsList = wide
          ? ListView.separated(
              itemCount: steps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 5),
              itemBuilder: (context, index) => stepTile(index),
            )
          : Column(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  stepTile(i),
                  if (i < steps.length - 1) const SizedBox(height: 5),
                ],
              ],
            );
    }
    return KeyedSubtree(
      key: _actionLadderPanelGlobalKey,
      child: _panel(
        title: 'Action Ladder',
        subtitle: 'One incident. One move. No guesswork.',
        shellless: wide,
        child: Column(
          children: [
            _actionLadderFocusCard(activeIncident, steps),
            const SizedBox(height: 6),
            if (wide) Expanded(child: stepsList) else stepsList,
          ],
        ),
      ),
    );
  }

  Widget _actionLadderFocusCard(
    _IncidentRecord? activeIncident,
    List<_LadderStep> steps,
  ) {
    final priorityStyle = activeIncident == null
        ? null
        : _priorityStyle(activeIncident.priority);
    final statusColor = activeIncident == null
        ? const Color(0xFF8FAFD4)
        : _statusChipColor(activeIncident.status);
    final currentStep = steps.firstWhere(
      (step) =>
          step.status == _LadderStepStatus.active ||
          step.status == _LadderStepStatus.thinking ||
          step.status == _LadderStepStatus.blocked,
      orElse: () => steps.isNotEmpty
          ? steps.first
          : const _LadderStep(
              id: 'standby',
              name: 'Awaiting lead incident',
              status: _LadderStepStatus.pending,
            ),
    );
    final summary =
        activeIncident?.latestSceneReviewSummary?.trim().isNotEmpty == true
        ? activeIncident!.latestSceneReviewSummary!.trim()
        : activeIncident?.latestIntelSummary?.trim().isNotEmpty == true
        ? activeIncident!.latestIntelSummary!.trim()
        : activeIncident?.latestIntelHeadline?.trim().isNotEmpty == true
        ? activeIncident!.latestIntelHeadline!.trim()
        : activeIncident == null
        ? 'Pin the lead incident back into the board to reopen override, queue, and context controls from one surface.'
        : '${currentStep.name} is driving the current response path while the queue and right-rail context stay available.';
    final queueLabel = _controlInboxTopBarQueueStateLabel();
    final primaryAccent = currentStep.status == _LadderStepStatus.blocked
        ? const Color(0xFFEF4444)
        : _activeTab == _ContextTab.voip
        ? const Color(0xFF3B82F6)
        : _activeTab == _ContextTab.visual
        ? const Color(0xFF10B981)
        : const Color(0xFF22D3EE);
    final commandLead = activeIncident == null
        ? 'PICK THE LEAD LANE'
        : currentStep.status == _LadderStepStatus.blocked
        ? 'HUMAN CALL NEEDED'
        : _activeTab != _ContextTab.details
        ? 'OPEN THE FACTS'
        : 'CLEAR THE NEXT MOVE';
    final commandSubline = activeIncident == null
        ? 'Start with the hottest live incident.'
        : currentStep.status == _LadderStepStatus.blocked
        ? 'Automation is blocked. Human override takes point.'
        : _activeTab != _ContextTab.details
        ? 'Pull the full incident facts forward before you act.'
        : 'The board is pinned. Reopen queue and push the next command.';
    final primaryActionLabel = activeIncident == null
        ? 'PICK LEAD INCIDENT'
        : currentStep.status == _LadderStepStatus.blocked
        ? 'OVERRIDE NOW'
        : _activeTab != _ContextTab.details
        ? 'OPEN DETAILS'
        : 'OPEN QUEUE';
    final primaryActionIcon = activeIncident == null
        ? Icons.center_focus_strong_rounded
        : currentStep.status == _LadderStepStatus.blocked
        ? Icons.gavel_rounded
        : _activeTab != _ContextTab.details
        ? Icons.article_outlined
        : Icons.schedule_rounded;
    final VoidCallback? primaryAction = activeIncident == null
        ? (_incidents.isEmpty
              ? null
              : () async {
                  _focusLeadIncident();
                  await Future<void>.delayed(Duration.zero);
                  await _ensureActionLadderPanelVisible();
                })
        : currentStep.status == _LadderStepStatus.blocked
        ? () => _openOverrideDialog(activeIncident)
        : _activeTab != _ContextTab.details
        ? () => _openActionLadderContextFromBoard(
            activeIncident,
            _ContextTab.details,
          )
        : () => _openActionLadderQueueFromBoard(activeIncident);

    Widget insightPill({
      required String label,
      required Color foreground,
      required Color background,
      required Color border,
      IconData? icon,
      Key? key,
    }) {
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: background,
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 8.0, color: foreground),
              const SizedBox(width: 1.8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: foreground,
                fontSize: 7.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('live-operations-board-focus-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.5),
        gradient: const LinearGradient(
          colors: [_commandPanelColor, _commandPanelTintColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primaryAccent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withValues(alpha: 0.1),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final actionWrap = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: primaryAction,
                icon: Icon(primaryActionIcon, size: 15),
                label: Text(primaryActionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: const Color(0xFFF8FCFF),
                  disabledBackgroundColor: const Color(0x33233C56),
                  disabledForegroundColor: const Color(0xFF7E93AF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 11,
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 2.2,
                runSpacing: 2.2,
                children: [
                  _chip(
                    key: const ValueKey(
                      'live-operations-board-focus-open-queue',
                    ),
                    label: 'QUEUE',
                    foreground: const Color(0xFF8A6500),
                    background: const Color(0xFFFFF7E8),
                    border: const Color(0xFFE6D2A2),
                    leadingIcon: Icons.schedule_rounded,
                    onTap: () =>
                        _openActionLadderQueueFromBoard(activeIncident),
                  ),
                  _chip(
                    key: const ValueKey(
                      'live-operations-board-focus-open-details',
                    ),
                    label: 'DETAILS',
                    foreground: _activeTab == _ContextTab.details
                        ? const Color(0xFF0F6D84)
                        : _commandMutedColor,
                    background: _activeTab == _ContextTab.details
                        ? const Color(0xFFEAF8FB)
                        : _commandPanelColor,
                    border: _activeTab == _ContextTab.details
                        ? const Color(0xFF9DD3E4)
                        : _commandBorderColor,
                    leadingIcon: Icons.article_outlined,
                    onTap: () => _openActionLadderContextFromBoard(
                      activeIncident,
                      _ContextTab.details,
                    ),
                  ),
                  _chip(
                    key: const ValueKey(
                      'live-operations-board-focus-open-voip',
                    ),
                    label: 'CALL',
                    foreground: _activeTab == _ContextTab.voip
                        ? const Color(0xFF345A87)
                        : _commandMutedColor,
                    background: _activeTab == _ContextTab.voip
                        ? const Color(0xFFF2F7FF)
                        : _commandPanelColor,
                    border: _activeTab == _ContextTab.voip
                        ? const Color(0xFFBED4F6)
                        : _commandBorderColor,
                    leadingIcon: Icons.call_rounded,
                    onTap: () => _openActionLadderContextFromBoard(
                      activeIncident,
                      _ContextTab.voip,
                    ),
                  ),
                  _chip(
                    key: const ValueKey(
                      'live-operations-board-focus-open-visual',
                    ),
                    label: 'CAM',
                    foreground: _activeTab == _ContextTab.visual
                        ? const Color(0xFF176B4A)
                        : _commandMutedColor,
                    background: _activeTab == _ContextTab.visual
                        ? const Color(0xFFEFFAF4)
                        : _commandPanelColor,
                    border: _activeTab == _ContextTab.visual
                        ? const Color(0xFFC5E7D2)
                        : _commandBorderColor,
                    leadingIcon: Icons.videocam_outlined,
                    onTap: () => _openActionLadderContextFromBoard(
                      activeIncident,
                      _ContextTab.visual,
                    ),
                  ),
                  _chip(
                    key: const ValueKey('live-operations-board-focus-override'),
                    label: 'OVERRIDE',
                    foreground: activeIncident == null
                        ? _commandMutedColor
                        : const Color(0xFFB93838),
                    background: activeIncident == null
                        ? _commandPanelColor
                        : const Color(0xFFFFF0F0),
                    border: activeIncident == null
                        ? _commandBorderColor
                        : const Color(0xFFE6B5B5),
                    leadingIcon: Icons.gavel_rounded,
                    onTap: activeIncident == null
                        ? null
                        : () => _openOverrideDialog(activeIncident),
                  ),
                  _chip(
                    key: const ValueKey('live-operations-board-focus-pause'),
                    label: 'HOLD',
                    foreground: activeIncident == null
                        ? _commandMutedColor
                        : _commandBodyColor,
                    background: activeIncident == null
                        ? _commandPanelColor
                        : _commandPanelColor,
                    border: activeIncident == null
                        ? _commandBorderColor
                        : _commandBorderColor,
                    leadingIcon: Icons.pause_circle_outline_rounded,
                    onTap: activeIncident == null
                        ? null
                        : () => _pauseAutomation(activeIncident),
                  ),
                ],
              ),
            ],
          );

          final summaryColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18.5,
                    height: 18.5,
                    decoration: BoxDecoration(
                      color: priorityStyle == null
                          ? const Color(0x1422D3EE)
                          : priorityStyle.background,
                      borderRadius: BorderRadius.circular(5.5),
                      border: Border.all(
                        color: priorityStyle?.border ?? const Color(0x3322D3EE),
                      ),
                    ),
                    child: Icon(
                      priorityStyle?.icon ?? Icons.center_focus_strong_rounded,
                      color:
                          priorityStyle?.foreground ?? const Color(0xFF8FD1FF),
                      size: 10.8,
                    ),
                  ),
                  const SizedBox(width: 3.6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DO NOW',
                          style: GoogleFonts.inter(
                            color: primaryAccent.withValues(alpha: 0.95),
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          activeIncident == null
                              ? 'No incident selected'
                              : 'Active Incident: ${activeIncident.id}',
                          style: GoogleFonts.inter(
                            color: _commandMutedColor,
                            fontSize: 7.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          commandLead,
                          style: GoogleFonts.inter(
                            color: _commandTitleColor,
                            fontSize: 13.6,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          activeIncident?.type ?? 'Standby board',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: _commandBodyColor,
                            fontSize: 8.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1.6),
              Text(
                commandSubline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 8.1,
                  fontWeight: FontWeight.w700,
                  height: 1.24,
                ),
              ),
              const SizedBox(height: 1.6),
              Text(
                summary,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _commandMutedColor,
                  fontSize: 7.2,
                  fontWeight: FontWeight.w600,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 1.6),
              Wrap(
                spacing: 1.9,
                runSpacing: 1.9,
                children: [
                  if (priorityStyle != null)
                    insightPill(
                      label: priorityStyle.label,
                      foreground: priorityStyle.foreground,
                      background: priorityStyle.background,
                      border: priorityStyle.border,
                      icon: priorityStyle.icon,
                    ),
                  insightPill(
                    label: activeIncident == null
                        ? 'STANDBY'
                        : _statusLabel(activeIncident.status),
                    foreground: statusColor,
                    background: statusColor.withValues(alpha: 0.16),
                    border: statusColor.withValues(alpha: 0.42),
                    icon: activeIncident == null
                        ? Icons.radio_button_unchecked_rounded
                        : Icons.fiber_manual_record_rounded,
                  ),
                  if (activeIncident != null)
                    insightPill(
                      label: activeIncident.site,
                      foreground: const Color(0xFF0F6D84),
                      background: const Color(0xFFEAF8FB),
                      border: const Color(0xFF9DD3E4),
                      icon: Icons.location_on_outlined,
                    ),
                  insightPill(
                    label: currentStep.status == _LadderStepStatus.blocked
                        ? 'OVERRIDE'
                        : 'NOW ${currentStep.name}',
                    foreground: currentStep.status == _LadderStepStatus.blocked
                        ? const Color(0xFFFFD6D6)
                        : const Color(0xFFBDFBFF),
                    background: currentStep.status == _LadderStepStatus.blocked
                        ? const Color(0x1AEF4444)
                        : const Color(0x1422D3EE),
                    border: currentStep.status == _LadderStepStatus.blocked
                        ? const Color(0x66EF4444)
                        : const Color(0x5522D3EE),
                    icon: _stepIcon(currentStep.status),
                  ),
                  insightPill(
                    label: activeIncident == null ? 'BOARD READY' : queueLabel,
                    foreground: const Color(0xFF2B5E8B),
                    background: const Color(0xFFF2F7FF),
                    border: const Color(0xFFBED4F6),
                    icon: Icons.view_compact_alt_outlined,
                  ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                summaryColumn,
                const SizedBox(height: 3.0),
                actionWrap,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: summaryColumn),
              const SizedBox(width: 3.0),
              Expanded(flex: 8, child: actionWrap),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openActionLadderQueueFromBoard(
    _IncidentRecord? activeIncident,
  ) async {
    if (activeIncident != null && _activeIncidentId != activeIncident.id) {
      _focusIncidentFromBanner(activeIncident);
    } else if (activeIncident == null && _incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureControlInboxPanelVisible();
    _showLiveOpsFeedback(
      activeIncident == null
          ? 'Control inbox reopened from the ladder.'
          : 'Control inbox reopened for ${activeIncident.id}.',
      label: 'ACTION LADDER',
      detail: activeIncident == null
          ? 'Live Ops moved the reply queue back into view so a lead incident can be pinned into the board without leaving the shell.'
          : 'The selected incident stayed pinned while the reply queue and operator review state came forward in the left rail.',
      accent: const Color(0xFFF59E0B),
    );
  }

  Future<void> _openActionLadderContextFromBoard(
    _IncidentRecord? activeIncident,
    _ContextTab tab,
  ) async {
    if (_activeTab != tab) {
      setState(() {
        _activeTab = tab;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureContextAndVigilancePanelVisible();
    final tabLabel = _tabLabel(tab);
    _showLiveOpsFeedback(
      activeIncident == null
          ? '$tabLabel context opened from the ladder.'
          : '$tabLabel context opened for ${activeIncident.id}.',
      label: 'ACTION LADDER',
      detail: activeIncident == null
          ? 'The right rail stayed inside the current workspace so the next live incident can land without resetting context.'
          : 'The action ladder kept ${activeIncident.id} active while ${tabLabel.toLowerCase()} context moved forward in the right rail.',
      accent: switch (tab) {
        _ContextTab.details => const Color(0xFF22D3EE),
        _ContextTab.voip => const Color(0xFF3B82F6),
        _ContextTab.visual => const Color(0xFF10B981),
      },
    );
  }

  Widget _contextAndVigilancePanel(
    _IncidentRecord? activeIncident, {
    required bool embeddedScroll,
  }) {
    final wide = embeddedScroll;
    if (!wide) {
      return KeyedSubtree(
        key: _contextAndVigilancePanelGlobalKey,
        child: Column(
          children: [
            _contextRailFocusCard(activeIncident),
            const SizedBox(height: 5),
            _panel(
              title: 'Incident Context',
              subtitle: 'Details, VoIP handshake, and visual verification',
              child: _contextPanelBody(activeIncident, embeddedScroll: false),
            ),
            const SizedBox(height: 5),
            _panel(
              title: 'Guard Vigilance',
              subtitle: 'Decay sparkline tracking and escalation posture',
              child: _vigilancePanel(embeddedScroll: false),
            ),
          ],
        ),
      );
    }
    return KeyedSubtree(
      key: _contextAndVigilancePanelGlobalKey,
      child: Column(
        children: [
          _contextRailFocusCard(activeIncident),
          const SizedBox(height: 5),
          Expanded(
            flex: 4,
            child: _panel(
              title: 'Incident Context',
              subtitle: 'Details, VoIP handshake, and visual verification',
              shellless: true,
              child: _contextPanelBody(activeIncident, embeddedScroll: true),
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            flex: 2,
            child: _panel(
              title: 'Guard Vigilance',
              subtitle: 'Decay sparkline tracking and escalation posture',
              shellless: true,
              child: _vigilancePanel(embeddedScroll: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextPanelBody(
    _IncidentRecord? activeIncident, {
    required bool embeddedScroll,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tightBoundedPanel =
            embeddedScroll &&
            constraints.hasBoundedHeight &&
            constraints.maxHeight < 150;
        final detailBody = _activeTab == _ContextTab.details
            ? _detailsTab(
                activeIncident,
                embeddedScroll: embeddedScroll && !tightBoundedPanel,
              )
            : _activeTab == _ContextTab.voip
            ? _voipTab(
                activeIncident,
                embeddedScroll: embeddedScroll && !tightBoundedPanel,
              )
            : _visualTab(
                activeIncident,
                embeddedScroll: embeddedScroll && !tightBoundedPanel,
              );

        if (tightBoundedPanel) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [_contextTabs(), const SizedBox(height: 5), detailBody],
            ),
          );
        }

        return Column(
          children: [
            _contextTabs(),
            const SizedBox(height: 5),
            if (embeddedScroll) Expanded(child: detailBody) else detailBody,
          ],
        );
      },
    );
  }

  Widget _contextRailFocusCard(_IncidentRecord? activeIncident) {
    final focusedGuard = _focusedVigilanceGuard;
    final queueLabel = _controlInboxTopBarQueueStateLabel();
    final tabLabel = _tabLabel(_activeTab);
    final openClientLaneAction = widget.clientCommsSnapshot == null
        ? null
        : _openClientLaneAction(
            clientId: widget.clientCommsSnapshot!.clientId,
            siteId: widget.clientCommsSnapshot!.siteId,
          );

    String summary;
    switch (_activeTab) {
      case _ContextTab.details:
        summary = activeIncident == null
            ? 'Right rail ready. Open queue, details, call, or visual.'
            : ((activeIncident.latestSceneReviewSummary ??
                          activeIncident.latestIntelSummary ??
                          activeIncident.latestIntelHeadline)
                      ?.trim()
                      .isNotEmpty ==
                  true)
            ? _compactContextLabel(
                (activeIncident.latestSceneReviewSummary ??
                        activeIncident.latestIntelSummary ??
                        activeIncident.latestIntelHeadline)!
                    .trim(),
              )
            : 'Details stay pinned for ${activeIncident.site}.';
      case _ContextTab.voip:
        summary = activeIncident == null
            ? 'Call rail ready. Keep comms visible here.'
            : 'Call posture stays live for ${activeIncident.id}.';
      case _ContextTab.visual:
        summary = activeIncident == null
            ? 'Visual rail ready. Reopen queue or compare footage here.'
            : 'Visual match stays live for ${activeIncident.id} at ${_visualMatchScoreForIncident(activeIncident)}%.';
    }

    final contextAccent = switch (_activeTab) {
      _ContextTab.details => const Color(0xFF22D3EE),
      _ContextTab.voip => const Color(0xFF60A5FA),
      _ContextTab.visual => const Color(0xFF4ADE80),
    };
    final contextIcon = switch (_activeTab) {
      _ContextTab.details => Icons.article_outlined,
      _ContextTab.voip => Icons.call_rounded,
      _ContextTab.visual => Icons.videocam_outlined,
    };
    final contextModeLabel = switch (_activeTab) {
      _ContextTab.details => 'DETAILS',
      _ContextTab.voip => 'CALL',
      _ContextTab.visual => 'VISUAL',
    };

    return Container(
      key: const ValueKey('live-operations-context-focus-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              contextAccent.withValues(alpha: 0.18),
              _commandPanelColor,
            ),
            _commandPanelTintColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: contextAccent.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: contextAccent.withValues(alpha: 0.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final actionWrap = Wrap(
            spacing: 2.0,
            runSpacing: 2.0,
            children: [
              _chip(
                key: const ValueKey('live-operations-context-focus-open-queue'),
                label: 'Queue',
                foreground: const Color(0xFFFFE4B5),
                background: const Color(0x1AF59E0B),
                border: const Color(0x66F59E0B),
                leadingIcon: Icons.schedule_rounded,
                onTap: () => _openContextRailQueue(activeIncident),
              ),
              _chip(
                key: const ValueKey(
                  'live-operations-context-focus-open-details',
                ),
                label: 'Details',
                foreground: _activeTab == _ContextTab.details
                    ? const Color(0xFF0F6D84)
                    : _commandMutedColor,
                background: _activeTab == _ContextTab.details
                    ? const Color(0xFFEAF8FB)
                    : _commandPanelColor,
                border: _activeTab == _ContextTab.details
                    ? const Color(0xFFBCDCE4)
                    : _commandBorderColor,
                leadingIcon: Icons.article_outlined,
                onTap: () =>
                    _openContextRailTab(activeIncident, _ContextTab.details),
              ),
              _chip(
                key: const ValueKey('live-operations-context-focus-open-voip'),
                label: 'VoIP',
                foreground: _activeTab == _ContextTab.voip
                    ? const Color(0xFF2E6EA8)
                    : _commandMutedColor,
                background: _activeTab == _ContextTab.voip
                    ? const Color(0xFFEFF4FA)
                    : _commandPanelColor,
                border: _activeTab == _ContextTab.voip
                    ? const Color(0xFFC4D8EC)
                    : _commandBorderColor,
                leadingIcon: Icons.call_rounded,
                onTap: () =>
                    _openContextRailTab(activeIncident, _ContextTab.voip),
              ),
              _chip(
                key: const ValueKey(
                  'live-operations-context-focus-open-visual',
                ),
                label: 'Visual',
                foreground: _activeTab == _ContextTab.visual
                    ? const Color(0xFF176B4A)
                    : _commandMutedColor,
                background: _activeTab == _ContextTab.visual
                    ? const Color(0xFFEFFAF4)
                    : _commandPanelColor,
                border: _activeTab == _ContextTab.visual
                    ? const Color(0xFFC6E8D4)
                    : _commandBorderColor,
                leadingIcon: Icons.videocam_outlined,
                onTap: () =>
                    _openContextRailTab(activeIncident, _ContextTab.visual),
              ),
              _chip(
                key: const ValueKey(
                  'live-operations-context-focus-guard-attention',
                ),
                label: focusedGuard == null
                    ? 'Guard attention'
                    : focusedGuard.callsign,
                foreground: const Color(0xFFE8FFF4),
                background: const Color(0x1A10B981),
                border: const Color(0x6610B981),
                leadingIcon: Icons.shield_moon_outlined,
                onTap: _vigilance.isEmpty
                    ? null
                    : _focusGuardAttentionFromContext,
              ),
              if (openClientLaneAction != null)
                _chip(
                  key: const ValueKey(
                    'live-operations-context-focus-open-client-lane',
                  ),
                  label: 'Client Comms',
                  foreground: const Color(0xFF0F6D84),
                  background: const Color(0xFFEAF8FB),
                  border: const Color(0xFFBCDCE4),
                  leadingIcon: Icons.open_in_new_rounded,
                  onTap: openClientLaneAction,
                ),
            ],
          );

          final summaryColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 19.5,
                    height: 19.5,
                    decoration: BoxDecoration(
                      color: contextAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(5.2),
                      border: Border.all(
                        color: contextAccent.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Icon(contextIcon, color: contextAccent, size: 11.0),
                  ),
                  const SizedBox(width: 3.6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RIGHT RAIL',
                          style: GoogleFonts.inter(
                            color: contextAccent.withValues(alpha: 0.96),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 1.6),
                        Text(
                          activeIncident == null
                              ? '$contextModeLabel READY'
                              : '$contextModeLabel FOR ${activeIncident.id}',
                          style: GoogleFonts.inter(
                            color: _commandBodyColor,
                            fontSize: 7.9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1.6),
                        Text(
                          activeIncident?.site ?? 'Pick the next drill-in',
                          style: GoogleFonts.inter(
                            color: _commandTitleColor,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2.6),
              Text(
                summary,
                maxLines: compact ? 4 : 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 8.3,
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 2.6),
              Wrap(
                spacing: 2.5,
                runSpacing: 2.5,
                children: [
                  _chip(
                    label: tabLabel,
                    foreground: const Color(0xFF2E6EA8),
                    background: const Color(0xFFEFF4FA),
                    border: const Color(0xFFC4D8EC),
                    leadingIcon: switch (_activeTab) {
                      _ContextTab.details => Icons.article_outlined,
                      _ContextTab.voip => Icons.call_rounded,
                      _ContextTab.visual => Icons.videocam_outlined,
                    },
                  ),
                  _chip(
                    label: queueLabel,
                    foreground: const Color(0xFFFFE4B5),
                    background: const Color(0x1AF59E0B),
                    border: const Color(0x66F59E0B),
                    leadingIcon: Icons.schedule_rounded,
                  ),
                  if (focusedGuard != null)
                    _chip(
                      key: const ValueKey(
                        'live-operations-context-focus-guard-chip',
                      ),
                      label:
                          '${focusedGuard.callsign} • ${focusedGuard.decayLevel}%',
                      foreground: focusedGuard.decayLevel >= 90
                          ? const Color(0xFFFFD6D6)
                          : focusedGuard.decayLevel >= 75
                          ? const Color(0xFFFFE4B5)
                          : const Color(0xFFE8FFF4),
                      background: focusedGuard.decayLevel >= 90
                          ? const Color(0x1AEF4444)
                          : focusedGuard.decayLevel >= 75
                          ? const Color(0x1AF59E0B)
                          : const Color(0x1A10B981),
                      border: focusedGuard.decayLevel >= 90
                          ? const Color(0x66EF4444)
                          : focusedGuard.decayLevel >= 75
                          ? const Color(0x66F59E0B)
                          : const Color(0x6610B981),
                      leadingIcon: Icons.shield_moon_outlined,
                    ),
                  if (activeIncident != null)
                    _chip(
                      label: _statusLabel(activeIncident.status),
                      foreground: _statusChipColor(activeIncident.status),
                      background: _statusChipColor(
                        activeIncident.status,
                      ).withValues(alpha: 0.16),
                      border: _statusChipColor(
                        activeIncident.status,
                      ).withValues(alpha: 0.42),
                      leadingIcon: Icons.fiber_manual_record_rounded,
                    ),
                ],
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [summaryColumn, const SizedBox(height: 4), actionWrap],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: summaryColumn),
              const SizedBox(width: 4),
              Expanded(flex: 8, child: actionWrap),
            ],
          );
        },
      ),
    );
  }

  Widget _detailsTab(
    _IncidentRecord? incident, {
    required bool embeddedScroll,
  }) {
    final wide = embeddedScroll;
    if (incident == null) {
      return _muted('Pick one live incident. Facts land here.');
    }
    final duress = _duressDetected(incident);
    final evidenceReady = _evidenceReadyLabel(incident);
    final priority = _priorityStyle(incident.priority);
    final partnerProgress = _partnerProgressForIncident(incident);
    final siteActivity = _siteActivitySnapshotForIncident(incident);
    final moShadowPosture = _moShadowPostureForIncident(incident);
    final nextShiftDrafts = _nextShiftDraftsForIncident(incident);
    final suppressedReviews = _suppressedSceneReviewsForIncident(incident);
    final clientComms = _clientCommsSnapshotForIncident(incident);
    final rows = <Widget>[
      _detailsWhatMattersCard(
        incident,
        priority: priority,
        duress: duress,
        evidenceReady: evidenceReady,
      ),
      const SizedBox(height: 8),
      _detailsFastFactsStrip(
        incident,
        priority: priority,
        evidenceReady: evidenceReady,
      ),
      const SizedBox(height: 8),
      _metaRow('Address', '123 Main Road, Sandton, Johannesburg'),
      _metaRow('GPS', '-26.1076, 28.0567'),
      _metaRow('SLA Tier', 'Gold'),
      _metaRow('Contact', 'John Sovereign'),
      _metaRow('Client Safe Word', 'PHOENIX'),
      if (clientComms != null) ...[
        const SizedBox(height: 8),
        _clientCommsPulseCard(incident, clientComms),
      ],
      if (siteActivity != null && siteActivity.totalSignals > 0) ...[
        const SizedBox(height: 8),
        _siteActivityTruthCard(incident, siteActivity),
      ],
      if (moShadowPosture != null &&
          moShadowPosture.moShadowMatchCount > 0) ...[
        const SizedBox(height: 8),
        _moShadowCard(incident, moShadowPosture),
      ],
      if (nextShiftDrafts.isNotEmpty) ...[
        const SizedBox(height: 8),
        _nextShiftDraftCard(incident, nextShiftDrafts),
      ],
      if (partnerProgress != null) ...[
        const SizedBox(height: 8),
        _partnerProgressCard(partnerProgress, incident.id),
      ],
      if ((incident.latestIntelHeadline ?? '').trim().isNotEmpty)
        _metaRow(
          'Latest ${widget.videoOpsLabel} Intel',
          incident.latestIntelHeadline!.trim(),
        ),
      if ((incident.latestIntelSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Intel Detail',
          _compactContextLabel(incident.latestIntelSummary!),
        ),
      if ((incident.latestSceneReviewLabel ?? '').trim().isNotEmpty)
        _metaRow('Scene Review', incident.latestSceneReviewLabel!.trim()),
      if ((incident.latestSceneReviewSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Review Detail',
          _compactContextLabel(incident.latestSceneReviewSummary!),
        ),
      if ((incident.latestSceneDecisionLabel ?? '').trim().isNotEmpty)
        _metaRow('Scene Action', incident.latestSceneDecisionLabel!.trim()),
      if ((incident.latestSceneDecisionSummary ?? '').trim().isNotEmpty)
        _metaRow(
          'Action Detail',
          _compactContextLabel(incident.latestSceneDecisionSummary!),
        ),
      _metaRow('Evidence Ready', evidenceReady),
      if ((incident.snapshotUrl ?? '').trim().isNotEmpty)
        _metaRow('Snapshot Ref', _compactContextLabel(incident.snapshotUrl!)),
      if ((incident.clipUrl ?? '').trim().isNotEmpty)
        _metaRow('Clip Ref', _compactContextLabel(incident.clipUrl!)),
      if (suppressedReviews.isNotEmpty) ...[
        const SizedBox(height: 8),
        _suppressedSceneReviewQueue(suppressedReviews),
      ],
      if (duress) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x66EF4444), width: 2),
            color: const Color(0xFFFFF1F1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SILENT DURESS DETECTED',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB42318),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => _forceDispatch(incident),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF1F1),
                  foregroundColor: const Color(0xFFB42318),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE8B6B6)),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('FORCED DISPATCH'),
              ),
            ],
          ),
        ),
      ],
    ];
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );
    }
    return ListView(
      key: const ValueKey('live-operations-details-scroll-view'),
      children: rows,
    );
  }

  Widget _detailsWhatMattersCard(
    _IncidentRecord incident, {
    required _PriorityStyle priority,
    required bool duress,
    required String evidenceReady,
  }) {
    final accent = duress ? const Color(0xFFEF4444) : priority.foreground;
    final leadLabel = duress
        ? 'MOVE NOW'
        : incident.priority == _IncidentPriority.p1Critical
        ? 'RED'
        : incident.priority == _IncidentPriority.p2High
        ? 'ACT'
        : 'WATCH';
    final headline = duress
        ? 'Silent duress flagged. Force the response.'
        : (incident.latestSceneDecisionLabel ?? '').trim().isNotEmpty
        ? incident.latestSceneDecisionLabel!.trim()
        : (incident.latestSceneReviewLabel ?? '').trim().isNotEmpty
        ? incident.latestSceneReviewLabel!.trim()
        : (incident.latestIntelHeadline ?? '').trim().isNotEmpty
        ? incident.latestIntelHeadline!.trim()
        : '${incident.type} at ${incident.site}';
    final detail = duress
        ? 'Do not wait on automation. Dispatch and hold this incident until the unit confirms.'
        : (incident.latestSceneDecisionSummary ?? '').trim().isNotEmpty
        ? incident.latestSceneDecisionSummary!.trim()
        : (incident.latestSceneReviewSummary ?? '').trim().isNotEmpty
        ? incident.latestSceneReviewSummary!.trim()
        : (incident.latestIntelSummary ?? '').trim().isNotEmpty
        ? incident.latestIntelSummary!.trim()
        : 'Board is pinned on this live incident. Work this one before you move.';
    return Container(
      key: ValueKey('live-operations-details-what-matters-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.16), const Color(0xFFFBFDFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  leadLabel,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                incident.id,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF556B80),
                  fontSize: 10.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            headline,
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10.1,
              fontWeight: FontWeight.w700,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _commsChip(
                icon: Icons.location_on_outlined,
                label: incident.site,
                accent: const Color(0xFF22D3EE),
              ),
              _commsChip(
                icon: Icons.fiber_manual_record_rounded,
                label: _statusLabel(incident.status),
                accent: _statusChipColor(incident.status),
              ),
              _commsChip(
                icon: Icons.verified_outlined,
                label: evidenceReady,
                accent: const Color(0xFF34D399),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailsFastFactsStrip(
    _IncidentRecord incident, {
    required _PriorityStyle priority,
    required String evidenceReady,
  }) {
    Widget factTile({
      required String label,
      required String value,
      required Color accent,
      required IconData icon,
    }) {
      return Container(
        constraints: const BoxConstraints(minWidth: 108),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: accent.withValues(alpha: 0.34)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: accent),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 8.6,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAF4FF),
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 340;
        final tiles = [
          factTile(
            label: 'SITE',
            value: incident.site,
            accent: const Color(0xFF22D3EE),
            icon: Icons.location_on_outlined,
          ),
          factTile(
            label: 'RISK',
            value: priority.label,
            accent: priority.foreground,
            icon: priority.icon,
          ),
          factTile(
            label: 'CLIENT',
            value: 'Sandton HOA',
            accent: const Color(0xFF3B82F6),
            icon: Icons.apartment_rounded,
          ),
          factTile(
            label: 'PROOF',
            value: evidenceReady,
            accent: const Color(0xFF34D399),
            icon: Icons.verified_outlined,
          ),
        ];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: wide ? (constraints.maxWidth - 8) / 2 : double.infinity,
                child: tile,
              ),
          ],
        );
      },
    );
  }

  LiveClientCommsSnapshot? _clientCommsSnapshotForIncident(
    _IncidentRecord incident,
  ) {
    final snapshot = widget.clientCommsSnapshot;
    if (snapshot == null) {
      return null;
    }
    final incidentClientId = incident.clientId.trim();
    final incidentSiteId = incident.siteId.trim();
    if (incidentClientId.isEmpty || incidentSiteId.isEmpty) {
      return null;
    }
    if (incidentClientId != snapshot.clientId.trim() ||
        incidentSiteId != snapshot.siteId.trim()) {
      return null;
    }
    return snapshot;
  }

  SiteActivityIntelligenceSnapshot? _siteActivitySnapshotForIncident(
    _IncidentRecord incident,
  ) {
    if (incident.clientId.trim().isEmpty || incident.siteId.trim().isEmpty) {
      return null;
    }
    return _siteActivityService.buildSnapshot(
      events: widget.events,
      clientId: incident.clientId,
      siteId: incident.siteId,
    );
  }

  Widget _clientCommsPulseCard(
    _IncidentRecord incident,
    LiveClientCommsSnapshot snapshot,
  ) {
    final cueKind = _liveClientLaneCueKind(snapshot);
    final learnedStyleBusy = _learnedStyleBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final laneVoiceBusy = _laneVoiceBusyScopeKeys.contains(
      _scopeBusyKey(snapshot.clientId, snapshot.siteId),
    );
    final accent = _clientCommsAccent(snapshot);
    final latestClientMessage =
        (snapshot.latestClientMessage ?? '').trim().isEmpty
        ? 'Client Comms is quiet right now. New messages will appear here.'
        : snapshot.latestClientMessage!.trim();
    final pendingDraft = (snapshot.latestPendingDraft ?? '').trim();
    final latestOnyxReply = (snapshot.latestOnyxReply ?? '').trim();
    final responseLabel = pendingDraft.isNotEmpty
        ? 'Pending ONYX Draft'
        : 'Latest Client Comms reply';
    final responseText = pendingDraft.isNotEmpty
        ? pendingDraft
        : latestOnyxReply.isEmpty
        ? 'No Client Comms reply has been logged yet.'
        : latestOnyxReply;
    final responseMoment = _commsMomentLabel(
      pendingDraft.isNotEmpty
          ? snapshot.latestPendingDraftAtUtc
          : snapshot.latestOnyxReplyAtUtc,
    );
    return Container(
      key: Key('client-comms-pulse-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.12), const Color(0xFFFBFDFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Client Comms Pulse',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF172638),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ) !=
                  null)
                OutlinedButton.icon(
                  onPressed: _openClientLaneAction(
                    clientId: snapshot.clientId,
                    siteId: snapshot.siteId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF315A86),
                    backgroundColor: const Color(0xFF13131E),
                    side: BorderSide(color: accent.withValues(alpha: 0.58)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'OPEN CLIENT COMMS',
                    style: GoogleFonts.inter(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (snapshot.learnedApprovalStyleCount > 0 &&
                  widget.onClearLearnedLaneStyleForScope != null) ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  key: ValueKey(
                    'client-comms-pulse-clear-learned-style-${snapshot.clientId}-${snapshot.siteId}',
                  ),
                  onPressed: learnedStyleBusy
                      ? null
                      : () => _clearLearnedLaneStyle(snapshot),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F6A83),
                    backgroundColor: const Color(0xFFF5FBFF),
                    side: const BorderSide(color: Color(0xFF87CAE0)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    minimumSize: const Size(0, 28),
                  ),
                  icon: learnedStyleBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0F6A83),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    'Clear Learned Style',
                    style: GoogleFonts.inter(
                      fontSize: 10.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_humanizeOpsScopeLabel(snapshot.siteId, fallback: incident.site)} • ${_clientCommsNarrative(snapshot)}',
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 10.4,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _commsChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '${snapshot.clientInboundCount} client msg',
                accent: const Color(0xFF22D3EE),
              ),
              _commsChip(
                icon: Icons.verified_user_rounded,
                label: '${snapshot.pendingApprovalCount} approval',
                accent: snapshot.pendingApprovalCount > 0
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF34D399),
              ),
              _commsChip(
                icon: Icons.telegram_rounded,
                label: 'Telegram ${snapshot.telegramHealthLabel.toUpperCase()}',
                accent: _telegramHealthAccent(snapshot.telegramHealthLabel),
              ),
              _commsChip(
                icon: Icons.sms_rounded,
                label: snapshot.smsFallbackLabel,
                accent: _smsFallbackAccent(
                  snapshot.smsFallbackLabel,
                  ready: snapshot.smsFallbackReady,
                  eligibleNow: snapshot.smsFallbackEligibleNow,
                ),
              ),
              _commsChip(
                icon: Icons.phone_forwarded_rounded,
                label: snapshot.voiceReadinessLabel,
                accent: _voiceReadinessAccent(snapshot.voiceReadinessLabel),
              ),
              _commsChip(
                icon: Icons.outbox_rounded,
                label: 'Push ${snapshot.pushSyncStatusLabel.toUpperCase()}',
                accent: _pushSyncAccent(snapshot.pushSyncStatusLabel),
              ),
              _commsChip(
                icon: _controlInboxDraftCueChipIcon(cueKind),
                label: _controlInboxDraftCueChipLabel(cueKind),
                accent: _controlInboxDraftCueChipAccent(cueKind),
              ),
              if (snapshot.learnedApprovalStyleCount > 0)
                _commsChip(
                  icon: Icons.school_rounded,
                  label: 'Learned style ${snapshot.learnedApprovalStyleCount}',
                  accent: const Color(0xFF22D3EE),
                ),
              if (snapshot.pendingLearnedStyleDraftCount > 0)
                _commsChip(
                  icon: Icons.psychology_alt_rounded,
                  label: snapshot.pendingLearnedStyleDraftCount == 1
                      ? 'ONYX using learned style'
                      : 'ONYX using learned style on ${snapshot.pendingLearnedStyleDraftCount} drafts',
                  accent: const Color(0xFF67E8F9),
                ),
            ],
          ),
          if (widget.onSetLaneVoiceProfileForScope != null) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (laneVoiceBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF8FD1FF),
                    ),
                  ),
                for (final option in const <(String, String?)>[
                  ('Auto', null),
                  ('Concise', 'concise-updates'),
                  ('Reassuring', 'reassurance-forward'),
                  ('Validation-heavy', 'validation-heavy'),
                ])
                  OutlinedButton(
                    onPressed: laneVoiceBusy
                        ? null
                        : () => _setLaneVoiceProfile(snapshot, option.$2),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? const Color(0xFF172638)
                          : const Color(0xFF556B80),
                      backgroundColor:
                          _laneVoiceOptionSelected(snapshot, option.$2)
                          ? accent.withValues(alpha: 0.16)
                          : const Color(0xFF13131E),
                      side: BorderSide(
                        color: _laneVoiceOptionSelected(snapshot, option.$2)
                            ? accent.withValues(alpha: 0.34)
                            : const Color(0xFFD4DFEA),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      option.$1,
                      style: GoogleFonts.inter(
                        fontSize: 10.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 7),
          Text(
            _liveClientLaneCue(snapshot),
            style: GoogleFonts.inter(
              color: const Color(0xFFA9BFD9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 8),
          _clientCommsTextBlock(
            label: 'Latest Client Message',
            text:
                '$latestClientMessage${_commsMomentLabel(snapshot.latestClientMessageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestClientMessageAtUtc)}'}',
            borderColor: const Color(0xFF31506F),
            textColor: const Color(0xFF172638),
          ),
          const SizedBox(height: 7),
          _clientCommsTextBlock(
            label: responseLabel,
            text:
                '$responseText${responseMoment.isEmpty ? '' : ' • $responseMoment'}',
            borderColor: accent,
            textColor: const Color(0xFF172638),
          ),
          if ((snapshot.latestSmsFallbackStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Latest SMS fallback',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestSmsFallbackStatus!.trim())}${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestSmsFallbackAtUtc)}'}',
              borderColor: const Color(0xFF2E7D68),
              textColor: const Color(0xFF166534),
            ),
          ],
          if ((snapshot.latestVoipStageStatus ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Latest VoIP stage',
              text:
                  '${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.latestVoipStageStatus!.trim())}${_commsMomentLabel(snapshot.latestVoipStageAtUtc).isEmpty ? '' : ' • ${_commsMomentLabel(snapshot.latestVoipStageAtUtc)}'}',
              borderColor: const Color(0xFF3E6AA6),
              textColor: const Color(0xFF315A86),
            ),
          ],
          if (snapshot.recentDeliveryHistoryLines.isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Recent delivery history',
              text: snapshot.recentDeliveryHistoryLines.join('\n'),
              borderColor: const Color(0xFF35506F),
              textColor: const Color(0xFF315A86),
            ),
          ],
          if (snapshot.learnedApprovalStyleExample.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            _clientCommsTextBlock(
              label: 'Learned approval style',
              text: snapshot.learnedApprovalStyleExample.trim(),
              borderColor: const Color(0xFF245B72),
              textColor: const Color(0xFF0F6A83),
            ),
          ],
          if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty ||
              (snapshot.pushSyncFailureReason ?? '').trim().isNotEmpty ||
              snapshot.telegramFallbackActive ||
              snapshot.queuedPushCount > 0) ...[
            const SizedBox(height: 7),
            Text(
              _clientCommsOpsFootnote(snapshot),
              style: GoogleFonts.inter(
                color: const Color(0xFFA9BFD9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _commsChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    final foreground = Color.lerp(_commandTitleColor, accent, 0.72) ?? accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 9.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactCommandActionChip({
    required String label,
    required Color foregroundColor,
    required Color borderColor,
    VoidCallback? onTap,
    IconData? icon,
    Widget? leading,
    Key? key,
    double fontSize = 9.1,
    double minHeight = 28,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 6,
    ),
  }) {
    final child = Ink(
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(color: foregroundColor, size: 14),
                  child: leading,
                ),
                const SizedBox(width: 4),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: foregroundColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      key: key,
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.56 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _clientCommsTextBlock({
    required String label,
    required String text,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(7.5),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(7.0),
        border: Border.all(color: borderColor.withValues(alpha: 0.52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: _commandMutedColor,
              fontSize: 8.8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3.5),
          Text(
            text,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 9.7,
              fontWeight: FontWeight.w600,
              height: 1.24,
            ),
          ),
        ],
      ),
    );
  }

  MonitoringGlobalSitePosture? _moShadowPostureForIncident(
    _IncidentRecord incident,
  ) {
    final snapshot = _globalPostureService.buildSnapshot(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    for (final site in snapshot.sites) {
      if (site.siteId.trim() == incident.siteId.trim() &&
          site.regionId.trim() == incident.regionId.trim()) {
        return site;
      }
    }
    return null;
  }

  List<MonitoringWatchAutonomyActionPlan> _nextShiftDraftsForIncident(
    _IncidentRecord incident,
  ) {
    if (widget.historicalSyntheticLearningLabels.isEmpty &&
        widget.historicalShadowMoLabels.isEmpty &&
        widget.historicalShadowStrengthLabels.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }
    return _orchestratorService
        .buildActionIntents(
          events: widget.events,
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          videoOpsLabel: widget.videoOpsLabel,
          historicalSyntheticLearningLabels:
              widget.historicalSyntheticLearningLabels,
          historicalShadowMoLabels: widget.historicalShadowMoLabels,
          historicalShadowStrengthLabels: widget.historicalShadowStrengthLabels,
        )
        .where((plan) => plan.metadata['scope'] == 'NEXT_SHIFT')
        .where(
          (plan) =>
              plan.siteId.trim() == incident.siteId.trim() ||
              (plan.metadata['lead_site'] ?? '').trim() ==
                  incident.siteId.trim() ||
              (plan.metadata['region'] ?? '').trim() ==
                  incident.regionId.trim(),
        )
        .toList(growable: false);
  }

  List<MonitoringWatchAutonomyActionPlan> _readinessBiasesForIncident(
    _IncidentRecord incident,
  ) {
    if (widget.historicalShadowMoLabels.isEmpty &&
        widget.historicalShadowStrengthLabels.isEmpty) {
      return const <MonitoringWatchAutonomyActionPlan>[];
    }
    return _orchestratorService
        .buildActionIntents(
          events: widget.events,
          sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
          videoOpsLabel: widget.videoOpsLabel,
          historicalSyntheticLearningLabels:
              widget.historicalSyntheticLearningLabels,
          historicalShadowMoLabels: widget.historicalShadowMoLabels,
          historicalShadowStrengthLabels: widget.historicalShadowStrengthLabels,
        )
        .where((plan) => plan.metadata['scope'] == 'READINESS')
        .where(
          (plan) =>
              plan.siteId.trim() == incident.siteId.trim() ||
              (plan.metadata['lead_site'] ?? '').trim() ==
                  incident.siteId.trim() ||
              (plan.metadata['region'] ?? '').trim() ==
                  incident.regionId.trim(),
        )
        .toList(growable: false);
  }

  MonitoringWatchAutonomyActionPlan? _syntheticPolicyForIncident(
    _IncidentRecord incident,
  ) {
    final plans = _syntheticWarRoomService.buildSimulationPlans(
      events: widget.events,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
      videoOpsLabel: widget.videoOpsLabel,
      historicalLearningLabels: widget.historicalSyntheticLearningLabels,
      historicalShadowMoLabels: widget.historicalShadowMoLabels,
    );
    for (final plan in plans) {
      if (plan.actionType != 'POLICY RECOMMENDATION') {
        continue;
      }
      if (plan.siteId.trim() == incident.siteId.trim() ||
          (plan.metadata['lead_site'] ?? '').trim() == incident.siteId.trim() ||
          (plan.metadata['region'] ?? '').trim() == incident.regionId.trim()) {
        return plan;
      }
    }
    return null;
  }

  String _promotionPressureSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    final prebuiltSummary =
        (plan.metadata['mo_promotion_pressure_summary'] ?? '').trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final baseSummary = (plan.metadata['mo_promotion_summary'] ?? '').trim();
    if (baseSummary.isEmpty) {
      return '';
    }
    return buildSyntheticPromotionSummary(
      baseSummary: baseSummary,
      shadowPostureBiasSummary: _shadowPostureBiasSummaryForPlan(plan),
    );
  }

  String _promotionExecutionSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    return buildSyntheticPromotionExecutionBiasSummary(
      promotionPriorityBias: (plan.metadata['mo_promotion_priority_bias'] ?? '')
          .trim(),
      promotionCountdownBias:
          (plan.metadata['mo_promotion_countdown_bias'] ?? '').trim(),
    );
  }

  String _shadowPostureBiasSummaryForPlan(
    MonitoringWatchAutonomyActionPlan plan,
  ) {
    final prebuiltSummary = (plan.metadata['shadow_posture_bias_summary'] ?? '')
        .trim();
    if (prebuiltSummary.isNotEmpty) {
      return prebuiltSummary;
    }
    final postureBias = (plan.metadata['shadow_posture_bias'] ?? '').trim();
    final posturePriority = (plan.metadata['shadow_posture_priority'] ?? '')
        .trim();
    final postureCountdown = (plan.metadata['shadow_posture_countdown'] ?? '')
        .trim();
    if (postureBias.isEmpty &&
        posturePriority.isEmpty &&
        postureCountdown.isEmpty) {
      return '';
    }
    final parts = <String>[
      if (postureBias.isNotEmpty) postureBias,
      if (posturePriority.isNotEmpty) posturePriority,
      if (postureCountdown.isNotEmpty) '${postureCountdown}s',
    ];
    return parts.join(' • ');
  }

  Widget _nextShiftDraftCard(
    _IncidentRecord incident,
    List<MonitoringWatchAutonomyActionPlan> drafts,
  ) {
    final leadDraft = drafts.first;
    final readinessBiases = _readinessBiasesForIncident(incident);
    final leadBias = readinessBiases.isEmpty ? null : readinessBiases.first;
    final linkedSyntheticPolicy = _syntheticPolicyForIncident(incident);
    final learningLabel = (leadDraft.metadata['learning_label'] ?? '').trim();
    final repeatCount = (leadDraft.metadata['learning_repeat_count'] ?? '')
        .trim();
    final shadowLabel = (leadDraft.metadata['shadow_mo_label'] ?? '').trim();
    final shadowRepeatCount =
        (leadDraft.metadata['shadow_mo_repeat_count'] ?? '').trim();
    final promotionPressureSummary = linkedSyntheticPolicy == null
        ? ''
        : _promotionPressureSummaryForPlan(linkedSyntheticPolicy);
    final promotionExecutionSummary = linkedSyntheticPolicy == null
        ? ''
        : _promotionExecutionSummaryForPlan(linkedSyntheticPolicy);
    return Container(
      key: ValueKey('live-next-shift-draft-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x665C7CFA)),
        color: const Color(0xFFF7F7FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Next-Shift Drafts',
                style: GoogleFonts.inter(
                  color: const Color(0xFF3F51B5),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${drafts.length} draft${drafts.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (learningLabel.isNotEmpty) _metaRow('Learning', learningLabel),
          if (repeatCount.isNotEmpty)
            _metaRow(
              'Memory',
              'Repeated across $repeatCount recent shift${repeatCount == '1' ? '' : 's'}',
            ),
          if (shadowLabel.isNotEmpty)
            _metaRow(
              'Shadow',
              '$shadowLabel${shadowRepeatCount.isEmpty ? '' : ' • x$shadowRepeatCount'}',
            ),
          if ((leadDraft.metadata['shadow_strength_bias'] ?? '')
              .trim()
              .isNotEmpty)
            _metaRow(
              'Urgency',
              [
                (leadDraft.metadata['shadow_strength_bias'] ?? '').trim(),
                if ((leadDraft.metadata['shadow_strength_priority'] ?? '')
                    .trim()
                    .isNotEmpty)
                  (leadDraft.metadata['shadow_strength_priority'] ?? '').trim(),
              ].join(' • '),
            ),
          if (widget.previousTomorrowUrgencySummary.trim().isNotEmpty)
            _metaRow(
              'Previous urgency',
              widget.previousTomorrowUrgencySummary.trim(),
            ),
          if (leadBias != null)
            _metaRow(
              'Readiness bias',
              _compactContextLabel(leadBias.description),
            ),
          if (promotionPressureSummary.isNotEmpty)
            _metaRow('Promotion pressure', promotionPressureSummary),
          if (promotionExecutionSummary.isNotEmpty)
            _metaRow('Promotion execution', promotionExecutionSummary),
          _metaRow('Lead Draft', leadDraft.actionType),
          _metaRow('Bias', _compactContextLabel(leadDraft.description)),
          if (drafts.length > 1)
            _metaRow(
              'Supporting',
              drafts.skip(1).map((plan) => plan.actionType).join(' • '),
            ),
        ],
      ),
    );
  }

  Widget _moShadowCard(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    return Container(
      key: ValueKey('live-mo-shadow-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x665B9BD5)),
        color: const Color(0xFFF5FBFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Shadow MO Intelligence',
                style: GoogleFonts.inter(
                  color: const Color(0xFF315A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${sitePosture.moShadowMatchCount} match${sitePosture.moShadowMatchCount == 1 ? '' : 'es'}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _metaRow('Pattern', sitePosture.moShadowSummary),
          _metaRow('Signal', 'mo_shadow'),
          _metaRow(
            'Posture Weight',
            shadowMoPostureStrengthSummary(sitePosture),
          ),
          _metaRow('Site Heat', sitePosture.heatLevel.name),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: ValueKey('live-mo-shadow-open-dossier-${incident.id}'),
              onPressed: () => _showMoShadowDossier(incident, sitePosture),
              child: const Text('VIEW DOSSIER'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoShadowDossier(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _commandPanelColor,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _commandBorderColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: ValueKey('live-mo-shadow-dialog-${incident.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'SHADOW MO DOSSIER',
                          style: GoogleFonts.inter(
                            color: _commandTitleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final pretty = const JsonEncoder.withIndent(
                            '  ',
                          ).convert(_moShadowPayload(incident, sitePosture));
                          Clipboard.setData(ClipboardData(text: pretty));
                          Navigator.of(dialogContext).pop();
                          _showLiveOpsFeedback(
                            'Shadow MO dossier copied',
                            label: 'SHADOW MO',
                            detail:
                                'The copied dossier stays visible in the desktop rail while the shadow pattern remains in context.',
                            accent: const Color(0xFF8FD1FF),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF315C86),
                        ),
                        child: const Text('COPY JSON'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: _commandMutedColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${incident.site} • ${sitePosture.moShadowSummary}',
                    style: GoogleFonts.inter(
                      color: _commandBodyColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: sitePosture.moShadowMatches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final match = sitePosture.moShadowMatches[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _commandPanelAltColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _commandBorderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.title,
                                style: GoogleFonts.inter(
                                  color: _commandTitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Indicators ${match.matchedIndicators.join(', ')}',
                                style: GoogleFonts.inter(
                                  color: _commandBodyColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (match.validationStatus.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Strength ${shadowMoStrengthSummary(match)}',
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFF315C86),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (match.recommendedActionPlans.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Actions ${match.recommendedActionPlans.join(' • ')}',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF315C86),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (widget.onOpenEventsForScope != null &&
                                  sitePosture.moShadowEventIds.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      widget.onOpenEventsForScope!(
                                        sitePosture.moShadowEventIds,
                                        sitePosture.moShadowSelectedEventId,
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF315C86),
                                      side: const BorderSide(
                                        color: _commandBorderStrongColor,
                                      ),
                                      backgroundColor: _commandPanelColor,
                                    ),
                                    child: const Text('OPEN EVIDENCE'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<String, Object?> _moShadowPayload(
    _IncidentRecord incident,
    MonitoringGlobalSitePosture sitePosture,
  ) {
    return buildShadowMoSitePayload(
      sitePosture,
      metadata: <String, Object?>{
        'incidentId': incident.id,
        'clientId': incident.clientId,
        'regionId': incident.regionId,
        'siteId': incident.siteId,
        'siteHeat': sitePosture.heatLevel.name,
      },
    );
  }

  Widget _siteActivityTruthCard(
    _IncidentRecord incident,
    SiteActivityIntelligenceSnapshot snapshot,
  ) {
    final canOpenEvents =
        widget.onOpenEventsForScope != null && snapshot.eventIds.isNotEmpty;
    return Container(
      key: ValueKey('live-activity-truth-card-${incident.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4DFEA)),
        color: const Color(0xFF13131E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity Truth',
                style: GoogleFonts.inter(
                  color: const Color(0xFF315A86),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${snapshot.totalSignals} signals',
                style: GoogleFonts.inter(
                  color: const Color(0xFF556B80),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _metaRow('Summary', snapshot.summaryLine),
          _metaRow(
            'Known / Unknown',
            '${snapshot.knownIdentitySignals} known • ${snapshot.unknownPersonSignals + snapshot.unknownVehicleSignals} unknown',
          ),
          if (snapshot.topFlaggedIdentitySummary.trim().isNotEmpty)
            _metaRow('Flagged', snapshot.topFlaggedIdentitySummary),
          if (snapshot.topLongPresenceSummary.trim().isNotEmpty)
            _metaRow('Long Presence', snapshot.topLongPresenceSummary),
          if (snapshot.topGuardInteractionSummary.trim().isNotEmpty)
            _metaRow('Guard Note', snapshot.topGuardInteractionSummary),
          if (snapshot.evidenceEventIds.isNotEmpty)
            _metaRow('Review Refs', snapshot.evidenceEventIds.join(', ')),
          if (canOpenEvents) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: ValueKey('live-activity-truth-open-events-${incident.id}'),
                onPressed: () {
                  widget.onOpenEventsForScope!(
                    snapshot.eventIds,
                    snapshot.selectedEventId,
                  );
                  _showLiveOpsFeedback(
                    'Events scope warmed for activity truth.',
                    label: 'EVENTS SCOPE',
                    detail:
                        'The scoped evidence handoff stays pinned in the context rail while the incident board remains in place.',
                    accent: const Color(0xFF67E8F9),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF23547C)),
                  foregroundColor: const Color(0xFF8FD1FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('OPEN EVENTS SCOPE'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_SuppressedSceneReviewContext> _suppressedSceneReviewsForIncident(
    _IncidentRecord incident,
  ) {
    final siteId = incident.site.trim();
    final output = <_SuppressedSceneReviewContext>[];
    for (final intel in widget.events.whereType<IntelligenceReceived>()) {
      if (intel.siteId.trim() != siteId) {
        continue;
      }
      if (intel.sourceType != 'hardware' && intel.sourceType != 'dvr') {
        continue;
      }
      final review =
          widget.sceneReviewByIntelligenceId[intel.intelligenceId.trim()];
      if (review == null) {
        continue;
      }
      final decisionLabel = review.decisionLabel.trim().toLowerCase();
      final decisionSummary = review.decisionSummary.trim().toLowerCase();
      if (!decisionLabel.contains('suppress') &&
          !decisionSummary.contains('suppress')) {
        continue;
      }
      output.add(
        _SuppressedSceneReviewContext(intelligence: intel, review: review),
      );
    }
    output.sort(
      (a, b) => b.review.reviewedAtUtc.compareTo(a.review.reviewedAtUtc),
    );
    return output.take(3).toList(growable: false);
  }

  Widget _suppressedSceneReviewQueue(
    List<_SuppressedSceneReviewContext> entries,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4DFEA)),
        color: const Color(0xFF13131E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Suppressed ${widget.videoOpsLabel} Reviews',
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _contextChip(
                label: '${entries.length} internal',
                foreground: const Color(0xFFBFD7F2),
                background: const Color(0x149AB1CF),
                border: const Color(0x339AB1CF),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Recent ${widget.videoOpsLabel} reviews ONYX held below the client notification threshold for this site.',
            style: GoogleFonts.inter(
              color: const Color(0xFF556B80),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map((entry) {
            final item = entry.value;
            final intel = item.intelligence;
            final review = item.review;
            final cameraLabel = (intel.cameraId ?? '').trim();
            final zoneLabel = (intel.zone ?? '').trim();
            final sourceLabel = review.sourceLabel.trim();
            final postureLabel = review.postureLabel.trim();
            return Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                bottom: entry.key == entries.length - 1 ? 0 : 8,
              ),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _commandPanelColor,
                border: Border.all(color: _commandBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          intel.headline.trim(),
                          style: GoogleFonts.inter(
                            color: _commandTitleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _hhmm(review.reviewedAtUtc.toLocal()),
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFF8FA7C8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.decisionSummary.trim().isEmpty
                        ? 'Suppressed because the activity remained below threshold.'
                        : review.decisionSummary.trim(),
                    style: GoogleFonts.inter(
                      color: _commandTitleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scene review: ${review.summary.trim()}',
                    style: GoogleFonts.inter(
                      color: _commandBodyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _contextChip(
                        label: sourceLabel.isEmpty ? 'metadata' : sourceLabel,
                        foreground: const Color(0xFFFDE68A),
                        background: const Color(0x145B3A16),
                        border: const Color(0x665B3A16),
                      ),
                      _contextChip(
                        label: postureLabel.isEmpty ? 'reviewed' : postureLabel,
                        foreground: const Color(0xFF86EFAC),
                        background: const Color(0x1420643B),
                        border: const Color(0x6634D399),
                      ),
                      if (cameraLabel.isNotEmpty)
                        _contextChip(
                          label: cameraLabel,
                          foreground: const Color(0xFF67E8F9),
                          background: const Color(0x1122D3EE),
                          border: const Color(0x5522D3EE),
                        ),
                      if (zoneLabel.isNotEmpty)
                        _contextChip(
                          label: zoneLabel,
                          foreground: const Color(0xFF556B80),
                          background: const Color(0xFF1A1A2E),
                          border: const Color(0xFFD4DFEA),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _PartnerLiveProgressSummary? _partnerProgressForIncident(
    _IncidentRecord incident,
  ) {
    final incidentId = incident.id.trim();
    if (incidentId.isEmpty) {
      return null;
    }
    final candidateDispatchIds = <String>{
      incidentId,
      if (incidentId.startsWith('INC-')) incidentId.substring(4).trim(),
    }..removeWhere((value) => value.isEmpty);
    final declarations = widget.events
        .whereType<PartnerDispatchStatusDeclared>()
        .where(
          (event) => candidateDispatchIds.contains(event.dispatchId.trim()),
        )
        .toList(growable: false);
    if (declarations.isEmpty) {
      return null;
    }
    final ordered = [...declarations]
      ..sort((a, b) {
        final occurredAtCompare = a.occurredAt.compareTo(b.occurredAt);
        if (occurredAtCompare != 0) {
          return occurredAtCompare;
        }
        return a.sequence.compareTo(b.sequence);
      });
    final first = ordered.first;
    final latest = ordered.last;
    final firstOccurrenceByStatus = <PartnerDispatchStatus, DateTime>{};
    for (final event in ordered) {
      firstOccurrenceByStatus.putIfAbsent(event.status, () => event.occurredAt);
    }
    return _PartnerLiveProgressSummary(
      dispatchId: first.dispatchId,
      clientId: first.clientId,
      siteId: first.siteId,
      partnerLabel: first.partnerLabel,
      latestStatus: latest.status,
      latestOccurredAt: latest.occurredAt,
      declarationCount: ordered.length,
      firstOccurrenceByStatus: firstOccurrenceByStatus,
    );
  }

  _PartnerLiveTrendSummary? _partnerTrendSummary(
    _PartnerLiveProgressSummary progress,
  ) {
    final clientId = progress.clientId.trim();
    final siteId = progress.siteId.trim();
    final partnerLabel = progress.partnerLabel.trim().toUpperCase();
    if (clientId.isEmpty ||
        siteId.isEmpty ||
        partnerLabel.isEmpty ||
        widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final latestDate = reports.first.date.trim();
    final matchingRows = <SovereignReportPartnerScoreboardRow>[];
    SovereignReportPartnerScoreboardRow? currentRow;
    for (final report in reports) {
      final reportDate = report.date.trim();
      for (final row in report.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardRowMatches(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        matchingRows.add(row);
        if (reportDate == latestDate) {
          currentRow = row;
        }
      }
    }
    if (matchingRows.isEmpty) {
      for (final report in reports) {
        final reportDate = report.date.trim();
        for (final row in report.partnerProgression.scoreboardRows) {
          if (row.partnerLabel.trim().toUpperCase() != partnerLabel) {
            continue;
          }
          matchingRows.add(row);
          if (reportDate == latestDate) {
            currentRow = row;
          }
        }
      }
    }
    if (matchingRows.isEmpty) {
      for (final report in reports) {
        final reportDate = report.date.trim();
        for (final row in report.partnerProgression.scoreboardRows) {
          matchingRows.add(row);
          if (currentRow == null && reportDate == latestDate) {
            currentRow = row;
          }
        }
      }
    }
    currentRow ??= matchingRows.isEmpty ? null : matchingRows.first;
    if (currentRow == null) {
      return null;
    }
    final priorSeverityScores = <double>[];
    final priorAcceptedDelayMinutes = <double>[];
    final priorOnSiteDelayMinutes = <double>[];
    for (final report in reports) {
      if (report.date.trim() == latestDate) {
        continue;
      }
      for (final row in report.partnerProgression.scoreboardRows) {
        if (!_partnerScoreboardRowMatches(
          row,
          clientId: clientId,
          siteId: siteId,
          partnerLabel: partnerLabel,
        )) {
          continue;
        }
        priorSeverityScores.add(_partnerSeverityScore(row));
        if (row.averageAcceptedDelayMinutes > 0) {
          priorAcceptedDelayMinutes.add(row.averageAcceptedDelayMinutes);
        }
        if (row.averageOnSiteDelayMinutes > 0) {
          priorOnSiteDelayMinutes.add(row.averageOnSiteDelayMinutes);
        }
      }
    }
    return _PartnerLiveTrendSummary(
      reportDays: matchingRows.length,
      currentScoreLabel: _partnerDominantScoreLabel(currentRow),
      trendLabel: _partnerTrendLabel(currentRow, priorSeverityScores),
      trendReason: _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: priorSeverityScores,
        priorAcceptedDelayMinutes: priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: priorOnSiteDelayMinutes,
      ),
    );
  }

  _PartnerLiveTrendSummary? _fallbackPartnerTrendSummary() {
    if (widget.morningSovereignReportHistory.isEmpty) {
      return null;
    }
    final reports = [...widget.morningSovereignReportHistory]
      ..sort(
        (a, b) => b.generatedAtUtc.toUtc().compareTo(a.generatedAtUtc.toUtc()),
      );
    if (reports.isEmpty) {
      return null;
    }
    final currentRows = reports.first.partnerProgression.scoreboardRows;
    if (currentRows.isEmpty) {
      return null;
    }
    final currentRow = currentRows.first;
    final priorSeverityScores = <double>[];
    final priorAcceptedDelayMinutes = <double>[];
    final priorOnSiteDelayMinutes = <double>[];
    for (final report in reports.skip(1)) {
      if (report.partnerProgression.scoreboardRows.isEmpty) {
        continue;
      }
      final row = report.partnerProgression.scoreboardRows.first;
      priorSeverityScores.add(_partnerSeverityScore(row));
      if (row.averageAcceptedDelayMinutes > 0) {
        priorAcceptedDelayMinutes.add(row.averageAcceptedDelayMinutes);
      }
      if (row.averageOnSiteDelayMinutes > 0) {
        priorOnSiteDelayMinutes.add(row.averageOnSiteDelayMinutes);
      }
    }
    return _PartnerLiveTrendSummary(
      reportDays: reports.length,
      currentScoreLabel: _partnerDominantScoreLabel(currentRow),
      trendLabel: _partnerTrendLabel(currentRow, priorSeverityScores),
      trendReason: _partnerTrendReason(
        currentRow: currentRow,
        priorSeverityScores: priorSeverityScores,
        priorAcceptedDelayMinutes: priorAcceptedDelayMinutes,
        priorOnSiteDelayMinutes: priorOnSiteDelayMinutes,
      ),
    );
  }

  double _partnerSeverityScore(SovereignReportPartnerScoreboardRow row) {
    final dispatchCount = row.dispatchCount <= 0 ? 1 : row.dispatchCount;
    final rawScore = (row.criticalCount * 3) + row.watchCount - row.strongCount;
    return rawScore / dispatchCount;
  }

  String _partnerDominantScoreLabel(SovereignReportPartnerScoreboardRow row) {
    if (row.criticalCount > 0) {
      return 'CRITICAL';
    }
    if (row.watchCount > 0) {
      return 'WATCH';
    }
    if (row.onTrackCount > 0) {
      return 'ON TRACK';
    }
    if (row.strongCount > 0) {
      return 'STRONG';
    }
    return '';
  }

  bool _partnerScoreboardRowMatches(
    SovereignReportPartnerScoreboardRow row, {
    required String clientId,
    required String siteId,
    required String partnerLabel,
  }) {
    final rowLabel = row.partnerLabel.trim().toUpperCase();
    final rowClientId = row.clientId.trim();
    final rowSiteId = row.siteId.trim();
    if (rowLabel != partnerLabel) {
      return false;
    }
    if (rowClientId == clientId && rowSiteId == siteId) {
      return true;
    }
    if (rowSiteId == siteId) {
      return true;
    }
    return rowClientId == clientId;
  }

  String _partnerTrendLabel(
    SovereignReportPartnerScoreboardRow currentRow,
    List<double> priorSeverityScores,
  ) {
    if (priorSeverityScores.isEmpty) {
      return 'NEW';
    }
    final priorAverage =
        priorSeverityScores.reduce((left, right) => left + right) /
        priorSeverityScores.length;
    final currentScore = _partnerSeverityScore(currentRow);
    if (currentScore <= priorAverage - 0.35) {
      return 'IMPROVING';
    }
    if (currentScore >= priorAverage + 0.35) {
      return 'SLIPPING';
    }
    return 'STABLE';
  }

  String _partnerTrendReason({
    required SovereignReportPartnerScoreboardRow currentRow,
    required List<double> priorSeverityScores,
    required List<double> priorAcceptedDelayMinutes,
    required List<double> priorOnSiteDelayMinutes,
  }) {
    if (priorSeverityScores.isEmpty) {
      return 'First recorded shift in the 7-day partner window.';
    }
    final trendLabel = _partnerTrendLabel(currentRow, priorSeverityScores);
    final priorAcceptedAverage = priorAcceptedDelayMinutes.isEmpty
        ? null
        : priorAcceptedDelayMinutes.reduce((left, right) => left + right) /
              priorAcceptedDelayMinutes.length;
    final priorOnSiteAverage = priorOnSiteDelayMinutes.isEmpty
        ? null
        : priorOnSiteDelayMinutes.reduce((left, right) => left + right) /
              priorOnSiteDelayMinutes.length;
    switch (trendLabel) {
      case 'IMPROVING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes > 0 &&
            currentRow.averageAcceptedDelayMinutes <=
                priorAcceptedAverage - 2.0) {
          return 'Acceptance timing improved against the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes > 0 &&
            currentRow.averageOnSiteDelayMinutes <= priorOnSiteAverage - 2.0) {
          return 'On-site timing improved against the prior 7-day average.';
        }
        return 'Current shift severity improved against the prior 7-day average.';
      case 'SLIPPING':
        if (priorAcceptedAverage != null &&
            currentRow.averageAcceptedDelayMinutes >=
                priorAcceptedAverage + 2.0) {
          return 'Acceptance timing slipped beyond the prior 7-day average.';
        }
        if (priorOnSiteAverage != null &&
            currentRow.averageOnSiteDelayMinutes >= priorOnSiteAverage + 2.0) {
          return 'On-site timing slipped beyond the prior 7-day average.';
        }
        return 'Current shift severity slipped against the prior 7-day average.';
      case 'STABLE':
      case 'NEW':
        return 'Current shift is holding close to the prior 7-day performance.';
    }
    return '';
  }

  Widget _partnerProgressCard(
    _PartnerLiveProgressSummary progress,
    String incidentId,
  ) {
    final trend =
        _partnerTrendSummary(progress) ?? _fallbackPartnerTrendSummary();
    return Container(
      key: ValueKey<String>('live-partner-progress-card-$incidentId'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4DFEA)),
        color: const Color(0xFF13131E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Partner Progression',
                style: GoogleFonts.inter(
                  color: const Color(0xFF172638),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              _contextChip(
                label: '${progress.declarationCount} declarations',
                foreground: const Color(0xFF8FD1FF),
                background: const Color(0x1122D3EE),
                border: const Color(0x5522D3EE),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${progress.partnerLabel} • Latest ${_partnerDispatchStatusLabel(progress.latestStatus)} • ${_hhmm(progress.latestOccurredAt.toLocal())}',
            style: GoogleFonts.inter(
              color: const Color(0xFF172638),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _contextChip(
                label: 'Dispatch ${progress.dispatchId}',
                foreground: const Color(0xFF556B80),
                background: const Color(0xFF1A1A2E),
                border: const Color(0xFFD4DFEA),
              ),
              if (trend != null)
                _contextChip(
                  label: '7D ${trend.trendLabel} • ${trend.reportDays}d',
                  foreground: _partnerTrendColor(trend.trendLabel),
                  background: _partnerTrendColor(
                    trend.trendLabel,
                  ).withValues(alpha: 0.12),
                  border: _partnerTrendColor(
                    trend.trendLabel,
                  ).withValues(alpha: 0.45),
                ),
              for (final status in PartnerDispatchStatus.values)
                _partnerProgressChip(
                  incidentId: incidentId,
                  status: status,
                  timestamp: progress.firstOccurrenceByStatus[status],
                ),
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: 6),
            Text(
              trend.trendReason,
              key: ValueKey<String>('live-partner-trend-reason-$incidentId'),
              style: GoogleFonts.inter(
                color: _partnerTrendColor(trend.trendLabel),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (widget.morningSovereignReportHistory.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '7-day partner history is available for review in Admin and Governance.',
              key: ValueKey<String>('live-partner-trend-reason-$incidentId'),
              style: GoogleFonts.inter(
                color: const Color(0xFF556B80),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _partnerProgressChip({
    required String incidentId,
    required PartnerDispatchStatus status,
    required DateTime? timestamp,
  }) {
    final reached = timestamp != null;
    final tone = _partnerProgressTone(status);
    return Container(
      key: ValueKey<String>('live-partner-progress-$incidentId-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: reached ? tone.$2 : const Color(0xFF1A1A2E),
        border: Border.all(color: reached ? tone.$3 : const Color(0xFFD4DFEA)),
      ),
      child: Text(
        reached
            ? '${_partnerDispatchStatusLabel(status)} ${_hhmm(timestamp.toLocal())}'
            : '${_partnerDispatchStatusLabel(status)} Pending',
        style: GoogleFonts.inter(
          color: reached ? tone.$1 : const Color(0xFF556B80),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _voipTab(_IncidentRecord? incident, {required bool embeddedScroll}) {
    final wide = embeddedScroll;
    if (incident == null) {
      return _contextTabRecoveryDeck(
        key: const ValueKey('live-operations-voip-recovery'),
        eyebrow: 'VOIP CONTEXT READY',
        title: 'No live call is pinned yet.',
        summary:
            'Pick the lead incident and the call script lands here. Keep this tab open when client pressure matters.',
        accent: const Color(0xFF22D3EE),
        clientCommsSnapshot: widget.clientCommsSnapshot,
      );
    }
    final duress = _duressDetected(incident);
    final transcript = <Map<String, String>>[
      <String, String>{
        'speaker': 'AI',
        'timestamp': '22:14:12',
        'message':
            'Good evening. ONYX Security Operations. We detected an alarm at your north gate. Please confirm your safe word.',
      },
      <String, String>{
        'speaker': 'CLIENT',
        'timestamp': '22:14:18',
        'message': duress ? '... please hold.' : 'Phoenix.',
      },
      <String, String>{
        'speaker': 'AI',
        'timestamp': '22:14:21',
        'message': duress
            ? 'Voice stress confidence dropped. Escalation recommended.'
            : 'Safe-word verification complete. Response team remains en route.',
      },
    ];
    final callAccent = duress
        ? const Color(0xFFEF4444)
        : const Color(0xFF22D3EE);
    final latestMessage = transcript.last['message'] ?? '';
    final items = List<Widget>.generate(transcript.length, (index) {
      final entry = transcript[index];
      final speaker = entry['speaker'] ?? '';
      final timestamp = entry['timestamp'] ?? '';
      final message = entry['message'] ?? '';
      final aiSpeaker = speaker == 'AI';
      return Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: aiSpeaker ? const Color(0xFFEAF8FB) : _commandPanelColor,
          border: Border.all(
            color: aiSpeaker ? const Color(0xFFBCDCE4) : _commandBorderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  speaker,
                  style: GoogleFonts.inter(
                    color: aiSpeaker
                        ? const Color(0xFF22D3EE)
                        : _commandTitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  timestamp,
                  style: GoogleFonts.robotoMono(
                    color: _commandMutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: GoogleFonts.inter(
                color: index == transcript.length - 1 && duress
                    ? const Color(0xFFB42318)
                    : _commandTitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
    final callFocusCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              callAccent.withValues(alpha: 0.14),
              _commandPanelColor,
            ),
            _commandPanelTintColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: callAccent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: callAccent.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: callAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: callAccent.withValues(alpha: 0.42)),
                ),
                child: Text(
                  duress ? 'CALL ALERT' : 'CALL LIVE',
                  style: GoogleFonts.inter(
                    color: callAccent,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                incident.id,
                style: GoogleFonts.robotoMono(
                  color: const Color(0xFF4D7FAE),
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            duress
                ? 'Escalate the caller now.'
                : 'Client is verified. Hold the line calm.',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            latestMessage,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 10.1,
              fontWeight: FontWeight.w700,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _commsChip(
                icon: Icons.call_rounded,
                label: duress ? 'voice stress high' : 'caller verified',
                accent: callAccent,
              ),
              _commsChip(
                icon: Icons.location_on_outlined,
                label: incident.site,
                accent: const Color(0xFF3B82F6),
              ),
              _commsChip(
                icon: Icons.schedule_rounded,
                label: transcript.last['timestamp'] ?? '',
                accent: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
    final statusBanner = Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: callAccent.withValues(alpha: 0.12),
        border: Border.all(color: callAccent.withValues(alpha: 0.36)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: callAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'VoIP Call Active - Recording in progress',
              style: GoogleFonts.inter(
                color: _commandTitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (!wide) {
      return Column(
        children: [
          callFocusCard,
          const SizedBox(height: 6),
          statusBanner,
          const SizedBox(height: 6),
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const SizedBox(height: 6),
          ],
        ],
      );
    }
    return ListView.separated(
      itemCount: items.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == 0) return callFocusCard;
        if (index == 1) return statusBanner;
        return items[index - 2];
      },
    );
  }

  Widget _visualTab(_IncidentRecord? incident, {required bool embeddedScroll}) {
    if (incident == null) {
      return _contextTabRecoveryDeck(
        key: const ValueKey('live-operations-visual-recovery'),
        eyebrow: 'VISUAL CONTEXT READY',
        title: 'No camera comparison is pinned yet.',
        summary:
            'The visual rail can still recover the lead incident, reopen the action ladder, or keep the scoped Client Comms posture visible while comparison evidence comes online.',
        accent: const Color(0xFFFACC15),
        clientCommsSnapshot: widget.clientCommsSnapshot,
      );
    }
    final snapshotAvailable = (incident.snapshotUrl ?? '').trim().isNotEmpty;
    final clipAvailable = (incident.clipUrl ?? '').trim().isNotEmpty;
    final score = _visualMatchScoreForIncident(incident);
    final scoreColor = score >= 95
        ? const Color(0xFF10B981)
        : score >= 60
        ? const Color(0xFFFACC15)
        : const Color(0xFFEF4444);
    final visualSummaryCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              scoreColor.withValues(alpha: 0.14),
              _commandPanelColor,
            ),
            _commandPanelTintColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scoreColor.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.42)),
                ),
                child: Text(
                  score < 60
                      ? 'VISUAL ALERT'
                      : score >= 95
                      ? 'VISUAL CLEAR'
                      : 'VISUAL WATCH',
                  style: GoogleFonts.inter(
                    color: scoreColor,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$score%',
                style: GoogleFonts.inter(
                  color: scoreColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            score < 60
                ? 'Visual mismatch needs human eyes.'
                : score >= 95
                ? 'Visual match is holding clean.'
                : 'Visuals are mostly clean. Keep watch.',
            style: GoogleFonts.inter(
              color: _commandTitleColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            snapshotAvailable || clipAvailable
                ? 'Proof is already attached to this incident. Compare quickly, then move.'
                : 'Live visual proof is still loading for this incident.',
            style: GoogleFonts.inter(
              color: _commandBodyColor,
              fontSize: 10.1,
              fontWeight: FontWeight.w700,
              height: 1.28,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _commsChip(
                icon: Icons.camera_alt_outlined,
                label: snapshotAvailable
                    ? 'snapshot ready'
                    : 'snapshot pending',
                accent: snapshotAvailable
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF59E0B),
              ),
              _commsChip(
                icon: Icons.movie_outlined,
                label: clipAvailable ? 'clip ready' : 'clip pending',
                accent: clipAvailable
                    ? const Color(0xFF34D399)
                    : const Color(0xFFF59E0B),
              ),
              _commsChip(
                icon: Icons.location_on_outlined,
                label: incident.site,
                accent: const Color(0xFF22D3EE),
              ),
            ],
          ),
        ],
      ),
    );
    final children = <Widget>[
      visualSummaryCard,
      const SizedBox(height: 8),
      _metaRow('NORM', 'NIGHT BASELINE'),
      _metaRow('LIVE', incident.timestamp),
      Row(
        children: [
          Text(
            'Match Score',
            style: GoogleFonts.inter(
              color: _commandMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '$score%',
            style: GoogleFonts.inter(
              color: scoreColor,
              fontSize: 38,
              height: 0.9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _metaRow(
              'Snapshot',
              snapshotAvailable ? 'READY' : 'PENDING',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metaRow('Clip', clipAvailable ? 'READY' : 'PENDING'),
          ),
        ],
      ),
      if (snapshotAvailable || clipAvailable) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF2FBF7),
            border: Border.all(color: const Color(0xFFB9DEC8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (snapshotAvailable)
                _anomalyRow('Snapshot reference captured', 100),
              if (snapshotAvailable && clipAvailable) const SizedBox(height: 4),
              if (clipAvailable) _anomalyRow('Clip reference captured', 100),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (score < 60) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFFF2F2),
            border: Border.all(color: const Color(0xFFE7B4B4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _anomalyRow('Gate status changed', 94),
              const SizedBox(height: 4),
              _anomalyRow('Perimeter breach line', 91),
              const SizedBox(height: 4),
              _anomalyRow('Unauthorized vehicle', 86),
            ],
          ),
        ),
      ] else
        _metaRow('Anomalies', '0'),
    ];
    if (!embeddedScroll) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return ListView(children: children);
  }

  Widget _anomalyRow(String label, int confidence) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFC3C9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$confidence%',
          style: GoogleFonts.inter(
            color: const Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _vigilancePanel({required bool embeddedScroll}) {
    final wide = embeddedScroll;
    Widget vigilanceTile(int index) {
      final guard = _vigilance[index];
      final selected = _focusedVigilanceCallsign == guard.callsign;
      final statusColor = guard.decayLevel <= 75
          ? const Color(0xFF10B981)
          : guard.decayLevel <= 90
          ? const Color(0xFFF59E0B)
          : const Color(0xFFEF4444);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('live-operations-vigilance-tile-${guard.callsign}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => _setFocusedVigilanceGuard(guard.callsign),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? statusColor.withValues(alpha: 0.16)
                  : _commandPanelTintColor,
              border: Border.all(
                color: selected
                    ? statusColor.withValues(alpha: 0.72)
                    : _commandBorderColor,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            guard.callsign,
                            style: GoogleFonts.inter(
                              color: _commandTitleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: statusColor.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                'FOCUS',
                                style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 8.8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'Last check-in: ${guard.lastCheckIn}',
                        style: GoogleFonts.inter(
                          color: _commandMutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  height: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: guard.sparkline
                        .map((value) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: (value.clamp(10, 100) / 100) * 18,
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${guard.decayLevel}%',
                  style: GoogleFonts.inter(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_vigilance.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Icon(
              Icons.shield_moon_outlined,
              color: _commandMutedColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'No guards online — check-in signals will appear here.',
              style: GoogleFonts.inter(
                color: _commandMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return wide
        ? ListView.separated(
            itemCount: _vigilance.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) => vigilanceTile(index),
          )
        : Column(
            children: [
              for (var i = 0; i < _vigilance.length; i++) ...[
                vigilanceTile(i),
                if (i < _vigilance.length - 1) const SizedBox(height: 6),
              ],
            ],
          );
  }

  Widget _ledgerPanel(List<_LedgerEntry> ledger, {bool embeddedScroll = true}) {
    final verifiedCount = ledger
        .where((entry) => _isLedgerEntryVerified(entry))
        .length;
    final chainVerified = ledger.isNotEmpty && verifiedCount == ledger.length;
    final panelPadding = EdgeInsets.all(embeddedScroll ? 10 : 8);
    final headerSpacing = embeddedScroll ? 10.0 : 8.0;
    final sectionSpacing = embeddedScroll ? 8.0 : 6.0;
    final visibleEntries = ledger.take(embeddedScroll ? 4 : 3).toList();
    final rows = List<Widget>.generate(visibleEntries.length, (index) {
      final entry = visibleEntries[index];
      final style = _ledgerStyle(entry.type);
      final verified = _isLedgerEntryVerified(entry);
      final hh = entry.timestamp.toLocal().hour.toString().padLeft(2, '0');
      final mm = entry.timestamp.toLocal().minute.toString().padLeft(2, '0');
      final ss = entry.timestamp.toLocal().second.toString().padLeft(2, '0');
      return Tooltip(
        message: entry.hash,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: _commandPanelTintColor,
            border: Border.all(color: _commandBorderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: style.color.withValues(alpha: 0.16),
                ),
                child: Icon(style.icon, size: 14, color: style.color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _ledgerTypeLabel(entry.type),
                          style: GoogleFonts.inter(
                            color: style.color,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: verified
                                ? const Color(0x1A34D399)
                                : const Color(0x1AF59E0B),
                            border: Border.all(
                              color: verified
                                  ? const Color(0x6634D399)
                                  : const Color(0x66F59E0B),
                            ),
                          ),
                          child: Text(
                            verified ? 'VERIFIED' : 'PENDING',
                            style: GoogleFonts.robotoMono(
                              color: verified
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFBBF24),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$hh:$mm:$ss',
                          style: GoogleFonts.robotoMono(
                            color: _commandMutedColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.description,
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if ((entry.actor ?? '').isNotEmpty)
                          Text(
                            'Actor: ${entry.actor}',
                            style: GoogleFonts.inter(
                              color: _commandBodyColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if ((entry.reasonCode ?? '').isNotEmpty) ...[
                          if ((entry.actor ?? '').isNotEmpty)
                            const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: style.color.withValues(alpha: 0.14),
                              border: Border.all(
                                color: style.color.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Text(
                              entry.reasonCode!,
                              style: GoogleFonts.robotoMono(
                                color: style.color,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
    return Container(
      key: const ValueKey('live-operations-ledger-preview'),
      width: double.infinity,
      padding: panelPadding,
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _commandBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D28D9).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.36),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Color(0xFFA78BFA),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOVEREIGN LEDGER',
                      style: GoogleFonts.inter(
                        color: _commandTitleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Immutable event chain',
                      style: GoogleFonts.inter(
                        color: _commandBodyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: headerSpacing),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _commandPanelTintColor,
                border: Border.all(color: _commandBorderColor),
              ),
              child: Text(
                'No ledger events recorded yet for the current command window.',
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i < rows.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          SizedBox(height: sectionSpacing),
          Container(
            key: const ValueKey('live-operations-ledger-chain-status'),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: embeddedScroll ? 9 : 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: chainVerified
                  ? const Color(0x1434D399)
                  : const Color(0x14F59E0B),
              border: Border.all(
                color: chainVerified
                    ? const Color(0x3334D399)
                    : const Color(0x33F59E0B),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  chainVerified
                      ? Icons.verified_user_outlined
                      : Icons.pending_actions_outlined,
                  size: 16,
                  color: chainVerified
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFFFBBF24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chainVerified
                            ? 'Chain status: Verified'
                            : 'Chain status: Pending verification',
                        style: GoogleFonts.inter(
                          color: chainVerified
                              ? const Color(0xFF176B4A)
                              : const Color(0xFF8A5A00),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chainVerified
                            ? '$verifiedCount of ${ledger.length} events sealed${_lastLedgerVerificationAt == null ? '' : ' • ${_commsMomentLabel(_lastLedgerVerificationAt)}'}'
                            : '$verifiedCount of ${ledger.length} events sealed',
                        style: GoogleFonts.inter(
                          color: _commandBodyColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: sectionSpacing),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ledger.length} events recorded',
                  style: GoogleFonts.inter(
                    color: _commandBodyColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                key: const ValueKey('live-operations-ledger-verify-chain'),
                onPressed: ledger.isEmpty
                    ? null
                    : () => _verifyLedgerChain(ledger),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6D28D9),
                  backgroundColor: _commandPanelColor,
                  side: const BorderSide(color: Color(0xFFD5C0FF)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
                child: Text(
                  chainVerified ? 'Re-run Verify' : 'Verify Chain',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isLedgerEntryVerified(_LedgerEntry entry) =>
      entry.verified || _verifiedLedgerEntryIds.contains(entry.id);

  void _verifyLedgerChain(List<_LedgerEntry> ledger) {
    if (ledger.isEmpty) {
      return;
    }
    setState(() {
      _verifiedLedgerEntryIds = <String>{
        ..._verifiedLedgerEntryIds,
        ...ledger.map((entry) => entry.id),
      };
      _lastLedgerVerificationAt = DateTime.now().toUtc();
    });
  }

  Widget _contextTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 480;
        if (compact) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _ContextTab.values
                .map((tab) {
                  final selected = tab == _activeTab;
                  return _contextTabButton(tab, selected, compact: true);
                })
                .toList(growable: false),
          );
        }
        return Row(
          children: _ContextTab.values
              .map((tab) {
                final selected = tab == _activeTab;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _contextTabButton(tab, selected, compact: false),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  int _visualMatchScoreForIncident(_IncidentRecord incident) {
    return incident.priority == _IncidentPriority.p1Critical
        ? 58
        : incident.priority == _IncidentPriority.p2High
        ? 74
        : 96;
  }

  _GuardVigilance? _guardAttentionLeadFrom(List<_GuardVigilance> guards) {
    if (guards.isEmpty) {
      return null;
    }
    return guards.reduce(
      (best, candidate) =>
          candidate.decayLevel > best.decayLevel ? candidate : best,
    );
  }

  _GuardVigilance? get _focusedVigilanceGuard {
    if (_vigilance.isEmpty) {
      return null;
    }
    final focusedCallsign = _focusedVigilanceCallsign;
    if (focusedCallsign != null) {
      for (final guard in _vigilance) {
        if (guard.callsign == focusedCallsign) {
          return guard;
        }
      }
    }
    return _guardAttentionLeadFrom(_vigilance);
  }

  void _setFocusedVigilanceGuard(String callsign) {
    if (_focusedVigilanceCallsign == callsign) {
      return;
    }
    setState(() {
      _focusedVigilanceCallsign = callsign;
    });
  }

  Future<void> _openContextRailQueue(_IncidentRecord? activeIncident) async {
    if (activeIncident != null && _activeIncidentId != activeIncident.id) {
      _focusIncidentFromBanner(activeIncident);
    } else if (activeIncident == null && _incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    await _jumpToControlInboxPanel();
    _showLiveOpsFeedback(
      activeIncident == null
          ? 'Context rail reopened the control inbox.'
          : 'Context rail reopened the control inbox for ${activeIncident.id}.',
      label: 'CONTEXT RAIL',
      detail: activeIncident == null
          ? 'The queue came forward in the left rail while the right-side context stayed pinned for the next incident.'
          : 'The selected incident stayed active while the left rail reopened high-priority reply work in place.',
      accent: const Color(0xFFF59E0B),
    );
  }

  Future<void> _openContextRailTab(
    _IncidentRecord? activeIncident,
    _ContextTab tab,
  ) async {
    if (_activeTab != tab) {
      setState(() {
        _activeTab = tab;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureContextAndVigilancePanelVisible();
    final tabLabel = _tabLabel(tab);
    _showLiveOpsFeedback(
      activeIncident == null
          ? 'Context rail opened $tabLabel.'
          : 'Context rail opened $tabLabel for ${activeIncident.id}.',
      label: 'CONTEXT RAIL',
      detail: activeIncident == null
          ? 'The right rail stayed active so the next incident can land without losing operator context.'
          : 'The context rail kept ${activeIncident.id} pinned while ${tabLabel.toLowerCase()} posture moved forward in place.',
      accent: switch (tab) {
        _ContextTab.details => const Color(0xFF22D3EE),
        _ContextTab.voip => const Color(0xFF3B82F6),
        _ContextTab.visual => const Color(0xFF10B981),
      },
    );
  }

  void _focusGuardAttentionFromContext() {
    final guard = _guardAttentionLeadFrom(_vigilance);
    if (guard == null) {
      return;
    }
    setState(() {
      _focusedVigilanceCallsign = guard.callsign;
    });
    final accent = guard.decayLevel >= 90
        ? const Color(0xFFEF4444)
        : guard.decayLevel >= 75
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    _showLiveOpsFeedback(
      'Guard attention centered on ${guard.callsign}.',
      label: 'GUARD VIGILANCE',
      detail:
          '${guard.callsign} now anchors the vigilance rail with ${guard.decayLevel}% decay and last check-in ${guard.lastCheckIn}.',
      accent: accent,
    );
  }

  Future<void> _openIncidentQueueBoardFocus(_IncidentRecord? incident) async {
    if (incident != null && _activeIncidentId != incident.id) {
      _focusIncidentFromBanner(incident);
    } else if (incident == null && _incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureActionLadderPanelVisible();
    final active = incident ?? _activeIncident;
    _showLiveOpsFeedback(
      active == null
          ? 'Rail focus moved to the active board.'
          : 'Board focus opened for ${active.id}.',
      label: 'INCIDENT RAIL',
      detail: active == null
          ? 'The board is centered and ready for the next live incident without leaving the rail.'
          : 'The selected incident stayed pinned while the action ladder moved into view for ${active.id}.',
      accent: const Color(0xFF22D3EE),
    );
  }

  Future<void> _openIncidentQueueContextFocus(
    _IncidentRecord? incident,
    _ContextTab tab,
  ) async {
    if (incident != null && _activeIncidentId != incident.id) {
      _focusIncidentFromBanner(incident);
    } else if (incident == null && _incidents.isNotEmpty) {
      _focusLeadIncident();
    }
    if (_activeTab != tab) {
      setState(() {
        _activeTab = tab;
      });
    }
    await Future<void>.delayed(Duration.zero);
    await _ensureContextAndVigilancePanelVisible();
    final active = incident ?? _activeIncident;
    final tabLabel = _tabLabel(tab);
    _showLiveOpsFeedback(
      active == null
          ? '$tabLabel context opened from the incident rail.'
          : '$tabLabel context opened for ${active.id}.',
      label: 'INCIDENT RAIL',
      detail: active == null
          ? 'The right rail stayed active so the next incident can land without losing operator context.'
          : 'The incident rail kept ${active.id} selected while ${tabLabel.toLowerCase()} posture moved forward in place.',
      accent: switch (tab) {
        _ContextTab.details => const Color(0xFF22D3EE),
        _ContextTab.voip => const Color(0xFF3B82F6),
        _ContextTab.visual => const Color(0xFF10B981),
      },
    );
  }

  Future<void> _openIncidentQueueQueueFocus() async {
    await _jumpToControlInboxPanel();
    final active = _activeIncident;
    _showLiveOpsFeedback(
      active == null
          ? 'Queue focus opened from the incident rail.'
          : 'Queue focus opened for ${active.id}.',
      label: 'INCIDENT RAIL',
      detail: active == null
          ? 'The left rail moved directly into reply work while the board stayed ready for the next selected incident.'
          : 'Reply work came forward in the left rail while ${active.id} remained the active live incident.',
      accent: const Color(0xFFF59E0B),
    );
  }

  Future<void> _focusCriticalIncidentFromQueue(_IncidentRecord incident) async {
    _focusIncidentFromBanner(incident);
    await Future<void>.delayed(Duration.zero);
    await _ensureActionLadderPanelVisible();
    _showLiveOpsFeedback(
      'Critical incident focused for ${incident.id}.',
      label: 'INCIDENT RAIL',
      detail:
          'The highest-risk live incident moved into the board while the rest of the queue stayed visible for follow-through.',
      accent: const Color(0xFFEF4444),
    );
  }

  Widget _contextTabButton(
    _ContextTab tab,
    bool selected, {
    required bool compact,
  }) {
    final pill = Container(
      width: compact ? null : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF8FB) : _commandPanelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFFBCDCE4) : _commandBorderColor,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _tabLabel(tab),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: selected ? const Color(0xFF0F6D84) : _commandMutedColor,
        ),
      ),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _activeTab = tab;
          });
        },
        child: pill,
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    bool shellless = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        if (shellless) {
          return child;
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _commandPanelColor,
            border: Border.all(color: _commandBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _commandTitleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: _commandBodyColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (boundedHeight) Expanded(child: child) else child,
            ],
          ),
        );
      },
    );
  }

  Widget _chip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
    IconData? leadingIcon,
    String? tooltipMessage,
    VoidCallback? onTap,
    Key? key,
  }) {
    Widget child = Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: background,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 10, color: foreground),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if ((tooltipMessage ?? '').trim().isNotEmpty) {
      child = Tooltip(message: tooltipMessage!.trim(), child: child);
    }
    if (onTap == null) {
      return child;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: child,
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 180) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _commandMutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _commandTitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          }
          final labelWidth = constraints.maxWidth < 260 ? 84.0 : 114.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: _commandMutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _commandTitleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contextChip({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foreground,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _muted(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: _commandMutedColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _contextTabRecoveryDeck({
    required Key key,
    required String eyebrow,
    required String title,
    required String summary,
    required Color accent,
    required LiveClientCommsSnapshot? clientCommsSnapshot,
  }) {
    final criticalAlertIncident = _criticalAlertIncident;
    final leadIncident = _incidents.isEmpty
        ? null
        : (_criticalAlertIncident ?? _incidents.first);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _commandPanelColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 7.8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.inter(
                color: _commandTitleColor,
                fontSize: 10.2,
                fontWeight: FontWeight.w700,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              summary,
              style: GoogleFonts.inter(
                color: _commandBodyColor,
                fontSize: 9.2,
                fontWeight: FontWeight.w600,
                height: 1.52,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _contextChip(
                  label: _tabLabel(_activeTab),
                  foreground: accent,
                  background: accent.withValues(alpha: 0.12),
                  border: accent.withValues(alpha: 0.38),
                ),
                _contextChip(
                  label:
                      '${_incidents.length} live incident${_incidents.length == 1 ? '' : 's'}',
                  foreground: _commandMutedColor,
                  background: _commandPanelTintColor,
                  border: _commandBorderColor,
                ),
                if (leadIncident != null)
                  _contextChip(
                    label: 'Lead ${leadIncident.id}',
                    foreground: const Color(0xFF8FD1FF),
                    background: const Color(0x1A22D3EE),
                    border: const Color(0x5522D3EE),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (leadIncident != null)
                  _chip(
                    key: const ValueKey(
                      'live-operations-context-recovery-focus-lead',
                    ),
                    label: 'Focus lead incident',
                    foreground: const Color(0xFF0F6D84),
                    background: const Color(0xFFEAF8FB),
                    border: const Color(0xFFBCDCE4),
                    leadingIcon: Icons.center_focus_strong_rounded,
                    onTap: () async {
                      _focusLeadIncident();
                      await Future<void>.delayed(Duration.zero);
                      await _ensureContextAndVigilancePanelVisible();
                      _showLiveOpsFeedback(
                        'Lead lane context recovered.',
                        label: 'CONTEXT RECOVERY',
                        detail:
                            'Live Ops pinned the lead incident back into the board while keeping the ${_tabLabel(_activeTab).toLowerCase()} context active.',
                        accent: accent,
                      );
                    },
                  ),
                if (criticalAlertIncident != null)
                  _chip(
                    key: const ValueKey(
                      'live-operations-context-recovery-focus-critical',
                    ),
                    label: 'Focus critical',
                    foreground: const Color(0xFFFFD6D6),
                    background: const Color(0x1AEF4444),
                    border: const Color(0x66EF4444),
                    leadingIcon: Icons.warning_amber_rounded,
                    onTap: () async {
                      _focusIncidentFromBanner(criticalAlertIncident);
                      await Future<void>.delayed(Duration.zero);
                      await _ensureContextAndVigilancePanelVisible();
                      _showLiveOpsFeedback(
                        'Critical lane context recovered.',
                        label: 'CONTEXT RECOVERY',
                        detail:
                            'Live Ops pinned the critical incident back into the board while keeping the current context tab active.',
                        accent: const Color(0xFFEF4444),
                      );
                    },
                  ),
                _chip(
                  key: const ValueKey(
                    'live-operations-context-recovery-open-queue',
                  ),
                  label: 'Open action ladder',
                  foreground: const Color(0xFF2E6EA8),
                  background: const Color(0xFFEFF4FA),
                  border: const Color(0xFFC4D8EC),
                  leadingIcon: Icons.schedule_rounded,
                  onTap: () async {
                    await _openPendingActionsRecovery();
                  },
                ),
                if (clientCommsSnapshot != null)
                  _chip(
                    key: const ValueKey(
                      'live-operations-context-recovery-open-client-lane',
                    ),
                    label: 'Recover Client Comms',
                    foreground: const Color(0xFF0F6D84),
                    background: const Color(0xFFEAF8FB),
                    border: const Color(0xFFBCDCE4),
                    leadingIcon: Icons.forum_rounded,
                    onTap: () async {
                      await _openClientLaneRecovery(clientCommsSnapshot);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onApproveClientReplyDraft == null ||
        _controlInboxBusyDraftIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _controlInboxBusyDraftIds = {
        ..._controlInboxBusyDraftIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onApproveClientReplyDraft!.call(
        draft.updateId,
        approvedText: draft.draftText,
      );
      _showLiveOpsSnack(message.trim().isEmpty ? 'Draft approved.' : message);
    } catch (_) {
      _showLiveOpsSnack('Failed to approve AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxBusyDraftIds = _controlInboxBusyDraftIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Future<void> _editControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onUpdateClientReplyDraftText == null ||
        _controlInboxDraftEditBusyIds.contains(draft.updateId)) {
      return;
    }
    final controller = TextEditingController(text: draft.draftText);
    late final String? nextText;
    try {
      nextText = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: _commandPanelColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _commandBorderColor),
            ),
            title: Text(
              'Refine ONYX Draft',
              style: GoogleFonts.inter(
                color: _commandTitleColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      return Text(
                        _controlInboxDraftCueForSignals(
                          sourceText: draft.sourceText,
                          replyText: value.text,
                          clientVoiceProfileLabel:
                              draft.clientVoiceProfileLabel,
                          usesLearnedApprovalStyle:
                              draft.usesLearnedApprovalStyle,
                        ),
                        style: GoogleFonts.inter(
                          color: _commandBodyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.32,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    minLines: 5,
                    maxLines: 9,
                    style: GoogleFonts.inter(
                      color: _commandTitleColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Shape the final client-facing wording here.',
                      hintStyle: GoogleFonts.inter(
                        color: _commandMutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: _commandPanelTintColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _commandBorderColor,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _commandBorderColor,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _commandBorderStrongColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: _commandMutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D5B),
                  foregroundColor: const Color(0xFFEAF4FF),
                ),
                child: Text(
                  'Save Draft',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    }
    final normalizedText = (nextText ?? '').trim();
    if (!mounted ||
        normalizedText.isEmpty ||
        normalizedText == draft.draftText.trim()) {
      return;
    }
    setState(() {
      _controlInboxDraftEditBusyIds = {
        ..._controlInboxDraftEditBusyIds,
        draft.updateId,
      };
    });
    try {
      await widget.onUpdateClientReplyDraftText!.call(
        draft.updateId,
        normalizedText,
      );
      _showLiveOpsSnack('Draft wording updated for approval.');
    } catch (_) {
      _showLiveOpsSnack('Failed to update AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxDraftEditBusyIds = _controlInboxDraftEditBusyIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  Future<void> _rejectControlInboxDraft(LiveControlInboxDraft draft) async {
    if (widget.onRejectClientReplyDraft == null ||
        _controlInboxBusyDraftIds.contains(draft.updateId)) {
      return;
    }
    setState(() {
      _controlInboxBusyDraftIds = {
        ..._controlInboxBusyDraftIds,
        draft.updateId,
      };
    });
    try {
      final message = await widget.onRejectClientReplyDraft!.call(
        draft.updateId,
      );
      _showLiveOpsSnack(message.trim().isEmpty ? 'Draft rejected.' : message);
    } catch (_) {
      _showLiveOpsSnack('Failed to reject AI draft ${draft.updateId}.');
    } finally {
      if (mounted) {
        setState(() {
          _controlInboxBusyDraftIds = _controlInboxBusyDraftIds
              .where((entry) => entry != draft.updateId)
              .toSet();
        });
      }
    }
  }

  void _showLiveOpsSnack(
    String message, {
    String label = 'CONTROL INBOX',
    String? detail,
    Color accent = const Color(0xFF8FD1FF),
  }) {
    _showLiveOpsFeedback(
      message,
      label: label,
      detail:
          detail ??
          'The latest inbox action stays pinned in the context rail while the queue and selected incident remain visible.',
      accent: accent,
    );
  }

  void _openOverrideDialog(_IncidentRecord incident) {
    String? selectedReason;
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF13131E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0x66EF4444)),
              ),
              title: Text(
                'Override ${incident.id}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8F2D36),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a reason code (required):',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF556B80),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._overrideReasonCodes.map((code) {
                      final selected = selectedReason == code;
                      return InkWell(
                        key: Key('reason-$code'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setDialogState(() {
                            selectedReason = code;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 16,
                                color: selected
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF9AB2D2),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  code,
                                  style: GoogleFonts.robotoMono(
                                    color: const Color(0xFF172638),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('override-submit-button'),
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          _applyOverride(incident, selectedReason!);
                          Navigator.of(context).pop();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F1),
                    foregroundColor: const Color(0xFFB42318),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE8B6B6)),
                    ),
                  ),
                  child: const Text('Submit Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyOverride(_IncidentRecord incident, String reasonCode) {
    _statusOverrides[incident.id] = _IncidentStatus.resolved;
    _manualLedger.add(
      _LedgerEntry(
        id: 'OVR-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: _LedgerType.humanOverride,
        description: 'Override submitted for ${incident.id}',
        hash: _hashFor('override-$reasonCode-${incident.id}'),
        verified: true,
        reasonCode: reasonCode,
      ),
    );
    _projectFromEvents();
    logUiAction(
      'live_operations.manual_override',
      context: {'incident_id': incident.id, 'reason_code': reasonCode},
    );
  }

  void _forceDispatch(_IncidentRecord incident) {
    _statusOverrides[incident.id] = _IncidentStatus.dispatched;
    _manualLedger.add(
      _LedgerEntry(
        id: 'ESC-${DateTime.now().microsecondsSinceEpoch}',
        timestamp: DateTime.now(),
        type: _LedgerType.escalation,
        description: 'Forced dispatch activated for ${incident.id}',
        hash: _hashFor('forced-dispatch-${incident.id}'),
        verified: true,
      ),
    );
    _projectFromEvents();
    logUiAction(
      'live_operations.force_dispatch',
      context: {'incident_id': incident.id},
    );
  }

  void _pauseAutomation(_IncidentRecord incident) {
    setState(() {
      _manualLedger.add(
        _LedgerEntry(
          id: 'PAUSE-${DateTime.now().microsecondsSinceEpoch}',
          timestamp: DateTime.now(),
          type: _LedgerType.systemEvent,
          description: 'Automation paused for ${incident.id}',
          hash: _hashFor('pause-${incident.id}'),
          verified: true,
        ),
      );
    });
    logUiAction(
      'live_operations.pause_automation',
      context: {'incident_id': incident.id},
    );
    _showLiveOpsSnack(
      'Automation paused for ${incident.id}',
      label: 'AUTOMATION HOLD',
      detail:
          'The automation hold stays visible in the context rail while the operator reviews the incident ladder.',
      accent: const Color(0xFFFBBF24),
    );
  }

  _IncidentRecord? get _activeIncident {
    if (_incidents.isEmpty) return null;
    return _incidents.firstWhere(
      (incident) => incident.id == _activeIncidentId,
      orElse: () => _incidents.first,
    );
  }

  void _projectFromEvents() {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final hasScopeFocus = scopeClientId.isNotEmpty;
    final scopedEvents = hasScopeFocus
        ? widget.events
              .where((event) {
                final clientId = switch (event) {
                  DecisionCreated value => value.clientId.trim(),
                  ResponseArrived value => value.clientId.trim(),
                  PartnerDispatchStatusDeclared value => value.clientId.trim(),
                  GuardCheckedIn value => value.clientId.trim(),
                  ExecutionCompleted value => value.clientId.trim(),
                  IntelligenceReceived value => value.clientId.trim(),
                  PatrolCompleted value => value.clientId.trim(),
                  IncidentClosed value => value.clientId.trim(),
                  _ => '',
                };
                final siteId = switch (event) {
                  DecisionCreated value => value.siteId.trim(),
                  ResponseArrived value => value.siteId.trim(),
                  PartnerDispatchStatusDeclared value => value.siteId.trim(),
                  GuardCheckedIn value => value.siteId.trim(),
                  ExecutionCompleted value => value.siteId.trim(),
                  IntelligenceReceived value => value.siteId.trim(),
                  PatrolCompleted value => value.siteId.trim(),
                  IncidentClosed value => value.siteId.trim(),
                  _ => '',
                };
                if (clientId != scopeClientId) {
                  return false;
                }
                if (scopeSiteId.isEmpty) {
                  return true;
                }
                return siteId == scopeSiteId;
              })
              .toList(growable: false)
        : widget.events;
    final focusReference = _canonicalFocusReference(
      widget.focusIncidentReference,
      scopedEvents,
    );
    final normalizedInputFocus = widget.focusIncidentReference.trim();
    final liveProjectedIncidents = _deriveIncidents(
      scopedEvents,
      allowDemoFallback: !hasScopeFocus,
    );
    final focusMatchedInLiveStream =
        focusReference.isNotEmpty &&
        liveProjectedIncidents.any((incident) => incident.id == focusReference);
    final projectedIncidents = _injectFocusedIncidentFallback(
      incidents: liveProjectedIncidents,
      focusReference: focusReference,
      hasLiveMatch: focusMatchedInLiveStream,
    );
    final projectedLedger = _deriveLedger(scopedEvents);
    final projectedVigilance = _deriveVigilance(scopedEvents);
    setState(() {
      _incidents = projectedIncidents;
      _projectedLedger = projectedLedger;
      _vigilance = projectedVigilance;
      final persistedFocusedGuard =
          _focusedVigilanceCallsign != null &&
              projectedVigilance.any(
                (guard) => guard.callsign == _focusedVigilanceCallsign,
              )
          ? _focusedVigilanceCallsign
          : _guardAttentionLeadFrom(projectedVigilance)?.callsign;
      _focusedVigilanceCallsign = persistedFocusedGuard;
      _resolvedFocusReference = focusReference;
      _focusLinkState = switch ((
        focusReference.isNotEmpty,
        focusMatchedInLiveStream,
      )) {
        (false, _) => _FocusLinkState.none,
        (true, false) => _FocusLinkState.seeded,
        (true, true) when normalizedInputFocus == focusReference =>
          _FocusLinkState.exact,
        (true, true) => _FocusLinkState.scopeBacked,
      };
      if (_incidents.isEmpty) {
        _activeIncidentId = null;
      } else if (focusReference.isNotEmpty &&
          _incidents.any((incident) => incident.id == focusReference)) {
        _activeIncidentId = focusReference;
      } else if (!_incidents.any(
        (incident) => incident.id == _activeIncidentId,
      )) {
        _activeIncidentId = _incidents.first.id;
      }
    });
  }

  String _canonicalFocusReference(
    String rawFocusReference,
    List<DispatchEvent> events,
  ) {
    final normalizedReference = rawFocusReference.trim();
    if (normalizedReference.isEmpty) {
      return '';
    }

    DecisionCreated? decisionMatch;
    IntelligenceReceived? intelligenceMatch;
    for (final event in events) {
      final dispatchId = switch (event) {
        DecisionCreated value => value.dispatchId.trim(),
        ResponseArrived value => value.dispatchId.trim(),
        PartnerDispatchStatusDeclared value => value.dispatchId.trim(),
        ExecutionCompleted value => value.dispatchId.trim(),
        ExecutionDenied value => value.dispatchId.trim(),
        IncidentClosed value => value.dispatchId.trim(),
        _ => '',
      };
      final eventMatches = event.eventId.trim() == normalizedReference;
      final dispatchMatches =
          dispatchId.isNotEmpty &&
          (dispatchId == normalizedReference ||
              _incidentIdForDispatch(dispatchId) == normalizedReference);
      if (eventMatches || dispatchMatches) {
        final decision = events
            .whereType<DecisionCreated>()
            .where((candidate) => candidate.dispatchId.trim() == dispatchId)
            .fold<DecisionCreated?>(
              null,
              (latest, candidate) =>
                  latest == null ||
                      candidate.occurredAt.isAfter(latest.occurredAt)
                  ? candidate
                  : latest,
            );
        if (decision != null &&
            (decisionMatch == null ||
                decision.occurredAt.isAfter(decisionMatch.occurredAt))) {
          decisionMatch = decision;
        }
      }
      if (event is IntelligenceReceived &&
          (event.eventId.trim() == normalizedReference ||
              event.intelligenceId.trim() == normalizedReference) &&
          (intelligenceMatch == null ||
              event.occurredAt.isAfter(intelligenceMatch.occurredAt))) {
        intelligenceMatch = event;
      }
    }

    if (decisionMatch != null) {
      return _incidentIdForDispatch(decisionMatch.dispatchId.trim());
    }

    if (intelligenceMatch != null) {
      final decision = events
          .whereType<DecisionCreated>()
          .where(
            (candidate) =>
                candidate.clientId.trim() ==
                    intelligenceMatch!.clientId.trim() &&
                candidate.siteId.trim() == intelligenceMatch.siteId.trim(),
          )
          .fold<DecisionCreated?>(
            null,
            (latest, candidate) =>
                latest == null ||
                    candidate.occurredAt.isAfter(latest.occurredAt)
                ? candidate
                : latest,
          );
      if (decision != null) {
        return _incidentIdForDispatch(decision.dispatchId.trim());
      }
    }

    return normalizedReference;
  }

  String _focusStateLabel(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => 'Idle',
      _FocusLinkState.exact => 'Linked',
      _FocusLinkState.scopeBacked => 'Scope-backed',
      _FocusLinkState.seeded => 'Seeded',
    };
  }

  Color _focusStateForeground(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0xFF9AB1CF),
      _FocusLinkState.exact => const Color(0xFF34D399),
      _FocusLinkState.scopeBacked => const Color(0xFF8FD1FF),
      _FocusLinkState.seeded => const Color(0xFFF59E0B),
    };
  }

  Color _focusStateBackground(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0x1A9AB1CF),
      _FocusLinkState.exact => const Color(0x3334D399),
      _FocusLinkState.scopeBacked => const Color(0x338FD1FF),
      _FocusLinkState.seeded => const Color(0x33F59E0B),
    };
  }

  Color _focusStateBorder(_FocusLinkState state) {
    return switch (state) {
      _FocusLinkState.none => const Color(0x669AB1CF),
      _FocusLinkState.exact => const Color(0x6634D399),
      _FocusLinkState.scopeBacked => const Color(0x668FD1FF),
      _FocusLinkState.seeded => const Color(0x66F59E0B),
    };
  }

  String _incidentIdForDispatch(String dispatchId) {
    final normalizedDispatchId = dispatchId.trim();
    if (normalizedDispatchId.isEmpty) {
      return '';
    }
    return normalizedDispatchId.startsWith('INC-')
        ? normalizedDispatchId
        : 'INC-$normalizedDispatchId';
  }

  List<_IncidentRecord> _injectFocusedIncidentFallback({
    required List<_IncidentRecord> incidents,
    required String focusReference,
    required bool hasLiveMatch,
  }) {
    if (focusReference.isEmpty || hasLiveMatch) {
      return incidents;
    }
    return [
      _IncidentRecord(
        id: focusReference,
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Focused lane playback',
        site: 'Focused War Room',
        timestamp: _hhmm(DateTime.now().toLocal()),
        status: _statusOverrides[focusReference] ?? _IncidentStatus.dispatched,
      ),
      ...incidents,
    ];
  }

  List<_IncidentRecord> _deriveIncidents(
    List<DispatchEvent> events, {
    required bool allowDemoFallback,
  }) {
    final decisions = events.whereType<DecisionCreated>().toList(
      growable: false,
    )..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (decisions.isEmpty) {
      if (!allowDemoFallback) {
        return const <_IncidentRecord>[];
      }
      final fallbackIncidents = _fallbackIncidents();
      return fallbackIncidents
          .map(
            (incident) => incident.copyWith(
              status: _statusOverrides[incident.id] ?? incident.status,
            ),
          )
          .toList(growable: false);
    }
    final closedIds = {
      ...events.whereType<IncidentClosed>().map((event) => event.dispatchId),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where(
            (event) =>
                event.status == PartnerDispatchStatus.allClear ||
                event.status == PartnerDispatchStatus.cancelled,
          )
          .map((event) => event.dispatchId),
    };
    final arrivedIds = {
      ...events.whereType<ResponseArrived>().map((event) => event.dispatchId),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where((event) => event.status == PartnerDispatchStatus.onSite)
          .map((event) => event.dispatchId),
    };
    final executedIds = {
      ...events.whereType<ExecutionCompleted>().map(
        (event) => event.dispatchId,
      ),
      ...events
          .whereType<PartnerDispatchStatusDeclared>()
          .where((event) => event.status == PartnerDispatchStatus.accepted)
          .map((event) => event.dispatchId),
    };
    final riskBySite = <String, int>{};
    final latestHardwareIntelBySite = <String, IntelligenceReceived>{};
    for (final intel in events.whereType<IntelligenceReceived>()) {
      final existing = riskBySite[intel.siteId] ?? 0;
      if (intel.riskScore > existing) {
        riskBySite[intel.siteId] = intel.riskScore;
      }
      if (intel.sourceType != 'hardware' && intel.sourceType != 'dvr') {
        continue;
      }
      final current = latestHardwareIntelBySite[intel.siteId];
      if (current == null || intel.occurredAt.isAfter(current.occurredAt)) {
        latestHardwareIntelBySite[intel.siteId] = intel;
      }
    }
    final incidents =
        decisions
            .take(12)
            .map((decision) {
              final baseStatus = closedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.resolved
                  : arrivedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.investigating
                  : executedIds.contains(decision.dispatchId)
                  ? _IncidentStatus.dispatched
                  : _IncidentStatus.triaging;
              final normalizedId = decision.dispatchId.startsWith('INC-')
                  ? decision.dispatchId
                  : 'INC-${decision.dispatchId}';
              final risk = riskBySite[decision.siteId] ?? 55;
              final latestIntel = latestHardwareIntelBySite[decision.siteId];
              final latestSceneReview = latestIntel == null
                  ? null
                  : widget.sceneReviewByIntelligenceId[latestIntel
                        .intelligenceId
                        .trim()];
              final priority = _incidentPriorityFor(
                risk,
                latestSceneReview: latestSceneReview,
              );
              final status = _statusOverrides[normalizedId] ?? baseStatus;
              return _IncidentRecord(
                id: normalizedId,
                clientId: decision.clientId,
                regionId: decision.regionId,
                siteId: decision.siteId,
                priority: priority,
                type: _incidentTypeFor(
                  risk,
                  latestSceneReview: latestSceneReview,
                ),
                site: decision.siteId,
                timestamp: _hhmm(decision.occurredAt.toLocal()),
                status: status,
                latestIntelHeadline: latestIntel?.headline,
                latestIntelSummary: latestIntel?.summary,
                latestSceneReviewLabel: latestSceneReview == null
                    ? null
                    : '${latestSceneReview.sourceLabel} • ${latestSceneReview.postureLabel}',
                latestSceneReviewSummary: latestSceneReview?.summary,
                latestSceneDecisionLabel: latestSceneReview?.decisionLabel,
                latestSceneDecisionSummary: latestSceneReview?.decisionSummary,
                snapshotUrl: latestIntel?.snapshotUrl,
                clipUrl: latestIntel?.clipUrl,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final byPriority = _priorityRank(
              a.priority,
            ).compareTo(_priorityRank(b.priority));
            if (byPriority != 0) return byPriority;
            return b.timestamp.compareTo(a.timestamp);
          });
    return incidents;
  }

  List<_IncidentRecord> _fallbackIncidents() {
    return const [
      _IncidentRecord(
        id: 'INC-8829-QX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Perimeter breach',
        site: 'North Residential Cluster',
        timestamp: '22:14',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8830-RZ',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p1Critical,
        type: 'Priority response',
        site: 'Central Access Gate',
        timestamp: '22:08',
        status: _IncidentStatus.dispatched,
      ),
      _IncidentRecord(
        id: 'INC-8827-PX',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Perimeter alarm',
        site: 'East Patrol Sector',
        timestamp: '21:56',
        status: _IncidentStatus.triaging,
      ),
      _IncidentRecord(
        id: 'INC-8828-MN',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p2High,
        type: 'Access control failure',
        site: 'Midrand Operations Park',
        timestamp: '21:45',
        status: _IncidentStatus.investigating,
      ),
      _IncidentRecord(
        id: 'INC-8826-KL',
        clientId: '',
        regionId: '',
        siteId: '',
        priority: _IncidentPriority.p3Medium,
        type: 'Power instability',
        site: 'Centurion Retail Annex',
        timestamp: '21:42',
        status: _IncidentStatus.resolved,
      ),
    ];
  }

  Widget _scopeFocusBanner({
    required String clientId,
    required String siteId,
    bool compact = false,
  }) {
    final scopeLabel = siteId.trim().isEmpty
        ? '$clientId/all sites'
        : '$clientId/$siteId';
    return Container(
      key: const ValueKey('live-operations-scope-banner'),
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 2.1, vertical: 0.88)
          : const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(compact ? 999 : 9),
        border: Border.all(color: const Color(0xFFD4DFEA)),
      ),
      child: compact
          ? Wrap(
              spacing: 0.6,
              runSpacing: 0.18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Scope focus active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 6.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  scopeLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF172638),
                    fontSize: 6.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scope focus active',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8FD1FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scopeLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF172638),
                    fontSize: 8.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  List<_LadderStep> _ladderStepsFor(_IncidentRecord? incident) {
    if (incident == null) return const [];
    final duress = _duressDetected(incident);
    final videoActivationStep = '${widget.videoOpsLabel} ACTIVATION';
    final dispatchStep = _dispatchStepLabel(incident);
    final clientCallStep = _clientCallStepLabel(incident);
    final verifyStep = _verifyStepLabel(incident);
    final dispatchActiveDetails = _dispatchActiveDetails(incident);
    final dispatchActiveMetadata = _dispatchActiveMetadata(incident);
    final clientCallActiveDetails = _clientCallActiveDetails(incident);
    final videoActiveDetails = _videoActiveDetails(incident);
    final videoActiveMetadata = _videoActiveMetadata(incident);
    final verifyThinkingMessage = _verifyThinkingMessage(incident);
    if (incident.status == _IncidentStatus.resolved) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.completed,
        ),
      ];
    }
    if (incident.status == _IncidentStatus.investigating) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.completed,
          details: clientCallActiveDetails,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.active,
          details: videoActiveDetails,
          timestamp: '22:14:18',
          metadata: videoActiveMetadata,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.thinking,
          thinkingMessage: verifyThinkingMessage,
        ),
      ];
    }
    if (incident.status == _IncidentStatus.dispatched) {
      return [
        _LadderStep(
          id: 's1',
          name: 'SIGNAL TRIAGE',
          status: _LadderStepStatus.completed,
        ),
        _LadderStep(
          id: 's2',
          name: dispatchStep,
          status: _LadderStepStatus.completed,
          details: dispatchActiveDetails,
          timestamp: '22:14:06',
          metadata: dispatchActiveMetadata,
        ),
        _LadderStep(
          id: 's3',
          name: clientCallStep,
          status: _LadderStepStatus.active,
          details: clientCallActiveDetails,
        ),
        _LadderStep(
          id: 's4',
          name: videoActivationStep,
          status: _LadderStepStatus.pending,
        ),
        _LadderStep(
          id: 's5',
          name: verifyStep,
          status: _LadderStepStatus.pending,
        ),
      ];
    }
    return [
      const _LadderStep(
        id: 's1',
        name: 'SIGNAL TRIAGE',
        status: _LadderStepStatus.completed,
      ),
      _LadderStep(
        id: 's2',
        name: dispatchStep,
        status: _LadderStepStatus.active,
        details: dispatchActiveDetails,
        timestamp: '22:14:06',
        metadata: dispatchActiveMetadata,
      ),
      _LadderStep(
        id: 's3',
        name: clientCallStep,
        status: duress ? _LadderStepStatus.blocked : _LadderStepStatus.thinking,
        thinkingMessage: duress
            ? 'Silent duress suspected • waiting for forced dispatch.'
            : _clientCallThinkingMessage(incident),
      ),
      _LadderStep(
        id: 's4',
        name: videoActivationStep,
        status: _LadderStepStatus.pending,
      ),
      _LadderStep(
        id: 's5',
        name: verifyStep,
        status: _LadderStepStatus.pending,
      ),
    ];
  }

  String _dispatchStepLabel(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'FIRE RESPONSE';
    }
    if (_isLeakIncident(incident)) {
      return 'LEAK CONTAINMENT';
    }
    if (_isHazardIncident(incident)) {
      return 'HAZARD RESPONSE';
    }
    return 'AUTO-DISPATCH';
  }

  String _clientCallStepLabel(_IncidentRecord incident) {
    if (_isHazardIncident(incident)) {
      return 'CLIENT SAFETY CALL';
    }
    return 'VOIP CLIENT CALL';
  }

  String _verifyStepLabel(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'FIRE VERIFY';
    }
    if (_isLeakIncident(incident)) {
      return 'LEAK VERIFY';
    }
    if (_isHazardIncident(incident)) {
      return 'HAZARD VERIFY';
    }
    return 'VISION VERIFY';
  }

  String _dispatchActiveDetails(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorDispatchActiveDetails;
    }
    return 'Officer Echo-3 • 2.4km • ETA 4m 12s';
  }

  String _dispatchActiveMetadata(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorDispatchActiveMetadata;
    }
    return 'Nearest armed response selected';
  }

  String _clientCallActiveDetails(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorClientCallActiveDetails;
    }
    return 'Safe-word verification call in progress.';
  }

  String _clientCallThinkingMessage(_IncidentRecord incident) {
    final directives = _hazardDirectivesForIncident(incident);
    if (directives.hasHazard) {
      return directives.operatorClientCallThinkingMessage;
    }
    return 'Waiting for VoIP completion...';
  }

  HazardResponseDirectives _hazardDirectivesForIncident(
    _IncidentRecord incident,
  ) {
    return _hazardDirectiveService.build(
      postureLabel: incident.latestSceneReviewLabel ?? incident.type,
      siteName: incident.site,
    );
  }

  String _videoActiveDetails(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Live thermal and smoke evidence stream active.';
    }
    if (_isLeakIncident(incident)) {
      return 'Live pooling and spread evidence stream active.';
    }
    if (_isHazardIncident(incident)) {
      return 'Live hazard verification stream active.';
    }
    return 'Live perimeter stream active.';
  }

  String _videoActiveMetadata(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Generator room cluster · confidence 98%';
    }
    if (_isLeakIncident(incident)) {
      return 'Stock room cluster · confidence 96%';
    }
    if (_isHazardIncident(incident)) {
      return 'Safety zone cluster · confidence 94%';
    }
    return 'Camera cluster N4 · confidence 98%';
  }

  String _verifyThinkingMessage(_IncidentRecord incident) {
    if (_isFireIncident(incident)) {
      return 'Checking for flame growth, smoke density, and spread pattern...';
    }
    if (_isLeakIncident(incident)) {
      return 'Checking for pooling spread, pipe-burst pattern, and ongoing water loss...';
    }
    if (_isHazardIncident(incident)) {
      return 'Checking for worsening hazard indicators against baseline...';
    }
    return 'Comparing live capture against norm baseline...';
  }

  bool _isFireIncident(_IncidentRecord incident) {
    final text = _incidentHazardText(incident);
    return text.contains('fire') || text.contains('smoke');
  }

  bool _isLeakIncident(_IncidentRecord incident) {
    final text = _incidentHazardText(incident);
    return text.contains('flood') || text.contains('leak');
  }

  bool _isHazardIncident(_IncidentRecord incident) {
    if (_isFireIncident(incident) || _isLeakIncident(incident)) {
      return true;
    }
    return _incidentHazardText(incident).contains('hazard');
  }

  String _incidentHazardText(_IncidentRecord incident) {
    return [
      incident.type,
      incident.latestSceneReviewLabel,
      incident.latestSceneReviewSummary,
      incident.latestSceneDecisionLabel,
      incident.latestSceneDecisionSummary,
      incident.latestIntelHeadline,
      incident.latestIntelSummary,
    ].join(' ').toLowerCase();
  }

  List<_LedgerEntry> _deriveLedger(List<DispatchEvent> events) {
    final entries = <_LedgerEntry>[];
    for (final event in events.take(40)) {
      final entry = switch (event) {
        DecisionCreated() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.aiAction,
          description: 'Dispatch decision created for ${event.dispatchId}',
          actor: 'ONYX AI',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ExecutionCompleted() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Execution completed for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ExecutionDenied() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.humanOverride,
          description: 'Execution denied for ${event.dispatchId}',
          actor: 'Admin-1',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        ResponseArrived() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Response arrived for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        PartnerDispatchStatusDeclared() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description:
              '${event.partnerLabel} declared ${event.status.name} for ${event.dispatchId}',
          actor: event.actorLabel,
          hash: _hashFor(event.eventId),
          verified: false,
        ),
        IncidentClosed() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'Incident closed for ${event.dispatchId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        IntelligenceReceived() => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.escalation,
          description: 'Intelligence received at ${event.siteId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
        _ => _LedgerEntry(
          id: event.eventId,
          timestamp: event.occurredAt,
          type: _LedgerType.systemEvent,
          description: 'System event ${event.eventId}',
          hash: _hashFor(event.eventId),
          verified: true,
        ),
      };
      entries.add(entry);
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (entries.isEmpty) {
      return [
        _LedgerEntry(
          id: 'L001',
          timestamp: DateTime(2026, 3, 10, 22, 14, 27),
          type: _LedgerType.aiAction,
          description: 'VoIP call transcript analyzed - safe word verified',
          actor: 'ONYX AI',
          hash: 'a7f3e9c2',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L002',
          timestamp: DateTime(2026, 3, 10, 22, 14, 12),
          type: _LedgerType.aiAction,
          description: 'VoIP call initiated to sovereign contact',
          actor: 'ONYX AI',
          hash: 'b8e41d3f',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L003',
          timestamp: DateTime(2026, 3, 10, 22, 14, 6),
          type: _LedgerType.aiAction,
          description: 'Auto-dispatch created for Echo-3',
          actor: 'ONYX AI',
          hash: 'c9f52e4g',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L004',
          timestamp: DateTime(2026, 3, 10, 22, 14, 3),
          type: _LedgerType.systemEvent,
          description: 'Perimeter breach signal received from Site-Sandton-04',
          hash: 'd1a63f5h',
          verified: true,
        ),
        _LedgerEntry(
          id: 'L005',
          timestamp: DateTime(2026, 3, 10, 22, 8, 45),
          type: _LedgerType.humanOverride,
          description: 'INC-8830 dispatch cancelled by Controller-1',
          actor: 'Admin-1',
          reasonCode: 'FALSE_ALARM',
          hash: 'e2b74g6i',
          verified: true,
        ),
      ];
    }
    return entries;
  }

  List<_GuardVigilance> _deriveVigilance(List<DispatchEvent> events) {
    final checkIns = events.whereType<GuardCheckedIn>().toList(growable: false)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (checkIns.isEmpty) {
      return const [
        _GuardVigilance(
          callsign: 'Echo-3',
          decayLevel: 67,
          lastCheckIn: '22:12',
          sparkline: [58, 61, 63, 64, 66, 67, 67, 67],
        ),
        _GuardVigilance(
          callsign: 'Bravo-2',
          decayLevel: 42,
          lastCheckIn: '22:10',
          sparkline: [35, 38, 40, 41, 42, 42, 42, 42],
        ),
        _GuardVigilance(
          callsign: 'Delta-1',
          decayLevel: 89,
          lastCheckIn: '22:02',
          sparkline: [74, 78, 82, 85, 87, 88, 89, 89],
        ),
        _GuardVigilance(
          callsign: 'Alpha-5',
          decayLevel: 98,
          lastCheckIn: '21:45',
          sparkline: [84, 87, 90, 93, 95, 97, 98, 98],
        ),
      ];
    }
    final now = DateTime.now().toUtc();
    final grouped = <String, List<GuardCheckedIn>>{};
    for (final checkIn in checkIns) {
      grouped
          .putIfAbsent(checkIn.guardId, () => <GuardCheckedIn>[])
          .add(checkIn);
    }
    return grouped.entries
        .take(6)
        .map((entry) {
          final latest = entry.value.first.occurredAt;
          final elapsedMinutes = now.difference(latest).inMinutes;
          final decay = ((elapsedMinutes / 20) * 100).round().clamp(0, 100);
          final sparkline = List<int>.generate(8, (index) {
            final value = decay - ((7 - index) * 3);
            return value.clamp(12, 100);
          });
          return _GuardVigilance(
            callsign: entry.key,
            decayLevel: decay,
            lastCheckIn: '${elapsedMinutes}m ago',
            sparkline: sparkline,
          );
        })
        .toList(growable: false);
  }

  bool _duressDetected(_IncidentRecord incident) {
    return incident.priority == _IncidentPriority.p1Critical &&
        incident.status == _IncidentStatus.triaging;
  }

  Color _statusChipColor(_IncidentStatus status) {
    return switch (status) {
      _IncidentStatus.triaging => OnyxDesignTokens.cyanInteractive,
      _IncidentStatus.dispatched => OnyxDesignTokens.amberWarning,
      _IncidentStatus.investigating => OnyxDesignTokens.purpleAdmin,
      _IncidentStatus.resolved => OnyxDesignTokens.greenNominal,
    };
  }

  _PriorityStyle _priorityStyle(_IncidentPriority priority) {
    return switch (priority) {
      _IncidentPriority.p1Critical => _PriorityStyle(
        label: 'P1',
        foreground: OnyxDesignTokens.redCritical,
        background: OnyxDesignTokens.redCritical.withValues(alpha: 0.2),
        border: OnyxDesignTokens.redCritical.withValues(alpha: 0.4),
        icon: Icons.local_fire_department_rounded,
      ),
      _IncidentPriority.p2High => _PriorityStyle(
        label: 'P2',
        foreground: OnyxDesignTokens.amberWarning,
        background: OnyxDesignTokens.amberWarning.withValues(alpha: 0.2),
        border: OnyxDesignTokens.amberWarning.withValues(alpha: 0.4),
        icon: Icons.track_changes_rounded,
      ),
      _IncidentPriority.p3Medium => _PriorityStyle(
        label: 'P3',
        foreground: OnyxDesignTokens.cyanInteractive,
        background: OnyxDesignTokens.cyanInteractive.withValues(alpha: 0.2),
        border: OnyxDesignTokens.cyanInteractive.withValues(alpha: 0.4),
        icon: Icons.schedule_rounded,
      ),
      _IncidentPriority.p4Low => _PriorityStyle(
        label: 'P4',
        foreground: OnyxDesignTokens.greenNominal,
        background: OnyxDesignTokens.greenNominal.withValues(alpha: 0.2),
        border: OnyxDesignTokens.greenNominal.withValues(alpha: 0.4),
        icon: Icons.shield_outlined,
      ),
    };
  }

  _LedgerStyle _ledgerStyle(_LedgerType type) {
    return switch (type) {
      _LedgerType.aiAction => const _LedgerStyle(
        icon: Icons.psychology_alt_rounded,
        color: OnyxDesignTokens.cyanInteractive,
      ),
      _LedgerType.humanOverride => const _LedgerStyle(
        icon: Icons.person_rounded,
        color: OnyxDesignTokens.greenNominal,
      ),
      _LedgerType.systemEvent => const _LedgerStyle(
        icon: Icons.settings_rounded,
        color: OnyxDesignTokens.purpleAdmin,
      ),
      _LedgerType.escalation => const _LedgerStyle(
        icon: Icons.priority_high_rounded,
        color: OnyxDesignTokens.redCritical,
      ),
    };
  }

  String _ledgerTypeLabel(_LedgerType type) {
    return switch (type) {
      _LedgerType.aiAction => 'AI ACTION',
      _LedgerType.humanOverride => 'HUMAN OVERRIDE',
      _LedgerType.systemEvent => 'SYSTEM EVENT',
      _LedgerType.escalation => 'ESCALATION',
    };
  }

  Color _stepColor(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => const Color(0xFF10B981),
      _LadderStepStatus.active => const Color(0xFF22D3EE),
      _LadderStepStatus.thinking => const Color(0xFF22D3EE),
      _LadderStepStatus.pending => const Color(0xFF6F84A3),
      _LadderStepStatus.blocked => const Color(0xFFEF4444),
    };
  }

  IconData _stepIcon(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => Icons.check_circle_rounded,
      _LadderStepStatus.active => Icons.autorenew_rounded,
      _LadderStepStatus.thinking => Icons.hourglass_top_rounded,
      _LadderStepStatus.pending => Icons.radio_button_unchecked_rounded,
      _LadderStepStatus.blocked => Icons.cancel_rounded,
    };
  }

  String _stepLabel(_LadderStepStatus status) {
    return switch (status) {
      _LadderStepStatus.completed => 'COMPLETED',
      _LadderStepStatus.active => 'ACTIVE',
      _LadderStepStatus.thinking => 'THINKING',
      _LadderStepStatus.pending => 'PENDING',
      _LadderStepStatus.blocked => 'BLOCKED',
    };
  }

  String _tabLabel(_ContextTab tab) {
    return switch (tab) {
      _ContextTab.details => 'DETAILS',
      _ContextTab.voip => 'VOIP',
      _ContextTab.visual => 'VISUAL',
    };
  }

  String _statusLabel(_IncidentStatus status) {
    return switch (status) {
      _IncidentStatus.triaging => 'TRIAGING',
      _IncidentStatus.dispatched => 'DISPATCHED',
      _IncidentStatus.investigating => 'INVESTIGATING',
      _IncidentStatus.resolved => 'RESOLVED',
    };
  }

  String _partnerDispatchStatusLabel(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.unknown => 'UNKNOWN',
      PartnerDispatchStatus.accepted => 'ACCEPT',
      PartnerDispatchStatus.onSite => 'ON SITE',
      PartnerDispatchStatus.allClear => 'ALL CLEAR',
      PartnerDispatchStatus.cancelled => 'CANCEL',
    };
  }

  (Color, Color, Color) _partnerProgressTone(PartnerDispatchStatus status) {
    return switch (status) {
      PartnerDispatchStatus.unknown => (
        const Color(0xFF94A3B8),
        const Color(0x1494A3B8),
        const Color(0x6694A3B8),
      ),
      PartnerDispatchStatus.accepted => (
        const Color(0xFF38BDF8),
        const Color(0x1A38BDF8),
        const Color(0x6638BDF8),
      ),
      PartnerDispatchStatus.onSite => (
        const Color(0xFFF59E0B),
        const Color(0x1AF59E0B),
        const Color(0x66F59E0B),
      ),
      PartnerDispatchStatus.allClear => (
        const Color(0xFF34D399),
        const Color(0x1A34D399),
        const Color(0x6634D399),
      ),
      PartnerDispatchStatus.cancelled => (
        const Color(0xFFF87171),
        const Color(0x1AF87171),
        const Color(0x66F87171),
      ),
    };
  }

  Color _partnerTrendColor(String trendLabel) {
    return switch (trendLabel.trim().toUpperCase()) {
      'IMPROVING' => const Color(0xFF34D399),
      'STABLE' => const Color(0xFF38BDF8),
      'SLIPPING' => const Color(0xFFF87171),
      'NEW' => const Color(0xFF60A5FA),
      _ => const Color(0xFF9CB4D0),
    };
  }

  Color _clientCommsAccent(LiveClientCommsSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return const Color(0xFF60A5FA);
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    final push = snapshot.pushSyncStatusLabel.trim().toLowerCase();
    if (bridge == 'blocked' || push == 'failed') {
      return const Color(0xFFEF4444);
    }
    if (bridge == 'degraded' || snapshot.telegramFallbackActive) {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFF22D3EE);
  }

  Color _controlInboxAccent(LiveControlInboxSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return const Color(0xFF60A5FA);
    }
    if (snapshot.awaitingResponseCount > 0) {
      return const Color(0xFF22D3EE);
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    if (bridge == 'blocked') {
      return const Color(0xFFEF4444);
    }
    if (snapshot.telegramFallbackActive || bridge == 'degraded') {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFF22D3EE);
  }

  String _clientLaneTopBarLabel(LiveClientCommsSnapshot? snapshot) {
    if (snapshot == null) {
      return 'Client Comms idle';
    }
    if (snapshot.pendingApprovalCount > 0) {
      return '${snapshot.pendingApprovalCount} Client Reply${snapshot.pendingApprovalCount == 1 ? '' : 's'} Awaiting';
    }
    if (snapshot.smsFallbackEligibleNow) {
      return 'Client Comms SMS fallback ready';
    }
    if (snapshot.telegramFallbackActive) {
      return 'Client Comms on fallback';
    }
    if (snapshot.clientInboundCount > 0) {
      return '${snapshot.clientInboundCount} Client Msg${snapshot.clientInboundCount == 1 ? '' : 's'} Live';
    }
    return 'Client Comms stable';
  }

  Color _clientLaneTopBarForeground(LiveClientCommsSnapshot? snapshot) {
    if (snapshot == null) {
      return const Color(0xFF8FA7C8);
    }
    return _clientCommsAccent(snapshot);
  }

  Color _clientLaneTopBarBackground(LiveClientCommsSnapshot? snapshot) {
    final foreground = _clientLaneTopBarForeground(snapshot);
    return foreground.withValues(alpha: 0.18);
  }

  Color _clientLaneTopBarBorder(LiveClientCommsSnapshot? snapshot) {
    final foreground = _clientLaneTopBarForeground(snapshot);
    return foreground.withValues(alpha: 0.42);
  }

  Color _telegramHealthAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'ok' => const Color(0xFF34D399),
      'blocked' => const Color(0xFFEF4444),
      'degraded' => const Color(0xFF60A5FA),
      'disabled' => const Color(0xFF8EA4C2),
      _ => const Color(0xFF38BDF8),
    };
  }

  Color _pushSyncAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'ok' => const Color(0xFF34D399),
      'failed' => const Color(0xFFEF4444),
      'syncing' => const Color(0xFF38BDF8),
      _ => const Color(0xFF8EA4C2),
    };
  }

  Color _smsFallbackAccent(
    String label, {
    required bool ready,
    required bool eligibleNow,
  }) {
    if (eligibleNow) {
      return const Color(0xFF60A5FA);
    }
    if (ready) {
      return const Color(0xFF34D399);
    }
    final normalized = label.trim().toLowerCase();
    if (normalized.contains('pending')) {
      return const Color(0xFF38BDF8);
    }
    return const Color(0xFF8EA4C2);
  }

  Color _voiceReadinessAccent(String label) {
    return switch (label.trim().toLowerCase()) {
      'voip ready' => const Color(0xFF34D399),
      'voip contact pending' => const Color(0xFF60A5FA),
      'voip staged' => const Color(0xFF38BDF8),
      _ => const Color(0xFF8EA4C2),
    };
  }

  String _clientCommsNarrative(LiveClientCommsSnapshot snapshot) {
    if (snapshot.pendingApprovalCount > 0) {
      return 'client reply waiting on human approval';
    }
    final bridge = snapshot.telegramHealthLabel.trim().toLowerCase();
    final push = snapshot.pushSyncStatusLabel.trim().toLowerCase();
    if (bridge == 'blocked' || bridge == 'degraded') {
      return 'Client Comms delivery posture needs operator attention.';
    }
    if (push == 'failed') {
      return 'push sync is failing and needs recovery';
    }
    if (snapshot.smsFallbackEligibleNow) {
      return 'telegram needs help and sms fallback is standing by';
    }
    if ((snapshot.latestClientMessage ?? '').trim().isNotEmpty) {
      return 'Client Comms is active and being tracked';
    }
    return 'Client Comms is quiet for now';
  }

  String _clientCommsOpsFootnote(LiveClientCommsSnapshot snapshot) {
    final notes = <String>[
      if (snapshot.telegramFallbackActive) 'Telegram fallback is active',
      if (snapshot.queuedPushCount > 0)
        '${snapshot.queuedPushCount} push item${snapshot.queuedPushCount == 1 ? '' : 's'} queued',
      if ((snapshot.telegramHealthDetail ?? '').trim().isNotEmpty)
        ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(
          snapshot.telegramHealthDetail!.trim(),
        ),
      if ((snapshot.deliveryReadinessDetail ?? '').trim().isNotEmpty)
        snapshot.deliveryReadinessDetail!.trim(),
      if ((snapshot.pushSyncFailureReason ?? '').trim().isNotEmpty)
        'Push detail: ${ClientDeliveryMessageFormatter.humanizeScopedCommsSummary(snapshot.pushSyncFailureReason!.trim())}',
    ];
    return notes.join(' • ');
  }

  String _commsMomentLabel(DateTime? atUtc) {
    if (atUtc == null) {
      return '';
    }
    final local = atUtc.toLocal();
    final now = DateTime.now();
    final age = now.difference(local);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (age.inMinutes < 1) {
      return 'just now • $hh:$mm';
    }
    if (age.inMinutes < 60) {
      return '${age.inMinutes}m ago • $hh:$mm';
    }
    if (age.inHours < 24) {
      return '${age.inHours}h ago • $hh:$mm';
    }
    return '${age.inDays}d ago • $hh:$mm';
  }

  String _humanizeClientLaneRelayIssue(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('Relay stream HTTP ')) {
      final code = trimmed.substring('Relay stream HTTP '.length).trim();
      return 'The MJPEG relay endpoint returned HTTP $code on the latest check.';
    }
    if (trimmed.startsWith('Relay player HTTP ')) {
      final code = trimmed.substring('Relay player HTTP '.length).trim();
      return 'The browser player endpoint returned HTTP $code on the latest check.';
    }
    final normalized = trimmed.toLowerCase();
    if (normalized.contains('connection refused')) {
      return 'The local relay was not accepting connections on the latest check.';
    }
    if (normalized.contains('timed out')) {
      return 'The local relay check timed out before the player was confirmed.';
    }
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  String _clientLaneRelayStatusLabel(ClientCameraRelayStatus? status) {
    return switch (status ?? ClientCameraRelayStatus.unknown) {
      ClientCameraRelayStatus.active => 'active',
      ClientCameraRelayStatus.ready => 'ready',
      ClientCameraRelayStatus.starting => 'starting',
      ClientCameraRelayStatus.stale => 'stale',
      ClientCameraRelayStatus.error => 'error',
      ClientCameraRelayStatus.idle => 'idle',
      ClientCameraRelayStatus.unknown => 'ready',
    };
  }

  String _clientLaneContinuousVisualWatchLabel(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'alerting' => 'alerting',
      'active' => 'active',
      'learning' => 'learning',
      'degraded' => 'degraded',
      'inactive' => 'inactive',
      _ => 'active',
    };
  }

  Color _clientLaneContinuousVisualWatchAccent(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'alerting' => const Color(0xFFEF4444),
      'active' => const Color(0xFF34D399),
      'learning' => const Color(0xFF67E8F9),
      'degraded' => const Color(0xFFF59E0B),
      'inactive' => const Color(0xFF94A3B8),
      _ => const Color(0xFF34D399),
    };
  }

  String _clientLaneContinuousVisualStageLabel(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'watching' => 'watching',
      'sustained' => 'sustained',
      'persistent' => 'persistent',
      'idle' => 'idle',
      _ => 'watching',
    };
  }

  Color _clientLaneContinuousVisualStageAccent(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'watching' => const Color(0xFFF59E0B),
      'sustained' => const Color(0xFFFF8A65),
      'persistent' => const Color(0xFFEF4444),
      'idle' => const Color(0xFF94A3B8),
      _ => const Color(0xFFF59E0B),
    };
  }

  Color _clientLaneContinuousVisualPriorityAccent(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'high' => const Color(0xFFEF4444),
      'medium' => const Color(0xFFF59E0B),
      'low' => const Color(0xFF94A3B8),
      _ => const Color(0xFF8FD1FF),
    };
  }

  Color _clientLaneContinuousVisualAttentionAccent(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'urgent' => const Color(0xFFB91C1C),
      'high' => const Color(0xFFEF4444),
      'elevated' => const Color(0xFFF59E0B),
      'watch' => const Color(0xFF67E8F9),
      _ => const Color(0xFF8FD1FF),
    };
  }

  Color _clientLaneRelayStatusAccent(ClientCameraRelayStatus? status) {
    return switch (status ?? ClientCameraRelayStatus.unknown) {
      ClientCameraRelayStatus.active => const Color(0xFF10B981),
      ClientCameraRelayStatus.ready => const Color(0xFF34D399),
      ClientCameraRelayStatus.starting => const Color(0xFF67E8F9),
      ClientCameraRelayStatus.stale => const Color(0xFFF59E0B),
      ClientCameraRelayStatus.error => const Color(0xFFEF4444),
      ClientCameraRelayStatus.idle => const Color(0xFF94A3B8),
      ClientCameraRelayStatus.unknown => const Color(0xFF34D399),
    };
  }

  String _clientLaneRelaySummary(
    ClientCameraRelayStatus? status, {
    required String relayFrameLabel,
    required String relayCheckLabel,
    required int activeClientCount,
  }) {
    return switch (status ?? ClientCameraRelayStatus.unknown) {
      ClientCameraRelayStatus.active => [
        'Operator stream relay is actively serving frames on the temporary local bridge.',
        if (activeClientCount > 0)
          '$activeClientCount operator ${activeClientCount == 1 ? 'session is' : 'sessions are'} attached right now.',
        if (relayFrameLabel.isNotEmpty) 'Latest frame $relayFrameLabel.',
      ].join(' '),
      ClientCameraRelayStatus.ready => [
        'Operator stream relay is ready on the temporary local bridge.',
        if (relayFrameLabel.isNotEmpty) 'Latest frame $relayFrameLabel.',
        'Use the relay player for moving video, and keep resident replies grounded on verified visual confirmation rather than on the existence of the relay itself.',
      ].join(' '),
      ClientCameraRelayStatus.starting => [
        'Operator stream relay is starting on the temporary local bridge.',
        if (relayCheckLabel.isNotEmpty) 'Last relay check $relayCheckLabel.',
        'A player request is open, but ONYX is still waiting for the next confirmed frame.',
      ].join(' '),
      ClientCameraRelayStatus.stale => [
        'Operator stream relay is reachable, but the moving-video path looks stale right now.',
        if (relayFrameLabel.isNotEmpty) 'Latest frame $relayFrameLabel.',
        'Refresh the player if motion looks frozen.',
      ].join(' '),
      ClientCameraRelayStatus.error => [
        'Operator stream relay is reachable, but it reported an error on the latest check.',
        if (relayCheckLabel.isNotEmpty) 'Last relay check $relayCheckLabel.',
        'Use the still-frame path until the relay clears.',
      ].join(' '),
      ClientCameraRelayStatus.idle => [
        'Operator stream relay is available on the temporary local bridge, but it is idle right now.',
        if (relayCheckLabel.isNotEmpty) 'Last relay check $relayCheckLabel.',
        'Open the player when moving video is needed.',
      ].join(' '),
      ClientCameraRelayStatus.unknown =>
        'Operator stream relay is ready on the temporary local bridge. Use the relay player for moving video, and keep resident replies grounded on verified visual confirmation rather than on the existence of the relay itself.',
    };
  }

  String _clientLaneLocalProxySummary(
    ClientCameraHealthFactPacket packet, {
    required String lastAlertLabel,
    required String lastSuccessLabel,
  }) {
    final upstreamStatus = (packet.localProxyUpstreamStreamStatus ?? '')
        .trim()
        .toLowerCase();
    final parts = <String>[
      'Scoped local proxy is ${packet.scopedLocalProxyStatusLabel}.',
      if (upstreamStatus == 'connected' ||
          packet.localProxyUpstreamStreamConnected == true)
        'The upstream alert stream is connected right now.'
      else if (upstreamStatus == 'reconnecting')
        'The upstream alert stream is reconnecting right now.'
      else if (packet.localProxyReachable == true &&
          packet.localProxyRunning == true)
        'The proxy is reachable, but the upstream alert stream is not currently attached.',
      if ((packet.localProxyBufferedAlertCount ?? 0) > 0)
        '${packet.localProxyBufferedAlertCount} alert${packet.localProxyBufferedAlertCount == 1 ? '' : 's'} buffered for this scope.',
      if (lastAlertLabel.isNotEmpty) 'Last alert $lastAlertLabel.',
      if (lastSuccessLabel.isNotEmpty) 'Last success $lastSuccessLabel.',
    ];
    return parts.join(' ');
  }

  String _humanizeClientLaneLocalProxyIssue(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return '';
    }
    final lower = normalized.toLowerCase();
    if (lower.contains('connection refused')) {
      return 'The scoped local proxy is not accepting connections on the latest check.';
    }
    if (lower.contains('host is down')) {
      return 'The recorder host reported as down on the latest proxy check.';
    }
    if (lower.contains('timed out')) {
      return 'The upstream alert path timed out on the latest proxy check.';
    }
    if (lower.contains('http 5')) {
      return 'The scoped local proxy returned an upstream server failure on the latest check.';
    }
    if (lower.contains('http 4')) {
      return 'The scoped local proxy returned a request failure on the latest check.';
    }
    return normalized;
  }

  Color _clientLaneLocalProxyStatusAccent(String status) {
    return switch (status.trim().toLowerCase()) {
      'connected' => const Color(0xFF34D399),
      'reconnecting' => const Color(0xFFF59E0B),
      'ready' => const Color(0xFF38BDF8),
      'degraded' => const Color(0xFFF59E0B),
      'offline' => const Color(0xFFEF4444),
      _ => const Color(0xFF94A3B8),
    };
  }

  String _clientLaneLocalProxyChipLabel(String status) {
    return switch (status.trim().toLowerCase()) {
      'reconnecting' => 'Proxy RECONNECTING...',
      _ => 'Proxy ${status.toUpperCase()}',
    };
  }

  String _humanizeOpsScopeLabel(String raw, {required String fallback}) {
    final cleaned = raw
        .trim()
        .replaceFirst(RegExp(r'^(CLIENT|SITE|REGION)-'), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return fallback;
    }
    final stopWords = <String>{'and', 'of', 'the'};
    return cleaned
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final lower = entry.value.toLowerCase();
          if (entry.key > 0 && stopWords.contains(lower)) {
            return lower;
          }
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  int _priorityRank(_IncidentPriority priority) {
    return switch (priority) {
      _IncidentPriority.p1Critical => 0,
      _IncidentPriority.p2High => 1,
      _IncidentPriority.p3Medium => 2,
      _IncidentPriority.p4Low => 3,
    };
  }

  _IncidentPriority _incidentPriorityFor(
    int risk, {
    required MonitoringSceneReviewRecord? latestSceneReview,
  }) {
    final basePriority = switch (risk) {
      >= 85 => _IncidentPriority.p1Critical,
      >= 70 => _IncidentPriority.p2High,
      >= 50 => _IncidentPriority.p3Medium,
      _ => _IncidentPriority.p4Low,
    };
    final posture = (latestSceneReview?.postureLabel ?? '')
        .trim()
        .toLowerCase();
    if (posture.contains('fire') || posture.contains('smoke')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('flood') || posture.contains('leak')) {
      return _IncidentPriority.p1Critical;
    }
    if (posture.contains('hazard')) {
      if (_priorityRank(basePriority) >
          _priorityRank(_IncidentPriority.p2High)) {
        return _IncidentPriority.p2High;
      }
    }
    return basePriority;
  }

  String _incidentTypeFor(
    int risk, {
    required MonitoringSceneReviewRecord? latestSceneReview,
  }) {
    final posture = (latestSceneReview?.postureLabel ?? '')
        .trim()
        .toLowerCase();
    if (posture.contains('fire') || posture.contains('smoke')) {
      return 'Fire / Smoke Emergency';
    }
    if (posture.contains('flood') || posture.contains('leak')) {
      return 'Flood / Leak Emergency';
    }
    if (posture.contains('hazard')) {
      return 'Environmental Hazard';
    }
    return risk >= 85 ? 'Breach Detection' : 'Perimeter Alarm';
  }

  String _hhmm(DateTime timestamp) {
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _evidenceReadyLabel(_IncidentRecord incident) {
    final snapshot = (incident.snapshotUrl ?? '').trim().isNotEmpty;
    final clip = (incident.clipUrl ?? '').trim().isNotEmpty;
    if (snapshot && clip) {
      return 'snapshot + clip';
    }
    if (snapshot) {
      return 'snapshot only';
    }
    if (clip) {
      return 'clip only';
    }
    return 'pending';
  }

  String _compactContextLabel(String value, {int maxLength = 68}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength).trimRight()}...';
  }

  String _hashFor(String seed) {
    final value = seed.hashCode.toUnsigned(32);
    return value.toRadixString(16).padLeft(8, '0');
  }
}

class _PriorityStyle {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const _PriorityStyle({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });
}

class _LedgerStyle {
  final IconData icon;
  final Color color;

  const _LedgerStyle({required this.icon, required this.color});
}
