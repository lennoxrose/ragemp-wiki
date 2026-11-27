import { render } from 'ink';
import { App } from './app';
import { HELP, parseCliArgs } from './config/args';

try {
  const args = parseCliArgs(process.argv.slice(2));
  if (args === 'help') {
    console.log(HELP);
  } else {
    render(<App args={args} />);
  }
} catch (err) {
  console.error(err instanceof Error ? err.message : err);
  process.exitCode = 2;
}
