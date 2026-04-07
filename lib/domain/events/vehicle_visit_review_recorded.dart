import 'dispatch_event.dart';

class VehicleVisitReviewRecorded extends DispatchEvent {
  static const String auditTypeKey = 'vehicle_visit_review_recorded';
  final String vehicleVisitKey;
  final String primaryEventId;
  final String clientId;
  final String regionId;
  final String siteId;
  final String vehicleLabel;
  final String actorLabel;
  final bool reviewed;
  final String statusOverride;
  final String effectiveStatusLabel;
  final String reasonLabel;
  final String workflowSummary;
  final String sourceSurface;

  const VehicleVisitReviewRecorded({
    required super.eventId,
    required super.sequence,
    required super.version,
    required super.occurredAt,
    required this.vehicleVisitKey,
    required this.primaryEventId,
    required this.clientId,
    required this.regionId,
    required this.siteId,
    required this.vehicleLabel,
    required this.actorLabel,
    required this.reviewed,
    required this.statusOverride,
    required this.effectiveStatusLabel,
    required this.reasonLabel,
    required this.workflowSummary,
    required this.sourceSurface,
  });

  @override
  VehicleVisitReviewRecorded copyWithSequence(int sequence) {
    return VehicleVisitReviewRecorded(
      eventId: eventId,
      sequence: sequence,
      version: version,
      occurredAt: occurredAt,
      vehicleVisitKey: vehicleVisitKey,
      primaryEventId: primaryEventId,
      clientId: clientId,
      regionId: regionId,
      siteId: siteId,
      vehicleLabel: vehicleLabel,
      actorLabel: actorLabel,
      reviewed: reviewed,
      statusOverride: statusOverride,
      effectiveStatusLabel: effectiveStatusLabel,
      reasonLabel: reasonLabel,
      workflowSummary: workflowSummary,
      sourceSurface: sourceSurface,
    );
  }

  @override
  String toAuditTypeKey() => auditTypeKey;
}
