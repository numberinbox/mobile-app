import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const checker = resolve('scripts/check-integration-test-drift.sh');
function fixture(run) {
  const dir = mkdtempSync(join(tmpdir(), 'integration-parity-'));
  const git = (...args) => {
    const r = spawnSync('git', ['-c', 'core.fsmonitor=false', ...args], { cwd: dir, encoding: 'utf8' });
    assert.equal(r.status, 0, r.stderr);
    return r.stdout.trim();
  };
  const write = (path, text) => writeFileSync(join(dir, path), text);
  const commit = () => { git('add', '.'); git('commit', '-qm', 'synthetic fixture'); };
  try {
    git('init', '-q'); git('config', 'user.name', 'Parity Test'); git('config', 'user.email', 'parity@example.test');
    mkdirSync(join(dir, 'integration_test'));
    write('integration_test/allowed.dart', 'upstream\n');
    write('integration_test/same.dart', 'unchanged\n');
    write('integration_test/removed.dart', 'upstream\n');
    commit();
    const base = git('rev-parse', 'HEAD');
    write('integration_test/UPSTREAM_BASE', `${base}\n`);
    write('integration_test/FORK_ALLOWLIST', '# synthetic reason\nintegration_test/allowed.dart\n# bookkeeping\nintegration_test/UPSTREAM_BASE\nintegration_test/FORK_ALLOWLIST\nintegration_test/FORK.md\n');
    write('integration_test/FORK.md', 'fixture\n');
    write('integration_test/allowed.dart', 'fork\n');
    commit();
    const check = (...args) => spawnSync('bash', [checker, ...args], { cwd: dir, encoding: 'utf8' });
    run({ dir, git, write, commit, check });
  } finally { rmSync(dir, { recursive: true, force: true }); }
}

test('accepts only explicitly allowlisted committed differences', () => fixture(({ check }) => {
  const r = check(); assert.equal(r.status, 0, r.stderr);
}));
test('rejects added, modified and deleted inherited files without printing contents', () => {
  for (const kind of ['add', 'modify', 'delete']) fixture(({ dir, write, commit, check }) => {
    const path = kind === 'add' ? 'integration_test/new.dart' : kind === 'delete' ? 'integration_test/removed.dart' : 'integration_test/same.dart';
    if (kind === 'delete') rmSync(join(dir, path)); else write(path, 'SENTINEL-not-for-logs\n');
    commit(); const r = check(); assert.notEqual(r.status, 0);
    assert.match(r.stdout + r.stderr, new RegExp(path.replaceAll('.', '\\.')));
    assert.doesNotMatch(r.stdout + r.stderr, /SENTINEL-not-for-logs/);
  });
});
test('rejects stale entries but exempts bookkeeping', () => fixture(({ write, commit, check }) => {
  write('integration_test/FORK_ALLOWLIST', 'integration_test/allowed.dart\nintegration_test/same.dart\n'); commit();
  const r = check(); assert.notEqual(r.status, 0); assert.match(r.stdout + r.stderr, /integration_test\/same\.dart/);
}));
test('worktree mode detects uncommitted and untracked drift', () => fixture(({ write, check }) => {
  write('integration_test/same.dart', 'SENTINEL-uncommitted\n');
  write('integration_test/new.dart', 'SENTINEL-untracked\n');
  const r = check('--worktree'); assert.notEqual(r.status, 0);
  assert.match(r.stdout + r.stderr, /integration_test\/same\.dart/);
  assert.match(r.stdout + r.stderr, /integration_test\/new\.dart/);
  assert.doesNotMatch(r.stdout + r.stderr, /SENTINEL/);
}));
test('rejects malformed bases and unsafe or duplicate allowlist entries', () => {
  for (const value of ['../escape', 'integration_test/../escape', 'integration_test/allowed.dart\nintegration_test/allowed.dart']) fixture(({ write, check }) => {
    write('integration_test/FORK_ALLOWLIST', `${value}\n`);
    assert.notEqual(check().status, 0);
  });
  fixture(({ write, check }) => { write('integration_test/UPSTREAM_BASE', '--bad-option\n'); assert.notEqual(check().status, 0); });
});

test('missing base fetch uses the public URL without a configured remote and fails closed', () => fixture(({ dir, write }) => {
  write('integration_test/UPSTREAM_BASE', `${'f'.repeat(40)}\n`);
  const bin = join(dir, 'bin'); mkdirSync(bin);
  const trace = join(dir, 'fetch-trace');
  const realGit = spawnSync('sh', ['-c', 'command -v git'], { encoding: 'utf8' }).stdout.trim();
  writeFileSync(join(bin, 'git'), `#!/bin/sh
case " $* " in
  *" fetch "*) printf '%s\\n' "$*" > "$DRIFT_FETCH_TRACE"; exit 1 ;;
esac
exec "$DRIFT_REAL_GIT" "$@"
`, { mode: 0o755 });
  const r = spawnSync('bash', [checker], { cwd: dir, encoding: 'utf8', env: {
    ...process.env, PATH: `${bin}:${process.env.PATH}`, DRIFT_REAL_GIT: realGit, DRIFT_FETCH_TRACE: trace,
  } });
  assert.notEqual(r.status, 0);
  assert.match(r.stdout + r.stderr, /integration_test\/UPSTREAM_BASE/);
  const args = spawnSync('cat', [trace], { encoding: 'utf8' }).stdout;
  assert.match(args, /fetch --no-tags --depth=1 https:\/\/github\.com\/linagora\/tmail-flutter\.git f{40}/);
}));
