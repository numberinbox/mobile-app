import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync, existsSync } from 'node:fs';
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

// NOTE: the "no mobile tag-triggered store upload" rule is intentionally NOT
// asserted here. `.github/workflows/release.yaml` still carries its `v*.*.*`
// tag trigger and is only switched off in the final rollout phase, once the
// private workflow is proven. Adding the assertion before that switch-off
// would turn CI red, which the CI discipline forbids. Move the release.yaml
// deletion and this assertion into the same commit.