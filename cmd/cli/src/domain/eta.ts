import type { RunState } from './state';

/** Pages per second since the sync phase started (rate-limit pauses included). */
export function pagesPerSecond(s: RunState, now: number): number {
  if (!s.syncStartedAt || s.done === 0) return 0;
  const elapsed = ((s.finishedAt ?? now) - s.syncStartedAt) / 1000;
  return elapsed > 0 ? s.done / elapsed : 0;
}

/** Estimated milliseconds until the sync phase completes, if it can be told yet. */
export function etaMs(s: RunState, now: number): number | undefined {
  const rate = pagesPerSecond(s, now);
  if (rate === 0 || s.changed === 0) return undefined;
  return ((s.changed - s.done) / rate) * 1000;
}
