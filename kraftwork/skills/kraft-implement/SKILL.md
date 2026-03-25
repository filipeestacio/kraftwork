---
name: kraft-implement
description: Execute implementation from specs. Reviews and applies pending changes before showing tasks. Use after kraft-plan.
---

# Workspace Implement - Implementation Workflow

Execute implementation based on the spec and task list, with all code changes confined to the worktree.

## Architecture

- **Worktrees:** `[WORKSPACE]/tasks/TICKET-123/` - Where code changes happen
- **Specs:** `[WORKSPACE]/docs/specs/TICKET-123/` - Read-only planning artifacts
- **Sources:** `[WORKSPACE]/sources/` - Reference only, no modifications

## Key Constraints

1. **Worktree-only writes** - All code modifications confined to working directory
2. **Spec path reads** - Read planning artifacts from central docs/specs/ location
3. **No parent access** - Don't traverse to ../sources/ for writes
4. **Task tracking** - Mark tasks complete in docs/specs/TICKET/tasks.md

## Scripts Used

| Script | Purpose |
|--------|---------|
| `find-workspace.sh` | Locate workspace root |

## Script Paths

**IMPORTANT:** Derive the scripts directory from this skill file's location:
- This skill file: `kraftwork/skills/kraft-implement/SKILL.md`
- Workspace plugin root: 3 directories up from this file
- Scripts directory: `<workspace-root>/scripts/`

When you load this skill, note its file path and compute the scripts directory. For example, if this skill is at `/path/to/kraftwork/skills/kraft-implement/SKILL.md`, then scripts are at `/path/to/kraftwork/scripts/`.

## Workflow

### Step 1: Validate Environment

```sh
WORKTREE_PATH=$(git rev-parse --show-toplevel 2>/dev/null)

# Check if in a tasks directory
case "$WORKTREE_PATH" in
  */tasks/*)
    ;;
  *)
    echo "Not in a worktree. Run /kraft-start first."
    exit 1
    ;;
esac

# Extract context
TICKET_ID=$(basename "$WORKTREE_PATH" | grep -oE '^[A-Z]+-[0-9]+')
WORKSPACE=$(<scripts-dir>/find-workspace.sh)
SPEC_DIR="$WORKSPACE/docs/specs/$TICKET_ID"

echo "Ticket: $TICKET_ID"
echo "Worktree: $WORKTREE_PATH"
echo "Spec directory: $SPEC_DIR"
```

### Step 2: Verify Spec Exists

```sh
TASKS_FILE="$SPEC_DIR/tasks.md"

if [ ! -f "$TASKS_FILE" ]; then
  echo "No tasks.md found at $TASKS_FILE"
  echo "Run /kraft-plan first to create the implementation plan."
  exit 1
fi

echo "Found tasks at: $TASKS_FILE"
```

### Step 2a: Check for Pending Changes

```sh
CHANGES_DIR="$SPEC_DIR/changes"
INDEX_FILE="$CHANGES_DIR/index.md"

if [ -f "$INDEX_FILE" ]; then
  PENDING_COUNT=$(grep -c '| pending |' "$INDEX_FILE" || echo 0)
else
  PENDING_COUNT=0
fi

if [ "$PENDING_COUNT" -gt 0 ]; then
  echo "$PENDING_COUNT pending change(s) found. Review required before implementation."
  HAS_PENDING=true
else
  HAS_PENDING=false
fi
```

If `HAS_PENDING=true`, proceed to Step 2b (interactive review) before showing tasks.

### Step 2b: Interactive Change Review (If Pending Changes)

If `HAS_PENDING=true`, review each pending change:

```sh
PENDING_CHANGES=$(grep '| pending |' "$INDEX_FILE" | awk -F'|' '{print $2}' | tr -d ' ')
```

**For each pending change:**

1. **Read the change file:**
   ```sh
   CHANGE_NUM="001"  # Current change being reviewed
   CHANGE_FILE=$(ls "$CHANGES_DIR" | grep "^${CHANGE_NUM}-" | head -1)
   cat "$CHANGES_DIR/$CHANGE_FILE"
   ```

2. **Present to user:**
   ```
   --- Change $CHANGE_NUM: $CHANGE_TITLE ---
   Impact: $IMPACT_TYPE
   Reason: $REASON

   Spec Delta:
   $SPEC_DELTA

   Task Impact:
   $TASK_IMPACT
   ```

3. **Ask for action:**
   Use AskUserQuestion with options:
   - **Apply** - Update spec.md, add tasks, mark applied
   - **Skip** - Mark as skipped, review later
   - **Modify** - Re-enter brainstorming for this change

4. **Handle response:**
   - **Apply:** Go to Step 2c (apply change)
   - **Skip:** Update index.md status to "skipped", continue to next change
   - **Modify:** Invoke brainstorming for this change, then return to review

Continue until all pending changes are reviewed.

### Step 2c: Apply Change

