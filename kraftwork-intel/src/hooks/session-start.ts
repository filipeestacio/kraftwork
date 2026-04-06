import { openDb } from "../metrics/db";

export interface SessionStartEvent {
  session_id: string;
  cwd: string;
}

export function handleSessionStart(event: SessionStartEvent): void {
  const db = openDb();
  db.run(
    "INSERT OR IGNORE INTO sessions (id, started_at, project_cwd) VALUES (?, ?, ?)",
    [event.session_id, Date.now(), event.cwd]
  );
  db.close();
}
