'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const { parseArgs, buildInvocation, main } = require('../lib/cli.cjs');
const { version } = require('../package.json');

function context(overrides = {}) {
  const output = { out: '', err: '', calls: [] };
  return { output, platform: 'win32', nodeVersion: '22.0.0', env: { SystemRoot: 'C:\\Windows' },
    stdout: { write: s => { output.out += s; } }, stderr: { write: s => { output.err += s; } },
    spawnSync: (...args) => { output.calls.push(args); return { status: 0 }; }, ...overrides };
}

for (const args of [[], ['help'], ['--help'], ['-h'], ['setup', '--help']]) {
  test(`help has no side effects: ${JSON.stringify(args)}`, () => {
    const ctx = context({ platform: 'linux' });
    assert.equal(main(args, ctx), 0);
    assert.match(ctx.output.out, /Usage: portable-ai/);
    assert.equal(ctx.output.calls.length, 0);
  });
}
test('version works without PowerShell', () => {
  const ctx = context({ env: {} });
  assert.equal(main(['--version'], ctx), 0);
  assert.equal(ctx.output.out.trim(), version);
});
for (const drive of ['E:', 'e:\\', 'E:/']) {
  test(`normalizes drive ${drive}`, () => assert.deepEqual(parseArgs(['check', '--drive', drive]), { command: 'check', drive: 'E:\\' }));
}
for (const args of [
  ['launch'], ['bad'], ['check', '--drive'], ['check', '--drive', 'E:', '--force'],
  ['check', '--drive', 'E:', '--drive', 'F:'], ['setup', '--drive', 'E:', '--name', ''],
  ['setup', '--drive', 'E:', '--name', ' '.repeat(2)], ['setup', '--drive', 'E:', '--name', 'x'.repeat(81)],
  ['setup', '--drive', 'E:', '--name', 'a\nb'], ['launch', '--drive', 'E:', '--name', 'SSD'],
  ['launch', '--drive', 'E:', '--model-path', 'hub'], ['--help', 'junk'],
  ['setup', '--drive', 'E:', '--name', '--model-path'], ['setup', '--drive', 'E:', 'toString', 'bad'],
]) {
  test(`rejects invalid CLI input: ${JSON.stringify(args)}`, () => {
    const ctx = context(); assert.equal(main(args, ctx), 1); assert.ok(ctx.output.err); assert.equal(ctx.output.calls.length, 0);
  });
}
for (const drive of ['E', 'E:folder', 'E:\\folder', '..', '\\\\server\\share', 'E:\\..\\', '/tmp', 'E:\n', 'E:;whoami']) {
  test(`rejects unsafe drive ${JSON.stringify(drive)}`, () => assert.throws(() => parseArgs(['setup', '--drive', drive])));
}
for (const platform of ['linux', 'darwin', 'freebsd']) {
  test(`blocks operations on ${platform}`, () => {
    const ctx = context({ platform }); assert.equal(main(['launch', '--drive', 'E:'], ctx), 1);
    assert.match(ctx.output.err, /Windows only/); assert.equal(ctx.output.calls.length, 0);
  });
}
test('blocks old Node runtimes before launching', () => {
  const ctx = context({ nodeVersion: '20.20.0' }); assert.equal(main(['check', '--drive', 'E:'], ctx), 1);
  assert.match(ctx.output.err, /22 or newer/); assert.equal(ctx.output.calls.length, 0);
});
test('user punctuation and Unicode remain JSON data; shell never receives them', () => {
  const request = parseArgs(['setup', '--drive', 'E:', '--name', 'Garv & "AI"; $(echo hi) हिन्दी', '--model-path', 'AI & data\\hub']);
  const env = { SystemRoot: 'C:\\Windows', portable_ai_request: 'stale', PSModulePath: 'PowerShell 7 modules', KEEP: 'unchanged' };
  const call = buildInvocation(request, env, 'C:\\Package with spaces');
  assert.deepEqual(JSON.parse(call.options.env.PORTABLE_AI_REQUEST), request);
  assert.equal(call.options.env.portable_ai_request, undefined);
  assert.equal(env.portable_ai_request, 'stale');
  assert.equal(call.options.env.PSModulePath, undefined);
  assert.equal(env.PSModulePath, 'PowerShell 7 modules');
  assert.equal(call.options.env.KEEP, 'unchanged');
  assert.equal(call.options.shell, false); assert.equal(call.options.windowsHide, true);
  assert.equal(call.options.stdio, 'inherit');
  assert.ok(!call.args.join(' ').includes('echo hi'));
  assert.equal(call.executable, 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe');
});
test('missing SystemRoot reports an actionable error', () => {
  const ctx = context({ env: {} }); assert.equal(main(['check', '--drive', 'E:'], ctx), 1);
  assert.match(ctx.output.err, /SystemRoot/);
});
test('missing PowerShell reports an actionable error', () => {
  const ctx = context({ spawnSync: () => ({ error: Object.assign(new Error('missing'), { code: 'ENOENT' }) }) });
  assert.equal(main(['check', '--drive', 'E:'], ctx), 1); assert.match(ctx.output.err, /PowerShell 5.1 was not found/);
});
test('spawn failure does not masquerade as success', () => {
  const ctx = context({ spawnSync: () => ({ error: new Error('access denied') }) });
  assert.equal(main(['check', '--drive', 'E:'], ctx), 1); assert.match(ctx.output.err, /access denied/);
});
test('child failure code is preserved', () => {
  assert.equal(main(['check', '--drive', 'E:'], context({ spawnSync: () => ({ status: 7 }) })), 7);
});
test('interrupted child returns a failing exit code', () => {
  assert.equal(main(['check', '--drive', 'E:'], context({ spawnSync: () => ({ status: null, signal: 'SIGINT' }) })), 130);
});
test('missing child status is treated as failure', () => {
  assert.equal(main(['check', '--drive', 'E:'], context({ spawnSync: () => ({ status: null }) })), 1);
});
for (const command of ['setup', 'check', 'launch', 'shortcut', 'popup-install', 'popup-remove']) {
  test(`dispatches ${command} once with an explicit drive`, () => {
    const ctx = context(); assert.equal(main([command, '--drive', 'E:'], ctx), 0);
    assert.equal(ctx.output.calls.length, 1);
    assert.deepEqual(JSON.parse(ctx.output.calls[0][2].env.PORTABLE_AI_REQUEST), { command, drive: 'E:\\' });
  });
}
test('real executable starts from another working directory', () => {
  const result = spawnSync(process.execPath, [path.resolve(__dirname, '../bin/portable-ai.cjs'), '--version'], { cwd: path.parse(process.cwd()).root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr); assert.equal(result.stdout.trim(), version);
});
