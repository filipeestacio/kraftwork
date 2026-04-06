import { openDb } from "./db";

export interface SkillStat {
  skill_name: string;
  uses: number;
  last_used: number | null;
  avg_score: number | null;
}

export function report(opts: { skill?: string; days?: number }): SkillStat[] {
  const db = openDb();
  const since = opts.days != null ? Date.now() - opts.days * 86_400_000 : 0;

  let sql = `
    SELECT su.skill_name,
           COUNT(*)           AS uses,
           MAX(su.invoked_at) AS last_used,
           AVG(er.score)      AS avg_score
    FROM skill_uses su
    LEFT JOIN eval_results er ON er.skill_name = su.skill_name
    WHERE su.invoked_at > ?
  `;
  const params: unknown[] = [since];

  if (opts.skill) {
    sql += ` AND su.skill_name = ?`;
    params.push(opts.skill);
  }

  sql += ` GROUP BY su.skill_name ORDER BY uses DESC`;

  const result = db.query(sql).all(...params) as SkillStat[];
  db.close();
  return result;
}
