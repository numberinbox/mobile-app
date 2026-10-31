#!/usr/bin/env bash
# CI compares committed trees. --worktree also checks pending local edits/new files.
set -euo pipefail
mode=HEAD
if [ "${1:-}" = --worktree ] && [ "$#" -eq 1 ]; then
  mode=worktree
elif [ "$#" -ne 0 ]; then
  echo 'usage: check-integration-test-drift.sh [--worktree]' >&2; exit 2
fi
cd "$(git -c core.fsmonitor=false rev-parse --show-toplevel)"
base_file=integration_test/UPSTREAM_BASE
allow_file=integration_test/FORK_ALLOWLIST
[ -f "$base_file" ] && [ -f "$allow_file" ] || { printf '%s\n' "$base_file" "$allow_file" >&2; exit 1; }
base=$(cat "$base_file")
[[ "$base" =~ ^[0-9a-f]{40}$ ]] || { echo "$base_file" >&2; exit 1; }
if ! git -c core.fsmonitor=false cat-file -e "${base}^{commit}" 2>/dev/null; then
  git -c core.fsmonitor=false fetch --no-tags --depth=1 \
    https://github.com/linagora/tmail-flutter.git "$base" >/dev/null 2>&1 \
    || { echo "$base_file" >&2; exit 1; }
fi
git -c core.fsmonitor=false cat-file -e "${base}^{commit}" 2>/dev/null || { echo "$base_file" >&2; exit 1; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/integration-drift.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/allow"
while IFS= read -r path || [ -n "$path" ]; do
  case "$path" in ''|\#*) continue ;; esac
  if ! [[ "$path" =~ ^integration_test/[a-zA-Z0-9_./-]+$ ]] \
      || [[ "$path" == */../* || "$path" == */./* || "$path" == */.. || "$path" == */. ]] \
      || grep -Fxq -- "$path" "$tmp/allow"; then
    echo "$allow_file" >&2; exit 1
  fi
  printf '%s\n' "$path" >> "$tmp/allow"
done < "$allow_file"
if [ "$mode" = HEAD ]; then
  git -c core.fsmonitor=false diff --no-renames --name-only --diff-filter=ACDMRT "$base" HEAD -- integration_test/ > "$tmp/changed"
else
  git -c core.fsmonitor=false diff --no-renames --name-only --diff-filter=ACDMRT "$base" -- integration_test/ > "$tmp/changed"
  git -c core.fsmonitor=false ls-files --others --exclude-standard -- integration_test/ >> "$tmp/changed"
fi
failed=0
while IFS= read -r path; do
  if ! grep -Fxq -- "$path" "$tmp/allow"; then
    printf 'unapproved: %s\n' "$path" >&2; failed=1
  fi
done < "$tmp/changed"
while IFS= read -r path; do
  case "$path" in integration_test/UPSTREAM_BASE|integration_test/FORK_ALLOWLIST|integration_test/FORK.md) continue ;; esac
  if ! grep -Fxq -- "$path" "$tmp/changed"; then
    printf 'stale: %s\n' "$path" >&2; failed=1
  fi
done < "$tmp/allow"
exit "$failed"
