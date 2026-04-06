---
name: growth-reflect
description: Weekly evidence-gathering reflection session — searches installed providers for progress against your growth goals, presents findings for curation, then writes Obsidian-compatible progress files
---

# Growth Reflect — Weekly Progress Session

Guided reflection on progress against your growth goals. Searches multiple sources for evidence, presents findings organized by goal and success signal, then pauses for you to curate and reflect before writing anything.

## Arguments

- No argument: covers the last 7 days
- `<days>`: covers the last N days (e.g., `/growth-reflect 14`)

## Setup

Read `workspace.json` from the workspace root. Extract:
- `[DOCS_PATH]` = `growth.docsPath` or default `docs/growth`
- `[DISABLED_SOURCES]` = `growth.disabledSources` or default `[]`

Detect installed providers by checking which sections exist in `workspace.json`:
- `[HAS_MESSAGING]` = true if `providers.messaging` or `slack` section exists
- `[HAS_GIT_HOSTING]` = true if `providers.git-hosting` or `github`/`gitlab` section exists
- `[GIT_HOST_TYPE]` = `"github"` if `github` section exists, `"gitlab"` if `gitlab` section exists
- `[HAS_TICKETS]` = true if `providers.ticket-management` or `jira`/`clickup` section exists
- `[TICKET_TYPE]` = `"jira"` if `jira` section exists, `"clickup"` if `clickup` section exists

MCP sources (not kraftwork providers) — detect by attempting a lightweight call:
- `[HAS_GMAIL]` = true if Gmail MCP tools are available
- `[HAS_GDRIVE]` = true if Google Drive MCP tools are available

`[HAS_LOCAL]` = always true.

Remove any source that appears in `[DISABLED_SOURCES]`.

If `workspace.json` is not found, look for `[DOCS_PATH]/goals/` by walking up from cwd. If neither is found, tell the user to run `/growth-init` first and stop.

Parse days argument:
```sh
DAYS="${1:-7}"
DATE_SINCE=$(date -v-${DAYS}d +%Y-%m-%d)
```

## Phase 1: Load Goals

Read all `.md` files from `[DOCS_PATH]/goals/` using the Read tool. For each goal file, extract:
- **Goal title** from the filename (strip `.md`, use as display name)
- **Success signals** from the "Success Signals" section
- **Practice descriptions** from the "What This Means in Practice" section
- **Search keywords** derived from the success signals and practice descriptions — pick the 3-4 most distinctive nouns and verbs per goal

Section detection must be fuzzy — match any of these formats (case-insensitive):
- `### Success Signals`, `**Success Signals**`, `**Success signals**`
- `### What This Means in Practice`, `**What this means in practice**`

If no goal files are found, tell the user to run `/growth-init` and stop.

Present to the user:

> **Goals loaded:**
> - [Goal Name] — N success signals
> - [Goal Name] — N success signals
>
> **Sources available:** [list of detected sources]
> **Sources disabled:** [list, or "none"]
>
> Searching the last {DAYS} days for evidence. This may take a moment.

## Phase 2: Gather Evidence

For each goal, search available sources using goal-specific keyword queries. Derive actual queries from the loaded goal files — do not use hardcoded search terms.

### Source: Messaging

**Skip if:** `[HAS_MESSAGING]` is false or `"slack"` in `[DISABLED_SOURCES]`.

Use the Slack MCP tool to search for messages in the date range:

```
mcp__claude_ai_Slack__slack_search_public_and_private
  query: "<goal keywords joined with OR> after:<DATE_SINCE>"
```

For each goal, construct a query combining its 3-4 most distinctive keywords with OR logic.

Example (derived from a goal about technical quality):
- `"architecture OR observability OR trade-off OR error-handling after:2026-03-30"`

Classify matching messages against the goal's success signals.

### Source: Git Hosting

**Skip if:** `[HAS_GIT_HOSTING]` is false or `"git-hosting"` in `[DISABLED_SOURCES]`.

