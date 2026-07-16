# Issue tracker: GitHub

Issues and PRDs for this repository live as GitHub issues. Use the `gh` CLI for issue operations.

## Conventions

- Create issues with `gh issue create`.
- Read issues and comments with `gh issue view <number> --comments`.
- List and filter issues with `gh issue list` and its JSON output options.
- Comment with `gh issue comment <number>`.
- Apply or remove labels with `gh issue edit <number>`.
- Close issues with `gh issue close <number>`.

Infer the repository from `git remote -v`; commands run inside this clone target `zxor-org/zerobox`.

When a skill says to publish to the issue tracker, create a GitHub issue. When it says to fetch a ticket, read that GitHub issue and its comments.
