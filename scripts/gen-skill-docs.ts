#!/usr/bin/env bun
/**
 * Generate SKILL.md files from SKILL.md.tmpl templates.
 *
 * Pipeline:
 *   read .tmpl → resolve {{PLACEHOLDERS}} → host frontmatter/path transforms → write .md
 *
 * Flags:
 *   --host <claude|codex|all>   target host (default: claude)
 *   --dry-run                   generate in memory; exit 1 if any output is stale
 *                               (the CI freshness gate — templates + outputs can't drift)
 *
 * Deliberately omitted (add back only if a real need appears): catalog-trim,
 * on-demand sections, voice-triggers, llms.txt, model overlays, out-dir.
 */

import * as fs from 'fs';
import * as path from 'path';
import type { TemplateContext } from './resolvers/types';
import { HOST_PATHS, unwrapResolver } from './resolvers/types';
import { RESOLVERS } from './resolvers/index';
import type { HostConfig } from './host-config';
import { ALL_HOST_NAMES, getHostConfig, resolveHostArg } from '../hosts/index';
import { discoverTemplates } from './discover-skills';

// Repo layout: engine lives in <repo>/scripts, skills are top-level dirs in <repo>
// (boots/, boots-build/, …) so the repo's front page is the list of what you get.
const ROOT = path.resolve(import.meta.dir, '..');
const DRY_RUN = process.argv.includes('--dry-run');

const GENERATED_HEADER =
  `<!-- AUTO-GENERATED from {{SOURCE}} — do not edit directly -->\n` +
  `<!-- Regenerate: bun run gen:skill-docs -->\n`;

// ─── Host arg ────────────────────────────────────────────────
const HOST_ARG = process.argv.find(a => a.startsWith('--host'));
const HOST_ARG_VAL: string = (() => {
  if (!HOST_ARG) return 'claude';
  const val = HOST_ARG.includes('=') ? HOST_ARG.split('=')[1] : process.argv[process.argv.indexOf(HOST_ARG) + 1];
  if (val === 'all') return 'all';
  return resolveHostArg(val);
})();

// ─── Frontmatter helpers ─────────────────────────────────────

function extractNameAndDescription(content: string): { name: string; description: string } {
  if (!content.startsWith('---\n')) return { name: '', description: '' };
  const fmEnd = content.indexOf('\n---', 4);
  if (fmEnd === -1) return { name: '', description: '' };
  const frontmatter = content.slice(4, fmEnd);

  const nameMatch = frontmatter.match(/^name:\s*(.+)$/m);
  const name = nameMatch ? nameMatch[1].trim() : '';

  let description = '';
  const lines = frontmatter.split('\n');
  let inDescription = false;
  const descLines: string[] = [];
  for (const line of lines) {
    if (line.match(/^description:\s*[|>]?\s*$/)) { inDescription = true; continue; }
    if (line.match(/^description:\s*\S/)) { description = line.replace(/^description:\s*/, '').trim(); break; }
    if (inDescription) {
      if (line === '' || line.match(/^\s/)) descLines.push(line.replace(/^\s{2}/, ''));
      else break;
    }
  }
  if (descLines.length > 0) description = descLines.join('\n').trim();
  return { name, description };
}

