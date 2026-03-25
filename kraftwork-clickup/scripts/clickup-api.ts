#!/usr/bin/env bun
/**
 * clickup-api.ts — Core infrastructure for kraftwork-clickup subcommands.
 *
 * Usage:
 *   bun run clickup-api.ts <subcommand> [--flag value] [positional...]
 *
 * Output is always JSON to stdout:
 *   { "ok": true, "data": ... }
 *   { "ok": false, "error": "..." }
 */

import * as fs from "fs";
import * as path from "path";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ClickUpConfig {
  teamId: string;
  tokenEnv: string;
  defaultList: string;
  chatChannelId?: string;
  spaces?: Record<string, unknown>;
}

export interface OkResult<T = unknown> {
  ok: true;
  data: T;
}

export interface ErrResult {
  ok: false;
  error: string;
}

export type Result<T = unknown> = OkResult<T> | ErrResult;

export interface ParsedArgs {
  subcommand: string;
  flags: Record<string, string>;
  positional: string[];
}

// ---------------------------------------------------------------------------
// 1. Config reader
// ---------------------------------------------------------------------------

/**
 * Walk up from startDir (or $KRAFTWORK_WORKSPACE) to find workspace.json,
 * then extract and return the `clickup` section.
 */
export function loadConfig(startDir?: string): ClickUpConfig {
  const workspaceEnv = process.env.KRAFTWORK_WORKSPACE;
  const searchFrom = workspaceEnv ?? startDir ?? process.cwd();

  const workspaceRoot = findWorkspaceRoot(searchFrom);
  if (!workspaceRoot) {
    output({ ok: false, error: "workspace.json not found. Run /kraft-init to configure." });
    process.exit(1);
  }

  const configPath = path.join(workspaceRoot, "workspace.json");
  let raw: Record<string, unknown>;
  try {
    raw = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (err) {
    output({ ok: false, error: `Failed to read workspace.json: ${String(err)}` });
    process.exit(1);
  }

  const section = raw["clickup"] as Record<string, unknown> | undefined;
  if (!section) {
    output({
      ok: false,
      error: "No 'clickup' section found in workspace.json. Run /kraft-init to configure.",
    });
    process.exit(1);
  }

  const teamId = section["teamId"] as string | undefined;
  const defaultList = section["defaultList"] as string | undefined;

  if (!teamId) {
    output({ ok: false, error: "Missing 'clickup.teamId' in workspace.json." });
    process.exit(1);
  }
  if (!defaultList) {
    output({ ok: false, error: "Missing 'clickup.defaultList' in workspace.json." });
    process.exit(1);
  }

  return {
    teamId,
    tokenEnv: (section["token_env"] as string | undefined) ?? "CLICKUP_TOKEN",
    defaultList,
    chatChannelId: section["chatChannelId"] as string | undefined,
    spaces: section["spaces"] as Record<string, unknown> | undefined,
  };
}

function findWorkspaceRoot(startDir: string): string | null {
  let dir = path.resolve(startDir);
  while (true) {
    if (fs.existsSync(path.join(dir, "workspace.json"))) {
      return dir;
    }
    const parent = path.dirname(dir);
    if (parent === dir) break; // reached filesystem root
    dir = parent;
  }
  return null;
}

// ---------------------------------------------------------------------------
// 2. Auth
// ---------------------------------------------------------------------------

/**
 * Read the ClickUp API token from the environment variable named in config.
 * Exits with an error envelope if the variable is unset.
 */
export function getToken(config: ClickUpConfig): string {
  const token = process.env[config.tokenEnv];
  if (!token) {
    output({
      ok: false,
      error: `Set the ${config.tokenEnv} environment variable with your ClickUp API token.`,
    });
    process.exit(1);
  }
  return token;
}

// ---------------------------------------------------------------------------
// 3. HTTP client wrapper
// ---------------------------------------------------------------------------

const BASE_URL_V2 = "https://api.clickup.com/api/v2";
export const BASE_URL_V3 = "https://api.clickup.com/api/v3";
const MAX_RETRIES = 3;

export async function request(
  method: string,
  url: string,
  body?: unknown,
  baseUrl: string = BASE_URL_V2
): Promise<Result> {
  const fullUrl = url.startsWith("http") ? url : `${baseUrl}${url}`;
  const token = _currentToken;

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const fetchOptions: RequestInit = {
      method,
      headers: {
        Authorization: token,
        "Content-Type": "application/json",
      },
    };
    if (body !== undefined) {
      fetchOptions.body = JSON.stringify(body);
    }

    let response: Response;
    try {
      response = await fetch(fullUrl, fetchOptions);
    } catch (err) {
      return { ok: false, error: `Network error: ${String(err)}` };
    }

    // Rate limited — wait and retry
    if (response.status === 429) {
      const resetHeader = response.headers.get("X-RateLimit-Reset");
      const resetAt = resetHeader ? parseInt(resetHeader, 10) * 1000 : Date.now() + 1000;
      const waitMs = Math.max(resetAt - Date.now(), 500);
      await sleep(waitMs);
      continue;
    }

    // Non-2xx error
    if (!response.ok) {
      let errorBody: string;
      try {
        errorBody = await response.text();
      } catch {
        errorBody = "(unreadable)";
      }
      return { ok: false, error: `${response.status}: ${errorBody}` };
    }

    // Success
    let data: unknown;
    try {
      data = await response.json();
    } catch {
      data = null;
    }
    return { ok: true, data };
  }

  return { ok: false, error: "Max retries exceeded (rate limited)." };
}

