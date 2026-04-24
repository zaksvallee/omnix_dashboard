# Worker FD-release bug — Phase A investigation

## Code path confirmation

The latent leak site is confirmed in the runtime implementation at
[`bin/onyx_camera_worker.dart`](/Users/zaks/omnix_dashboard/bin/onyx_camera_worker.dart).

- The service owns a long-lived shared ISAPI client via `_buildIsapiHttpClient()`
  at lines 2239-2241, stored in `_client` by the constructor at line 2362.
- `_streamSubscription` exists as a field at line 2293 and `stop()` tries to
  cancel it at lines 2554-2560.
- `_runConnectionLoop()` obtains a fresh `http.StreamedResponse` on each
  iteration at lines 2898-2908.
- The non-running short-circuit drains the response stream at lines 2909-2911.
- The non-2xx branch consumes and drains the response via
  `http.Response.fromStream(response)` at line 2914.
- The success path does **not** retain or cancel the owning response. Instead it
  passes only `response.stream` into `_consumeAlertStream(...)` at line 2938,
  then reconnects after `_consumeAlertStream(...)` returns and the stream closes
  at line 2941.
- `_consumeAlertStream(...)` never assigns `_streamSubscription`; it only reads
  the stream with `await for` (lines 3015-3032) and then nulls the field in
  `finally` at lines 3053-3054.

That means the one field intended to let `stop()` / generation changes cancel
the active alert stream is never wired to the active response at all. On any
legitimate reconnect event, the loop discards the completed `StreamedResponse`
without explicit cancellation / cleanup on the success path.

There is a second copy of the same service in
[`lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart`](/Users/zaks/omnix_dashboard/lib/application/site_awareness/onyx_hik_isapi_stream_awareness_service.dart),
with the same structural pattern:

- `_streamSubscription` field at line 54
- `stop()` cancellation path at lines 159-160
- `_runConnectionLoop()` success path at lines 320-365
- `_consumeAlertStream()` clearing `_streamSubscription` without ever assigning
  it at lines 416-456

Current tests exercise the library copy, not the runtime copy in `bin/`.

## Proposed minimal fix

Recommend **Option 2**: wire `_streamSubscription` to the active alert-stream
response and make each reconnect iteration explicitly cancel / clear that
subscription before advancing.

Why this option fits the actual code best:

- The code already has the `_streamSubscription` field and `stop()` cleanup
  path, so this is filling in a missing ownership link rather than inventing a
  new lifecycle model.
- It directly addresses the present bug: the active response is not cancelable
  by `stop()` or generation changes because `_streamSubscription` is never set.
- It is smaller and less invasive than separating the alert stream into a new
  dedicated client immediately.

Rough shape:

1. Change `_consumeAlertStream(...)` so it owns an explicit
   `StreamSubscription<List<int>>` instead of an implicit `await for`.
2. Assign that subscription to `_streamSubscription` before awaiting
   completion.
3. In `finally`, cancel the subscription if still active and clear
   `_streamSubscription` only if it still points at the same subscription.
4. Mirror the same change into the duplicated library copy, or extract the
   shared logic so the runtime and tested implementation cannot drift again.

If Phase B finds that canceling the explicit subscription does **not** release
the underlying socket promptly enough under induced reconnects, the next
escalation should be the dedicated stream-client separation from the runtime
profile's option 3. That should be treated as a fallback, not the first move.

## LOC estimate

Estimated runtime fix size:

- `bin/onyx_camera_worker.dart`: about 20-30 LOC
- mirrored change in the duplicated library copy: another 15-25 LOC

Repo-wide net change is therefore likely in the 35-50 LOC range unless the
duplicate implementations are first consolidated.

## Test impact

Nearest existing coverage is in
[`test/application/onyx_hik_isapi_stream_awareness_service_test.dart`](/Users/zaks/omnix_dashboard/test/application/onyx_hik_isapi_stream_awareness_service_test.dart),
especially the reconnect test at lines 274-303. That test currently proves only
that the service retries and reconnects:

- `client.requestCount >= 2`
- `service.isConnected == true`

It does **not** assert that the previous alert-stream subscription was canceled
or that reconnects avoid accumulating active resources.

Recommended new assertion:

- use a fake stream whose `onCancel` completes a `Completer<void>`
- trigger one reconnect
- assert the first subscription's cancel path fired before or during the second
  successful connection

Because the test suite currently targets the library copy rather than the
runtime copy in `bin/`, Phase B should either:

- mirror the fix into both copies and extend the library-copy test, or
- remove the duplication first so the runtime path is what the tests actually
  exercise

There is currently no direct unit test for FD growth itself.

## Open questions

- Does canceling the active `http.ByteStream` subscription release the
  underlying `IOClient` connection promptly enough under `package:http`, or
  will Phase B need to escalate to a dedicated per-stream client after all?
- Should the duplicate service implementation in `lib/` remain in sync manually,
  or is this the point where the project should stop carrying two copies of the
  same reconnect logic?
- Is there any production path that still instantiates the library copy
  directly, or is it effectively test-only now?

## Recommended next action

Recommend handoff to **CC** for Phase B.

Reason: the fix is still small, but it sits in subtle connection-lifecycle code
with two divergent copies in the repo and tests that currently exercise only
one of them. That is within CC's stronger envelope for surgical Dart changes,
especially after today's proxy-streaming fix followed the same investigate →
implement → verify pattern successfully.
