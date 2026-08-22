---
id: STORY-04
epic: EPIC-02
status: draft
pr: null
---

# Play a manifest-indexed clip with expo-audio, with replay

## User story
As a user practising frequency ID, I want the question's clip to play
immediately and to be replayable as often as I want, so that I can listen
again before committing to an answer.

## Context

The clip matrix and its manifest come from EPIC-01 (STORY-02). This story is
the playback seam: given a (frequency, gain) pair, play the right bundled
clip. Everything about *which* pair to play belongs to STORY-05.

The PRD's performance NFR is the sharp edge here: playback must start with no
perceptible delay (<200ms) after the tap. With bundled assets and expo-audio
that is achievable, but it depends on the player being prepared ahead of the
tap rather than loaded on it — so it is an acceptance criterion, not a hope.

Depends on STORY-02 (manifest) and STORY-03 (app scaffold).

## Acceptance criteria

1. Given a (frequency, gain) pair present in the manifest, when playback is
   requested, then the bundled clip for exactly that pair is played.
2. Given a clip is playing, when the replay control is used, then the same
   clip plays again from the start, and this can be repeated without limit.
3. Given a clip is already playing, when replay is triggered, then only one
   playback is audible — the previous one is stopped rather than overlapped.
4. Given a prepared question, when the user triggers playback, then audio
   starts within 200ms of the tap (PRD NFR "Performance"), measured and
   recorded as evidence.
5. Given the device is in airplane mode with no network, when a clip is
   played, then it plays normally (PRD FR10, fully offline).
6. Given a (frequency, gain) pair that is not in the manifest, when playback
   is requested, then it fails loudly in development (clear error, not a
   silent no-op) and does not crash the app for the user.
7. Given the app is backgrounded mid-playback, when it returns to the
   foreground, then audio is not left stuck playing or in a broken state.

## Out of scope

- Choosing which band/gain to play, distractors, scoring — STORY-05.
- Answer UI and feedback — STORY-07.
- Volume/output routing controls, headphone detection, ducking other apps
  beyond whatever the default audio mode gives.
- Preloading the *next* question's clip — revisit only if AC4 fails without
  it.

## Technical notes

- `expo-audio` per the PRD stack constraint. Confirm during Refine how it
  wants bundled assets handed over (`require()` / asset module) and reconcile
  with the manifest shape STORY-02 produced.
- Keep the playback surface small — something like
  `play(frequency, gain)` / `replay()` / `stop()`. The quiz screen should not
  hold player objects.
- AC4 wants a real measurement on a device or emulator, not a claim; record
  the number in the QA evidence.
- Affected areas: a playback module, the app entry screen used to exercise
  it, the generated manifest from STORY-02.

## Definition of Done

See CLAUDE.md.
