# Report shape

Write plain, direct sentences. Use tables for the scorecards. Cite evidence inline (`file:line`, a short commit hash, counts).

```markdown
# Project review: <project name> (<period covered>)

**Verdict:** <2–3 sentences: overall rating, the main strength, the main weakness.>
Tally: N Strong · N Adequate · N Needs work · N N/A

## 1. Criteria
<List the three lenses and their criteria (IDs and names only), and the rating scale.
Note any criteria marked N/A, and why.>

## 2. Scorecard: AI-Native SDLC Playbook
| # | Criterion | Rating | Evidence |
|---|---|---|---|
| S1 | ... | Strong / Adequate / Needs work / N/A | ... |

> **Biggest gap:** <one finding, why it carries the most risk, and the playbook rule it breaks.>

## 3. Scorecard: project management
| # | Criterion | Rating | Finding |

## 4. Working with AI
| Framework | Area | Rating | Notes |

## 5. Recommendations (most urgent first)
1. **<Action>.** <What, where, and which finding it fixes.>
...

## Limits
<What couldn't be checked ("not confirmed"), what assumptions were made, and that nothing was changed.>

## Sources
<From sources.md: only the frameworks actually used.>
```
