# Audit: news_intelligence_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/infrastructure/intelligence/news_intelligence_service.dart` + `test/infrastructure/news_intelligence_service_test.dart`
- Read-only: yes

---

## Executive Summary

The service is well-structured for its scope: clean credential guard logic, consistent normalization via a single `_normalizeArticles` path, solid diagnostic and probe surfaces. The test file covers the happy path and several edge cases competently.

Two concrete bugs are present. The most significant is a structural incoherence in `fetchLatest` — providers are awaited sequentially but the design pretends to be concurrent via a stale `requests` accumulator. The second is an unguarded `jsonDecode` in `_parseCommunityFeed` that will surface as an opaque runtime exception with no provider attribution. A third concern — hardcoded geography in `_scoreArticle` — couples the service to a specific deployment region and will silently produce wrong risk scores everywhere else.

Test coverage is good for credential state and normalization but has gaps on all three non-newsapi.org / non-newsdata.io providers, malformed community feed input, and the empty-providers-after-fetch error path.

---

## What Looks Good

- `_hasUsableCredential` / `_hasPlaceholderCredential` logic is solid and consistently applied; placeholder detection covers `replace-me`, `<...>`, and `your_*_here` forms.
- `_normalizeArticles` centralizes all field extraction and record construction behind a single path; adding a new provider requires only a new `_fetch*` method.
- `dispose()` correctly tracks `_ownsClient` to avoid closing an injected client — test verifies this.
- `_throwIfFailed` extracts error detail from response JSON before throwing, giving callers actionable messages.
- `probeProvider` falls through to a safe `unsupported` diagnostic rather than throwing on unknown providers.
- `configuredProviders` and `diagnostics` are unmodifiable — callers cannot mutate service state via these accessors.
- `_unixSecondsToIso` guards against zero/negative epoch values before conversion.

---

## Findings

### P1 — Sequential fetches in `fetchLatest` despite a concurrent-looking accumulator
- **Action: REVIEW**
- `collect()` (line 336) is defined as an async function that `await`s each provider action before returning. The outer `fetchLatest` body calls `await collect(...)` for each provider in sequence (lines 349, 360, 370, 381, 392, 404). The `requests` list (line 332) accumulates already-resolved `Future.value(records)` and is then re-awaited in a second loop (lines 421-424). All provider HTTP calls are therefore serial.
- **Why it matters:** With four providers configured, a 1-second response time per provider stacks to 4+ seconds before the caller receives any results. The `requests` list creates a false impression that parallel dispatch was intended.
- **Evidence:** `news_intelligence_service.dart:332-424`
- **Suggested follow-up for Codex:** Validate whether concurrent dispatch via `Future.wait` is safe given that `feedDistribution` is mutated inside `collect`. If yes, convert to parallel dispatch with a guarded `feedDistribution` update.

---

### P1 — Unguarded `jsonDecode` in `_parseCommunityFeed`
- **Action: AUTO**
- `_parseCommunityFeed` (line 674) calls `jsonDecode(communityFeedJson)` with no try/catch. `communityFeedJson` is a raw string supplied at construction time from env; if it is malformed JSON, the call throws a `FormatException` with no provider attribution. In `fetchLatest`, the community feed path wraps the call in `async =>` (line 407) but the outer `collect` does not catch exceptions, and neither does `fetchLatest`. The error will propagate as an unattributed `FormatException` indistinguishable from an HTTP failure.
- **Why it matters:** A misconfigured `ONYX_COMMUNITY_FEED_JSON` silently breaks the entire `fetchLatest` call rather than degrading gracefully or reporting a provider-scoped failure.
- **Evidence:** `news_intelligence_service.dart:669-730`, specifically line 674.
- **Suggested follow-up for Codex:** Wrap `jsonDecode(communityFeedJson)` in a try/catch inside `_parseCommunityFeed`; rethrow as a `FormatException` with `community-feed: invalid JSON — <original message>`.

---

### P2 — `_scoreArticle` hardcodes Sandton and Gauteng as location boosters
- **Action: DECISION**
- Lines 822-823 unconditionally add +10 to the risk score if the article text contains `'sandton'` or `'gauteng'`. This logic is baked into the shared scoring method used by all providers.
- **Why it matters:** Any deployment outside the Sandton/Gauteng geography receives miscalibrated scores. Articles mentioning those terms from an unrelated context (e.g. national crime statistics) will be over-scored regardless of site context. The `regionId` and `siteId` are available at the call site and are unused by `_scoreArticle`.
- **Evidence:** `news_intelligence_service.dart:822-823`
- **Suggested follow-up for Codex:** Validate whether `_scoreArticle` should accept a `Set<String> locationTerms` derived from `regionId`/`siteId` at the call site instead of hard-coding region names.

---

### P2 — `_fetchWorldNewsApi` always makes two requests on any non-2xx first attempt
- **Action: REVIEW**
- The retry loop (lines 579-593) iterates both auth strategies in sequence and breaks only on a 2xx. If the first attempt returns any non-2xx, the second attempt fires unconditionally, even for 4xx responses (e.g. 403 Forbidden, 404 Not Found) where a retry will not recover.
- **Why it matters:** Non-transient failures (wrong endpoint, 403, etc.) always generate two outbound requests per `fetchLatest` or `probeProvider` call.
- **Evidence:** `news_intelligence_service.dart:579-599`
- **Suggested follow-up for Codex:** Break early on 4xx responses (excluding 401/403 where switching auth strategy may help) rather than always attempting both strategies.

---

