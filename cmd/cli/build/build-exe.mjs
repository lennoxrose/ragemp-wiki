// Builds bin/wikisync-cli.exe: the CLI bundled into one file and embedded in a
// copy of node.exe (Node single-executable application).
//   1. esbuild -> one ESM bundle (Ink needs top-level await, so it stays ESM)
//   2. a CJS stub inside the exe unpacks the bundle and imports it at start
//   3. node --experimental-sea-config -> blob, postject -> injected into node.exe
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';
import { rcedit } from 'rcedit';

const here = path.dirname(fileURLToPath(import.meta.url));
const cli = path.resolve(here, '..');
const out = path.resolve(cli, '../../bin', process.platform === 'win32' ? 'wikisync-cli.exe' : 'wikisync-cli');
const tmp = path.join(here, 'tmp');
mkdirSync(tmp, { recursive: true });

await build({
  entryPoints: [path.join(cli, 'src/index.tsx')],
  outfile: path.join(tmp, 'app.mjs'),
  bundle: true,
  platform: 'node',
  format: 'esm',
  target: 'node24',
  alias: { 'react-devtools-core': path.join(here, 'devtools-stub.mjs') },
  define: { 'process.env.NODE_ENV': '"production"' },
  banner: { js: "import { createRequire as __cr } from 'node:module'; const require = __cr(import.meta.url);" },
});

writeFileSync(path.join(tmp, 'stub.cjs'), `
const sea = require('node:sea');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'wikisync-'));
const file = path.join(dir, 'app.mjs');
fs.writeFileSync(file, Buffer.from(sea.getAsset('app.mjs')));
process.on('exit', () => fs.rmSync(dir, { recursive: true, force: true }));
import(pathToFileURL(file).href);
`);

const config = path.join(tmp, 'sea-config.json');
writeFileSync(config, JSON.stringify({
  main: path.join(tmp, 'stub.cjs'),
  output: path.join(tmp, 'sea.blob'),
  disableExperimentalSEAWarning: true,
  assets: { 'app.mjs': path.join(tmp, 'app.mjs') },
}));
execFileSync(process.execPath, ['--experimental-sea-config', config], { stdio: 'inherit' });

copyFileSync(process.execPath, out);
if (process.platform === 'win32') {
  // Set the icon before injecting the blob; editing resources afterwards can corrupt it.
  await rcedit(out, { icon: path.resolve(cli, '../../ragemp.ico') });
}
const postject = path.join(cli, 'node_modules/postject/dist/cli.js');
execFileSync(process.execPath, [postject, out, 'NODE_SEA_BLOB', path.join(tmp, 'sea.blob'),
  '--sentinel-fuse', 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2'], { stdio: 'inherit' });
console.log(`built ${out}`);
