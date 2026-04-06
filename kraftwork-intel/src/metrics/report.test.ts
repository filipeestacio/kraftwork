import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { openDb } from "./db";
import { report } from "./report";

const TEST_DIR = join(import.meta.dir, "__test_data__");
const now = Date.now();

beforeEach(() => {
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
  const db = openDb();
  db.run("INSERT INTO sessions VALUES (?, ?, ?)", ["s1", now, "/proj"]);
  db.run("INSERT INTO skill_uses VALUES (?, ?, ?, ?)", ["u1", "s1", "memory-memorize", now]);
  db.run("INSERT INTO skill_uses VALUES (?, ?, ?, ?)", ["u2", "s1", "memory-memorize", now]);
  db.run("INSERT INTO skill_uses VALUES (?, ?, ?, ?)", ["u3", "s1", "kraft-plan", now]);
  db.close();
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("report", () => {
  it("returns skills sorted by uses descending", () => {
    const stats = report({});
    expect(stats[0].skill_name).toBe("memory-memorize");
    expect(stats[0].uses).toBe(2);
    expect(stats[1].skill_name).toBe("kraft-plan");
    expect(stats[1].uses).toBe(1);
  });

  it("filters by skill name", () => {
    const stats = report({ skill: "kraft-plan" });
    expect(stats).toHaveLength(1);
    expect(stats[0].skill_name).toBe("kraft-plan");
  });

  it("returns empty array when no usage in time window", () => {
    const stats = report({ days: 0 });
    expect(stats).toHaveLength(0);
  });
});
