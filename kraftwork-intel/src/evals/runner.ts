import { openDb } from "../metrics/db";
import { randomUUID } from "crypto";

export interface EvalScore {
  scorer: string;
  score: number;
}

export interface EvalSummary {
  skill_name: string;
  interaction_count: number;
  scores: EvalScore[];
  avg: number;
}

export function scoreResponseLength(content: string): number {
  const len = content.length;
  if (len < 50) return 0.2;
  if (len < 200) return 0.5;
  if (len > 8000) return 0.7;
  return 1.0;
}

export function scoreAskedClarifyingQuestions(content: string): number {
  return (content.match(/\?/g) ?? []).length >= 1 ? 1.0 : 0.0;
}

export function scoreFollowedTDD(content: string): number {
  const testIdx = content.search(/\btest_\w+|describe\(|it\(|beforeEach\(/);
  const implIdx = content.search(/\bfunction \w+|\bclass \w+|\bconst \w+ = /);
  if (testIdx === -1 || implIdx === -1) return 0.5;
  return testIdx < implIdx ? 1.0 : 0.0;
}

export function scoreNoComments(content: string): number {
  const codeBlocks = [...content.matchAll(/```[\s\S]*?```/g)].map((m) => m[0]);
  if (codeBlocks.length === 0) return 1.0;
  return codeBlocks.some((b) => /\/\/|#\s/.test(b)) ? 0.0 : 1.0;
}

const SCORERS: Record<string, (content: string) => number> = {
  responseLength: scoreResponseLength,
  askedClarifyingQuestions: scoreAskedClarifyingQuestions,
  followedTDD: scoreFollowedTDD,
  noComments: scoreNoComments,
};

export function evalSkill(skillName: string): EvalSummary {
  const db = openDb();

  const interactions = db
    .query(`
      SELECT i.content
      FROM interactions i
      JOIN skill_uses su ON su.session_id = i.session_id
      WHERE su.skill_name = ? AND i.role = 'assistant'
      ORDER BY i.created_at DESC
      LIMIT 50
    `)
    .all(skillName) as { content: string }[];

  if (interactions.length === 0) {
    db.close();
    return { skill_name: skillName, interaction_count: 0, scores: [], avg: 0 };
  }

  const totals: Record<string, number> = {};
  for (const { content } of interactions) {
    for (const [name, fn] of Object.entries(SCORERS)) {
      totals[name] = (totals[name] ?? 0) + fn(content);
    }
  }

  const scores: EvalScore[] = Object.entries(totals).map(([scorer, total]) => ({
    scorer,
    score: total / interactions.length,
  }));

  const avg = scores.reduce((s, e) => s + e.score, 0) / scores.length;
  const now = Date.now();

  for (const { scorer, score } of scores) {
    db.run(
      "INSERT INTO eval_results (id, skill_name, scorer, score, ran_at) VALUES (?, ?, ?, ?, ?)",
      [randomUUID(), skillName, scorer, score, now]
    );
  }

  db.close();
  return { skill_name: skillName, interaction_count: interactions.length, scores, avg };
}

export function evalAll(): EvalSummary[] {
  const db = openDb();
  const skills = db
    .query("SELECT DISTINCT skill_name FROM skill_uses")
    .all() as { skill_name: string }[];
  db.close();
  return skills.map(({ skill_name }) => evalSkill(skill_name));
}

export function evalFlagged(): EvalSummary[] {
  return evalAll().filter((s) => s.avg < 0.7);
}
