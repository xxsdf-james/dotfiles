# Report shape

The report is read in a Markdown viewer or a terminal. Keep table cells short so the rows don't wrap into a mess, and put the detail in an evidence list under each table.

**Rules**
- **Table cells:** the "Key point" column has at most 12 words, and no other cell holds a sentence. No `file:line`, hashes or quotes in tables; those go in the evidence lists.
- **Evidence lists:** one bullet per row, in the same order as the table, starting with the row's ID in bold. Each bullet has 1–3 short sentences with `file:line`, hashes and counts.
- **Summary:** at most about 15 lines. It must make sense to someone who reads nothing else.
- Write plain, direct sentences, and don't repeat the same finding in several sections. Cross-refer by ID (e.g. "see S6").

```markdown
# Project review: <project name>

_<period covered> · reviewed <date> · scope: <paths reviewed>_

## Summary
**Overall: <Strong | Adequate | Needs work>.** <1–2 sentences: the main strength and the main weakness.>

Tally: N Strong · N Adequate · N Needs work · N N/A

**Biggest gap:** <2–3 sentences: what it is, why it carries the most risk, and the rule it breaks.>

**Do first:**
1. <action> (fixes <IDs>)
2. <action> (fixes <IDs>)
3. <action> (fixes <IDs>)

## 1. Criteria
- **Lens A, AI-Native SDLC Playbook:** S1 … S10 (names only)
- **Lens B, project management:** B1 … B9
- **Lens C, working with AI:** the frameworks and areas used
- **Scale:** Strong / Adequate / Needs work / N/A
- **N/A:** <which, and why, or "none">

## 2. AI-Native SDLC Playbook
| # | Criterion | Rating | Key point |
|---|---|---|---|
| S1 | Committed files | Needs work | Plan and scripts aren't under version control |

**Evidence**
- **S1:** <1–3 sentences with file:line, hashes, counts.>

## 3. Project management
| # | Criterion | Rating | Key point |
|---|---|---|---|

**Evidence**
- **B1:** …

## 4. Working with AI
| # | Framework: area | Rating | Key point |
|---|---|---|---|
| C1 | 4D: Delegation | Strong | … |

**Evidence**
- **C1:** …

## 5. Recommendations
1. **<Action>.** <What and where, in 1–2 sentences.> Fixes <IDs>.
...

## Limits
- **Not confirmed:** <what couldn't be checked, and why>
- **Assumptions:** <…>
- Nothing was changed.

## Sources
- <only the frameworks actually used, from sources.md>
```
