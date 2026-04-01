---
name: kraft-plan
description: Orchestrate planning for a ticket. Creates specs directly during planning phase, or tracked change records once implementation has started. Use after kraft-work.
---

# Workspace Plan - Planning Workflow

Orchestrate the planning phase for a ticket, using the centralized specs directory to keep code directories clean.

## Architecture

- **Worktrees:** `[WORKSPACE]/trees/TICKET-123/` - Clean code only
- **Specs:** `[WORKSPACE]/docs/specs/TICKET-123/` - All planning artifacts
- **Modules:** `[WORKSPACE]/modules/` - Read-only repos for pattern discovery

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-plan/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-plan/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Validate Environment

Verify we're in a valid worktree:

```sh
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)

# Check if in a trees directory
case "$WORKTREE_PATH" in
  */trees/*)
    echo "Worktree: $WORKTREE_PATH"
    ;;
  *)
    echo "Not in a worktree. Run /kraft-work first."
    exit 1
    ;;
esac
```

### Step 2: Extract Context

```sh
TICKET_ID=$(basename "$WORKTREE_PATH" | grep -oE '^[A-Z]+-[0-9]+')

if [ -z "$TICKET_ID" ]; then
  TICKET_ID=$(basename "$WORKTREE_PATH")
fi

WORKSPACE=$(<scripts-dir>/find-workspace.sh)
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"

echo "Ticket: $TICKET_ID"
echo "Workspace: $WORKSPACE"
echo "Spec directory: $SPEC_DIR"
```

### Step 3: Check Planning State

```sh
mkdir -p "$SPEC_DIR"

# Check if implementation has started (tasks.md exists)
if [ -f "$SPEC_DIR/tasks.md" ]; then
  IMPL_STARTED=true
  echo "Implementation in progress. Modifications will be tracked as changes."
else
  IMPL_STARTED=false
  echo "Planning phase. Direct spec edits allowed."
fi

# Check for existing spec
if [ -f "$SPEC_DIR/spec.md" ]; then
  echo "Found existing spec at $SPEC_DIR/spec.md"
fi
```

### Step 3a: Change Creation Flow (If Implementation Started)

If `IMPL_STARTED=true`, create a change record instead of editing spec directly.

**Ask what changed:**
```
What modification do you want to make to the spec?
```

Use AskUserQuestion or direct conversation to understand the change.

**Brainstorm the change:**

Apply the same brainstorming approach, but scoped to just this delta:
- What's the reason for this change?
- What spec sections are affected?
- What new tasks are needed?

**Ask impact type:**

```
How does this change impact implementation?

1. Additive - New requirements/tasks, existing work unaffected
2. Blocking - Must pause implementation until resolved
3. Replacing - Affects already-completed work that may need revisiting
```

Use AskUserQuestion with these three options.

**Generate change number:**

```sh
CHANGES_DIR="$SPEC_DIR/changes"
mkdir -p "$CHANGES_DIR"

LAST_NUM=$(ls "$CHANGES_DIR" 2>/dev/null | grep -E '^[0-9]{3}-' | sort -r | head -1 | grep -oE '^[0-9]{3}' || echo "000")
NEXT_NUM=$(printf "%03d" $((LAST_NUM + 1)))

echo "Next change number: $NEXT_NUM"
```

**Create change slug:**

```sh
CHANGE_TITLE="Add retry logic"  # From user input
SLUG=$(echo "$CHANGE_TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)
CHANGE_FILE="$CHANGES_DIR/${NEXT_NUM}-${SLUG}.md"

echo "Change file: $CHANGE_FILE"
```

**Write change record:**

Create the change file with appropriate content based on brainstorming results.

**Update index.md:**

```sh
INDEX_FILE="$CHANGES_DIR/index.md"

# Create index if it doesn't exist
if [ ! -f "$INDEX_FILE" ]; then
  cat > "$INDEX_FILE" << 'EOF'
# Changes Index

| # | Name | Status | Impact | Date |
|---|------|--------|--------|------|
EOF
fi

# Append new change entry
echo "| $NEXT_NUM | $CHANGE_TITLE | pending | $IMPACT_TYPE | $(date +%Y-%m-%d) |" >> "$INDEX_FILE"

echo "Updated index at $INDEX_FILE"
```

