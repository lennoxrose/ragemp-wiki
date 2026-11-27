/**
 * Category colors. Same algorithm as the Go side (internal/store/obsidian.go):
 * FNV-1a hash of the folder name -> hue, so the terminal matches Obsidian's graph.
 */
function fnv1a(text: string): number {
  let hash = 0x811c9dc5;
  for (const byte of new TextEncoder().encode(text)) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

function hslToHex(h: number, s: number, l: number): string {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  const sector = Math.floor(h / 60);
  const [r, g, b] = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c]][sector] ?? [c, 0, x];
  const hex = (v: number) => Math.round((v + m) * 255).toString(16).padStart(2, '0');
  return `#${hex(r)}${hex(g)}${hex(b)}`;
}

export const categoryColor = (name: string): string => hslToHex((fnv1a(name) % 3600) / 10, 0.72, 0.62);

export const theme = {
  brand: '#ffc828',
  ok: '#58e49d',
  warn: '#e4c458',
  bad: '#e45858',
  dim: 'gray',
} as const;
