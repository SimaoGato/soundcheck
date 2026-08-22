---
id: STORY-05
epic: EPIC-02
status: draft
pr: null
---

# Free-tier question generation and choice selection

## User story
As a user practising frequency ID, I want each question to pick a band to
play and offer a set of choices, so that there is something to answer and it
doesn't feel like the same question every time.

## Context

This is the pure logic behind a question: pick the band, pick the gain, build
the choice list, and know which choice is correct. No audio, no UI — those
are STORY-04 and STORY-07 — which makes it fully unit-testable.

Free tier is fixed by PRD FR4: bands {125Hz, 1kHz, 8kHz}, +9dB only,
unlimited play. That maps exactly onto the "Obvious" tier of the ladder in
FR5 (3 widely spaced choices, +9dB).

**Ambiguity to settle here, deliberately:** PRD journey 1 shows a wrong-answer
example where the user picked 250Hz — a band outside the free set — implying
distractors could come from outside the playable bands. The epic's acceptance
signals say the opposite ("never presents a band outside {125Hz, 1kHz,
8kHz}"). This story takes the epic's reading: free-tier choices are exactly
the three free bands. It is the simpler rule, it matches the Obvious tier,
and it keeps the free tier honest — every choice offered is a band the user
can actually be trained on. The PRD example stands as an illustration of the
explanation feature (STORY-06), which will be exercised for real by paid-tier
band sets in EPIC-03.

With three bands and three choices, "distractor selection" in the free tier
is just the other two bands. That is the correct amount of work for this
story — the choice-count ladder is EPIC-03 and must not be built here.

## Acceptance criteria

1. Given the free tier, when a question is generated, then its correct band
   is one of {125Hz, 1kHz, 8kHz} and its gain is exactly +9dB — for every
   question, checked over a large number of generated questions.
2. Given a generated question, when its choices are inspected, then they are
   exactly the three free-tier bands, with no duplicates and no band outside
   that set.
3. Given a generated question, when the correct band is compared with the
   choices, then it is present among them exactly once.
4. Given many generated questions, when the sequence of correct bands is
   inspected, then the same band is never the answer more than twice in a
   row (so a 3-band pool doesn't produce runs that read as a broken app).
5. Given many generated questions, when the distribution of correct bands is
   inspected, then all three bands occur — no band is unreachable.
6. Given a generated question, when it is used to request playback, then its
   (frequency, gain) pair resolves to an existing manifest entry.
7. Given the choices for a question, when they are presented in order, then
   the order is not a fixed positional tell (the correct answer is not always
   in the same slot).

## Out of scope

- Playing the clip — STORY-04.
- Rendering choices or handling taps — STORY-07.
- The wrong-answer explanation text — STORY-06.
- Anything paid-tier: extra bands, cuts, other gain levels, adjacent-hard
  mode, the choice-count ladder, difficulty progression — EPIC-03.
- Scoring, streaks, stats.

## Technical notes

- Pure TypeScript module, no React, no audio imports — that's what makes
  AC1–AC7 cheap to test.
- Randomness has to be injectable (seed or an injected RNG) or AC4/AC5/AC7
  become flaky tests. Decide this in Refine before writing the tests.
- Keep the free-tier band set and gain defined in one place; EPIC-03 will
  widen it, and it should widen in one file.
- Affected areas: a new quiz-logic module and its tests; the manifest from
  STORY-02 for AC6.

## Definition of Done

See CLAUDE.md.
