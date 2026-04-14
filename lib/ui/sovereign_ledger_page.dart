import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../application/evidence_certificate_export_service.dart';
import '../application/monitoring_scene_review_store.dart';
import '../domain/events/decision_created.dart';
import '../domain/events/dispatch_event.dart';
import '../domain/events/execution_completed.dart';
import '../domain/events/execution_denied.dart';
import '../domain/events/guard_checked_in.dart';
import '../domain/events/incident_closed.dart';
import '../domain/events/intelligence_received.dart';
import '../domain/events/partner_dispatch_status_declared.dart';
import '../domain/events/patrol_completed.dart';
import '../domain/events/report_generated.dart';
import '../domain/events/response_arrived.dart';
import '../domain/events/vehicle_visit_review_recorded.dart';
import 'onyx_surface.dart';
import 'theme/onyx_design_tokens.dart';

const _obSurfaceFill = Color(0xFF13131E);
const _obSurfaceElevated = Color(0xFF1A1A2E);
const _obSurfaceSoft = Color(0xFF1A1A2E);
const _obInputFill = Color(0xFF0D0D14);
const _obBorder = Color(0x269D4BFF);
const _obBorderStrong = Color(0x4D9D4BFF);
const _obTextPrimary = Color(0xFFE8E8F0);
const _obTextSecondary = Color(0x80FFFFFF);
const _obTextMuted = Color(0x4DFFFFFF);
const _obBlueAccent = Color(0xFF9D4BFF);
const _obBlueAccentStrong = Color(0xFF9D4BFF);
const _obButtonFill = Color(0xFF9D4BFF);

class SovereignLedgerPinnedAuditEntry {
  final String auditId;
  final String clientId;
  final String siteId;
  final String recordCode;
  final String title;
  final String description;
  final DateTime occurredAt;
  final String actorLabel;
  final String sourceLabel;
  final String hash;
  final String previousHash;
  final Color accent;
  final Map<String, Object?> payload;

  const SovereignLedgerPinnedAuditEntry({
    required this.auditId,
    required this.clientId,
    required this.siteId,
    required this.recordCode,
    required this.title,
    required this.description,
    required this.occurredAt,
    required this.actorLabel,
    required this.sourceLabel,
    required this.hash,
    required this.previousHash,
    required this.accent,
    required this.payload,
  });
}

class DispatchAuditOpenRequest {
  final String incidentReference;
  final String auditId;
  final String payloadType;
  final String action;
  final String? dispatchId;

  const DispatchAuditOpenRequest({
    required this.incidentReference,
    required this.auditId,
    required this.payloadType,
    required this.action,
    this.dispatchId,
  });
}

class SovereignLedgerPage extends StatefulWidget {
  final String clientId;
  final String? initialScopeClientId;
  final String? initialScopeSiteId;
  final List<DispatchEvent> events;
  final String initialFocusReference;
  final Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId;
  final void Function(List<String> eventIds, String? selectedEventId)?
  onOpenEventsForScope;
  final SovereignLedgerPinnedAuditEntry? pinnedAuditEntry;
  final VoidCallback? onReturnToWarRoom;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenDispatchForIncident;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenReportForDispatchAudit;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenClientForIncident;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenAgentForIncident;
  final ValueChanged<DispatchAuditOpenRequest>?
  onOpenOperationsAgentForIncident;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenCctvForIncident;
  final ValueChanged<DispatchAuditOpenRequest>? onOpenTrackForIncident;
  final VoidCallback? onOpenManualIntelFromAudit;
  final VoidCallback? onOpenVipPackageFromAudit;
  final VoidCallback? onOpenRosterPlannerFromAudit;
  final VoidCallback? onOpenSitesActionFromAudit;

  const SovereignLedgerPage({
    super.key,
    required this.clientId,
    this.initialScopeClientId,
    this.initialScopeSiteId,
    required this.events,
    this.initialFocusReference = '',
    this.sceneReviewByIntelligenceId = const {},
    this.onOpenEventsForScope,
    this.pinnedAuditEntry,
    this.onReturnToWarRoom,
    this.onOpenDispatchForIncident,
    this.onOpenReportForDispatchAudit,
    this.onOpenClientForIncident,
    this.onOpenAgentForIncident,
    this.onOpenOperationsAgentForIncident,
    this.onOpenCctvForIncident,
    this.onOpenTrackForIncident,
    this.onOpenManualIntelFromAudit,
    this.onOpenVipPackageFromAudit,
    this.onOpenRosterPlannerFromAudit,
    this.onOpenSitesActionFromAudit,
  });

  @override
  State<SovereignLedgerPage> createState() => _SovereignLedgerPageState();
}

class _SovereignLedgerPageState extends State<SovereignLedgerPage> {
  static const _defaultCommandReceipt = _ObCommandReceipt(
    label: 'AUTO-AUDIT READY',
    message: 'Pick one record. Check it fast. Move.',
    detail:
        'Every shift action stays signed in the background so the controller only works from the record that matters now.',
    accent: Color(0xFF19B4E5),
  );

  late final TextEditingController _searchController;
  late final TextEditingController _guardNameController;
  late final TextEditingController _callsignController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  final List<_ObEntryView> _manualEntries = <_ObEntryView>[];

  String _searchQuery = '';
  String? _selectedEntryId;
  String _draftPresetKey = '';
  String _draftSite = '';
  DateTime _draftOccurredAt = DateTime.now().toUtc();
  bool _draftFlagged = false;
  bool _composerOpen = false;
  bool _desktopWorkspaceActive = false;
  _ObCategory _categoryFilter = _ObCategory.all;
  _ObCategory _draftCategory = _ObCategory.patrol;
  _ObWorkspaceView _workspaceView = _ObWorkspaceView.record;
  _ChainIntegrity _integrity = _ChainIntegrity.pending;
  _ObCommandReceipt _commandReceipt = _defaultCommandReceipt;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _guardNameController = TextEditingController();
    _callsignController = TextEditingController();
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();
    _resetDraft();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _guardNameController.dispose();
    _callsignController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scopeClientId = (widget.initialScopeClientId ?? '').trim();
    final scopeSiteId = (widget.initialScopeSiteId ?? '').trim();
    final focusReference = widget.initialFocusReference.trim();
    final generatedEntries = _buildObEntries(
      widget.events,
      clientId: scopeClientId.isEmpty ? widget.clientId : scopeClientId,
      siteId: scopeSiteId,
      sceneReviewByIntelligenceId: widget.sceneReviewByIntelligenceId,
    );
    final baseEntries = generatedEntries.isEmpty
        ? _fallbackEntries
        : generatedEntries;
    final pinnedAuditEntry = widget.pinnedAuditEntry == null
        ? null
        : _pinnedAuditEntryToView(widget.pinnedAuditEntry!);
    final allEntries = <_ObEntryView>[
      ..._presentEntries(pinnedAuditEntry),
      ..._manualEntries,
      ...baseEntries,
    ]..sort(_sortEntriesDescending);
    final guardPresets = _buildGuardPresets(allEntries);
    final siteOptions = _buildSiteOptions(allEntries);
    final filteredEntries = allEntries
        .where(
          (entry) =>
              _matchesCategory(entry, _categoryFilter) &&
              _matchesSearch(entry, _searchQuery),
        )
        .toList(growable: false);
    final selectedPool = filteredEntries.isNotEmpty
        ? filteredEntries
        : allEntries;
    _selectedEntryId = _resolveSelectedEntryId(
      entries: selectedPool,
      currentId: _selectedEntryId,
      focusReference: focusReference,
    );
    final selected = selectedPool.firstWhere(
      (entry) => entry.id == _selectedEntryId,
      orElse: () => selectedPool.first,
    );
    final relatedEntries = _relatedEntriesForSelected(allEntries, selected);
    final hasScopeFocus = scopeClientId.isNotEmpty && scopeSiteId.isNotEmpty;
    final totalEntries = allEntries.length;
    final todayEntries = allEntries
        .where(
          (entry) => _isSameUtcDate(entry.occurredAt, DateTime.now().toUtc()),
        )
        .length;
    final incidentEntries = allEntries.where((entry) => entry.incident).length;
    final flaggedEntries = allEntries.where((entry) => entry.flagged).length;

