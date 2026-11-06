# Twake Mail

 ## Build

 To update Flutter packages, run `./scripts/prebuild.sh` instead of `flutter pub get`.

 ## Fork policy

 This repository is a fork of the upstream Twake Mail mobile app. Keep the same
 features and behavior as upstream unless a divergence is explicitly requested
 and recorded in the release plan or an ADR. Do not add or remove product
 features (for example, at-rest encryption of mail caches) merely because a
 review suggests them; propose such changes upstream instead.

### Scope of fork changes

- Limit fork-owned changes to NumberInbox branding, explicitly approved
  NumberInbox features, and fixes necessary for those customizations. Record
  intentional behavioral differences in a release plan or ADR.
- Preserve inherited features, behavior, architecture, and public interfaces
  outside that scope. An audit recommendation alone does not authorize changing
  upstream behavior. Report unrelated upstream issues separately.
- Before fixing a suspected defect, establish whether it originates upstream or
  in the fork. Check the relevant history and upstream implementation; distinguish
  an upstream change we have not yet incorporated from a fork regression.
- Upstream synchronization and adoption of upstream fixes are separate, explicitly
  authorized work. Preserve approved NumberInbox behavior during those updates.

### Minimize upstream merge conflicts

- Make the smallest focused change that satisfies the approved requirement.
  Prefer NumberInbox-specific files, assets, shared brand constants, and existing
  extension points over changes spread throughout inherited code.
- When a shared upstream component must change, keep the patch narrow. Prefer an
  optional parameter or existing customization mechanism that preserves upstream
  defaults for other callers. Do not add an abstraction merely to avoid a small,
  necessary patch.
- Retain upstream file names, directory structure, interfaces, and formatting
  where practical. Avoid unrelated renames, file moves, formatting churn,
  dependency upgrades, generated-file churn, and broad refactors.
- Reuse upstream components and workflows rather than copying or replacing them.
  Do not introduce parallel implementations when existing extension points meet
  the requirement.
- Keep branding and feature changes separate from upstream fixes or sync work in
  reviewable diffs and, when commits are authorized, focused commits. Document
  unavoidable shared-code changes and the requirement that justifies them.
- Add focused regression coverage for NumberInbox behavior and preserve inherited
  assertions. Run the affected upstream tests when shared code changes; do not
  weaken or skip them to accommodate a customization.

## Security review

For a security review, follow `docs/security/local-review.md`: run `bash scripts/security-review.sh <area>` and answer the generated `.security-review/prompt-<area>.md`.
