import { useEffect, useState } from 'react';

/** Current time, refreshed on an interval so durations tick live. */
export function useNow(intervalMs = 200): number {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}
