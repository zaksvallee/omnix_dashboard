import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/domain/intelligence/news_item.dart';
import 'package:omnix_dashboard/domain/intelligence/risk_policy.dart'
    as intelligence;
import 'package:omnix_dashboard/domain/policy/risk_policy.dart' as policy;
import 'package:omnix_dashboard/domain/risk/risk_policy.dart' as risk;

void main() {
  test('all risk policy import paths resolve to canonical behavior', () {
    const intelPolicy = intelligence.RiskPolicy(escalationThreshold: 70);
    const policyPath = policy.RiskPolicy(escalationThreshold: 70);
    const riskPath = risk.RiskPolicy(escalationThreshold: 70);
    const item = NewsItem(
      id: 'NEWS-1',
      title: 'Signal cluster',
      summary: 'Multiple perimeter pings.',
      riskScore: 75,
      source: 'test',
      clientId: 'CLIENT-001',
      regionId: 'REGION-GP',
      siteId: 'SITE-SANDTON',
    );

    expect(intelPolicy.shouldEscalate(item), isTrue);
    expect(policyPath.shouldEscalate(item), isTrue);
    expect(riskPath.shouldEscalate(item), isTrue);
  });
}
