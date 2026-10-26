# About screen: branded website link only

## Outcome

Keep the About NumberInbox screen, existing Settings entry, approved N/@ mark,
NumberInbox name, and tagline. Replace its legal paragraphs and source-specific
link with one clearly actionable `numberinbox.com` link that opens exactly
`https://numberinbox.com` through the existing URL launcher.

The rendered About screen will contain no Twake/LINAGORA attribution, AGPL or
open-source wording, GitHub URL, `/open-source` URL, or duplicated URL fallback.
Detailed attribution, license information, and corresponding source remain
accessible on the website. This request changes presentation; it does not
change the app's license or users' rights.

## Evidence and scope

Inspected on October 26, 2026:

- `lib/features/numberinbox/about_numberinbox.dart` contains the attribution,
  rights/warranty paragraph, `TextButton.icon`, and selectable source-page URL.
- `lib/main/utils/app_config.dart` defines `openSourceUrl`. The inspected app
  references are in the About screen; confirm all references before removing it.
- `test/branding/about_attribution_test.dart` has three widget tests for the old
  content, source-page launch, and narrow-screen layout.
- Sibling `../site/open-source.html` and `../site/licenses/AGPL-3.0.txt` exist.
  The site checker already requires open-source footer links. The site's root
  currently serves the privacy document; a marketing homepage redesign is not
  included in this change.
- `../platform/docs/16-branding.md` still explicitly requires an in-app Twake
  attribution and direct public repository URL. Update this stale requirement
  to reflect the user's approved change, retaining the public-source policy.
- The website's app-version table currently says no entries have been validated.
  Do not invent build/source records. Actual distributed builds need accurate
  records before release.

There are unrelated worktree changes. Leave them untouched and stage only this
task's files. Read applicable instructions in each repository before editing it.

## Licensing boundaries

The UI exception in AGPL section 5(d) is the basis for the proposed presentation:
interfaces that did not display Appropriate Legal Notices upstream need not be
made to display them in the modified version. The inspected upstream app source
does not show such a notice screen. This observation is not a substitute for a
review of any separately applicable notices or additional terms.

Preserve upstream source headers, copyright notices, license files, modification
records, and dependency notices. Keep the existing license and source-access
arrangements; do not remove bundled license material as part of this task.
Do not claim that a generic homepage link alone satisfies source-distribution
obligations. Keep clear source directions beside app downloads/store listings,
using the direct branded `/open-source` URL there, and maintain corresponding
source access for the distributed NumberInbox versions.

References:

- https://www.gnu.org/licenses/agpl-3.0.html (sections 4–6)
- https://www.gnu.org/licenses/gpl-faq.en.html

## Implementation

### 1. Mobile configuration and About widget

1. Add `AppConfig.websiteUrl = 'https://numberinbox.com'` as a fixed string.
   Do not read this public destination from backend responses, account state,
   environment files, or runtime configuration.
2. Search all consumers of `openSourceUrl`. Remove that constant if unused
   after the About change; retain it with its original meaning if another real
   consumer needs it. Do not rename a source-page constant while retaining a
   misleading name or change unrelated URLs.
3. Remove the About widget's attribution constant, legal paragraphs, old
   source-specific link label, and duplicate `SelectableText` URL.
4. Keep a single `TextButton.icon` with the visible label `numberinbox.com`,
   the existing external-link icon, and `NumberInboxPalette.actionBlue`.
   Its callback is `AppUtils.launchLink(AppConfig.websiteUrl)`.
5. Retain `SingleChildScrollView`, current padding, logo asset and dimensions,
   title, name typography, tagline, and existing navigation. Let the URL action
   accommodate large text within the available width.
6. Remove the obsolete comment claiming the old About wording is required by
   `docs/16-branding.md`. Preserve this screen's current language policy.

Do not change `AppUtils.launchLink`, add a URL-launch abstraction, introduce a
new UI framework, or add dependencies. This link carries no account details,
credentials, query parameters, or tracking identifiers.

### 2. Website and documentation

- In `../platform/docs/16-branding.md`, replace the old About requirement with
  the branded website-only app presentation and the website's responsibility
  for attribution, license, and corresponding-source information. Preserve the
  requirement to publish the modified mobile source when shipping the app.
- Keep `../site/open-source.html`, license download, existing footer navigation,
  source/revision links, clean URLs, and historical version records working.
- Add a focused website regression assertion only if missing: the served root
  document has a visible, actionable `/open-source` link. Validate rendered HTML
  elements/text, not a matching string in a comment or script.
- Check the served source page's attribution and license/source links using
  existing tests. Reuse existing coverage rather than duplicating it.
- Keep the existing release instructions for version/build/source mappings and
  clear source directions next to app downloads/store listings. Record a missing
  actual release mapping as a release prerequisite; do not generate a fake row.

No website redesign, redirect changes, backend service, authentication change,
source archive pipeline, or release-workflow restructuring is needed.

## TDD slices

### Slice 1 — About content and actual link destination

Edit the existing widget tests in `test/branding/about_attribution_test.dart`.
It may be renamed to `about_numberinbox_test.dart` if that improves clarity;
update any explicit test-path consumers if renamed.

RED:

- Require the title, NumberInbox name, approved tagline, and existing mark asset.
- Require exactly one actionable `numberinbox.com` link.
- Require no rendered Twake/LINAGORA, AGPL, open-source, warranty, GitHub, or
  `/open-source` content. Inspect rendered `Text`/`SelectableText` content rather
  than scanning application source files.
