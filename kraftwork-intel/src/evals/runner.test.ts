import { describe, it, expect, beforeEach, afterEach } from "bun:test";
import { mkdirSync, rmSync } from "fs";
import { join } from "path";
import { openDb } from "../metrics/db";
import {
  scoreResponseLength,
  scoreAskedClarifyingQuestions,
  scoreFollowedTDD,
  scoreNoComments,
  evalSkill,
} from "./runner";

const TEST_DIR = join(import.meta.dir, "__test_data__");
const now = Date.now();

beforeEach(() => {
  process.env.CLAUDE_PLUGIN_DATA = TEST_DIR;
  mkdirSync(TEST_DIR, { recursive: true });
  const db = openDb();
  db.run("INSERT INTO sessions VALUES (?, ?, ?)", ["s1", now, "/proj"]);
  db.run("INSERT INTO skill_uses VALUES (?, ?, ?, ?)", ["u1", "s1", "memory-memorize", now]);
  db.run("INSERT INTO interactions VALUES (?, ?, ?, ?, ?)", [
    "i1", "s1", "assistant",
    "This is a medium-length response that answers the question well without being too long.",
    now,
  ]);
  db.close();
});

afterEach(() => {
  rmSync(TEST_DIR, { recursive: true, force: true });
  delete process.env.CLAUDE_PLUGIN_DATA;
});

describe("heuristic scorers", () => {
  it("scoreResponseLength: penalises very short responses", () => {
    expect(scoreResponseLength("hi")).toBeLessThan(0.5);
  });

  it("scoreResponseLength: rewards medium-length responses", () => {
    expect(scoreResponseLength("x".repeat(500))).toBe(1.0);
  });

  it("scoreAskedClarifyingQuestions: rewards responses with questions", () => {
    expect(scoreAskedClarifyingQuestions("What do you mean?")).toBe(1.0);
    expect(scoreAskedClarifyingQuestions("Here is the answer.")).toBe(0.0);
  });

  it("scoreFollowedTDD: rewards test-before-implementation order", () => {
    const tddContent = "test_something()\n\nfunction doThing() {}";
    expect(scoreFollowedTDD(tddContent)).toBe(1.0);
  });

  it("scoreNoComments: penalises code blocks with comments", () => {
    const withComment = "```ts\n// this is a comment\nconst x = 1;\n```";
    expect(scoreNoComments(withComment)).toBe(0.0);
    const withoutComment = "```ts\nconst x = 1;\n```";
    expect(scoreNoComments(withoutComment)).toBe(1.0);
  });
});

describe("evalSkill", () => {
  it("returns zero interaction_count when skill has no interactions", () => {
    const result = evalSkill("unknown-skill");
    expect(result.interaction_count).toBe(0);
    expect(result.scores).toEqual([]);
  });

  it("returns scores for a skill with interactions", () => {
    const result = evalSkill("memory-memorize");
    expect(result.interaction_count).toBe(1);
    expect(result.scores.length).toBeGreaterThan(0);
    expect(result.avg).toBeGreaterThanOrEqual(0);
    expect(result.avg).toBeLessThanOrEqual(1);
  });
});
