import { parseArgs } from 'node:util';

export type Mode = 'vault' | 'compile';

export interface CliArgs {
  mode: Mode;
  out: string;
  full: boolean;
  limit?: number;
  batch?: number;
}

export const HELP = `wikisync-cli - mirror the RAGE MP wiki into Markdown

  --mode vault|compile   vault = Obsidian vault with colors (default)
                         compile = plain Markdown, same file layout
  --out <dir>            output directory (default: dist)
  --full                 refetch every page, ignoring the manifest
  --limit <n>            only process n changed pages (testing)
  --batch <n>            pages rendered per API call (default: 50)
  -h, --help             show this help`;

export function parseCliArgs(argv: string[]): CliArgs | 'help' {
  const { values } = parseArgs({
    args: argv,
    options: {
      mode: { type: 'string', default: 'vault' },
      out: { type: 'string', default: 'dist' },
      full: { type: 'boolean', default: false },
      limit: { type: 'string' },
      batch: { type: 'string' },
      help: { type: 'boolean', short: 'h', default: false },
    },
  });
  if (values.help) return 'help';
  if (values.mode !== 'vault' && values.mode !== 'compile') {
    throw new Error('--mode must be "vault" or "compile"');
  }
  return {
    mode: values.mode,
    out: values.out,
    full: values.full,
    limit: values.limit ? Number(values.limit) : undefined,
    batch: values.batch ? Number(values.batch) : undefined,
  };
}
