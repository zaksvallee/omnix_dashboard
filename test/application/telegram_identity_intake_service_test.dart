import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_dashboard/application/telegram_identity_intake_service.dart';
import 'package:omnix_dashboard/application/site_identity_registry_repository.dart';

void main() {
  const service = TelegramIdentityIntakeService();

  test('parses visitor message with name, plate, and until time', () {
    final result = service.tryParse(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      endpointId: 'endpoint-1',
      rawText: 'John Smith is visiting in a white Hilux CA123456 until 18:00',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 10, 30),
    );

    expect(result, isNotNull);
    expect(result!.intake.category, SiteIdentityCategory.visitor);
    expect(result.intake.parsedDisplayName, 'John Smith');
    expect(result.intake.parsedPlateNumber, 'CA123456');
    expect(result.intake.validUntilUtc, DateTime.utc(2026, 3, 15, 18));
    expect(result.clientAcknowledgementText, contains('John Smith'));
    expect(result.clientAcknowledgementText, contains('plate CA123456'));
  });

  test('parses contractor message with overnight until rollover', () {
    final result = service.tryParse(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      endpointId: 'endpoint-1',
      rawText: 'Contractor Mike Brown coming with plate ND12345 until 06:00',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 22, 15),
    );

    expect(result, isNotNull);
    expect(result!.intake.category, SiteIdentityCategory.contractor);
    expect(result.intake.parsedDisplayName, 'Mike Brown');
    expect(result.intake.parsedPlateNumber, 'ND12345');
    expect(result.intake.validUntilUtc, DateTime.utc(2026, 3, 16, 6));
  });

  test('ignores unrelated free text', () {
    final result = service.tryParse(
      clientId: 'CLIENT-MS-VALLEE',
      siteId: 'SITE-MS-VALLEE-RESIDENCE',
      endpointId: 'endpoint-1',
      rawText: 'What is the status of the gate alarm?',
      occurredAtUtc: DateTime.utc(2026, 3, 15, 10, 30),
    );

    expect(result, isNull);
  });
}
