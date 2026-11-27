import path from 'node:path';
import { isSea } from 'node:sea';
import { fileURLToPath } from 'node:url';

const exe = process.platform === 'win32' ? 'wikisync.exe' : 'wikisync';

// Compiled: <root>/bin/wikisync-cli.exe -> <root>.  From source: cmd/cli/src/config -> <root>.
export const repoRoot = isSea()
  ? path.resolve(path.dirname(process.execPath), '..')
  : path.resolve(fileURLToPath(new URL('../../../../', import.meta.url)));

/** The compiled Go core (`pnpm build` writes it to bin/). */
export const goBinary = process.env.WIKISYNC_BIN ?? path.join(repoRoot, 'bin', exe);
