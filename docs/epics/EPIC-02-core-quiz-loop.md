# EPIC-02: Core quiz loop (free tier)

**Depends on:** EPIC-01 (needs the clip matrix + manifest)

## Goal

A playable, shippable free-tier game: Expo app scaffolded, a question plays
a clip with one band boosted, the user picks from multiple choice, and gets
instant feedback — including, on a wrong answer, a plain-language
explanation of how their guess relates to the correct band. Free tier is
3 bands (125Hz / 1kHz / 8kHz) at a fixed +9dB, unlimited play, no ads,
no session cap.

## Why it matters

This is the product. Everything else is content depth (EPIC-03), money
(EPIC-04), or shipping (EPIC-05). The PRD's stated positioning — a free
tier that is "genuinely playable, not a demo stub" — means this epic alone
has to be worth installing. It's also the epic that delivers the actual
differentiator: teaching on wrong answers (octave relationship), not just
scoring.

## Scope (in)

- Expo + TypeScript project scaffold, expo-audio playback wiring.
- Question generation: pick a band + gain, select distractor choices.
- Clip playback from the bundled matrix via the EPIC-01 manifest, with
  replay.
- Answer selection UI and instant correct/incorrect feedback.
- Wrong-answer explanation: relationship between guess and correct band
  (octave distance, higher/lower) in FOH/AV language, not producer jargon.
- Free-tier constraint: 3 bands, +9dB only.
- Local state via AsyncStorage (progress, session counters).
- Fully offline operation.
- Accessibility basics: legible sizing, contrast for bright-venue use,
  correct/incorrect conveyed by icon/text and not color alone (NFR).

## Out of scope

- Anything gated behind the paid tier (10 bands, cuts, gain levels,
  adjacent-hard mode, difficulty ladder) — EPIC-03.
- Purchase flow, entitlement, paywall banner — EPIC-04.
- Store listing, icon, release build — EPIC-05.
- Scores/streaks persisted as a long-term stat system — v1 keeps local
  state minimal (PRD FR9); anything beyond "last level reached" needs a
  deliberate decision, not drift.

## Acceptance signals

- Cold start to first question with no signup, no network.
- A question plays, is answerable, and feedback appears instantly
  (<200ms to playback start per NFR).
- A wrong answer produces a correct, human-readable relationship
  explanation (e.g. "1kHz is about 3 octaves above 125Hz").
- Free tier never presents a band outside {125Hz, 1kHz, 8kHz} or a gain
  other than +9dB.
- Play is unlimited: no cap, no ad, no forced interruption.
- App relaunch restores local state.

## Candidate stories

- Expo + TypeScript project scaffold
- expo-audio playback of a manifest-indexed clip, with replay
- Question generation and distractor selection (free-tier band set)
- Answer UI + instant correct/incorrect feedback
- Wrong-answer octave-relationship explanation
- AsyncStorage local state persistence
- Accessibility pass (contrast, sizing, non-color-only feedback)
