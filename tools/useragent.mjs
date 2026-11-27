// Builds the User-Agent a normal, non-headless Chrome of the same version would send.
import { readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname } from 'node:path';

const PLATFORM = {
  win32: 'Windows NT 10.0; Win64; x64',
  darwin: 'Macintosh; Intel Mac OS X 10_15_7',
  linux: 'X11; Linux x86_64',
};

function majorVersion(exe) {
  try {
    // Windows installs keep a "157.0.8103.79" folder next to chrome.exe.
    const dir = readdirSync(dirname(exe)).find((d) => /^\d+\.\d+\.\d+\.\d+$/.test(d));
    if (dir) return dir.split('.')[0];
  } catch {}
  try {
    const out = execFileSync(exe, ['--version'], { encoding: 'utf8', timeout: 5000 });
    return out.match(/(\d+)\.\d+\.\d+\.\d+/)?.[1];
  } catch {}
  return undefined;
}

export function normalUserAgent(exe) {
  const major = majorVersion(exe);
  if (!major) return undefined;
  const os = PLATFORM[process.platform] ?? PLATFORM.linux;
  return `Mozilla/5.0 (${os}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${major}.0.0.0 Safari/537.36`;
}
