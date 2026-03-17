import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/chat_casefile_history_text_formatter.dart';

void main() {
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
}
