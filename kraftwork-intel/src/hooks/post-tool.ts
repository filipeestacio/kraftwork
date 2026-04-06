import { openDb } from "../metrics/db";
import { randomUUID } from "crypto";

export interface PostToolEvent {
  session_id: string;
  tool_name: string;
  tool_input?: { skill?: string; [key: string]: unknown };
}

export function handlePostTool(event: PostToolEvent): void {
  const skillName = event.tool_input?.skill ?? event.tool_name;
  const db = openDb();
  db.run(
    "INSERT INTO skill_uses (id, session_id, skill_name, invoked_at) VALUES (?, ?, ?, ?)",
    [randomUUID(), event.session_id, skillName, Date.now()]
  );
  db.close();
}
