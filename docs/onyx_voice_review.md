# ONYX Voice Review

This note tracks the transcript-style review fixture for ONYX client comms voice.

## What it covers

- Vallee residential intake reassurance
- Vallee pressured follow-up with learned approval style active
- Vallee on-site update
- Vallee closure
- Enterprise tower access issue
- Enterprise tower status follow-up
- Enterprise tower closure

The current transcript artifact lives at:

- `test/fixtures/telegram_ai_voice_review_transcripts.txt`

It is also enforced by:

- `test/application/telegram_ai_assistant_service_test.dart`

## Why this exists

The standard responder tests are good at checking single-turn rules like:

- escalation handling
- daylight / camera validation wording
- learned approval style usage
- delivery-mode compression

This transcript fixture adds a quick human-readable review of whether ONYX still feels coherent across a whole lane journey.

## Refreshing the transcript

To regenerate the voice review transcript from the current fallback responder:

```bash
dart run test/scripts/generate_telegram_ai_voice_review.dart --write
```

Then verify the responder suite:

```bash
flutter test test/application/telegram_ai_assistant_service_test.dart
```

## Review cues

When reading the transcript, check for:

- no robotic phrases like "received your message" or raw scope IDs
- residential lanes staying warmer than enterprise lanes
- pressure tightening the wording without turning cold or mechanical
- learned approval style staying visible without blocking sensible compression
- closure sounding settled and confident without losing the reopen cue
