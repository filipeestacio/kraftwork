import * as lancedb from "@lancedb/lancedb";
import { join } from "path";
import { dataDir } from "../metrics/db";
import { embed as defaultEmbed } from "./embed";

export interface QueryResult {
  id: string;
  content: string;
  category: string;
  project: string;
  created_at: number;
  _distance: number;
}

export async function query(
  terms: string,
  opts: { category?: string; project?: string; limit?: number },
  embedFn = defaultEmbed
): Promise<QueryResult[]> {
  const dir = join(dataDir(), "knowledge");
  const db = await lancedb.connect(dir);

  const tableNames = await db.tableNames();
  if (!tableNames.includes("knowledge")) return [];

  const tbl = await db.openTable("knowledge");
  const vector = await embedFn(terms);

  // superseded_by uses empty string "" as the sentinel for "not superseded"
  const conditions = ["superseded_by = ''"];
  if (opts.category) conditions.push(`category = '${opts.category}'`);
  if (opts.project) conditions.push(`project = '${opts.project}'`);

  const results = await tbl
    .vectorSearch(vector)
    .limit(opts.limit ?? 5)
    .where(conditions.join(" AND "))
    .toArray();

  return results as QueryResult[];
}
