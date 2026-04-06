import { Database } from "bun:sqlite";
import { mkdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";

export function dataDir(): string {
  return (
    process.env.CLAUDE_PLUGIN_DATA ??
    join(homedir(), ".claude", "kraftwork-intel", "data")
  );
}

export function openDb(): Database {
  const dir = dataDir();
  mkdirSync(dir, { recursive: true });
  const db = new Database(join(dir, "metrics.db"));
  db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      started_at INTEGER NOT NULL,
      project_cwd TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS interactions (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS skill_uses (
      id TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      skill_name TEXT NOT NULL,
      invoked_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS eval_results (
      id TEXT PRIMARY KEY,
      skill_name TEXT NOT NULL,
      scorer TEXT NOT NULL,
      score REAL NOT NULL,
      ran_at INTEGER NOT NULL
    );
  `);
  return db;
}
