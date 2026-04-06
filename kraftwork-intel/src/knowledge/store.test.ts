import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { store } from "./store";

const TEST_DIR = join(import.meta.dir, "__test_data__");
const fakeEmbed = async (_: string) =>
  Array.from({ length: 384 }, (_, i) => i / 384);

beforeEach(() => {
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("store", () => {
  it("returns a UUID string", async () => {
    const id = await store(
      { content: "test fact", category: "pattern", project: "api" },
      fakeEmbed
    );
    expect(typeof id).toBe("string");
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    );
  });

  it("stores a second record without error", async () => {
    await store({ content: "fact one", category: "pattern", project: "api" }, fakeEmbed);
    const id2 = await store({ content: "fact two", category: "architecture", project: "api" }, fakeEmbed);
    expect(typeof id2).toBe("string");
  });
});
