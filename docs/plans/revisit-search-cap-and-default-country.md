# Revisit list — two product issues found during store-screenshot capture

Recorded on 2026-10-11 while preparing Play Store and App Store screenshots. Neither blocks
submission. Both were found by using the app the way a store reviewer would.

---

## 1. Search returns at most 5 results with no way to load more

### Symptom

Searching a term that matches more than five messages returns exactly five rows. The result list
shows blank space below the fifth row and offers no "load more" control, so the remaining matches
are unreachable.

### Evidence

Measured on the reviewer mailbox during capture, three separate queries:

| Query | Matches in mailbox | Rows returned |
| --- | --- | --- |
| `atlas` | 8 | **5** |
| `feedback` | 4 | 4 |
| `workshop` | 3 | 3 |

No query ever returned more than five rows.

### Theory already ruled out: full-text index lag

The first hypothesis was that Stalwart indexes new mail asynchronously, so recently delivered
messages were not yet searchable. **Disproven.** A message delivered minutes earlier
(`Atlas community feedback`, 08:40) was returned by the `feedback` query, so freshly delivered
mail is indexed and searchable. The cap is real.

Related observation from the same session: when a highlighted match sits at the right edge of the
row, the highlight box butts against the timestamp and the two run together (`feedback8:40`).
Cosmetic, separate from the cap.

### Where to look

- `lib/features/search/email/domain/notifier/search_email_notifier.dart`
  - `limit` selection around line 225: `RefreshChangesIntent` re-queries with
    `UnsignedInt(intent.currentCount)`, otherwise `spec.limit` is used
  - `SearchMoreEmailInteractor` (line 40) and the `loadMore` state transitions (lines 120-160)
- `lib/features/search/email/domain/model/search_email_query_params.dart`
  - Carries `limit`, `position`, `lastEmailId`; `lastEmailId` is the `searchMore` anchor
- `lib/features/search/email/domain/execution/search_execution_intent.dart`
  - Documents the caller-supplied anchor for the next page
- `lib/features/search/email/domain/model/search_email_result.dart` — `LoadMoreState`
- Background reading: `docs/adr/0052-logic-sort-order-in-search.md`,
  `docs/adr/0093-search-filter-single-source-of-truth.md`

Paging machinery already exists, so the question is why the UI stops at five: either the initial
`limit` is five, or the `loadMore` trigger is never wired to a scroll/gesture.

### Hypotheses to test

1. The first-page `limit` is fixed at 5 and nothing requests the next page.
2. `loadMore` fires but the result is discarded (wrong anchor, or `position` resets on each query).
3. The scroll-to-load-more listener is not attached in the current search view.
4. Results are capped client-side after the JMAP response rather than in the query.

### Reproduction

1. Sign in as the reviewer mailbox.
2. Search a term present in more than five messages (five `project` mails exist; seed more to
   exceed five).
3. Observe exactly five rows and no pagination affordance.

### Acceptance criteria

- A query matching N > 5 messages can reach all N results.
- The load-more path is either wired to a real affordance (or scroll) or deliberately removed, in
  which case the initial `limit` must cover the full result set.
- Regression test covers a query with more results than the page size.
- The highlight/timestamp overlap is either fixed or explicitly accepted.

---

## 2. Default country follows the device locale, and falls back to Thailand

### Symptom

The welcome screen preselects the country from the device locale. An iPhone simulator configured
for `th_TH` shows 🇹🇭 **+66**, while an Android AVD defaulted to `en_US` shows 🇺🇸 **+1** — the same
build, two different defaults.

### Current behaviour

`lib/features/numberinbox/country.dart`:

- `deviceRegionCode()` reads `ui.PlatformDispatcher.instance.locale.countryCode`
- `countryForRegionCode()` resolves that code case-insensitively
- **Fallback is Thailand**: when the code is null, empty, or unknown, it returns `countries.first`,
  which is Thailand. This is inherited from the upstream Tmail implementation, not a recent choice.
- `defaultCountry({String? regionOverride})` is the entry point; `regionOverride` exists for tests
  and callers that already know their region

Callers:

- `lib/features/starting_page/presentation/twake_welcome/twake_welcome_controller.dart:36`
- `lib/features/numberinbox/account_deletion_page.dart:44`

### Why it matters

It is correct behaviour, not a bug — but it is a recurring source of friction:

- During capture it nearly caused a wrong-number login: the plan has to tell operators to
  "tap the country picker → United States" on every login, because +66 is preselected on a Thai
  locale device.
- The Thailand fallback means a region-less locale also lands on +66, which is a surprising default
  for a product sold internationally.

### Proposed change (not yet approved)

Remember the last country the user selected and default to it on the next launch, falling back to
the device locale for a first-time user. `defaultCountry` already accepts `regionOverride`, so the
caller-side change is small; persistence needs a local setting alongside the existing
`CachingManager` / language-cache pattern.

Decide separately whether the Thailand fallback should stay. It is upstream behaviour and changing
it affects every locale-less device.

### Acceptance criteria

- A returning user sees their last-used country preselected.
- A first-time user still gets the device-locale country.
- Tests cover both paths, plus an unknown/empty region code.

---

## 3. Accepted: grey arc in the iPad screenshot corners

**Decision (2026-10-11): accepted, no action.**

The iPad captures show a thin grey arc (`rgb(158,158,158)`) in the bottom-right corner, on
shots 01-04 and under the UI on 05-06.

What was ruled out along the way:

- Not app UI. The inbox has no such element.
- Not macOS window decoration. Simulator.app's GUI is not running; the devices are booted
  headlessly via `simctl`, and a `simctl io ... screenshot` capture contains the arc too.
- Therefore it is the simulator runtime rendering the iPad's **rounded display corner**, with the
  bezel colour showing outside the rounded screen.

Left as captured. Apple's iPad Pro reference screenshots also show rounded corners, so the artifact
is defensible. Revisit only if a store reviewer rejects it.
