import type { Action, Phase } from './events';

export interface BatchInfo {
  index: number;
  size: number;
  titles: string[];
  startedAt: number;
  durationMs?: number;
}

export interface PageInfo {
  title: string;
  category: string;
}

export interface RunState {
  phase: 'starting' | Phase | 'finished' | 'failed';
  startedAt: number;
  syncStartedAt?: number;
  finishedAt?: number;
  listed: number;
  total: number;
  changed: number;
  removed: number;
  done: number;
  written: number;
  failed: number;
  current?: BatchInfo;
  batches: BatchInfo[]; // most recent completed batches
  pages: PageInfo[]; // most recent written pages
  warnings: string[];
  error?: string;
}

export const initialState = (now: number): RunState => ({
  phase: 'starting', startedAt: now, listed: 0, total: 0, changed: 0, removed: 0,
  done: 0, written: 0, failed: 0, batches: [], pages: [], warnings: [],
});

const keep = <T>(list: T[], item: T, n: number) => [...list.slice(-(n - 1)), item];

export function reduce(s: RunState, a: Action): RunState {
  switch (a.t) {
    case 'phase':
      return { ...s, phase: a.name, syncStartedAt: a.name === 'syncing' ? a.ts : s.syncStartedAt };
    case 'listing':
      return { ...s, listed: a.count };
    case 'plan':
      return { ...s, total: a.total, changed: a.changed, removed: a.removed };
    case 'batch':
      return { ...s, current: { index: a.index, size: a.size, titles: a.titles, startedAt: a.ts } };
    case 'page':
      return { ...s, written: s.written + 1, pages: keep(s.pages, { title: a.title, category: a.path.split('/')[0] }, 10) };
    case 'progress': {
      const finished = s.current && { ...s.current, durationMs: a.ts - s.current.startedAt };
      return { ...s, done: a.done, current: undefined, batches: finished ? keep(s.batches, finished, 5) : s.batches };
    }
    case 'warn':
      return { ...s, warnings: keep(s.warnings, a.msg, 4) };
    case 'done':
      return { ...s, phase: 'finished', finishedAt: a.ts, failed: a.failed, current: undefined };
    case 'error':
      return { ...s, phase: 'failed', finishedAt: a.ts, error: a.msg, current: undefined };
    case 'exit':
      if (s.phase === 'finished' || s.phase === 'failed') return s;
      return { ...s, phase: 'failed', finishedAt: a.ts, error: `process exited with code ${a.code}` };
  }
}