### P2 — `_fetchNewsApiAi` evaluates `decoded['articles']` twice
- **Action: AUTO**
- Lines 535-537 call `_asMap(decoded['articles'])['results']` twice — once to check if it `is List`, once to extract the value. A single local variable assignment would eliminate the double traversal and the double cast.
- **Evidence:** `news_intelligence_service.dart:535-537`
- **Suggested follow-up for Codex:** Extract `_asMap(decoded['articles'])` into a local variable before the branch.

---

### P3 — No HTTP timeout on any outbound request
- **Action: REVIEW**
- All `_client.get(...)` and `_client.post(...)` calls have no timeout. A stalled provider will block the calling isolate indefinitely.
- **Why it matters:** In a monitoring context where `fetchLatest` is called on a schedule, a stalled provider blocks the entire news intelligence pipeline until the OS-level socket timeout fires (which can be minutes).
- **Evidence:** `news_intelligence_service.dart:452, 488, 527, 585-587, 645`
- **Suggested follow-up for Codex:** Confirm whether the injected `http.Client` is wrapped with a timeout at the call site upstream, or whether per-request timeouts should be added here.

---

### P3 — `communityFeedJson` entire payload stored as string in memory
- **Action: REVIEW** (suspicion, not confirmed bug)
- `communityFeedJson` is accepted as a raw env-injected string and stored as a field for the lifetime of the service (lines 61, 84-85). For large community feeds this is a bounded cost, but it is never re-read from env — the feed is frozen at construction. If the env var represents a dynamic or frequently updated feed, callers must reconstruct the service to pick up changes.
- **Evidence:** `news_intelligence_service.dart:61, 84-85`
- **Suggested follow-up for Codex:** Verify whether `communityFeedJson` is expected to be static or dynamic. If dynamic, document that the service must be reconstructed.

---

## Duplication

### `_firstNonEmpty` double-trims
- Every call site passes `.trim()` on each argument before passing to `_firstNonEmpty`, and `_firstNonEmpty` (line 914) also trims each value internally.
- Files involved: `news_intelligence_service.dart:467-473, 503-511, 551-558, 618-625, 655-666, 695-720`
- Centralization candidate: Remove `.trim()` calls from all call sites and let `_firstNonEmpty` own trimming exclusively — or remove trimming from `_firstNonEmpty` and keep it at call sites. Currently both places trim.

### `_locationQuery` called once per provider in `probeProvider` but shared in `fetchLatest`
- `probeProvider` recomputes `_locationQuery` inside each `switch` arm (lines 241, 247, 253, 259). `fetchLatest` correctly computes it once (line 334). Minor inconsistency that is not a bug but adds redundant computation in probe paths.
- Files involved: `news_intelligence_service.dart:241, 247, 253, 259, 334`

---

## Coverage Gaps

| Gap | Risk |
|-----|------|
| No test for `newsapi.ai` provider fetch (happy path) | Medium — provider-specific JSON shape `decoded['articles']['results']` branch at line 535 is untested |
| No test for `openweather.org` provider fetch | Medium — unix-seconds timestamp path (`_unixSecondsToIso`) is not exercised in integration |
| No test for `_parseCommunityFeed` with `messages` key | Low — `items` key is tested, `messages` fallback at line 681 is not |
| No test for malformed `communityFeedJson` | High — the unguarded `jsonDecode` at line 674 should have a test asserting either graceful degradation or a scoped error |
| No test for `fetchLatest` where all providers return empty results | Medium — the `FormatException('Configured news providers returned no ingestible records.')` at line 427 is not covered |
| No test for `_scoreArticle` location terms affecting score | Low — scoring behavior is asserted via `greaterThanOrEqualTo` thresholds but the Sandton/Gauteng +10 path has no direct test |
| No test for `configurationHint` when `configuredProviders.isEmpty` and no placeholders | Low — the hint path at line 142-143 is not covered |
| No test for `worldnewsapi.com` `news` key vs `articles` key fallback | Low — `_firstNonEmptyList` at line 601 is partially exercised but the `news` key path is not |

---

## Performance / Stability Notes

- **Serial provider chain in `fetchLatest`** is the primary latency concern. Four providers at 500ms average = 2s minimum wall time before any batch is returned. Parallel dispatch would reduce this to max-provider-latency.
- **No request timeout** means a stalled remote silently starves downstream consumers. This is low probability but high impact in a monitoring context.
- **`_extractErrorDetail`** limits truncated error messages to 180 characters (line 936), which is appropriate — no risk of large blobs being stored or logged.

---

## Recommended Fix Order

1. **Wrap `jsonDecode` in `_parseCommunityFeed`** — P1, AUTO, minimal blast radius, protects the entire `fetchLatest` call from an opaque crash on misconfigured env.
2. **Add test for malformed `communityFeedJson`** — pairs with #1, locks the fix in.
3. **Add tests for `newsapi.ai` and `openweather.org` fetch paths** — medium-risk coverage gaps on provider-specific JSON branches.
4. **Fix `fetchLatest` serial/concurrent incoherence** — REVIEW required; architectural decision on whether `Future.wait` is safe here. High latency impact if multiple providers are configured.
5. **Decide on `_scoreArticle` location coupling** — DECISION; product/architecture call before Codex can act.
6. **Add HTTP timeout** — REVIEW to confirm whether it belongs at call site or upstream client.
7. **Remove double-trimming in `_firstNonEmpty` call sites** — LOW, cosmetic, AUTO.
8. **Extract `_asMap(decoded['articles'])` local in `_fetchNewsApiAi`** — trivial, AUTO, correctness-neutral.
