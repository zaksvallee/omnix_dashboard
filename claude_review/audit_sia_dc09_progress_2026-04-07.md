# Audit: SIA DC-09 Implementation Progress

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/infrastructure/alarm/`, `lib/domain/alarms/`, and corresponding tests
- Read-only: yes

---

## Executive Summary

The SIA DC-09 stack is well-structured and further along than a stub. The domain model, frame parser, payload parser, TCP receiver, and event mapper are all substantively implemented and carry real tests. The AES-128-CBC decryption and CRC16/ARC computation are correctly wired. Contact ID payload parsing covers all three qualifier codes and enforces the 15-character fixed-length contract.

Two real bugs exist: the encrypted-payload block-alignment guard uses `.isOdd` instead of `% 16 != 0`, and the TCP stream is decoded with `utf8.decode(allowMalformed: true)` where `latin1.decode` is required for safe ASCII framing. Both can silently corrupt frames rather than surface clean parse errors.

The largest structural gap is the missing integration pipeline: `ContactIdFrame.payloadData` is never routed through `ContactIdPayloadParser` or `ContactIdEventMapper`. The three layers compile and test independently but are not wired together. No Supabase persistence or dispatch hand-off exists yet.

---

## What Looks Good

- **CRC16/ARC** is correctly implemented: reflected polynomial `0xA001`, init `0x0000`, operating byte-by-byte. Result is zero-padded to 4 hex digits. (`sia_dc09_frame_parser.dart:118–131`)
- **AES-128-CBC decryption** correctly extracts the 16-byte IV as the first block, feeds remaining bytes to `PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))`, and propagates `FormatException` and generic errors as `SiaParseFailure`. (`sia_dc09_frame_parser.dart:133–175`)
- **Frame structure parsing** correctly handles both `/` (plain) and `*` (encrypted) prefixes, validates header length to 13, validates receiver and account numbers as 4 ASCII digits, validates hex sequence number, and enforces `closeParen + 5 == line.length` for the 4-character trailing CRC. (`sia_dc09_frame_parser.dart:16–107`)
- **TCP receiver** uses `ServerSocket` with port 0 for test isolation, per-connection idle timers, `\r\n` framing with a string accumulation buffer, ACK/NAK responses, and per-account modular sequence duplicate detection. (`contact_id_receiver_service.dart`)
- **Sequence duplicate detection** uses `(delta) & 0xFFFF` modular arithmetic so 65535→0 is correctly treated as an advance (delta=1 < 0x8000). Confirmed by test. (`contact_id_receiver_service.dart:152–165`)
- **Clock injection** in `SiaDc09FrameParser` via the `now` parameter makes timestamp logic deterministically testable. (`sia_dc09_frame_parser.dart:8–13`)
- **Event mapper** SHA-256 event ID includes raw frame, receiver, account, sequence, event code, partition, zone, and timestamp — collision resistance is strong. (`contact_id_event_mapper.dart:52–68`)
- **Tests have real substance**: integration tests spin up a live `ServerSocket`, send real TCP frames, and assert on emitted events and ACK bytes.

---

## Findings

### P1 — Bug: AES block-alignment guard uses `.isOdd` instead of `% 16 != 0`

- Action: AUTO
- **Finding**: The encrypted payload byte-length is validated with `encryptedBytes.length.isOdd`. AES-128-CBC requires the ciphertext (post-IV) to be a multiple of 16 bytes. `.isOdd` passes lengths like 18, 20, 22, 26 — none of which are AES-aligned — meaning the cipher will throw at runtime. When it does, the generic `catch (error)` path produces a `decryptionFailed` failure, so the frame is rejected. The issue is that the early validation guard is wrong and the real validation is happening inside an exception catch, making the error message less informative and the code misleading.
- **Why it matters**: A legitimate encrypted frame with a non-16-aligned hex payload (malformed at source) will produce an opaque `decryptionFailed` instead of a clear `malformedFrame`. More importantly, the `isOdd` check signals an incorrect mental model of AES block requirements that could propagate to future code.
- **Evidence**: `lib/infrastructure/alarm/sia_dc09_frame_parser.dart:143`
  ```dart
  if (encryptedBytes.length < 32 || encryptedBytes.length.isOdd) {
  ```
  Correct guard: `encryptedBytes.length < 32 || encryptedBytes.length % 16 != 0`
- **Suggested follow-up**: Codex can replace the condition. Add a test case with a 34-byte encrypted payload (16-byte IV + 18 bytes, not 16-aligned) and confirm it returns `malformedFrame`.

---

### P1 — Bug: TCP frame buffer uses `utf8.decode(allowMalformed: true)` on an ASCII protocol

- Action: REVIEW
- **Finding**: `_handleConnection` accumulates frame data by concatenating `utf8.decode(data, allowMalformed: true)` results. SIA DC-09 frames are 7-bit ASCII (header digits, `/`/`*`, hex digits, parentheses, CRC hex). UTF-8 decoding is irrelevant, and `allowMalformed: true` means that if a TCP segment boundary splits a multi-byte sequence, a replacement character (U+FFFD, 3 bytes in UTF-8, not in the ASCII range) is silently inserted into the accumulation buffer. This corrupts the frame's hex payload, causing a CRC mismatch or encrypted-payload hex decode failure that reveals nothing about the root cause.
- **Why it matters**: This is a production data-integrity risk. A panel that sends frames with any byte above 0x7F (which the SIA DC-09 spec does not prohibit in the encrypted hex payload's surrounding structure) will trigger silent corruption at segment boundaries.
- **Evidence**: `lib/infrastructure/alarm/contact_id_receiver_service.dart:84`
  ```dart
  buffer += utf8.decode(data, allowMalformed: true);
  ```
  Correct approach: accumulate raw `Uint8List` bytes and call `latin1.decode` (or `ascii.decode`) once a `\r\n` terminator is found. Alternatively, keep raw `Uint8List` accumulation and convert to string per-frame.
- **Suggested follow-up**: This requires a buffer type change from `String` to `Uint8List` or `List<int>`. Codex should validate the fix is safe with the simultaneous-connection and partial-frame test cases.

---

### P1 — Architecture gap: No integration pipeline connecting the three layers

- Action: DECISION
- **Finding**: `ContactIdReceiverService.frames` emits `ContactIdFrame` objects containing `payloadData` as a raw string. `ContactIdPayloadParser.parse(payloadData)` and `ContactIdEventMapper.map(frame, payload)` exist but are never called anywhere in `lib/`. There is no coordinator, use-case, or application service that wires the three layers into a working alarm ingestion pipeline.
- **Why it matters**: The implementation is functionally inert end-to-end. A panel could connect, send frames, receive ACKs, and the system would emit `ContactIdFrame` events to a broadcast stream with no listener. No `ContactIdEvent` is ever created in production code paths.
- **Evidence**:
  - `lib/infrastructure/alarm/contact_id_receiver_service.dart` — `frames` stream has no consumer in `lib/`
  - `lib/infrastructure/alarm/contact_id_payload_parser.dart` — not imported by any non-test file
  - `lib/domain/alarms/contact_id_event_mapper.dart` — not imported by any non-test file
- **Suggested follow-up**: A new application service (e.g., `AlarmIngestionService` or `ContactIdIngestionCoordinator`) must subscribe to `frames`, run `ContactIdPayloadParser`, run `ContactIdEventMapper`, and route to persistence and dispatch. This is a product/architecture decision about where that coordinator lives and how it integrates with the existing monitoring watch or dispatch layers.

---

### P2 — Bug: `qualifierDetail` is silently dropped for all named event codes

- Action: AUTO
- **Finding**: `_descriptionFor` builds `qualifierDetail = ' status'` for `ContactIdQualifier.status` events, then uses it only in the generic range-catch arms. The specific named-code arms (100, 101, 111, 114, 121, 122, 130, 131, 161, 301, 302, 321, 570, 601) never interpolate `qualifierDetail`. A status-qualifier event for code 130 produces `'Burglary - perimeter (zone 003, partition 01)'` instead of `'Burglary - perimeter status (zone 003, partition 01)'`.
- **Why it matters**: Status events for well-known codes are silently mis-described. An operator viewing a status heartbeat on zone 130 cannot distinguish it from an active alarm from the description alone.
- **Evidence**: `lib/domain/alarms/contact_id_event_mapper.dart:145–159`
  ```dart
  return switch (eventCode) {
    100 => 'Medical alarm$detail',            // qualifierDetail missing
    130 => 'Burglary - perimeter$detail',     // qualifierDetail missing
    ...
  ```
- **Suggested follow-up**: Codex can insert `$qualifierDetail` before `$detail` in all named-code arms. Add a test asserting that `qualifier: status` for code 130 produces a description containing `' status'`.

---

### P2 — Bug: Single global AES key; no per-account key dispatch

- Action: DECISION
- **Finding**: `ContactIdReceiverService` takes a single `Uint8List aesKey` at construction time and applies it to all incoming frames regardless of `accountNumber`. SIA DC-09 deployments typically issue per-panel (per-account) keys. With a global key, any new panel requires a service restart, and a compromised key affects all accounts.
- **Why it matters**: Security boundary and operational correctness. If two panels use different AES keys, one will always produce `decryptionFailed`.
- **Evidence**: `lib/infrastructure/alarm/contact_id_receiver_service.dart:15,34` (`_aesKey` field, constructor)
- **Suggested follow-up**: This is a product decision — whether to support per-account keys (requires an account registry lookup before decryption) or accept single-key operation. The existing `alarm_account_registry_test.dart` may signal intent.

---

### P3 — Risk: `dispose()` double-call throws StateError on `framesController`

- Action: AUTO
- **Finding**: `dispose()` calls `stop()` then `_framesController.close()`. A `StreamController.close()` called on an already-closed controller throws `StateError: "Cannot add event after closing"`. If `dispose()` is ever called twice (e.g., in a widget teardown race), the second call hits a dead `stop()` but then tries to close an already-closed controller.
- **Why it matters**: Unhandled `StateError` in dispose paths typically surfaces as a crash in debug mode and a silent no-op in release mode depending on the Flutter error handler.
- **Evidence**: `lib/infrastructure/alarm/contact_id_receiver_service.dart:72–76`
- **Suggested follow-up**: Guard with `if (!_framesController.isClosed)` before closing. Alternatively, use `_framesController.isClosed` as the `isRunning` signal.

---

## Duplication

None identified within the five files. The CRC hex helper, hex decoder, and digit validators are private statics with no duplication across the infra/domain boundary.

---

## Coverage Gaps

### `sia_dc09_frame_parser_test.dart` — 4 tests

| Gap | Missing test |
|---|---|
| Encrypted payload not AES-aligned (18 bytes total) | Should return `malformedFrame`, not `decryptionFailed` |
| Header shorter than 13 chars | Path at line 40 |
| Non-digit receiver or account number | Path at line 51 |
| Empty frame string | Path at line 20 |
| Plaintext frame without `\r\n` terminator | Stripping logic at line 17–19 |
| Frame with `\r\n` in the middle of hex payload | Would break framing prematurely |

### `contact_id_payload_parser_test.dart` — 5 tests

| Gap | Missing test |
|---|---|
| Message type ≠ 18 (e.g. `'19'`) | Should throw with message containing "Unsupported" |
| Invalid qualifier code (`'0'`, `'2'`, `'4'`) | Should throw |
| Non-digit character in event code segment | Should throw |
| Maximum valid event code (`999`) | Boundary check |
| All-zeros payload `'000018100000000'` | Zero-value normality check |

### `contact_id_receiver_service_test.dart` — 4 tests

| Gap | Missing test |
|---|---|
| NAK sent for malformed frame | Protocol compliance |
| Idle timeout disconnects socket | Timer path at line 167–179 |
| Frame split across two TCP `data` events | Framing robustness |
| `start()` called twice is idempotent | Guard at line 46 |
| `stop()` while connections are active | Active socket teardown |
| `dispose()` called twice | `StateError` guard (P3 above) |
| `activeConnectionCount` reflects live connections | Property at line 43 |

### `contact_id_event_mapper_test.dart` — 5 tests

| Gap | Missing test |
|---|---|
| Status qualifier on named event code (e.g. 130) | Should contain `' status'` in description — exposes P2 bug |
| Event ID determinism | Same inputs → same SHA-256 ID |
| Event ID uniqueness | Different sequence numbers → different IDs |
| Description format for zone 000, partition 00 | Zero padding correctness |

### Integration

No test chains `ContactIdReceiverService` → `ContactIdPayloadParser` → `ContactIdEventMapper`. No test verifies that a complete encrypted frame arriving over TCP produces a `ContactIdEvent` with the correct `incidentType` and `severity`.

---

## Performance / Stability Notes

- **String accumulation buffer** (`buffer += utf8.decode(data)`): repeated string concatenation for long-lived connections allocates a new string on every `data` event. A `StringBuffer` would be more efficient. This is low priority given typical SIA DC-09 traffic rates.
- **Per-account sequence map** (`_lastSequencePerAccount`) is unbounded. A device that rotates through many account numbers (unlikely but possible in multi-tenant installations) will grow this map indefinitely. Low risk for a fixed-panel deployment.
- **Broadcast stream** with no back-pressure: if the `frames` consumer is slow or absent, `_framesController.add()` will buffer without bound. For low-volume alarm traffic this is acceptable, but worth noting if the service becomes a high-rate ingest point.

---

## Recommended Fix Order

1. **P1 — AES block-alignment guard** (`sia_dc09_frame_parser.dart:143`) — one-line fix, add test. `AUTO`.
2. **P1 — TCP decode: `utf8` → `latin1` or raw byte accumulation** (`contact_id_receiver_service.dart:84`) — data integrity risk, requires buffer refactor. `REVIEW`.
3. **P2 — `qualifierDetail` in named-code arms** (`contact_id_event_mapper.dart:145–159`) — string interpolation fix, add test. `AUTO`.
4. **P3 — `dispose()` double-call guard** (`contact_id_receiver_service.dart:72–76`) — one-line guard. `AUTO`.
5. **P1 — Integration pipeline** — wire `frames` stream through payload parser and event mapper into an application service. `DECISION` (architecture choice needed before implementation).
6. **P2 — Per-account AES key dispatch** — depends on `AlarmAccountRegistry`. `DECISION`.
7. **Coverage gaps** — add missing tests for NAK, idle timeout, split TCP frames, and mapper qualifierDetail. These can mostly be implemented after fixes 1–4 land.
