import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/domain/events/decision_created.dart';
import 'package:omnix_dashboard/domain/events/intelligence_received.dart';
import 'package:omnix_dashboard/domain/intelligence/intel_ingestion.dart';
import 'package:omnix_dashboard/domain/intelligence/triage_policy.dart';

void main() {
  group('IntelligenceTriagePolicy', () {
    const policy = IntelligenceTriagePolicy();

    test('marks corroborated high-risk intel as dispatch candidate', () {
      final now = DateTime.utc(2026, 3, 6, 10, 0);
      final item = IntelligenceReceived(
        eventId: 'E-1',
        sequence: 1,
        version: 1,
        occurredAt: now,
        intelligenceId: 'INT-1',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'N-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed robbery near perimeter gate',
        summary: 'Vehicle and suspects near entry point',
        riskScore: 86,
        canonicalHash: 'hash-1',
      );
      final corroborating = IntelligenceReceived(
        eventId: 'E-2',
        sequence: 2,
        version: 1,
        occurredAt: now.add(const Duration(minutes: 3)),
        intelligenceId: 'INT-2',
        provider: 'community-feed',
        sourceType: 'community',
        externalId: 'C-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Community alert reports robbery near perimeter gate',
        summary: 'Witness reports suspicious vehicle near entry',
        riskScore: 71,
        canonicalHash: 'hash-2',
      );

      final assessment = policy.evaluateReceived(
        item: item,
        allIntel: [item, corroborating],
        decisions: const [],
      );

      expect(assessment.corroborated, isTrue);
      expect(
        assessment.recommendation,
        IntelligenceRecommendation.dispatchCandidate,
      );
      expect(assessment.shouldEscalate, isTrue);
      expect(assessment.predictiveScore, greaterThanOrEqualTo(80));
    });

    test('returns advisory for low-risk isolated intel', () {
      final now = DateTime.utc(2026, 3, 6, 11, 0);
      final item = IntelligenceReceived(
        eventId: 'E-3',
        sequence: 1,
        version: 1,
        occurredAt: now,
        intelligenceId: 'INT-3',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'N-2',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Routine traffic update',
        summary: 'Normal vehicle flow around sector 3',
        riskScore: 34,
        canonicalHash: 'hash-3',
      );

      final assessment = policy.evaluateReceived(
        item: item,
        allIntel: [item],
        decisions: const [],
      );

      expect(assessment.corroborated, isFalse);
      expect(assessment.recommendation, IntelligenceRecommendation.advisory);
      expect(assessment.shouldEscalate, isFalse);
    });

    test('dismissed item never escalates', () {
      final now = DateTime.utc(2026, 3, 6, 11, 30);
      final item = IntelligenceReceived(
        eventId: 'E-4',
        sequence: 1,
        version: 1,
        occurredAt: now,
        intelligenceId: 'INT-4',
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'N-3',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'High-risk signal',
        summary: 'Potential armed incident',
        riskScore: 95,
        canonicalHash: 'hash-4',
      );

      final assessment = policy.evaluateReceived(
        item: item,
        allIntel: [item],
        decisions: const [],
        dismissed: true,
      );

      expect(assessment.recommendation, IntelligenceRecommendation.advisory);
      expect(assessment.shouldEscalate, isFalse);
      expect(assessment.predictiveScore, 0);
    });

    test('normalized record can escalate from nearby dispatch context', () {
      final now = DateTime.utc(2026, 3, 6, 12, 0);
      final record = NormalizedIntelRecord(
        provider: 'newsapi.org',
        sourceType: 'news',
        externalId: 'N-4',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
        headline: 'Armed suspects seen near complex gate',
        summary: 'Escalation risk near entry',
        riskScore: 82,
        occurredAtUtc: DateTime.utc(2026, 3, 6, 12, 0),
      );
      final decision = DecisionCreated(
        eventId: 'DEC-1',
        sequence: 1,
        version: 1,
        occurredAt: now.add(const Duration(minutes: 5)),
        dispatchId: 'DSP-1',
        clientId: 'CLIENT-001',
        regionId: 'REGION-GAUTENG',
        siteId: 'SITE-SANDTON',
      );

      final assessment = policy.evaluateNormalizedRecord(
        record: record,
        decisions: [decision],
      );

      expect(assessment.recentDispatchNearby, isTrue);
      expect(assessment.corroborated, isTrue);
      expect(
        assessment.recommendation,
        IntelligenceRecommendation.dispatchCandidate,
      );
      expect(assessment.shouldEscalate, isTrue);
    });
  });
}
