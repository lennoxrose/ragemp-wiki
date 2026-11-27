import { Box, Text } from 'ink';
import type { RunState } from '../domain/state';
import { categoryColor, theme } from './color';
import { clip, formatDuration } from './format';

/** What was just finished: the latest pages and how long each batch took. */
export function RecentPanel({ state }: { state: RunState }) {
  if (state.pages.length === 0 && state.batches.length === 0) return null;
  return (
    <Box flexDirection="column" gap={1}>
      <Box flexDirection="column">
        <Text bold>Just processed</Text>
        {state.pages.slice(-6).map((p, i) => (
          <Text key={`${p.title}-${i}`}>
            <Text color={theme.ok}>✔</Text> {clip(p.title, 44).padEnd(44)}{' '}
            <Text color={categoryColor(p.category)}>{p.category}</Text>
          </Text>
        ))}
      </Box>
      <Box flexDirection="column">
        <Text bold>Recent batches</Text>
        {state.batches.map((b) => (
          <Text key={b.index} color={theme.dim}>
            #{String(b.index + 1).padEnd(4)} {String(b.size).padStart(3)} pages in{' '}
            <Text color={theme.warn}>{formatDuration(b.durationMs)}</Text>
          </Text>
        ))}
      </Box>
    </Box>
  );
}
