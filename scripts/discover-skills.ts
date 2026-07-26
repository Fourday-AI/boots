/**
 * Discover SKILL.md.tmpl files under the skills root.
 * Scans root + one level of subdirs, skipping node_modules/.git/dist and the
 * repo's own non-skill directories. A skill opts into the engine simply by
 * having a SKILL.md.tmpl; hand-written SKILL.md files (no .tmpl) are left
 * untouched. Skills are top-level dirs in the repo, so the skills root and the
 * repo root are the same directory.
 */

import * as fs from 'fs';
import * as path from 'path';

const SKIP = new Set([
  'node_modules', '.git', 'dist',
  // Repo machinery, never skills — listed so a stray SKILL.md.tmpl in one of
  // them can't quietly become a published skill.
  'scripts', 'hosts', 'docs', 'migrations', 'supabase', 'evals',
]);

function subdirs(root: string): string[] {
  return fs.readdirSync(root, { withFileTypes: true })
    .filter(d => d.isDirectory() && !d.name.startsWith('.') && !SKIP.has(d.name))
    .map(d => d.name);
}

export function discoverTemplates(root: string): Array<{ tmpl: string; output: string }> {
  const dirs = ['', ...subdirs(root)];
  const results: Array<{ tmpl: string; output: string }> = [];
  for (const dir of dirs) {
    const rel = dir ? `${dir}/SKILL.md.tmpl` : 'SKILL.md.tmpl';
    if (fs.existsSync(path.join(root, rel))) {
      results.push({ tmpl: rel, output: rel.replace(/\.tmpl$/, '') });
    }
  }
  return results.sort((a, b) => a.tmpl.localeCompare(b.tmpl));
}
