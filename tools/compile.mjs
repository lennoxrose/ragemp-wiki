#!/usr/bin/env node
// Builds every exe and DLL into bin/. Needs Go, gcc (for the DLLs) and pnpm (for the CLI).
// Usage: node tools/compile.mjs [--skip-cli]
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const bin = path.join(root, 'bin');
mkdirSync(bin, { recursive: true });

const run = (cmd, args, opts = {}) => {
  console.log(`> ${cmd} ${args.join(' ')}`);
  execFileSync(cmd, args, { cwd: root, stdio: 'inherit', shell: process.platform === 'win32' && cmd === 'pnpm', ...opts });
};

const exes = { 'wikisync.exe': './cmd/wikisync', 'wikisync-chromium.exe': './cmd/chromium', 'wikisync-remote.exe': './cmd/wikisync-remote' };
for (const [out, pkg] of Object.entries(exes)) run('go', ['build', '-o', `bin/${out}`, pkg]);

const dlls = { 'wikisync-chromium.dll': './cmd/chromiumdll', 'wikisync-useragent.dll': './cmd/useragentdll' };
for (const [out, pkg] of Object.entries(dlls)) {
  run('go', ['build', '-buildmode=c-shared', '-o', `bin/${out}`, pkg], { env: { ...process.env, CGO_ENABLED: '1' } });
  rmSync(path.join(bin, out.replace(/\.dll$/, '.h')), { force: true }); // c-shared emits an unused header
}

if (!process.argv.includes('--skip-cli')) run('pnpm', ['run', 'build:exe'], { cwd: path.join(root, 'cmd/cli') });
console.log('done');
