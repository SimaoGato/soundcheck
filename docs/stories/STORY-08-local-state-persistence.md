---
id: STORY-08
epic: EPIC-02
status: draft
pr: null
---

# Persist minimal local state across relaunch

## User story
As a user who closes the app between sessions, I want it to remember where I
was, so that reopening it continues my practice rather than resetting
everything.

## Context

PRD FR9 deliberately keeps v1 state minimal — local-only, AsyncStorage, no
backend, no accounts — and the epic's out-of-scope section is explicit that
anything beyond "last level reached" needs a deliberate decision rather than
drift.

So this story is intentionally thin. In the free tier the only state worth
keeping is the count of questions answered — which EPIC-04's every-5-questions
paywall cadence depends on — plus the single place where EPIC-03's difficulty
level and EPIC-04's purchase flag will later live. Building the storage seam
once, with corruption handling, is what stops three stories from each
inventing their own AsyncStorage calls.

Depends on STORY-07.

## Acceptance criteria

1. Given a user has answered some questions, when the app is fully closed and
   relaunched, then the questions-answered count is restored, not reset.
2. Given a first-ever launch with no stored state, when the app starts, then
   it starts from sensible defaults with no error shown to the user.
3. Given stored state that is corrupt or unparseable (e.g. hand-edited or
   left by an older version), when the app starts, then it falls back to
   defaults and does not crash or block the user from playing.
4. Given stored state written by a previous version with missing fields, when
   it is read, then missing fields take their defaults rather than becoming
   `undefined` in use.
5. Given state is being written, when the user answers a question, then
   persistence happens off the interaction path — the answer and feedback do
   not wait on storage, and playback start still meets the 200ms NFR.
6. Given the device is offline, when state is read or written, then it works
   normally (PRD FR10, no backend involved).

## Out of scope

- What that state *contains* beyond the questions-answered counter — the
  difficulty level (EPIC-03) and purchase flag (EPIC-04) get added by the
  stories that need them.
- Scores, streaks, per-band accuracy history, stats screens — PRD FR9 keeps
  v1 minimal, and adding them here would be exactly the drift the epic warns
  against.
- Any cloud sync, export, or backup.
- A migration framework — AC4's defaults-for-missing-fields is the whole
  requirement until there is a real breaking change to migrate.

## Technical notes

- AsyncStorage per PRD stack constraint; a single key holding one JSON blob
  is enough at this size — don't spread state across keys.
- One small module with `load()` / `save()` and a typed default object.
  Everything else in the app should touch state through it.
- AC3 and AC4 are the reason this exists as a story at all; they are unit
  tests against a mocked storage, not manual checks.
- Affected areas: a new storage module and its tests, plus the quiz screen
  from STORY-07 reading and updating the counter.

## Definition of Done

See CLAUDE.md.
