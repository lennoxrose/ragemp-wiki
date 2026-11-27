import { spawn } from 'node:child_process';
import type { CliArgs } from '../config/args';
import { goBinary, repoRoot } from '../config/paths';
import { parseEvent, type Action } from '../domain/events';

export interface RunHandle {
  stop(): void;
}

function goArgs(a: CliArgs): string[] {
  const out = ['-json', '-mode', a.mode, '-out', a.out];
  if (a.full) out.push('-full');
  if (a.limit) out.push('-limit', String(a.limit));
  if (a.batch) out.push('-batch', String(a.batch));
  return out;
}

/** Starts the Go core and forwards its NDJSON stdout as typed actions. */
export function startRun(args: CliArgs, emit: (action: Action) => void): RunHandle {
  const child = spawn(goBinary, goArgs(args), { cwd: repoRoot });
  let buffer = '';
  child.stdout.on('data', (chunk: Buffer) => {
    buffer += chunk.toString('utf8');
    const lines = buffer.split('\n');
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      const event = parseEvent(line);
      if (event) emit(event);
    }
  });
  child.stderr.on('data', (chunk: Buffer) => {
    emit({ t: 'warn', ts: Date.now(), msg: chunk.toString('utf8').trim() });
  });
  child.on('error', (err) => emit({ t: 'error', ts: Date.now(), msg: `cannot start ${goBinary}: ${err.message}` }));
  child.on('close', (code) => emit({ t: 'exit', ts: Date.now(), code }));
  return { stop: () => child.kill() };
}
