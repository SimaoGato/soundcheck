# EPIC-03: Full band set & difficulty progression

**Depends on:** EPIC-01 (full clip matrix), EPIC-02 (the loop it extends)

## Goal

Everything that makes the paid tier worth €0.99 as *content*: the full
10-band set, cuts as well as boosts, six gain levels, adjacent-frequency
hard mode, and the five-tier difficulty ladder (obvious → intermediate →
advanced → expert → cuts) with its widening-then-narrowing choice counts.

## Why it matters

The free tier proves the app works; this epic is the reason to pay. It's
also where the training actually gets *useful* for the target personas —
identifying a problem frequency in a live room means discriminating between
adjacent bands at modest gain, not spotting a +9dB boost three octaves
away. Note this epic builds the content and progression; whether the user
is *entitled* to it is EPIC-04's job.

## Scope (in)

- Full 10-band question generation (31Hz–16kHz).
- Cut questions (negative gain) alongside boosts.
- Gain levels +9/+6/+3dB and -3/-6/-9dB.
- Adjacent-frequency hard mode: distractors drawn from neighboring bands
  rather than spread across the spectrum.
- The difficulty ladder per PRD FR5:

  | Tier | Choices | Gain | Notes |
  |---|---|---|---|
  | Obvious | 3, widely spaced | +9dB | |
  | Intermediate | 5, moderate spacing | +9/+6dB | |
  | Advanced | 7, most of the band set | +6/+3dB | |
  | Expert | 10 (full set) | +3dB | adjacent-hard mode on |
  | Cuts | 10 (full set) | -3/-6/-9dB | cuts only, adjacent-hard mode on |

- Tier selection/progression and persisting the reached tier locally.
- Wrong-answer explanations that still read correctly for cuts and for
  adjacent-band mistakes (a one-band-off miss needs different wording than
  a three-octave miss).

## Out of scope

- Entitlement checks and purchase gating — EPIC-04 (this epic assumes
  content is available and is driven by a tier/unlock flag it does not own).
- Scoring systems, XP, streaks, or unlock-by-performance mechanics —
  explicitly not the competitors' model the PRD positions against.
- Any new audio assets beyond the EPIC-01 matrix.

## Acceptance signals

- Every tier generates questions matching its row in the table above:
  correct choice count, correct gain range, correct distractor spacing.
- Cut questions play the right clip and are scored/explained correctly.
- Adjacent-hard mode never presents widely-spaced distractors.
- Progression through tiers persists across app relaunch.
- Explanations remain accurate and readable for cuts and near-misses.

## Candidate stories

- Extend question generation to the full 10-band set
- Cut (negative gain) questions
- Multi-gain-level question generation
- Adjacent-frequency distractor mode
- Difficulty tier definitions and the choice-count ladder
- Tier progression + local persistence
- Explanation wording for cuts and adjacent-band misses
