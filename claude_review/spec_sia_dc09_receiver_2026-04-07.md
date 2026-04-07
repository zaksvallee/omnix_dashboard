# Spec: SIA DC-09 Virtual Receiver — ONYX Integration

- Date: 2026-04-07
- Author: Claude Code (auditor)
- Status: Design spec — no code has been written
- Scope: `lib/infrastructure/alarm/`, `lib/domain/alarms/`, Incident Triage Agent handoff
- Read-only: yes (this document only)

---

## Purpose

Define the full implementation architecture for a software-only SIA DC-09 virtual receiver in Dart. The receiver ingests Contact ID alarm signals from IP/GPRS panels, decrypts them (AES-128 per DC-09 §6), parses them into domain events, maps them to ONYX `IncidentType` values, and delivers them to the Incident Triage Agent pipeline.

This spec is the single source of truth for Codex to implement. Nothing in `/lib/` or `/test/` should be written until Zaks approves this document.

---

## Architecture Overview

```
Alarm Panel (any brand)
  │  Contact ID over TCP (SIA DC-09 framing)
  ▼
ContactIdReceiverService          ← infrastructure layer
  │  raw DC-09 frame bytes
  ▼
SiaDc09FrameParser                ← infrastructure layer (pure, no I/O)
  │  parsed + decrypted ContactIdFrame
  ▼
ContactIdEventMapper              ← domain layer (pure)
  │  ContactIdEvent
  ▼
AlarmTriageGateway                ← application layer
  │  OnyxWorkItem (intent: triageIncident)
  ▼
OnyxCommandBrainOrchestrator      ← existing, unchanged
```

All layers have explicit contracts. The transport (TCP) is fully isolated from the domain. The domain mapper is a pure function: no I/O, no async, no AES.

---

## 1. TCP Server Setup

### Class: `ContactIdReceiverService`

**File:** `lib/infrastructure/alarm/contact_id_receiver_service.dart`
*(replaces the current placeholder)*

**Responsibilities:**
- Bind a `ServerSocket` on a configurable port (default: `2222`).
- Accept one or many simultaneous panel connections.
- Read raw bytes from each socket.
- Hand byte sequences to `SiaDc09FrameParser` for deframing and decryption.
- Emit parsed `ContactIdFrame` objects via a `Stream<ContactIdFrame>`.
- Send DC-09 acknowledgement frames back to the panel.
- Handle disconnects and reconnects without crashing the server.

**Constructor parameters:**
```dart
const ContactIdReceiverService({
  required String bindAddress,   // e.g. '0.0.0.0'
  required int port,             // e.g. 2222
  required Uint8List aesKey,     // 16 bytes, AES-128
  Duration connectionTimeout = const Duration(seconds: 30),
});
```

**Key behaviours:**

| Behaviour | Detail |
|-----------|--------|
| Bind | `ServerSocket.bind(bindAddress, port)` |
| Accept | `server.listen(onConnection)` |
| Per-connection buffer | Accumulate bytes until `\r\n` (DC-09 line terminator) |
| Parse | Call `SiaDc09FrameParser.parse(rawBytes, aesKey)` |
| ACK | Write `ACK` frame per DC-09 §7.4 within 10 seconds of receiving a valid frame |
| NAK | Write `NAK` on parse or decryption failure; do not throw |
| Idle timeout | Close socket after `connectionTimeout` of inactivity |
| Stream | `Stream<ContactIdFrame> get frames` — broadcast, never closes |
| Logging | Emit structured log lines; never log raw AES key bytes |

**Error policy:**
- Per-socket errors must not propagate to the global stream or crash the server.
- Log each socket error with the remote address and error type.
- Continue accepting new connections unconditionally.

**Replay safety:**
- Each frame carries a `sequenceNumber` (uint16, from DC-09 header).
- The service maintains a per-account `lastSequenceNumber` map.
- Frames with a sequence number ≤ `lastSequenceNumber` are tagged `isDuplicate: true` and still emitted (the domain decides whether to act).
- Wrap-around at 65535 → 0 must be handled correctly.

---

## 2. DC-09 Frame Deframing and AES-128 Decryption

### Class: `SiaDc09FrameParser`

**File:** `lib/infrastructure/alarm/sia_dc09_frame_parser.dart` *(new)*

