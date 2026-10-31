# Criteria

Three lenses. Lens A (the AI-Native SDLC Playbook) is the main structure; B and C refer back to it where they overlap. Ratings: **Strong**, **Adequate**, **Needs work**, **N/A**. For each criterion: what good looks like, the evidence to check, and red flags.

## Lens A: AI-Native SDLC Playbook

**S1. Stages linked by committed files, one source of truth each**
- Good: intent, spec, plan, changes plus tests, review and incident record each live in a versioned file, and the next stage reads the previous one. The commit chain is the audit trail.
- Check: are plans, status and decisions committed? Is each one in exactly one place? Are the scripts that changed things under version control?
- Red flags: one huge file doing every job; working folders that aren't git repos; the same fact kept in several places that disagree.

**S2. Plan: intent captured first**
- Good: before work starts, a short intent records the problem, outcome, constraints and open questions, and accepting it is recorded.
- Check: does new work (including work added mid-stream) have its own written intent?
- Red flags: features folded into an unrelated step; work that started from a chat message alone.

**S3. Design: a human reviews the spec**
- Good: a spec or design doc exists. A human reviews it and decides. Concerns are flagged, and rejected options are recorded.
- Check: does a spec or philosophy doc exist, and are decisions checked against it?
- Red flags: decisions that contradict the spec's own rules; no recorded alternatives.

**S4. Build: plan first, short CLAUDE.md, skills, hooks**
- Good: work starts from an approved plan. `CLAUDE.md` is under a page and is updated when mistakes repeat. Skills hold knowledge that must be applied the same way every time. Hooks enforce rules that must hold.
- Check: `CLAUDE.md` (and its length), `.claude/settings*.json`, hooks, `.claude/skills`, `.claude/agents`.
- Red flags: conventions only in memory or prose; no hooks for rules stated as "never".

**S5. Test: a feedback loop**
- Good: checks with measurable targets pass before anything counts as "done". Every incident becomes a test. Fix the code, not the test. The agent can't edit the checks it is graded by.
- Check: test scripts and CI; whether bugs that were found produced new tests; whether manual checks can be re-run.
- Red flags: one-off manual verification; tests edited in the same commit to make them pass; untested code merged.

**S6. Deploy: gates**
- Good: a review policy (e.g. `REVIEW.md`). Whoever wrote a change doesn't approve it. Branch protection is on. Gates are enforced the same way for everyone. The agent can act up to the production gate but can't pass it. Rollback is rehearsed.
- Check: does anything push straight to the main branch? Does any script show a diff and publish in the same run? Branch protection (usually "not confirmed" without `gh`)? Rollback steps?
- Red flags: commit-and-push in one step; broken code reaching a public or production branch; no way back.

**S7. Maintain: close the loop**
- Good: drift and regressions are detected automatically, scans recur, lessons are kept in a versioned file, and incidents become tests.
- Check: watch scripts, update or drift commands, a lessons or post-mortem file.
- Red flags: maintenance only planned; lessons scattered through prose.

**S8. Advisory vs enforced controls**
- Good: every must-hold rule is paired with a hook, a permission rule or a setting. Decisions don't wait on a committee.
- Check: list the "never/always" rules and how each is enforced.
- Red flags: security rules kept only by habit.

**S9. Metrics**
- Good: some leading and lagging measures per stage: first-pass success, rework cycles, change failure rate, time from intent to done.
- Check: anything tracked at all? Compute one easy proxy from git, such as the share of fix or follow-up commits.
- Red flags: no measures.

**S10. Humans at the gates**
- Good: people set direction and review outputs, not every line, with a review load they can sustain.
- Check: who decides and who executes; how much review material each gate carries; pace.
- Red flags: the human only rubber-stamps; very high pace with dense gates (decision fatigue).

## Lens B: classic project management

1. **Goal and scope control.** A clear goal and a boundary. New work goes to a backlog unless it's on the critical path. Red flags: a growing "later" list with no limit; side features inside a test step.
2. **Sequencing and the critical path.** Dependencies are ordered, and risky exposure comes after its safeguards. Red flag: something goes public before its hardening.
3. **Status visibility.** The current state and the next action can be found in under a minute. Red flags: dense paragraphs; mixed done and next items; struck-through text.
4. **Definition of done.** Every task or milestone has a written done-check that gets ticked off. Red flag: a "verify" list that is never closed.
5. **Risk management.** A register with each risk, its owner, a date and its status. Known risks are scheduled. Red flag: risks recorded in prose and never scheduled.
6. **Change control and reversibility.** Backups before destructive steps, scripts that don't depend on prompts, snapshots, the ability to undo.
7. **Continuity between sessions.** A new session (or a new person) can resume from the docs, and the docs match reality. Check for stale lines and cite `file:line`.
8. **Decision records.** Decisions are dated, with the reason and the alternatives turned down.
9. **Pace and sustainability.** Milestones, time limits and a load the people involved can keep up.

## Lens C: working with AI

**AI Fluency 4D**
- *Delegation:* the right split between human and AI; credentials and judgement calls stay with the human.
- *Description:* the AI is given clear goals and context, in a short, findable form.
- *Discernment:* AI output is checked critically. Did someone catch drift, untested claims or wrong assumptions?
- *Diligence:* responsibility for outcomes, transparency about AI use, secrets handled safely, safe ordering.

**Safe and trustworthy agents:** human control (approvals, the ability to interrupt), transparency (visible plans), privacy (no sensitive data carried across contexts), security (enforced, not habitual).

**Claude Code best practices:** tell Claude what it can't see (`CLAUDE.md`, connected tools), give it a check to run, enforce the rules that can't have exceptions (hooks, permissions, sandbox).

**Long-running agents:** a short progress file, a structured feature list with statuses, one feature at a time, a commit per step, a clean state at the end of each session, and a startup routine that re-checks before new work.
