import '../domain/events/intelligence_received.dart';

const _genericObjectLabels = <String>{'movement', 'motion', 'unknown'};

String resolveIdentityBackedObjectLabelFromSignals({
  required String directObjectLabel,
  String? faceMatchId,
  String? plateNumber,
  Set<String> genericObjectLabels = _genericObjectLabels,
}) {
  final trimmed = directObjectLabel.trim();
  final normalized = trimmed.toLowerCase();
  if (normalized.isNotEmpty && !genericObjectLabels.contains(normalized)) {
    return trimmed;
  }
  if ((faceMatchId ?? '').trim().isNotEmpty) {
    return 'person';
  }
  if ((plateNumber ?? '').trim().isNotEmpty) {
    return 'vehicle';
  }
  return trimmed;
}

String resolveIdentityBackedObjectLabel({
  required IntelligenceReceived event,
  required String directObjectLabel,
  Set<String> genericObjectLabels = _genericObjectLabels,
}) {
  return resolveIdentityBackedObjectLabelFromSignals(
    directObjectLabel: directObjectLabel,
    faceMatchId: event.faceMatchId,
    plateNumber: event.plateNumber,
    genericObjectLabels: genericObjectLabels,
  );
}