**Skip to Step 7a** (change completion output) instead of normal planning flow.

### Step 4: Invoke Brainstorming

**IMPORTANT:** This skill integrates with `superpowers:brainstorming` for the requirement shaping process.

Invoke the brainstorming skill to explore and refine the idea:

```
Invoke superpowers:brainstorming with context:

- Ticket: $TICKET_ID
- Worktree: $WORKTREE_PATH
- Spec directory: $SPEC_DIR
- Modules available at: $WORKSPACE/modules/ (for pattern discovery)

The brainstorming output should be saved to:
- $SPEC_DIR/idea.md - Initial idea capture
- $SPEC_DIR/spec.md - Refined specification
```

The brainstorming skill will:
1. Ask questions to understand the feature
2. Explore existing patterns in `modules/`
3. Present design options with trade-offs
4. Build the specification incrementally

### Step 5: MR Decomposition

After brainstorming produces a spec, decompose the work into MR-sized increments **before** writing tasks.

**Size targets (from industry best practices):**
- Each MR should be **under 200 lines changed**
- Touch **fewer than 10 files**
- Address **a single concern** (one feature slice, one refactor, one data model change)
- Be **independently mergeable to main** without breaking staging

**How to decompose:**

1. Read the spec and identify the logical layers of change (data model, business logic, API, UI, tests)
2. Group these into MRs where each MR is a self-contained, shippable increment
3. Order MRs so each builds on the previous — later MRs may depend on earlier ones being merged
4. Verify each MR leaves the system in a working state — no half-wired features, no broken imports

**Present the MR plan to the user for approval before writing tasks:**

```
MR Decomposition for $TICKET_ID:

MR1: [short title] (~estimated lines, ~N files)
  - What it does
  - Why it's safe to merge independently

MR2: [short title] (~estimated lines, ~N files)
  - What it does
  - Depends on: MR1

MR3: ...
```

If the entire ticket fits in one MR (<200 lines, <10 files), say so — don't split for the sake of splitting.

If the ticket requires stacked branches (MR2 depends on MR1), note that `/kraft-work` (stacking mode) will be used during implementation.

**Get user approval on the MR plan before proceeding to Step 6.**

### Step 6: Create Tasks List

After the MR decomposition is approved, create the implementation task list:

```sh
if [ ! -f "$SPEC_DIR/spec.md" ]; then
  echo "Spec not found. Complete brainstorming first."
  exit 1
fi
```

Analyze the spec and create `$SPEC_DIR/tasks.md`, organizing tasks under MR headings:

```markdown
# Implementation Tasks for $TICKET_ID

## Overview
Brief summary of what needs to be built.

## MR1: [title]
Target: ~N lines, ~N files. Independently mergeable.

- [ ] Task 1 description
- [ ] Task 2 description
- [ ] Tests for MR1 scope

## MR2: [title]
Target: ~N lines, ~N files. Depends on MR1.

- [ ] Task 3 description
- [ ] Task 4 description
- [ ] Tests for MR2 scope

## MR3: [title] (if needed)
...

## Verification
How to verify the full feature is complete after all MRs merge:
- [ ] Unit tests pass
- [ ] Integration test scenarios
- [ ] Manual verification steps
```

### Step 7: Output Completion

```
Planning complete for $TICKET_ID

Spec Directory: $SPEC_DIR
  ├── idea.md     - Initial idea capture
  ├── spec.md     - Full specification
  └── tasks.md    - Implementation checklist

Next steps:
1. Review the spec: cat "$SPEC_DIR/spec.md"
2. Review tasks: cat "$SPEC_DIR/tasks.md"
3. Start implementation: /kraft-implement
```

### Step 7a: Change Completion Output (If Change Created)

If a change record was created (not normal planning), output:

```
Change recorded for $TICKET_ID

Change: $CHANGES_DIR/${NEXT_NUM}-${SLUG}.md
   Status: pending
   Impact: $IMPACT_TYPE

Pending changes: $(grep -c '| pending |' "$INDEX_FILE" || echo 0)

Next steps:
1. Review change: cat "$CHANGE_FILE"
2. Apply changes: /kraft-implement
3. Add more changes: /kraft-plan
```

