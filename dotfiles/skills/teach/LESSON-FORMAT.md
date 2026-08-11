# LESSON.md Format

`LESSON.md` lives in `docs/learning/lessons/000N-<dash-case-name>/` and is the primary document a lesson produces. It states one assignment against the shared project, tied to the mission and scoped to the user's zone of proximal development.

## Template

```md
# Lesson N: {Short title}

## Goal
{1-3 sentences: the concrete assignment. What must the user make true about the running project — a failing test that should pass, a feature that should work.}

## Concepts
{Only what's needed for this assignment. Cite RESOURCES.md entries for every claim.}

- {Concept 1}, citing [{Resource name}](path or link in RESOURCES.md)
- {Concept 2}, ...

Stuck? See [Hint 1](#hint-1). Still stuck? [Hint 2](#hint-2), then [Hint 3](#hint-3).

---

## Hints

### Hint 1
{A nudge — point at the missing piece of understanding, not the mechanism.}

### Hint 2
{The approach — name the technique or pattern to use.}

### Hint 3
{Near-answer — enough to unblock completely, short of the literal final code.}
```

## Rules

- **Never state the full solution in `## Goal` or `## Concepts`.** Concepts explain what to know; they don't show how to assemble it into the answer.
- **Hints escalate, never restate.** Each hint level should reveal genuinely new information, not rephrase the previous one.
- **Reveal one hint level at a time, only on request.** Never read ahead in the Hints section and give the user information from a later hint before they've asked for the earlier ones.
- **Every concept is cited.** If no resource backs a claim, add one to `RESOURCES.md` first, or reconsider whether the claim belongs in the lesson.
- **Plain markdown only — no `<details>`/collapsible syntax.** Anchor links (`[Hint 1](#hint-1)`) render everywhere; collapsible blocks don't render in every markdown viewer the user reads lessons in.
- **Scope to one assignment.** If the goal needs more than one sitting's worth of work, split into multiple lessons.

## Numbering

Scan `docs/learning/lessons/` for the highest existing number and increment by one.