- Use the existing mocked URL-launcher channel. Tap the domain label and assert
  exactly one launch of the literal `https://numberinbox.com`. Use the literal
  expected URL in the assertion so an incorrect config constant cannot make the
  test pass. The exact comparison also rejects query strings/user data.
- Confirm the tests fail against the old screen for the expected content and
  destination differences, not because of a mock or test setup error.

GREEN: implement the small widget/config change and rerun these tests.

### Slice 2 — Small screen, text scaling, and accessibility

- At 320 × 480 logical pixels with 200% text, confirm no layout exceptions and
  that the website link can be scrolled into view and tapped.
- Apply `MediaQuery` scaling inside `MaterialApp.builder` (or another verified
  location below MaterialApp's own MediaQuery) so the test really uses 200% text.
  Assert the effective `TextScaler` to avoid a false large-text pass.
- Test both LTR and RTL layouts with the same screen content; do not introduce
  translations as part of the test.
- Confirm the link exposes an actionable semantics node with the domain as its
  accessible name. Preserve standard button focus/tap behavior; avoid brittle
  snapshots of Flutter's complete semantics tree.

Use a failing regression test before making any layout adjustment actually
needed. Do not add speculative layout fixes when the simplified screen passes.

### Slice 3 — Website route to notices and license preservation

Use `../site/scripts/test_routes.py` and the existing brand checker:

- Require the root GET response to contain a visible link to `/open-source`.
  If existing coverage lacks this assertion, add it and demonstrate it fails
  when that link is removed/commented out in an isolated temporary fixture.
- Preserve existing GET/HEAD checks for `/open-source`, the `.html` alias,
  license download, source links, and privacy/deletion routes.
- Preserve the check that the full license download matches mobile `LICENSE`.
- Keep any already-passing website behavior intact; do not force a production
  change solely to manufacture a RED phase.

## Commands and manual verification

From `mobile-app`:

```bash
# Only when dependency/localization preparation is necessary:
./scripts/prebuild.sh

flutter test test/branding/about_attribution_test.dart
flutter analyze
```

Use the renamed path if the test was renamed. Compare analysis output with the
baseline and report any existing failures accurately. Run the repository's
normal CI test checks on the final commit. Do not substitute `flutter pub get`
for prebuild.

From `../site`:

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/check_brand.py --require-sources
```

Before committing platform changes, follow its AGENTS.md, including Java 25
`./mvnw -B -ntp verify` from `apps/api` and applicable checks. Do not silently
waive repository checks because the change is documentation-only.

Manually inspect Android and an iOS simulator at normal/large text sizes. Open
Settings → About, activate the domain link, confirm the public homepage loads,
then navigate from its visible footer to notices, full license, and source
without logging in. Inspect actual content, not HTTP status alone. Confirm
existing Settings/back navigation still works.

## Rollout and acceptance

1. Verify the live homepage visibly exposes its working notices page before
   distributing the changed app. Publish needed website changes first through
   the existing deployment process.
2. Update the branding specification and implement/test the mobile screen.
3. Verify license/source access and real release records before distribution;
   retain access for earlier distributed builds.
4. Obtain green required CI for touched repositories. If an implementation MR
   is opened/updated, follow the user's requirement for a standalone `/review`
   note. Commit/push or release only when separately authorized.

Acceptance: the About screen shows only NumberInbox branding and one domain
link, opening the exact HTTPS homepage; the website and distribution pages
retain clear notice/license/source access; no license, copyright, source,
navigation, or unrelated application behavior is removed.

## Execution record — October 26, 2026

Implemented locally:

- About widget now keeps its existing branding and a single homepage action.
- `AppConfig.websiteUrl` replaces the unused source-page constant.
- Widget tests cover branding/content, the literal HTTPS destination, actual
  200% text scaling in both text directions, and actionable button semantics.
- Platform branding documentation reflects the approved app/site split.
- Website routing tests parse actual footer anchors and demonstrate rejection
  of a commented-out notices link in a temporary fixture. Production website
  pages and license content were not changed.

Verification:

- RED: all five updated widget tests fail against the original widget/config;
  the failure output includes the original `/open-source` destination and old
  semantics label. The implementation was restored after that baseline run.
- GREEN: all five About widget tests pass in the final branding run.
- Focused `flutter analyze --no-pub` for the three changed Dart files: clean.
- Full analysis baseline reports 62 informational issues elsewhere.
- Full branding tests: 75 passed, one opt-in capture test skipped, one failure
  in `startup_timing_test.dart`. That failure detects the fixed two-second delay
  in the pre-existing, separately modified `home_controller.dart`; this task
  did not change that file.
- Website routing tests: all 10 pass. Full website tests: 14 pass, one existing
  failure. The brand checker identifies that failure as the mobile welcome view
  missing the secondary tagline; the same failure was captured before edits.
- Website AGPL download remains byte-identical to mobile `LICENSE`.
- Whitespace/diff checks pass for the changed files.

Outstanding verification/release gates:

- Live homepage, notices, and license requests all returned HTTP 403 from this
  environment. Public content access remains unverified; this is not evidence
  that the production site is broken for ordinary browsers.
- Flutter device discovery lists only macOS and Chrome, and no iOS simulator is
  booted. Android/iOS visual and external-browser checks remain pending.
- Version/build/source entries still need validation from actual distributed
  builds; no release record was fabricated.
- Required remote CI has not been dispatched. No commit, push, deployment, or
  store submission was performed. Follow the pre-commit/CI rules above before
  those steps, including platform verification before committing its changes.
