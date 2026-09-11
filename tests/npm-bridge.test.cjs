'use strict';
// These subprocess tests replace drive operations with disposable fixture
// modules. They exercise the real adapter's routing and exit codes, not SSD I/O.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const { spawnSync } = require('node:child_process');
const { buildInvocation } = require('../lib/cli.cjs');

function fixture() {
  const base = path.resolve(__dirname, '../test-results');
  fs.mkdirSync(base, { recursive: true });
  const root = fs.mkdtempSync(path.join(base, 'bridge-'));
  const drive = path.join(root, 'SSD fixture & spaces');
  const directory = path.join(drive, 'T5-Launcher');
  fs.mkdirSync(directory, { recursive: true });
  fs.mkdirSync(path.join(root, 'T5-Launcher'));
  fs.mkdirSync(path.join(root, 'npm'));
  fs.copyFileSync(path.resolve(__dirname, '../npm/Invoke-Npm.ps1'), path.join(root, 'npm/Invoke-Npm.ps1'));
  fs.writeFileSync(path.join(root, 'T5-Launcher/T5Launcher.psm1'), `
function Assert-T5PlainPath { param($Path) }
function Get-T5DeviceConfig { param($Directory); Get-Content -LiteralPath (Join-Path $Directory 'device.json') -Raw | ConvertFrom-Json }
function Test-T5Root { param($Root,$Config); return [bool]$Config.valid }
function Assert-T5DeviceConfig { param($Config); if ($Config.modelRelativePath -match '\\.\\.') { throw 'Invalid model path' } }
function Get-T5CachePlan { param($Root,$Config) }
Export-ModuleMember -Function *-T5*
`);
  fs.writeFileSync(path.join(root, 'npm/NpmInstaller.psm1'), `
function Assert-NpmDrive { param($Root); if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw 'Missing fixture drive' }; '0123ABCD' }
function Get-NpmPayloadPlan { param($PackageRoot,$Destination); $Destination }
function Copy-NpmPayload { param($Plan); [IO.File]::WriteAllText((Join-Path $Plan[0] 'copied.txt'), 'copied') }
function Assert-NpmRuntime { param($PackageRoot,$Drive) }
Export-ModuleMember -Function Assert-NpmDrive,Get-NpmPayloadPlan,Copy-NpmPayload,Assert-NpmRuntime
`);
  fs.writeFileSync(path.join(directory, 'T5Launcher.ps1'), `param([string]$Mode)
[pscustomobject]@{mode=$Mode;requestCleared=($null -eq $env:PORTABLE_AI_REQUEST)} | ConvertTo-Json
exit ([int]$env:PORTABLE_AI_FIXTURE_EXIT)
`);
  fs.writeFileSync(path.join(directory, 'Create-Desktop-Shortcut.ps1'), `Write-Output 'fixture shortcut'
exit ([int]$env:PORTABLE_AI_FIXTURE_EXIT)
`);
  function run(request, exitCode = 0) {
    const invocation = buildInvocation(request, { ...process.env, PORTABLE_AI_FIXTURE_EXIT: String(exitCode) }, root);
    return spawnSync(invocation.executable, invocation.args, { ...invocation.options, stdio: 'pipe', encoding: 'utf8', timeout: 10000 });
  }
  return { root, drive, directory, run };
}

for (const [command, mode] of [['check', 'Check'], ['launch', 'Launch'], ['popup-install', 'Install'], ['popup-remove', 'Uninstall']]) {
  test(`real bridge dispatches ${command} and preserves script failure`, { skip: process.platform !== 'win32', timeout: 15000 }, () => {
    const f = fixture(); const result = f.run({ command, drive: f.drive }, 7);
    assert.equal(result.status, 7, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { mode, requestCleared: true });
  });
}
test('real bridge preserves shortcut failure', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); const result = f.run({ command: 'shortcut', drive: f.drive }, 9);
  assert.equal(result.status, 9, result.stderr); assert.match(result.stdout, /fixture shortcut/);
});
test('setup with existing pairing reuses it without invoking configuration', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); const marker = path.join(f.directory, 'device.json');
  fs.writeFileSync(marker, '{"valid":true,"keep":"pairing"}');
  const result = f.run({ command: 'setup', drive: f.drive });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Existing pairing kept/);
  assert.equal(fs.readFileSync(marker, 'utf8'), '{"valid":true,"keep":"pairing"}');
  assert.ok(fs.existsSync(path.join(f.drive, 'copied.txt')));
});
test('setup refuses configuration changes on a paired drive before copying', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); fs.writeFileSync(path.join(f.directory, 'device.json'), '{"valid":true}');
  const result = f.run({ command: 'setup', drive: f.drive, displayName: 'new name' });
  assert.equal(result.status, 1); assert.match(result.stderr, /already paired/);
  assert.ok(!fs.existsSync(path.join(f.drive, 'copied.txt')));
});
test('setup refuses an invalid existing pairing before copying', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); fs.writeFileSync(path.join(f.directory, 'device.json'), '{"valid":false}');
  const result = f.run({ command: 'setup', drive: f.drive });
  assert.equal(result.status, 1); assert.match(result.stderr, /existing pairing does not match/);
  assert.ok(!fs.existsSync(path.join(f.drive, 'copied.txt')));
});
test('setup validates the model path before copying', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); const result = f.run({ command: 'setup', drive: f.drive, modelPath: '..\\hub' });
  assert.equal(result.status, 1); assert.match(result.stderr, /Invalid model path/);
  assert.ok(!fs.existsSync(path.join(f.drive, 'copied.txt')));
});
test('unattended unpaired setup fails before copying', { skip: process.platform !== 'win32', timeout: 15000 }, () => {
  const f = fixture(); const result = f.run({ command: 'setup', drive: f.drive });
  assert.equal(result.status, 1); assert.match(result.stderr, /interactive terminal/);
  assert.ok(!fs.existsSync(path.join(f.drive, 'copied.txt')));
});
