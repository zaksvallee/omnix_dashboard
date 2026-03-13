# ONYX Evidence Provenance

Last updated: 2026-03-13 (Africa/Johannesburg)

Purpose:
- make snapshots, clips, and derived incident evidence tamper-evident at ingest
- prepare certificate-of-integrity exports without depending on vendor APIs

Current repo scope:
- intelligence ingestion now records deterministic provenance hashes for video evidence
- new video intelligence provenance rows are now sealed into the existing client evidence ledger
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
- hash staged validation/signoff artifacts into the same provenance flow
