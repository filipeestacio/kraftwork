import { mkdirSync, writeFileSync, chmodSync } from "node:fs";
import { openDb } from "../metrics/db";

export interface SessionStartEvent {
  session_id: string;
  cwd: string;
}

export function bootstrapCli(cliPath: string): void {
  if (!cliPath) return;
  const home = process.env.HOME;
  if (!home) return;
  const dir = `${home}/.claude/kraftwork-intel`;
  const wrapper = `${dir}/cli`;
  // Hooks run with CLAUDE_PLUGIN_DATA pointing at the plugin-isolated data dir.
  // Bake it into the shim so direct CLI invocation reads the same DB the hooks write.
  // Use ":=" so the user can still override CLAUDE_PLUGIN_DATA at call time.
  const pluginData = process.env.CLAUDE_PLUGIN_DATA;
  const dataLine = pluginData
    ? `: "\${CLAUDE_PLUGIN_DATA:=${pluginData}}"\nexport CLAUDE_PLUGIN_DATA\n`
    : "";
  try {
    mkdirSync(dir, { recursive: true });
    writeFileSync(wrapper, `#!/bin/sh\n${dataLine}exec bun run "${cliPath}" "$@"\n`);
    chmodSync(wrapper, 0o755);
  } catch {
    // best-effort — never fail a hook
  }
}

export function handleSessionStart(event: SessionStartEvent, cliPath: string): void {
  bootstrapCli(cliPath);
  const db = openDb();
  db.run(
    "INSERT OR IGNORE INTO sessions (id, started_at, project_cwd) VALUES (?, ?, ?)",
    [event.session_id, Date.now(), event.cwd]
  );
  db.close();
}
