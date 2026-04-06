## Git Hosting & CI (GitLab)

- Before creating a branch, use `git-hosting-find` to check if one already exists for the ticket.
- Use `git-hosting-request-review` to create or update merge requests — do not use `git push` and manually create MRs.
- Use `ci-find` and `ci-describe` to check pipeline status before declaring work done.
- Use `ci-fix` when a pipeline fails — read the job log before attempting a fix.
- MR descriptions must include a summary of changes and a test plan. Use `git-hosting-describe` to review before submitting.
