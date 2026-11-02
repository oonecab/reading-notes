import fs from 'node:fs';
export function supports(version, minimum, major) {
  const match = /^v?(\d+)\.(\d+)\.(\d+)$/.exec(version ?? '');
  if (!match) return false;
  const values = match.slice(1).map(Number);
  const lower = minimum.split('.').map(Number);
  return values[0] === major && (values[1] > lower[1] || (values[1] === lower[1] && values[2] >= lower[2]));
}
export function validateToolchain() {
  const node = process.versions.node;
  const pnpm = /^pnpm\/(\S+)/.exec(process.env.npm_config_user_agent ?? '')?.[1];
  if (!supports(node, '24.21.0', 24)) throw new Error('Requires Node >=24.21.0 <25');
  if (!supports(pnpm, '11.21.0', 11)) throw new Error('Run build with pnpm >=11.21.0 <12');
  const astro = JSON.parse(fs.readFileSync(new URL('../node_modules/astro/package.json', import.meta.url))).version;
  return {node, pnpm, astro};
}
