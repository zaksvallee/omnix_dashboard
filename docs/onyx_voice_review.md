# ONYX Voice Review

This note tracks the transcript-style review fixture for ONYX client comms voice.

## What it covers

- Vallee residential intake reassurance
- Vallee pressured follow-up with learned approval style active
- Vallee reassurance-tag follow-up
- Vallee ETA-crisp tagged follow-up
- Vallee on-site update
- Vallee closure
- Vallee camera / daylight validation
- Vallee camera-validation tagged follow-up
- Enterprise tower access issue
- Enterprise tower formal-operations status tag follow-up
- Enterprise tower worried intake
- Enterprise tower ETA follow-up
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

It now also helps us spot:

- whether visual-check language stays plain on residential lanes
- whether enterprise worry replies stay calm without sounding soft or robotic
- whether ETA follow-ups stay concise without inventing timing
- whether operator tags like `Warm reassurance`, `ETA crisp`, and `Camera validation` actually shift the fallback voice in the intended direction

The transcript now groups both the A/B pair blocks and the broader journey cases by site type, so the Vallee residential comparisons stay clustered and the Tower enterprise comparisons stay clustered. Both the pair groups and the journey subsections carry short `focus=...` notes so reviewers can see the intended lane coverage at a glance. Each pair includes both an `expectedShift=...` note and an `observedDifference=...` summary so we can compare style drift quickly before reading the broader lane journey cases.

## Legend

- `focus`: what the grouped section is meant to cover during review
- `expectedShift`: the wording change we hope the tag or memory will cause
- `observedDifference`: the wording difference the transcript actually shows

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
- tagged review lanes visibly shifting the wording in the expected direction without becoming awkward or repetitive
- closure sounding settled and confident without losing the reopen cue
