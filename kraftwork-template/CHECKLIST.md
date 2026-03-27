# Extension Development Checklist

## Setup

1. Copy `kraftwork-template/` to `kraftwork-<name>/`
2. Update `.claude-plugin/plugin.json` — set name and description
3. Edit `providers.json` — delete categories you don't provide
4. Delete script stubs for removed categories
5. Delete fragment stubs for removed categories

## Configuration

6. Fill in `config/workspace-config.json` — section name, title, fields
7. For API-based auth: add an `apiTokenEnv` field (stores env var name, not the secret)
8. For CLI-based auth: no config needed (CLI handles its own auth)

## Implementation

9. Implement `scripts/auth-check.sh` — pick Pattern A (CLI) or Pattern B (API)
10. Implement each remaining script — replace `# --- IMPLEMENT BELOW ---` sections
11. Write fragment content — replace CHANGEME placeholders

## Verification

12. Run `kraft-config` — verify the new extension is discovered and offered
13. Test each script via `resolve-provider.sh`:
    - `kraftwork/scripts/resolve-provider.sh script <category> <capability>`
    - `kraftwork/scripts/resolve-provider.sh has <category> <capability>`
    - `kraftwork/scripts/resolve-provider.sh fragment <category> <fragment-name>`