**For GitHub (`[GIT_HOST_TYPE]` = `"github"`):**

```sh
gh api "search/issues?q=author:@me+type:pr+created:>=$DATE_SINCE&per_page=50"
```

For each PR, read the title and description. For PRs with review comments:
```sh
gh api "repos/[OWNER]/[REPO]/pulls/[NUMBER]/comments?per_page=20"
```

**For GitLab (`[GIT_HOST_TYPE]` = `"gitlab"`):**

```sh
USERNAME=$(glab api user | jq -r '.username')
glab api "merge_requests?scope=all&author_username=$USERNAME&created_after=$DATE_SINCE&state=all&per_page=50"
```

For MRs with discussions, extract `project_id` and `iid`:
```sh
glab api "projects/$PROJECT_ID/merge_requests/$MR_IID/notes?per_page=20"
```

Classify PRs/MRs against goals based on description content and discussion themes.

### Source: Ticket Management

**Skip if:** `[HAS_TICKETS]` is false or `"ticket-management"` in `[DISABLED_SOURCES]`.

**For Jira (`[TICKET_TYPE]` = `"jira"`):**

Use the Jira MCP tool:
```
mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql
  cloudId: <from workspace.json jira.cloudId>
  jql: "assignee = currentUser() AND updated >= '-[DAYS]d' ORDER BY updated DESC"
```

For each ticket, check status transitions and comments relevant to goal keywords.

**For ClickUp (`[TICKET_TYPE]` = `"clickup"`):**

Use the ClickUp MCP tools to search for tasks assigned to the user, updated within the date range. Classify against goal keywords.

### Source: Gmail

**Skip if:** `[HAS_GMAIL]` is false or `"gmail"` in `[DISABLED_SOURCES]`.

```
mcp__claude_ai_Gmail__gmail_search_messages
  query: "after:[DATE_SINCE_EPOCH] (meeting notes OR 1:1 OR standup OR retro OR <goal keywords>)"
```

Scan results for content relevant to loaded goals.

### Source: Google Drive

**Skip if:** `[HAS_GDRIVE]` is false or `"google-drive"` in `[DISABLED_SOURCES]`.

Search for documents modified in the date range using Google Drive MCP tools. Use goal-related keywords as search terms.

### Source: Local Workspace

**Skip if:** `"local"` in `[DISABLED_SOURCES]`.

Search local repositories for recent activity:

```sh
for repo in "[WORKSPACE]/sources"/*/; do
  git -C "$repo" log --author="$(git -C "$repo" config user.email)" --since="$DATE_SINCE" --oneline 2>/dev/null
done
```

Also check worktrees:
```sh
for wt in "[WORKSPACE]/tasks"/*/; do
  git -C "$wt" log --author="$(git -C "$wt" config user.email)" --since="$DATE_SINCE" --oneline 2>/dev/null
done
```

Check recently modified docs:
```sh
find "[WORKSPACE]/docs/plans" -name "*.md" -newermt "$DATE_SINCE" 2>/dev/null
find "[WORKSPACE]/docs/specs" -name "*.md" -newermt "$DATE_SINCE" 2>/dev/null
```

Check intel-store for recent learnings:
```sh
~/.claude/kraftwork-intel/cli query --recent $DAYS 2>/dev/null
```

If the intel CLI is not available, skip silently.

### Handling Unavailable Sources

For each source that fails or is not connected, log:

> **Warning: [Source] unavailable** — [reason]. Skipping.

Continue with remaining sources. The skill works with as few as one source available.

## Phase 3: Present Findings

Organize all gathered evidence by goal. For each goal, present:

```
## [Goal Name]

### Evidence Found

1. **[Source]** Brief description of the activity
   - *Success signal: [which success signal this maps to]*

2. **[Source]** Brief description
   - *Success signal: [mapping]*

### Gaps — no evidence found for:
- [Success signal with no matching evidence]
```

