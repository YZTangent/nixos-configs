# EVAL.md Format

`EVAL.md` lives alongside `LESSON.md` in the same lesson folder. It is a prompt for the assistant, written by the assistant at lesson-authoring time, to grade the user's completed assignment.

## Template

```md
# Eval: {Lesson title}

## Run
{Exact command(s) to run this lesson's tests.}

## Check
- [ ] Tests pass: {what a full pass looks like — e.g. "all tests under tests/lesson_0004 green"}
- [ ] Code review against `LESSON.md`'s Concepts: {specific things to check — e.g. "uses recursion, not an explicit stack"}
- [ ] {Any other lesson-specific completion criterion}

## Feedback rules
- Do not reveal or imply the contents of a hint the user hasn't asked for.
- If tests fail, point at *which* test and *what class of behavior* it exercises — not the fix.
- If tests pass but the approach contradicts a stated concept, say so and explain why the concept matters, without prescribing the exact rewrite.
- State pass/fail explicitly at the end: "Lesson complete" or "Not yet — {specific gap}".
```

## Rules

- **Grounded in `LESSON.md`, not a stored solution.** There is no reference implementation to diff against — review is judged against the stated Goal and Concepts, which keeps valid alternate approaches from being marked wrong.
- **Tests gate correctness; review gates understanding.** A lesson can have passing tests and still get "not yet" if the approach ignores a concept the lesson exists to teach.
- **Write `EVAL.md` when the lesson is authored**, using the specific test command and check criteria for that lesson — not a generic template left unfilled.
