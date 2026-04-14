import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/response_arrived.dart';
import 'client_comms_queue_board.dart';
import 'layout_breakpoints.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';
import 'ui_action_logger.dart';

class ClientsAgentDraftHandoff {
  final String id;
  final String clientId;
  final String siteId;
  final String room;
  final String incidentReference;
  final String draftText;
  final String originalDraftText;
  final String sourceRouteLabel;
  final DateTime createdAtUtc;
  final ClientCommsQueueSeverity severity;

  const ClientsAgentDraftHandoff({
    required this.id,
    required this.clientId,
    required this.siteId,
    required this.room,
    required this.incidentReference,
    required this.draftText,
    required this.originalDraftText,
    required this.sourceRouteLabel,
    required this.createdAtUtc,
    this.severity = ClientCommsQueueSeverity.medium,
  });

  bool matchesScope(String candidateClientId, String candidateSiteId) {
    return clientId.trim() == candidateClientId.trim() &&
        siteId.trim() == candidateSiteId.trim();
  }
}

class ClientsEvidenceReturnReceipt {
  final String auditId;
  final String label;
  final String headline;
  final String detail;
  final Color accent;

  const ClientsEvidenceReturnReceipt({
    required this.auditId,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
  });
}

class ClientsLiveFollowUpNotice {
  final String id;
  final String author;
  final String body;
  final String room;
  final DateTime occurredAtUtc;
  final bool urgent;
  final String suggestedReplyDraft;

  const ClientsLiveFollowUpNotice({
    required this.id,
    required this.author,
    required this.body,
    this.room = '',
    required this.occurredAtUtc,
    this.urgent = false,
    this.suggestedReplyDraft = '',
  });
}

enum ClientsRouteHandoffTarget {
  none,
  pendingDrafts,
  threadContext,
  channelReview,
}

class ClientsPage extends StatefulWidget {
  final String clientId;
  final String siteId;
  final List<DispatchEvent> events;
  final Future<void> Function()? onRetryPushSync;
  final void Function(String room, String clientId, String siteId)?
  onOpenClientRoomForScope;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;
  final ValueChanged<String>? onOpenAgentForIncident;
  final ClientsAgentDraftHandoff? stagedAgentDraftHandoff;
  final ValueChanged<String>? onConsumeStagedAgentDraftHandoff;
  final ClientsEvidenceReturnReceipt? evidenceReturnReceipt;
  final ValueChanged<String>? onConsumeEvidenceReturnReceipt;
  final ClientsLiveFollowUpNotice? liveFollowUpNotice;
  final Future<String> Function(
    ClientsLiveFollowUpNotice notice,
    String clientId,
    String siteId,
  )?
  onSuggestLiveFollowUpReply;
  final Future<bool> Function(
    ClientsAgentDraftHandoff handoff,
    String draftText,
  )?
  onSendStagedAgentDraftHandoff;
  final Future<String?> Function(
    String clientId,
    String siteId,
    String room,
    String currentDraftText,
  )?
  onAiAssistQueueDraft;
  final bool usePlaceholderDataWhenEmpty;
  final int routeHandoffToken;
  final ClientsRouteHandoffTarget routeHandoffTarget;

  const ClientsPage({
    super.key,
    required this.clientId,
    required this.siteId,
    required this.events,
    this.onRetryPushSync,
    this.onOpenClientRoomForScope,
    this.onOpenEventsForScope,
    this.onOpenAgentForIncident,
    this.stagedAgentDraftHandoff,
    this.onConsumeStagedAgentDraftHandoff,
    this.evidenceReturnReceipt,
    this.onConsumeEvidenceReturnReceipt,
    this.liveFollowUpNotice,
    this.onSuggestLiveFollowUpReply,
    this.onSendStagedAgentDraftHandoff,
    this.onAiAssistQueueDraft,
    this.usePlaceholderDataWhenEmpty = true,
    this.routeHandoffToken = 0,
    this.routeHandoffTarget = ClientsRouteHandoffTarget.none,
  });

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final GlobalKey _messageHistoryKey = GlobalKey();
  final GlobalKey _pendingDraftsCardKey = GlobalKey();
  final GlobalKey _roomThreadContextCardKey = GlobalKey();
  final GlobalKey _communicationChannelsCardKey = GlobalKey();

  String? _selectedClientId;
  String? _selectedSiteId;
  String _lastOpenedRoom = '';
  bool _selectionReconcileScheduled = false;
  bool _showDetailedWorkspace = false;
  int _pushRetryCount = 0;
  String _pushSyncStatus = 'push idle';
  String _backendProbeStatus = 'healthy';
  String? _voipStageStatus;
  String _selectedPinnedVoice = 'Auto';
  String? _focusedQueueItemId;
  _DetailedCommsResumeTarget _focusedQueueResumeTarget =
      _DetailedCommsResumeTarget.pendingDrafts;
  final Map<String, ClientsAgentDraftHandoff> _stagedAgentDraftHandoffs =
      <String, ClientsAgentDraftHandoff>{};
  final Set<String> _resolvedQueueItemIds = <String>{};
  final Map<String, String> _editedQueueDraftBodies = <String, String>{};
  ClientsEvidenceReturnReceipt? _activeEvidenceReturnReceipt;
  bool _preparingLatestSentFollowUpReply = false;
  int _lastAppliedRouteHandoffToken = 0;

  @override
  void initState() {
    super.initState();
    _ingestStagedAgentDraftHandoff(widget.stagedAgentDraftHandoff);
    _ingestEvidenceReturnReceipt(widget.evidenceReturnReceipt);
    _syncSelectedScopeFromWidget();
    _applyRouteHandoff(force: true);
  }

  @override
  void dispose() => super.dispose();

