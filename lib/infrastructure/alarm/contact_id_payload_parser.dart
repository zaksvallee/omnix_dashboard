import '../../domain/alarms/contact_id_event.dart';

class ContactIdParseException implements Exception {
  final String message;
  final String rawInput;

  const ContactIdParseException(this.message, {required this.rawInput});

  @override
  String toString() => 'ContactIdParseException($message): $rawInput';
}

class ContactIdPayloadParser {
  const ContactIdPayloadParser();

  ContactIdPayload parse(String rawInput) {
    final normalized = rawInput.trim();
    if (normalized.length != 15) {
      throw ContactIdParseException(
        'Contact ID payload must be exactly 15 characters.',
        rawInput: rawInput,
      );
    }
    final accountNumber = normalized.substring(0, 4);
    final messageType = normalized.substring(4, 6);
    final qualifierCode = normalized.substring(6, 7);
    final eventCodeRaw = normalized.substring(7, 10);
    final partitionRaw = normalized.substring(10, 12);
    final zoneRaw = normalized.substring(12, 15);
    if (!_isDigits(accountNumber) ||
        !_isDigits(messageType) ||
        !_isDigits(qualifierCode) ||
        !_isDigits(eventCodeRaw) ||
        !_isDigits(partitionRaw) ||
        !_isDigits(zoneRaw)) {
      throw ContactIdParseException(
        'Contact ID payload must contain only numeric segments.',
        rawInput: rawInput,
      );
    }
    if (messageType != '18') {
      throw ContactIdParseException(
        'Unsupported Contact ID message type: $messageType',
        rawInput: rawInput,
      );
    }
    final qualifier = switch (qualifierCode) {
      '1' => ContactIdQualifier.newEvent,
      '3' => ContactIdQualifier.restore,
      '6' => ContactIdQualifier.status,
      _ => throw ContactIdParseException(
        'Unsupported qualifier code: $qualifierCode',
        rawInput: rawInput,
      ),
    };
    return ContactIdPayload(
      accountNumber: accountNumber,
      qualifier: qualifier,
      eventCode: int.parse(eventCodeRaw),
      partition: int.parse(partitionRaw),
      zone: int.parse(zoneRaw),
    );
  }

  static bool _isDigits(String value) {
    return value.runes.every((rune) => rune >= 0x30 && rune <= 0x39);
  }
}
