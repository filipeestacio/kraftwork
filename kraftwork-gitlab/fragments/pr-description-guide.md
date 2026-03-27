## MR Description Guide (GitLab)

- Include `Closes <TICKET-ID>` (e.g., `Closes PROJ-1234`) in the description to auto-close the linked Jira/GitLab issue on merge.
- Use GitLab-flavored markdown for formatting: task lists (`- [ ]`), collapsible sections (`<details>`), and code blocks with language hints.
- CI pipelines run automatically on push. Ensure the pipeline passes before requesting review.
- For stacked MRs, include `Stacked on !<parent-MR-number>` in the description to indicate the dependency chain.
