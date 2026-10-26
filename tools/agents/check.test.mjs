import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import { auditRepository } from './check.mjs';

function fixture(t) {
  const root = mkdtempSync(path.join(os.tmpdir(), 'runner-agent-guidance-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  execFileSync('git', ['init', '--quiet', root]);
  execFileSync('git', ['-C', root, 'config', 'core.autocrlf', 'false']);
  const write = (name, text) => {
    const target = path.join(root, name);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, text);
  };
  const append = (name, text) => write(name, readFileSync(path.join(root, name), 'utf8') + text);
  write('AGENTS.md', '# Root\n\n[Routing](.agent/README.md)\n');
  write('.agent/README.md', '# Routing\n\n[Root](../AGENTS.md)\n'
    + '[Contract](../docs/tdd/agent_orchestration.md)\n'
    + '[Workflow](workflows/change.md)\n');
  write('.agent/workflows/change.md', '---\ndescription: Change code\n---\n\n# Change\n');
  write('docs/tdd/agent_orchestration.md', '# Contract\n');
  return { root, write, append, audit: () => auditRepository(root) };
}

test('valid tracked and new guidance passes without changing repository files', (t) => {
  const f = fixture(t);
  execFileSync('git', ['-C', f.root, 'add', 'AGENTS.md']);
  const before = execFileSync('git', ['-C', f.root, 'status', '--porcelain']);
  assert.deepEqual(f.audit().errors, []);
  assert.deepEqual(execFileSync('git', ['-C', f.root, 'status', '--porcelain']), before);
});

test('new nested instructions and workflows must be indexed', (t) => {
  const f = fixture(t);
  f.write('lib/AGENTS.md', '# App\n');
  f.write('.agent/workflows/extra.md', '---\ndescription: Extra\n---\n# Extra\n');
  const errors = f.audit().errors;
  assert.ok(errors.some((error) => error.includes('missing index entry for lib/AGENTS.md')));
  assert.ok(errors.some((error) => error.includes('missing index entry for .agent/workflows/extra.md')));
});

test('deleted tracked guidance and renamed targets fail', (t) => {
  const f = fixture(t);
  execFileSync('git', ['-C', f.root, 'add', '.']);
  rmSync(path.join(f.root, '.agent/workflows/change.md'));
  assert.ok(f.audit().errors.some((error) => error.includes('cannot read referenced file')));
  f.write('.agent/workflows/changed.md', '---\ndescription: Changed\n---\n# Changed\n');
  assert.ok(f.audit().errors.some((error) => error.includes('missing index entry')));
});

test('broken source links fail even when the guidance itself is unchanged', (t) => {
  const f = fixture(t);
  f.write('lib/source.dart', 'void main() {}\n');
  f.append('AGENTS.md', '\n[Source](lib/source.dart)\n');
  execFileSync('git', ['-C', f.root, 'add', '.']);
  assert.deepEqual(f.audit().errors, []);
  rmSync(path.join(f.root, 'lib/source.dart'));
  assert.ok(f.audit().errors.some((error) => error.includes('missing link target: lib/source.dart')));
});

test('deleted directories cannot pass using only stale Git inventory', (t) => {
  const f = fixture(t);
  f.write('docs/removed/file.md', '# Example\n');
  f.append('AGENTS.md', '[Directory](docs/removed/)\n');
  execFileSync('git', ['-C', f.root, 'add', '.']);
  assert.deepEqual(f.audit().errors, []);
  rmSync(path.join(f.root, 'docs/removed'), { recursive: true });
  assert.ok(f.audit().errors.some((error) => error.includes('directory target')));
});

test('reference labels containing inline code still have their targets checked', (t) => {
  const f = fixture(t);
  f.append('AGENTS.md', '[`code.dart`](missing.dart)\n');
  assert.ok(f.audit().errors.some((error) => error.includes('missing link target: missing.dart')));
});

test('symlinked Markdown cannot make the checker read outside its repository', (t) => {
  const f = fixture(t);
  const external = fixture(t);
  external.write('secret.md', '# Private\n');
  const target = path.join(f.root, 'external.md');
  try { symlinkSync(path.join(external.root, 'secret.md'), target); } catch (error) {
    if (error.code === 'EPERM') return t.skip('Host does not allow unprivileged file symlinks');
    throw error;
  }
  f.append('AGENTS.md', '[Outside](external.md)\n');
  assert.ok(f.audit().errors.some((error) => error.includes('outside repository')));
});

test('required root, index, contract and root-to-index route are enforced', (t) => {
  const f = fixture(t);
  f.write('AGENTS.md', '# Root\n');
  assert.ok(f.audit().errors.some((error) => error.startsWith('AGENTS.md: must link')));
  for (const name of ['AGENTS.md', '.agent/README.md', 'docs/tdd/agent_orchestration.md']) {
    rmSync(path.join(f.root, name));
    assert.ok(f.audit().errors.some((error) => error === `${name}: required guidance is missing`));
  }
});

test('empty guidance and workflows without descriptions fail', (t) => {
  const f = fixture(t);
  f.write('.agent/workflows/change.md', '');
  const errors = f.audit().errors;
  assert.ok(errors.some((error) => error.includes('must not be empty')));
  assert.ok(errors.some((error) => error.includes('description front matter')));
});

test('instruction budgets count UTF-8 ancestors but not siblings or references', (t) => {
  const f = fixture(t);
  f.write('lib/AGENTS.md', 'é'.repeat(8000));
  f.write('lib/ui/AGENTS.md', 'x'.repeat(14000));
  f.write('tools/AGENTS.md', 'x'.repeat(14000));
  f.write('.agent/references/details.md', 'x'.repeat(50000));
  for (const name of ['lib/AGENTS.md', 'lib/ui/AGENTS.md', 'tools/AGENTS.md', '.agent/references/details.md']) {
    f.append('.agent/README.md', `[Details](../${name})\n`);
  }
  const result = f.audit();
  assert.equal(result.errors.length, 1);
  assert.match(result.errors[0], /^lib\/ui\/AGENTS.md: instruction chain/);
  assert.equal(result.chains[0].bytes,
    Buffer.byteLength(readFileSync(path.join(f.root, 'AGENTS.md'), 'utf8')) + 30004);
});

test('root budget prevents gradual always-loaded context growth', (t) => {
  const f = fixture(t);
  f.append('AGENTS.md', 'x'.repeat(10240));
  assert.ok(f.audit().errors.some((error) => error.includes('root budget')));
});

test('shadowing overrides cannot silently hide scoped instructions', (t) => {
  const f = fixture(t);
  f.write('AGENTS.override.md', '# Override\n');
  f.append('.agent/README.md', '[Override](../AGENTS.override.md)\n');
  assert.ok(f.audit().errors.some((error) => error.includes('shadows AGENTS.md')));
});

test('relative links support spaces, Unicode, references, directories and heading anchors', (t) => {
  const f = fixture(t);
  f.write('docs/é space.md', '# My heading\n\n## My heading\n\n## Code `value`\n');
  f.append('AGENTS.md', '\n[One](<docs/é space.md#my-heading>)\n'
    + '[Two](docs/%C3%A9%20space.md#my-heading-1 "title")\n'
    + '[Code](docs/%C3%A9%20space.md#code-value)\n'
    + '[Folder](docs/)\n[Reference][ref]\n[ref]: <docs/é space.md>\n');
  assert.deepEqual(f.audit().errors, []);
  f.append('AGENTS.md', '[Bad](docs/%C3%A9%20space.md#missing)\n');
  assert.ok(f.audit().errors.some((error) => error.includes('missing heading anchor')));
});

test('examples and external links are not fetched or treated as local paths', (t) => {
  const f = fixture(t);
  f.append('AGENTS.md', '\n````md\n[Example](missing.md)\n```\n[Still fenced](absent.md)\n````\n'
    + '~~~\n[Example](missing.md)\n~~~\n`[Inline](missing.md)`\n'
    + '[External](https://example.invalid/missing)\n[Mail](mailto:nobody@example.invalid)\n');
  assert.deepEqual(f.audit().errors, []);
});

test('invalid, absolute and escaping link paths fail', (t) => {
  const f = fixture(t);
  f.append('AGENTS.md', '\n[Escape](../outside.md)\n[Absolute](/tmp/a.md)\n'
    + '[Encoding](bad%ZZ.md)\n[Backslash](docs\\bad.md)\n');
  const errors = f.audit().errors;
  assert.equal(errors.length, 4);
  assert.ok(errors.some((error) => error.includes('leaves repository')));
  assert.ok(errors.some((error) => error.includes('invalid link encoding')));
});

test('ignored build/dependency trees are excluded from instruction discovery', (t) => {
  const f = fixture(t);
  f.write('.gitignore', 'node_modules/\nbuild/\n');
  f.write('node_modules/AGENTS.md', '[Missing](missing.md)\n');
  f.write('build/AGENTS.md', '[Missing](missing.md)\n');
  assert.deepEqual(f.audit().errors, []);
});

test('checker handles CRLF content and reports deterministic diagnostics', (t) => {
  const f = fixture(t);
  f.write('.agent/workflows/change.md', '---\r\ndescription: Change code\r\n---\r\n\r\n# Change\r\n');
  assert.deepEqual(f.audit().errors, []);
  f.append('AGENTS.md', '[B](b.md)\n[A](a.md)\n[B](b.md)\n');
  assert.deepEqual(f.audit().errors, [
    'AGENTS.md: missing link target: a.md', 'AGENTS.md: missing link target: b.md',
  ]);
});

test('CLI resolves its checkout from its own path and fails on invalid arguments', (t) => {
  const f = fixture(t);
  const implementation = fileURLToPath(new URL('./check.mjs', import.meta.url));
  f.write('tools/agents/check.mjs', readFileSync(implementation, 'utf8'));
  const script = path.join(f.root, 'tools/agents/check.mjs');
  const success = spawnSync(process.execPath, [script], { cwd: os.tmpdir(), encoding: 'utf8' });
  assert.equal(success.status, 0, success.stderr);
  assert.match(success.stdout, /Agent guidance OK/);
  const usage = spawnSync(process.execPath, [script, '--unknown'], { encoding: 'utf8' });
  assert.equal(usage.status, 1);
  assert.match(usage.stderr, /Usage:/);
  f.append('AGENTS.md', '[Missing](missing.md)\n');
  const failure = spawnSync(process.execPath, [script], { encoding: 'utf8' });
  assert.equal(failure.status, 1);
  assert.match(failure.stderr, /missing link target/);
});

test('instruction discovery works in a linked Git worktree', (t) => {
  const f = fixture(t);
  execFileSync('git', ['-C', f.root, 'add', '.']);
  execFileSync('git', ['-C', f.root, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
    '-c', 'commit.gpgsign=false', 'commit', '--quiet', '-m', 'fixture']);
  const worktree = path.join(f.root, 'linked');
  execFileSync('git', ['-C', f.root, 'worktree', 'add', '--quiet', '--detach', worktree]);
  assert.deepEqual(auditRepository(worktree).errors, []);
});
