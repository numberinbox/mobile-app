#!/usr/bin/env bash
# fail if any commands fails
set -e
echo "Prebuild started..."

# Single pub get resolves the entire workspace (Dart pub workspaces).
#
# Retried: the workspace has git-hosted dependencies, so a transient DNS or
# TLS failure on the runner surfaces as pub's EX_UNAVAILABLE (exit 69) and
# fails the whole job. Three attempts with a short backoff turn a five-minute
# outage into a passing run, and a genuinely broken dependency still fails.
retry() {
  local attempts=3 delay=5 attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if (( attempt >= attempts )); then
      printf 'prebuild: gave up after %d attempts: %s\n' "$attempts" "$*" >&2
      return 1
    fi
    printf 'prebuild: attempt %d/%d failed (%s), retrying in %ss\n' \
      "$attempt" "$attempts" "$*" "$delay" >&2
    sleep "$delay"
    attempt=$(( attempt + 1 ))
    delay=$(( delay * 2 ))
  done
}

retry flutter pub get > /dev/null
echo "[workspace] pub get done."

# Pinned browser libs for web/index.html (web/js/vendor, gitignored)
sh "$(dirname "$0")/fetch-web-vendor.sh"
echo "[web/vendor] done."

# Run build_runner across all workspace members in a single invocation
dart run build_runner build --workspace > /dev/null
echo "[workspace] build_runner done."

# Root module: intl localization generation
dart run intl_generator:extract_to_arb --output-dir=./lib/l10n lib/main/localizations/app_localizations.dart
dart run intl_generator:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/main/localizations/app_localizations.dart lib/l10n/intl*.arb
echo "[root] Done."

# Scribe module: intl localization generation
echo "[scribe/l10n] Starting..."
(
   cd scribe
   dart run intl_generator:extract_to_arb --output-dir=./lib/scribe/ai/l10n lib/scribe/ai/localizations/scribe_localizations.dart
   dart run intl_generator:generate_from_arb --output-dir=lib/scribe/ai/l10n --no-use-deferred-loading lib/scribe/ai/localizations/scribe_localizations.dart lib/scribe/ai/l10n/intl*.arb
)
echo "[scribe/l10n] Done."

echo "Prebuild finished."
