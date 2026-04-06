import { mkdirSync, writeFileSync, chmodSync } from "node:fs";
import { openDb } from "../metrics/db";

export interface SessionStartEvent {
  session_id: string;
  cwd: string;
}

function bootstrapCli(cliPath: string): void {
  if (!cliPath) return;
  const home = process.env.HOME;
  if (!home) return;
  const dir = `${home}/.claude/kraftwork-intel`;
  const wrapper = `${dir}/cli`;
  try {
    mkdirSync(dir, { recursive: true });
    writeFileSync(wrapper, `#!/bin/sh\nexec bun run "${cliPath}" "$@"\n`);
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
