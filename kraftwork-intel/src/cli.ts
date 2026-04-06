#!/usr/bin/env bun

import { report } from "./metrics/report";
import { store } from "./knowledge/store";
import { query } from "./knowledge/query";
import { evalSkill, evalAll, evalFlagged } from "./evals/runner";
import { handleSessionStart } from "./hooks/session-start";
import { handleUserPrompt } from "./hooks/user-prompt";
import { handlePostTool } from "./hooks/post-tool";
import { handleStop } from "./hooks/stop";

const args = process.argv.slice(2);
const command = args[0];
const rest = args.slice(1);

function flag(name: string): string | undefined {
  const idx = rest.indexOf(`--${name}`);
  return idx !== -1 && rest[idx + 1] !== undefined ? rest[idx + 1] : undefined;
}

function hasFlag(name: string): boolean {
  return rest.includes(`--${name}`);
}

switch (command) {
  case "store": {
    const content = flag("content");
    const category = flag("category");
    const project = flag("project");
    if (!content || !category || !project) {
      console.error("Usage: cli.ts store --content <text> --category <cat> --project <proj> [--supersedes <id>]");
      process.exit(1);
    }
    const id = await store({ content, category, project, supersedes: flag("supersedes") });
    console.log(JSON.stringify({ id }));
    break;
  }

  case "query": {
    const terms = rest[0];
    if (!terms || terms.startsWith("--")) {
      console.error("Usage: cli.ts query <terms> [--category <cat>] [--project <proj>] [--limit N]");
      process.exit(1);
    }
    const limitStr = flag("limit");
    const results = await query(terms, {
      category: flag("category"),
      project: flag("project"),
      limit: limitStr ? parseInt(limitStr, 10) : undefined,
    });
    console.log(JSON.stringify(results, null, 2));
    break;
  }

  case "report": {
    const daysStr = flag("days");
    const stats = report({
      skill: flag("skill"),
      days: daysStr ? parseInt(daysStr, 10) : undefined,
    });
    console.log(JSON.stringify(stats, null, 2));
    break;
  }

  case "eval": {
    const target = rest[0];
    let summaries;
    if (hasFlag("all")) {
      summaries = evalAll();
    } else if (hasFlag("flagged")) {
      summaries = evalFlagged();
    } else if (target && !target.startsWith("--")) {
      summaries = [evalSkill(target)];
    } else {
      console.error("Usage: cli.ts eval <skill> | --all | --flagged");
      process.exit(1);
    }
    console.log(JSON.stringify(summaries, null, 2));
    break;
  }

  case "hook": {
    const hookType = rest[0];
    const raw = await Bun.stdin.text();
    const event = JSON.parse(raw);
    switch (hookType) {
      case "session-start": handleSessionStart(event); break;
      case "user-prompt":   handleUserPrompt(event);   break;
      case "post-tool":     handlePostTool(event);      break;
      case "stop":          handleStop(event);           break;
      default:
        console.error(`Unknown hook type: ${hookType} (ignored)`);
    }
    process.exit(0);
    break;
  }

  case "check": {
    let ok = true;

    // bun version
    const [major, minor] = Bun.version.split(".").map(Number);
    if (major > 1 || (major === 1 && minor >= 3)) {
      console.log(`✓ bun ${Bun.version}`);
    } else {
      console.error(`✗ bun ${Bun.version} — requires >= 1.3`);
      ok = false;
    }

    // LanceDB
    try {
      await import("@lancedb/lancedb");
      console.log("✓ @lancedb/lancedb");
    } catch {
      console.error("✗ @lancedb/lancedb not found — run: bun install");
      ok = false;
    }

    // Ollama (optional)
    try {
      const ollama = Bun.spawnSync(["ollama", "list"], { stdout: "pipe", stderr: "pipe" });
      if (ollama.exitCode === 0) {
        const out = new TextDecoder().decode(ollama.stdout);
        if (out.includes("llama3.2:3b")) {
          console.log("✓ ollama llama3.2:3b");
        } else {
          console.log("~ ollama installed, llama3.2:3b not found — run: ollama pull llama3.2:3b");
        }
      } else {
        console.log("~ ollama not installed — LLM scoring unavailable (optional)");
      }
    } catch {
      console.log("~ ollama not installed — LLM scoring unavailable (optional)");
    }

    if (!ok) process.exit(1);
    break;
  }

  default:
    console.error(`Unknown command: ${command ?? "(none)"}`);
    console.error("Commands: store, query, report, eval, hook, check");
    process.exit(1);
}
