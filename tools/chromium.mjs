#!/usr/bin/env node
// Starts Chromium with a remote debugging port, detached so the terminal can be closed.
// Usage: node tools/chromium.mjs [--port 9222] [--url <url>] [--show]
// By default it runs headless: no window, no taskbar entry, pure background process.
// --show opens a normal window (only needed to solve a Cloudflare challenge by hand).
// Override the browser with the CHROMIUM_PATH env var.
import { spawn } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalUserAgent } from './useragent.mjs';

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? def : args[i + 1];
};
const port = Number(opt('port', 9222));
const url = opt('url', 'https://wiki.rage.mp/wiki/Main_Page');
const show = args.includes('--show');
const profile = join(dirname(fileURLToPath(import.meta.url)), '.profile');

const local = process.env.LOCALAPPDATA ?? '';
const pf = process.env.ProgramFiles ?? '';
const candidates = [
  process.env.CHROMIUM_PATH,
  join(local, 'Chromium/Application/chrome.exe'),
  join(local, 'Google/Chrome/Application/chrome.exe'),
  join(pf, 'Google/Chrome/Application/chrome.exe'),
  join(pf, 'Microsoft/Edge/Application/msedge.exe'),
  '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  join(homedir(), '.local/bin/chromium'),
].filter(Boolean);

const probe = async () => {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/json/version`);
    return res.ok ? await res.json() : null;
  } catch {
    return null;
  }
};

const running = await probe();
if (running) {
  console.log(`Already running on port ${port}: ${running.Browser}`);
  process.exit(0);
}

const exe = candidates.find((p) => existsSync(p));
if (!exe) {
  console.error('No Chromium-based browser found. Set CHROMIUM_PATH.');
  process.exit(1);
}

mkdirSync(profile, { recursive: true });
const flags = [
  `--remote-debugging-port=${port}`,
  '--remote-allow-origins=*',
  `--user-data-dir=${profile}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--lang=en-US',
  '--disable-features=Translate,TranslateUI,TranslateSubFrames',
  '--disable-renderer-backgrounding',
  '--disable-background-timer-throttling',
  '--disable-backgrounding-occluded-windows',
  '--disable-blink-features=AutomationControlled',
  ...(normalUserAgent(exe) ? [`--user-agent=${normalUserAgent(exe)}`] : []),
  ...(show ? [] : ['--headless=new', '--window-size=1280,800']),
  url,
];

const child = spawn(exe, flags, { detached: true, stdio: 'ignore', windowsHide: !show });
child.unref();

for (let i = 0; i < 120; i++) {
  await new Promise((r) => setTimeout(r, 500));
  const info = await probe();
  if (info) {
    console.log(`Ready: ${info.Browser}\nDebug endpoint: ${info.webSocketDebuggerUrl}`);
    process.exit(0);
  }
}
console.error(`Browser started (pid ${child.pid}) but port ${port} never opened.`);
process.exit(1);