Present all goals, then **STOP**. Do not proceed to writing files.

Ask the user to curate, one goal at a time:

> **Ready for your input.** For each goal:
> 1. Which items should I dismiss?
> 2. Anything I missed that you want to add?
> 3. Write your reflection — what did you learn, what would you do differently, what's the trajectory?
>
> Let's start with **[first goal name]**.

Wait for the user to respond for each goal before moving to the next.

**IMPORTANT:** Do not generate reflections. The user writes these. You may prompt with guiding questions if the user is stuck:
- "What did you learn from [specific item]?"
- "How does this week compare to last?"
- "Any of the gaps worth addressing next week?"

But the words in the reflection are the user's.

After all goals are curated, confirm before writing:

> **Ready to write progress files.** Proceed?

## Phase 4: Write Progress Files

Only after the user confirms in Phase 3.

Determine the week date (Monday of the current week):

```sh
if [ "$(date +%u)" = "1" ]; then
  WEEK_DATE=$(date +%Y-%m-%d)
else
  WEEK_DATE=$(date -v-monday +%Y-%m-%d)
fi
```

Create the progress directory:

```sh
mkdir -p "[DOCS_PATH]/progress/$WEEK_DATE"
```

**Check for existing files first.** If `[DOCS_PATH]/progress/$WEEK_DATE/<goal-slug>.md` already exists, read it and ask the user:

> **Progress file already exists for [Goal Name] this week.** Append new evidence to the existing file, or replace it?

For each goal that has curated evidence, write a progress file using the Write tool.

**File:** `[DOCS_PATH]/progress/$WEEK_DATE/<goal-slug>.md`

Where `<goal-slug>` is the goal filename lowercased with spaces replaced by hyphens (e.g., "Software Craftsmanship" becomes "software-craftsmanship").

```markdown
# [Goal Name] — Week of [WEEK_DATE]

## Evidence
- **[Source]** Description of activity
  - *Success signal: [mapping]*
- **[Source]** Description
  - *Success signal: [mapping]*

## Reflection
[User's written reflection — copied verbatim from what they provided in Phase 3]
```

Only create a file for a goal if there is curated evidence. No empty files.

### Update Index

**File:** `[DOCS_PATH]/progress/index.md`

If the file exists, read it first. Check if a `## [WEEK_DATE]` section already exists:
- **If it exists:** update the section in place with the new/updated goal entries.
- **If it doesn't exist:** prepend the new week's entries at the top (after the `# Growth Progress` heading), keeping existing entries below.

If the file does not exist, create it.

Format:

```markdown
# Growth Progress

## [WEEK_DATE]
- [[<WEEK_DATE>/<goal-slug>|Goal Name]] — one-line summary of key evidence
- [[<WEEK_DATE>/<goal-slug>|Goal Name]] — one-line summary

## [PREVIOUS_WEEK_DATE]
- ...
```

Use Obsidian wikilink syntax. Newest entries first.

If the index file exists but is malformed (missing `# Growth Progress` heading or corrupted structure), warn the user and rebuild from all existing progress directories.

After writing all files:

> **Progress updated.**
> - Written: [list of files created/updated]
> - Index updated: `[DOCS_PATH]/progress/index.md`
>
> Next 1:1 prep: review the index for a quick update, or read individual goal files for detail.

## Error Handling

- **No workspace.json and no goals directory:** Tell user to run `/growth-init` and stop.
- **No evidence survives curation:** Inform the user. Do not create empty directories or files. This is itself a signal worth noting.
- **Source authentication failures:** Log the warning, skip the source, continue with others.
- **Date calculation on Linux:** Check `uname` first. On Linux, use `date -d "-${DAYS} days" +%Y-%m-%d` for `DATE_SINCE` and `date -d "last monday" +%Y-%m-%d` for `WEEK_DATE` instead of the macOS `-v` flag.
