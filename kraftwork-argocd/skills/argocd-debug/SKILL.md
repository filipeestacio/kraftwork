---
name: argocd-debug
description: Use when an ArgoCD application is failing, unhealthy, or behaving unexpectedly — walks through top-down diagnosis from app overview to pod logs and events
---

# ArgoCD Debug

Top-down diagnosis for a broken ArgoCD application. Walks from app overview down to specific pod logs and events.

## Setup

Read `workspace.json` from the workspace root. Extract the `argocd` section. If missing, tell the user to run `/kraft-init` to configure ArgoCD settings, then stop.

Store:
- `[SERVER]` = `argocd.server`
- `[APP_PATTERN]` = `argocd.appPattern`
- `[ENVIRONMENTS]` = `argocd.environments`
- `[DEFAULT_ENV]` = `argocd.defaultEnvironment`, falling back to the first entry in `argocd.environments`

## Input

Optional environment argument. Must be one of `[ENVIRONMENTS]`. Defaults to `[DEFAULT_ENV]`.

Examples: `/argocd-debug`, `/argocd-debug production`, `/argocd-debug sandbox`

## Phase 1: Resolve App Name

Parse environment from argument. Default to `[DEFAULT_ENV]`.

Construct app name by substituting `{env}` in `[APP_PATTERN]` with the resolved environment. Store as `[APP]`.

## Phase 2: Auth Gate

```bash
argocd app get [APP] --grpc-web 2>&1 | head -5
```

If auth error:
```bash
argocd login [SERVER] --sso --grpc-web
```

Retry. If still failing, STOP and report auth issue.

## Phase 3: App Overview

```bash
argocd app get [APP] --grpc-web
```

Report sync status, health status, and current operation.

If app is `Healthy` and `Synced`:
```
[APP] is healthy and synced. Nothing to debug.

If you're seeing issues not reflected in ArgoCD, the problem may be
at the application level (check application logs directly).
```
Then STOP.

## Phase 4: Identify Unhealthy Resources

```bash
argocd app resources [APP] --grpc-web
```

Filter to resources that are NOT `Healthy` or NOT `Synced`. Store the list.

If no unhealthy resources but app-level health is not Healthy, note this — the issue may be at the app definition level.

## Phase 5: Diagnose Each Unhealthy Resource

For each unhealthy resource:

### 5.1 Resource Details

Report: kind, name, namespace, sync status, health status, and any status message from the resources output.

### 5.2 Pod Logs (for workload resources)

If the resource is a Deployment, StatefulSet, ReplicaSet, or Pod:

```bash
argocd app logs [APP] --kind [Kind] --name [Name] --grpc-web --tail 100
```

If the above fails or returns empty (common with CrashLoopBackOff), try getting logs for the previous container:

```bash
argocd app logs [APP] --kind [Kind] --name [Name] --grpc-web --tail 100 --previous
```

Look for: stack traces, OOM kills, connection refused, missing env vars, crashloop indicators.

### 5.3 Events

If `kubectl` is available and connected to the right cluster:

```bash
kubectl get events --namespace [Namespace] --field-selector involvedObject.name=[Name] --sort-by='.lastTimestamp' | tail -20
```

If kubectl is not available, note this and move on — ArgoCD logs from 5.2 are the primary diagnostic.

## Phase 6: Diff Check

Check for drift between Git and live state:

```bash
argocd app diff [APP] --grpc-web 2>&1
```

If there's a diff, report what's different. Common causes:
- Helm values changed but not synced
- Manual kubectl edits drifting from Git
- Secret or ConfigMap changes

If no diff, state that live matches Git.

## Phase 7: Operation History

Check recent sync operations for context:

```bash
argocd app history [APP] --grpc-web
```

Report last 3-5 entries: revision, date, sync status. Useful for identifying when things broke.

## Phase 8: Summary

Present findings:

```
Diagnosis for [APP]
═══════════════════

Status: [Health] / [Sync]

Unhealthy Resources:
  1. [Kind]/[Name] — [Health]
     Cause: [What the logs/events indicate]

  2. ...

Git vs Live Drift: [Yes/No — details if yes]

Recent History:
  [Last 3 deploys with status]

Likely Cause: [Your assessment based on all evidence]

Suggested Next Steps:
  - [Actionable step 1]
  - [Actionable step 2]
```

## Error Handling

- **Network timeout**: Suggest checking VPN
- **App not found**: List apps with `argocd app list --grpc-web`
- **Logs unavailable**: Fall back to resource status messages
- **kubectl not connected**: Skip events, note the gap in diagnosis
