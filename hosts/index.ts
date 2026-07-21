/**
 * Host config registry. Adding a host: create hosts/<name>.ts, import it here,
 * append to ALL_HOST_CONFIGS.
 */

import type { HostConfig } from '../scripts/host-config';
import claude from './claude';
import codex from './codex';

export const ALL_HOST_CONFIGS: HostConfig[] = [claude, codex];

export const HOST_CONFIG_MAP: Record<string, HostConfig> = Object.fromEntries(
  ALL_HOST_CONFIGS.map(c => [c.name, c]),
);

export type Host = (typeof ALL_HOST_CONFIGS)[number]['name'];
export const ALL_HOST_NAMES: string[] = ALL_HOST_CONFIGS.map(c => c.name);

export function getHostConfig(name: string): HostConfig {
  const config = HOST_CONFIG_MAP[name];
  if (!config) throw new Error(`Unknown host '${name}'. Valid hosts: ${ALL_HOST_NAMES.join(', ')}`);
  return config;
}

export function resolveHostArg(arg: string): string {
  if (HOST_CONFIG_MAP[arg]) return arg;
  for (const config of ALL_HOST_CONFIGS) {
    if (config.cliAliases?.includes(arg)) return config.name;
  }
  throw new Error(`Unknown host '${arg}'. Valid hosts: ${ALL_HOST_NAMES.join(', ')}`);
}

export { claude, codex };
