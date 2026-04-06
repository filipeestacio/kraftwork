import { openDb } from "../metrics/db";
import { randomUUID } from "crypto";

export interface UserPromptEvent {
  session_id: string;
  prompt: string;
}

export function handleUserPrompt(event: UserPromptEvent): void {
  const db = openDb();
  db.run(
    "INSERT INTO interactions (id, session_id, role, content, created_at) VALUES (?, ?, ?, ?, ?)",
    [randomUUID(), event.session_id, "user", event.prompt, Date.now()]
  );
  db.close();
}
