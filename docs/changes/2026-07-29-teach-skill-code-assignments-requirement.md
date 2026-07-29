# Teach skill: pivot to code-assignment lessons

## Context

`dotfiles/skills/teach/` (copied out of the `matt-pocock-skills` submodule into this repo at `dotfiles/skills/teach/`) is a general teaching skill. Lessons are single self-contained HTML files mixing knowledge exposition and quizzes. This change repurposes the skill so lessons are programming assignments against one continuous project, following the zone-of-proximal-development principle: scaffold stub code + failing tests into the real project, explain concepts, hint at the approach without giving away the answer, and let the assistant grade completion by running tests and reviewing the code.

## Scope

- Replace the HTML lesson mechanic with a markdown, code-assignment mechanic.
- Move all teaching-workspace artifacts under `docs/learning/` so they don't collide with this repo's existing `docs/spec/`, `docs/adr/`, `docs/changes/` convention.
- Drop the `assets/` reusable-component concept (no longer needed without HTML lessons).
- Out of scope: changes to `matt-pocock-skills` submodule itself (this only touches the copy at `dotfiles/skills/teach/`); changes to any other skill.

## Workspace layout (new)

```
docs/learning/
  MISSION.md
  RESOURCES.md
  NOTES.md
  reference/*.md              (was reference/*.html)
  learning-records/0001-*.md
  lessons/
    0001-<dash-case-name>/
      LESSON.md
      EVAL.md
```

Project code lives at the repo root as normal — one continuous project per mission. A lesson's stub code and failing tests are authored directly into the real project source tree, not a segregated skeleton copy.

## `LESSON.md`

Contains, in order:
1. Title / goal — the assignment tied to the mission, scoped to the user's zone of proximal development.
2. Concepts — cited to `RESOURCES.md` entries, only what's needed for this assignment.
3. Inline pointers to hints (e.g. "Stuck? See [Hint 1](#hint-1).").
4. A `## Hints` section at the bottom with `### Hint 1`, `### Hint 2`, ... headers, escalating nudge → approach → near-answer. Plain markdown headers + anchor links only — no `<details>`/collapsible syntax (doesn't render in the user's nvim markdown setup).

The assistant reveals hints one level at a time, only when the user asks — never all at once, never unprompted.

No stored reference solution. Grading and hint quality are judged against `LESSON.md`'s stated concepts and goal, not a fixed implementation, to stay flexible to valid alternate approaches.

## `EVAL.md`

A prompt for the assistant, written per lesson, instructing it to:
1. Run the lesson's tests.
2. Review the resulting code against `LESSON.md`'s stated concepts and goal.
3. Give feedback without revealing the answer outright.
4. State pass/fail against the lesson's completion criteria explicitly.

## Format docs

Existing disclosed-reference files (`MISSION-FORMAT.md`, `RESOURCES-FORMAT.md`, `LEARNING-RECORD-FORMAT.md`, `GLOSSARY-FORMAT.md`) get their path references updated from workspace-root paths to `docs/learning/`-relative paths, and lose HTML/print framing where present.

Two new disclosed-reference files are added:
- `LESSON-FORMAT.md` — template and rules for `LESSON.md` (goal, concepts, hint tiering, citation rules).
- `EVAL-FORMAT.md` — template and rules for `EVAL.md` (test-run step, review step, feedback constraints, pass/fail statement).

## `SKILL.md` changes

- Update the workspace file listing at the top to the `docs/learning/` layout above.
- Replace the "Lessons" section: single continuous project per mission; stub code + tests land in the real project tree; lesson folder holds only `LESSON.md` + `EVAL.md`.
- Update "Zone Of Proximal Development" section to frame stub/test scaffolding difficulty, not HTML content difficulty.
- Remove the "Assets" section entirely.
- Update "Reference Documents" section: `.md` instead of `.html`, drop "print out well" framing.
- "Skills" section's interactive-lesson tooling (quizzes, in-browser tasks) is superseded by run-the-tests-and-review; simplify to reflect the code-assignment feedback loop.

## Non-goals

- No change to how missions are chosen or how `RESOURCES.md`/`learning-records/` work conceptually — only their location moves.
- No stored per-lesson solution file (explicitly rejected — tests + concept-grounded review is sufficient, avoids leak risk).
