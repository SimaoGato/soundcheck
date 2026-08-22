---
id: STORY-07
epic: EPIC-02
status: draft
pr: null
---

# Quiz screen: answer, instant feedback, next question

## User story
As a user practising frequency ID, I want to hear a clip, tap the band I
think was boosted, and immediately see whether I was right and why, so that
I can do reps without leaving the screen.

## Context

This is the story that makes the app a game: it wires STORY-04 (playback),
STORY-05 (question generation) and STORY-06 (explanation) into the single
screen the user actually uses, and it is the first story a human can play.

Accessibility is built in here rather than being a later pass, because the
only UI in this epic is this screen and retro-fitting contrast and non-colour
feedback onto a screen you just wrote is rework. The PRD's accessibility NFR
is grounded in a real use case: a volunteer reading a phone in a bright
sanctuary, so correct/incorrect must survive both glare and colour blindness.

Depends on STORY-04, STORY-05 and STORY-06.

## Acceptance criteria

1. Given the app is opened cold with no network, when the user starts, then a
   question is presented and its clip plays without any signup, loading
   screen or network request (PRD journey 1).
2. Given a question is presented, when the user taps a choice, then feedback
   appears immediately, stating whether the answer was correct.
3. Given the user tapped a wrong choice, when feedback appears, then it shows
   the correct band *and* the STORY-06 relationship explanation for the band
   they picked.
4. Given feedback is showing, when the user continues, then a new question is
   presented and its clip plays — and this can repeat indefinitely with no
   cap, no ad and no forced interruption (PRD FR4).
5. Given feedback is showing, when the user taps a choice again, then the
   answer is not re-scored and the question does not change (no double
   submit).
6. Given a question is presented, when the user uses the replay control, then
   the clip replays, before and after answering.
7. Given correct or incorrect feedback, when it is rendered, then the outcome
   is conveyed by icon *and* text, not by colour alone (PRD NFR
   Accessibility) — verifiable by reading the rendered content with colour
   removed.
8. Given the screen is rendered, when text and interactive elements are
   measured, then body text meets the stated minimum size, contrast meets
   WCAG AA (4.5:1 for text), and every tap target is at least 44×44dp.
9. Given a screen reader is enabled, when the screen is traversed, then every
   control (each choice, replay, next) has a meaningful accessible label —
   not "button" or the raw asset name.
10. Given the device font scale is set to its largest setting, when the
    screen renders, then choices and feedback remain readable and reachable
    without clipping or overlap.

## Out of scope

- Persisting anything across relaunch — STORY-08.
- Scores, streaks, session summaries, stats screens (PRD FR9 keeps v1 state
  minimal).
- The paywall banner and the "Get full version" entry point — EPIC-04.
- Difficulty selection or level UI — EPIC-03.
- Animation polish, sound effects, haptics.
- App icon, splash, store assets — EPIC-05.

## Technical notes

- One screen; resist introducing navigation or global state management for a
  single screen's worth of state.
- The screen should consume the three existing modules and hold only view
  state (current question, answered/unanswered, last result). Any quiz rule
  that ends up here is a sign it belongs in STORY-05's module.
- AC8/AC9/AC10 want evidence against running code (device or emulator
  screenshots + a contrast measurement), not a claim in the PR description.
  If the Playwright MCP is not applicable to a React Native screen, the QA
  stage should capture emulator screenshots instead — decide this in Refine.
- Affected areas: the main screen component and its tests, plus small
  presentational pieces if the screen file gets unwieldy.

## Definition of Done

See CLAUDE.md.
