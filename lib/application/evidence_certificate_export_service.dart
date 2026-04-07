import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../domain/evidence/client_ledger_repository.dart';
import '../domain/evidence/client_ledger_service.dart';
import '../domain/evidence/evidence_provenance.dart';
import '../domain/events/intelligence_received.dart';

class EvidenceCertificateExport {
  final Map<String, Object?> json;
  final String markdown;

  const EvidenceCertificateExport({required this.json, required this.markdown});
}

class EvidenceCertificateExportService {
  final ClientLedgerRepository repository;
  final ClientLedgerService? ledgerService;

  const EvidenceCertificateExportService({
    required this.repository,
    this.ledgerService,
  });

  static String chainedPayloadHash({
    required Map<String, Object?> payload,
    required String previousHash,
  }) {
    return sha256
        .convert(utf8.encode('${jsonEncode(payload)}|$previousHash'))
        .toString();
  }

  Future<EvidenceCertificateExport> exportForIntelligence(
    IntelligenceReceived event,
  ) async {
    await ledgerService?.flushPendingEvidence();
    final certificate = EvidenceProvenanceCertificate.fromIntelligence(event);
    final ledgerRow = await repository.fetchLedgerRow(
      clientId: event.clientId,
      dispatchId: ClientLedgerService.intelligenceLedgerDispatchId(
        event.intelligenceId,
      ),
    );
    final hashVerified = ledgerRow == null
        ? false
        : ClientLedgerService.ledgerHashFor(
                canonicalJson: ledgerRow.canonicalJson,
                previousHash: ledgerRow.previousHash,
              ) ==
              ledgerRow.hash;
    if (ledgerRow != null && !hashVerified) {
      throw StateError(
        'Ledger tamper detected for intelligence ${event.intelligenceId}: stored hash does not match canonical payload.',
      );
    }

    final payload = <String, Object?>{
      'certificate_type': 'onyx_evidence_integrity_certificate',
      'intelligence': certificate.toJson(),
      'ledger': {
        'dispatchId': ledgerRow?.dispatchId ?? '',
        'hash': ledgerRow?.hash ?? '',
        'previousHash': ledgerRow?.previousHash ?? '',
        'sealed': ledgerRow != null,
        'hashVerified': hashVerified,
      },
    };

    final markdown = _toMarkdown(payload);
    return EvidenceCertificateExport(json: payload, markdown: markdown);
  }

  String _toMarkdown(Map<String, Object?> payload) {
    final intelligence = payload['intelligence'] as Map<String, Object?>;
    final ledger = payload['ledger'] as Map<String, Object?>;
    final locators = intelligence['locators'] as Map<String, Object?>;
    final snapshot = locators['snapshot'] as Map<String, Object?>;
    final clip = locators['clip'] as Map<String, Object?>;

    return [
      '# ONYX Evidence Integrity Certificate',
      '',
      '- Intelligence ID: `${intelligence['intelligenceId']}`',
      '- Provider: `${intelligence['provider']}`',
      '- Source type: `${intelligence['sourceType']}`',
      '- External ID: `${intelligence['externalId']}`',
      '- Client / Site: `${intelligence['clientId']}` / `${intelligence['siteId']}`',
      '- Occurred at UTC: `${intelligence['occurredAtUtc']}`',
      '- Canonical hash: `${intelligence['canonicalHash']}`',
      '- Evidence record hash: `${intelligence['evidenceRecordHash']}`',
      '- Snapshot locator hash: `${snapshot['locatorHash']}`',
      '- Clip locator hash: `${clip['locatorHash']}`',
      '- Ledger sealed: `${ledger['sealed']}`',
      '- Ledger hash: `${ledger['hash']}`',
      '- Ledger previous hash: `${ledger['previousHash']}`',
    ].join('\n');
  }

  String exportJsonPretty(EvidenceCertificateExport export) {
    return const JsonEncoder.withIndent('  ').convert(export.json);
  }
}
