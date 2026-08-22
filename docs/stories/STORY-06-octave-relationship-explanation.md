---
id: STORY-06
epic: EPIC-02
status: draft
pr: null
---

# Wrong-answer explanation in FOH language

## User story
As a church AV volunteer who guessed wrong, I want to be told how my guess
relates to the correct frequency, so that I learn something from the miss
instead of just being marked incorrect.

## Context

This is the epic's stated differentiator: teaching on wrong answers, not just
scoring (EPIC-02 "Why it matters", PRD FR2). Competing apps mark right/wrong;
this one explains the relationship — "You picked 250Hz — the correct answer,
1kHz, is about 2 octaves higher" (PRD journey 1).

Pure text generation from two frequencies, so it is fully unit-testable and
independent of the UI that will display it (STORY-07).

Two things make it more than string formatting:
- **Octave math on a 10-band EQ.** The standard set (31/62/125/250/500/1k/
  2k/4k/8k/16k) is one octave per step, so the distance in octaves is the
  distance in band positions — but 31→62 is not exactly an octave and 1k→2k
  isn't exactly 2×, hence the PRD's "about". Wording must not promise
  precision the band centres don't have.
- **Vocabulary.** PRD personas are FOH techs and AV volunteers, not
  producers. "Boxiness", "air", "presence" as *supporting* plain description
  is fine; producer jargon and mixing-desk-brand slang is not.

## Acceptance criteria

1. Given a wrong guess of 250Hz and a correct answer of 1kHz, when the
   explanation is generated, then it names both frequencies, states the
   direction (the correct answer is *higher*), and states the distance as
   about 2 octaves.
2. Given a wrong guess above the correct answer (e.g. guessed 8kHz, correct
   1kHz), when the explanation is generated, then the direction is *lower*.
3. Given any two distinct bands from the full 10-band set, when the
   explanation is generated, then the octave distance stated equals the
   number of band steps between them, in every one of the 90 ordered pairs.
4. Given a guess adjacent to the correct answer (one band apart), when the
   explanation is generated, then it reads naturally in the singular ("about
   one octave", not "about 1 octaves").
5. Given a correct guess, when feedback is generated, then no
   relationship explanation is produced (there is no relationship to
   explain).
6. Given any generated explanation, when it is read, then it contains no
   producer-studio jargon and no undefined abbreviations — checked against a
   short explicit list of banned terms so the criterion is testable rather
   than a matter of taste.
7. Given any generated explanation, when its length is measured, then it fits
   the feedback area without truncation at the app's largest supported font
   scale (a stated character ceiling).

## Out of scope

- Displaying the explanation, animations, layout — STORY-07.
- Explaining *cuts* vs boosts, or gain-level differences — free tier is
  +9dB boosts only; EPIC-03 widens this.
- Per-band tutorial content ("125Hz is where kick body lives") beyond the
  one-line relationship — a content project, not this story.
- Localisation — English only for v1 (PRD NFR i18n).

## Technical notes

- Pure function, e.g. `explain(guess, correct)` returning a string; no React
  imports. Table-driven tests over all ordered band pairs satisfy AC3
  cheaply.
- Derive octave distance from band *index*, not from `log2(f2/f1)` — the
  nominal band centres are rounded (62, 125, 250…) and the log will produce
  1.01 and 1.99 octaves, which then needs rounding anyway. One source of
  truth for the band order, shared with STORY-05.
- Affected areas: a new explanation module and its tests, sharing the band
  list with the quiz-logic module.

## Definition of Done

See CLAUDE.md.
