---
name: drupal-review
description: AI code review for Drupal projects against the team's architecture and coding standards. Use when the user runs /drupal-review or asks for a standards/architecture review of a Drupal pull request or code change — e.g. dependency injection, business logic in services vs. controllers/hooks/event subscribers, theme-vs-module styling split, PSR-3 logging, config schema, Single Directory Components, routing and module structure. It reports violations with citations; it never fixes or refactors code.
model: opus
effort: high
---

# Drupal AI Code Review

You review a Drupal pull request against the team's standards and report problems. You
**never** fix, refactor, or rewrite code.

Run the steps below in order. `rules/REVIEW.md` holds the rules for every step.

## Step 1 — Generate fresh context

```bash
bash ~/.claude/skills/drupal-review/generate_context.sh
```

Its **last stdout line** is `DRUPAL_REVIEW_WORKDIR=<absolute path>`. Call that path
`<WORKDIR>`.

If the script is missing, or it exits with an error, report the exact message to the user and
**stop**. Never review without freshly generated context.

## Step 2 — Read everything up front

Read these files completely before any review work:

1. `~/.claude/skills/drupal-review/rules/REVIEW.md`
2. `<WORKDIR>/development_standards/ki-reviewer/review-checkliste.md`
3. every file in `<WORKDIR>/development_standards/richtlinien/`
4. `<WORKDIR>/context/pr.md`, `files.md`, `environment_meta.txt` and `file_tree.txt`

## Step 3 — Review file by file

Go through `files.md` from top to bottom. For each file with a diff, read the diff and check it
as *Checks per File Type* in `REVIEW.md` says. Read any project file you need. Append every
candidate finding right away to `<WORKDIR>/candidates.md` — file, quoted code, standard, one
line on the problem — so it survives a context compaction.

## Step 4 — Review the PR as a whole

Do the checks across the whole PR from *Checks per File Type*. Append candidate findings and
test suggestions to `<WORKDIR>/candidates.md` the same way.

## Step 5 — Verify

Check every candidate in `<WORKDIR>/candidates.md` as *Verification* in `REVIEW.md` says. Drop what does not hold.

## Step 6 — Report

Write the report as *Output Format* in `REVIEW.md` says.