    return OnyxPageScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dualColumnLayout = constraints.maxWidth >= 1100;
          final maxWidth = constraints.maxWidth >= 1760
              ? 1660.0
              : constraints.maxWidth * 0.975;
          _desktopWorkspaceActive = dualColumnLayout;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth >= 900 ? 18 : 12,
                  14,
                  constraints.maxWidth >= 900 ? 18 : 12,
                  18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroPanel(
                      context: context,
                      selected: selected,
                      totalEntries: totalEntries,
                      todayEntries: todayEntries,
                      incidentEntries: incidentEntries,
                      flaggedEntries: flaggedEntries,
                      hasScopeFocus: hasScopeFocus,
                      scopeClientId: scopeClientId,
                      scopeSiteId: scopeSiteId,
                      focusReference: focusReference,
                      guardPresets: guardPresets,
                    ),
                    if (_composerOpen) ...[
                      const SizedBox(height: 14),
                      _buildComposerPanel(
                        context: context,
                        guardPresets: guardPresets,
                        siteOptions: siteOptions,
                        currentEntries: allEntries,
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (dualColumnLayout)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildEntriesPanel(
                              entries: filteredEntries,
                              selected: selected,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 5,
                            child: _buildDetailPanel(
                              context: context,
                              entries: allEntries,
                              selected: selected,
                              relatedEntries: relatedEntries,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildEntriesPanel(
                        entries: filteredEntries,
                        selected: selected,
                      ),
                      const SizedBox(height: 14),
                      _buildDetailPanel(
                        context: context,
                        entries: allEntries,
                        selected: selected,
                        relatedEntries: relatedEntries,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroPanel({
    required BuildContext context,
    required _ObEntryView selected,
    required int totalEntries,
    required int todayEntries,
    required int incidentEntries,
    required int flaggedEntries,
    required bool hasScopeFocus,
    required String scopeClientId,
    required String scopeSiteId,
    required String focusReference,
    required List<_GuardPreset> guardPresets,
  }) {
    final heroBannerChildren = <Widget>[
      _buildHeroStatusChip(label: _integrity.label, color: _integrity.color),
      if (focusReference.isNotEmpty)
        _buildContextChip(
          label: 'Focus: $focusReference',
          color: const Color(0xFF6A63FF),
        ),
      if (hasScopeFocus)
        Container(
          key: const ValueKey('ledger-scope-banner'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _obSurfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _obBorder),
          ),
          child: Text(
            '${_displayClientLabel(scopeClientId)} / ${_displaySiteLabel(scopeSiteId)}',
            style: GoogleFonts.inter(
              color: _obBlueAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];

    return _surfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnyxStoryHero(
            eyebrow: 'Command',
            title: 'Sovereign Ledger',
            subtitle:
                'One clean record, one clear next move, full chain in the background.',
            icon: Icons.menu_book_rounded,
            gradientColors: const [Color(0xFF13131E), Color(0xFF1A1A2E)],
            metrics: [
              OnyxStoryMetric(
                value: selected.recordCode,
                label: 'focus',
                foreground: const Color(0xFF2F6AA3),
                background: const Color(0x142F6AA3),
                border: const Color(0x332F6AA3),
              ),
              OnyxStoryMetric(
                value: '$todayEntries',
                label: 'today',
                foreground: const Color(0xFF5B5CE2),
                background: const Color(0x145B5CE2),
                border: const Color(0x335B5CE2),
              ),
              OnyxStoryMetric(
                value: '$incidentEntries',
                label: 'incident',
                foreground: const Color(0xFFF87171),
                background: const Color(0x1AF87171),
                border: const Color(0x66F87171),
              ),
              OnyxStoryMetric(
                value: '$flaggedEntries',
                label: 'flagged',
                foreground: flaggedEntries > 0
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFF9AB1CF),
                background: flaggedEntries > 0
                    ? const Color(0x1AF59E0B)
                    : const Color(0x1494A3B8),
                border: flaggedEntries > 0
                    ? const Color(0x66F59E0B)
                    : const Color(0x6694A3B8),
              ),
              OnyxStoryMetric(
                value: '$totalEntries',
                label: 'entries',
                foreground: _obTextPrimary,
                background: const Color(0xFF13131E),
                border: _obBorder,
              ),
            ],
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('ledger-hero-view-events-button'),
                onPressed:
                    selected.linkedEventIds.isEmpty ||
                        widget.onOpenEventsForScope == null
                    ? null
                    : () => _openSelectedEvents(
                        selected,
                        label: 'OPEN EVENTS SCOPE',
                      ),
                style: _secondaryButtonStyle(),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('OPEN EVENTS SCOPE'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('ledger-hero-verify-button'),
                onPressed: () => _runIntegrityCheck(
                  _manualEntries.isNotEmpty
                      ? <_ObEntryView>[..._manualEntries, selected]
                      : <_ObEntryView>[selected],
                ),
                style: _secondaryButtonStyle(),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Check Chain'),
              ),
              FilledButton.icon(
                key: const ValueKey('ledger-open-composer'),
                onPressed: () => _openComposer(guardPresets),
                style: _primaryButtonStyle(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Entry Now'),
              ),
            ],
            banner: heroBannerChildren.isEmpty
                ? null
                : Wrap(spacing: 8, runSpacing: 8, children: heroBannerChildren),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: _obInputFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _obBorder),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              style: GoogleFonts.inter(
                color: _obTextPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search entries...',
                hintStyle: GoogleFonts.inter(
                  color: _obTextMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _obTextMuted,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _ObCategory.values
                .map(
                  (category) => _buildFilterChip(
                    category: category,
                    selected: _categoryFilter == category,
                    onTap: () {
                      setState(() {
                        _categoryFilter = category;
                        if (!_composerOpen) {
                          return;
                        }
                        if (category != _ObCategory.all) {
                          _draftCategory = category;
                        }
                      });
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerPanel({
    required BuildContext context,
    required List<_GuardPreset> guardPresets,
    required List<String> siteOptions,
    required List<_ObEntryView> currentEntries,
  }) {
    final activePreset = _resolvePresetByKey(guardPresets, _draftPresetKey);
    final selectedSite = siteOptions.contains(_draftSite)
        ? _draftSite
        : siteOptions.first;
    final twoColumn = MediaQuery.sizeOf(context).width >= 1100;

    return _surfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add Entry Now',
                style: GoogleFonts.inter(
                  color: _obTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                _formatUtcTimestamp(_draftOccurredAt),
                style: GoogleFonts.inter(
                  color: _obTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (twoColumn)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Guard (quick select)',
                    value: activePreset.key,
                    items: guardPresets
                        .map(
                          (preset) => DropdownMenuItem<String>(
                            value: preset.key,
                            child: Text(
                              '${preset.callsign} - ${preset.guardName}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final preset = _resolvePresetByKey(guardPresets, value);
                      setState(() => _applyGuardPreset(preset));
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildDropdownField(
                    label: 'Site',
                    value: selectedSite,
                    items: siteOptions
                        .map(
                          (site) => DropdownMenuItem<String>(
                            value: site,
                            child: Text(site),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _draftSite = value);
                    },
                  ),
                ),
              ],
            )
          else ...[
            _buildDropdownField(
              label: 'Guard (quick select)',
              value: activePreset.key,
              items: guardPresets
                  .map(
                    (preset) => DropdownMenuItem<String>(
                      value: preset.key,
                      child: Text('${preset.callsign} - ${preset.guardName}'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                final preset = _resolvePresetByKey(guardPresets, value);
                setState(() => _applyGuardPreset(preset));
              },
            ),
            const SizedBox(height: 14),
            _buildDropdownField(
              label: 'Site',
              value: selectedSite,
              items: siteOptions
                  .map(
                    (site) => DropdownMenuItem<String>(
                      value: site,
                      child: Text(site),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _draftSite = value);
              },
            ),
          ],
          const SizedBox(height: 14),
          if (twoColumn)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _guardNameController,
                    label: 'Guard Name',
                    hintText: 'Full name',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTextField(
                    controller: _callsignController,
                    label: 'Callsign',
                    hintText: 'e.g. Echo-3',
                  ),
                ),
              ],
            )
          else ...[
            _buildTextField(
              controller: _guardNameController,
              label: 'Guard Name',
              hintText: 'Full name',
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _callsignController,
              label: 'Callsign',
              hintText: 'e.g. Echo-3',
            ),
          ],
          const SizedBox(height: 14),
          if (twoColumn)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: 'Category',
                    value: _draftCategory.storageKey,
                    items: _ObCategory.values
                        .where((category) => category != _ObCategory.all)
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.storageKey,
                            child: Text(category.label.toUpperCase()),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(
                        () => _draftCategory = _ObCategory.values.firstWhere(
                          (category) => category.storageKey == value,
                          orElse: () => _ObCategory.patrol,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildReadOnlyField(
                    label: 'Occurred At',
                    value: _formatComposerTimestamp(_draftOccurredAt),
                  ),
                ),
              ],
            )
          else ...[
            _buildDropdownField(
              label: 'Category',
              value: _draftCategory.storageKey,
              items: _ObCategory.values
                  .where((category) => category != _ObCategory.all)
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category.storageKey,
                      child: Text(category.label.toUpperCase()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(
                  () => _draftCategory = _ObCategory.values.firstWhere(
                    (category) => category.storageKey == value,
                    orElse: () => _ObCategory.patrol,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildReadOnlyField(
              label: 'Occurred At',
              value: _formatComposerTimestamp(_draftOccurredAt),
            ),
          ],
          const SizedBox(height: 14),
          _buildTextField(
            controller: _locationController,
            label: 'Location Detail',
            hintText: 'e.g. North Gate, Zone 4',
            fieldKey: const ValueKey('ledger-form-location'),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _descriptionController,
            label: 'Entry Description *',
            hintText: 'Describe the occurrence in detail...',
            maxLines: 5,
            fieldKey: const ValueKey('ledger-form-description'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _obSurfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _obBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  color: _obBlueAccentStrong,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refine quietly in the background',
                        style: GoogleFonts.inter(
                          color: _obTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ONYX can tighten wording before save, but the controller still only sees one clean entry form.',
                        style: GoogleFonts.inter(
                          color: _obTextSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Checkbox(
                  value: _draftFlagged,
                  activeColor: const Color(0xFFF39A19),
                  onChanged: (value) {
                    setState(() => _draftFlagged = value ?? false);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                key: const ValueKey('ledger-form-submit'),
                onPressed: () => _submitEntry(
                  guardPresets: guardPresets,
                  currentEntries: currentEntries,
                ),
                style: _primaryButtonStyle(),
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('Submit Entry'),
              ),
              TextButton(
                key: const ValueKey('ledger-form-cancel'),
                onPressed: () {
                  setState(() {
                    _composerOpen = false;
                    _resetDraft(presets: guardPresets);
                  });
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: _obTextPrimary,
                    fontSize: 15,
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

  Widget _buildEntriesPanel({
    required List<_ObEntryView> entries,
    required _ObEntryView selected,
  }) {
    return _surfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRACE RAIL',
            style: GoogleFonts.inter(
              color: _obTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entries.isEmpty
                ? 'Nothing matches the current filter.'
                : '${entries.length} records ready right now.',
            style: GoogleFonts.inter(
              color: _obTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _obSurfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _obBorder),
              ),
              child: Text(
                'Widen the filter or clear search to bring the record rail back.',
                style: GoogleFonts.inter(
                  color: _obTextSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _buildEntryCard(
                    entry: entries[i],
                    selected: entries[i].id == selected.id,
                  ),
                  if (i != entries.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEntryCard({
    required _ObEntryView entry,
    required bool selected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('ledger-entry-card-${entry.id}'),
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            _selectedEntryId = entry.id;
            _workspaceView = _ObWorkspaceView.record;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected
                ? entry.accent.withValues(alpha: 0.08)
                : _obSurfaceElevated,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? entry.accent.withValues(alpha: 0.42)
                  : _obBorder,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF172638,
                ).withValues(alpha: selected ? 0.08 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.recordCode,
                        style: GoogleFonts.inter(
                          color: _obTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _buildBadge(
                        label: entry.category.label.toUpperCase(),
                        backgroundColor: entry.accent.withValues(alpha: 0.12),
                        foregroundColor: entry.accent,
                      ),
                      _buildBadge(
                        label: entry.statusLabel,
                        backgroundColor: _obBlueAccentStrong.withValues(
                          alpha: 0.14,
                        ),
                        foregroundColor: _obBlueAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.title,
                    style: GoogleFonts.inter(
                      color: _obTextPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.description,
                    style: GoogleFonts.inter(
                      color: _obTextSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${entry.callsign}  ·  ${entry.guardLabel}  ·  ${entry.siteLabel}  ·  ${entry.locationDetail}',
                    style: GoogleFonts.inter(
                      color: _obTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );

              final iconColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    entry.verified
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    color: entry.verified
                        ? const Color(0xFF2BB973)
                        : const Color(0xFFF39A19),
                    size: 22,
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    entry.flagged
                        ? Icons.flag_rounded
                        : Icons.outlined_flag_rounded,
                    color: entry.flagged
                        ? const Color(0xFFF39A19)
                        : _obTextMuted,
                    size: 22,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _formatUtcTimestamp(entry.occurredAt),
                    style: GoogleFonts.inter(
                      color: _obTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [content, const SizedBox(height: 14), iconColumn],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 14),
                  SizedBox(width: 200, child: iconColumn),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel({
    required BuildContext context,
    required List<_ObEntryView> entries,
    required _ObEntryView selected,
    required List<_ObEntryView> relatedEntries,
  }) {
    return _surfacePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const ValueKey('ledger-workspace-status-banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _obSurfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _obBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOU ARE HERE',
                        style: GoogleFonts.inter(
                          color: _obBlueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${selected.recordCode} · ${selected.category.label}',
                        style: GoogleFonts.inter(
                          color: _obTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHeroStatusChip(
                  label: _integrity.label,
                  color: _integrity.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('ledger-workspace-command-receipt'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _commandReceipt.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _commandReceipt.accent.withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _commandReceipt.label,
                  style: GoogleFonts.inter(
                    color: _commandReceipt.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _commandReceipt.message,
                  style: GoogleFonts.inter(
                    color: _obTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _commandReceipt.detail,
                  style: GoogleFonts.inter(
                    color: _obTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('ledger-context-verify-chain'),
                onPressed: () => _runIntegrityCheck(entries),
                style: _primaryButtonStyle(
                  backgroundColor: _obButtonFill,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Check Chain'),
              ),
              FilledButton.icon(
                key: const ValueKey('ledger-context-export-ledger'),
                onPressed: () => _exportLedger(entries),
                style: _primaryButtonStyle(
                  backgroundColor: _obButtonFill,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Copy Ledger'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildWorkspaceChip(
                key: const ValueKey('ledger-workspace-view-case-file'),
                label: 'Now',
                selected: _workspaceView == _ObWorkspaceView.record,
                onTap: () =>
                    setState(() => _workspaceView = _ObWorkspaceView.record),
              ),
              _buildWorkspaceChip(
                key: const ValueKey('ledger-workspace-view-chain'),
                label: 'Chain',
                selected: _workspaceView == _ObWorkspaceView.chain,
                onTap: () =>
                    setState(() => _workspaceView = _ObWorkspaceView.chain),
              ),
              _buildWorkspaceChip(
                key: const ValueKey('ledger-workspace-view-trace'),
                label: 'Trace',
                selected: _workspaceView == _ObWorkspaceView.linked,
                onTap: () =>
                    setState(() => _workspaceView = _ObWorkspaceView.linked),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_workspaceView == _ObWorkspaceView.record)
            _buildRecordView(selected)
          else if (_workspaceView == _ObWorkspaceView.chain)
            _buildChainView(selected)
          else
            _buildLinkedView(
              context: context,
              selected: selected,
              relatedEntries: relatedEntries,
            ),
        ],
      ),
    );
  }

  Widget _buildRecordView(_ObEntryView selected) {
    final returnToWarRoomLabel = _returnToWarRoomLabelForSelected(selected);
    final dispatchAuditDispatchId = _dispatchAuditDispatchIdForSelected(
      selected,
    );
    final dispatchAuditIncidentReference =
        _dispatchAuditIncidentReferenceForSelected(selected);
    final dispatchAuditAction = _dispatchAuditActionForSelected(selected);
    final liveOpsAuditIncidentReference =
        _liveOpsAuditIncidentReferenceForSelected(selected);
    final liveOpsAuditAction = _liveOpsAuditActionForSelected(selected);
    final clientHandoffRoom = _clientHandoffRoomForSelected(selected);
    final auditTargetCallout = _auditTargetCalloutForSelected(
      selected,
      clientHandoffRoom,
    );
    final riskIntelAuditAction = _riskIntelAuditActionForSelected(selected);
    final riskIntelAuditEventIds = _riskIntelAuditEventIdsForSelected(selected);
    final riskIntelSelectedEventId = _riskIntelSelectedEventIdForSelected(
      selected,
    );
    final opensManualIntel = _selectedAuditOpensManualIntel(selected);
    final vipAuditAction = _vipAuditActionForSelected(selected);
    final opensVipPackageDesk = _selectedAuditOpensVipPackageDesk(selected);
    final opensRosterPlanner = _selectedAuditOpensRosterPlanner(selected);
    final sitesAuditAction = _sitesAuditActionForSelected(selected);
    final opensSitesAction = _selectedAuditOpensSitesAction(selected);
    return Container(
      key: const ValueKey('ledger-workspace-panel-case-file'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _obSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _obBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority',
            style: GoogleFonts.inter(
              color: _obTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailGrid(
            items: [
              _DetailItem(label: 'Record', value: selected.recordCode),
              _DetailItem(label: 'Category', value: selected.category.label),
              _DetailItem(label: 'Guard', value: selected.guardLabel),
              _DetailItem(label: 'Callsign', value: selected.callsign),
              _DetailItem(label: 'Site', value: selected.siteLabel),
              if (clientHandoffRoom != null)
                _DetailItem(
                  key: const ValueKey('ledger-detail-room'),
                  label: 'Room',
                  value: clientHandoffRoom,
                ),
              _DetailItem(
                label: 'Occurred',
                value: _formatUtcTimestamp(selected.occurredAt),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            selected.locationDetail,
            style: GoogleFonts.inter(
              color: _obBlueAccent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (auditTargetCallout != null) ...[
            const SizedBox(height: 8),
            Text(
              auditTargetCallout,
              key: const ValueKey('ledger-audit-target-callout'),
              style: GoogleFonts.inter(
                color: const Color(0xFF22D3EE),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            selected.description,
            style: GoogleFonts.inter(
              color: _obTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('ledger-entry-export-data'),
                onPressed: () => _exportEntryData(selected),
                style: _primaryButtonStyle(
                  backgroundColor: _obButtonFill,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Entry'),
              ),
              FilledButton.icon(
                key: const ValueKey('ledger-entry-view-event-review'),
                onPressed:
                    selected.linkedEventIds.isEmpty ||
                        widget.onOpenEventsForScope == null
                    ? null
                    : () => _openSelectedEvents(
                        selected,
                        label: 'OPEN EVENTS SCOPE',
                      ),
                style: _primaryButtonStyle(
                  backgroundColor: _obButtonFill,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('OPEN EVENTS SCOPE'),
              ),
              if (dispatchAuditIncidentReference != null)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-dispatch'),
                  onPressed: widget.onOpenDispatchForIncident == null
                      ? null
                      : () => widget.onOpenDispatchForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: _dispatchAuditPrimaryButtonBackground(
                      dispatchAuditAction,
                    ),
                    foregroundColor: _dispatchAuditPrimaryButtonAccent(
                      dispatchAuditAction,
                    ),
                  ),
                  icon: Icon(
                    _dispatchAuditPrimaryButtonIcon(dispatchAuditAction),
                    size: 18,
                  ),
                  label: Text(
                    _dispatchAuditPrimaryButtonLabel(dispatchAuditAction),
                  ),
                ),
              if (dispatchAuditDispatchId != null &&
                  dispatchAuditAction == 'report_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-dispatch-report'),
                  onPressed: widget.onOpenReportForDispatchAudit == null
                      ? null
                      : () => widget.onOpenReportForDispatchAudit!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference ??
                                'INC-$dispatchAuditDispatchId',
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF102338),
                    foregroundColor: const Color(0xFF8FD1FF),
                  ),
                  icon: const Icon(Icons.description_rounded, size: 18),
                  label: const Text('OPEN REPORTS WORKSPACE'),
                ),
              if (dispatchAuditIncidentReference != null &&
                  dispatchAuditAction == 'track_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-dispatch-track'),
                  onPressed: widget.onOpenTrackForIncident == null
                      ? null
                      : () => widget.onOpenTrackForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF12213A),
                    foregroundColor: const Color(0xFF8FD1FF),
                  ),
                  icon: const Icon(Icons.near_me_rounded, size: 18),
                  label: const Text('OPEN TACTICAL TRACK'),
                ),
              if (dispatchAuditIncidentReference != null &&
                  dispatchAuditAction == 'client_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-client-handoff'),
                  onPressed: widget.onOpenClientForIncident == null
                      ? null
                      : () => widget.onOpenClientForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF0E2230),
                    foregroundColor: const Color(0xFF22D3EE),
                  ),
                  icon: const Icon(Icons.forum_rounded, size: 18),
                  label: Text(
                    _clientHandoffButtonLabelForRoom(clientHandoffRoom),
                  ),
                ),
              if (dispatchAuditIncidentReference != null &&
                  dispatchAuditAction == 'cctv_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-cctv'),
                  onPressed: widget.onOpenCctvForIncident == null
                      ? null
                      : () => widget.onOpenCctvForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: OnyxColorTokens.surfaceInset,
                    foregroundColor: OnyxDesignTokens.greenNominal,
                  ),
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('OPEN CCTV REVIEW'),
                ),
              if (riskIntelAuditEventIds.isNotEmpty &&
                  (riskIntelAuditAction == 'feed_item_opened' ||
                      riskIntelAuditAction == 'area_scope_opened'))
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-risk-intel-events'),
                  onPressed: widget.onOpenEventsForScope == null
                      ? null
                      : () => widget.onOpenEventsForScope!(
                          riskIntelAuditEventIds,
                          riskIntelSelectedEventId,
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: OnyxColorTokens.surfaceInset,
                    foregroundColor: OnyxDesignTokens.accentPurple,
                  ),
                  icon: const Icon(Icons.timeline_rounded, size: 18),
                  label: const Text('OPEN EVENTS SCOPE'),
                ),
              if (opensManualIntel)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-manual-intel'),
                  onPressed: widget.onOpenManualIntelFromAudit,
                  style: _primaryButtonStyle(
                    backgroundColor: OnyxColorTokens.surfaceInset,
                    foregroundColor: OnyxDesignTokens.accentSky,
                  ),
                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                  label: const Text('OPEN INTEL INTAKE'),
                ),
              if (opensVipPackageDesk)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-vip-package'),
                  onPressed: widget.onOpenVipPackageFromAudit,
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF173124),
                    foregroundColor: vipAuditAction == 'package_review_opened'
                        ? const Color(0xFF7DDCFF)
                        : const Color(0xFF5BE2A3),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  label: Text(
                    vipAuditAction == 'package_review_opened'
                        ? 'OPEN PACKAGE REVIEW'
                        : 'OPEN PACKAGE DESK',
                  ),
                ),
              if (liveOpsAuditIncidentReference != null &&
                  liveOpsAuditAction == 'track_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-live-ops-track'),
                  onPressed: widget.onOpenTrackForIncident == null
                      ? null
                      : () => widget.onOpenTrackForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            liveOpsAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF12213A),
                    foregroundColor: const Color(0xFF8FD1FF),
                  ),
                  icon: const Icon(Icons.near_me_rounded, size: 18),
                  label: const Text('OPEN TACTICAL TRACK'),
                ),
              if (liveOpsAuditIncidentReference != null &&
                  liveOpsAuditAction == 'dispatch_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-live-ops-dispatch'),
                  onPressed: widget.onOpenDispatchForIncident == null
                      ? null
                      : () => widget.onOpenDispatchForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            liveOpsAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF102338),
                    foregroundColor: const Color(0xFF8FD1FF),
                  ),
                  icon: const Icon(Icons.local_shipping_rounded, size: 18),
                  label: const Text('OPEN DISPATCH BOARD'),
                ),
              if (liveOpsAuditIncidentReference != null &&
                  liveOpsAuditAction == 'client_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey(
                    'ledger-entry-open-live-ops-client-handoff',
                  ),
                  onPressed: widget.onOpenClientForIncident == null
                      ? null
                      : () => widget.onOpenClientForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            liveOpsAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF0E2230),
                    foregroundColor: const Color(0xFF22D3EE),
                  ),
                  icon: const Icon(Icons.forum_rounded, size: 18),
                  label: Text(
                    _clientHandoffButtonLabelForRoom(clientHandoffRoom),
                  ),
                ),
              if (liveOpsAuditIncidentReference != null &&
                  liveOpsAuditAction == 'cctv_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-live-ops-cctv'),
                  onPressed: widget.onOpenCctvForIncident == null
                      ? null
                      : () => widget.onOpenCctvForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            liveOpsAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: OnyxColorTokens.surfaceInset,
                    foregroundColor: OnyxDesignTokens.greenNominal,
                  ),
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('OPEN CCTV REVIEW'),
                ),
              if (dispatchAuditIncidentReference != null &&
                  dispatchAuditAction == 'agent_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-ai-copilot'),
                  onPressed: widget.onOpenAgentForIncident == null
                      ? null
                      : () => widget.onOpenAgentForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            dispatchAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF241532),
                    foregroundColor: const Color(0xFFC084FC),
                  ),
                  icon: const Icon(Icons.psychology_alt_rounded, size: 18),
                  label: const Text('OPEN AI COPILOT'),
                ),
              if (liveOpsAuditIncidentReference != null &&
                  liveOpsAuditAction == 'agent_handoff_opened')
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-live-ops-ai-copilot'),
                  onPressed: widget.onOpenOperationsAgentForIncident == null
                      ? null
                      : () => widget.onOpenOperationsAgentForIncident!(
                          _dispatchAuditOpenRequestForSelected(
                            selected,
                            liveOpsAuditIncidentReference,
                          ),
                        ),
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF241532),
                    foregroundColor: const Color(0xFFC084FC),
                  ),
                  icon: const Icon(Icons.psychology_alt_rounded, size: 18),
                  label: const Text('OPEN AI COPILOT'),
                ),
              if (opensRosterPlanner)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-roster-planner'),
                  onPressed: widget.onOpenRosterPlannerFromAudit,
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF2B1804),
                    foregroundColor: const Color(0xFFFBBF24),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('OPEN MONTH PLANNER'),
                ),
              if (opensSitesAction)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-open-sites-action'),
                  onPressed: widget.onOpenSitesActionFromAudit,
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF12213A),
                    foregroundColor: _sitesAuditButtonAccent(sitesAuditAction),
                  ),
                  icon: Icon(_sitesAuditButtonIcon(sitesAuditAction), size: 18),
                  label: Text(_sitesAuditButtonLabel(sitesAuditAction)),
                ),
              if (returnToWarRoomLabel != null)
                FilledButton.icon(
                  key: const ValueKey('ledger-entry-back-to-war-room'),
                  onPressed: widget.onReturnToWarRoom,
                  style: _primaryButtonStyle(
                    backgroundColor: const Color(0xFF1B4332),
                    foregroundColor: const Color(0xFF63E6A1),
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(returnToWarRoomLabel),
                ),
            ],
          ),
          if (selected.sceneReview != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _obSurfaceSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _obBorderStrong),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCENE REVIEW',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B63FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected.sceneReview!.sourceLabel,
                    style: GoogleFonts.inter(
                      color: _obTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (selected.sceneReview!.decisionLabel
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      selected.sceneReview!.decisionLabel,
                      style: GoogleFonts.inter(
                        color: _obTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (selected.sceneReview!.decisionSummary
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      selected.sceneReview!.decisionSummary,
                      style: GoogleFonts.inter(
                        color: _obTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    selected.sceneReview!.summary,
                    style: GoogleFonts.inter(
                      color: _obTextSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChainView(_ObEntryView selected) {
    return Container(
      key: const ValueKey('ledger-workspace-panel-chain'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _obSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _obBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHECK CHAIN',
            style: GoogleFonts.inter(
              color: _obTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailGrid(
            items: [
              _DetailItem(label: 'Chain State', value: _integrity.label),
              _DetailItem(
                label: 'Record State',
                value: selected.verified ? 'VERIFIED' : 'PENDING',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHashPanel(
            label: 'Current Hash',
            value: selected.hash,
            color: const Color(0xFF19B26D),
          ),
          const SizedBox(height: 12),
          _buildHashPanel(
            label: 'Previous Hash',
            value: selected.previousHash,
            color: const Color(0xFF11A4DA),
          ),
          const SizedBox(height: 16),
          Text(
            'The chain stays visible for audit while the controller only needs one move: check the record, confirm the state, and keep going.',
            style: GoogleFonts.inter(
              color: _obTextSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedView({
    required BuildContext context,
    required _ObEntryView selected,
    required List<_ObEntryView> relatedEntries,
  }) {
    return Container(
      key: const ValueKey('ledger-workspace-panel-trace'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _obSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _obBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRACE RAIL',
            style: GoogleFonts.inter(
              color: _obTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (selected.linkedEventIds.isEmpty)
            Text(
              'No linked events are pinned to this record yet.',
              style: GoogleFonts.inter(
                color: _obTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected.linkedEventIds
                  .map(
                    (eventId) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _obSurfaceSoft,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _obBorderStrong),
                      ),
                      child: Text(
                        eventId,
                        style: GoogleFonts.inter(
                          color: _obBlueAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (relatedEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Related Entries',
              style: GoogleFonts.inter(
                color: _obBlueAccent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                for (var i = 0; i < relatedEntries.length; i++) ...[
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedEntryId = relatedEntries[i].id;
                          _workspaceView = _ObWorkspaceView.record;
                        });
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _obSurfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _obBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    relatedEntries[i].recordCode,
                                    style: GoogleFonts.inter(
                                      color: _obTextPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    relatedEntries[i].title,
                                    style: GoogleFonts.inter(
                                      color: _obTextSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _obTextMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (i != relatedEntries.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ],
          if (selected.sceneReview != null) ...[
            const SizedBox(height: 18),
            Text(
              'Scene posture: ${selected.sceneReview!.postureLabel}',
              style: GoogleFonts.inter(
                color: _obTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  String? _returnToWarRoomLabelForSelected(_ObEntryView selected) {
    final pinnedAuditEntry = widget.pinnedAuditEntry;
    if (widget.onReturnToWarRoom == null ||
        pinnedAuditEntry == null ||
        selected.id != pinnedAuditEntry.auditId) {
      return null;
    }
    final sourceLabel = pinnedAuditEntry.sourceLabel.trim().toLowerCase();
    if (sourceLabel.contains('dispatch')) {
      return 'Back to Dispatch';
    }
    if (sourceLabel.contains('live ops')) {
      return 'Back to Live Ops';
    }
    if (sourceLabel.contains('risk intel')) {
      return 'Back to Risk Intel';
    }
    if (sourceLabel.contains('vip')) {
      return 'Back to VIP';
    }
    if (sourceLabel.contains('sites')) {
      return 'Back to Sites';
    }
    return 'Back to War Room';
  }

  String? _dispatchAuditIncidentReferenceForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'dispatch_auto_audit') {
      return null;
    }
    final incidentReference =
        (selected.payload['incident_reference'] as String? ?? '').trim();
    return incidentReference.isEmpty ? null : incidentReference;
  }

  String? _dispatchAuditDispatchIdForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'dispatch_auto_audit') {
      return null;
    }
    final dispatchId = (selected.payload['dispatch_id'] as String? ?? '')
        .trim();
    return dispatchId.isEmpty ? null : dispatchId;
  }

  String _dispatchAuditActionForSelected(_ObEntryView selected) {
    return (selected.payload['action'] as String? ?? '').trim();
  }

  DispatchAuditOpenRequest _dispatchAuditOpenRequestForSelected(
    _ObEntryView selected,
    String incidentReference,
  ) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    final action = (selected.payload['action'] as String? ?? '').trim();
    final dispatchId = (selected.payload['dispatch_id'] as String? ?? '')
        .trim();
    return DispatchAuditOpenRequest(
      incidentReference: incidentReference.trim(),
      auditId: selected.id,
      payloadType: payloadType,
      action: action,
      dispatchId: dispatchId.isEmpty ? null : dispatchId,
    );
  }

  String _dispatchAuditPrimaryButtonLabel(String action) {
    return switch (action.trim()) {
      'dispatch_launched' => 'OPEN LIVE DISPATCH',
      'dispatch_resolved' => 'OPEN CLOSURE BOARD',
      'alarm_cleared' => 'OPEN CLEARED DISPATCH',
      _ => 'OPEN DISPATCH BOARD',
    };
  }

  IconData _dispatchAuditPrimaryButtonIcon(String action) {
    return switch (action.trim()) {
      'dispatch_resolved' || 'alarm_cleared' => Icons.verified_rounded,
      _ => Icons.local_shipping_rounded,
    };
  }

  Color _dispatchAuditPrimaryButtonAccent(String action) {
    return switch (action.trim()) {
      'dispatch_launched' => const Color(0xFFF59E0B),
      'dispatch_resolved' || 'alarm_cleared' => const Color(0xFF63E6A1),
      _ => const Color(0xFF8FD1FF),
    };
  }

  Color _dispatchAuditPrimaryButtonBackground(String action) {
    return OnyxColorTokens.surfaceInset;
  }

  String? _liveOpsAuditIncidentReferenceForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'live_ops_auto_audit') {
      return null;
    }
    final incidentReference =
        (selected.payload['incident_reference'] as String? ?? '').trim();
    return incidentReference.isEmpty ? null : incidentReference;
  }

  String _liveOpsAuditActionForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'live_ops_auto_audit') {
      return '';
    }
    return (selected.payload['action'] as String? ?? '').trim();
  }

  String? _clientHandoffRoomForSelected(_ObEntryView selected) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    if (payloadType != 'dispatch_auto_audit' &&
        payloadType != 'live_ops_auto_audit') {
      return null;
    }
    final action = (selected.payload['action'] as String? ?? '').trim();
    if (action != 'client_handoff_opened') {
      return null;
    }
    final room =
        (selected.payload['room'] as String? ??
                selected.payload['room_key'] as String? ??
                '')
            .trim();
    return room.isEmpty ? null : room;
  }

  String _clientHandoffButtonLabelForRoom(String? room) {
    final normalizedRoom = (room ?? '').trim();
    if (normalizedRoom.isEmpty) {
      return 'Open Client Handoff';
    }
    return 'Open $normalizedRoom';
  }

  String? _auditTargetCalloutForSelected(_ObEntryView selected, String? room) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    final action = (selected.payload['action'] as String? ?? '').trim();
    final normalizedRoom = (room ?? '').trim();
    return switch ((payloadType, action)) {
      ('dispatch_auto_audit', 'client_handoff_opened') ||
      (
        'live_ops_auto_audit',
        'client_handoff_opened',
      ) when normalizedRoom.isNotEmpty => 'ROOM TARGET • $normalizedRoom',
      ('dispatch_auto_audit', 'track_handoff_opened') ||
      (
        'live_ops_auto_audit',
        'track_handoff_opened',
      ) => 'DESK TARGET • Tactical Track',
      ('dispatch_auto_audit', 'cctv_handoff_opened') ||
      (
        'live_ops_auto_audit',
        'cctv_handoff_opened',
      ) => 'DESK TARGET • CCTV Review',
      ('dispatch_auto_audit', 'agent_handoff_opened') ||
      (
        'live_ops_auto_audit',
        'agent_handoff_opened',
      ) => 'DESK TARGET • AI Copilot',
      ('dispatch_auto_audit', 'report_handoff_opened') =>
        'DESK TARGET • Reports Workspace',
      ('dispatch_auto_audit', 'roster_planner_opened') ||
      (
        'live_ops_auto_audit',
        'roster_planner_opened',
      ) => 'DESK TARGET • Month Planner',
      ('live_ops_auto_audit', 'dispatch_handoff_opened') =>
        'DESK TARGET • Dispatch Board',
      ('risk_intel_auto_audit', 'area_scope_opened') ||
      (
        'risk_intel_auto_audit',
        'feed_item_opened',
      ) => 'DESK TARGET • Events Scope',
      ('risk_intel_auto_audit', 'manual_intel_opened') =>
        'DESK TARGET • Intel Intake',
      ('vip_auto_audit', 'package_review_opened') =>
        'DESK TARGET • VIP Package Review',
      ('vip_auto_audit', 'package_staging_opened') =>
        'DESK TARGET • VIP Package Desk',
      ('sites_auto_audit', 'site_builder_opened') => 'DESK TARGET • Site Desk',
      ('sites_auto_audit', 'site_map_opened') => 'DESK TARGET • Site Map',
      ('sites_auto_audit', 'site_settings_opened') =>
        'DESK TARGET • Site Settings',
      ('sites_auto_audit', 'site_guard_roster_opened') =>
        'DESK TARGET • Guard Roster',
      _ => null,
    };
  }

  String _riskIntelAuditActionForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'risk_intel_auto_audit') {
      return '';
    }
    return (selected.payload['action'] as String? ?? '').trim();
  }

  List<String> _riskIntelAuditEventIdsForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'risk_intel_auto_audit') {
      return const <String>[];
    }
    final raw = selected.payload['scoped_event_ids'];
    if (raw is! List) {
      return const <String>[];
    }
    return raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  String? _riskIntelSelectedEventIdForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'risk_intel_auto_audit') {
      return null;
    }
    final selectedEventId =
        (selected.payload['selected_event_id'] as String? ?? '').trim();
    return selectedEventId.isEmpty ? null : selectedEventId;
  }

  bool _selectedAuditOpensRosterPlanner(_ObEntryView selected) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    if (payloadType != 'dispatch_auto_audit' &&
        payloadType != 'live_ops_auto_audit') {
      return false;
    }
    return (selected.payload['action'] as String? ?? '').trim() ==
        'roster_planner_opened';
  }

  bool _selectedAuditOpensManualIntel(_ObEntryView selected) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    if (payloadType != 'risk_intel_auto_audit') {
      return false;
    }
    return (selected.payload['action'] as String? ?? '').trim() ==
        'manual_intel_opened';
  }

  String _vipAuditActionForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'vip_auto_audit') {
      return '';
    }
    return (selected.payload['action'] as String? ?? '').trim();
  }

  bool _selectedAuditOpensVipPackageDesk(_ObEntryView selected) {
    final payloadType = (selected.payload['type'] as String? ?? '').trim();
    if (payloadType != 'vip_auto_audit') {
      return false;
    }
    final action = (selected.payload['action'] as String? ?? '').trim();
    return action == 'package_staging_opened' ||
        action == 'package_review_opened';
  }

  String _sitesAuditActionForSelected(_ObEntryView selected) {
    if (selected.payload['type'] != 'sites_auto_audit') {
      return '';
    }
    return (selected.payload['action'] as String? ?? '').trim();
  }

  bool _selectedAuditOpensSitesAction(_ObEntryView selected) {
    final action = _sitesAuditActionForSelected(selected);
    return action == 'site_builder_opened' ||
        action == 'site_map_opened' ||
        action == 'site_settings_opened' ||
        action == 'site_guard_roster_opened';
  }

  String _sitesAuditButtonLabel(String action) {
    return switch (action.trim()) {
      'site_builder_opened' => 'OPEN SITE DESK',
      'site_map_opened' => 'OPEN SITE MAP',
      'site_settings_opened' => 'OPEN SITE SETTINGS',
      'site_guard_roster_opened' => 'OPEN GUARD ROSTER',
      _ => 'OPEN SITE DESK',
    };
  }

  IconData _sitesAuditButtonIcon(String action) {
    return switch (action.trim()) {
      'site_builder_opened' => Icons.add_business_rounded,
      'site_map_opened' => Icons.map_rounded,
      'site_settings_opened' => Icons.settings_rounded,
      'site_guard_roster_opened' => Icons.groups_rounded,
      _ => Icons.domain_rounded,
    };
  }

  Color _sitesAuditButtonAccent(String action) {
    return switch (action.trim()) {
      'site_builder_opened' => const Color(0xFF8FD1FF),
      'site_map_opened' => const Color(0xFF54C8FF),
      'site_settings_opened' => const Color(0xFFFFC247),
      'site_guard_roster_opened' => const Color(0xFF63E6A1),
      _ => const Color(0xFF8FD1FF),
    };
  }

  Widget _buildContextChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required _ObCategory category,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = category == _ObCategory.all
        ? _obBlueAccentStrong
        : category.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('ledger-lane-filter-${category.storageKey}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : _obSurfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.22) : _obBorder,
            ),
          ),
          child: Text(
            category.label.toUpperCase(),
            style: GoogleFonts.inter(
              color: selected ? color : _obTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildWorkspaceChip({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _obSurfaceSoft : _obSurfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? _obBlueAccent : _obBorder),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? _obBlueAccent : _obTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailGrid({required List<_DetailItem> items}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              key: item.key,
              width: 190,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _obSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _obBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      color: _obTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    style: GoogleFonts.inter(
                      color: _obTextPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildHashPanel({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _obSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _obBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hashPreview(value),
            style: GoogleFonts.robotoMono(
              color: _obTextPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _obTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.any((item) => item.value == value)
              ? value
              : items.first.value,
          onChanged: onChanged,
          style: GoogleFonts.inter(
            color: _obTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(),
          items: items,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int maxLines = 1,
    Key? fieldKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _obTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: _obTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _obTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          decoration: BoxDecoration(
            color: _obInputFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _obBorder),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: _obTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.inter(
        color: _obTextMuted,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _obInputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _obBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _obBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _obBlueAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: _obSurfaceFill,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _obBorder),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF172638).withValues(alpha: 0.07),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Widget _surfacePanel({required Widget child}) {
    return Container(
      decoration: _panelDecoration(),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  ButtonStyle _primaryButtonStyle({
    Color backgroundColor = _obButtonFill,
    Color foregroundColor = Colors.white,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }

  ButtonStyle _secondaryButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _obTextPrimary,
      backgroundColor: _obSurfaceFill,
      side: const BorderSide(color: _obBorder),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
    );
  }

  void _openComposer(List<_GuardPreset> guardPresets) {
    setState(() {
      _composerOpen = true;
      _workspaceView = _ObWorkspaceView.record;
      _draftOccurredAt = DateTime.now().toUtc();
      _resetDraft(presets: guardPresets);
    });
  }

  void _resetDraft({List<_GuardPreset> presets = const []}) {
    final source = presets.isEmpty ? _defaultGuardPresets : presets;
    final preset = source.first;
    _applyGuardPreset(preset);
    _draftCategory = _categoryFilter == _ObCategory.all
        ? _ObCategory.patrol
        : _categoryFilter;
    _draftOccurredAt = DateTime.now().toUtc();
    _draftFlagged = false;
    _locationController.clear();
    _descriptionController.clear();
  }

  void _applyGuardPreset(_GuardPreset preset) {
    _draftPresetKey = preset.key;
    _draftSite = preset.siteLabel;
    _guardNameController.text = preset.guardName;
    _callsignController.text = preset.callsign;
  }

  void _submitEntry({
    required List<_GuardPreset> guardPresets,
    required List<_ObEntryView> currentEntries,
  }) {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showActionMessage(
        'Entry description required.',
        label: 'SUBMIT ENTRY',
        detail:
            'Add the operational note before saving it into the occurrence book.',
        accent: const Color(0xFFF39A19),
      );
      return;
    }

    final nextSequence = _nextSequence(currentEntries);
    final nextRecordNumber = _nextRecordNumber(currentEntries);
    final previousHash = currentEntries.isEmpty
        ? 'GENESIS'
        : currentEntries.first.hash;
    final payload = <String, Object?>{
      'source': 'manual_ob_entry',
      'clientId': widget.clientId,
      'site': _draftSite,
      'guard_name': _guardNameController.text.trim(),
      'callsign': _callsignController.text.trim(),
      'location_detail': _locationController.text.trim(),
      'description': description,
      'category': _draftCategory.storageKey,
      'flagged': _draftFlagged,
      'refined': true,
    };
    final hash = EvidenceCertificateExportService.chainedPayloadHash(
      payload: payload,
      previousHash: previousHash,
    );
    final entry = _ObEntryView(
      id: 'MAN-$nextSequence',
      sequence: nextSequence,
      recordCode: 'OB-$nextRecordNumber',
      title: _manualEntryTitle(_draftCategory, description),
      description: description,
      category: _draftCategory,
      occurredAt: _draftOccurredAt,
      siteLabel: _draftSite.trim().isEmpty
          ? _defaultGuardPresets.first.siteLabel
          : _draftSite,
      guardLabel: _guardNameController.text.trim(),
      callsign: _callsignController.text.trim(),
      locationDetail: _locationController.text.trim().isEmpty
          ? 'Controller desk note'
          : _locationController.text.trim(),
      incident:
          _draftCategory == _ObCategory.incident ||
          _draftCategory == _ObCategory.alarm,
      flagged: _draftFlagged,
      verified: false,
      statusLabel: 'SUBMITTED',
      linkedEventIds: const <String>[],
      hash: hash,
      previousHash: previousHash,
      accent: _draftCategory.accent,
      payload: payload,
    );

    setState(() {
      _manualEntries.insert(0, entry);
      _selectedEntryId = entry.id;
      _composerOpen = false;
      _workspaceView = _ObWorkspaceView.record;
      _resetDraft(presets: guardPresets);
    });

    _showActionMessage(
      'OB entry submitted (${entry.recordCode}).',
      label: 'SUBMIT ENTRY',
      detail:
          'The note is now pinned to the occurrence book and available for handover, review, and audit continuity.',
      accent: entry.accent,
    );
  }

  void _openSelectedEvents(_ObEntryView entry, {required String label}) {
    if (widget.onOpenEventsForScope == null || entry.linkedEventIds.isEmpty) {
      _showActionMessage(
        'No linked events available for ${entry.recordCode}.',
        label: label,
        detail:
            'This entry is currently a clean standalone record in the OB log.',
        accent: const Color(0xFFF39A19),
      );
      return;
    }

    widget.onOpenEventsForScope!(
      entry.linkedEventIds,
      entry.linkedEventIds.first,
    );
    _showActionMessage(
      'Linked events opened (${entry.recordCode}).',
      label: label,
      detail:
          'The related event scope has been handed off without leaving the occurrence-book context behind.',
      accent: const Color(0xFF19B4E5),
    );
  }

  void _runIntegrityCheck(List<_ObEntryView> entries) {
    final intact = _verifyChain(entries);
    setState(() {
      _integrity = intact
          ? _ChainIntegrity.intact
          : _ChainIntegrity.compromised;
    });
    _showActionMessage(
      intact
          ? 'Chain verification returned intact.'
          : 'Chain verification detected a continuity mismatch.',
      label: 'VERIFY CHAIN',
      detail:
          'Continuity state remains visible while the operational view stays simple for the controller.',
      accent: intact ? const Color(0xFF19B26D) : const Color(0xFFF44B4B),
    );
  }

  void _exportLedger(List<_ObEntryView> entries) {
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(entries.map(_entryToJson).toList(growable: false));
    Clipboard.setData(ClipboardData(text: pretty));
    _showActionMessage(
      'Ledger export copied (${entries.length} entries).',
      label: 'EXPORT LEDGER',
      detail:
          'The full occurrence-book payload is on the clipboard while the clean controller view remains in place.',
      accent: const Color(0xFF19B4E5),
    );
  }

  void _exportEntryData(_ObEntryView entry) {
    final pretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(_entryToJson(entry));
    Clipboard.setData(ClipboardData(text: pretty));
    _showActionMessage(
      'Entry export copied (${entry.id}).',
      label: 'EXPORT ENTRY',
      detail:
          'The focused entry payload is on the clipboard while its selected record stays pinned in view.',
      accent: entry.accent,
    );
  }

  void _showActionMessage(
    String message, {
    required String label,
    required String detail,
    required Color accent,
  }) {
    if (_desktopWorkspaceActive) {
      setState(() {
        _commandReceipt = _ObCommandReceipt(
          label: label,
          message: message,
          detail: detail,
          accent: accent,
        );
      });
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: _obSurfaceFill,
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
}

enum _ObCategory {
  all,
  patrol,
  incident,
  handover,
  visitor,
  maintenance,
  vehicle,
  alarm,
  other,
}

extension on _ObCategory {
  String get label {
    switch (this) {
      case _ObCategory.all:
        return 'All';
      case _ObCategory.patrol:
        return 'Patrol';
      case _ObCategory.incident:
        return 'Incident';
      case _ObCategory.handover:
        return 'Handover';
      case _ObCategory.visitor:
        return 'Visitor';
      case _ObCategory.maintenance:
        return 'Maintenance';
      case _ObCategory.vehicle:
        return 'Vehicle';
      case _ObCategory.alarm:
        return 'Alarm';
      case _ObCategory.other:
        return 'Other';
    }
  }

  String get storageKey {
    switch (this) {
      case _ObCategory.all:
        return 'all';
      case _ObCategory.patrol:
        return 'patrol';
      case _ObCategory.incident:
        return 'incident';
      case _ObCategory.handover:
        return 'handover';
      case _ObCategory.visitor:
        return 'visitor';
      case _ObCategory.maintenance:
        return 'maintenance';
      case _ObCategory.vehicle:
        return 'vehicle';
      case _ObCategory.alarm:
        return 'alarm';
      case _ObCategory.other:
        return 'other';
    }
  }

  Color get accent {
    switch (this) {
      case _ObCategory.all:
        return const Color(0xFF19B4E5);
      case _ObCategory.patrol:
        return const Color(0xFF33B878);
      case _ObCategory.incident:
        return const Color(0xFFF44B4B);
      case _ObCategory.handover:
        return const Color(0xFF6A63FF);
      case _ObCategory.visitor:
        return const Color(0xFF9C66E6);
      case _ObCategory.maintenance:
        return const Color(0xFF1DA2C9);
      case _ObCategory.vehicle:
        return const Color(0xFFF39A19);
      case _ObCategory.alarm:
        return const Color(0xFFF0672B);
      case _ObCategory.other:
        return const Color(0xFF73879B);
    }
  }
}

enum _ObWorkspaceView { record, chain, linked }

enum _ChainIntegrity { intact, pending, compromised }

extension on _ChainIntegrity {
  String get label {
    switch (this) {
      case _ChainIntegrity.intact:
        return 'INTACT';
      case _ChainIntegrity.pending:
        return 'PENDING';
      case _ChainIntegrity.compromised:
        return 'COMPROMISED';
    }
  }

  Color get color {
    switch (this) {
      case _ChainIntegrity.intact:
        return const Color(0xFF19B26D);
      case _ChainIntegrity.pending:
        return const Color(0xFFF39A19);
      case _ChainIntegrity.compromised:
        return const Color(0xFFF44B4B);
    }
  }
}

class _GuardPreset {
  final String key;
  final String callsign;
  final String guardName;
  final String siteLabel;

  const _GuardPreset({
    required this.key,
    required this.callsign,
    required this.guardName,
    required this.siteLabel,
  });
}

class _DetailItem {
  final Key? key;
  final String label;
  final String value;

  const _DetailItem({this.key, required this.label, required this.value});
}

class _ObCommandReceipt {
  final String label;
  final String message;
  final String detail;
  final Color accent;

  const _ObCommandReceipt({
    required this.label,
    required this.message,
    required this.detail,
    required this.accent,
  });
}

class _ObEntryView {
  final String id;
  final int sequence;
  final String recordCode;
  final String title;
  final String description;
  final _ObCategory category;
  final DateTime occurredAt;
  final String siteLabel;
  final String guardLabel;
  final String callsign;
  final String locationDetail;
  final bool incident;
  final bool flagged;
  final bool verified;
  final String statusLabel;
  final List<String> linkedEventIds;
  final String hash;
  final String previousHash;
  final Color accent;
  final Map<String, Object?> payload;
  final MonitoringSceneReviewRecord? sceneReview;

  const _ObEntryView({
    required this.id,
    required this.sequence,
    required this.recordCode,
    required this.title,
    required this.description,
    required this.category,
    required this.occurredAt,
    required this.siteLabel,
    required this.guardLabel,
    required this.callsign,
    required this.locationDetail,
    required this.incident,
    required this.flagged,
    required this.verified,
    required this.statusLabel,
    required this.linkedEventIds,
    required this.hash,
    required this.previousHash,
    required this.accent,
    required this.payload,
    this.sceneReview,
  });
}

_ObEntryView _pinnedAuditEntryToView(SovereignLedgerPinnedAuditEntry entry) {
  return _ObEntryView(
    id: entry.auditId,
    sequence: entry.occurredAt.microsecondsSinceEpoch,
    recordCode: entry.recordCode,
    title: entry.title,
    description: entry.description,
    category: _ObCategory.handover,
    occurredAt: entry.occurredAt.toUtc(),
    siteLabel: _displaySiteLabel(entry.siteId),
    guardLabel: entry.actorLabel,
    callsign: 'AUTO-AUDIT',
    locationDetail: entry.sourceLabel,
    incident: false,
    flagged: true,
    verified: true,
    statusLabel: 'SIGNED',
    linkedEventIds: const <String>[],
    hash: entry.hash,
    previousHash: entry.previousHash,
    accent: entry.accent,
    payload: entry.payload,
  );
}

Iterable<_ObEntryView> _presentEntries(_ObEntryView? entry) sync* {
  if (entry != null) {
    yield entry;
  }
}

const List<_GuardPreset> _defaultGuardPresets = [
  _GuardPreset(
    key: 'charlie-4',
    callsign: 'Charlie-4',
    guardName: 'Tom Brown',
    siteLabel: 'Riverside Estate',
  ),
  _GuardPreset(
    key: 'echo-3',
    callsign: 'Echo-3',
    guardName: 'John Smith',
    siteLabel: 'Midrand Logistics Hub',
  ),
  _GuardPreset(
    key: 'alpha-2',
    callsign: 'Alpha-2',
    guardName: 'Nandi Khumalo',
    siteLabel: 'Sector C',
  ),
];

final List<_ObEntryView> _fallbackEntries = [
  _ObEntryView(
    id: 'LED-1',
    sequence: 2441,
    recordCode: 'OB-2441',
    title: 'Patrol Irregularity - Sector B',
    description:
        'Checkpoint missed during the night shift. Controller note saved after guard callback and handover review.',
    category: _ObCategory.incident,
    occurredAt: DateTime.utc(2026, 3, 25, 15, 48),
    siteLabel: 'Riverside Estate',
    guardLabel: 'Tom Brown',
    callsign: 'Charlie-4',
    locationDetail: 'Sector B',
    incident: true,
    flagged: false,
    verified: true,
    statusLabel: 'SUBMITTED',
    linkedEventIds: ['INC-2438'],
    hash: 'a7f3e9d2c1b4f8a6e9c2b1a5d6e7f8a6',
    previousHash: '8e2f4a9d1c6b7e3f0a1b2c3d4e5f6a7b',
    accent: Color(0xFFF44B4B),
    payload: {
      'source': 'fallback',
      'site': 'Riverside Estate',
      'guard_name': 'Tom Brown',
      'callsign': 'Charlie-4',
      'description':
          'Checkpoint missed during the night shift. Controller note saved after guard callback and handover review.',
      'category': 'incident',
    },
  ),
  _ObEntryView(
    id: 'LED-2',
    sequence: 2440,
    recordCode: 'OB-2440',
    title: 'Gate lock delay resolved',
    description:
        'Guard delayed while fixing the outer gate lock. Patrol resumed and controller cleared the action-required queue.',
    category: _ObCategory.patrol,
    occurredAt: DateTime.utc(2026, 3, 25, 15, 43),
    siteLabel: 'Midrand Logistics Hub',
    guardLabel: 'John Smith',
    callsign: 'Echo-3',
    locationDetail: 'Main vehicle gate',
    incident: false,
    flagged: false,
    verified: true,
    statusLabel: 'SUBMITTED',
    linkedEventIds: ['PATROL-119'],
    hash: '8e2f4a9d1c6b7e3f0a1b2c3d4e5f6a7b',
    previousHash: '3d9a7e2f4c1b8e6a0d4e5f6a7b8c9d0e',
    accent: Color(0xFF33B878),
    payload: {
      'source': 'fallback',
      'site': 'Midrand Logistics Hub',
      'guard_name': 'John Smith',
      'callsign': 'Echo-3',
      'description':
          'Guard delayed while fixing the outer gate lock. Patrol resumed and controller cleared the action-required queue.',
      'category': 'patrol',
    },
  ),
  _ObEntryView(
    id: 'LED-3',
    sequence: 2439,
    recordCode: 'OB-2439',
    title: 'Suspicious Vehicle - Main Gate',
    description:
        'White vehicle observed loitering outside the main gate for an extended period after a client call.',
    category: _ObCategory.vehicle,
    occurredAt: DateTime.utc(2026, 3, 25, 9, 22),
    siteLabel: 'Main Gate',
    guardLabel: 'Controller Desk',
    callsign: 'Command',
    locationDetail: 'Outer approach lane',
    incident: false,
    flagged: false,
    verified: true,
    statusLabel: 'SUBMITTED',
    linkedEventIds: ['VEH-091'],
    hash: '3d9a7e2f4c1b8e6a0d4e5f6a7b8c9d0e',
    previousHash: '1f6c8a4e9d2b7e3a4b5c6d7e8f9a0b1c',
    accent: Color(0xFFF39A19),
    payload: {
      'source': 'fallback',
      'site': 'Main Gate',
      'guard_name': 'Controller Desk',
      'callsign': 'Command',
      'description':
          'White vehicle observed loitering outside the main gate for an extended period after a client call.',
      'category': 'vehicle',
    },
  ),
];

List<_ObEntryView> _buildObEntries(
  List<DispatchEvent> events, {
  String clientId = '',
  String siteId = '',
  Map<String, MonitoringSceneReviewRecord> sceneReviewByIntelligenceId =
      const {},
}) {
  if (events.isEmpty) {
    return const <_ObEntryView>[];
  }

  final normalizedClientId = clientId.trim();
  final normalizedSiteId = siteId.trim();
  final ordered = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
  var previousHash = 'GENESIS';
  final built = <_ObEntryView>[];

  for (final event in ordered) {
    if (normalizedClientId.isNotEmpty &&
        _eventClientId(event).trim() != normalizedClientId) {
      continue;
    }
    if (normalizedSiteId.isNotEmpty &&
        _eventSiteId(event).trim() != normalizedSiteId) {
      continue;
    }

    final sceneReview = event is IntelligenceReceived
        ? sceneReviewByIntelligenceId[event.intelligenceId.trim()]
        : null;
    final category = _categoryForEvent(event);
    final payload = _payloadForEvent(event, sceneReview: sceneReview);
    final hash = EvidenceCertificateExportService.chainedPayloadHash(
      payload: payload,
      previousHash: previousHash,
    );

    built.add(
      _ObEntryView(
        id: 'LED-${event.sequence}',
        sequence: event.sequence,
        recordCode: 'OB-${2400 + event.sequence}',
        title: _titleForEvent(event),
        description: _descriptionForEvent(event, sceneReview: sceneReview),
        category: category,
        occurredAt: event.occurredAt.toUtc(),
        siteLabel: _displaySiteLabel(_eventSiteId(event)),
        guardLabel: _guardLabelForEvent(event),
        callsign: _callsignForEvent(event),
        locationDetail: _locationForEvent(event),
        incident: _isIncidentEvent(event),
        flagged: _isFlaggedEvent(event, sceneReview: sceneReview),
        verified: true,
        statusLabel: 'SUBMITTED',
        linkedEventIds: <String>[event.eventId],
        hash: hash,
        previousHash: previousHash,
        accent: category.accent,
        payload: payload,
        sceneReview: sceneReview,
      ),
    );
    previousHash = hash;
  }

  return built.reversed.toList(growable: false);
}

Map<String, Object?> _payloadForEvent(
  DispatchEvent event, {
  MonitoringSceneReviewRecord? sceneReview,
}) {
  final payload = <String, Object?>{
    'event_id': event.eventId,
    'sequence': event.sequence,
    'type': event.toAuditTypeKey(),
    'occurred_at_utc': event.occurredAt.toUtc().toIso8601String(),
    'client_id': _eventClientId(event),
    'site_id': _eventSiteId(event),
    'summary': _titleForEvent(event),
  };

  if (event is IntelligenceReceived) {
    payload['intelligence_id'] = event.intelligenceId;
    payload['provider'] = event.provider;
    payload['source_type'] = event.sourceType;
    payload['risk_score'] = event.riskScore;
    payload['headline'] = event.headline;
    payload['summary_text'] = event.summary;
  } else if (event is PatrolCompleted) {
    payload['guard_id'] = event.guardId;
    payload['route_id'] = event.routeId;
    payload['duration_seconds'] = event.durationSeconds;
  } else if (event is GuardCheckedIn) {
    payload['guard_id'] = event.guardId;
  } else if (event is DecisionCreated) {
    payload['dispatch_id'] = event.dispatchId;
  } else if (event is ResponseArrived) {
    payload['dispatch_id'] = event.dispatchId;
    payload['guard_id'] = event.guardId;
  } else if (event is IncidentClosed) {
    payload['dispatch_id'] = event.dispatchId;
    payload['resolution_type'] = event.resolutionType;
  } else if (event is ExecutionCompleted) {
    payload['dispatch_id'] = event.dispatchId;
    payload['success'] = event.success;
  } else if (event is ExecutionDenied) {
    payload['dispatch_id'] = event.dispatchId;
    payload['operator_id'] = event.operatorId;
    payload['reason'] = event.reason;
  } else if (event is ReportGenerated) {
    payload['month'] = event.month;
    payload['event_count'] = event.eventCount;
    payload['report_schema_version'] = event.reportSchemaVersion;
  } else if (event is PartnerDispatchStatusDeclared) {
    payload['dispatch_id'] = event.dispatchId;
    payload['partner_label'] = event.partnerLabel;
    payload['status'] = event.status.name;
  } else if (event is VehicleVisitReviewRecorded) {
    payload['vehicle_label'] = event.vehicleLabel;
    payload['status'] = event.effectiveStatusLabel;
    payload['workflow_summary'] = event.workflowSummary;
  }

  if (sceneReview != null) {
    payload['sceneReview'] = <String, Object?>{
      'source_label': sceneReview.sourceLabel,
      'posture_label': sceneReview.postureLabel,
      if (sceneReview.decisionLabel.trim().isNotEmpty)
        'decision_label': sceneReview.decisionLabel,
      if (sceneReview.decisionSummary.trim().isNotEmpty)
        'decision_summary': sceneReview.decisionSummary,
      'summary': sceneReview.summary,
      'reviewed_at_utc': sceneReview.reviewedAtUtc.toIso8601String(),
      if (sceneReview.evidenceRecordHash.trim().isNotEmpty)
        'evidence_record_hash': sceneReview.evidenceRecordHash,
    };
  }

  return payload;
}

String _titleForEvent(DispatchEvent event) {
  if (event is IntelligenceReceived) {
    return event.headline.trim().isEmpty
        ? 'AI observation logged'
        : event.headline;
  }
  if (event is PatrolCompleted) {
    return 'Patrol completed - ${_displaySiteLabel(event.siteId)}';
  }
  if (event is GuardCheckedIn) {
    return 'Shift handover captured';
  }
  if (event is DecisionCreated) {
    return 'Controller dispatched response';
  }
  if (event is ResponseArrived) {
    return '${_callsignFromGuardId(event.guardId)} arrived on site';
  }
  if (event is IncidentClosed) {
    return 'Incident closed - ${_displaySiteLabel(event.siteId)}';
  }
  if (event is ExecutionCompleted) {
    return event.success
        ? 'Alarm workflow completed'
        : 'Alarm workflow closed with errors';
  }
  if (event is ExecutionDenied) {
    return 'Alarm trigger denied for execution';
  }
  if (event is ReportGenerated) {
    return 'Shift report generated';
  }
  if (event is PartnerDispatchStatusDeclared) {
    return '${event.partnerLabel} updated dispatch status';
  }
  if (event is VehicleVisitReviewRecorded) {
    return '${event.vehicleLabel} visit reviewed';
  }
  return event.eventId;
}

String _descriptionForEvent(
  DispatchEvent event, {
  MonitoringSceneReviewRecord? sceneReview,
}) {
  if (event is IntelligenceReceived) {
    if (sceneReview != null && sceneReview.decisionSummary.trim().isNotEmpty) {
      return sceneReview.decisionSummary;
    }
    return event.summary.trim().isEmpty
        ? 'AI surfaced a new item for controller review.'
        : event.summary;
  }
  if (event is PatrolCompleted) {
    return '${_displayGuardLabel(event.guardId)} completed route ${_displayRouteLabel(event.routeId)} in ${_durationLabel(event.durationSeconds)}.';
  }
  if (event is GuardCheckedIn) {
    return '${_displayGuardLabel(event.guardId)} checked in for the current shift and handover continuity was recorded.';
  }
  if (event is DecisionCreated) {
    return 'Dispatch ${event.dispatchId} was opened for ${_displaySiteLabel(event.siteId)} after controller review.';
  }
  if (event is ResponseArrived) {
    return '${_displayGuardLabel(event.guardId)} arrived for dispatch ${event.dispatchId} and the response timeline was updated.';
  }
  if (event is IncidentClosed) {
    return 'Incident ${event.dispatchId} closed as ${_humanizeIdentifier(event.resolutionType)}.';
  }
  if (event is ExecutionCompleted) {
    return event.success
        ? 'Execution completed successfully and the action was sealed into the record.'
        : 'Execution reported a failure and requires review.';
  }
  if (event is ExecutionDenied) {
    return event.reason.trim().isEmpty
        ? 'Execution was denied and the alarm record now needs operator review.'
        : event.reason;
  }
  if (event is ReportGenerated) {
    return 'Generated report for ${_displaySiteLabel(event.siteId)} using ${event.eventCount} source events.';
  }
  if (event is PartnerDispatchStatusDeclared) {
    return '${event.partnerLabel} marked the dispatch as ${event.status.name}.';
  }
  if (event is VehicleVisitReviewRecorded) {
    return event.workflowSummary.trim().isEmpty
        ? '${event.vehicleLabel} review recorded.'
        : event.workflowSummary;
  }
  return 'Operational record created.';
}

_ObCategory _categoryForEvent(DispatchEvent event) {
  if (event is PatrolCompleted) {
    return _ObCategory.patrol;
  }
  if (event is GuardCheckedIn || event is ReportGenerated) {
    return _ObCategory.handover;
  }
  if (event is VehicleVisitReviewRecorded) {
    return _ObCategory.vehicle;
  }
  if (event is ExecutionCompleted || event is ExecutionDenied) {
    return _ObCategory.alarm;
  }
  if (event is DecisionCreated ||
      event is ResponseArrived ||
      event is IncidentClosed ||
      event is PartnerDispatchStatusDeclared) {
    return _ObCategory.incident;
  }
  if (event is IntelligenceReceived) {
    final narrative = '${event.headline} ${event.summary}'.toLowerCase();
    if (narrative.contains('vehicle') || narrative.contains('car')) {
      return _ObCategory.vehicle;
    }
    if (narrative.contains('alarm') ||
        narrative.contains('breach') ||
        narrative.contains('distress') ||
        narrative.contains('movement') ||
        narrative.contains('intrusion')) {
      return _ObCategory.incident;
    }
  }
  return _ObCategory.other;
}

String _guardLabelForEvent(DispatchEvent event) {
  if (event is PatrolCompleted) {
    return _displayGuardLabel(event.guardId);
  }
  if (event is GuardCheckedIn) {
    return _displayGuardLabel(event.guardId);
  }
  if (event is ResponseArrived) {
    return _displayGuardLabel(event.guardId);
  }
  if (event is PartnerDispatchStatusDeclared) {
    return event.actorLabel.trim().isEmpty
        ? event.partnerLabel
        : event.actorLabel;
  }
  if (event is VehicleVisitReviewRecorded) {
    return event.actorLabel.trim().isEmpty
        ? 'Controller Desk'
        : event.actorLabel;
  }
  if (event is IntelligenceReceived) {
    return 'ONYX AI';
  }
  return 'Controller Desk';
}

String _callsignForEvent(DispatchEvent event) {
  if (event is PatrolCompleted) {
    return _callsignFromGuardId(event.guardId);
  }
  if (event is GuardCheckedIn) {
    return _callsignFromGuardId(event.guardId);
  }
  if (event is ResponseArrived) {
    return _callsignFromGuardId(event.guardId);
  }
  if (event is PartnerDispatchStatusDeclared) {
    return event.partnerLabel;
  }
  if (event is VehicleVisitReviewRecorded) {
    return event.actorLabel.trim().isEmpty ? 'Command' : event.actorLabel;
  }
  if (event is IntelligenceReceived) {
    return 'AI Watch';
  }
  return 'Command';
}

String _locationForEvent(DispatchEvent event) {
  if (event is IntelligenceReceived) {
    if ((event.zone ?? '').trim().isNotEmpty) {
      return _humanizeIdentifier(event.zone!);
    }
    if ((event.cameraId ?? '').trim().isNotEmpty) {
      return _humanizeIdentifier(event.cameraId!);
    }
    return 'Restricted zone review';
  }
  if (event is PatrolCompleted) {
    return 'Route ${_displayRouteLabel(event.routeId)}';
  }
  if (event is GuardCheckedIn) {
    return 'Shift handover desk';
  }
  if (event is DecisionCreated) {
    return 'Controller desk';
  }
  if (event is ResponseArrived) {
    return _displaySiteLabel(event.siteId);
  }
  if (event is IncidentClosed) {
    return _displaySiteLabel(event.siteId);
  }
  if (event is ExecutionCompleted || event is ExecutionDenied) {
    return 'Alarm response lane';
  }
  if (event is ReportGenerated) {
    return 'Shift report archive';
  }
  if (event is PartnerDispatchStatusDeclared) {
    return event.sourceChannel;
  }
  if (event is VehicleVisitReviewRecorded) {
    return event.reasonLabel.trim().isEmpty
        ? _displaySiteLabel(event.siteId)
        : event.reasonLabel;
  }
  return 'Operations';
}

bool _isIncidentEvent(DispatchEvent event) {
  return event is DecisionCreated ||
      event is ResponseArrived ||
      event is IncidentClosed ||
      event is ExecutionCompleted ||
      event is ExecutionDenied ||
      (event is IntelligenceReceived && event.riskScore >= 75);
}

bool _isFlaggedEvent(
  DispatchEvent event, {
  MonitoringSceneReviewRecord? sceneReview,
}) {
  if (sceneReview != null) {
    return true;
  }
  if (event is IntelligenceReceived) {
    return event.riskScore >= 90;
  }
  if (event is ExecutionDenied) {
    return true;
  }
  return false;
}

String _eventClientId(DispatchEvent event) {
  if (event is DecisionCreated) return event.clientId;
  if (event is ResponseArrived) return event.clientId;
  if (event is PartnerDispatchStatusDeclared) return event.clientId;
  if (event is VehicleVisitReviewRecorded) return event.clientId;
  if (event is GuardCheckedIn) return event.clientId;
  if (event is ExecutionCompleted) return event.clientId;
  if (event is ExecutionDenied) return event.clientId;
  if (event is IntelligenceReceived) return event.clientId;
  if (event is PatrolCompleted) return event.clientId;
  if (event is IncidentClosed) return event.clientId;
  if (event is ReportGenerated) return event.clientId;
  return '';
}

String _eventSiteId(DispatchEvent event) {
  if (event is DecisionCreated) return event.siteId;
  if (event is ResponseArrived) return event.siteId;
  if (event is PartnerDispatchStatusDeclared) return event.siteId;
  if (event is VehicleVisitReviewRecorded) return event.siteId;
  if (event is GuardCheckedIn) return event.siteId;
  if (event is ExecutionCompleted) return event.siteId;
  if (event is ExecutionDenied) return event.siteId;
  if (event is IntelligenceReceived) return event.siteId;
  if (event is PatrolCompleted) return event.siteId;
  if (event is IncidentClosed) return event.siteId;
  if (event is ReportGenerated) return event.siteId;
  return '';
}

Map<String, Object?> _entryToJson(_ObEntryView entry) {
  return <String, Object?>{
    'id': entry.id,
    'record_code': entry.recordCode,
    'sequence': entry.sequence,
    'category': entry.category.storageKey,
    'title': entry.title,
    'description': entry.description,
    'occurred_at_utc': entry.occurredAt.toIso8601String(),
    'site': entry.siteLabel,
    'guard': entry.guardLabel,
    'callsign': entry.callsign,
    'location_detail': entry.locationDetail,
    'incident': entry.incident,
    'flagged': entry.flagged,
    'verified': entry.verified,
    'status': entry.statusLabel,
    'linked_event_ids': entry.linkedEventIds,
    'hash': entry.hash,
    'previous_hash': entry.previousHash,
    if (entry.sceneReview != null)
      'sceneReview': <String, Object?>{
        'source_label': entry.sceneReview!.sourceLabel,
        'posture_label': entry.sceneReview!.postureLabel,
        if (entry.sceneReview!.decisionLabel.trim().isNotEmpty)
          'decision_label': entry.sceneReview!.decisionLabel,
        if (entry.sceneReview!.decisionSummary.trim().isNotEmpty)
          'decision_summary': entry.sceneReview!.decisionSummary,
        'summary': entry.sceneReview!.summary,
        'reviewed_at_utc': entry.sceneReview!.reviewedAtUtc.toIso8601String(),
        if (entry.sceneReview!.evidenceRecordHash.trim().isNotEmpty)
          'evidence_record_hash': entry.sceneReview!.evidenceRecordHash,
      },
    'payload': entry.payload,
  };
}

List<_ObEntryView> _relatedEntriesForSelected(
  List<_ObEntryView> entries,
  _ObEntryView selected,
) {
  return entries
      .where(
        (entry) =>
            entry.id != selected.id &&
            (entry.siteLabel == selected.siteLabel ||
                entry.guardLabel == selected.guardLabel),
      )
      .take(3)
      .toList(growable: false);
}

List<_GuardPreset> _buildGuardPresets(List<_ObEntryView> entries) {
  final presetsByKey = <String, _GuardPreset>{};
  for (final entry in entries) {
    if (entry.guardLabel == 'Controller Desk' ||
        entry.guardLabel == 'ONYX AI') {
      continue;
    }
    final preset = _GuardPreset(
      key: '${entry.callsign}|${entry.guardLabel}|${entry.siteLabel}',
      callsign: entry.callsign,
      guardName: entry.guardLabel,
      siteLabel: entry.siteLabel,
    );
    presetsByKey.putIfAbsent(preset.key, () => preset);
  }
  for (final preset in _defaultGuardPresets) {
    presetsByKey.putIfAbsent(preset.key, () => preset);
  }
  return presetsByKey.values.toList(growable: false);
}

List<String> _buildSiteOptions(List<_ObEntryView> entries) {
  final sites = <String>{};
  for (final entry in entries) {
    if (entry.siteLabel.trim().isNotEmpty) {
      sites.add(entry.siteLabel);
    }
  }
  for (final preset in _defaultGuardPresets) {
    sites.add(preset.siteLabel);
  }
  final ordered = sites.toList()..sort();
  return ordered;
}

_GuardPreset _resolvePresetByKey(List<_GuardPreset> presets, String key) {
  for (final preset in presets) {
    if (preset.key == key) {
      return preset;
    }
  }
  return presets.isNotEmpty ? presets.first : _defaultGuardPresets.first;
}

bool _matchesCategory(_ObEntryView entry, _ObCategory filter) {
  return filter == _ObCategory.all || entry.category == filter;
}

bool _matchesSearch(_ObEntryView entry, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final haystack = [
    entry.recordCode,
    entry.title,
    entry.description,
    entry.siteLabel,
    entry.guardLabel,
    entry.callsign,
    entry.locationDetail,
    ...entry.linkedEventIds,
  ].join(' ').toLowerCase();
  return haystack.contains(normalized);
}

String? _resolveSelectedEntryId({
  required List<_ObEntryView> entries,
  required String? currentId,
  required String focusReference,
}) {
  if (entries.isEmpty) {
    return null;
  }
  if (currentId != null && entries.any((entry) => entry.id == currentId)) {
    return currentId;
  }
  final normalizedFocus = focusReference.trim().toLowerCase();
  if (normalizedFocus.isNotEmpty) {
    for (final entry in entries) {
      final fields = [
        entry.id,
        entry.recordCode,
        entry.title,
        entry.description,
        entry.siteLabel,
        ...entry.linkedEventIds,
      ].join(' ').toLowerCase();
      if (fields.contains(normalizedFocus)) {
        return entry.id;
      }
    }
  }
  for (final entry in entries) {
    if (entry.linkedEventIds.isNotEmpty) {
      return entry.id;
    }
  }
  return entries.first.id;
}

int _sortEntriesDescending(_ObEntryView a, _ObEntryView b) {
  final byTime = b.occurredAt.compareTo(a.occurredAt);
  if (byTime != 0) {
    return byTime;
  }
  return b.sequence.compareTo(a.sequence);
}

bool _verifyChain(List<_ObEntryView> entries) {
  if (entries.length < 2) {
    return true;
  }
  final ordered = [...entries]..sort(_sortEntriesDescending);
  for (var i = 0; i < ordered.length - 1; i++) {
    if (ordered[i].previousHash != ordered[i + 1].hash) {
      return false;
    }
  }
  return true;
}

int _nextSequence(List<_ObEntryView> entries) {
  var maxSequence = 2441;
  for (final entry in entries) {
    if (entry.sequence > maxSequence) {
      maxSequence = entry.sequence;
    }
  }
  return maxSequence + 1;
}

int _nextRecordNumber(List<_ObEntryView> entries) {
  var maxRecordNumber = 2441;
  final matcher = RegExp(r'(\d+)$');
  for (final entry in entries) {
    final match = matcher.firstMatch(entry.recordCode);
    if (match == null) {
      continue;
    }
    final value = int.tryParse(match.group(1)!);
    if (value != null && value > maxRecordNumber) {
      maxRecordNumber = value;
    }
  }
  return maxRecordNumber + 1;
}

String _manualEntryTitle(_ObCategory category, String description) {
  final clean = description.trim();
  if (clean.isEmpty) {
    return '${category.label} entry';
  }
  final words = clean.split(RegExp(r'\s+'));
  final headline = words.take(6).join(' ');
  return headline[0].toUpperCase() + headline.substring(1);
}

bool _isSameUtcDate(DateTime a, DateTime b) {
  final left = a.toUtc();
  final right = b.toUtc();
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatUtcTimestamp(DateTime dateTime) {
  final utc = dateTime.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')} ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')} UTC';
}

String _formatComposerTimestamp(DateTime dateTime) {
  final utc = dateTime.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}/${utc.month.toString().padLeft(2, '0')}/${utc.day.toString().padLeft(2, '0')}, ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}

String _hashPreview(String value) {
  if (value.length <= 24) {
    return value;
  }
  return '${value.substring(0, 24)}...';
}

String _displayClientLabel(String raw) {
  if (raw.trim().isEmpty) {
    return 'Client';
  }
  return _humanizeIdentifier(raw);
}

String _displaySiteLabel(String raw) {
  final normalized = raw.trim();
  const overrides = <String, String>{
    'SITE-SANDTON': 'Sandton Estate',
    'SITE-MIDRAND': 'Midrand Logistics Hub',
    'SITE-NORTH-GATE': 'North Gate',
    'SITE-RIVERSIDE': 'Riverside Estate',
  };
  if (normalized.isEmpty) {
    return 'Unassigned Site';
  }
  return overrides[normalized] ?? _humanizeIdentifier(normalized);
}

String _displayGuardLabel(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return 'Unassigned Guard';
  }
  return _humanizeIdentifier(normalized);
}

String _callsignFromGuardId(String raw) {
  final digits = RegExp(r'(\d+)').firstMatch(raw.trim())?.group(1);
  if (digits != null && digits.isNotEmpty) {
    return 'Echo-$digits';
  }
  return _humanizeIdentifier(raw);
}

String _displayRouteLabel(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return 'Route';
  }
  return _humanizeIdentifier(normalized);
}

String _durationLabel(int seconds) {
  if (seconds <= 0) {
    return '0m';
  }
  final minutes = (seconds / 60).round();
  return '${minutes}m';
}

String _humanizeIdentifier(String raw) {
  final normalized = raw
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return raw;
  }
  return normalized
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        final lower = word.toLowerCase();
        if (lower.length <= 2 && lower == word.toUpperCase()) {
          return word;
        }
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
