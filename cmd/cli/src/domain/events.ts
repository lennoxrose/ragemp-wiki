/** Events emitted by the Go core with `wikisync -json` (one JSON object per line). */
export type Phase = 'listing' | 'syncing' | 'indexing';

export type WikiEvent =
  | { t: 'phase'; ts: number; name: Phase }
  | { t: 'listing'; ts: number; count: number }
  | { t: 'plan'; ts: number; total: number; changed: number; removed: number }
  | { t: 'batch'; ts: number; index: number; size: number; titles: string[] }
  | { t: 'page'; ts: number; title: string; path: string }
  | { t: 'progress'; ts: number; done: number; total: number }
  | { t: 'warn'; ts: number; msg: string }
  | { t: 'done'; ts: number; failed: number }
  | { t: 'error'; ts: number; msg: string };

/** The process ended (synthesised by the runner, not emitted by Go). */
export interface ExitEvent {
  t: 'exit';
  ts: number;
  code: number | null;
}

export type Action = WikiEvent | ExitEvent;

const KNOWN = new Set(['phase', 'listing', 'plan', 'batch', 'page', 'progress', 'warn', 'done', 'error']);

export function parseEvent(line: string): WikiEvent | undefined {
  try {
    const value = JSON.parse(line) as WikiEvent;
    return KNOWN.has(value.t) ? value : undefined;
  } catch {
    return undefined;
  }
}
