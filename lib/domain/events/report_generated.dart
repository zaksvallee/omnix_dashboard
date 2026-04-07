import 'dispatch_event.dart';
import '../crm/reporting/report_branding_configuration.dart';
import '../crm/reporting/report_section_configuration.dart';

class ReportGenerated extends DispatchEvent {
  static const String auditTypeKey = 'report_generated';
  final String clientId;
  final String siteId;
  final String month;
  final String contentHash;
  final String pdfHash;
  final int eventRangeStart;
  final int eventRangeEnd;
  final int eventCount;
  final int reportSchemaVersion;
  final int projectionVersion;
  final String primaryBrandLabel;
  final String endorsementLine;
  final String brandingSourceLabel;
  final bool brandingUsesOverride;
  final String investigationContextKey;
  final bool includeTimeline;
  final bool includeDispatchSummary;
  final bool includeCheckpointCompliance;
  final bool includeAiDecisionLog;
  final bool includeGuardMetrics;

  const ReportGenerated({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.clientId,
    required this.siteId,
    required this.month,
    required this.contentHash,
    required this.pdfHash,
    required this.eventRangeStart,
    required this.eventRangeEnd,
    required this.eventCount,
    required this.reportSchemaVersion,
    required this.projectionVersion,
    this.primaryBrandLabel = '',
    this.endorsementLine = '',
    this.brandingSourceLabel = '',
    this.brandingUsesOverride = false,
    this.investigationContextKey = '',
    this.includeTimeline = true,
    this.includeDispatchSummary = true,
    this.includeCheckpointCompliance = true,
    this.includeAiDecisionLog = true,
    this.includeGuardMetrics = true,
  });

  ReportSectionConfiguration get sectionConfiguration =>
      ReportSectionConfiguration(
        includeTimeline: includeTimeline,
        includeDispatchSummary: includeDispatchSummary,
        includeCheckpointCompliance: includeCheckpointCompliance,
        includeAiDecisionLog: includeAiDecisionLog,
        includeGuardMetrics: includeGuardMetrics,
      );

  ReportBrandingConfiguration get brandingConfiguration =>
      ReportBrandingConfiguration(
        primaryLabel: primaryBrandLabel,
        endorsementLine: endorsementLine,
        sourceLabel: brandingSourceLabel,
        usesOverride: brandingUsesOverride,
      );

  @override
  ReportGenerated copyWithSequence(int sequence) {
    return ReportGenerated(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      clientId: clientId,
      siteId: siteId,
      month: month,
      contentHash: contentHash,
      pdfHash: pdfHash,
      eventRangeStart: eventRangeStart,
      eventRangeEnd: eventRangeEnd,
      eventCount: eventCount,
      reportSchemaVersion: reportSchemaVersion,
      projectionVersion: projectionVersion,
      primaryBrandLabel: primaryBrandLabel,
      endorsementLine: endorsementLine,
      brandingSourceLabel: brandingSourceLabel,
      brandingUsesOverride: brandingUsesOverride,
      investigationContextKey: investigationContextKey,
      includeTimeline: includeTimeline,
      includeDispatchSummary: includeDispatchSummary,
      includeCheckpointCompliance: includeCheckpointCompliance,
      includeAiDecisionLog: includeAiDecisionLog,
      includeGuardMetrics: includeGuardMetrics,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
