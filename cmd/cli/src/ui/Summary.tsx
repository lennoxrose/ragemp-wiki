import { Box, Text } from 'ink';
import { pagesPerSecond } from '../domain/eta';
import type { RunState } from '../domain/state';
import { theme } from './color';
import { formatDuration, formatRate } from './format';

/** Shown once the run is over, plus any warnings collected on the way. */
export function Summary({ state, out }: { state: RunState; out: string }) {
  const failed = state.phase === 'failed';
  return (
    <Box flexDirection="column" borderStyle="round" borderColor={failed ? theme.bad : theme.ok} paddingX={1}>
      <Text bold color={failed ? theme.bad : theme.ok}>{failed ? '✖ Run failed' : '✔ Run complete'}</Text>
      {state.error ? <Text color={theme.bad}>{state.error}</Text> : null}
      <Text>Total time: <Text bold>{formatDuration((state.finishedAt ?? 0) - state.startedAt)}</Text></Text>
      <Text>Pages written: <Text bold>{state.written}</Text> · removed: {state.removed} · failed batches: {state.failed}</Text>
      <Text>Average speed: {formatRate(pagesPerSecond(state, state.finishedAt ?? 0))}</Text>
      {failed ? null : <Text color={theme.dim}>Output: {out}/index.md</Text>}
    </Box>
  );
}

export function Warnings({ state }: { state: RunState }) {
  if (state.warnings.length === 0) return null;
  return (
    <Box flexDirection="column">
      {state.warnings.map((w, i) => <Text key={i} color={theme.warn}>! {w}</Text>)}
    </Box>
  );
}
