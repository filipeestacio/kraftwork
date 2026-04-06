import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { openDb } from "../metrics/db";
import { handleSessionStart } from "./session-start";
import { handleUserPrompt } from "./user-prompt";
import { handlePostTool } from "./post-tool";
import { handleStop } from "./stop";

const TEST_DIR = join(import.meta.dir, "__test_data__");

beforeEach(() => {
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("handleSessionStart", () => {
  it("inserts a session row", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    const db = openDb();
    const row = db.query("SELECT * FROM sessions WHERE id = 's1'").get() as { id: string } | null;
    db.close();
    expect(row?.id).toBe("s1");
  });

  it("is idempotent (INSERT OR IGNORE)", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    expect(() => handleSessionStart({ session_id: "s1", cwd: "/proj" })).not.toThrow();
  });
});

describe("handleUserPrompt", () => {
  it("inserts a user interaction row", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    handleUserPrompt({ session_id: "s1", prompt: "Hello world" });
    const db = openDb();
    const row = db.query("SELECT * FROM interactions WHERE session_id = 's1' AND role = 'user'")
      .get() as { content: string } | null;
    db.close();
    expect(row?.content).toBe("Hello world");
  });
});

describe("handlePostTool", () => {
  it("inserts a skill_use row", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    handlePostTool({ session_id: "s1", tool_name: "Skill", tool_input: { skill: "brainstorming" } });
    const db = openDb();
    const row = db.query("SELECT * FROM skill_uses WHERE session_id = 's1'")
      .get() as { skill_name: string } | null;
    db.close();
    expect(row?.skill_name).toBe("brainstorming");
  });

  it("falls back to tool_name when skill field absent", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    handlePostTool({ session_id: "s1", tool_name: "Skill", tool_input: {} });
    const db = openDb();
    const row = db.query("SELECT * FROM skill_uses WHERE session_id = 's1'")
      .get() as { skill_name: string } | null;
    db.close();
    expect(row?.skill_name).toBe("Skill");
  });
});

describe("handleStop", () => {
  it("inserts an assistant interaction row", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    handleStop({ session_id: "s1", response: "Here is my answer." });
    const db = openDb();
    const row = db.query("SELECT * FROM interactions WHERE session_id = 's1' AND role = 'assistant'")
      .get() as { content: string } | null;
    db.close();
    expect(row?.content).toBe("Here is my answer.");
  });

  it("stores empty string gracefully when response absent", () => {
    handleSessionStart({ session_id: "s1", cwd: "/proj" });
    handleStop({ session_id: "s1", response: "" });
    const db = openDb();
    const row = db.query("SELECT * FROM interactions WHERE role = 'assistant'")
      .get() as { content: string } | null;
    db.close();
    expect(row?.content).toBe("");
  });
});
