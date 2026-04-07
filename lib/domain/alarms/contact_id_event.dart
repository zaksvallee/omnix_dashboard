import '../incidents/incident_enums.dart';

sealed class SiaDc09ParseResult {
  const SiaDc09ParseResult();
}

class ContactIdFrame extends SiaDc09ParseResult {
  final String accountNumber;
  final String receiverNumber;
  final int sequenceNumber;
  final bool isEncrypted;
  final bool isDuplicate;
  final String payloadData;
  final DateTime receivedAtUtc;
  final String rawFrame;

  const ContactIdFrame({
    required this.accountNumber,
    required this.receiverNumber,
    required this.sequenceNumber,
    required this.isEncrypted,
    required this.isDuplicate,
    required this.payloadData,
    required this.receivedAtUtc,
    required this.rawFrame,
  });

  ContactIdFrame copyWith({bool? isDuplicate}) {
    return ContactIdFrame(
      accountNumber: accountNumber,
      receiverNumber: receiverNumber,
      sequenceNumber: sequenceNumber,
      isEncrypted: isEncrypted,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      payloadData: payloadData,
      receivedAtUtc: receivedAtUtc,
      rawFrame: rawFrame,
    );
  }
}

enum SiaParseFailureReason {
  crcMismatch,
  decryptionFailed,
  malformedFrame,
  unsupportedFormat,
}

class SiaParseFailure extends SiaDc09ParseResult {
  final SiaParseFailureReason reason;
  final String rawFrame;
  final String detail;

  const SiaParseFailure({
    required this.reason,
    required this.rawFrame,
    required this.detail,
  });
}

enum ContactIdQualifier { newEvent, restore, status }

class ContactIdPayload {
  final String accountNumber;
  final ContactIdQualifier qualifier;
  final int eventCode;
  final int partition;
  final int zone;

  const ContactIdPayload({
    required this.accountNumber,
    required this.qualifier,
    required this.eventCode,
    required this.partition,
    required this.zone,
  });

  bool get isTestSignal => eventCode >= 601 && eventCode <= 609;
}

class ContactIdEvent {
  final String eventId;
  final String accountNumber;
  final String receiverNumber;
  final int sequenceNumber;
  final ContactIdPayload payload;
  final IncidentType incidentType;
  final IncidentSeverity severity;
  final String description;
  final bool isRestore;
  final bool isTest;
  final DateTime receivedAtUtc;
  final String rawFrame;

  const ContactIdEvent({
    required this.eventId,
    required this.accountNumber,
    required this.receiverNumber,
    required this.sequenceNumber,
    required this.payload,
    required this.incidentType,
    required this.severity,
    required this.description,
    required this.isRestore,
    required this.isTest,
    required this.receivedAtUtc,
    required this.rawFrame,
  });
}
