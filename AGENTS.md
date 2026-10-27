# Twake Mail

 ## Build

 To update Flutter packages, run `./scripts/prebuild.sh` instead of `flutter pub get`.

 ## Fork policy

 This repository is a fork of the upstream Twake Mail mobile app. Keep the same
 features and behavior as upstream unless a divergence is explicitly requested
 and recorded in the release plan or an ADR. Do not add or remove product
 features (for example, at-rest encryption of mail caches) merely because a
 review suggests them; propose such changes upstream instead.

## Security review

For a security review, follow `docs/security/local-review.md`: run `bash scripts/security-review.sh <area>` and answer the generated `.security-review/prompt-<area>.md`.
