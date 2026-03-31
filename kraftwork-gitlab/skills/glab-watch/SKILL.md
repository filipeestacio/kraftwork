---
name: glab-watch
description: Monitor an MR for pipeline failures and review comments, diagnose issues, and propose fixes until merged. Use after creating/pushing an MR.
---

# GitLab MR Watch

Monitor a merge request continuously via Ralph Loop. Polls for pipeline failures and unresolved discussion threads, diagnoses issues, proposes fixes, and detects when the MR is ready to merge.

## Dependencies

- `glab` CLI (authenticated)
- Ralph Loop plugin (`/ralph-loop` command available)
- `jq`

## Input

Optional: MR identifier — a URL, `!123`, or omitted (infers from current branch).

Examples: `/glab-watch`, `/glab-watch !123`, `/glab-watch https://gitlab.com/.../merge_requests/123`

## Script Path

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork-gitlab/skills/glab-watch/SKILL.md`
- Plugin root: 3 directories up from this file
- Scripts directory: `<plugin-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory.

## Initialization

### Step 1: Auth Check

```bash
glab auth status 2>&1
```

If not authenticated, STOP and suggest `glab auth login`.

### Step 2: Resolve MR IID

If an argument was provided:
- URL: extract the IID from the last path segment (`.../merge_requests/123` → `123`)
- `!123`: strip the `!` prefix → `123`

If no argument:
```bash
glab mr view --json iid -q .iid 2>/dev/null
```

If no MR found for current branch, STOP:
```
No MR found for current branch. Push your branch and create an MR first.
```

### Step 3: Validate MR is open

```bash
glab mr view <IID> --json state -q .state
```

If state is `merged`, report "MR already merged" and STOP.
If state is `closed`, report "MR is closed" and STOP.

### Step 4: Extract ticket ID and branch

```bash
BRANCH=$(git branch --show-current)
```

Extract ticket ID from branch name (e.g., `feat/MES-3874/description` → `MES-3874`). This prefixes commit messages for fixes.

### Step 5: Enter Ralph Loop

Run the following command to start the watch loop:

```
/ralph-loop <WATCH_PROMPT> --completion-promise 'MR watch complete'
```

Where `<WATCH_PROMPT>` is the iteration prompt below, with `<IID>`, `<TICKET_ID>`, and `<SCRIPTS_DIR>` substituted with actual values.

---

## Iteration Prompt

This is the prompt that gets fed to Ralph Loop. Substitute `{IID}`, `{TICKET_ID}`, `{BRANCH}`, and `{SCRIPTS_DIR}` before passing to `/ralph-loop`.

---

You are monitoring MR !{IID} on branch `{BRANCH}`. Your job: check for pipeline failures and review comments, diagnose them, propose fixes, and detect when the MR is ready to merge.

**Each iteration, follow these steps exactly:**

### 1. Poll status

```bash
{SCRIPTS_DIR}/mr-status.sh {IID}
```

Parse the JSON output.

### 2. Check exit conditions

**If `merged` is true:**
The MR has been merged externally. Output:
```
MR !{IID} has been merged.
<promise>MR watch complete</promise>
```

**If the MR state is `closed` (not merged):**
The MR was abandoned. Output:
```
MR !{IID} was closed without merging.
<promise>MR watch complete</promise>
```

### 3. Check ready to merge

**If `ready_to_merge` is true:**
```
MR !{IID} is ready to merge:
  Pipeline: passed
  Approvals: {current}/{required}
  Unresolved threads: 0

Merge it now?
```

Wait for user response:
- If yes: run `glab mr merge {IID}`, then output `<promise>MR watch complete</promise>`
- If no: continue to the status line and sleep

### 4. Handle pipeline failures

**If `pipeline.status` is `failed`:**

For each job in `pipeline.failed_jobs`:
1. Fetch the job log:
   ```bash
   glab ci trace {JOB_NAME}
   ```
   Focus on the last 80 lines and lines containing error/Error/ERROR/FATAL/failed/FAILED.

2. Read the relevant source files to understand context.

3. Diagnose the root cause — explain what failed and why.

4. Propose a fix: show the exact edit using the Edit tool. Wait for user approval.

5. On approval, commit:
   ```bash
   git add <changed-files>
   git commit -m "{TICKET_ID} fix: <description of what was fixed>"
   ```

6. After committing, show unpushed commit count:
   ```bash
   git rev-list --count origin/{BRANCH}..HEAD
   ```
   Remind: "X unpushed commit(s). Push when ready with `git push`."

Handle failed jobs sequentially.

### 5. Handle unresolved threads

**If `threads.unresolved` is non-empty:**

For each unresolved thread:
1. Show the comment: author, body, file, and line number.

2. If a file and line are referenced, read that file around the referenced line to understand context.

3. Diagnose what the reviewer or bugbot is asking for.

4. Propose a fix: show the exact edit using the Edit tool. Wait for user approval.

5. On approval, commit:
   ```bash
   git add <changed-files>
   git commit -m "{TICKET_ID} fix: <description of what was fixed>"
   ```

6. After committing, show unpushed commit count:
   ```bash
   git rev-list --count origin/{BRANCH}..HEAD
   ```
   Remind: "X unpushed commit(s). Push when ready with `git push`."

Handle threads sequentially.

### 6. Status line and sleep

Print a status summary:
```
[glab-watch] Pipeline: {status} | Threads: {unresolved_count} unresolved | Approvals: {current}/{required} | Unpushed: {unpushed_count} commits
```

Where:
- Pipeline status: `passed`, `failed`, `running`, `pending`, or `none`
- Unpushed count from: `git rev-list --count origin/{BRANCH}..HEAD`

Then sleep for 5 minutes:
```bash
sleep 300
```

After sleeping, exit so Ralph Loop feeds the prompt back for the next iteration.

---

## Error Handling

- **mr-status.sh fails (exit code 1):** Print the error, sleep 300 seconds, and exit to retry next iteration. Do not break the loop.
- **Auth expired mid-loop:** Print "GitLab auth may have expired. Run `glab auth login` in another terminal." Sleep and retry.
- **No pipeline found (pipeline is null):** Report "No pipeline found" in the status line. This is normal if the branch hasn't been pushed yet or CI hasn't triggered.
