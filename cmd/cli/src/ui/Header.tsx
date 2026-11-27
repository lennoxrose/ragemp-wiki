import { Box, Text } from 'ink';
import Spinner from 'ink-spinner';
import type { Mode } from '../config/args';
import type { RunState } from '../domain/state';
import { theme } from './color';

const LABEL: Record<RunState['phase'], string> = {
  starting: 'Starting',
  listing: 'Listing pages',
  syncing: 'Downloading and converting',
  indexing: 'Writing indexes',
  finished: 'Finished',
  failed: 'Failed',
};

export function Header({ state, mode }: { state: RunState; mode: Mode }) {
  const active = state.phase !== 'finished' && state.phase !== 'failed';
  return (
    <Box gap={1}>
      <Text bold color={theme.brand}>RAGE MP Wiki Sync</Text>
      <Text color="cyan">[{mode === 'vault' ? 'Obsidian vault' : 'compile'}]</Text>
      {active ? <Text color={theme.ok}><Spinner type="dots" /></Text> : null}
      <Text color={state.phase === 'failed' ? theme.bad : state.phase === 'finished' ? theme.ok : undefined}>
        {LABEL[state.phase]}
      </Text>
    </Box>
  );
}