Then exit (do not continue to normal spec creation flow).

## Integration with Modules

During brainstorming, use the `modules/` directory for context:

```sh
# Search for similar patterns
grep -r "pattern_name" "$WORKSPACE/modules/" --include="*.ts"

# Find related components
find "$WORKSPACE/modules/" -name "*ComponentName*"

# Read existing implementations
cat "$WORKSPACE/modules/repo-name/src/path/to/file.ts"
```

This helps ensure new code follows existing patterns and conventions.

## Spec File Formats

### idea.md
```markdown
# $TICKET_ID - Feature Name

## Summary
One-paragraph description from the ticket or user.

## Initial Requirements
- Requirement 1
- Requirement 2

## Open Questions
- Question 1?
- Question 2?

## Notes
Any additional context captured during initial discussion.
```

### spec.md
```markdown
# $TICKET_ID - Feature Name

## Overview
Detailed description of what will be built.

## Requirements
### Functional Requirements
1. FR1: Description
2. FR2: Description

### Non-Functional Requirements
1. NFR1: Performance/scale considerations
2. NFR2: Security considerations

## Design
### Architecture
How this fits into the existing system.

### Components
What new components/modules will be created.

### Data Flow
How data moves through the system.

### API Changes
Any API additions or modifications.

## Edge Cases
- Edge case 1 and how it's handled
- Edge case 2 and how it's handled

## Testing Strategy
- Unit test approach
- Integration test scenarios
- Manual QA steps

## Rollout Plan
How this will be deployed/enabled.
```

### tasks.md
```markdown
# Tasks for $TICKET_ID

## Status Legend
- [ ] Not started
- [x] Complete
- [~] In progress
- [-] Blocked/Skipped

## Tasks

### 1. Setup
- [ ] Create new module structure
- [ ] Add dependencies

### 2. Implementation
- [ ] Implement core logic
- [ ] Add API endpoints
- [ ] Create UI components

### 3. Testing
- [ ] Write unit tests
- [ ] Write integration tests
- [ ] Manual QA

### 4. Documentation
- [ ] Update README
- [ ] Add inline comments

## Notes
Any implementation notes or decisions made during development.
```

## Reverting Changes

If invoked with `--revert NNN` argument (e.g., `/kraft-plan --revert 001`):

### Revert Workflow

**1. Validate the change exists and is applied:**

```sh
REVERT_NUM="$1"  # From argument
CHANGE_FILE=$(ls "$CHANGES_DIR" | grep "^${REVERT_NUM}-" | head -1)

if [ -z "$CHANGE_FILE" ]; then
  echo "Change $REVERT_NUM not found"
  exit 1
fi

STATUS=$(grep '^\*\*Status:\*\*' "$CHANGES_DIR/$CHANGE_FILE" | awk '{print $2}')
if [ "$STATUS" != "applied" ]; then
  echo "Change $REVERT_NUM is not applied (status: $STATUS)"
  exit 1
fi
```

**2. Read the spec delta:**

Parse the Spec Delta section from the change file to understand what was added/modified.

**3. Reverse the delta:**

Use the Edit tool to reverse the changes made to spec.md.

**4. Handle affected tasks:**

```sh
AFFECTED_TASKS=$(grep "(from change $REVERT_NUM)" "$TASKS_FILE" || echo "")

if [ -n "$AFFECTED_TASKS" ]; then
  echo "The following tasks were added by this change:"
  echo "$AFFECTED_TASKS"
fi
```

Use AskUserQuestion to decide whether to remove or keep affected tasks.

**5. Update statuses:**

Update change file status to "reverted" and update index.md accordingly.

**6. Confirm:**

```
Reverted change $REVERT_NUM: $CHANGE_TITLE
   - Spec delta reversed
   - Tasks: [removed/kept]
   - Changelog updated
```

## Error Handling

- **Not in worktree:** Guide user to run `/kraft-work`
- **Spec exists:** Ask if continuing or starting fresh
- **Brainstorming incomplete:** Save progress, allow resumption