**Responsibilities:**
- Parse DC-09 ASCII-encoded frame lines into a typed `ContactIdFrame` record.
- Detect whether the frame is encrypted (prefix `"*"` per DC-09 §6.3).
- Decrypt using AES-128-CBC when present.
- Validate the DC-09 CRC-16 checksum.
- Return a typed result (`ContactIdFrame` or `SiaParseFailure`).

### DC-09 Frame Structure (abbreviated)

```
LF [ receiver ] [ line ] [ prefix ] [ ID ] [ LPAREN ] [ data ] [ RPAREN ] CRC CRLF
```

Key fields:
| Field | Width | Notes |
|-------|-------|-------|
| Receiver number | 4 ASCII digits | |
| Line/account | 4 ASCII digits | maps to ONYX account |
| Prefix | 1 char | `"*"` = encrypted, `"/"` = SIA-DCS, `"[` = Contact ID |
| Message ID | variable | event block |
| Data block | variable | Contact ID payload; may be AES-128-CBC ciphertext |
| CRC | 4 hex ASCII | CRC-16/ARC over the full frame |

### AES-128-CBC Decryption

- **Algorithm:** AES-128-CBC.
- **Key:** 16-byte `Uint8List` supplied at construction.
- **IV:** First 16 bytes of the ciphertext block (per SIA DC-09 §6.3.2 — the IV is prepended to the ciphertext).
- **Padding:** PKCS#7. Strip after decryption.
- **Package:** `package:pointycastle` — already available in Flutter ecosystem.
- **Key constraint:** The caller must supply the key; the parser never stores or logs it.

**Pseudocode:**
```dart
Uint8List _decryptAes128Cbc(Uint8List ciphertext, Uint8List key) {
  final iv = ciphertext.sublist(0, 16);
  final body = ciphertext.sublist(16);
  final cipher = CBCBlockCipher(AESEngine())
    ..init(false, ParametersWithIV(KeyParameter(key), iv));
  // process blocks, strip PKCS7 padding
  return plaintext;
}
```

### CRC-16 Validation

- Algorithm: CRC-16/ARC (polynomial 0x8005, initial value 0x0000, reflected input/output).
- Compute over the raw frame bytes excluding the 4-char CRC field itself.
- Reject frames where computed ≠ received; emit `SiaParseFailure.crcMismatch`.

### Parse Result Types

```dart
sealed class SiaDc09ParseResult {}

class ContactIdFrame implements SiaDc09ParseResult {
  final String accountNumber;      // 4-digit panel account
  final String receiverNumber;     // 4-digit receiver ID
  final int sequenceNumber;        // uint16, DC-09 sequence
  final bool isEncrypted;
  final bool isDuplicate;          // set by receiver service
  final ContactIdPayload payload;
  final DateTime receivedAtUtc;
  final String rawFrame;           // for evidence/audit
}

class SiaParseFailure implements SiaDc09ParseResult {
  final SiaParseFailureReason reason;
  final String rawFrame;
  final String detail;
}

enum SiaParseFailureReason {
  crcMismatch,
  decryptionFailed,
  malformedFrame,
  unsupportedFormat,
}
```

---

## 3. Contact ID Event Parsing

### Class: `ContactIdPayloadParser`

**File:** `lib/infrastructure/alarm/contact_id_payload_parser.dart` *(new)*

**Input:** The decrypted ASCII data block from a `ContactIdFrame`.

**Contact ID Format:**

```
ACCT MT QXYZ GG CCC
```

| Token | Width | Meaning |
|-------|-------|---------|
| ACCT | 4 digits | Account/panel number |
| MT | 2 chars | Message type — always `18` for Contact ID |
| Q | 1 digit | Qualifier: `1`=new/open, `3`=restore/close, `6`=status |
| XYZ | 3 digits | Event code (see §4 below) |
| GG | 2 digits | Partition/group (00 = no partition) |
| CCC | 3 digits | Zone or user number (000 = not applicable) |

**Output: `ContactIdPayload`**

```dart
class ContactIdPayload {
  final String accountNumber;
  final ContactIdQualifier qualifier;   // enum: newEvent, restore, status
  final int eventCode;                  // 3-digit integer
  final int partition;                  // 0 = not applicable
  final int zone;                       // 0 = not applicable
}

enum ContactIdQualifier { newEvent, restore, status }
```

