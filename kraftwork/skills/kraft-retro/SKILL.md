---
name: kraft-retro
description: Run a post-merge retrospective on a completed ticket. Reviews plan quality, MR feedback, and implementation to capture lessons.
---

# Workspace Retro - Post-Merge Retrospective

Analyze a completed ticket end-to-end — from plan through merge — and capture lessons learned.

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |
| `resolve-provider.sh` | Delegate to the configured git-hosting provider |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-retro/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-retro/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Locate Workspace and Validate Input

```sh
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
```

The ticket ID must be provided as an argument. If not provided, use AskUserQuestion to request it.

Validate:
```sh
TICKET_ID="<argument>"
if [ -z "$TICKET_ID" ]; then
  echo "Ticket ID required"
  exit 1
fi
```

### Step 2: Gather Local Artifacts

Check for each artifact and record whether it exists:

```sh
SPEC_FILE="$WORKSPACE/docs/specs/$TICKET_ID/spec.md"
TASKS_FILE="$WORKSPACE/docs/specs/$TICKET_ID/tasks.md"
DESIGN_DOC=$(find "$WORKSPACE/docs/plans" -maxdepth 1 -name "*$TICKET_ID*" -type f 2>/dev/null | head -1)
GROWTH_FILE="$WORKSPACE/docs/my-growth/My Development.md"
```

Read each file that exists using the Read tool. Missing artifacts are noted as gaps but do not block the retrospective.

### Step 3: Find Merge Requests

Use the configured git-hosting provider via provider delegation:

```sh
SEARCH_PRS=$(<scripts-dir>/resolve-provider.sh script git-hosting search-prs 2>/dev/null || echo "")
if [ -n "$SEARCH_PRS" ]; then
  MRS=$("$SEARCH_PRS" "$TICKET_ID")
fi
```

If no git-hosting provider is configured or search-prs is unavailable, proceed with local artifacts only.

If no MRs are found, inform the user and ask whether to proceed with local artifacts only via AskUserQuestion.

Select the primary MR — prefer merged state:

```sh
MR=$(echo "$MRS" | jq '[.[] | select(.state == "merged")] | first // first')
```

If multiple merged MRs exist, ask the user to choose via AskUserQuestion.

Extract from the selected MR:

```sh
IID=$(echo "$MR" | jq -r '.iid')
MR_URL=$(echo "$MR" | jq -r '.web_url')
MR_TITLE=$(echo "$MR" | jq -r '.title')
```

### Step 4: Gather MR Data

Fetch MR details, discussions, diff, and commits via provider delegation:

```sh
FETCH_PR=$(<scripts-dir>/resolve-provider.sh script git-hosting fetch-pr-details 2>/dev/null || echo "")
if [ -n "$FETCH_PR" ]; then
  PR_DATA=$("$FETCH_PR" "$IID")
  MR_DETAILS=$(echo "$PR_DATA" | jq '.details')
  MR_DISCUSSIONS=$(echo "$PR_DATA" | jq '.discussions')
  MR_CHANGES=$(echo "$PR_DATA" | jq '.changes')
  MR_COMMITS=$(echo "$PR_DATA" | jq '.commits')
fi
```

Extract key data points:

```sh
CREATED_AT=$(echo "$MR_DETAILS" | jq -r '.created_at')
MERGED_AT=$(echo "$MR_DETAILS" | jq -r '.merged_at')
COMMIT_COUNT=$(echo "$MR_COMMITS" | jq 'length')
FILES_CHANGED=$(echo "$MR_CHANGES" | jq '.changes | length')
```

For large diffs (>500 changed lines), summarize changed files by name and change size rather than reading full content:

```sh
echo "$MR_CHANGES" | jq -r '.changes[] | "\(.new_path) (+\(.diff | split("\n") | map(select(test("^\\+[^+]"))) | length)/-\(.diff | split("\n") | map(select(test("^-[^-]"))) | length))"'
```

### Step 5: Compute Metrics

**Days plan-to-merge:** Calculate from the earliest artifact date (spec file mtime, MR creation, or first commit) to the merge date.

```sh
FIRST_COMMIT_DATE=$(echo "$MR_COMMITS" | jq -r '.[-1].created_at')
MERGE_DATE=$(echo "$MR_DETAILS" | jq -r '.merged_at')
```

If a design doc was found, use its filename date (YYYY-MM-DD prefix) as the plan start date instead of the first commit date. Compute the delta in days — on macOS use `date -j`, on Linux use `date -d`. The calculation is approximate and that is fine.

**Review rounds:** Count distinct push events by looking at commits grouped after MR creation, or count diff versions from discussion timestamps.

```sh
REVIEW_ROUNDS=$(echo "$MR_DISCUSSIONS" | jq '[.[] | .notes[0] | select(.system == true and (.body | test("added \\d+ commit"))) ] | length + 1')
```

**Comment count:** Total non-system notes across all discussions.

```sh
COMMENT_COUNT=$(echo "$MR_DISCUSSIONS" | jq '[.[] | .notes[] | select(.system == false)] | length')
```

