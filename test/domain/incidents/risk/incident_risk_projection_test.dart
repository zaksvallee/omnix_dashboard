import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/incidents/incident_enums.dart';
import 'package:omnix_dashboard/domain/incidents/incident_event.dart';
import 'package:omnix_dashboard/domain/incidents/risk/incident_risk_projection.dart';
import 'package:omnix_dashboard/domain/incidents/risk/risk_tag.dart';

void main() {
  group('IncidentRiskProjection.extractTags', () {
    test('returns only events that include risk_tag metadata', () {
      final events = <IncidentEvent>[
        const IncidentEvent(
          eventId: 'event-1',
          incidentId: 'INC-1',
          type: IncidentEventType.incidentDetected,
          timestamp: '2026-04-07T08:00:00Z',
          metadata: <String, dynamic>{},
        ),
        const IncidentEvent(
          eventId: 'event-2',
          incidentId: 'INC-1',
          type: IncidentEventType.incidentClassified,
          timestamp: '2026-04-07T08:05:00Z',
          metadata: <String, dynamic>{
            'risk_tag': 'perimeter_breach',
            'weight': 30,
          },
        ),
      ];

      final tags = IncidentRiskProjection.extractTags(events);

      expect(tags, hasLength(1));
      expect(tags.single.tag, 'perimeter_breach');
      expect(tags.single.weight, 30);
      expect(tags.single.addedAt, '2026-04-07T08:05:00Z');
    });
  });

  group('IncidentRiskProjection.computeRiskScore', () {
    test('returns zero for an empty tag list', () {
      expect(IncidentRiskProjection.computeRiskScore(const <RiskTag>[]), 0);
    });

    test('sums weights across all extracted tags', () {
      final tags = <RiskTag>[
        const RiskTag(tag: 'a', weight: 30, addedAt: '2026-04-07T08:00:00Z'),
        const RiskTag(tag: 'b', weight: 25, addedAt: '2026-04-07T08:01:00Z'),
      ];

      expect(IncidentRiskProjection.computeRiskScore(tags), 55);
    });
  });

  group('IncidentRiskProjection.deriveSeverity', () {
    test('treats 19 as low and 20 as medium', () {
      expect(IncidentRiskProjection.deriveSeverity(19), IncidentSeverity.low);
      expect(IncidentRiskProjection.deriveSeverity(20), IncidentSeverity.medium);
    });

    test('treats 49 as medium and 50 as high', () {
      expect(IncidentRiskProjection.deriveSeverity(49), IncidentSeverity.medium);
      expect(IncidentRiskProjection.deriveSeverity(50), IncidentSeverity.high);
    });

    test('treats 79 as high and 80 as critical', () {
      expect(IncidentRiskProjection.deriveSeverity(79), IncidentSeverity.high);
      expect(
        IncidentRiskProjection.deriveSeverity(80),
        IncidentSeverity.critical,
      );
    });
  });
}