**Parser contract:**
- Pure function, no async, no I/O.
- Returns `ContactIdPayload` or throws `ContactIdParseException` with a `rawInput` field.
- Does not apply mapping logic — that is the domain mapper's responsibility.

---

## 4. Contact ID Event Mapping to ONYX Incident Types

### Class: `ContactIdEventMapper`

**File:** `lib/domain/alarms/contact_id_event_mapper.dart`
*(replaces the current placeholder)*

**Contract:** Pure function. Receives `ContactIdPayload`, returns `ContactIdEvent`. No I/O, no AES, no transport details.

### Domain Model: `ContactIdEvent`

**File:** `lib/domain/alarms/contact_id_event.dart`
*(replaces the current placeholder)*

```dart
class ContactIdEvent {
  final String eventId;               // UUID, generated at mapping time
  final String accountNumber;         // panel account
  final String receiverNumber;        // DC-09 receiver
  final int sequenceNumber;
  final ContactIdPayload payload;
  final IncidentType incidentType;
  final IncidentSeverity severity;
  final String description;           // human-readable, for triage prompt
  final bool isRestore;               // true when qualifier == restore
  final DateTime receivedAtUtc;
  final String rawFrame;              // for audit trail
}
```

### Event Code Table

The mapper must implement the following reference table. This is the minimum coverage required for ONYX production deployment. Additional codes can be added without changing the mapping architecture.

| Code Range | Category | `IncidentType` | `IncidentSeverity` | Notes |
|------------|----------|----------------|--------------------|-------|
| 100–109 | Medical alarm | `panicAlert` | `critical` | 100=medical, 101=panic |
| 110–119 | Fire alarm | `alarmTrigger` | `critical` | 111=smoke, 114=heat |
| 120–129 | Panic / duress | `panicAlert` | `critical` | 121=duress, 122=silent |
| 130–139 | Burglary | `intrusion` | `high` | 130=perimeter, 131=interior |
| 140–149 | General alarm | `alarmTrigger` | `high` | |
| 150–159 | 24-hour (non-burglary) | `alarmTrigger` | `medium` | |
| 160–169 | Tamper | `equipmentFailure` | `medium` | 161=sensor tamper |
| 300–309 | System trouble | `systemAnomaly` | `low` | 301=AC loss, 302=low battery |
| 320–329 | Communication trouble | `systemAnomaly` | `low` | 321=comm fault |
| 400–409 | Open/close (arm/disarm) | `accessViolation` | `low` | qualify by partition/user |
| 570–579 | Bypass | `accessViolation` | `medium` | 570=zone bypass |
| 601–609 | Test signals | `systemAnomaly` | `low` | suppress from triage when configured |

**Restore handling:**
- When `qualifier == restore`, prefix `description` with `"[RESTORE] "`.
- Set `isRestore: true`.
- Do NOT lower the severity for life-safety codes (100–129). Restores of life-safety events still require operator acknowledgement.
- Lower severity by one step for burglary restores (130–139): `high` → `medium`.

**Unknown code fallback:**
- Map to `IncidentType.other`, `IncidentSeverity.medium`.
- Include the raw event code in `description` for operator review.

### Mapping method signature

```dart
ContactIdEvent map({
  required ContactIdFrame frame,
  required ContactIdPayload payload,
});
```

---

## 5. Integration with Incident Triage Agent

### Class: `AlarmTriageGateway`

**File:** `lib/application/alarm_triage_gateway.dart` *(new)*

**Responsibilities:**
- Subscribe to the `ContactIdReceiverService.frames` stream.
- For each `ContactIdFrame`, invoke `ContactIdPayloadParser` then `ContactIdEventMapper`.
- Construct an `OnyxWorkItem` with `intent: OnyxWorkIntent.triageIncident`.
- Submit the `OnyxWorkItem` to `OnyxCommandBrainOrchestrator.decide()`.
- Persist the raw `ContactIdEvent` to the event store for the audit trail.
- Suppress test signals when operator has enabled test-signal filtering.
- Route restore events to a separate `onRestore` callback rather than full triage.

