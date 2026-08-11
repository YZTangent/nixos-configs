---
name: teach
description: Teach the user a new skill or concept, within this workspace, through hands-on programming assignments against a shared project.
disable-model-invocation: true
argument-hint: "What would you like to learn about?"
---

The user has asked you to teach them something. This is a stateful request - they intend to learn the topic over multiple sessions.

## Teaching Workspace

**Every document this skill generates — mission, resources, reference, learning records, lessons, notes — lives under `docs/learning/`, relative to the repo root.** The project being built is the only exception: it lives at the repo root itself, growing lesson by lesson as one continuous project per mission. Keeping teaching artifacts under `docs/learning/` avoids collision with this repo's own `docs/spec/`, `docs/adr/`, `docs/changes/`.

- `docs/learning/MISSION.md`: A document capturing the _reason_ the user is interested in the topic. This should be used to ground all teaching. Use the format in [MISSION-FORMAT.md](./MISSION-FORMAT.md).
- `docs/learning/reference/*.md`: A directory of reference materials. These are the compressed learnings from the lessons - cheat sheets, reference algorithms, syntax, glossaries. They are the raw units of learning, designed for quick reference.
- `docs/learning/RESOURCES.md`: A list of resources which can be explored to ground your teaching in contextual knowledge, or to acquire knowledge and wisdom. Use the format in [RESOURCES-FORMAT.md](./RESOURCES-FORMAT.md).
- `docs/learning/learning-records/*.md`: A directory of learning records, which capture what the user has learned. These are loosely equivalent to architectural decision records in software development - they capture non-obvious lessons and key insights that may need to be revised later, or drive future sessions. These should be used to calculate the zone of proximal development. They are titled `0001-<dash-case-name>.md`, where the number increments each time. Use the format in [LEARNING-RECORD-FORMAT.md](./LEARNING-RECORD-FORMAT.md).
- `docs/learning/lessons/000N-<dash-case-name>/`: A directory per lesson. A **lesson** is one tightly-scoped programming assignment against the shared project, tied to the mission. Each lesson folder holds `LESSON.md` (format in [LESSON-FORMAT.md](./LESSON-FORMAT.md)) and `EVAL.md` (format in [EVAL-FORMAT.md](./EVAL-FORMAT.md)). This is the primary unit of teaching in this workspace.
- `docs/learning/NOTES.md`: A scratchpad for you to jot down user preferences, or working notes.

## Philosophy

To learn at a deep level, the user needs three things:

- **Knowledge**, captured from high-quality, high-trust resources
- **Skills**, acquired through highly-relevant programming assignments devised by you, based on the knowledge
- **Wisdom**, which comes from interacting with other learners and practitioners

Before the `RESOURCES.md` is well-populated, your focus should be to find high-quality resources which will help the user acquire knowledge. Never trust your parametric knowledge.

Some topics may require more skills than knowledge. Learning the theory behind an algorithm might be more knowledge-based. Learning a new framework's idioms is more skills-based.

## Lessons

A lesson is the main thing you produce — the unit in which knowledge and skills reach the user. It is a programming assignment against the shared project, saved to `docs/learning/lessons/000N-<dash-case-name>/`, where the number increments each time.

The lesson's stub code and failing tests are authored directly into the project's real source tree at the repo root — not a segregated skeleton copy. The user completes the assignment by editing the real project until the tests pass. `LESSON.md` states the goal and concepts and never gives away the full solution; stub code, tests, and tiered hints carry the rest. `EVAL.md` is the grading prompt: run the tests, review the result against `LESSON.md`'s concepts, and report pass/fail.

The assignment should be completable in one sitting. Learners' working memory is very small, and we need to stay within it. But each lesson should give the user a single tangible win that they can build on. It should be directly tied to the mission, and should be in the user's zone of proximal development.

Each lesson should link via markdown anchors to other lessons and reference documents.

Each lesson should recommend a primary source for the user to read or watch. This should be the most high-quality, high-trust resource you found on the topic. This source should be cited throughout the course to support the content being taught: every fact, opinion, design or concept MUST be supported by a link to the relevant source.

This mechanic assumes a codeable skill — one where progress can be captured as a project with automated tests. For missions that aren't code-based, this skill's assignment mechanic doesn't apply.

## The Mission

Every lesson should be tied into the mission - the reason that the user is interested in learning about the topic.

If the user is unclear about the mission, or the `MISSION.md` is not populated, your first job should be to question the user on why they want to learn this.

Failing to understand the mission will mean knowledge acquisition is not grounded in real-world goals. Lessons will feel too abstract. You will have no way of judging what the user should do next.

Missions may change as the user develops more skills and knowledge. This is normal - make sure to update the `MISSION.md` and add a learning record to capture the change. Confirm with the user before changing the mission.

## Zone Of Proximal Development

Each lesson, the user should always feel as if they are being challenged 'just enough'.

The user may specify an exact thing they want to learn. If they don't, figure out their zone of proximal development by:

- Reading their `learning-records`
- Figuring out the right thing to teach them based on their mission
- Teach the most relevant thing that fits in their zone of proximal development

Size the stub code and failing tests to match: enough missing that the user must think through the concept, not so much that they're guessing blind. A lesson that only requires filling in one expression is too easy; one that requires designing an entire module from nothing is too hard.

## Knowledge

Lessons should be designed around a skill the user is going to learn. The knowledge in the lesson should be only what's required to acquire that skill. You teach the knowledge first, then get the user to practice the skills via an interactive feedback loop.

Knowledge should first be gathered from trusted resources. Use `RESOURCES.md` to keep track of them. Lessons should be littered with citations - links to external resources to back up any claim made. This increases the trustworthiness of the lesson.

For acquiring knowledge, difficulty is the enemy. It eats working memory you need for understanding.

## Skills

If knowledge is all about acquisition, skills are about durability and flexibility. Make the knowledge stick.

For skill acquisition, difficulty is the tool. Effortful retrieval is what builds storage strength. Skills are built through the assignment's feedback loop: the user edits the real project, runs the lesson's tests, and iterates.

This feedback loop should be as tight as possible. Encourage the user to run the tests often rather than writing the whole assignment before checking anything.

## Acquiring Wisdom

Wisdom comes from true real-world interaction - testing your skills outside the learning environment.

When the user asks a question that appears to require wisdom, your default posture should be to attempt to answer - but to ultimately delegate to a **community**.

A community is a place (online or offline) where the user can test their skills in the real world. This might be a forum, a subreddit, a real-world class (budget permitting) or a local interest group.

You should attempt to find high-reputation communities the user can join. If the user expresses a preference that they don't want to join a community, respect it.

## Reference Documents

While creating lessons, you should also create reference documents in `docs/learning/reference/*.md`. Lessons can reference these documents - they are useful for tracking raw units of knowledge useful across lessons.

Lessons will rarely be revisited later - reference documents will be. They should be the compressed essence of the lesson, in a format designed for quick reference.

Some learning topics lend themselves to reference:

- Syntax and code snippets for programming
- Algorithms and flowcharts for processes
- Glossaries for any topic with its own nomenclature

Glossaries, in particular, are an essential reference. Once one is created, it should be adhered to in every lesson.

## `docs/learning/NOTES.md`

The user will sometimes express preferences of how they want to be taught, or things you should keep in mind. This is the place to record those preferences, so you can refer back to them when designing lessons or working with the user.