/** Transform frontmatter for the target host (allowlist rebuild or denylist strip). */
function transformFrontmatter(content: string, host: string): string {
  const hostConfig = getHostConfig(host);
  const fm = hostConfig.frontmatter;

  if (fm.mode === 'denylist') {
    for (const field of fm.stripFields || []) {
      if (field === 'voice-triggers') {
        content = content.replace(/^voice-triggers:\n(?:\s+-\s+"[^"]*"\n?)*/m, '');
      } else {
        content = content.replace(new RegExp(`^${field}:\\s*.*\\n`, 'm'), '');
      }
    }
    return content;
  }

  // allowlist: rebuild frontmatter with only allowed fields
  const fmStart = content.indexOf('---\n');
  if (fmStart !== 0) return content;
  const fmEnd = content.indexOf('\n---', fmStart + 4);
  if (fmEnd === -1) return content;
  const frontmatter = content.slice(fmStart + 4, fmEnd);
  const body = content.slice(fmEnd + 4);
  const { name, description } = extractNameAndDescription(content);

  if (fm.descriptionLimit && description.length > fm.descriptionLimit) {
    const behavior = fm.descriptionLimitBehavior || 'error';
    if (behavior === 'error') {
      throw new Error(
        `${hostConfig.displayName} description for "${name}" is ${description.length} chars ` +
        `(max ${fm.descriptionLimit}). Compress it in the .tmpl.`,
      );
    } else if (behavior === 'warn') {
      console.warn(`WARNING: ${hostConfig.displayName} description for "${name}" exceeds ${fm.descriptionLimit} chars`);
    }
  }

  const indentedDesc = description.split('\n').map(l => `  ${l}`).join('\n');
  let newFm = `---\nname: ${name}\ndescription: |\n${indentedDesc}\n`;
  if (fm.keepFields) {
    for (const field of fm.keepFields) {
      if (field === 'name' || field === 'description') continue;
      const fieldMatch = frontmatter.match(new RegExp(`^${field}:(.*(?:\\n(?:[ \\t]+.+))*)`, 'm'));
      if (fieldMatch) newFm += `${field}:${fieldMatch[1]}\n`;
    }
  }
  newFm += '---';
  return newFm + body;
}

/** Condense a description to a <=120-char lead for external-host metadata,
 * truncating on a word boundary (matches the condenseOpenAIShortDescription
 * — a hard slice mid-word reads badly in the host's skill picker). */
function condenseShortDescription(description: string): string {
  const LIMIT = 120;
  const lead = (description.split(/\n\s*\n/)[0] || description).replace(/\s+/g, ' ').trim();
  if (lead.length <= LIMIT) return lead;
  const truncated = lead.slice(0, LIMIT - 3);
  const lastSpace = truncated.lastIndexOf(' ');
  return `${lastSpace > 40 ? truncated.slice(0, lastSpace) : truncated}...`;
}

function applyHostRewrites(content: string, hostConfig: HostConfig): string {
  let result = content;
  for (const rewrite of hostConfig.pathRewrites) result = result.replaceAll(rewrite.from, rewrite.to);
  if (hostConfig.toolRewrites) {
    for (const [from, to] of Object.entries(hostConfig.toolRewrites)) result = result.replaceAll(from, to);
  }
  return result;
}

// ─── Placeholder resolution ──────────────────────────────────

function buildContext(tmplContent: string, tmplPath: string, host: string): TemplateContext {
  const { name } = extractNameAndDescription(tmplContent);
  const skillName = name || path.basename(path.dirname(tmplPath));
  const tierMatch = tmplContent.match(/^preamble-tier:\s*(\d+)$/m);
  const preambleTier = tierMatch ? parseInt(tierMatch[1], 10) : undefined;
  const interactiveMatch = tmplContent.match(/^interactive:\s*(true|false)\s*$/m);
  const interactive = interactiveMatch ? interactiveMatch[1] === 'true' : undefined;
  return { skillName, tmplPath, host, paths: HOST_PATHS[host], preambleTier, interactive };
}

function resolvePlaceholders(tmplContent: string, ctx: TemplateContext, hostConfig: HostConfig, rel: string): string {
  const suppressed = new Set(hostConfig.suppressedResolvers || []);
  const onePass = (input: string): string =>
    input.replace(/\{\{(\w+(?::[^}]+)?)\}\}/g, (_m, fullKey) => {
      const parts = fullKey.split(':');
      const name = parts[0];
      const args = parts.slice(1);
      if (suppressed.has(name)) return '';
      const entry = RESOLVERS[name];
      if (!entry) throw new Error(`Unknown placeholder {{${name}}} in ${rel}`);
      const { resolve, appliesTo } = unwrapResolver(entry);
      if (appliesTo && !appliesTo(ctx)) return '';
      return args.length > 0 ? resolve(ctx, args) : resolve(ctx);
    });

  // Multi-pass: a resolver may emit further placeholders. Bounded to 6.
  let content = tmplContent;
  for (let pass = 0; pass < 6; pass++) {
    const next = onePass(content);
    if (next === content) break;
    content = next;
  }
  const remaining = content.match(/\{\{(\w+(?::[^}]+)?)\}\}/g);
  if (remaining) throw new Error(`Unresolved placeholders in ${rel}: ${remaining.join(', ')}`);
  return content;
}

// ─── Per-template processing ─────────────────────────────────

