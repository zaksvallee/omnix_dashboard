import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../incidents/incident_enums.dart';
import 'contact_id_event.dart';

class ContactIdEventMapper {
  final String Function(ContactIdFrame frame, ContactIdPayload payload)
  _eventIdBuilder;

  ContactIdEventMapper({
    String Function(ContactIdFrame frame, ContactIdPayload payload)?
    eventIdBuilder,
  }) : _eventIdBuilder = eventIdBuilder ?? _defaultEventId;

  ContactIdEvent map({
    required ContactIdFrame frame,
    required ContactIdPayload payload,
  }) {
    final incidentType = _incidentTypeFor(payload.eventCode);
    final baseSeverity = _severityFor(payload.eventCode);
    final severity =
        payload.qualifier == ContactIdQualifier.restore &&
            payload.eventCode >= 130 &&
            payload.eventCode <= 139
        ? _lowerSeverity(baseSeverity)
        : baseSeverity;
    final descriptionPrefix = payload.qualifier == ContactIdQualifier.restore
        ? '[RESTORE] '
        : payload.isTestSignal
        ? '[TEST] '
        : '';
    final description =
        '$descriptionPrefix${_descriptionFor(payload.eventCode, payload)}';
    return ContactIdEvent(
      eventId: _eventIdBuilder(frame, payload),
      accountNumber: frame.accountNumber,
      receiverNumber: frame.receiverNumber,
      sequenceNumber: frame.sequenceNumber,
      payload: payload,
      incidentType: incidentType,
      severity: severity,
      description: description,
      isRestore: payload.qualifier == ContactIdQualifier.restore,
      isTest: payload.isTestSignal,
      receivedAtUtc: frame.receivedAtUtc,
      rawFrame: frame.rawFrame,
    );
  }

  static String _defaultEventId(ContactIdFrame frame, ContactIdPayload payload) {
    final digest = sha256.convert(
      utf8.encode(
        [
          frame.receiverNumber,
          frame.accountNumber,
          frame.sequenceNumber.toString(),
          payload.eventCode.toString(),
          payload.partition.toString(),
          payload.zone.toString(),
          frame.receivedAtUtc.toIso8601String(),
          frame.rawFrame,
        ].join('|'),
      ),
    );
    return 'contact-id-${digest.toString().substring(0, 16)}';
  }

  static IncidentType _incidentTypeFor(int eventCode) {
    if (eventCode >= 100 && eventCode <= 109) {
      return IncidentType.panicAlert;
    }
    if (eventCode >= 110 && eventCode <= 119) {
      return IncidentType.alarmTrigger;
    }
    if (eventCode >= 120 && eventCode <= 129) {
      return IncidentType.panicAlert;
    }
    if (eventCode >= 130 && eventCode <= 139) {
      return IncidentType.intrusion;
    }
    if (eventCode >= 140 && eventCode <= 159) {
      return IncidentType.alarmTrigger;
    }
    if (eventCode >= 160 && eventCode <= 169) {
      return IncidentType.equipmentFailure;
    }
    if (eventCode >= 300 && eventCode <= 329) {
      return IncidentType.systemAnomaly;
    }
    if (eventCode >= 400 && eventCode <= 409) {
      return IncidentType.accessViolation;
    }
    if (eventCode >= 570 && eventCode <= 579) {
      return IncidentType.accessViolation;
    }
    if (eventCode >= 601 && eventCode <= 609) {
      return IncidentType.systemAnomaly;
    }
    return IncidentType.other;
  }

  static IncidentSeverity _severityFor(int eventCode) {
    if (eventCode >= 100 && eventCode <= 129) {
      return IncidentSeverity.critical;
    }
    if (eventCode >= 130 && eventCode <= 149) {
      return IncidentSeverity.high;
    }
    if (eventCode >= 150 && eventCode <= 169) {
      return IncidentSeverity.medium;
    }
    if (eventCode >= 300 && eventCode <= 329) {
      return IncidentSeverity.low;
    }
    if (eventCode >= 400 && eventCode <= 409) {
      return IncidentSeverity.low;
    }
    if (eventCode >= 570 && eventCode <= 579) {
      return IncidentSeverity.medium;
    }
    if (eventCode >= 601 && eventCode <= 609) {
      return IncidentSeverity.low;
    }
    return IncidentSeverity.medium;
  }

  static IncidentSeverity _lowerSeverity(IncidentSeverity severity) {
    return switch (severity) {
      IncidentSeverity.critical => IncidentSeverity.critical,
      IncidentSeverity.high => IncidentSeverity.medium,
      IncidentSeverity.medium => IncidentSeverity.low,
      IncidentSeverity.low => IncidentSeverity.low,
    };
  }

  static String _descriptionFor(int eventCode, ContactIdPayload payload) {
    final qualifierDetail = payload.qualifier == ContactIdQualifier.status
        ? ' status'
        : '';
    final partitionLabel = payload.partition.toString().padLeft(2, '0');
    final zoneLabel = payload.zone.toString().padLeft(3, '0');
    final detail = ' (zone $zoneLabel, partition $partitionLabel)';
    return switch (eventCode) {
      100 => 'Medical alarm$detail',
      101 => 'Panic alarm$detail',
      111 => 'Smoke alarm$detail',
      114 => 'Heat alarm$detail',
      121 => 'Duress alarm$detail',
      122 => 'Silent panic alarm$detail',
      130 => 'Burglary - perimeter$detail',
      131 => 'Burglary - interior$detail',
      161 => 'Sensor tamper$detail',
      301 => 'System trouble - AC loss$detail',
      302 => 'System trouble - low battery$detail',
      321 => 'Communication trouble - comm fault$detail',
      570 => 'Zone bypass$detail',
      601 => 'Test signal$detail',
      _ when eventCode >= 100 && eventCode <= 109 =>
        'Medical alarm code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 110 && eventCode <= 119 =>
        'Fire alarm code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 120 && eventCode <= 129 =>
        'Panic / duress code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 130 && eventCode <= 139 =>
        'Burglary alarm code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 140 && eventCode <= 149 =>
        'General alarm code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 150 && eventCode <= 159 =>
        '24-hour alarm code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 160 && eventCode <= 169 =>
        'Tamper code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 300 && eventCode <= 309 =>
        'System trouble code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 320 && eventCode <= 329 =>
        'Communication trouble code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 400 && eventCode <= 409 =>
        'Open/close event code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 570 && eventCode <= 579 =>
        'Bypass event code $eventCode$qualifierDetail$detail',
      _ when eventCode >= 601 && eventCode <= 609 =>
        'Test signal code $eventCode$qualifierDetail$detail',
      _ => 'Unknown Contact ID code $eventCode$detail',
    };
  }
}
