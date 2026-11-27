import { Box, Text } from 'ink';
import { etaMs, pagesPerSecond } from '../domain/eta';
import type { RunState } from '../domain/state';
import { theme } from './color';
import { formatDuration, formatRate } from './format';

function Stat({ label, value, color }: { label: string; value: string; color?: string }) {
  return (
    <Box width={30}>
      <Text color={theme.dim}>{label.padEnd(12)}</Text>
      <Text bold color={color}>{value}</Text>
    </Box>
  );
}

export function StatsPanel({ state, now }: { state: RunState; now: number }) {
  const elapsed = (state.finishedAt ?? now) - state.startedAt;
  const finished = state.phase === 'finished' || state.phase === 'failed';
  const eta = finished ? undefined : etaMs(state, now);
  return (
    <Box flexDirection="column">
      <Box>
        <Stat label="Elapsed" value={formatDuration(elapsed)} />
        <Stat label="Remaining" value={finished ? '--' : formatDuration(eta)} color={theme.brand} />
      </Box>
      <Box>
        <Stat label="Speed" value={formatRate(pagesPerSecond(state, now))} />
        <Stat label="Written" value={String(state.written)} color={theme.ok} />
      </Box>
      <Box>
        <Stat label="Removed" value={String(state.removed)} />
        <Stat label="Failed" value={String(state.failed)} color={state.failed > 0 ? theme.bad : undefined} />
      </Box>
    </Box>
  );
}
