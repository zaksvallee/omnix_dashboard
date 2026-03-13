# ONYX Evidence Provenance

Last updated: 2026-03-13 (Africa/Johannesburg)

Purpose:
- make snapshots, clips, and derived incident evidence tamper-evident at ingest
- prepare certificate-of-integrity exports without depending on vendor APIs

Current repo scope:
- intelligence ingestion now records deterministic provenance hashes for video evidence
- new video intelligence provenance rows are now sealed into the existing client evidence ledger
- ledger-backed integrity certificate export is now available for `IntelligenceReceived` evidence
- staged validation bundles now auto-emit deterministic integrity certificates from `validation_report.json`
- CCTV, DVR, and listener readiness now verify those staged bundle certificates before signoff posture can pass
- CCTV signoff now also emits a sibling audited JSON artifact that records the staged validation-bundle integrity certificate refs/status on both pass and fail
- CCTV release posture can now be emitted as a final `release_gate.json` / `release_gate.md` pair that consumes the staged integrity certificate plus CCTV signoff JSON
- CCTV release posture can now be compared across runs with `release_trend_report.json` / `release_trend_report.md`, which surface result regressions and signoff/integrity drift in the current or previous staged bundle
- each ingested `IntelligenceReceived` event can now carry:
  - `snapshotReferenceHash`
  - `clipReferenceHash`
  - `evidenceRecordHash`
- hashes are derived from:
  - canonical event payload hash
  - provider/source identity
  - site identity
  - occurred-at timestamp
  - snapshot and clip locator hashes

Current rules:
- locator hashes are SHA-256 over the normalized private evidence locator
- evidence-record hash is SHA-256 over the canonical evidence provenance payload
- empty locators do not produce reference hashes

Certificate model:
- `lib/domain/evidence/evidence_provenance.dart`
  - `EvidenceProvenanceCertificate`
  - `EvidenceLocatorProvenance`
- `lib/application/evidence_certificate_export_service.dart`
  - `EvidenceCertificateExportService`
  - joins an intelligence provenance certificate with its sealed client-ledger row
- `scripts/onyx_validation_bundle_certificate.sh`
  - emits `integrity_certificate.json` and `integrity_certificate.md`
  - verifies staged file checksums from a validation bundle
  - derives a deterministic `bundle_hash` from report metadata plus staged file hashes
  - is now called automatically by CCTV, DVR, and listener field-validation flows
- current certificate JSON includes:
  - intelligence id
  - provider/source identity
  - client/region/site identity
  - occurred-at timestamp
  - canonical event hash
  - evidence-record hash
  - snapshot and clip locator hashes

Next step candidates:
- add certificate export UI/API
- hash staged signoff artifacts into the same provenance flow
