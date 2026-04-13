import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase/supabase.dart';

import 'site_awareness/onyx_site_awareness_snapshot.dart';

const String _onyxEvidenceCertificateGenesisHash = 'GENESIS';
const String _onyxEvidenceCertificateIssuer =
    'ONYX Risk and Intelligence Group';
const String _onyxEvidenceCertificateVersion = '1.0';

class OnyxEvidenceCertificate {
  final String certificateId;
  final String eventId;
  final String? incidentId;
  final String siteId;
  final String clientId;
  final String cameraId;
  final DateTime detectedAt;
  final DateTime issuedAt;
  final String? snapshotHash;
  final String eventHash;
  final int chainPosition;
  final String previousCertificateHash;
  final String certificateHash;
  final double? confidence;
  final String? faceMatchId;
  final String? zoneId;
  final String issuer;
  final String version;
  final bool valid;
  final Map<String, Object?> eventData;

  const OnyxEvidenceCertificate({
    required this.certificateId,
    required this.eventId,
    required this.incidentId,
    required this.siteId,
    required this.clientId,
    required this.cameraId,
    required this.detectedAt,
    required this.issuedAt,
    required this.snapshotHash,
    required this.eventHash,
    required this.chainPosition,
    required this.previousCertificateHash,
    required this.certificateHash,
    required this.confidence,
    required this.faceMatchId,
    required this.zoneId,
    required this.issuer,
    required this.version,
    required this.valid,
    required this.eventData,
  });

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'certificate_id': certificateId,
      'event_id': eventId,
      'incident_id': incidentId,
      'site_id': siteId,
      'client_id': clientId,
      'camera_id': cameraId,
      'detected_at': detectedAt.toUtc().toIso8601String(),
      'issued_at': issuedAt.toUtc().toIso8601String(),
      'snapshot_hash': snapshotHash,
      'event_hash': eventHash,
      'chain_position': chainPosition,
      'previous_certificate_hash': previousCertificateHash,
      'certificate_hash': certificateHash,
      'confidence': confidence,
      'face_match_id': faceMatchId,
      'zone_id': zoneId,
      'issuer': issuer,
      'version': version,
      'valid': valid,
      'event_data': eventData,
    };
  }
}

class OnyxEvidenceCertificateVerificationResult {
  final bool verified;
  final List<String> tamperedFields;

  const OnyxEvidenceCertificateVerificationResult({
    required this.verified,
    required this.tamperedFields,
  });
}

class OnyxEvidenceCertificateService {
  final SupabaseClient _client;
  final DateTime Function() _clock;
  final Random _random;

  OnyxEvidenceCertificateService({
    required SupabaseClient client,
    DateTime Function()? clock,
    Random? random,
  }) : _client = client,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  Future<OnyxEvidenceCertificate> generateCertificate(
    OnyxSiteAwarenessEvent event,
  ) async {
    final certificateId = _generateUuidV4();
    final siteId = (event.siteId ?? '').trim();
    final clientId = (event.clientId ?? '').trim();
    final cameraId = (event.cameraId ?? event.channelId).trim();
    if (siteId.isEmpty || clientId.isEmpty || cameraId.isEmpty) {
      throw StateError(
        'Evidence certificate requires siteId, clientId, and cameraId.',
      );
    }

    final issuedAt = _clock().toUtc();
    final snapshotHash = _snapshotHashFor(event.snapshotBytes);
    final eventData = _canonicalEventData(event, snapshotHash: snapshotHash);
    final eventHash = _sha256HexString(_canonicalJson(eventData));
    final previousCertificateRow = await _readLastCertificateForSite(siteId);
    final previousCertificateHash =
        (previousCertificateRow?['certificate_hash'] as String?)
                ?.trim()
                .isNotEmpty ==
            true
        ? (previousCertificateRow!['certificate_hash'] as String).trim()
        : _onyxEvidenceCertificateGenesisHash;
    final chainPosition = await _readCurrentChainPosition(siteId) + 1;
    final incidentId = (event.incidentId ?? '').trim().isNotEmpty
        ? event.incidentId!.trim()
        : await _readLinkedIncidentId(siteId);

    final certificate = OnyxEvidenceCertificate(
      certificateId: certificateId,
      eventId: event.eventId,
      incidentId: incidentId,
      siteId: siteId,
      clientId: clientId,
      cameraId: cameraId,
      detectedAt: event.detectedAt.toUtc(),
      issuedAt: issuedAt,
      snapshotHash: snapshotHash,
      eventHash: eventHash,
      chainPosition: chainPosition,
      previousCertificateHash: previousCertificateHash,
      certificateHash: '',
      confidence: event.personConfidence,
      faceMatchId: _trimToNull(event.faceMatchId),
      zoneId: _trimToNull(event.zoneId),
      issuer: _onyxEvidenceCertificateIssuer,
      version: _onyxEvidenceCertificateVersion,
      valid: true,
      eventData: eventData,
    );
    final certificateHash = _certificateHashFor(certificate);
    final persisted = OnyxEvidenceCertificate(
      certificateId: certificate.certificateId,
      eventId: certificate.eventId,
      incidentId: certificate.incidentId,
      siteId: certificate.siteId,
      clientId: certificate.clientId,
      cameraId: certificate.cameraId,
      detectedAt: certificate.detectedAt,
      issuedAt: certificate.issuedAt,
      snapshotHash: certificate.snapshotHash,
      eventHash: certificate.eventHash,
      chainPosition: certificate.chainPosition,
      previousCertificateHash: certificate.previousCertificateHash,
      certificateHash: certificateHash,
      confidence: certificate.confidence,
      faceMatchId: certificate.faceMatchId,
      zoneId: certificate.zoneId,
      issuer: certificate.issuer,
      version: certificate.version,
      valid: certificate.valid,
      eventData: certificate.eventData,
    );

    await _client
        .from('onyx_evidence_certificates')
        .insert(persisted.toJsonMap());
    return persisted;
  }

