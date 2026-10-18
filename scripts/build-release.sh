#!/usr/bin/env sh

# No `set -x`: tracing would echo the expanded Fastlane arguments, including
# the full DART_DEFINES value and signing material, into the workflow log.
# Guarded by scripts/tests/workflow-policy.test.mjs.
set -eu

bundle exec fastlane release
