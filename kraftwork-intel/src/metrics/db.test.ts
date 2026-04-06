import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { openDb } from "./db";

const TEST_DIR = join(import.meta.dir, "__test_data__");

beforeEach(() => {
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("openDb", () => {
  it("creates all four tables on first open", () => {
    const db = openDb();
    const tables = db.query(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    ).all() as { name: string }[];
    const names = tables.map((t) => t.name);
    expect(names).toContain("sessions");
    expect(names).toContain("interactions");
    expect(names).toContain("skill_uses");
    expect(names).toContain("eval_results");
  });

  it("is idempotent — calling twice does not error", () => {
    openDb();
    expect(() => openDb()).not.toThrow();
  });

  it("inserts and retrieves a session row", () => {
    const db = openDb();
    db.run("INSERT INTO sessions (id, started_at, project_cwd) VALUES (?, ?, ?)", [
      "s1", 1000, "/proj",
    ]);
    const row = db.query("SELECT * FROM sessions WHERE id = ?").get("s1") as {
      id: string; started_at: number; project_cwd: string;
    };
    expect(row.id).toBe("s1");
    expect(row.project_cwd).toBe("/proj");
  });
});
