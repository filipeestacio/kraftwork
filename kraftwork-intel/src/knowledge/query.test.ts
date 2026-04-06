import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { store } from "./store";
import { query } from "./query";

const TEST_DIR = join(import.meta.dir, "__test_data__");
let callCount = 0;
const fakeEmbed = async (_: string) =>
  Array.from({ length: 384 }, (_, i) => (i + callCount++) / 384);

beforeEach(() => {
  callCount = 0;
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("query", () => {
  it("returns empty array when knowledge table does not exist", async () => {
    const results = await query("anything", {}, fakeEmbed);
    expect(results).toEqual([]);
  });

  it("returns stored records", async () => {
    await store({ content: "use dependency injection", category: "pattern", project: "api" }, fakeEmbed);
    await store({ content: "postgres for persistence", category: "architecture", project: "api" }, fakeEmbed);
    const results = await query("injection pattern", { limit: 5 }, fakeEmbed);
    expect(results.length).toBeGreaterThan(0);
    expect(results[0]).toHaveProperty("content");
    expect(results[0]).toHaveProperty("category");
  });

  it("excludes superseded records", async () => {
    const oldId = await store({ content: "old fact", category: "pattern", project: "api" }, fakeEmbed);
    await store({ content: "new fact", category: "pattern", project: "api", supersedes: oldId }, fakeEmbed);
    const results = await query("fact", { limit: 10 }, fakeEmbed);
    const contents = results.map((r) => r.content);
    expect(contents).not.toContain("old fact");
    expect(contents).toContain("new fact");
  });
});
