---
name: argocd-status
description: Use when checking the health or sync status of an ArgoCD application, before debugging — quick overview of whether an app is healthy or not
---

# ArgoCD Status Check

Quick health check for ArgoCD applications. Shows sync status, health, and any unhealthy resources.

## Setup

Read `workspace.json` from the workspace root. Extract the `argocd` section. If missing, tell the user to run `/kraft-init` to configure ArgoCD settings, then stop.

Store:
- `[SERVER]` = `argocd.server`
- `[APP_PATTERN]` = `argocd.appPattern`
- `[ENVIRONMENTS]` = `argocd.environments`
- `[DEFAULT_ENV]` = `argocd.defaultEnvironment`, falling back to the first entry in `argocd.environments`

## Input

Optional environment argument. Must be one of `[ENVIRONMENTS]`. Defaults to `[DEFAULT_ENV]`.

Examples: `/argocd-status`, `/argocd-status production`, `/argocd-status sandbox`

## Phase 1: Resolve App Name

Parse the environment from the argument. Default to `[DEFAULT_ENV]` if none provided.

Construct app name by substituting `{env}` in `[APP_PATTERN]` with the resolved environment.

Store as `[APP]`.

## Phase 2: Auth Check

Test authentication:
```bash
argocd app get [APP] --grpc-web 2>&1 | head -5
```

If output contains `Please login` or `Unauthenticated`:
```bash
argocd login [SERVER] --sso --grpc-web
```

Then retry the `app get` command.

## Phase 3: App Overview

```bash
argocd app get [APP] --grpc-web
```

Extract and report:
- **Sync Status**: Synced / OutOfSync
- **Health Status**: Healthy / Degraded / Progressing / Missing / Unknown
- **Last Sync**: timestamp and result
- **Current Operation**: if any in progress

## Phase 4: Unhealthy Resources

If health is not `Healthy`, list unhealthy resources:
```bash
argocd app resources [APP] --grpc-web 2>&1 | grep -v "Healthy"
```

For each unhealthy resource, report: kind, name, sync status, health status, and any message.

## Phase 5: Summary

Output a clean summary:
```
[APP] — [HEALTH_STATUS] / [SYNC_STATUS]

[If healthy:]
All resources healthy. Last synced: [timestamp].

[If unhealthy:]
Unhealthy resources:
  - [Kind]/[Name]: [Health] — [Message]
  - ...

Run /argocd-debug [env] for deeper investigation.
```

## Error Handling

- **Network timeout**: Suggest checking VPN connection
- **App not found**: List available apps with `argocd app list --grpc-web`
- **Auth failure after login**: Suggest `argocd logout` then re-login
