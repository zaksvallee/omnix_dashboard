import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_high_risk_classifier.dart';

void main() {
  const classifier = TelegramHighRiskClassifier();

  group('TelegramHighRiskClassifier', () {
    test('marks active high-risk reports as high risk', () {
      expect(classifier.isHighRiskMessage('there is a fire in the building'), isTrue);
      expect(classifier.isHighRiskMessage('need police now'), isTrue);
      expect(classifier.isHighRiskMessage('armed intruder on site'), isTrue);
      expect(classifier.isHighRiskMessage('panic at the gate'), isTrue);
      expect(
        classifier.isHighRiskMessage(
          'i heard sounds of glass breaking, can you check?',
        ),
        isTrue,
      );
      expect(
        classifier.isHighRiskMessage('i think someone is in the house'),
        isTrue,
      );
      expect(classifier.isHighRiskMessage('help!!!!! aaaaah'), isTrue);
      expect(classifier.isHighRiskMessage('i just got robbed'), isTrue);
    });

    test('does not mark lookup-style questions as high risk', () {
      expect(classifier.isHighRiskMessage('fire status'), isFalse);
      expect(classifier.isHighRiskMessage('medical?'), isFalse);
      expect(classifier.isHighRiskMessage('police here'), isFalse);
      expect(classifier.isHighRiskMessage('ambulnce status'), isFalse);
      expect(classifier.isHighRiskMessage('ambulnce stauts?'), isFalse);
      expect(classifier.isHighRiskMessage('is there a fire?'), isFalse);
      expect(classifier.isHighRiskMessage('do we have any breaches?'), isFalse);
      expect(classifier.isHighRiskMessage('any fire issues tonight'), isFalse);
      expect(classifier.isHighRiskMessage('do we have police activity tonight?'), isFalse);
      expect(classifier.isHighRiskMessage('any medical incidents here'), isFalse);
      expect(classifier.isHighRiskMessage('breaches at the site?'), isFalse);
      expect(
        classifier.isHighRiskMessage('police activity at ms vallee tonight?'),
        isFalse,
      );
      expect(classifier.isHighRiskMessage('breaches across all sites?'), isFalse);
      expect(
        classifier.isHighRiskMessage(
          'police activity across vallee sites tonight?',
        ),
        isFalse,
      );
    });

    test('does not escalate historical robbery review prompts', () {
      expect(
        classifier.isHighRiskMessage(
          'are you aware of the robbery earlier today?',
        ),
        isFalse,
      );
      expect(
        classifier.isHighRiskMessage(
          'I am asking if you were aware of the robbery that took place earlier.',
        ),
        isFalse,
      );
    });

    test('does not escalate hypothetical escalation capability questions', () {
      expect(
        classifier.isHighRiskMessage('if i need help, can you escalate?'),
        isFalse,
      );
      expect(
        classifier.isHighRiskMessage('if anyting happens, can you escalate?'),
        isFalse,
      );
      expect(
        classifier.isHighRiskMessage(
          'if something happens, can you escalate this?',
        ),
        isFalse,
      );
    });
  });
}
