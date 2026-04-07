import 'package:flutter_test/flutter_test.dart';

import 'package:omnix_dashboard/application/admin_write_follow_up_policy.dart';

void main() {
  test('treats follow-up failures as success when the primary write completed', () {
    final outcome = resolveAdminWriteFollowUpOutcome(
      primaryWriteCompleted: true,
      failureMessage: 'Failed to save client.',
      successWarningMessage: 'Client CLIENT-1 saved with follow-up warning.',
      successWarningDetail:
          'The client record was saved before a later follow-up step failed',
      failureDetailPrefix: 'Client save failed',
      error: StateError('directory refresh failed'),
    );

    expect(outcome.treatAsSuccess, isTrue);
    expect(
      outcome.message,
      'Client CLIENT-1 saved with follow-up warning.',
    );
    expect(
      outcome.detail,
      contains(
        'The client record was saved before a later follow-up step failed',
      ),
    );
    expect(outcome.detail, contains('directory refresh failed'));
  });

  test('keeps failures as failures when the primary write never completed', () {
    final outcome = resolveAdminWriteFollowUpOutcome(
      primaryWriteCompleted: false,
      failureMessage: 'Failed to save client.',
      successWarningMessage: 'Client CLIENT-1 saved with follow-up warning.',
      successWarningDetail:
          'The client record was saved before a later follow-up step failed',
      failureDetailPrefix: 'Client save failed',
      error: StateError('clients upsert failed'),
    );

    expect(outcome.treatAsSuccess, isFalse);
    expect(outcome.message, 'Failed to save client.');
    expect(outcome.detail, contains('Client save failed'));
    expect(outcome.detail, contains('clients upsert failed'));
  });
}
