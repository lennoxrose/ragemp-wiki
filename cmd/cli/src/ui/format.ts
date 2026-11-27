/** 3723000 -> "1h 02m 03s", 125000 -> "2m 05s", 3400 -> "3.4s". */
export function formatDuration(ms: number | undefined): string {
  if (ms === undefined || !Number.isFinite(ms) || ms < 0) return '--';
  const total = Math.round(ms / 100) / 10;
  if (total < 60) return `${total.toFixed(1)}s`;
  const s = Math.floor(total) % 60;
  const m = Math.floor(total / 60) % 60;
  const h = Math.floor(total / 3600);
  const two = (n: number) => String(n).padStart(2, '0');
  return h > 0 ? `${h}h ${two(m)}m ${two(s)}s` : `${m}m ${two(s)}s`;
}

export const formatRate = (perSecond: number): string =>
  perSecond > 0 ? `${perSecond.toFixed(1)} pages/s` : '--';

export const percent = (done: number, total: number): number =>
  total > 0 ? Math.min(100, Math.round((done / total) * 100)) : 0;

export const clip = (text: string, max: number): string =>
  text.length > max ? `${text.slice(0, max - 1)}…` : text;
