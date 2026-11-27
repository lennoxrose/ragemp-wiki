import { useEffect } from 'react';
import { Box, useApp } from 'ink';
import type { CliArgs } from './config/args';
import { useNow } from './hooks/useNow';
import { useRun } from './hooks/useRun';
import { CurrentPanel } from './ui/CurrentPanel';
import { Header } from './ui/Header';
import { ProgressPanel } from './ui/ProgressPanel';
import { RecentPanel } from './ui/RecentPanel';
import { StatsPanel } from './ui/StatsPanel';
import { Summary, Warnings } from './ui/Summary';

export function App({ args }: { args: CliArgs }) {
  const state = useRun(args);
  const now = useNow();
  const { exit } = useApp();
  const over = state.phase === 'finished' || state.phase === 'failed';

  useEffect(() => {
    if (!over) return;
    process.exitCode = state.phase === 'failed' ? 1 : 0;
    const id = setTimeout(exit, 150); // let the final frame render first
    return () => clearTimeout(id);
  }, [over, state.phase, exit]);

  return (
    <Box flexDirection="column" gap={1} paddingX={1}>
      <Header state={state} mode={args.mode} />
      <ProgressPanel state={state} />
      <StatsPanel state={state} now={now} />
      {over ? null : <CurrentPanel state={state} now={now} />}
      <RecentPanel state={state} />
      <Warnings state={state} />
      {over ? <Summary state={state} out={args.out} /> : null}
    </Box>
  );
}
