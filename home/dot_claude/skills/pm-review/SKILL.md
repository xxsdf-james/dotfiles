---
name: pm-review
description: Project-manager review of a repo's process, not its code. Scores planning, scope, status, done-criteria, risk, change control, continuity and human–AI collaboration against Anthropic's AI-Native SDLC Playbook and related frameworks. Saves a Markdown report with a summary first, short scorecards and evidence lists, and ranked recommendations.
when_to_use: When the user asks for a project review, a PM critique, a process audit, or "how is this project going" for a repo.
argument-hint: "[repo path] [focus]"
disable-model-invocation: true
---

# PM review

Today is !`date +%F`.

Run an independent project review of `$ARGUMENTS`. If no path is given, review the current working directory. Any words after the path are a focus for the reviewer to weight, for example "risk" or "the last week".

## 1. Hand the review to the reviewer
Spawn the `pm-reviewer` agent (Agent tool, `subagent_type: "pm-reviewer"`) and wait for it to finish. It starts with fresh context, which is the point: the review shouldn't be shaped by this conversation. Give it this task, filling in the absolute paths:

> Review the project at `<absolute repo path>`. Focus: `<focus, or "none">`. Today is `<date>`.
> Follow the procedure in `${CLAUDE_SKILL_DIR}/procedure.md`. It points to `criteria.md`, `report.md` and `sources.md` in the same folder.
> Return only the finished Markdown report.

Don't add your own opinions of the project to the task. If you have context the reviewer can't find on disk (for example, that the repo is public), give it as a plain fact.

## 2. Save the report
Write the returned report, unchanged, to `<folder>/<repo folder name>-<date>.md`. Choose `<folder>` as follows:
1. If the environment variable `PM_REVIEW_DIR` is set (check it with Bash: `printenv PM_REVIEW_DIR`), use it. Each machine sets this to wherever it wants reviews kept.
2. Otherwise, use the `pm-reviews` folder inside Claude Code's config folder, next to this skill's own install folder. That's `~/.claude/pm-reviews` on Linux and macOS and `%USERPROFILE%\.claude\pm-reviews` on Windows. It exists on every machine that can run this skill, and its name is the same in every OS language.

Resolve the folder to an absolute path, because the file tools don't expand `~`. Never write into the reviewed repo, so that a review can't be committed by accident. If the file already exists, add `-2`, `-3` and so on. Create the folder if it's missing, and **note whether you created the default folder in this run**; step 4 needs that. If the write is refused, save the report to the session's scratchpad instead and say where it went.

Never ask anything before the review or before saving. The review must also work where nobody can answer (`claude -p`, scripts, test runs).

## 3. Report back
In the chat, show only:
- the report's **Summary** section, copied as it is
- the saved file's full path

Don't repeat the scorecards in the chat. They're in the file.

## 4. First review on this machine: offer a folder choice once
Do this step only if **all** of these are true:
- `PM_REVIEW_DIR` was not set
- you created the default folder in this run, which means this is the first review on this machine
- the session is interactive. In `claude -p`, scripts and test runs, skip this step.

Then ask the user once, with AskUserQuestion: keep reports in the default folder (give its full path; make this the first option), or use another folder. Explain that it's a one-time question for this machine.

- **Keep the default:** do nothing more. The folder now exists, so this question won't come back.
- **Another folder:** ask for the path if they haven't given it. Then:
  1. Propose adding `"PM_REVIEW_DIR": "<absolute path>"` to the `env` object in this machine's `~/.claude/settings.json`. Create `env` if it's missing, and keep every other setting as it is. Make this an edit the user approves; never change settings without approval. This file is per machine and not in any repo, so the choice stays local.
  2. Write a copy of this run's report into the new folder, creating it if needed. Then try to delete the copy in the default folder. If a sandbox blocks the delete, leave it and tell the user which file is the extra copy. Keep the default folder itself: because it exists, this question won't be asked again.
  3. Tell the user the setting applies from the next session.

  If the user declines the settings edit, leave the report where it is and tell them how to set `PM_REVIEW_DIR` themselves.
