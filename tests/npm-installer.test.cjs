'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { buildInvocation } = require('../lib/cli.cjs');

test('PowerShell installer regression checks', { skip: process.platform !== 'win32', timeout: 60000 }, () => {
  const result = spawnSync(path.join(process.env.SystemRoot, 'System32/WindowsPowerShell/v1.0/powershell.exe'),
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(__dirname, 'Test-NpmInstaller.ps1')],
    { encoding: 'utf8', windowsHide: true, timeout: 50000,
      env: buildInvocation({ command: 'check', drive: 'Z:\\' }).options.env });
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /npm installer checks passed/);
  process.stdout.write(result.stdout);
});

test('real CLI refuses the system drive and check still returns JSON', { skip: process.platform !== 'win32', timeout: 20000 }, () => {
  const result = spawnSync(process.execPath, [path.join(__dirname, '../bin/portable-ai.cjs'), 'check', '--drive', process.env.SystemRoot.slice(0, 2)],
    { encoding: 'utf8', windowsHide: true, timeout: 15000 });
  assert.equal(result.status, 1, result.stdout + result.stderr);
  const report = JSON.parse(result.stdout.replace(/^\uFEFF/u, ''));
  assert.equal(report.readyToLaunch, false);
  assert.match(report.problems.join(' '), /system volume/);
});
