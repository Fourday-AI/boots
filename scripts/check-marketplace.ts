#!/usr/bin/env bun
/**
 * Validate `.claude-plugin/marketplace.json` — the catalog Claude Code reads when
 * a user runs `/plugin marketplace add Fourday-AI/boots`.
 *
 * WHY THIS EXISTS. The catalog is the one file in the repo whose failure mode is
 * total and silent: if it is malformed, or points at a directory that isn't
 * committed, the marketplace does not load and every user sees nothing. There is
 * no partial success and no error surfaced back to us. So it gets a gate.
 *
 * The unusual check is the LAST one. A `version` on a plugin entry PINS that
 * plugin: Claude Code resolves a version from plugin.json → the marketplace entry
 * → the git commit SHA, and skips the update when the resolved version matches
 * what a user already has. Omitting it everywhere is what makes `git push` a
 * release. So here, a version present is the bug and its absence is correct.
 *
 * Usage:  bun run scripts/check-marketplace.ts
 */

import * as fs from 'fs';
import * as path from 'path';

const ROOT = path.resolve(import.meta.dir, '..');
const FILE = path.join(ROOT, '.claude-plugin', 'marketplace.json');

const problems: string[] = [];
const fail = (s: string) => problems.push(s);

if (!fs.existsSync(FILE)) {
  console.error(`✗ no .claude-plugin/marketplace.json — there is no marketplace to add.`);
  process.exit(1);
}

let m: any;
try {
  m = JSON.parse(fs.readFileSync(FILE, 'utf-8'));
} catch (e) {
  console.error(`✗ marketplace.json is not valid JSON: ${e}`);
  process.exit(1);
}

// ─── Marketplace-level ───────────────────────────────────────
if (!m.name) fail('no `name` — this is the identifier users install against (boots@<name>)');
else if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(m.name)) fail(`name '${m.name}' is not kebab-case`);

// Names Anthropic reserves for official sources. A marketplace registered under
// one of these stops loading entirely — and the list is re-checked on every load,
// so a name that is fine today can be revoked later.
const RESERVED = [
  'claude-code-marketplace', 'claude-code-plugins', 'claude-plugins-official',
  'claude-plugins-community', 'claude-community', 'anthropic-marketplace',
  'anthropic-plugins', 'agent-skills', 'anthropic-agent-skills',
  'knowledge-work-plugins', 'life-sciences', 'claude-for-legal',
  'claude-for-financial-services', 'financial-services-plugins',
  'first-party-plugins', 'healthcare',
];
if (RESERVED.includes(m.name)) fail(`name '${m.name}' is reserved for Anthropic and will not load`);

if (!m.owner?.name) fail('no `owner.name` — required');
if (!Array.isArray(m.plugins) || m.plugins.length === 0) fail('`plugins` is empty — nothing to install');

// ─── Per-plugin ──────────────────────────────────────────────
const seen = new Set<string>();
for (const p of m.plugins ?? []) {
  const id = p?.name ?? '<unnamed>';
  if (!p?.name) fail('a plugin entry has no `name`');
  else if (seen.has(p.name)) fail(`two plugin entries are both named '${p.name}'`);
  else seen.add(p.name);

  if (!p?.source) { fail(`plugin '${id}' has no `+'`source`'); continue; }

  // The pinning check — see the header note. This is deliberately inverted.
  if (p.version) {
    fail(
      `plugin '${id}' sets version '${p.version}'. That pins it: installed copies ` +
      `compare against it and skip the update, so pushed changes never reach users. ` +
      `Omit it and the commit SHA becomes the version.`,
    );
  }

  // A relative source resolves against the marketplace ROOT — the directory
  // holding .claude-plugin/, not the json file. If it isn't committed, the entry
  // resolves to nothing on a fresh clone even though it works on this machine.
  if (typeof p.source === 'string' && p.source.startsWith('.')) {
    const target = path.join(ROOT, p.source);
    if (!fs.existsSync(target)) {
      fail(`plugin '${id}' points at ${p.source}, which does not exist`);
    } else if (!fs.existsSync(path.join(target, '.claude-plugin', 'plugin.json'))
            && !fs.existsSync(path.join(target, 'skills'))) {
      fail(`plugin '${id}' points at ${p.source}, which has neither a manifest nor skills/`);
    }
    if (p.source.includes('..')) fail(`plugin '${id}' source escapes the marketplace root`);
  }
}

// ─── Report ──────────────────────────────────────────────────
if (problems.length) {
  console.error(`\n${problems.length} problem(s) with .claude-plugin/marketplace.json:`);
  for (const p of problems) console.error(`  ✗ ${p}`);
  process.exit(1);
}

console.log(
  `OK — marketplace '${m.name}' lists ${m.plugins.length} plugin(s): ` +
  `${m.plugins.map((p: any) => p.name).join(', ')}. No entry is version-pinned.`,
);
