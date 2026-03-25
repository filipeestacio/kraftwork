---
name: glab-pipeline
description: Use when a CI pipeline is failing, you want to check pipeline status, read job logs, retry failed jobs, or watch a running pipeline
---

# GitLab Pipeline Debugging

Debug and monitor CI/CD pipelines via `glab` CLI.

## Input

Optional subcommand: `status`, `debug`, `retry`, `watch`.

Examples: `/glab-pipeline`, `/glab-pipeline debug`, `/glab-pipeline retry`, `/glab-pipeline watch`

**Default:** `status`. If pipeline is failed, suggest running `debug`.

## Project Detection

Auto-detect from current git repo. If outside a repo, pass `--repo <git.group>/<name>` (using `git.group` from workspace.json).

## Auth Check

```bash
glab auth status 2>&1
```

If not authenticated, STOP and suggest `glab auth login`.

---

## Subcommand: status

### Phase 1: Get Latest Pipeline

```bash
glab ci status
```

If no pipeline found for current branch:
```bash
glab ci list --per-page 5
```

Show last 5 pipelines with branch, status, and date.

### Phase 2: Job Breakdown

```bash
glab ci view
```

Present each stage and its jobs with status:
```
Pipeline #12345 — failed

  build:
    build-image ............. passed (2m 13s)
  test:
    unit-tests .............. passed (4m 02s)
    integration-tests ....... failed (1m 45s)
  deploy:
    deploy-staging .......... skipped
```

If pipeline is failed, suggest:
```
Run /glab-pipeline debug to investigate the failing job(s).
```

---

## Subcommand: debug

### Phase 1: Identify Failing Jobs

```bash
glab ci view
```

Parse output to find jobs with `failed` status. Store job names and IDs.

If no failing jobs:
```
No failed jobs in the latest pipeline. Current status: [STATUS].
```
Then STOP.

### Phase 2: Get Job Logs

For each failing job:

```bash
glab ci trace [JOB_NAME]
```

This streams the full log. Since logs can be very long, focus on:
- The last 80 lines (where errors typically appear)
- Any lines containing `error`, `Error`, `ERROR`, `FATAL`, `fatal`, `failed`, `FAILED`

If `glab ci trace` doesn't work for the specific job, fall back to:
```bash
glab api "projects/:id/jobs/:job_id/trace" | tail -80
```

### Phase 3: Analyze

For each failing job, present:
- **Job name** and stage
- **Duration** before failure
- **Error section**: the relevant log lines showing what went wrong
- **Likely cause**: your assessment (test failure, build error, timeout, OOM, config issue, flaky test)

### Phase 4: Summary

```
Pipeline #12345 — [N] failed job(s)

1. [job-name] (stage: [stage])
   Error: [concise description of failure]
   Likely cause: [assessment]

2. ...

Suggested next steps:
  - [Fix X and push] or
  - [/glab-pipeline retry to retry flaky job]
```

---

## Subcommand: retry

### Phase 1: Identify What to Retry

```bash
glab ci view
```

Find failed jobs.

If no failed jobs:
```
No failed jobs to retry. Pipeline status: [STATUS].
```
Then STOP.

### Phase 2: Choose Scope

If one failed job, retry it directly. If multiple, ask the user:
```
Multiple jobs failed:
  1. [job-name-1]
  2. [job-name-2]
  3. All failed jobs

Which would you like to retry?
```

### Phase 3: Execute Retry

For a specific job:
```bash
glab ci retry [JOB_ID]
```

For the full pipeline:
```bash
glab ci retry
```

### Phase 4: Confirm

Report: what was retried, new pipeline/job URL. Suggest `/glab-pipeline watch` to monitor.

---

## Subcommand: watch

### Phase 1: Identify Pipeline

```bash
glab ci status
```

If no running pipeline:
```
No running pipeline for current branch. Latest pipeline status: [STATUS].
```
Then STOP.

### Phase 2: Monitor

```bash
glab ci view --live
```

If `--live` is not supported, poll with:
```bash
glab ci status
```

Report job completions as they happen. When pipeline finishes:

```
Pipeline #12345 — [passed/failed]

  [Full job breakdown with durations]

[If failed: suggest /glab-pipeline debug]
[If passed: all clear]
```

---

## Error Handling

- **No pipeline**: Branch may not be pushed, or no CI config. Check `.gitlab-ci.yml` exists.
- **Job not found**: Pipeline may have been cancelled. List recent pipelines.
- **Permission denied**: Check project access level.
- **Rate limiting**: Back off and retry after delay.
