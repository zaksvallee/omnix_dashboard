import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/intelligence/decision_service.dart';
import 'package:omnix_dashboard/domain/intelligence/news_item.dart';
import 'package:omnix_dashboard/domain/intelligence/risk_policy.dart';

void main() {
  test(
    'DecisionService uses one injected clock value for escalation events',
    () {
      final service = DecisionService(
        const RiskPolicy(escalationThreshold: 70),
      );
      final item = NewsItem(
        id: 'NEWS-1',
        title: 'Escalate this',
        source: 'unit-test',
        summary: 'Escalation threshold crossed.',
        riskScore: 91,
        clientId: 'CLIENT-001',
        regionId: 'REGION-001',
        siteId: 'SITE-001',
      );

      final result = service.evaluate(
        item,
        clientId: 'CLIENT-001',
        regionId: 'REGION-001',
        siteId: 'SITE-001',
        clock: () => DateTime.utc(2026, 4, 7, 10, 15, 30, 456, 789),
      );

      expect(result, isNotNull);
      expect(result!.eventId, '1775556930456789');
      expect(result.occurredAt, DateTime.utc(2026, 4, 7, 10, 15, 30, 456, 789));
      expect(result.dispatchId, 'DSP-NEWS-1');
    },
  );
}