### `OnyxWorkItem` Construction

The gateway must populate these fields from the `ContactIdEvent`:

| `OnyxWorkItem` field | Source |
|----------------------|--------|
| `intent` | `OnyxWorkIntent.triageIncident` |
| `prompt` | Built from `description`, severity, zone, partition |
| `clientId` | Resolved by account-number → client lookup |
| `siteId` | Resolved by account-number → site lookup |
| `incidentReference` | `contactIdEvent.eventId` |
| `sourceRouteLabel` | `"SIA DC-09 / Contact ID"` |
| `createdAt` | `receivedAtUtc` |
| `contextSummary` | `"Panel: {account} | Zone: {zone} | Partition: {partition}"` |
| `hasHumanSafetySignal` | `true` when severity == critical |

**Prompt construction example:**
```
[ALARM] Burglary — Interior zone (zone 03, partition 01)
Panel: 1234 | Severity: HIGH | Received: 2026-04-07T09:14:32Z
SIA DC-09 Contact ID event. Operator action required.
```

### Account → Client/Site Resolution

- The gateway requires an `AccountRegistry` (interface, not defined here) that resolves a 4-digit account number to `(clientId, siteId)`.
- If the account is unknown, use `clientId: 'unknown_account_{accountNumber}'` and log a structured warning. Do not drop the event.

### Stream Lifecycle

- The gateway starts listening when `start()` is called.
- It stops (cancels subscription, closes receiver) when `dispose()` is called.
- It must not retain references that prevent GC after disposal.

---

## 6. Buffering, Replay Safety, and Observability

### Buffering

- The `ContactIdReceiverService` must use a per-connection byte buffer (not a fixed-size buffer) to handle partial frame delivery over TCP.
- Frames are separated by `CRLF` (`\r\n`). Buffer until `\r\n` is received, then parse.
- If a partial frame remains in the buffer after a connection drops, discard it and emit a structured warning log.

### Replay Safety

- Duplicate detection is per-account (4-digit account number).
- The receiver maintains a `Map<String, int> lastSequencePerAccount` in memory.
- On service restart, the map resets — cross-restart duplicate detection is out of scope for v1 but should be noted as a gap.
- The domain layer (triage gateway) receives `isDuplicate: true` frames and must decide whether to act (by default: suppress triage, persist the frame to audit log only).

### Observability

Every inbound frame must produce one structured log entry containing:

```
{
  "event": "sia_dc09_frame_received",
  "account": "<4-digit>",
  "receiver": "<4-digit>",
  "sequence": <int>,
  "encrypted": <bool>,
  "duplicate": <bool>,
  "crc_ok": <bool>,
  "event_code": <int>,
  "qualifier": "<newEvent|restore|status>",
  "severity": "<low|medium|high|critical>",
  "incident_type": "<IncidentType.name>",
  "received_at_utc": "<ISO-8601>"
}
```

No key material, no raw decrypted payload beyond event code, zone, and partition.

---

## 7. File Manifest

| File | Layer | Status |
|------|-------|--------|
| `lib/infrastructure/alarm/contact_id_receiver_service.dart` | Infrastructure | Replace placeholder |
| `lib/infrastructure/alarm/sia_dc09_frame_parser.dart` | Infrastructure | New |
| `lib/infrastructure/alarm/contact_id_payload_parser.dart` | Infrastructure | New |
| `lib/domain/alarms/contact_id_event.dart` | Domain | Replace placeholder |
| `lib/domain/alarms/contact_id_event_mapper.dart` | Domain | Replace placeholder |
| `lib/application/alarm_triage_gateway.dart` | Application | New |

---

## 8. Test Coverage Requirements

All of the following must be covered before any production deployment. Labels follow the CLAUDE_CODE_ROLE.md action scheme.

