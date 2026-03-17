import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/chat_casefile_history_text_formatter.dart';

void main() {
  test('buildChatCaseFileHeader preserves order and skips empty values', () {
    final text = buildChatCaseFileHeader(
      title: 'ONYX SYNTHETICCASE JSON',
      fields: const [
        ChatCaseFileHeaderField(key: 'report_date', value: '2026-03-17'),
        ChatCaseFileHeaderField(key: 'focus_summary', value: 'Policy shift'),
        ChatCaseFileHeaderField(key: 'empty', value: ''),
        ChatCaseFileHeaderField(
          key: 'review_command',
          value: '/syntheticreview 2026-03-17',
        ),
      ],
    );

    expect(
      text,
      'ONYX SYNTHETICCASE JSON\n'
      'report_date=2026-03-17\n'
      'focus_summary=Policy shift\n'
      'review_command=/syntheticreview 2026-03-17\n',
    );
  });

  test('buildChatCaseFileHistoryText formats indexed non-empty rows', () {
    final text = buildChatCaseFileHistoryText(
      rows: const [
        <String, Object?>{
          'reportDate': '2026-03-17',
          'summary': 'Current pressure rising',
          'reviewCommand': '/syntheticreview 2026-03-17',
          'empty': '',
        },
        <String, Object?>{
          'reportDate': '2026-03-16',
          'summary': 'Prior pressure stable',
          'reviewCommand': '',
        },
      ],
      fields: const [
        ChatCaseFileHistoryField(
          inputKey: 'reportDate',
          outputKey: 'report_date',
        ),
        ChatCaseFileHistoryField(inputKey: 'summary', outputKey: 'summary'),
        ChatCaseFileHistoryField(
          inputKey: 'reviewCommand',
          outputKey: 'review_command',
        ),
        ChatCaseFileHistoryField(inputKey: 'empty', outputKey: 'empty'),
      ],
    );

    expect(text, contains('history_1_report_date=2026-03-17'));
    expect(text, contains('history_1_summary=Current pressure rising'));
    expect(
      text,
      contains('history_1_review_command=/syntheticreview 2026-03-17'),
    );
    expect(text, contains('history_2_report_date=2026-03-16'));
    expect(text, contains('history_2_summary=Prior pressure stable'));
    expect(text, isNot(contains('history_1_empty=')));
    expect(text, isNot(contains('history_2_review_command=')));
  });

  test('buildPromotionShadowHeaderFields preserves promotion anchor order', () {
    final header = buildChatCaseFileHeader(
      title: 'ONYX SYNTHETICCASE JSON',
      fields: buildPromotionShadowHeaderFields(
        payload: const <String, Object?>{
          'promotionCurrentValidationStatus': 'validated',
          'promotionCurrentStrengthSummary': 'PROMOTED VALIDATED • 0.88',
          'promotionShadowSelectedEventId': 'evt-office-1',
          'promotionShadowReviewRefs': 'intel-office-1,intel-office-2',
          'promotionShadowReviewCommand': '/shadowreview 2026-03-17',
          'promotionShadowCaseFileCommand': '/shadowcase json 2026-03-17',
        },
      ),
    );

    expect(
      header,
      'ONYX SYNTHETICCASE JSON\n'
      'promotion_current_validation_status=validated\n'
      'promotion_current_strength_summary=PROMOTED VALIDATED • 0.88\n'
      'promotion_shadow_selected_event_id=evt-office-1\n'
      'promotion_shadow_review_refs=intel-office-1,intel-office-2\n'
      'promotion_shadow_review_command=/shadowreview 2026-03-17\n'
      'promotion_shadow_case_file_command=/shadowcase json 2026-03-17\n',
    );
  });

  test('buildPromotionShadowFieldText supports custom prefix and line prefix', () {
    final text = buildPromotionShadowFieldText(
      payload: const <String, Object?>{
        'promotionCurrentValidationStatus': 'validated',
        'promotionCurrentStrengthSummary': 'PROMOTED VALIDATED • 0.88',
        'promotionShadowSelectedEventId': 'evt-office-1',
      },
      keyPrefix: '',
      linePrefix: '\n',
    );

    expect(
      text,
      '\ncurrent_validation_status=validated\n'
      '\ncurrent_strength_summary=PROMOTED VALIDATED • 0.88\n'
      '\nshadow_selected_event_id=evt-office-1\n',
    );
  });

  test('buildChatReviewHeaderFields preserves order and optional fields', () {
    final header = buildChatCaseFileHeader(
      title: 'ONYX SHADOWREVIEW',
      fields: buildChatReviewHeaderFields(
        reportDate: '2026-03-17',
        summary: 'Shadow MO pressure rising',
        focusSummary: 'Viewing command-targeted shift.',
        historyHeadline: 'RISING • 3d',
        historySummary: 'Shadow-MO pressure is increasing.',
        caseFileCommand: '/shadowcase json 2026-03-17',
        reviewRefs: const ['intel-1', 'intel-2'],
        eventCount: 2,
      ),
    );

    expect(
      header,
      'ONYX SHADOWREVIEW\n'
      'report_date=2026-03-17\n'
      'summary=Shadow MO pressure rising\n'
      'focus_summary=Viewing command-targeted shift.\n'
      'history_headline=RISING • 3d\n'
      'history_summary=Shadow-MO pressure is increasing.\n'
      'review_refs=intel-1, intel-2\n'
      'case_file_command=/shadowcase json 2026-03-17\n'
      'events=2\n',
    );
  });
}