  Future<OnyxEvidenceCertificateVerificationResult> verifyCertificate(
    String certificateId,
  ) async {
    final normalizedCertificateId = certificateId.trim();
    if (normalizedCertificateId.isEmpty) {
      return const OnyxEvidenceCertificateVerificationResult(
        verified: false,
        tamperedFields: <String>['certificateId'],
      );
    }

    final dynamic row = await _client
        .from('onyx_evidence_certificates')
        .select()
        .eq('certificate_id', normalizedCertificateId)
        .maybeSingle();
    if (row is! Map<String, dynamic>) {
      return const OnyxEvidenceCertificateVerificationResult(
        verified: false,
        tamperedFields: <String>['certificateId'],
      );
    }

    final tamperedFields = <String>[];
    final eventData = _normalizedJsonMap(row['event_data']);
    final storedEventHash = (row['event_hash'] as String? ?? '').trim();
    final recomputedEventHash = _sha256HexString(_canonicalJson(eventData));
    if (storedEventHash != recomputedEventHash) {
      tamperedFields.add('eventHash');
    }

    final storedCertificateHash = (row['certificate_hash'] as String? ?? '')
        .trim();
    final recomputedCertificateHash = _certificateHashFromRow(row);
    if (storedCertificateHash != recomputedCertificateHash) {
      tamperedFields.add('certificateHash');
    }

    final previousCertificateHash =
        (row['previous_certificate_hash'] as String? ?? '').trim();
    if (previousCertificateHash.isEmpty) {
      tamperedFields.add('previousCertificateHash');
    } else if (previousCertificateHash != _onyxEvidenceCertificateGenesisHash) {
      final dynamic previousRow = await _client
          .from('onyx_evidence_certificates')
          .select('certificate_hash')
          .eq('site_id', row['site_id'])
          .lt('chain_position', row['chain_position'])
          .order('chain_position', ascending: false)
          .limit(1)
          .maybeSingle();
      final linkedPreviousHash = previousRow is Map<String, dynamic>
          ? (previousRow['certificate_hash'] as String? ?? '').trim()
          : '';
      if (linkedPreviousHash.isEmpty ||
          linkedPreviousHash != previousCertificateHash) {
        tamperedFields.add('previousCertificateHash');
      }
    }

    return OnyxEvidenceCertificateVerificationResult(
      verified: tamperedFields.isEmpty,
      tamperedFields: List<String>.unmodifiable(tamperedFields),
    );
  }

  Future<Map<String, dynamic>?> _readLastCertificateForSite(
    String siteId,
  ) async {
    final dynamic row = await _client
        .from('onyx_evidence_certificates')
        .select('certificate_hash, chain_position')
        .eq('site_id', siteId)
        .order('chain_position', ascending: false)
        .limit(1)
        .maybeSingle();
    return row is Map<String, dynamic> ? row : null;
  }

  Future<int> _readCurrentChainPosition(String siteId) async {
    try {
      final dynamic row = await _client
          .from('onyx_event_store')
          .select('sequence')
          .eq('site_id', siteId)
          .order('sequence', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return _intFrom(row['sequence']) ?? 0;
      }
    } catch (_) {
      // Fall back to existing certificate chain if the EventStore receipt table
      // is not yet available in the target stack.
    }
    final previousCertificate = await _readLastCertificateForSite(siteId);
    return _intFrom(previousCertificate?['chain_position']) ?? 0;
  }

