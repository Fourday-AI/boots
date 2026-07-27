/**
 * Platform resolvers — the capability axis, rendered into skill bodies.
 *
 * These exist so a skill body can stay platform-NEUTRAL. Before this file, the
 * only way to say "Cowork" in a skill was to write it, which meant a second copy
 * of the skill, which meant drift — and drift is exactly what happened: the
 * hand-made Cowork snapshot ended up both behind the repo (missing a skill) and
 * ahead of it (extra translation rows, a bullet the repo's own router lacked),
 * with nobody noticing either direction.
 *
 * THE RULE THAT KEEPS THIS SMALL. There are four resolvers here and there should
 * not be a fifth without a fight. Platform-specific PROSE — what forms exist, how
 * to verify each, what "shipped" means, what to call things in front of the user —
 * belongs in `boots/forms/<palette>.md`, which the skills read at run time. This
 * file only carries what a skill body cannot defer to the palette: the product's
 * name, which palette to default to, and (for a host whose filesystem is not the
 * user's) a pointer to the home-resolution protocol.
 *
 * If you are about to add a paragraph here, put it in the palette instead.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { TemplateContext } from './types';
import { getHostConfig } from '../../hosts/index';

const ROOT = path.resolve(import.meta.dir, '..', '..');

/** The product name as the user knows it: "Claude Code", "Cowork". */
export const resolveRuntime = (ctx: TemplateContext): string =>
  getHostConfig(ctx.host).platform.runtime;

/** The palette slug a system's `platform:` field defaults to on this host. */
export const resolveDefaultPlatform = (ctx: TemplateContext): string =>
  getHostConfig(ctx.host).platform.palette;

/** Where the skills read palettes from, e.g. `~/.claude/skills/boots/forms`. */
export const resolveFormsDir = (ctx: TemplateContext): string =>
  `${ctx.paths.skillDir}/forms`;

/**
 * The home-resolution protocol, for hosts whose filesystem is not the user's.
 *
 * Rendered from `boots/reference/home-<homeModel>.md` so the prose stays in
 * markdown where it can be read and edited, rather than becoming a string
 * literal in a build script. A host with no matching file renders nothing —
 * which is the correct output for every terminal host, where the home is simply
 * a path and needs no protocol at all.
 */
export function resolveHomeProtocol(ctx: TemplateContext): string {
  const { homeModel } = getHostConfig(ctx.host).platform;
  const file = path.join(ROOT, 'boots', 'reference', `home-${homeModel}.md`);
  if (!fs.existsSync(file)) return '';
  return fs.readFileSync(file, 'utf-8').trim();
}
