'use strict';
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { buildInvocation } = require('../lib/cli.cjs');
if (process.platform !== 'win32') throw new Error('The launcher tests require Windows.');
const invocation = buildInvocation({ command: 'check', drive: 'Z:\\' });
const result = spawnSync(invocation.executable,
  ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.resolve(__dirname, '../tests/Test-Launcher.ps1')],
  { env: invocation.options.env, stdio: 'inherit', shell: false, windowsHide: true });
if (result.error) {
  process.stderr.write(result.error.message + '\n');
  process.exitCode = 1;
} else {
  process.exitCode = Number.isInteger(result.status) ? result.status : 1;
}