/** Token used by the HTTP client — set via initClient(). */
let _currentToken = "";

export function initClient(token: string): void {
  _currentToken = token;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// ---------------------------------------------------------------------------
// 4. Custom task ID helper
// ---------------------------------------------------------------------------

const CUSTOM_TASK_ID_RE = /^[A-Z]+-[0-9]+$/;

/**
 * Returns the task endpoint URL for a given task ID.
 * If the ID looks like a custom task ID (e.g. "ABC-123"), appends
 * custom_task_ids and team_id query params.
 */
export function taskUrl(taskId: string, teamId: string): string {
  if (CUSTOM_TASK_ID_RE.test(taskId)) {
    return `/task/${taskId}?custom_task_ids=true&team_id=${teamId}`;
  }
  return `/task/${taskId}`;
}

// ---------------------------------------------------------------------------
// 5. Pagination helper
// ---------------------------------------------------------------------------

const PAGE_SIZE = 100;

/**
 * Fetches paginated results from a list endpoint.
 * Stops when a page returns fewer than PAGE_SIZE items.
 * Returns all collected items in a single array.
 */
export async function paginateList(url: string): Promise<Result<unknown[]>> {
  const allItems: unknown[] = [];
  let page = 0;

  while (true) {
    const separator = url.includes("?") ? "&" : "?";
    const pageUrl = `${url}${separator}page=${page}&limit=${PAGE_SIZE}`;

    const result = await request("GET", pageUrl);
    if (!result.ok) return result;

    const data = result.data as Record<string, unknown>;

    // ClickUp list responses typically wrap items in a named array field.
    // Try common field names; fall back to treating data itself as an array.
    let items: unknown[];
    if (Array.isArray(data)) {
      items = data;
    } else {
      const arrayField = Object.values(data).find((v) => Array.isArray(v)) as
        | unknown[]
        | undefined;
      items = arrayField ?? [];
    }

    allItems.push(...items);

    if (items.length < PAGE_SIZE) break;
    page++;
  }

  return { ok: true, data: allItems };
}

// ---------------------------------------------------------------------------
// 6. Arg parser
// ---------------------------------------------------------------------------

/**
 * Parses process.argv (skipping node/bun and script path) into:
 *   - subcommand: first non-flag argument
 *   - flags: --key value pairs
 *   - positional: remaining non-flag arguments after subcommand
 */
export function parseArgs(argv: string[] = process.argv.slice(2)): ParsedArgs {
  const flags: Record<string, string> = {};
  const positional: string[] = [];
  let subcommand = "";

  let i = 0;
  while (i < argv.length) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (next !== undefined && !next.startsWith("--")) {
        flags[key] = next;
        i += 2;
      } else {
        // Boolean flag with no value
        flags[key] = "true";
        i++;
      }
    } else {
      if (!subcommand) {
        subcommand = arg;
      } else {
        positional.push(arg);
      }
      i++;
    }
  }

  return { subcommand, flags, positional };
}

// ---------------------------------------------------------------------------
// 7. Output helper
// ---------------------------------------------------------------------------

export function output(result: Result): void {
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

// ---------------------------------------------------------------------------
// 8. Main dispatch
// ---------------------------------------------------------------------------

// Subcommand handler registry — populated by later tasks.
type SubcommandHandler = (
  args: ParsedArgs,
  config: ClickUpConfig
) => Promise<Result>;

const subcommands: Record<string, SubcommandHandler> = {
  // Subcommands will be registered here in subsequent tasks.
};

export async function main(): Promise<void> {
  const args = parseArgs();

  // Validate subcommand before loading config/auth so that unknown subcommands
  // produce a clean error without requiring workspace.json or a token.
  const handler = subcommands[args.subcommand];
  if (!handler) {
    const name = args.subcommand || "(none)";
    output({ ok: false, error: `Unknown subcommand: ${name}` });
    process.exit(1);
  }

  const config = loadConfig();
  const token = getToken(config);
  initClient(token);

  const result = await handler(args, config);
  output(result);
  if (!result.ok) process.exit(1);
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

if (import.meta.main) {
  main().catch((err: unknown) => {
    output({ ok: false, error: String(err) });
    process.exit(1);
  });
}