When user selects "Apply" for a change:

**1. Update spec.md with the delta:**

Read the Spec Delta from the change file and apply it to spec.md using the Edit tool.

**2. Append to changelog:**

```sh
SPEC_FILE="$SPEC_DIR/spec.md"

# Check if Change History section exists
if ! grep -q "^## Change History" "$SPEC_FILE"; then
  echo "" >> "$SPEC_FILE"
  echo "## Change History" >> "$SPEC_FILE"
  echo "" >> "$SPEC_FILE"
fi

# Append change entry
echo "- $(date +%Y-%m-%d): Applied \"$CHANGE_TITLE\" ($IMPACT_TYPE)" >> "$SPEC_FILE"
```

**3. Add new tasks to tasks.md:**

Read Task Impact from the change file and append new tasks.

**4. Update change status:**

Update the change file and index.md to mark the change as "applied".

**5. Confirm:**

```
Applied change $CHANGE_NUM: $CHANGE_TITLE
   - Spec updated
   - $NEW_TASK_COUNT task(s) added
   - Changelog updated
```

Continue to next pending change or proceed to task display.

### Step 3: Display Tasks

Read and display the task list:

```sh
cat "$TASKS_FILE"
```

Parse tasks to show status:
```
Implementation Tasks for $TICKET_ID:

 [ ] 1. Create new module structure
 [ ] 2. Add dependencies
 [x] 3. Implement core logic (completed)
 [ ] 4. Add API endpoints
 [ ] 5. Create UI components
 [ ] 6. Write unit tests
```

### Step 4: Select Tasks to Implement

Ask user which tasks to work on using AskUserQuestion:

```
Which tasks would you like to implement?

Options:
1. All remaining tasks
2. Specific task numbers (e.g., "4, 5")
3. Next incomplete task only
```

### Step 5: Execute Implementation

For each selected task:

1. **Read the spec** for context on what to build
2. **Check sources/** for existing patterns to follow
3. **Implement in worktree** - all file writes go to $WORKTREE_PATH
4. **Mark task complete** in tasks.md

Implementation loop:
```
For task: "Add API endpoints"

1. Reading spec for API requirements...
2. Checking sources/messaging/src/api/ for patterns...
3. Creating $WORKTREE_PATH/src/api/newEndpoint.ts
4. Updating $SPEC_DIR/tasks.md - marking task complete
```

### Step 6: Update Tasks File

After completing a task, update tasks.md using the Edit tool to change the checkbox from `[ ]` to `[x]`.

### Step 7: Check Completion Status

```sh
TOTAL=$(grep -c '^\- \[' "$TASKS_FILE" || echo 0)
COMPLETE=$(grep -c '^\- \[x\]' "$TASKS_FILE" || echo 0)
REMAINING=$((TOTAL - COMPLETE))

echo "Progress: $COMPLETE/$TOTAL tasks complete ($REMAINING remaining)"
```

### Step 8: Verification (If All Tasks Complete)

When all tasks are done, run verification:

```sh
if [ "$REMAINING" -eq 0 ]; then
  echo "All tasks complete! Running verification..."

  # Run tests
  npm test  # or appropriate test command

  # Run linting
  npm run lint

  # Type checking
  npm run typecheck
fi
```

### Step 9: Output Status

After each implementation session:

```
Implementation Progress for $TICKET_ID
─────────────────────────────────────────
Tasks: $COMPLETE/$TOTAL complete

Completed this session:
  - Add API endpoints
  - Create UI components

Remaining:
  - Write unit tests
  - Manual QA

Files modified:
  - src/api/newEndpoint.ts (created)
  - src/components/NewFeature.tsx (created)
  - src/index.ts (modified)

Next steps:
1. Review changes: git diff
2. Continue implementation: /kraft-implement
3. When done: git add . && git commit
```

## Implementation Guidelines

### File Organization
- Follow existing patterns from `sources/`
- Keep imports organized
- Add appropriate types/interfaces

### Code Quality
- Write self-documenting code
- Add comments only where logic isn't obvious
- Follow project's ESLint/Prettier config

### Testing
- Write tests alongside implementation
- Cover happy path and edge cases
- Match existing test patterns

## Pattern Discovery

Use sources/ to find patterns:

```sh
# Find similar implementations
grep -r "similar_pattern" "$WORKSPACE/sources/" --include="*.ts" -l

# Read existing examples
cat "$WORKSPACE/sources/frontend/src/components/Example.tsx"
```

Apply discovered patterns to the implementation in the worktree.

## Error Handling

- **No spec:** Guide user to run `/kraft-plan`
- **Tests fail:** Show errors, don't mark task complete
- **Lint errors:** Auto-fix if possible, report otherwise
- **Build errors:** Pause and ask user how to proceed

## Notes

- All writes go to the worktree only
- Specs are read-only during implementation
- Use sources/ for reference, never modify
- Commit frequently to preserve progress