function processTemplate(tmplPath: string, host: string): { outputPath: string; content: string } {
  const tmplContent = fs.readFileSync(tmplPath, 'utf-8');
  const rel = path.relative(ROOT, tmplPath);
  const hostConfig = getHostConfig(host);
  const skillDir = path.relative(ROOT, path.dirname(tmplPath));
  const ctx = buildContext(tmplContent, tmplPath, host);
  const { name, description } = extractNameAndDescription(tmplContent);

  let content = resolvePlaceholders(tmplContent, ctx, hostConfig, rel);
  content = transformFrontmatter(content, host);

  let outputPath: string;
  if (host === 'claude') {
    outputPath = tmplPath.replace(/\.tmpl$/, '');
  } else {
    // External host: route to <hostSubdir>/skills/<name>/SKILL.md + metadata sidecar.
    //
    // WHERE <hostSubdir> IS ANCHORED depends on how the host takes delivery.
    //
    //   'symlink' hosts (Codex) install from a sibling of the repo's own skills
    //   dir — the documented layout puts the repo at <skills>/.boots, so two
    //   levels up is the host's config root. That is a real install path on the
    //   user's machine, deliberately outside the repo.
    //
    //   'plugin' hosts (Cowork) do not install from a path at all: the repo
    //   BUILDS a bundle that the user installs through the host's own mechanism.
    //   A build output belongs inside the repo that produced it, so it can be
    //   inspected, tested, and packaged. Writing it two levels up would scatter
    //   build artifacts across the user's home directory.
    const anchor = hostConfig.packaging === 'plugin' ? ROOT : path.resolve(ROOT, '..', '..');
    const externalName = skillDir || name;
    const outputDir = path.join(anchor, hostConfig.hostSubdir, 'skills', externalName);
    fs.mkdirSync(outputDir, { recursive: true });
    outputPath = path.join(outputDir, 'SKILL.md');
    content = applyHostRewrites(content, hostConfig);
    if (hostConfig.generation.generateMetadata) {
      const shortDesc = condenseShortDescription(description);
      const yaml =
        `interface:\n  display_name: ${JSON.stringify(name)}\n` +
        `  short_description: ${JSON.stringify(shortDesc)}\n` +
        `  default_prompt: ${JSON.stringify(`Use ${name} for this task.`)}\n` +
        `policy:\n  allow_implicit_invocation: true\n`;
      fs.writeFileSync(path.join(outputDir, 'openai.yaml'), yaml);
    }
  }

  // Prepend the generated header after the frontmatter close.
  const header = GENERATED_HEADER.replace('{{SOURCE}}', path.basename(tmplPath));
  const fmEnd = content.indexOf('---', content.indexOf('---') + 3);
  if (fmEnd !== -1) {
    const insertAt = content.indexOf('\n', fmEnd) + 1;
    content = content.slice(0, insertAt) + header + content.slice(insertAt);
  } else {
    content = header + content;
  }

  return { outputPath, content };
}

// ─── Main ────────────────────────────────────────────────────

const hostsToRun = HOST_ARG_VAL === 'all' ? ALL_HOST_NAMES : [HOST_ARG_VAL];
let hasChanges = false;

for (const host of hostsToRun) {
  const hostConfig = getHostConfig(host);
  for (const { tmpl } of discoverTemplates(ROOT)) {
    const dir = path.basename(path.dirname(path.join(ROOT, tmpl)));
    if (hostConfig.generation.includeSkills?.length && !hostConfig.generation.includeSkills.includes(dir)) continue;
    if (hostConfig.generation.skipSkills?.includes(dir)) continue;

    const { outputPath, content } = processTemplate(path.join(ROOT, tmpl), host);
    const relOut = path.relative(ROOT, outputPath);

    if (DRY_RUN) {
      const existing = fs.existsSync(outputPath) ? fs.readFileSync(outputPath, 'utf-8') : '';
      if (existing !== content) { console.log(`STALE: ${relOut}`); hasChanges = true; }
      else console.log(`FRESH: ${relOut}`);
    } else {
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      fs.writeFileSync(outputPath, content);
      console.log(`GENERATED (${host}): ${relOut}`);
    }
  }
}

if (DRY_RUN && hasChanges) {
  console.error(`\nGenerated SKILL.md files are stale. Run: bun run gen:skill-docs`);
  process.exit(1);
}
