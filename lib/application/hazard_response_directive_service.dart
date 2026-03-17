class HazardResponseDirectives {
  final String signal;
  final String dispatchDirective;
  final String welfareDirective;
  final String initiatedDispatchLine;

  const HazardResponseDirectives({
    required this.signal,
    required this.dispatchDirective,
    required this.welfareDirective,
    required this.initiatedDispatchLine,
  });

  bool get hasHazard => signal.isNotEmpty;
}

class HazardResponseDirectiveService {
  const HazardResponseDirectiveService();

  HazardResponseDirectives build({
    required String postureLabel,
    String objectLabel = '',
    required String siteName,
  }) {
    final signal = _resolveSignal(
      postureLabel: postureLabel,
      objectLabel: objectLabel,
    );
    final normalizedSiteName = siteName.trim().isEmpty ? 'the site' : siteName.trim();
    return switch (signal) {
      'fire' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage fire response to $normalizedSiteName and prioritize flame or smoke containment on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Fire response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
      ),
      'water_leak' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage leak containment to $normalizedSiteName and prioritize water-loss control on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Leak containment has been staged while ONYX keeps the client safety and occupant welfare lane active.',
      ),
      'environment_hazard' => HazardResponseDirectives(
        signal: signal,
        dispatchDirective:
            'Stage site safety response to $normalizedSiteName and prioritize hazard isolation on arrival.',
        welfareDirective:
            'Confirm occupant welfare status for $normalizedSiteName as part of the first partner update.',
        initiatedDispatchLine:
            'Site safety response has been staged while ONYX keeps the client safety and occupant welfare lane active.',
      ),
      _ => const HazardResponseDirectives(
        signal: '',
        dispatchDirective: '',
        welfareDirective: '',
        initiatedDispatchLine: '',
      ),
    };
  }

  String _resolveSignal({
    required String postureLabel,
    required String objectLabel,
  }) {
    final posture = postureLabel.trim().toLowerCase();
    final object = objectLabel.trim().toLowerCase();
    if (posture.contains('fire') ||
        posture.contains('smoke') ||
        object == 'fire' ||
        object == 'smoke') {
      return 'fire';
    }
    if (posture.contains('flood') ||
        posture.contains('leak') ||
        object == 'water' ||
        object == 'leak') {
      return 'water_leak';
    }
    if (posture.contains('hazard') || object == 'equipment') {
      return 'environment_hazard';
    }
    return '';
  }
}