  Future<String?> _readLinkedIncidentId(String siteId) async {
    try {
      final dynamic row = await _client
          .from('incidents')
          .select('incident_id, status')
          .eq('site_id', siteId)
          .not('status', 'in', '("closed","resolved")')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row is! Map<String, dynamic>) {
        return null;
      }
      return _trimToNull(row['incident_id']?.toString());
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _canonicalEventData(
    OnyxSiteAwarenessEvent event, {
    required String? snapshotHash,
  }) {
    return <String, Object?>{
      'event_id': event.eventId,
      'site_id': _trimToNull(event.siteId),
      'client_id': _trimToNull(event.clientId),
      'camera_id': _trimToNull(event.cameraId) ?? event.channelId.trim(),
      'channel_id': event.channelId.trim(),
      'event_type': event.eventType.name,
      'detected_at': event.detectedAt.toUtc().toIso8601String(),
      'raw_event_type': event.rawEventType.trim(),
      'target_type': _trimToNull(event.targetType),
      'plate_number': _trimToNull(event.plateNumber),
      'face_match_id': _trimToNull(event.faceMatchId),
      'face_match_name': _trimToNull(event.faceMatchName),
      'face_match_confidence': event.faceMatchConfidence,
      'face_match_distance': event.faceMatchDistance,
      'person_confidence': event.personConfidence,
      'snapshot_hash': snapshotHash,
      'zone_id': _trimToNull(event.zoneId),
      'incident_id': _trimToNull(event.incidentId),
      'unknown_person': event.unknownPerson,
      'is_known_fault_channel': event.isKnownFaultChannel,
    };
  }

  String _certificateHashFor(OnyxEvidenceCertificate certificate) {
    return _sha256HexString(
      _canonicalJson(<String, Object?>{
        'certificate_id': certificate.certificateId,
        'event_id': certificate.eventId,
        'incident_id': certificate.incidentId,
        'site_id': certificate.siteId,
        'client_id': certificate.clientId,
        'camera_id': certificate.cameraId,
        'detected_at': certificate.detectedAt.toUtc().toIso8601String(),
        'issued_at': certificate.issuedAt.toUtc().toIso8601String(),
        'snapshot_hash': certificate.snapshotHash,
        'event_hash': certificate.eventHash,
        'chain_position': certificate.chainPosition,
        'previous_certificate_hash': certificate.previousCertificateHash,
        'confidence': certificate.confidence,
        'face_match_id': certificate.faceMatchId,
        'zone_id': certificate.zoneId,
        'issuer': certificate.issuer,
        'version': certificate.version,
        'valid': certificate.valid,
      }),
    );
  }

  String _certificateHashFromRow(Map<String, dynamic> row) {
    return _sha256HexString(
      _canonicalJson(<String, Object?>{
        'certificate_id': row['certificate_id'],
        'event_id': row['event_id'],
        'incident_id': row['incident_id'],
        'site_id': row['site_id'],
        'client_id': row['client_id'],
        'camera_id': row['camera_id'],
        'detected_at': _isoString(row['detected_at']),
        'issued_at': _isoString(row['issued_at']),
        'snapshot_hash': row['snapshot_hash'],
        'event_hash': row['event_hash'],
        'chain_position': _intFrom(row['chain_position']),
        'previous_certificate_hash': row['previous_certificate_hash'],
        'confidence': _doubleFrom(row['confidence']),
        'face_match_id': row['face_match_id'],
        'zone_id': row['zone_id'],
        'issuer': row['issuer'],
        'version': row['version'],
        'valid': row['valid'] == true,
      }),
    );
  }

  String _canonicalJson(Object? value) {
    return jsonEncode(_normalizeJsonValue(value));
  }

  Object? _normalizeJsonValue(Object? value) {
    if (value is Map) {
      final normalizedEntries =
          value.entries
              .map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  _normalizeJsonValue(entry.value),
                ),
              )
              .toList(growable: false)
            ..sort((a, b) => a.key.compareTo(b.key));
      return Map<String, Object?>.fromEntries(normalizedEntries);
    }
    if (value is List) {
      return value
          .map<Object?>((entry) => _normalizeJsonValue(entry))
          .toList(growable: false);
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is num || value is bool || value == null || value is String) {
      return value;
    }
    return value.toString();
  }

  Map<String, Object?> _normalizedJsonMap(Object? value) {
    final normalized = _normalizeJsonValue(value);
    if (normalized is Map<String, Object?>) {
      return normalized;
    }
    return const <String, Object?>{};
  }

  String? _snapshotHashFor(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return sha256.convert(bytes).toString();
  }

  String _sha256HexString(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final buffer = StringBuffer();
    for (var index = 0; index < bytes.length; index++) {
      if (index == 4 || index == 6 || index == 8 || index == 10) {
        buffer.write('-');
      }
      buffer.write(bytes[index].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  int? _intFrom(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  double? _doubleFrom(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _isoString(Object? value) {
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    return value?.toString() ?? '';
  }
}