| Test | Type | Action |
|------|------|--------|
| `SiaDc09FrameParser` parses valid unencrypted frame | Unit | AUTO |
| `SiaDc09FrameParser` parses valid AES-128-CBC encrypted frame | Unit | AUTO |
| `SiaDc09FrameParser` rejects CRC mismatch | Unit | AUTO |
| `SiaDc09FrameParser` rejects truncated frame | Unit | AUTO |
| `SiaDc09FrameParser` returns `SiaParseFailure.decryptionFailed` on bad key | Unit | AUTO |
| `ContactIdPayloadParser` parses all qualifier codes (1, 3, 6) | Unit | AUTO |
| `ContactIdPayloadParser` parses zone = 000 correctly | Unit | AUTO |
| `ContactIdEventMapper` maps all codes in the reference table | Unit | AUTO |
| `ContactIdEventMapper` maps unknown code to `other` | Unit | AUTO |
| `ContactIdEventMapper` sets `isRestore: true` on restore qualifier | Unit | AUTO |
| `ContactIdEventMapper` does not lower severity for critical-restore | Unit | AUTO |
| `ContactIdReceiverService` handles two simultaneous connections | Integration | REVIEW |
| `ContactIdReceiverService` sends ACK within 10s of valid frame | Integration | REVIEW |
| `ContactIdReceiverService` marks duplicate sequence as `isDuplicate` | Unit | AUTO |
| `ContactIdReceiverService` handles sequence number wrap-around | Unit | AUTO |
| `AlarmTriageGateway` produces `OnyxWorkItem` with correct fields | Unit | AUTO |
| `AlarmTriageGateway` suppresses duplicate frames from triage | Unit | AUTO |
| `AlarmTriageGateway` routes restores to `onRestore` not triage | Unit | AUTO |
| `AlarmTriageGateway` uses fallback clientId for unknown account | Unit | AUTO |

---

## 9. Open Decisions (DECISION label — blocked on Zaks)

1. **Port and bind address configuration.** Where does the receiver port live? Options: `config/onyx.local.json`, environment variable, or Supabase remote config.

2. **AES key storage.** The 16-byte AES-128 key is sensitive. It cannot live in `config/onyx.local.json` in plaintext. Options: OS keychain, environment variable (`CONTACT_ID_AES_KEY` hex), or Supabase vault secret. Must be decided before any deployment.

3. **Account → Client/Site registry.** The `AccountRegistry` interface needs a concrete implementation. Options: hardcoded YAML file per deployment, Supabase table, or admin UI in ONYX. The registry must support hot-reload without restarting the TCP server.

4. **Test signal suppression.** Some panels send periodic test events (code 601–609). Should ONYX silently drop these, persist-only, or surface them as low-priority system notifications? Default recommendation: persist-only, no triage.

5. **Multi-account AES keys.** DC-09 allows per-account encryption keys. If any monitored panel uses a different key than the global key, the gateway architecture must support a `Map<String, Uint8List> keyPerAccount`. Currently specced as a single global key — confirm scope.

6. **Restart persistence for duplicate tracking.** Cross-restart duplicate detection requires persisting `lastSequencePerAccount` to durable storage. Out of scope for v1 — but confirm this is acceptable for the first deployment window.

---

## 10. Risks and Constraints

| Risk | Severity | Mitigation |
|------|----------|------------|
| AES key in memory after disposal | High | Overwrite key bytes to zero in `dispose()` |
| TCP socket exhaustion under flood | Medium | Cap max simultaneous connections; close idle sockets aggressively |
| Sequence number reset on panel restart | Low | Log and clear the per-account last-sequence on large backward jump (e.g., > 32768 steps back) |
| `pointycastle` AES performance | Low | AES-128-CBC is fast; not a bottleneck at alarm panel throughput |
| Flutter web target incompatibility | Medium | `dart:io` `ServerSocket` is not available on web. The receiver must run as a native Dart server process or be conditionally compiled out of web builds |

---

## Recommended Implementation Order for Codex

1. Implement `ContactIdPayload` data class and `ContactIdPayloadParser` (pure, easiest to unit test).
2. Implement `ContactIdEvent` domain model.
3. Implement `ContactIdEventMapper` with the full reference table.
4. Implement `SiaDc09FrameParser` — unencrypted path first, then add AES-128-CBC.
5. Implement `ContactIdReceiverService` TCP server using the parser.
6. Implement `AlarmTriageGateway` integrating the service with the `OnyxCommandBrainOrchestrator`.
7. Write all unit tests listed in §8.
8. Wire `AlarmTriageGateway` into `main.dart` behind the DECISION items in §9.

Do not begin step 8 until all DECISION items are resolved with Zaks.
