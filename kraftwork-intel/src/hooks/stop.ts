import { openDb } from "../metrics/db";
import { randomUUID } from "crypto";

export interface StopEvent {
  session_id: string;
  response?: string;
}

export function handleStop(event: StopEvent): void {
  const db = openDb();
  db.run(
    "INSERT INTO interactions (id, session_id, role, content, created_at) VALUES (?, ?, ?, ?, ?)",
    [randomUUID(), event.session_id, "assistant", event.response ?? "", Date.now()]
  );
  db.close();
}
