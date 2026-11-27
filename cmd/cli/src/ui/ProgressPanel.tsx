import { Box, Text } from 'ink';
import type { RunState } from '../domain/state';
import { theme } from './color';
import { percent } from './format';

const WIDTH = 40;

function Bar({ ratio }: { ratio: number }) {
  const filled = Math.round(Math.min(1, ratio) * WIDTH);
  return (
    <Text>
      <Text color={theme.ok}>{'█'.repeat(filled)}</Text>
      <Text color={theme.dim}>{'░'.repeat(WIDTH - filled)}</Text>
    </Text>
  );
}

export function ProgressPanel({ state }: { state: RunState }) {
  if (state.phase === 'starting' || state.phase === 'listing') {
    return <Text>Pages listed: <Text bold>{state.listed}</Text></Text>;
  }
  if (state.changed === 0) {
    return <Text color={theme.ok}>Everything is up to date ({state.total} pages, {state.removed} removed).</Text>;
  }
  const ratio = state.done / state.changed;
  return (
    <Box gap={1}>
      <Bar ratio={ratio} />
      <Text bold>{percent(state.done, state.changed)}%</Text>
      <Text color={theme.dim}>{state.done}/{state.changed} pages</Text>
    </Box>
  );
}