  @override
  void didUpdateWidget(covariant ClientsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stagedAgentDraftHandoff?.id !=
        widget.stagedAgentDraftHandoff?.id) {
      _ingestStagedAgentDraftHandoff(
        widget.stagedAgentDraftHandoff,
        useSetState: true,
      );
    }
    if (oldWidget.evidenceReturnReceipt?.auditId !=
        widget.evidenceReturnReceipt?.auditId) {
      _ingestEvidenceReturnReceipt(
        widget.evidenceReturnReceipt,
        useSetState: true,
      );
    }
    if (oldWidget.clientId != widget.clientId ||
        oldWidget.siteId != widget.siteId) {
      _syncSelectedScopeFromWidget(useSetState: true);
    }
    if (oldWidget.routeHandoffToken != widget.routeHandoffToken ||
        oldWidget.routeHandoffTarget != widget.routeHandoffTarget) {
      _applyRouteHandoff(useSetState: true, force: true);
    }
  }

  void _syncSelectedScopeFromWidget({bool useSetState = false}) {
    final normalizedClientId = widget.clientId.trim();
    final normalizedSiteId = widget.siteId.trim();
    final effectiveClientId = normalizedClientId.isEmpty
        ? _selectedClientId
        : normalizedClientId;
    final effectiveSiteId = normalizedSiteId.isEmpty
        ? _selectedSiteId
        : normalizedSiteId;

    void apply() {
      if (effectiveClientId != null && effectiveClientId.isNotEmpty) {
        _selectedClientId = effectiveClientId;
      }
      if (effectiveSiteId != null && effectiveSiteId.isNotEmpty) {
        _selectedSiteId = effectiveSiteId;
      }
      final latestDraft =
          effectiveClientId == null ||
              effectiveClientId.isEmpty ||
              effectiveSiteId == null ||
              effectiveSiteId.isEmpty
          ? null
          : _latestStagedAgentDraftHandoffForScope(
              clientId: effectiveClientId,
              siteId: effectiveSiteId,
            );
      _focusedQueueItemId = latestDraft?.id;
      if (latestDraft == null) {
        _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
      }
    }

    if (useSetState && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _applyRouteHandoff({bool useSetState = false, bool force = false}) {
    final handoffToken = widget.routeHandoffToken;
    if (!force && handoffToken == _lastAppliedRouteHandoffToken) {
      return;
    }
    final normalizedClientId = widget.clientId.trim();
    final normalizedSiteId = widget.siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      _lastAppliedRouteHandoffToken = handoffToken;
      return;
    }
    final latestDraft = _latestStagedAgentDraftHandoffForScope(
      clientId: normalizedClientId,
      siteId: normalizedSiteId,
    );
    final effectiveTarget = latestDraft != null
        ? ClientsRouteHandoffTarget.pendingDrafts
        : widget.routeHandoffTarget;

    void apply() {
      _selectedClientId = normalizedClientId;
      _selectedSiteId = normalizedSiteId;
      _lastAppliedRouteHandoffToken = handoffToken;
      switch (effectiveTarget) {
        case ClientsRouteHandoffTarget.none:
          return;
        case ClientsRouteHandoffTarget.pendingDrafts:
          _showDetailedWorkspace = false;
          _focusedQueueItemId = latestDraft?.id;
          _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
        case ClientsRouteHandoffTarget.threadContext:
          _showDetailedWorkspace = true;
          _focusedQueueItemId = null;
          _focusedQueueResumeTarget = _DetailedCommsResumeTarget.threadContext;
        case ClientsRouteHandoffTarget.channelReview:
          _showDetailedWorkspace = true;
          _focusedQueueItemId = null;
          _focusedQueueResumeTarget = _DetailedCommsResumeTarget.channelReview;
      }
    }

    if (useSetState && mounted) {
      setState(apply);
    } else {
      apply();
    }

    if (effectiveTarget == ClientsRouteHandoffTarget.threadContext ||
        effectiveTarget == ClientsRouteHandoffTarget.channelReview) {
      final resumeTarget = effectiveTarget ==
              ClientsRouteHandoffTarget.threadContext
          ? _DetailedCommsResumeTarget.threadContext
          : _DetailedCommsResumeTarget.channelReview;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _scrollToDetailedCommsResumeTarget(resumeTarget);
      });
    }
  }

  void _ingestEvidenceReturnReceipt(
    ClientsEvidenceReturnReceipt? receipt, {
    bool useSetState = false,
  }) {
    if (receipt == null) {
      return;
    }

    void apply() {
      _activeEvidenceReturnReceipt = receipt;
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseModel = _withAgentDraftHandoffScopes(
      _deriveClientSiteModel(widget.events),
    );
    final model = widget.usePlaceholderDataWhenEmpty
        ? baseModel
        : _withExplicitRouteScope(baseModel);
    final clients =
        model.clients.isEmpty && widget.usePlaceholderDataWhenEmpty
        ? _fallbackClients
        : model.clients;
    final sites = model.sites.isEmpty && widget.usePlaceholderDataWhenEmpty
        ? _fallbackSites
        : model.sites;
    if (clients.isEmpty || sites.isEmpty) {
      return OnyxPageScaffold(
        child: Center(
          child: Text(
            'Client Communications needs a scoped client and site before the workspace can open.',
            style: GoogleFonts.inter(
              color: const Color(0x80FFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selectedClientId =
        _selectedClientId != null && clients.any((c) => c.id == _selectedClientId)
        ? _selectedClientId!
        : clients.first.id;
    var availableSites = sites
        .where((site) => site.clientId == selectedClientId)
        .toList(growable: false);
    if (availableSites.isEmpty) {
      availableSites = sites;
    }

    final selectedSiteId =
        _selectedSiteId != null &&
            availableSites.any((site) => site.id == _selectedSiteId)
        ? _selectedSiteId!
        : availableSites.first.id;
    _scheduleSelectionReconcile(
      clientId: selectedClientId,
      siteId: selectedSiteId,
    );

    final currentClient = clients.firstWhere(
      (client) => client.id == selectedClientId,
    );
    final currentSite = availableSites.firstWhere(
      (site) => site.id == selectedSiteId,
    );

    final feedRows = _incidentFeedRows(
      events: widget.events,
      selectedClientId: selectedClientId,
      selectedSiteId: selectedSiteId,
    );
    final rows =
        feedRows.isEmpty && widget.usePlaceholderDataWhenEmpty
        ? _fallbackFeed
        : feedRows;

    final unreadAlerts = rows
        .where((row) => row.status != _FeedStatus.info)
        .length;
    final activeIncidents = widget.events
        .whereType<DecisionCreated>()
        .where(
          (event) =>
              event.clientId == selectedClientId &&
              event.siteId == selectedSiteId,
        )
        .length;
    final directUpdates = rows.length;
    final pendingAsks =
        rows.where((row) => row.type == _FeedType.update).length +
        _stagedAgentDraftCountForScope(
          clientId: selectedClientId,
          siteId: selectedSiteId,
        );
    final pushSyncLower = _pushSyncStatus.toLowerCase();
    final backendProbeLower = _backendProbeStatus.toLowerCase();
    final voipStageLower = (_voipStageStatus ?? '').toLowerCase();
    final voipConfigured = (_voipStageStatus ?? '').trim().isNotEmpty;
    final telegramBlocked = pushSyncLower.contains('blocked');
    final smsFallbackActive = pushSyncLower.contains('fallback');
    final voipReady =
        voipConfigured &&
        voipStageLower.contains('dialing') ||
        voipConfigured &&
        voipStageLower.contains('ready') ||
        voipConfigured &&
        voipStageLower.contains('connected');
    final voipStaged = voipConfigured && voipStageLower.contains('staged');
    final pushNeedsReview =
        pushSyncLower.contains('retry') || pushSyncLower.contains('review');
    final pushIdle =
        pushSyncLower.contains('idle') &&
        !pushNeedsReview &&
        !telegramBlocked &&
        !smsFallbackActive;
    String? reviewEventId;
    for (final row in rows) {
      if (row.type == _FeedType.update && row.eventId != null) {
        reviewEventId = row.eventId;
        break;
      }
    }
    final queueItems = _visibleControllerQueueItems();
    final agentIncidentReference = _agentIncidentReference(
      selectedClientId: selectedClientId,
      selectedSiteId: selectedSiteId,
    );
    final queuedDraftItemId = _latestStagedAgentDraftHandoffForScope(
      clientId: selectedClientId,
      siteId: selectedSiteId,
    )?.id.trim();
    final learnedStyleSummary = _learnedStyleSummaryForScope(
      clientId: selectedClientId,
      siteId: selectedSiteId,
    );

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktopWorkspace = constraints.maxWidth >= 1240;
          final stacked = constraints.maxWidth < 1220;
          final boundedDesktopSurface =
              desktopWorkspace && allowEmbeddedPanelScroll(context);
          final ultrawideSurface = isUltrawideLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final widescreenSurface = isWidescreenLayout(
            context,
            viewportWidth: constraints.maxWidth,
          );
          final surfaceMaxWidth = ultrawideSurface || widescreenSurface
              ? constraints.maxWidth
              : 1760.0;
          final communicationsBoard = Column(
            children: [
              _messageHistoryCard(
                rows,
                currentClient: currentClient,
                currentSite: currentSite,
                pendingAsks: pendingAsks,
                unreadAlerts: unreadAlerts,
                directUpdates: directUpdates,
              ),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: _roomThreadContextCardKey,
                child: _roomThreadContextCard(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  clients: clients,
                  sites: sites,
                  availableSites: availableSites,
                  pendingAsks: pendingAsks,
                  agentIncidentReference: agentIncidentReference,
                  queuedDraftItemId: queuedDraftItemId,
                ),
              ),
              const SizedBox(height: 8),
              KeyedSubtree(
                key: _communicationChannelsCardKey,
                child: _communicationChannelsCard(
                  telegramBlocked: telegramBlocked,
                  smsFallbackActive: smsFallbackActive,
                  voipConfigured: voipConfigured,
                  voipReady: voipReady,
                  voipStaged: voipStaged,
                  pushNeedsReview: pushNeedsReview,
                  pushIdle: pushIdle,
                  backendProbeHealthy:
                      backendProbeLower.contains('healthy') ||
                      backendProbeLower.contains('ok'),
                  pendingAsks: pendingAsks,
                  agentIncidentReference: agentIncidentReference,
                  queuedDraftItemId: queuedDraftItemId,
                ),
              ),
            ],
          );
          final contextRail = Column(
            children: [
              KeyedSubtree(
                key: _pendingDraftsCardKey,
                child: _pendingDraftsCard(
                  pendingAsks: pendingAsks,
                  activeIncidents: activeIncidents,
                  reviewEventId: reviewEventId,
                  agentIncidentReference: agentIncidentReference,
                  queuedDraftItemId: queuedDraftItemId,
                ),
              ),
              if (learnedStyleSummary != null) ...[
                const SizedBox(height: 8),
                _learnedStyleCard(
                  label: learnedStyleSummary.label,
                  source: learnedStyleSummary.source,
                ),
              ],
              const SizedBox(height: 8),
              _pinnedVoiceCard(),
            ],
          );

          final body = desktopWorkspace
              ? _clientsDesktopWorkspace(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  clients: clients,
                  sites: sites,
                  pendingAsks: pendingAsks,
                  unreadAlerts: unreadAlerts,
                  directUpdates: directUpdates,
                  activeIncidents: activeIncidents,
                  reviewEventId: reviewEventId,
                  pushRetryAvailable: widget.onRetryPushSync != null,
                  roomRoutingAvailable: widget.onOpenClientRoomForScope != null,
                  communicationsBoard: communicationsBoard,
                  contextRail: contextRail,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activeLanesSection(
                      currentClient: currentClient,
                      currentSite: currentSite,
                      clients: clients,
                      sites: availableSites,
                      pendingAsks: pendingAsks,
                    ),
                    const SizedBox(height: 8),
                    stacked
                        ? Column(
                            children: [
                              communicationsBoard,
                              const SizedBox(height: 8),
                              contextRail,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: communicationsBoard),
                              const SizedBox(width: 8),
                              Expanded(flex: 1, child: contextRail),
                            ],
                          ),
                  ],
                );
          final detailedBody = _buildDetailedWorkspaceBody(
            desktopWorkspace: desktopWorkspace,
            boundedDesktopSurface: boundedDesktopSurface,
            currentClient: currentClient,
            currentSite: currentSite,
            clients: clients,
            sites: sites,
            pendingAsks: pendingAsks,
            unreadAlerts: unreadAlerts,
            directUpdates: directUpdates,
            activeIncidents: activeIncidents,
            reviewEventId: reviewEventId,
            communicationsBoard: communicationsBoard,
            contextRail: contextRail,
            legacyBody: body,
          );

          if (!_showDetailedWorkspace) {
            return OnyxViewportWorkspaceLayout(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              maxWidth: surfaceMaxWidth,
              spacing: 0,
              lockToViewport: false,
              header: const SizedBox.shrink(),
              body: ClientCommsQueueBoard(
                items: queueItems,
                showDetailedWorkspace: false,
                latestSentFollowUpAuthor: widget.liveFollowUpNotice?.author,
                latestSentFollowUpBody: widget.liveFollowUpNotice?.body,
                latestSentFollowUpOccurredAtUtc:
                    widget.liveFollowUpNotice?.occurredAtUtc,
                latestSentFollowUpUrgent:
                    widget.liveFollowUpNotice?.urgent ?? false,
                preparingLatestSentFollowUpReply:
                    _preparingLatestSentFollowUpReply,
                onPrepareLatestSentFollowUpReply:
                    widget.liveFollowUpNotice == null ||
                        _preparingLatestSentFollowUpReply
                    ? null
                    : () {
                        unawaited(_prepareLatestSentFollowUpReply());
                      },
                onToggleDetailedWorkspace: _toggleDetailedWorkspace,
                focusedItemId: _focusedQueueItemId,
                focusedResumeActionLabel: _focusedQueueResumeActionLabel,
                onResumeDetailedWorkspaceForItem:
                    _resumeDetailedWorkspaceForQueueItem,
                onSend: (item) {
                  unawaited(_sendQueueItem(item));
                },
                onEdit: _editQueueItem,
                onReject: _rejectQueueItem,
                onOpenAgentForIncident: widget.onOpenAgentForIncident,
              ),
            );
          }

          return OnyxViewportWorkspaceLayout(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            maxWidth: surfaceMaxWidth,
            spacing: 6,
            lockToViewport: boundedDesktopSurface,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Clients',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: OnyxDesignTokens.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    if (pendingAsks + unreadAlerts > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: OnyxDesignTokens.cyanInfo.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: OnyxDesignTokens.cyanInfo.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: OnyxDesignTokens.cyanInfo,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${pendingAsks + unreadAlerts} active',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: OnyxDesignTokens.cyanInfo,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _heroHeader(
                  currentClient: currentClient,
                  currentSite: currentSite,
                  unreadAlerts: unreadAlerts,
                  pendingAsks: pendingAsks,
                  directUpdates: directUpdates,
                  agentIncidentReference: agentIncidentReference,
                  desktopStatusCard: desktopWorkspace
                      ? _clientsWorkspaceStatusBanner(
                          currentClient: currentClient,
                          currentSite: currentSite,
                          unreadAlerts: unreadAlerts,
                          pendingAsks: pendingAsks,
                          directUpdates: directUpdates,
                          activeIncidents: activeIncidents,
                          reviewEventId: reviewEventId,
                          agentIncidentReference: agentIncidentReference,
                          pushRetryAvailable: widget.onRetryPushSync != null,
                          roomRoutingAvailable:
                              widget.onOpenClientRoomForScope != null,
                          shellless: true,
                        )
                      : null,
                ),
              ],
            ),
            body: detailedBody,
          );
        },
      ),
    );
  }

  Widget _buildDetailedWorkspaceBody({
    required bool desktopWorkspace,
    required bool boundedDesktopSurface,
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
    required int activeIncidents,
    required String? reviewEventId,
    required Widget communicationsBoard,
    required Widget contextRail,
    required Widget legacyBody,
  }) {
    final toggle = _clientsDetailedWorkspaceToggle();
    if (!desktopWorkspace) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [legacyBody, const SizedBox(height: 12), toggle],
      );
    }

    final desktopBody = _clientsDesktopWorkspace(
      currentClient: currentClient,
      currentSite: currentSite,
      clients: clients,
      sites: sites,
      pendingAsks: pendingAsks,
      unreadAlerts: unreadAlerts,
      directUpdates: directUpdates,
      activeIncidents: activeIncidents,
      reviewEventId: reviewEventId,
      pushRetryAvailable: widget.onRetryPushSync != null,
      roomRoutingAvailable: widget.onOpenClientRoomForScope != null,
      communicationsBoard: communicationsBoard,
      contextRail: contextRail,
    );

    if (boundedDesktopSurface) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: desktopBody),
          const SizedBox(height: 12),
          toggle,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [desktopBody, const SizedBox(height: 12), toggle],
    );
  }

  Widget _clientsDetailedWorkspaceToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        key: const ValueKey('clients-toggle-detailed-workspace'),
        onPressed: _toggleDetailedWorkspace,
        icon: const Icon(Icons.visibility_off_rounded, size: 15),
        label: const Text('Hide Detailed Workspace'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9D4BFF),
          side: const BorderSide(color: Color(0x4D9D4BFF)),
          backgroundColor: const Color(0xFF13131E),
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

  void _toggleDetailedWorkspace() {
    setState(() {
      _showDetailedWorkspace = !_showDetailedWorkspace;
    });
    logUiAction(
      'clients.toggle_detailed_workspace',
      context: {
        'open': _showDetailedWorkspace,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
      },
    );
  }

  Widget _clientsDesktopWorkspace({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
    required int activeIncidents,
    required String? reviewEventId,
    required bool pushRetryAvailable,
    required bool roomRoutingAvailable,
    required Widget communicationsBoard,
    required Widget contextRail,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final workspaceWidth = constraints.maxWidth;
        final stretchPanels =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;
        final ultrawideWorkspace = isUltrawideLayout(
          context,
          viewportWidth: workspaceWidth,
        );
        final widescreenWorkspace = isWidescreenLayout(
          context,
          viewportWidth: workspaceWidth,
        );
        final railGap = ultrawideWorkspace ? 8.0 : 6.0;
        final leftRailWidth = ultrawideWorkspace
            ? 276.0
            : widescreenWorkspace
            ? 264.0
            : 248.0;
        final rightRailWidth = ultrawideWorkspace
            ? 260.0
            : widescreenWorkspace
            ? 248.0
            : 232.0;

        return Row(
          crossAxisAlignment: stretchPanels
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftRailWidth,
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-rail'),
                title: 'PICK A CLIENT THREAD',
                subtitle: 'Choose the client thread and move fast.',
                shellless: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activeLanesSection(
                      currentClient: currentClient,
                      currentSite: currentSite,
                      clients: clients,
                      sites: sites,
                      pendingAsks: pendingAsks,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pick the thread first. Clear drafts and open rooms from the boards next to it.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF9CB2D1),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: railGap),
            Expanded(
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-board'),
                title: 'TALK / REVIEW / SEND',
                subtitle: 'Read the thread, review the draft, send the reply.',
                shellless: true,
                child: communicationsBoard,
              ),
            ),
            SizedBox(width: railGap),
            SizedBox(
              width: rightRailWidth,
              child: _clientsWorkspacePanel(
                key: const ValueKey('clients-workspace-panel-context'),
                title: 'QUEUE / VOICE',
                subtitle: 'Clear queued drafts and keep voice ready.',
                shellless: true,
                child: contextRail,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _clientsWorkspacePanel({
    Key? key,
    required String title,
    required String subtitle,
    required Widget child,
    bool shellless = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (shellless) {
          final shelllessBody =
              constraints.hasBoundedHeight && !isHandsetLayout(context)
              ? SingleChildScrollView(child: child)
              : child;
          return KeyedSubtree(key: key, child: shelllessBody);
        }
        return Container(
          key: key,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF13131E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x269D4BFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120D1726),
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8E8F0),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6A7D93),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                onyxBoundedPanelBody(
                  context: context,
                  constraints: constraints,
                  child: child,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _clientsWorkspaceStatusBanner({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
    required int activeIncidents,
    required String? reviewEventId,
    required String? agentIncidentReference,
    required bool pushRetryAvailable,
    required bool roomRoutingAvailable,
    bool shellless = false,
  }) {
    final evidenceReceipt = _activeEvidenceReturnReceipt;
    if (evidenceReceipt != null) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EVIDENCE RETURN',
            style: GoogleFonts.inter(
              color: evidenceReceipt.accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            evidenceReceipt.label,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            evidenceReceipt.headline,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            evidenceReceipt.detail,
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const ValueKey('clients-acknowledge-evidence-return'),
              onPressed: _acknowledgeEvidenceReturnReceipt,
              child: const Text('Acknowledge'),
            ),
          ),
        ],
      );
      if (shellless) {
        return KeyedSubtree(
          key: const ValueKey('clients-workspace-status-banner'),
          child: content,
        );
      }
      return Container(
        key: const ValueKey('clients-workspace-status-banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: evidenceReceipt.accent.withValues(alpha: 0.34),
          ),
        ),
        child: content,
      );
    }
    final openAgent = widget.onOpenAgentForIncident;
    final canOpenAgent =
        openAgent != null && (agentIncidentReference ?? '').trim().isNotEmpty;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What needs attention',
          style: GoogleFonts.inter(
            color: const Color(0x80FFFFFF),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _clientsNextMoveLabel(
            pendingAsks: pendingAsks,
            unreadAlerts: unreadAlerts,
            directUpdates: directUpdates,
          ),
          style: GoogleFonts.inter(
            color: const Color(0xFFE8E8F0),
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${currentClient.name} • ${currentSite.name}',
          style: GoogleFonts.inter(
            color: const Color(0xFF6A7D93),
            fontSize: 10.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _clientsNextMoveDetail(
            pendingAsks: pendingAsks,
            unreadAlerts: unreadAlerts,
            directUpdates: directUpdates,
          ),
          style: GoogleFonts.inter(
            color: const Color(0xFF6A7D93),
            fontSize: 10.2,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _clientsWorkspaceSummaryLine(
            unreadAlerts: unreadAlerts,
            pendingAsks: pendingAsks,
            directUpdates: directUpdates,
            activeIncidents: activeIncidents,
          ),
          style: GoogleFonts.inter(
            color: const Color(0x80FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        if (canOpenAgent) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('clients-workspace-open-agent'),
              onPressed: () => openAgent(agentIncidentReference!.trim()),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9D4BFF),
                side: const BorderSide(color: Color(0x4D9D4BFF)),
                backgroundColor: const Color(0xFF1A1A2E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.psychology_alt_rounded, size: 16),
              label: const Text('Ask Junior Analyst'),
            ),
          ),
        ],
      ],
    );
    if (shellless) {
      return KeyedSubtree(
        key: const ValueKey('clients-workspace-status-banner'),
        child: content,
      );
    }
    return Container(
      key: const ValueKey('clients-workspace-status-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: content,
    );
  }

  String _clientsWorkspaceSummaryLine({
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
    required int activeIncidents,
  }) {
    final parts = <String>[
      unreadAlerts == 1 ? '1 alert' : '$unreadAlerts alerts',
      pendingAsks == 1 ? '1 draft waiting' : '$pendingAsks drafts waiting',
      directUpdates == 1 ? '1 recent update' : '$directUpdates recent updates',
      activeIncidents == 1
          ? '1 live incident'
          : '$activeIncidents live incidents',
    ];
    return parts.join(' • ');
  }

  Widget _heroHeader({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int unreadAlerts,
    required int pendingAsks,
    required int directUpdates,
    required String? agentIncidentReference,
    Widget? desktopStatusCard,
  }) {
    final openAgent = widget.onOpenAgentForIncident;
    final normalizedAgentIncidentReference = (agentIncidentReference ?? '')
        .trim();
    final canOpenAgent =
        openAgent != null && normalizedAgentIncidentReference.isNotEmpty;
    final threadStatus = _chatThreadStatus(
      pendingAsks: pendingAsks,
      unreadAlerts: unreadAlerts,
      directUpdates: directUpdates,
    );
    final snapshotCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What needs attention',
            style: GoogleFonts.inter(
              color: const Color(0x80FFFFFF),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _clientsNextMoveLabel(
              pendingAsks: pendingAsks,
              unreadAlerts: unreadAlerts,
              directUpdates: directUpdates,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 15.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${currentClient.name} • ${currentSite.name} • $threadStatus',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 10.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _clientsNextMoveDetail(
              pendingAsks: pendingAsks,
              unreadAlerts: unreadAlerts,
              directUpdates: directUpdates,
            ),
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 10.1,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4ECF9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.mark_chat_read_rounded,
                  color: Color(0xFF9D4BFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Client Communications',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8E8F0),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${currentClient.name} • ${currentSite.name}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6A7D93),
                        fontSize: 11.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Keep the chat familiar. Read the thread, clear the next draft, and reply without hunting through the UI.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6A7D93),
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (canOpenAgent)
                OutlinedButton.icon(
                  key: const ValueKey('clients-open-agent-button'),
                  onPressed: () => openAgent(normalizedAgentIncidentReference),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9D4BFF),
                    side: const BorderSide(color: Color(0x4D9D4BFF)),
                    backgroundColor: const Color(0xFF1A1A2E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.psychology_alt_rounded, size: 16),
                  label: const Text('Ask Junior Analyst'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          desktopStatusCard ?? snapshotCard,
        ],
      ),
    );
  }

  String _clientsNextMoveLabel({
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
  }) {
    if (pendingAsks > 0) return 'Review the top draft';
    if (unreadAlerts > 0) return 'Reply to the thread';
    if (directUpdates > 0) return 'Hold the thread';
    return 'Keep the thread ready';
  }

  String _clientsNextMoveDetail({
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
  }) {
    if (pendingAsks > 0) {
      return 'Queued replies are waiting for control approval. Review and send the top draft first.';
    }
    if (unreadAlerts > 0) {
      return 'This thread needs attention. Open the room or ask the agent before the client chases you.';
    }
    if (directUpdates > 0) {
      return 'The thread is active but stable. Keep it tight and stay ready for the next client ask.';
    }
    return 'Nothing is pushing right now. Stay on watch and keep the room ready.';
  }

  String? _agentIncidentReference({
    required String selectedClientId,
    required String selectedSiteId,
  }) {
    final stagedHandoffs =
        _stagedAgentDraftHandoffs.values
            .where(
              (handoff) =>
                  handoff.matchesScope(selectedClientId, selectedSiteId),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    for (final handoff in stagedHandoffs) {
      final reference = handoff.incidentReference.trim();
      if (reference.isNotEmpty) {
        return reference;
      }
    }
    final scopedEvents =
        widget.events
            .where(
              (event) =>
                  _eventClientId(event) == selectedClientId &&
                  _eventSiteId(event) == selectedSiteId,
            )
            .toList(growable: false)
          ..sort((a, b) => b.sequence.compareTo(a.sequence));
    for (final event in scopedEvents) {
      final reference = _eventIncidentReference(event);
      if (reference.isNotEmpty) {
        return reference;
      }
      final eventId = event.eventId.trim();
      if (eventId.isNotEmpty) {
        return eventId;
      }
    }
    return null;
  }

  String _chatThreadStatus({
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
  }) {
    if (pendingAsks > 0) {
      return pendingAsks == 1
          ? '1 draft waiting'
          : '$pendingAsks drafts waiting';
    }
    if (unreadAlerts > 0) {
      return unreadAlerts == 1
          ? '1 unread update'
          : '$unreadAlerts unread updates';
    }
    if (directUpdates > 0) {
      return directUpdates == 1
          ? '1 recent update'
          : '$directUpdates recent updates';
    }
    return 'Quiet for now';
  }

  String _chatListPreview({
    required int pendingDrafts,
    required int alerts,
    required int incidents,
    required bool active,
  }) {
    if (pendingDrafts > 0) {
      return pendingDrafts == 1
          ? 'Draft waiting for approval.'
          : '$pendingDrafts drafts waiting for approval.';
    }
    if (alerts > 0) {
      return alerts == 1
          ? '1 client update needs a reply.'
          : '$alerts client updates need a reply.';
    }
    if (incidents > 0) {
      return incidents == 1
          ? '1 live incident in this thread.'
          : '$incidents live incidents in this thread.';
    }
    return active
        ? 'This is the thread you are working in now.'
        : 'Quiet thread. Tap to switch here.';
  }

  String _chatAvatarLabel(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) {
      return first;
    }
    final second = parts[1].characters.first.toUpperCase();
    return '$first$second';
  }

  Widget _feedRow(_FeedRow row) {
    final rowColor = _feedColor(row.status);
    final canOpenEvent =
        row.eventId != null && widget.onOpenEventsForScope != null;
    final openAgent = widget.onOpenAgentForIncident;
    final normalizedIncidentReference = (row.incidentReference ?? '').trim();
    final canOpenAgent =
        openAgent != null && normalizedIncidentReference.isNotEmpty;
    final redraftWithAgent = row.type == _FeedType.update;
    final agentActionKey = ValueKey(
      redraftWithAgent
          ? 'clients-incident-redraft-agent-${row.eventId ?? normalizedIncidentReference}'
          : 'clients-incident-open-agent-${row.eventId ?? normalizedIncidentReference}',
    );
    final highlightsClientSide = row.type == _FeedType.update;
    final bubbleBackground = highlightsClientSide
        ? const Color(0x1A9D4BFF)
        : const Color(0xFF13131E);
    final bubbleBorder = highlightsClientSide
        ? const Color(0x4D9D4BFF)
        : const Color(0xFFD9E3EE);
    final labelColor = highlightsClientSide
        ? const Color(0xFF315A9A)
        : const Color(0xFF5B708B);
    final surfaceTextColor = highlightsClientSide
        ? const Color(0xFF1E355A)
        : const Color(0xFFE8E8F0);
    return InkWell(
      key: ValueKey('clients-incident-row-${row.title}-${row.timestampLabel}'),
      borderRadius: BorderRadius.circular(9),
      onTap: !canOpenEvent
          ? null
          : () {
              logUiAction(
                'client_app.reopen_selected_incident',
                context: {
                  'role': 'client',
                  'reference_label': row.title,
                  'source': 'clients_incident_feed',
                  'event_id': row.eventId,
                },
              );
              widget.onOpenEventsForScope!.call([row.eventId!], row.eventId);
            },
      child: Container(
        width: double.infinity,
        alignment: highlightsClientSide
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bubbleBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: bubbleBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!highlightsClientSide) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x269D4BFF)),
                    ),
                    child: Icon(_feedIcon(row.type), color: rowColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: highlightsClientSide
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        textAlign: highlightsClientSide
                            ? TextAlign.right
                            : TextAlign.left,
                        style: GoogleFonts.inter(
                          color: surfaceTextColor,
                          fontSize: 12.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.description,
                        textAlign: highlightsClientSide
                            ? TextAlign.right
                            : TextAlign.left,
                        style: GoogleFonts.inter(
                          color: surfaceTextColor.withValues(alpha: 0.78),
                          fontSize: 11.4,
                          fontWeight: FontWeight.w600,
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: highlightsClientSide
                            ? WrapAlignment.end
                            : WrapAlignment.start,
                        children: [
                          Text(
                            row.timestampLabel,
                            style: GoogleFonts.inter(
                              color: labelColor,
                              fontSize: 10.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (canOpenAgent)
                            OutlinedButton.icon(
                              key: agentActionKey,
                              onPressed: () =>
                                  openAgent(normalizedIncidentReference),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF9D4BFF),
                                side: const BorderSide(
                                  color: Color(0x4D9D4BFF),
                                ),
                                backgroundColor: const Color(0xFF1A1A2E),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                redraftWithAgent
                                    ? Icons.auto_fix_high_rounded
                                    : Icons.psychology_alt_rounded,
                                size: 15,
                              ),
                              label: Text(
                                redraftWithAgent
                                    ? 'Redraft with Junior Analyst'
                                    : 'Ask Junior Analyst',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (highlightsClientSide) ...[
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE9FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBED0F1)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mark_chat_read_rounded,
                      color: Color(0xFF9D4BFF),
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomButton(
    String label,
    Color iconColor, {
    required bool enabled,
    String? unreadLabel,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: ValueKey('clients-room-$label'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x269D4BFF)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: enabled
                      ? const Color(0xFFE8E8F0)
                      : const Color(0x80FFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (unreadLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x1AEF4444),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x66EF4444)),
                ),
                child: Text(
                  unreadLabel,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFCC5B67),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0x80FFFFFF),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeLanesSection({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required int pendingAsks,
  }) {
    final currentMetrics = _laneMetrics(
      clientId: currentClient.id,
      siteId: currentSite.id,
    );
    final laneCards =
        <
          ({
            _ClientOption client,
            _SiteOption site,
            bool active,
            int pendingDrafts,
            int alerts,
            int feedCount,
            int incidents,
          })
        >[
          (
            client: currentClient,
            site: currentSite,
            active: true,
            pendingDrafts: pendingAsks,
            alerts: currentMetrics.alerts,
            feedCount: currentMetrics.feedCount,
            incidents: currentMetrics.incidents,
          ),
          for (final client
              in clients
                  .where((client) => client.id != currentClient.id)
                  .take(2))
            () {
              final laneSite = sites.firstWhere(
                (site) => site.clientId == client.id,
                orElse: () => currentSite,
              );
              final metrics = _laneMetrics(
                clientId: client.id,
                siteId: laneSite.id,
              );
              return (
                client: client,
                site: laneSite,
                active: false,
                pendingDrafts: metrics.pendingDrafts,
                alerts: metrics.alerts,
                feedCount: metrics.feedCount,
                incidents: metrics.incidents,
              );
            }(),
        ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client chats',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep the familiar inbox list on the left. Open one thread and stay in it.',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x269D4BFF)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7F93AB),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search or start a chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0x80FFFFFF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < laneCards.length; index++) ...[
            Builder(
              builder: (context) {
                final lane = laneCards[index];
                final preview = _chatListPreview(
                  pendingDrafts: lane.pendingDrafts,
                  alerts: lane.alerts,
                  incidents: lane.incidents,
                  active: lane.active,
                );
                final badgeLabel = lane.pendingDrafts > 0
                    ? '${lane.pendingDrafts}'
                    : lane.alerts > 0
                    ? '${lane.alerts}'
                    : null;
                return InkWell(
                  key: ValueKey(
                    'clients-active-lane-card-${lane.client.id}-${lane.site.id}',
                  ),
                  onTap: () => _selectClientSite(
                    lane.client.id,
                    lane.site.id,
                    source: 'active_lane_card',
                  ),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lane.active
                          ? const Color(0xFF13131E)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: lane.active
                            ? const Color(0x4D9D4BFF)
                            : const Color(0x269D4BFF),
                      ),
                      boxShadow: lane.active
                          ? const [
                              BoxShadow(
                                color: Color(0x120E1726),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: lane.active
                                ? const Color(0xFFE5EEFC)
                                : const Color(0xFFEFF3F8),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _chatAvatarLabel(lane.client.name),
                            style: GoogleFonts.inter(
                              color: const Color(0xFF274770),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lane.client.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFE8E8F0),
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    lane.active ? 'Open' : 'Tap',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF6C82A0),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                lane.site.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF5D728C),
                                  fontSize: 10.6,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF6A7D93),
                                  fontSize: 10.8,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F1FF),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              badgeLabel,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9D4BFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            if (index != laneCards.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _roomThreadContextCard({
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required List<_ClientOption> clients,
    required List<_SiteOption> sites,
    required List<_SiteOption> availableSites,
    required int pendingAsks,
    required String? agentIncidentReference,
    required String? queuedDraftItemId,
  }) {
    final roomRoutingAvailable = widget.onOpenClientRoomForScope != null;
    final openAgent = widget.onOpenAgentForIncident;
    final normalizedAgentIncidentReference = (agentIncidentReference ?? '')
        .trim();
    final normalizedQueuedDraftItemId = (queuedDraftItemId ?? '').trim();
    final canOpenAgent =
        openAgent != null && normalizedAgentIncidentReference.isNotEmpty;
    final canOpenQueuedDraft = normalizedQueuedDraftItemId.isNotEmpty;
    final prefersRedraft = pendingAsks > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat details',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Stay in one thread. Switch the client or room only when you need to.',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 940;
              final selectors = [
                _selectorSurface(
                  label: 'CLIENT',
                  value: _selectedClientId!,
                  items: [
                    for (final client in clients)
                      DropdownMenuItem<String>(
                        value: client.id,
                        child: Text('${client.name} (${client.code})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final nextSites = sites
                        .where((site) => site.clientId == value)
                        .toList(growable: false);
                    if (nextSites.isEmpty) return;
                    _selectClientSite(
                      value,
                      nextSites.first.id,
                      source: 'client_selector',
                    );
                  },
                ),
                _selectorSurface(
                  label: 'SITE',
                  value: _selectedSiteId!,
                  items: [
                    for (final site in availableSites)
                      DropdownMenuItem<String>(
                        value: site.id,
                        child: Text('${site.name} (${site.code})'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _selectClientSite(
                      _selectedClientId!,
                      value,
                      source: 'site_selector',
                    );
                  },
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    selectors[0],
                    const SizedBox(height: 8),
                    selectors[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: selectors[0]),
                  const SizedBox(width: 8),
                  Expanded(child: selectors[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 940;
              final roomId = 'ROOM-${currentSite.code}';
              final threadId = 'THREAD-${currentSite.code}';
              final roomCard = _contextPill(
                label: 'ROOM ID',
                value: '# $roomId',
                accent: const Color(0xFFC084FC),
                mono: true,
              );
              final threadCard = _contextPill(
                label: 'ACTIVE THREAD',
                value: '# $threadId',
                accent: const Color(0xFF22D3EE),
                mono: true,
              );
              if (stacked) {
                return Column(
                  children: [roomCard, const SizedBox(height: 8), threadCard],
                );
              }
              return Row(
                children: [
                  Expanded(child: roomCard),
                  const SizedBox(width: 8),
                  Expanded(child: threadCard),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x269D4BFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This chat is live',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9D4BFF),
                    fontSize: 11.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Replies stay tied to ${currentClient.name}. Use the quick actions only when you need help or want to reopen a queued draft.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6A7D93),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (canOpenAgent) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('clients-thread-open-agent'),
                    onPressed: () =>
                        openAgent(normalizedAgentIncidentReference),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9D4BFF),
                      side: const BorderSide(color: Color(0x4D9D4BFF)),
                      backgroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.6,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: Icon(
                      prefersRedraft
                          ? Icons.auto_fix_high_rounded
                          : Icons.psychology_alt_rounded,
                      size: 15,
                    ),
                    label: Text(
                      prefersRedraft
                          ? 'Redraft with Junior Analyst'
                          : 'Ask Junior Analyst',
                    ),
                  ),
                ],
                if (canOpenQueuedDraft) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const ValueKey('clients-thread-review-queued-draft'),
                    onPressed: () => _openSimpleQueueForDraft(
                      normalizedQueuedDraftItemId,
                      resumeTarget: _DetailedCommsResumeTarget.threadContext,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9D4BFF),
                      side: const BorderSide(color: Color(0x4D9D4BFF)),
                      backgroundColor: const Color(0xFF1A1A2E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      textStyle: GoogleFonts.inter(
                        fontSize: 10.6,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.queue_rounded, size: 15),
                    label: const Text('Open queued draft'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 760;
              final children = [
                _roomButton(
                  'Residents',
                  const Color(0xFF22D3EE),
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Residents'),
                ),
                _roomButton(
                  'Trustees',
                  const Color(0xFFC084FC),
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Trustees'),
                ),
                _roomButton(
                  'Security Desk',
                  const Color(0xFF10B981),
                  enabled: roomRoutingAvailable,
                  onTap: () => _openClientRoom('Security Desk'),
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i != children.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: children[0]),
                  const SizedBox(width: 8),
                  Expanded(child: children[1]),
                  const SizedBox(width: 8),
                  Expanded(child: children[2]),
                ],
              );
            },
          ),
          if (!roomRoutingAvailable && kDebugMode) ...[
            const SizedBox(height: 8),
            Text(
              'Room switching is view-only in this session.',
              style: GoogleFonts.inter(
                color: const Color(0x80FFFFFF),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectorSurface({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF13131E),
              iconEnabledColor: const Color(0x80FFFFFF),
              style: GoogleFonts.inter(
                color: const Color(0xFFE8E8F0),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextPill({
    required String label,
    required String value,
    required Color accent,
    bool mono = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF13131E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: mono
                ? GoogleFonts.robotoMono(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )
                : GoogleFonts.inter(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _communicationChannelsCard({
    required bool telegramBlocked,
    required bool smsFallbackActive,
    required bool voipConfigured,
    required bool voipReady,
    required bool voipStaged,
    required bool pushNeedsReview,
    required bool pushIdle,
    required bool backendProbeHealthy,
    required int pendingAsks,
    required String? agentIncidentReference,
    required String? queuedDraftItemId,
  }) {
    final pushRetryAvailable = widget.onRetryPushSync != null;
    final openAgent = widget.onOpenAgentForIncident;
    final normalizedAgentIncidentReference = (agentIncidentReference ?? '')
        .trim();
    final normalizedQueuedDraftItemId = (queuedDraftItemId ?? '').trim();
    final canOpenAgent =
        openAgent != null &&
        pendingAsks > 0 &&
        normalizedAgentIncidentReference.isNotEmpty;
    final canOpenQueuedDraft = normalizedQueuedDraftItemId.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8E8F0),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'What is ready, what is blocked, and what still needs a nudge.',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _channelChip(
                label: telegramBlocked ? 'Telegram blocked' : 'Telegram ready',
                icon: Icons.check_circle_rounded,
                foreground: telegramBlocked
                    ? const Color(0xFFAF4E57)
                    : const Color(0xFF2D7A5F),
                background: telegramBlocked
                    ? const Color(0xFFFFF2F2)
                    : const Color(0x1A00D4AA),
                border: telegramBlocked
                    ? const Color(0x1AFF3B5C)
                    : const Color(0xFFCFE6DA),
              ),
              _channelChip(
                label: smsFallbackActive ? 'SMS fallback' : 'SMS idle',
                icon: Icons.sms_outlined,
                foreground: smsFallbackActive
                    ? const Color(0xFF9A6A19)
                    : const Color(0xFF6A7D93),
                background: smsFallbackActive
                    ? const Color(0x1AF5A623)
                    : const Color(0xFF13131E),
                border: smsFallbackActive
                    ? const Color(0x4DF5A623)
                    : const Color(0x269D4BFF),
              ),
              _channelChip(
                label: !voipConfigured
                    ? 'VoIP unconfigured'
                    : voipStaged
                    ? 'VoIP staging'
                    : voipReady
                    ? 'VoIP ready'
                    : 'VoIP idle',
                icon: Icons.phone_forwarded_rounded,
                foreground: !voipConfigured
                    ? const Color(0xFF6A7D93)
                    : voipStaged
                    ? const Color(0xFF9A6A19)
                    : voipReady
                    ? const Color(0xFF2D7A5F)
                    : const Color(0xFF6A7D93),
                background: !voipConfigured
                    ? const Color(0xFF13131E)
                    : voipStaged
                    ? const Color(0x1AF5A623)
                    : voipReady
                    ? const Color(0x1A00D4AA)
                    : const Color(0xFF13131E),
                border: !voipConfigured
                    ? const Color(0x269D4BFF)
                    : voipStaged
                    ? const Color(0x4DF5A623)
                    : voipReady
                    ? const Color(0xFFCFE6DA)
                    : const Color(0x269D4BFF),
              ),
              _channelChip(
                label: pushNeedsReview
                    ? 'Push review'
                    : pushIdle
                    ? 'Push idle'
                    : 'Push healthy',
                icon: Icons.notifications_active_outlined,
                foreground: pushNeedsReview
                    ? const Color(0xFF9A6A19)
                    : pushIdle
                    ? const Color(0xFF6A7D93)
                    : const Color(0xFF6A7D93),
                background: pushNeedsReview
                    ? const Color(0x1AF5A623)
                    : pushIdle
                    ? const Color(0xFF13131E)
                    : const Color(0xFF13131E),
                border: pushNeedsReview
                    ? const Color(0x4DF5A623)
                    : pushIdle
                    ? const Color(0x269D4BFF)
                    : const Color(0x269D4BFF),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (voipConfigured && (voipStaged || voipReady))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF13131E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x4DF5A623)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voipReady ? 'VoIP Call Active' : 'VoIP Call Staged',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9A6A19),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    voipReady
                        ? 'Voice call is actively engaging the client escalation path.'
                        : 'Voice call queued for high-priority incident escalation. Ready to dial.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7B6947),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 620;
                      final placeCall = _channelActionButton(
                        key: const ValueKey('clients-place-call-now-action'),
                        label: voipReady
                            ? 'Call In Progress'
                            : 'Place Call Now',
                        accent: const Color(0xFFFBBF24),
                        filled: true,
                        enabled: !voipReady,
                        onTap: voipReady
                            ? null
                            : () {
                                setState(() {
                                  _voipStageStatus = 'dialing';
                                  _backendProbeStatus = 'healthy';
                                  _pushSyncStatus = 'call engaged';
                                });
                                logUiAction(
                                  'clients.place_voip_call',
                                  context: {
                                    'client_id': _selectedClientId,
                                    'site_id': _selectedSiteId,
                                  },
                                );
                              },
                      );
                      final cancelStage = _channelActionButton(
                        key: const ValueKey('clients-cancel-stage-action'),
                        label: voipReady ? 'End Call' : 'Cancel Stage',
                        accent: const Color(0xFF6A7D93),
                        filled: false,
                        onTap: () {
                          setState(() {
                            _voipStageStatus = 'idle';
                            _pushSyncStatus = 'push idle';
                          });
                          logUiAction(
                            'clients.cancel_voip_stage',
                            context: {
                              'client_id': _selectedClientId,
                              'site_id': _selectedSiteId,
                            },
                          );
                        },
                      );
                      if (stacked) {
                        return Column(
                          children: [
                            placeCall,
                            const SizedBox(height: 8),
                            cancelStage,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: placeCall),
                          const SizedBox(width: 8),
                          Expanded(child: cancelStage),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (voipConfigured && (voipStaged || voipReady))
            const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: backendProbeHealthy
                  ? const Color(0x1A00D4AA)
                  : const Color(0xFFFFF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: backendProbeHealthy
                    ? const Color(0xFFCFE6DA)
                    : const Color(0x1AFF3B5C),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery health',
                  style: GoogleFonts.inter(
                    color: backendProbeHealthy
                        ? const Color(0xFF2D7A5F)
                        : const Color(0xFFAF4E57),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  backendProbeHealthy
                      ? 'Healthy • Last probe 5s ago'
                      : 'Backend status is $_backendProbeStatus. Push sync is ${_pushSyncStatus.toLowerCase()}.',
                  style: GoogleFonts.inter(
                    color: backendProbeHealthy
                        ? const Color(0xFF4E816A)
                        : const Color(0xFF8C5C62),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  key: const ValueKey('clients-retry-push-sync-action'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: !pushRetryAvailable ? null : _retryPushSync,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: pushRetryAvailable
                            ? const Color(0x4D9D4BFF)
                            : const Color(0x269D4BFF),
                      ),
                    ),
                    child: Text(
                      pendingAsks > 0
                          ? 'Review draft queue'
                          : 'Retry push sync',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: pushRetryAvailable
                            ? const Color(0xFF9D4BFF)
                            : const Color(0x80FFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (canOpenAgent) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    key: const ValueKey('clients-channel-open-agent'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openAgent(normalizedAgentIncidentReference),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x269D4BFF)),
                      ),
                      child: Text(
                        'Redraft with Junior Analyst',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9D4BFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                if (canOpenQueuedDraft) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    key: const ValueKey('clients-channel-review-queued-draft'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openSimpleQueueForDraft(
                      normalizedQueuedDraftItemId,
                      resumeTarget: _DetailedCommsResumeTarget.channelReview,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13131E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x4D9D4BFF)),
                      ),
                      child: Text(
                        'Open queued draft',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF9D4BFF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  Widget _channelActionButton({
    required Key key,
    required String label,
    required Color accent,
    required bool filled,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: filled
              ? enabled
                    ? const Color(0x1A9D4BFF)
                    : const Color(0xFF1A1A2E)
              : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled
                ? enabled
                      ? const Color(0x4D9D4BFF)
                      : const Color(0x269D4BFF)
                : const Color(0x269D4BFF),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: enabled ? accent : const Color(0x80FFFFFF),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _channelChip({
    required String label,
    required IconData icon,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageHistoryCard(
    List<_FeedRow> rows, {
    required _ClientOption currentClient,
    required _SiteOption currentSite,
    required int pendingAsks,
    required int unreadAlerts,
    required int directUpdates,
  }) {
    final threadStatus = _chatThreadStatus(
      pendingAsks: pendingAsks,
      unreadAlerts: unreadAlerts,
      directUpdates: directUpdates,
    );
    return Container(
      key: _messageHistoryKey,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4ECF9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _chatAvatarLabel(currentClient.name),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF274770),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentClient.name,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFE8E8F0),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${currentSite.name} • $threadStatus',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF667A92),
                        fontSize: 11.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: Text(
              rows.isEmpty ? 'No messages yet' : 'Today',
              style: GoogleFonts.inter(
                color: const Color(0x80FFFFFF),
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF13131E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x269D4BFF)),
              ),
              child: Text(
                'The thread is clear right now. New client messages and drafted replies will land here.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF6A7D93),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            )
          else
            for (int i = 0; i < rows.length; i++) ...[
              _feedRow(rows[i]),
              if (i != rows.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _pendingDraftsCard({
    required int pendingAsks,
    required int activeIncidents,
    required String? reviewEventId,
    required String? agentIncidentReference,
    required String? queuedDraftItemId,
  }) {
    final openAgent = widget.onOpenAgentForIncident;
    final normalizedAgentIncidentReference = (agentIncidentReference ?? '')
        .trim();
    final normalizedQueuedDraftItemId = (queuedDraftItemId ?? '').trim();
    final canOpenAgent =
        openAgent != null &&
        pendingAsks > 0 &&
        normalizedAgentIncidentReference.isNotEmpty;
    final opensQueuedDraft = normalizedQueuedDraftItemId.isNotEmpty;
    return _railCard(
      title: 'Drafts waiting',
      icon: Icons.chat_bubble_outline_rounded,
      accent: const Color(0xFF4C78B8),
      child: Column(
        children: [
          Text(
            '$pendingAsks',
            style: GoogleFonts.inter(
              color: const Color(0xFF9D4BFF),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'Awaiting review',
            style: GoogleFonts.inter(
              color: const Color(0xFF6A7D93),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            key: const ValueKey('clients-review-drafts-action'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _reviewPendingDrafts(
              reviewEventId,
              queuedDraftItemId: normalizedQueuedDraftItemId,
              queuedDraftResumeTarget: _DetailedCommsResumeTarget.pendingDrafts,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF13131E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0x4D9D4BFF)),
              ),
              child: Text(
                opensQueuedDraft ? 'Open queued draft' : 'Review drafts',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF9D4BFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (canOpenAgent) ...[
            const SizedBox(height: 8),
            InkWell(
              key: const ValueKey('clients-review-drafts-open-agent'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => openAgent(normalizedAgentIncidentReference),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x269D4BFF)),
                ),
                child: Text(
                  'Ask Junior Analyst',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9D4BFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF13131E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x269D4BFF)),
            ),
            child: Text(
              '$activeIncidents active thread${activeIncidents == 1 ? '' : 's'}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(0x80FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _learnedStyleCard({
    required String label,
    required String source,
  }) {
    return _railCard(
      title: 'Learned tone',
      icon: Icons.auto_graph_rounded,
      accent: const Color(0xFF4C78B8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x269D4BFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFFE8E8F0),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              source,
              style: GoogleFonts.inter(
                color: const Color(0xFF6A7D93),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pinnedVoiceCard() {
    return _railCard(
      title: 'Reply tone',
      icon: Icons.shield_outlined,
      accent: const Color(0xFF4C78B8),
      child: Column(
        children: [
          _voiceOption('Auto', selected: _selectedPinnedVoice == 'Auto'),
          const SizedBox(height: 8),
          _voiceOption('Concise', selected: _selectedPinnedVoice == 'Concise'),
          const SizedBox(height: 8),
          _voiceOption(
            'Reassuring',
            selected: _selectedPinnedVoice == 'Reassuring',
          ),
          const SizedBox(height: 8),
          _voiceOption('Formal', selected: _selectedPinnedVoice == 'Formal'),
        ],
      ),
    );
  }

  Widget _voiceOption(String label, {bool selected = false}) {
    return InkWell(
      key: ValueKey('clients-pinned-voice-$label'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _selectedPinnedVoice = label);
        logUiAction(
          'clients.select_pinned_voice',
          context: {
            'voice': label,
            'client_id': _selectedClientId,
            'site_id': _selectedSiteId,
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x1A9D4BFF) : const Color(0xFF13131E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0x4D9D4BFF) : const Color(0x269D4BFF),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: selected ? const Color(0xFF9D4BFF) : const Color(0x80FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _railCard({
    required String title,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x269D4BFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8E8F0),
                    fontSize: 11.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  List<ClientCommsQueueItem> _visibleControllerQueueItems() {
    final selectedClientId = (_selectedClientId ?? '').trim();
    final selectedSiteId = (_selectedSiteId ?? '').trim();
    final stagedItems =
        _stagedAgentDraftHandoffs.values
            .where(
              (handoff) =>
                  handoff.matchesScope(selectedClientId, selectedSiteId),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    return <ClientCommsQueueItem>[
          for (final handoff in stagedItems)
            _queueItemFromAgentDraftHandoff(handoff),
          if (widget.usePlaceholderDataWhenEmpty) ..._seedControllerQueueItems(),
        ]
        .where((item) => !_resolvedQueueItemIds.contains(item.id))
        .map(
          (item) => item.copyWith(
            draftMessage: _editedQueueDraftBodies[item.id] ?? item.draftMessage,
          ),
        )
        .toList(growable: false);
  }

  ClientsAgentDraftHandoff? _latestStagedAgentDraftHandoffForScope({
    required String clientId,
    required String siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return null;
    }
    final stagedItems =
        _stagedAgentDraftHandoffs.values
            .where(
              (handoff) =>
                  handoff.matchesScope(normalizedClientId, normalizedSiteId),
            )
            .toList(growable: false)
          ..sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
    if (stagedItems.isEmpty) {
      return null;
    }
    return stagedItems.first;
  }

  int _stagedAgentDraftCountForScope({
    required String clientId,
    required String siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return 0;
    }
    return _stagedAgentDraftHandoffs.values
        .where(
          (handoff) =>
              handoff.matchesScope(normalizedClientId, normalizedSiteId),
        )
        .length;
  }

  List<ClientCommsQueueItem> _seedControllerQueueItems() {
    return const <ClientCommsQueueItem>[
      ClientCommsQueueItem(
        id: 'INC-4430-31',
        clientName: 'Sandton Corp',
        siteName: 'Sandton Estate North',
        incidentLabel: 'INC-4430-31',
        incidentReference: 'INC-4430-31',
        severity: ClientCommsQueueSeverity.high,
        generatedAtLabel: '23:42',
        context: 'Perimeter breach alarm triggered',
        draftMessage:
            'Armed response officer Echo-3 has been dispatched to Sandton Estate North following perimeter breach detection at 23:42. Estimated arrival 4 minutes. Officer will verify scene and provide update.',
      ),
      ClientCommsQueueItem(
        id: 'INC-4430-22',
        clientName: 'Ms Valley',
        siteName: 'Ms Valley Residence',
        incidentLabel: 'INC-4430-22',
        incidentReference: 'INC-4430-22',
        severity: ClientCommsQueueSeverity.medium,
        generatedAtLabel: '23:40',
        context: 'Motion sensor alert - Zone 3',
        draftMessage:
            'We detected unusual activity near the north gate camera feed at 23:38. Our team is reviewing footage and will call you shortly to verify safe-word protocol. No immediate action required.',
      ),
      ClientCommsQueueItem(
        id: 'INC-4430-18',
        clientName: 'Hyde Park Management',
        siteName: 'Hyde Park Complex',
        incidentLabel: 'INC-4430-18',
        incidentReference: 'INC-4430-18',
        severity: ClientCommsQueueSeverity.low,
        generatedAtLabel: '23:35',
        context: 'Routine patrol completion',
        draftMessage:
            'Guard patrol completed at Hyde Park Complex. All zones checked and secured. Next scheduled patrol in 2 hours.',
      ),
    ];
  }

  Future<void> _sendQueueItem(ClientCommsQueueItem item) async {
    final stagedHandoff = _stagedAgentDraftHandoffs[item.id];
    final draftText = (_editedQueueDraftBodies[item.id] ?? item.draftMessage)
        .trim();
    if (stagedHandoff != null && widget.onSendStagedAgentDraftHandoff != null) {
      final sent = await widget.onSendStagedAgentDraftHandoff!(
        stagedHandoff,
        draftText,
      );
      if (!mounted) {
        return;
      }
      if (!sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Telegram reply could not be delivered yet. The draft is still queued.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        );
        return;
      }
    }
    setState(() {
      _resolvedQueueItemIds.add(item.id);
      _stagedAgentDraftHandoffs.remove(item.id);
      _editedQueueDraftBodies.remove(item.id);
      if (_focusedQueueItemId == item.id) {
        _focusedQueueItemId = null;
        _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
      }
    });
    logUiAction(
      'clients.send_pending_message',
      context: {'draft_id': item.id, 'severity': item.severity.name},
    );
    if (mounted && stagedHandoff != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reply sent to the client on Telegram.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
  }

  void _rejectQueueItem(ClientCommsQueueItem item) {
    setState(() {
      _resolvedQueueItemIds.add(item.id);
      _stagedAgentDraftHandoffs.remove(item.id);
      _editedQueueDraftBodies.remove(item.id);
      if (_focusedQueueItemId == item.id) {
        _focusedQueueItemId = null;
        _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
      }
    });
    logUiAction(
      'clients.reject_pending_message',
      context: {'draft_id': item.id, 'severity': item.severity.name},
    );
  }

  void _ingestStagedAgentDraftHandoff(
    ClientsAgentDraftHandoff? handoff, {
    bool useSetState = false,
  }) {
    final normalizedId = handoff?.id.trim() ?? '';
    if (handoff == null || normalizedId.isEmpty) {
      return;
    }
    if (_stagedAgentDraftHandoffs.containsKey(normalizedId)) {
      return;
    }
    void apply() {
      _stagedAgentDraftHandoffs[normalizedId] = handoff;
      _focusedQueueItemId = normalizedId;
      _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
    }

    if (useSetState && mounted) {
      setState(apply);
    } else {
      apply();
    }
    final consume = widget.onConsumeStagedAgentDraftHandoff;
    if (consume != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        consume(normalizedId);
      });
    }
  }

  ClientCommsQueueItem _queueItemFromAgentDraftHandoff(
    ClientsAgentDraftHandoff handoff,
  ) {
    final incidentLabel = handoff.incidentReference.trim().isEmpty
        ? 'AGENT HANDOFF'
        : handoff.incidentReference.trim();
    final clientId = handoff.clientId.trim();
    final siteId = handoff.siteId.trim();
    final roomLabel = handoff.room.trim().isEmpty
        ? 'the scoped client lane'
        : handoff.room.trim();
    return ClientCommsQueueItem(
      id: handoff.id,
      clientName: _humanizeName(clientId, prefix: 'CLIENT-'),
      siteName: _humanizeName(siteId, prefix: 'SITE-'),
      incidentLabel: incidentLabel,
      incidentReference: handoff.incidentReference.trim(),
      severity: handoff.severity,
      generatedAtLabel: _utc(handoff.createdAtUtc),
      context:
          'Agent handoff ready for $roomLabel from ${handoff.sourceRouteLabel}. Review and send from the scoped client thread.',
      draftMessage: handoff.draftText.trim(),
    );
  }

  Future<void> _prepareLatestSentFollowUpReply() async {
    final notice = widget.liveFollowUpNotice;
    final selectedClientId = (_selectedClientId ?? '').trim();
    final selectedSiteId = (_selectedSiteId ?? '').trim();
    if (_preparingLatestSentFollowUpReply) {
      return;
    }
    if (notice == null || selectedClientId.isEmpty || selectedSiteId.isEmpty) {
      _toggleDetailedWorkspace();
      return;
    }
    setState(() {
      _preparingLatestSentFollowUpReply = true;
    });
    try {
      var draftText = notice.suggestedReplyDraft.trim().isEmpty
          ? 'Control is following up now and will confirm here as soon as the next verified update comes in.'
          : notice.suggestedReplyDraft.trim();
      final suggestReply = widget.onSuggestLiveFollowUpReply;
      if (suggestReply != null) {
        final suggestedDraft = await suggestReply(
          notice,
          selectedClientId,
          selectedSiteId,
        );
        if (suggestedDraft.trim().isNotEmpty) {
          draftText = suggestedDraft.trim();
        }
      }
      if (!mounted) {
        return;
      }
      final handoff = ClientsAgentDraftHandoff(
        id: notice.id.trim().isEmpty
            ? 'live-follow-up-${notice.occurredAtUtc.microsecondsSinceEpoch}'
            : notice.id.trim(),
        clientId: selectedClientId,
        siteId: selectedSiteId,
        room: _preferredFollowUpRoom(notice),
        incidentReference: '',
        draftText: draftText,
        originalDraftText: draftText,
        sourceRouteLabel: 'Live Follow-up',
        createdAtUtc: notice.occurredAtUtc,
        severity: notice.urgent
            ? ClientCommsQueueSeverity.high
            : ClientCommsQueueSeverity.medium,
      );
      setState(() {
        _resolvedQueueItemIds.remove(handoff.id);
        _stagedAgentDraftHandoffs[handoff.id] = handoff;
        _editedQueueDraftBodies.remove(handoff.id);
        _focusedQueueItemId = handoff.id;
        _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
        _showDetailedWorkspace = false;
      });
      logUiAction(
        'clients.prepare_live_follow_up_reply',
        context: {
          'client_id': selectedClientId,
          'site_id': selectedSiteId,
          'follow_up_id': handoff.id,
          'urgent': notice.urgent,
        },
      );
      final queueItem = _queueItemFromAgentDraftHandoff(handoff);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_editQueueItem(queueItem));
      });
    } finally {
      if (mounted) {
        setState(() {
          _preparingLatestSentFollowUpReply = false;
        });
      }
    }
  }

  String _preferredFollowUpRoom(ClientsLiveFollowUpNotice notice) {
    final noticeRoom = notice.room.trim();
    if (noticeRoom.isNotEmpty) {
      return noticeRoom;
    }
    final lastOpenedRoom = _lastOpenedRoom.trim();
    if (lastOpenedRoom.isNotEmpty) {
      return lastOpenedRoom;
    }
    final author = notice.author.trim();
    if (_isKnownClientRoom(author)) {
      return author;
    }
    return '';
  }

  bool _isKnownClientRoom(String value) {
    switch (value.trim()) {
      case 'Residents':
      case 'Trustees':
      case 'Security Desk':
        return true;
    }
    return false;
  }

  _ClientSiteModel _withAgentDraftHandoffScopes(_ClientSiteModel model) {
    final clientsById = <String, _ClientOption>{
      for (final client in model.clients) client.id: client,
    };
    final sitesById = <String, _SiteOption>{
      for (final site in model.sites) site.id: site,
    };
    for (final handoff in _stagedAgentDraftHandoffs.values) {
      final clientId = handoff.clientId.trim();
      final siteId = handoff.siteId.trim();
      if (clientId.isNotEmpty && !clientsById.containsKey(clientId)) {
        clientsById[clientId] = _ClientOption(
          id: clientId,
          name: _humanizeName(clientId, prefix: 'CLIENT-'),
          code: clientId,
        );
      }
      if (siteId.isNotEmpty && !sitesById.containsKey(siteId)) {
        sitesById[siteId] = _SiteOption(
          id: siteId,
          name: _humanizeName(siteId, prefix: 'SITE-'),
          code: siteId,
          clientId: clientId.isEmpty ? 'CLIENT-UNKNOWN' : clientId,
        );
      }
    }
    final clients = clientsById.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sites = sitesById.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return _ClientSiteModel(clients: clients, sites: sites);
  }

  _ClientSiteModel _withExplicitRouteScope(_ClientSiteModel model) {
    final normalizedClientId = widget.clientId.trim();
    final normalizedSiteId = widget.siteId.trim();
    if (normalizedClientId.isEmpty && normalizedSiteId.isEmpty) {
      return model;
    }
    final clientsById = <String, _ClientOption>{
      for (final client in model.clients) client.id: client,
    };
    final sitesById = <String, _SiteOption>{
      for (final site in model.sites) site.id: site,
    };
    if (normalizedClientId.isNotEmpty &&
        !clientsById.containsKey(normalizedClientId)) {
      clientsById[normalizedClientId] = _ClientOption(
        id: normalizedClientId,
        name: _humanizeName(normalizedClientId, prefix: 'CLIENT-'),
        code: normalizedClientId,
      );
    }
    if (normalizedSiteId.isNotEmpty && !sitesById.containsKey(normalizedSiteId)) {
      sitesById[normalizedSiteId] = _SiteOption(
        id: normalizedSiteId,
        name: _humanizeName(normalizedSiteId, prefix: 'SITE-'),
        code: normalizedSiteId,
        clientId: normalizedClientId.isEmpty
            ? 'CLIENT-UNKNOWN'
            : normalizedClientId,
      );
    }
    final clients = clientsById.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final sites = sitesById.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    return _ClientSiteModel(clients: clients, sites: sites);
  }

  Future<void> _editQueueItem(ClientCommsQueueItem item) async {
    final controller = TextEditingController(
      text: _editedQueueDraftBodies[item.id] ?? item.draftMessage,
    );
    final handoff = _stagedAgentDraftHandoffs[item.id];
    final aiAssistQueueDraft = widget.onAiAssistQueueDraft;
    final canAiAssist =
        aiAssistQueueDraft != null &&
        handoff != null &&
        handoff.clientId.trim().isNotEmpty &&
        handoff.siteId.trim().isNotEmpty &&
        handoff.room.trim().isNotEmpty;
    var aiAssistBusy = false;
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> runAiAssist() async {
              if (!canAiAssist || aiAssistBusy) {
                return;
              }
              setDialogState(() {
                aiAssistBusy = true;
              });
              try {
                final assistedDraft = await aiAssistQueueDraft(
                  handoff.clientId,
                  handoff.siteId,
                  handoff.room,
                  controller.text.trim(),
                );
                if (!mounted || !dialogContext.mounted) {
                  return;
                }
                final normalizedAssistedDraft = assistedDraft?.trim() ?? '';
                if (normalizedAssistedDraft.isEmpty) {
                  return;
                }
                controller.text = normalizedAssistedDraft;
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    aiAssistBusy = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF13131E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0x269D4BFF)),
              ),
              title: Text(
                'Edit Draft',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE8E8F0),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 560,
                child: TextField(
                  controller: controller,
                  maxLines: 8,
                  minLines: 6,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Refine the outgoing message',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0x80FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0x269D4BFF)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF253548)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF22D3EE)),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
                if (canAiAssist)
                  OutlinedButton(
                    key: const ValueKey('clients-edit-draft-ai-assist'),
                    onPressed: aiAssistBusy ? null : runAiAssist,
                    child: Text(
                      aiAssistBusy ? 'AI ASSISTING...' : 'AI ASSIST',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                    ),
                  ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (!mounted || updated == null || updated.isEmpty) {
      return;
    }
    setState(() {
      _editedQueueDraftBodies[item.id] = updated;
    });
    logUiAction(
      'clients.edit_pending_message',
      context: {'draft_id': item.id, 'severity': item.severity.name},
    );
  }

  void _openClientRoom(String room) {
    final callback = widget.onOpenClientRoomForScope;
    if (callback == null) return;
    logUiAction(
      'clients.open_room',
      context: {
        'room': room,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
      },
    );
    _lastOpenedRoom = room;
    callback(room, _selectedClientId!, _selectedSiteId!);
  }

  Future<void> _retryPushSync() async {
    final callback = widget.onRetryPushSync;
    if (callback == null) return;
    setState(() {
      _pushRetryCount += 1;
      _pushSyncStatus = 'retry in flight';
      _backendProbeStatus = 'healthy';
    });
    logUiAction(
      'clients.retry_push_sync',
      context: {
        'retries': _pushRetryCount,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
      },
    );
    try {
      await callback();
    } finally {
      if (mounted) {
        setState(() {
          _pushSyncStatus = 'push idle';
        });
      }
    }
  }

  void _scheduleSelectionReconcile({
    required String clientId,
    required String siteId,
  }) {
    if ((_selectedClientId == clientId && _selectedSiteId == siteId) ||
        _selectionReconcileScheduled) {
      return;
    }
    _selectionReconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionReconcileScheduled = false;
      if (!mounted) {
        return;
      }
      if (_selectedClientId == clientId && _selectedSiteId == siteId) {
        return;
      }
      setState(() {
        _selectedClientId = clientId;
        _selectedSiteId = siteId;
      });
    });
  }

  ({String label, String source})? _learnedStyleSummaryForScope({
    required String clientId,
    required String siteId,
  }) {
    final normalizedClientId = clientId.trim();
    final normalizedSiteId = siteId.trim();
    if (normalizedClientId.isEmpty || normalizedSiteId.isEmpty) {
      return null;
    }
    return null;
  }

  void _acknowledgeEvidenceReturnReceipt() {
    if (_activeEvidenceReturnReceipt == null) {
      return;
    }
    setState(() {
      _activeEvidenceReturnReceipt = null;
    });
  }

  void _selectClientSite(
    String clientId,
    String siteId, {
    required String source,
  }) {
    if (_selectedClientId == clientId && _selectedSiteId == siteId) {
      return;
    }
    setState(() {
      _selectedClientId = clientId;
      _selectedSiteId = siteId;
      _focusedQueueItemId = null;
      _focusedQueueResumeTarget = _DetailedCommsResumeTarget.pendingDrafts;
    });
    logUiAction(
      'clients.select_lane',
      context: {'client_id': clientId, 'site_id': siteId, 'source': source},
    );
  }

  ({int pendingDrafts, int alerts, int feedCount, int incidents}) _laneMetrics({
    required String clientId,
    required String siteId,
  }) {
    var rows = _incidentFeedRows(
      events: widget.events,
      selectedClientId: clientId,
      selectedSiteId: siteId,
    );
    if (rows.isEmpty &&
        widget.usePlaceholderDataWhenEmpty &&
        clientId == _selectedClientId &&
        siteId == _selectedSiteId) {
      rows = _fallbackFeed;
    }
    return (
      pendingDrafts:
          rows.where((row) => row.type == _FeedType.update).length +
          _stagedAgentDraftCountForScope(clientId: clientId, siteId: siteId),
      alerts: rows.where((row) => row.status != _FeedStatus.info).length,
      feedCount: rows.length,
      incidents: widget.events
          .whereType<DecisionCreated>()
          .where(
            (event) => event.clientId == clientId && event.siteId == siteId,
          )
          .length,
    );
  }

  void _reviewPendingDrafts(
    String? reviewEventId, {
    String? queuedDraftItemId,
    _DetailedCommsResumeTarget queuedDraftResumeTarget =
        _DetailedCommsResumeTarget.pendingDrafts,
  }) {
    final normalizedQueuedDraftItemId = (queuedDraftItemId ?? '').trim();
    if (normalizedQueuedDraftItemId.isNotEmpty) {
      logUiAction(
        'clients.review_pending_drafts',
        context: {
          'client_id': _selectedClientId,
          'site_id': _selectedSiteId,
          'source': 'queued_agent_draft',
          'draft_id': normalizedQueuedDraftItemId,
          'resume_target': _detailedCommsResumeTargetValue(
            queuedDraftResumeTarget,
          ),
        },
      );
      _openSimpleQueueForDraft(
        normalizedQueuedDraftItemId,
        resumeTarget: queuedDraftResumeTarget,
      );
      return;
    }
    if (reviewEventId != null && widget.onOpenEventsForScope != null) {
      logUiAction(
        'clients.review_pending_drafts',
        context: {
          'event_id': reviewEventId,
          'client_id': _selectedClientId,
          'site_id': _selectedSiteId,
        },
      );
      widget.onOpenEventsForScope!.call(<String>[reviewEventId], reviewEventId);
      return;
    }
    final selectedClientId = (_selectedClientId ?? '').trim();
    final selectedSiteId = (_selectedSiteId ?? '').trim();
    final stagedDraftCount = _stagedAgentDraftCountForScope(
      clientId: selectedClientId,
      siteId: selectedSiteId,
    );
    if (_showDetailedWorkspace && stagedDraftCount > 0) {
      final latestStagedDraft = _latestStagedAgentDraftHandoffForScope(
        clientId: selectedClientId,
        siteId: selectedSiteId,
      );
      if (latestStagedDraft != null) {
        logUiAction(
          'clients.review_pending_drafts',
          context: {
            'client_id': selectedClientId,
            'site_id': selectedSiteId,
            'source': 'staged_agent_queue',
            'draft_count': stagedDraftCount,
            'draft_id': latestStagedDraft.id,
            'resume_target': _detailedCommsResumeTargetValue(
              _DetailedCommsResumeTarget.pendingDrafts,
            ),
          },
        );
        _openSimpleQueueForDraft(
          latestStagedDraft.id,
          resumeTarget: _DetailedCommsResumeTarget.pendingDrafts,
        );
        return;
      }
      logUiAction(
        'clients.review_pending_drafts',
        context: {
          'client_id': selectedClientId,
          'site_id': selectedSiteId,
          'source': 'staged_agent_queue',
          'draft_count': stagedDraftCount,
        },
      );
      _toggleDetailedWorkspace();
      return;
    }
    _scrollToMessageHistory();
  }

  String get _focusedQueueResumeActionLabel {
    return switch (_focusedQueueResumeTarget) {
      _DetailedCommsResumeTarget.pendingDrafts => 'RESUME DRAFT RAIL',
      _DetailedCommsResumeTarget.threadContext => 'RESUME THREAD CONTEXT',
      _DetailedCommsResumeTarget.channelReview => 'RESUME CHANNEL REVIEW',
    };
  }

  String _detailedCommsResumeTargetValue(_DetailedCommsResumeTarget target) {
    return switch (target) {
      _DetailedCommsResumeTarget.pendingDrafts => 'pending_drafts',
      _DetailedCommsResumeTarget.threadContext => 'thread_context',
      _DetailedCommsResumeTarget.channelReview => 'channel_review',
    };
  }

  void _openSimpleQueueForDraft(
    String queueItemId, {
    _DetailedCommsResumeTarget resumeTarget =
        _DetailedCommsResumeTarget.pendingDrafts,
  }) {
    final normalizedQueueItemId = queueItemId.trim();
    if (normalizedQueueItemId.isEmpty) {
      return;
    }
    setState(() {
      _showDetailedWorkspace = false;
      _focusedQueueItemId = normalizedQueueItemId;
      _focusedQueueResumeTarget = resumeTarget;
    });
    logUiAction(
      'clients.toggle_detailed_workspace',
      context: {
        'open': false,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
        'source': 'focused_queue_draft',
        'draft_id': normalizedQueueItemId,
        'resume_target': _detailedCommsResumeTargetValue(resumeTarget),
      },
    );
  }

  void _resumeDetailedWorkspaceForQueueItem(ClientCommsQueueItem item) {
    final normalizedQueueItemId = item.id.trim();
    if (normalizedQueueItemId.isEmpty) {
      _toggleDetailedWorkspace();
      return;
    }
    final resumeTarget = _focusedQueueResumeTarget;
    setState(() {
      _showDetailedWorkspace = true;
      _focusedQueueItemId = normalizedQueueItemId;
    });
    logUiAction(
      'clients.toggle_detailed_workspace',
      context: {
        'open': true,
        'client_id': _selectedClientId,
        'site_id': _selectedSiteId,
        'source': 'resume_detailed_comms',
        'draft_id': normalizedQueueItemId,
        'resume_target': _detailedCommsResumeTargetValue(resumeTarget),
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scrollToDetailedCommsResumeTarget(resumeTarget);
    });
  }

  void _scrollToMessageHistory() {
    final context = _messageHistoryKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _scrollToDetailedCommsResumeTarget(_DetailedCommsResumeTarget target) {
    final targetContext = switch (target) {
      _DetailedCommsResumeTarget.pendingDrafts =>
        _pendingDraftsCardKey.currentContext,
      _DetailedCommsResumeTarget.threadContext =>
        _roomThreadContextCardKey.currentContext,
      _DetailedCommsResumeTarget.channelReview =>
        _communicationChannelsCardKey.currentContext,
    };
    if (targetContext == null) {
      return;
    }
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }
}

enum _FeedType { dispatch, arrival, update, resolution }

enum _FeedStatus { info, success, warning }

class _FeedRow {
  final _FeedType type;
  final _FeedStatus status;
  final String title;
  final String description;
  final String timestampLabel;
  final String? eventId;
  final String? incidentReference;

  const _FeedRow({
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.timestampLabel,
    this.eventId,
    this.incidentReference,
  });
}

enum _DetailedCommsResumeTarget { pendingDrafts, threadContext, channelReview }

class _ClientOption {
  final String id;
  final String name;
  final String code;

  const _ClientOption({
    required this.id,
    required this.name,
    required this.code,
  });
}

class _SiteOption {
  final String id;
  final String name;
  final String code;
  final String clientId;

  const _SiteOption({
    required this.id,
    required this.name,
    required this.code,
    required this.clientId,
  });
}

class _ClientSiteModel {
  final List<_ClientOption> clients;
  final List<_SiteOption> sites;

  const _ClientSiteModel({required this.clients, required this.sites});
}

const List<_ClientOption> _fallbackClients = [
  _ClientOption(
    id: 'CLIENT-001',
    name: 'Northern Residential Portfolio',
    code: 'NRP-OPS',
  ),
  _ClientOption(
    id: 'CLIENT-002',
    name: 'Blue Ridge Operations',
    code: 'BLR-OPS',
  ),
  _ClientOption(
    id: 'CLIENT-003',
    name: 'Centurion Commerce Campus',
    code: 'CNT-CAMP',
  ),
];

const List<_SiteOption> _fallbackSites = [
  _SiteOption(
    id: 'SITE-SANDTON',
    name: 'North Residential Cluster',
    code: 'SITE-SANDTON',
    clientId: 'CLIENT-001',
  ),
  _SiteOption(
    id: 'SITE-WTF-MAIN',
    name: 'Central Access Gate',
    code: 'SITE-WTF-MAIN',
    clientId: 'CLIENT-001',
  ),
  _SiteOption(
    id: 'SITE-BLR',
    name: 'Blue Ridge Response Hub',
    code: 'SITE-BLR',
    clientId: 'CLIENT-002',
  ),
];

const List<_FeedRow> _fallbackFeed = [
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-4 and is checking the site.',
    timestampLabel: '19:47 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-4 opened for the North Residential Cluster.',
    timestampLabel: '19:38 UTC',
  ),
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-3 and is checking the site.',
    timestampLabel: '18:53 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-3 opened for the North Residential Cluster.',
    timestampLabel: '18:38 UTC',
  ),
  _FeedRow(
    type: _FeedType.arrival,
    status: _FeedStatus.success,
    title: 'Responder On Site',
    description: 'Response unit arrived for DSP-2 and is checking the site.',
    timestampLabel: '17:47 UTC',
  ),
  _FeedRow(
    type: _FeedType.dispatch,
    status: _FeedStatus.info,
    title: 'Dispatch Activated',
    description: 'DSP-2 opened for the North Residential Cluster.',
    timestampLabel: '17:38 UTC',
  ),
];

_ClientSiteModel _deriveClientSiteModel(List<DispatchEvent> events) {
  final clientsById = <String, _ClientOption>{};
  final sitesById = <String, _SiteOption>{};

  for (final event in events) {
    final clientId = _eventClientId(event);
    final siteId = _eventSiteId(event);
    if (clientId.isNotEmpty && !clientsById.containsKey(clientId)) {
      clientsById[clientId] = _ClientOption(
        id: clientId,
        name: _humanizeName(clientId, prefix: 'CLIENT-'),
        code: clientId,
      );
    }
    if (siteId.isNotEmpty && !sitesById.containsKey(siteId)) {
      sitesById[siteId] = _SiteOption(
        id: siteId,
        name: _humanizeName(siteId, prefix: 'SITE-'),
        code: siteId,
        clientId: clientId.isEmpty ? 'CLIENT-UNKNOWN' : clientId,
      );
    }
  }

  final clients = clientsById.values.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  final sites = sitesById.values.toList(growable: false)
    ..sort((a, b) => a.id.compareTo(b.id));
  return _ClientSiteModel(clients: clients, sites: sites);
}

List<_FeedRow> _incidentFeedRows({
  required List<DispatchEvent> events,
  required String selectedClientId,
  required String selectedSiteId,
}) {
  final rows = <_FeedRow>[];
  final scoped =
      events
          .where(
            (event) =>
                _eventClientId(event) == selectedClientId &&
                _eventSiteId(event) == selectedSiteId,
          )
          .toList(growable: false)
        ..sort((a, b) => b.sequence.compareTo(a.sequence));

  for (final event in scoped) {
    if (event is ResponseArrived) {
      rows.add(
        _FeedRow(
          type: _FeedType.arrival,
          status: _FeedStatus.success,
          title: 'Officer Arrived',
          description: '${event.guardId} arrived for ${event.dispatchId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
          incidentReference: _eventIncidentReference(event),
        ),
      );
      continue;
    }
    if (event is DecisionCreated) {
      rows.add(
        _FeedRow(
          type: _FeedType.dispatch,
          status: _FeedStatus.info,
          title: 'Dispatch Created',
          description: '${event.dispatchId} opened for ${event.siteId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
          incidentReference: _eventIncidentReference(event),
        ),
      );
      continue;
    }
    if (event is IntelligenceReceived) {
      rows.add(
        _FeedRow(
          type: _FeedType.update,
          status: _FeedStatus.warning,
          title: 'Client Advisory',
          description: event.headline,
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
          incidentReference: _eventIncidentReference(event),
        ),
      );
      continue;
    }
    if (event is IncidentClosed) {
      rows.add(
        _FeedRow(
          type: _FeedType.resolution,
          status: _FeedStatus.success,
          title: 'Incident Resolved',
          description: '${event.dispatchId} closed for ${event.siteId}.',
          timestampLabel: _utc(event.occurredAt),
          eventId: event.eventId,
          incidentReference: _eventIncidentReference(event),
        ),
      );
      continue;
    }
  }

  return rows;
}

String _eventIncidentReference(DispatchEvent event) {
  if (event is IntelligenceReceived) return event.intelligenceId.trim();
  if (event is DecisionCreated) return event.dispatchId.trim();
  if (event is ResponseArrived) return event.dispatchId.trim();
  if (event is IncidentClosed) return event.dispatchId.trim();
  return '';
}

String _eventClientId(DispatchEvent event) {
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  return '';
}

String _eventSiteId(DispatchEvent event) {
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  return '';
}

String _humanizeName(String raw, {required String prefix}) {
  final stripped = raw.replaceFirst(prefix, '');
  final words = stripped
      .replaceAll('_', '-')
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .toList(growable: false);
  if (words.isEmpty) return raw;
  return words.join(' ');
}

String _utc(DateTime value) {
  final utc = value.toUtc();
  final hh = utc.hour.toString().padLeft(2, '0');
  final mm = utc.minute.toString().padLeft(2, '0');
  return '$hh:$mm UTC';
}

IconData _feedIcon(_FeedType type) {
  switch (type) {
    case _FeedType.dispatch:
      return Icons.shield_outlined;
    case _FeedType.arrival:
      return Icons.check_circle_outline_rounded;
    case _FeedType.update:
      return Icons.warning_amber_rounded;
    case _FeedType.resolution:
      return Icons.task_alt_rounded;
  }
}

Color _feedColor(_FeedStatus status) {
  switch (status) {
    case _FeedStatus.info:
      return const Color(0xFF22D3EE);
    case _FeedStatus.success:
      return const Color(0xFF10B981);
    case _FeedStatus.warning:
      return const Color(0xFFF59E0B);
  }
}
