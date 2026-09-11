'use strict';
// Installs only into a disposable prefix under test-results; never publishes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { buildInvocation } = require('../lib/cli.cjs');
const pkg = require('../package.json');
const root = path.resolve(__dirname, '..');
if (process.platform !== 'win32') throw new Error('Run this Windows installation smoke test on Windows.');
const npmCli = process.env.npm_execpath;
if (!npmCli || !fs.existsSync(npmCli)) throw new Error('Run this script using npm run test:package.');
fs.mkdirSync(path.join(root, 'test-results'), { recursive: true });
const fixture = fs.mkdtempSync(path.join(root, 'test-results', 'package-'));
const prefix = path.join(fixture, 'global install with spaces');
const env = buildInvocation({ command: 'check', drive: 'Z:\\' }).options.env;
const common = ['--offline', '--no-audit', '--no-fund', '--cache', path.join(fixture, 'cache')];
function run(executable, args, options = {}) {
  const result = spawnSync(executable, args, { cwd: root, encoding: 'utf8', env, windowsHide: true, timeout: 60000, ...options });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, result.stdout + result.stderr);
  return result.stdout;
}
function npm(args) { return run(process.execPath, [npmCli, ...common, ...args]); }
const [packed] = JSON.parse(npm(['pack', '--json', '--ignore-scripts', '--pack-destination', fixture]));
const names = new Set(packed.files.map(file => file.path));
const required = ['package.json', 'README.md', 'LICENSE', ...pkg.files.filter(name => !name.includes('*'))];
for (const name of required) assert.ok(names.has(name), `Missing published file: ${name}`);
for (const name of names) {
  const allowed = required.includes(name) || /^docs\/[^/]+\.md$/u.test(name);
  assert.ok(allowed, `Unexpected published file: ${name}`);
  assert.ok(!/(^|\/)(device\.json|\.env|token|stored_tokens|installed\.json|node_modules|test-results|tests)(\/|$)/u.test(name), `Private/test file leaked: ${name}`);
}
const tarball = path.join(fixture, packed.filename);
assert.ok(fs.statSync(tarball).size < 150000, 'Package should stay lightweight (no model weights or marketing images).');
npm(['install', '--global', '--prefix', prefix, tarball]);
const shim = path.join(prefix, 'portable-ai.cmd');
assert.ok(fs.existsSync(shim), 'npm must generate the Windows command shim');
assert.ok(fs.existsSync(path.join(prefix, 'portable-ai.ps1')), 'npm must generate the PowerShell shim');
const powershell = buildInvocation({ command: 'check', drive: 'Z:\\' }).executable;
const shimEnv = { ...env, PORTABLE_AI_TEST_SHIM: shim };
const version = run(powershell, ['-NoProfile', '-Command', '& $env:PORTABLE_AI_TEST_SHIM --version; exit $LASTEXITCODE'], { env: shimEnv, cwd: fixture });
assert.equal(version.trim(), pkg.version);
const help = run(powershell, ['-NoProfile', '-Command', '& $env:PORTABLE_AI_TEST_SHIM --help; exit $LASTEXITCODE'], { env: shimEnv, cwd: fixture });
assert.match(help, /Usage: portable-ai/);
const installed = path.join(prefix, 'node_modules', pkg.name);
const { buildInvocation: installedInvocation } = require(path.join(installed, 'lib/cli.cjs'));
const payload = installedInvocation({ command: 'check', drive: process.env.SystemRoot.slice(0, 2) + '\\' });
const report = spawnSync(payload.executable, payload.args, { ...payload.options, stdio: 'pipe', encoding: 'utf8', timeout: 15000 });
assert.equal(report.status, 1, report.stdout + report.stderr);
assert.equal(JSON.parse(report.stdout.replace(/^\uFEFF/u, '')).readyToLaunch, false);
const npxResult = npm(['exec', '--yes', '--package', tarball, '--', 'portable-ai', '--version']);
assert.ok(npxResult.trim().endsWith(pkg.version), npxResult);
npm(['uninstall', '--global', '--prefix', prefix, pkg.name]);
assert.ok(!fs.existsSync(shim), 'Uninstall should remove only the disposable command shim');
assert.ok(!fs.existsSync(installed), 'Uninstall should remove the disposable package');
// npm's generated CMD shim has an unquoted SET dp0 assignment. Its PowerShell
// shim is the compatible route for an installation path containing ampersands.
const specialPrefix = path.join(fixture, 'global install & punctuation');
npm(['install', '--global', '--prefix', specialPrefix, tarball]);
const psVersion = run(powershell, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(specialPrefix, 'portable-ai.ps1'), '--version']);
assert.equal(psVersion.trim(), pkg.version);
npm(['uninstall', '--global', '--prefix', specialPrefix, pkg.name]);
console.log(`Package smoke test passed: ${packed.entryCount} files, ${packed.size} bytes; pack, private-file exclusion, global install, CMD shim, help, backend, npm exec, and uninstall.`);
console.log(`Disposable test artifacts: ${fixture}`);
