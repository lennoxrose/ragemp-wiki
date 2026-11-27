import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';
import type { RunState } from '../domain/state';
import { theme } from './color';
import { clip, formatDuration } from './format';

const SHOWN = 6;

/** What the Go core is working on right now. */
export function CurrentPanel({ state, now }: { state: RunState; now: number }) {
  const batch = state.current;
  if (!batch) {
    return state.phase === 'syncing'
      ? <Text color={theme.dim}>waiting for the next batch…</Text>
      : null;
  }
  const hidden = batch.titles.length - SHOWN;
  return (
    <Box flexDirection="column">
      <Text>
        <Text color={theme.brand}><Spinner type="dots" /></Text>
        {' '}Processing batch <Text bold>#{batch.index + 1}</Text> · {batch.size} pages ·{' '}
        <Text color={theme.warn}>{formatDuration(now - batch.startedAt)}</Text>
      </Text>
      {batch.titles.slice(0, SHOWN).map((title) => (
        <Text key={title} color={theme.dim}>  · {clip(title, 70)}</Text>
      ))}
      {hidden > 0 ? <Text color={theme.dim}>  … and {hidden} more</Text> : null}
    </Box>
  );
}
