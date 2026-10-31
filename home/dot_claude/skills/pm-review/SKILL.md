---
name: pm-review
description: Project-manager review of a repo's process, not its code. Scores planning, scope, status, done-criteria, risk, change control, continuity and human–AI collaboration against Anthropic's AI-Native SDLC Playbook and related frameworks, and returns a report with criteria first, scorecards, evidence and ranked recommendations.
when_to_use: When the user asks for a project review, a PM critique, a process audit, or "how is this project going" for a repo.
argument-hint: "[repo path] [focus]"
disable-model-invocation: true
context: fork
agent: pm-reviewer
background: false
---

# PM review

Review the project in `$ARGUMENTS`. If no path is given, review the current working directory. Any words after the path are a focus to weight, for example "risk" or "the last week".

You are judging **how the work is run**, not whether the code is good. Code quality only counts when it shows something about the process: a bug that shipped untested is a test or gate finding, not a code finding.

## Files in this skill
- [criteria.md](${CLAUDE_SKILL_DIR}/criteria.md): every criterion, with what good looks like, the evidence to check and the red flags. Read it before scoring.
- [report.md](${CLAUDE_SKILL_DIR}/report.md): the shape of the report. Follow it exactly.
- [sources.md](${CLAUDE_SKILL_DIR}/sources.md): the Anthropic frameworks behind the criteria, with links. Cite from here.

## Procedure
1. **Orient.** Find the repo root and what kind of project this is: code, config, docs or research. Note how many people work on it, how old it is and how active it is. Read the README, any `CLAUDE.md`, and the plan, status, TODO or roadmap files.
2. **Gather evidence (read-only).**
   - `git log`: commit count, dates, pace, and the share of commits that fix or follow up earlier ones. Check whether pushes go straight to the main branch.
   - `.claude/`: settings, hooks, skills and agents. Also check git hooks (`core.hooksPath`, `.git/hooks` minus `*.sample`).
   - Tests, CI configuration and evaluation scripts.
   - Scripts that change things outside the repo, and whether they pause before publishing.
   - Plan documents: compare their claims with the repo's actual state, and note each stale line with `file:line`.
   - If you can't check something (GitHub settings, a server, a VM), mark it **not confirmed**. Never call it missing.
3. **Check the premise.** Decide which criteria apply. A one-person repo has no separate reviewer, so read team roles as analogies. Mark a criterion **N/A** with a one-line reason rather than forcing a score.
4. **Score.** Rate each criterion **Strong**, **Adequate**, **Needs work** or **N/A**. Back every rating with concrete evidence: `file:line`, a commit hash, a count. One finding per row. Give credit where it's due, because strengths tell the reader what to keep doing.
5. **Name the biggest gap.** Pick the one finding with the most risk. Gaps in gates and security usually outrank tidiness.
6. **Recommend.** Give 5–8 actions, most urgent first. Each should be small enough to start this week and tied to a finding.
7. **Self-check before returning.**
   - Every claim traces to evidence you actually saw.
   - Ratings agree with their evidence.
   - Nothing unverified is stated as fact.
   - The criteria are listed before any scores.

Return the finished report as Markdown. Do not edit, create, commit or push anything.
