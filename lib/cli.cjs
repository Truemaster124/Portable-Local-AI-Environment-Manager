'use strict';

const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { version } = require('../package.json');

const commands = ['setup', 'check', 'launch', 'shortcut', 'popup-install', 'popup-remove'];
const help = `Portable Local AI ${version}

Usage: portable-ai <command> --drive E:

Commands:
  setup          Copy the launcher to the SSD and interactively pair it
  check          Print the existing read-only setup report as JSON
  launch         Open Unsloth after the existing confirmation and checks
  shortcut       Create the optional desktop shortcut
  popup-install  Enable the optional connection popup for this account
  popup-remove   Disable the optional connection popup for this account

Options:
  --drive <root>       Required SSD drive letter: E:, E:\\, or E:/
  --model-path <path>  Setup only: relative Hub cache folder
  --name <name>        Setup only: a display name of up to 80 characters
  -h, --help          Show help
  -v, --version       Show version

Examples:
  portable-ai setup --drive E:
  portable-ai setup --drive E: --name "My AI SSD" --model-path "AI\\Models\\huggingface\\hub"
  portable-ai check --drive E:
  portable-ai launch --drive E:

Requires Windows, Node.js 22+, Windows PowerShell 5.1, and a prepared
Unsloth Desktop installation. Setup asks you to type PAIR before pairing.
No models, runtime, startup helper, or shortcut are installed by npm install.
See docs/npm.md for installation, updates, and troubleshooting.
`;

function parseArgs(args) {
  if (args.length === 0 || (args.length === 1 && ['help', '-h', '--help'].includes(args[0]))) {
    return { command: 'help' };
  }
  if (args.length === 1 && ['-v', '--version'].includes(args[0])) return { command: 'version' };
  const [command, ...options] = args;
  if (!commands.includes(command)) throw new Error(`Unknown command: ${command}. Run portable-ai --help.`);
  if (options.length === 1 && ['-h', '--help'].includes(options[0])) return { command: 'help' };
  const request = { command };
  const names = { '--drive': 'drive', '--model-path': 'modelPath', '--name': 'displayName' };
  for (let i = 0; i < options.length; i += 2) {
    const flag = options[i];
    const key = Object.hasOwn(names, flag) ? names[flag] : null;
    if (!key) throw new Error(`Unknown option: ${flag}. Run portable-ai --help.`);
    if (Object.hasOwn(request, key)) throw new Error(`Option ${flag} was supplied more than once.`);
    const value = options[i + 1];
    if (!value || value.startsWith('--')) throw new Error(`Option ${flag} needs a value.`);
    if (/[\x00-\x1f]/u.test(value)) throw new Error(`Option ${flag} must be a single line without control characters.`);
    request[key] = value;
  }
  if (!request.drive || !/^[a-z]:[\\/]?$/iu.test(request.drive)) {
    throw new Error('Specify the SSD root with --drive E:. Folders and network paths are not supported.');
  }
  request.drive = request.drive[0].toUpperCase() + ':\\';
  if (command !== 'setup' && (request.modelPath !== undefined || request.displayName !== undefined)) {
    throw new Error('--model-path and --name can only be used with setup.');
  }
  if (request.displayName !== undefined && (!request.displayName.trim() || request.displayName.length > 80)) {
    throw new Error('Use a nonempty display name of up to 80 characters.');
  }
  return request;
}

// Pass user values as JSON data, never as PowerShell source or shell arguments.
function buildInvocation(request, env = process.env, packageRoot = path.resolve(__dirname, '..')) {
  const systemRoot = env.SystemRoot || env.SYSTEMROOT;
  if (!systemRoot || !path.win32.isAbsolute(systemRoot) || !/^[a-z]:\\/iu.test(systemRoot)) {
    throw new Error('Cannot locate Windows PowerShell: SystemRoot is missing or invalid.');
  }
  const childEnv = { ...env };
  for (const key of Object.keys(childEnv)) {
    // npm may run inside PowerShell 7. Its module search path can hide the
    // Windows PowerShell 5.1 built-ins (including Get-FileHash).
    if (['PORTABLE_AI_REQUEST', 'PSMODULEPATH'].includes(key.toUpperCase())) delete childEnv[key];
  }
  childEnv.PORTABLE_AI_REQUEST = JSON.stringify(request);
  return {
    executable: path.win32.join(systemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
    args: ['-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File',
      path.join(packageRoot, 'npm', 'Invoke-Npm.ps1')],
    options: { env: childEnv, stdio: 'inherit', shell: false, windowsHide: true },
  };
}

function main(args, context = {}) {
  const stdout = context.stdout || process.stdout;
  const stderr = context.stderr || process.stderr;
  try {
    const request = parseArgs(args);
    if (request.command === 'help') { stdout.write(help); return 0; }
    if (request.command === 'version') { stdout.write(version + '\n'); return 0; }
    if ((context.platform || process.platform) !== 'win32') {
      throw new Error('This release supports Windows only. Ubuntu, macOS, and iOS are not supported.');
    }
    const nodeVersion = context.nodeVersion || process.versions.node;
    if (Number(nodeVersion.split('.')[0]) < 22) throw new Error('Node.js 22 or newer is required.');
    const env = context.env || process.env;
    const invocation = buildInvocation(request, env);
    const result = (context.spawnSync || spawnSync)(invocation.executable, invocation.args, invocation.options);
    if (result.error) {
      if (result.error.code === 'ENOENT') throw new Error('Windows PowerShell 5.1 was not found. Restore it before running portable-ai.');
      throw new Error(`Could not start Windows PowerShell: ${result.error.message}`);
    }
    if (result.signal) {
      stderr.write(`portable-ai: Interrupted (${result.signal}).\n`);
      return result.signal === 'SIGINT' ? 130 : 1;
    }
    return Number.isInteger(result.status) ? result.status : 1;
  } catch (error) {
    stderr.write(`portable-ai: ${error.message}\n`);
    return 1;
  }
}

module.exports = { parseArgs, buildInvocation, main };
