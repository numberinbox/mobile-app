import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Guards on what the PUBLIC repository is allowed to contain. The Android
// integration run and every store upload move to the private platform repo
// (platform/docs/private-mobile-ci-release-plan.md); what stays here is app
// code, ordinary Flutter tests, and the web/James gate.
//
// These checks are static on purpose: they must run in the fast `node --test`
// job without an Android SDK or a Gradle build.

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

function repoPath(...segments) {
  return join(repoRoot, ...segments);
}

function readRepoFile(...segments) {
  return readFileSync(repoPath(...segments), 'utf8');
}

// ── Removed public Android integration job ────────────────────────────────

test('the public Android Patrol workflow and its bore tunnel script are gone', () => {
  assert.equal(
    existsSync(repoPath('.github', 'workflows', 'patrol-integration-test.yaml')),
    false,
    'patrol-integration-test.yaml must not come back: it cannot reach a backend '
      + 'without a public tunnel, and the real run lives in the private repo.',
  );
  assert.equal(
    existsSync(repoPath('scripts', 'patrol-integration-test-with-docker.sh')),
    false,
    'patrol-integration-test-with-docker.sh must not come back: it tunnels the '
      + 'backend through bore.pub.',
  );
});

test('no tracked script or workflow opens a public tunnel to a backend', () => {
  // `bore` reached bore.pub from the public runner. No replacement tunnel may
  // creep in: the private smoke job talks to host loopback only.
  const tunnelPattern = /\bbore(\.pub)?\b|ngrok\b|localtunnel\b|lt\s+--port\b|cloudflared\s+tunnel\b/;

  for (const file of ['patrol-web-integration-test-with-docker.sh',
    'patrol-web-local-integration-test-with-docker.sh',
    'patrol-local-integration-test-with-docker.sh']) {
    const path = repoPath('scripts', file);
    if (!existsSync(path)) continue;
    assert.equal(
      tunnelPattern.test(readFileSync(path, 'utf8')),
      false,
      `${file} must not reference a public tunnel service.`,
    );
  }
});

// ── Release cleartext must not leak out of debug ──────────────────────────

test('the cleartext network policy is debug-only', () => {
  const mainConfig = repoPath('android', 'app', 'src', 'main', 'res', 'xml', 'network_security_config.xml');
  assert.equal(
    existsSync(mainConfig),
    false,
    'network_security_config.xml must not live under src/main: it permits '
      + 'cleartext to the emulator host and would ship in the release APK.',
  );

  const debugConfig = repoPath('android', 'app', 'src', 'debug', 'res', 'xml', 'network_security_config.xml');
  assert.equal(
    existsSync(debugConfig),
    true,
    'the debug copy must exist, or Android tests cannot reach 10.0.2.2.',
  );

  const mainManifest = readRepoFile('android', 'app', 'src', 'main', 'AndroidManifest.xml');
  assert.equal(
    /android:networkSecurityConfig/.test(mainManifest),
    false,
    'src/main/AndroidManifest.xml must not reference a network security '
      + 'config; the attribute belongs on the debug manifest only.',
  );

  const debugManifest = readRepoFile('android', 'app', 'src', 'debug', 'AndroidManifest.xml');
  assert.match(
    debugManifest,
    /android:networkSecurityConfig="@xml\/network_security_config"/,
    'the debug manifest must reference the debug network security config.',
  );
});

test('the debug network policy permits cleartext only to local emulator hosts', () => {
  const config = readRepoFile('android', 'app', 'src', 'debug', 'res', 'xml', 'network_security_config.xml');
  const domains = [...config.matchAll(/<domain[^>]*>([^<]+)<\/domain>/g)].map((m) => m[1].trim());
  const allowed = new Set(['10.0.2.2', 'localhost', '127.0.0.1']);

  for (const domain of domains) {
    assert.ok(
      allowed.has(domain),
      `cleartext must stay local, but the debug config allows ${domain}`,
    );
  }
});

// ── Release script hygiene ────────────────────────────────────────────────

test('the release script does not trace its commands', () => {
  const script = readRepoFile('scripts', 'build-release.sh');
  assert.equal(
    /^set\s+-[a-z]*x/m.test(script),
    false,
    'set -x echoes expanded secrets and full DART_DEFINES into the log.',
  );
});

test('the release script does not print the full DART_DEFINES value', () => {
  const script = readRepoFile('scripts', 'build-release.sh');
  assert.equal(
    /echo[^#\n]*\$\{?DART_DEFINES/.test(script),
    false,
    'echoing DART_DEFINES prints every signing/app define in one line.',
  );
});

// NOTE: the "no mobile tag-triggered store upload" rule is enforced below.
// `.github/workflows/release.yaml` carried a `v*.*.*` tag trigger until the
// private workflow replaced it; the Fastlane lanes stay in this repository for
// the private CI to invoke, but nothing here may upload to a store on a tag
// push. Keep the trigger removal and this assertion in the same commit.

// ── No tag-triggered store upload in the public repository ────────────────

test('no public workflow uploads to a store on a tag push', () => {
  // A tag push is the one event an outside contributor cannot be trusted to
  // control in a public repository. Releases now go through the private
  // workflow, which requires human approval on a protected environment.
  const workflowDir = repoPath('.github', 'workflows');
  const storeMarkers = /upload_to_play_store|upload_to_testflight|build-release\.sh|fastlane release/i;

  const offenders = readdirSync(workflowDir)
    .filter((name) => /\.ya?ml$/.test(name))
    .filter((name) => {
      const text = readFileSync(join(workflowDir, name), 'utf8');
      return storeMarkers.test(text) && /^[ \t]*tags:[ \t]*$/m.test(text);
    });

  assert.deepEqual(
    offenders,
    [],
    `these workflows still upload to a store on a tag push: ${offenders.join(', ')}`,
  );
});

test('the release lanes stay available for private CI to invoke', () => {
  // Disabling the trigger must not remove the Fastfile lanes the private
  // workflow calls; they are the build path, not the trigger.
  for (const platform of ['android', 'ios']) {
    assert.ok(
      existsSync(repoPath(platform, 'fastlane', 'Fastfile')),
      `${platform}/fastlane/Fastfile must remain`,
    );
  }
  assert.ok(
    existsSync(repoPath('scripts', 'build-release.sh')),
    'build-release.sh must remain as the build entry point',
  );
});
// The inherited HTML jobs test local transforms and do not require Firebase.
test('HTML display jobs do not restore removed Firebase secret setup', () => {
  const workflow = readRepoFile('.github', 'workflows', 'html-display.yaml');
  assert.equal(workflow.includes('./scripts/setup-firebase.sh'), false);
  assert.equal(workflow.includes('secrets.FIREBASE_ENV'), false);
  assert.match(workflow, /run: \.\/scripts\/prebuild\.sh/);
});