**Pushback threads:** Discussions where a reviewer's comment led to code changes or extended back-and-forth (3+ notes in a thread, or threads containing words like "should", "instead", "why not", "concern", "suggestion").

```sh
PUSHBACK_THREADS=$(echo "$MR_DISCUSSIONS" | jq '[.[] | select((.notes | length) >= 3 or (.notes | any(.body | test("should|instead|why not|concern|suggest"; "i"))))] | length')
```

### Step 6: Qualitative Analysis

Analyze across five dimensions using all gathered artifacts:

**Plan vs Reality**
Compare the spec and task plan against the actual MR diff. Look for:
- Tasks that were planned but not implemented
- Work that was done but not in any plan
- Assumptions in the spec that proved wrong
- Estimation accuracy (if task plan had estimates)

**Growth & Development**
Read `$WORKSPACE/docs/my-growth/My Development.md` to understand current objectives. Assess this ticket against the specific goals documented there — reference them by name (e.g., "Software Craftsmanship objective", "backend mastery", "Conversation Service deep dive"). Evaluate:
- Did this work build toward the senior bar? Which competencies specifically?
- Were architectural decisions documented with trade-offs and rationale?
- Did any reusable patterns or standards emerge that others can follow?
- What would a senior engineer have done differently here?
- Was there deep engagement with legacy code or system complexity?

**Review Friction**
Examine MR discussions for:
- Threads with the most back-and-forth
- Patterns in reviewer feedback (naming, architecture, testing, edge cases)
- Whether pushback led to better code or was unnecessary churn
- Reference specific discussion threads by quoting key points

**Scope Management**
Assess whether scope stayed controlled:
- Did the MR touch files outside the planned scope?
- Were there follow-up MRs or TODOs created?
- Was anything descoped during review?

**Patterns Worth Extracting**
Identify reusable insights:
- Code patterns that worked well and should be repeated
- Approaches that caused problems and should be avoided
- Testing strategies that proved valuable
- Architectural decisions worth documenting

### Step 7: Write Lesson Doc

Write the retrospective to `$WORKSPACE/docs/lessons/$TICKET_ID-retro.md` using the Write tool:

```markdown
# $TICKET_ID Retrospective: <MR title>

**Date:** <today>
**MR:** <MR URL>
**Repo:** <repo name>

## Metrics
| Metric | Value |
|--------|-------|
| Days plan-to-merge | <value> |
| Commits | <value> |
| Review rounds | <value> |
| Comments | <value> |
| Pushback threads | <value> |
| Files changed | <value> |

## Artifacts
- Spec: <found/missing>
- Task plan: <found/missing>
- Design doc: <found/missing — filename if found>

## Plan vs Reality
<analysis>

## Growth & Development
<assessment against specific objectives from My Development.md>

## Review Friction
<analysis with specific thread references>

## Scope Management
<analysis>

## Patterns Worth Extracting
<actionable patterns>

## Reflection Questions
1. <question>
2. <question>
3. <question>
```

### Step 8: Store Key Learnings

Extract 1-3 concrete learnings from the analysis. Each learning should be a single actionable insight, not a vague observation.

For each learning, run:
```sh
bun run ~/.claude/kraftwork-intel/src/cli.ts store \
  --category "<architecture|pattern|convention|debugging>" \
  --project "<repo-name>" \
  --content "<1-3 sentence learning>"
```

If the kraftwork-intel CLI is not installed or the store command fails, skip this step and note "Intel-store: unavailable" in the output.

Choose the category that best fits each learning:
- **architecture** — structural decisions, service boundaries, data flow
- **pattern** — reusable code patterns, testing approaches
- **convention** — team norms, style, naming
- **debugging** — troubleshooting techniques, failure modes

### Step 9: Present Reflection Questions

Present 2-3 reflection questions derived from the analysis. These must be specific to what was found — not generic templates.

Good: "The reviewer flagged three naming inconsistencies — what naming convention would have prevented all three?"
Bad: "What could you improve next time?"

Present the questions to the user. User answers are not captured — the questions exist to prompt thinking.

## Handling Edge Cases

1. **No MRs found** — Proceed with local artifacts only. Skip MR-dependent metrics and analysis. Note the gap in the output.
2. **MR not yet merged** — Warn the user and ask whether to proceed via AskUserQuestion. Use current date instead of merge date for time calculations.
3. **No local artifacts** — Proceed with MR data only. The Plan vs Reality section becomes "No plan artifacts found — this is itself an observation."
4. **Multiple MRs** — Analyze the primary MR in depth. List others in the Artifacts section with their URLs.
5. **Large diffs** — For MRs with >500 changed lines, summarize by file (path + lines added/removed) instead of reading full diffs. Focus qualitative analysis on the files most discussed in review threads.
6. **No git-hosting provider** — If `resolve-provider.sh` returns empty or errors, skip all MR fetching and proceed with local artifacts only. Note "Git-hosting provider: unavailable" in the output.
