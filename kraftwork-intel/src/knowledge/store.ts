import * as lancedb from "@lancedb/lancedb";
import { mkdirSync } from "fs";
import { join } from "path";
import { randomUUID } from "crypto";
import { dataDir } from "../metrics/db";
import { embed as defaultEmbed } from "./embed";

function escapeSql(val: string): string {
  return val.replace(/'/g, "''");
}

export interface KnowledgeRecord {
  id: string;
  content: string;
  category: string;
  project: string;
  vector: number[];
  created_at: number;
  superseded_by: string;
}

function knowledgeDir(): string {
  const dir = join(dataDir(), "knowledge");
  mkdirSync(dir, { recursive: true });
  return dir;
}

export async function store(
  opts: { content: string; category: string; project: string; supersedes?: string },
  embedFn = defaultEmbed
): Promise<string> {
  const db = await lancedb.connect(knowledgeDir());
  const vector = await embedFn(opts.content);
  const id = randomUUID();
  const record: KnowledgeRecord = {
    id,
    content: opts.content,
    category: opts.category,
    project: opts.project,
    vector,
    created_at: Date.now(),
    // Use empty string as sentinel for "not superseded" since LanceDB
    // may have trouble with null in schema inference
    superseded_by: "",
  };

  const tableNames = await db.tableNames();
  if (tableNames.includes("knowledge")) {
    const tbl = await db.openTable("knowledge");
    await tbl.add([record]);
    if (opts.supersedes) {
      await tbl.update({
        values: { superseded_by: id },
        where: `id = '${escapeSql(opts.supersedes)}'`,
      });
    }
  } else {
    const tbl = await db.createTable("knowledge", [record]);
    if (opts.supersedes) {
      await tbl.update({
        values: { superseded_by: id },
        where: `id = '${escapeSql(opts.supersedes)}'`,
      });
    }
  }

  return id;
}
