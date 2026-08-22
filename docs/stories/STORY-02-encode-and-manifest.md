---
id: STORY-02
epic: EPIC-01
status: draft
pr: null
---

# Encode the clip matrix and emit an app-facing manifest

## User story
As a developer building the quiz loop, I want the generated clips encoded as
small bundled audio assets with a manifest keyed by (frequency, gain), so
that the app can look up and play the right clip without knowing anything
about how the audio was produced.

## Context

STORY-01 produces correct but uncompressed audio. This story is the
packaging seam: turn the matrix into shippable assets (2.5s mono AAC
~64kbps, ≈1.2MB total per PRD FR8) and give the app a single lookup table
so playback code never hardcodes filenames.

**Known risk to verify, not assume:** AAC at ~64kbps mono commonly
low-passes somewhere around 14–16kHz. That could flatten or silence the
16kHz band clip specifically, making one of the ten bands untrainable. This
story must confirm the band emphasis *survives encoding* and raise the
bitrate for affected clips if it doesn't — the PRD's size budget has ample
room (≈1.2MB of a multi-MB app).

Depends on STORY-01 (needs its output to encode).

## Acceptance criteria

1. Given the WAV matrix from STORY-01, when the encode step runs, then 60
   mono AAC clips are produced, one per source WAV.
2. Given any encoded clip, when its properties are inspected, then it is
   mono, 2.5s within a small tolerance, and encoded at the target bitrate.
3. Given the encoded set, when total size is measured, then it is within the
   PRD budget (≈1.2MB, and in no case more than a stated ceiling).
4. Given an encoded clip for frequency F, when the octave-band energy check
   from STORY-01 is re-run **on the encoded file**, then the boost or cut at
   F is still present and in the same direction — verified explicitly for
   16kHz and 31kHz, the two bands most at risk from codec band-limiting.
5. Given the manifest, when it is loaded, then it contains exactly 60
   entries and every (frequency, gain) pair in the matrix resolves to a
   bundled asset path that exists.
6. Given the manifest, when it is compared against the asset directory,
   then there are no orphan assets and no dangling entries in either
   direction.
7. Given the app bundle, when it is inspected, then all 60 clips are
   included as static assets — no runtime download (PRD FR10, offline).

## Out of scope

- Playback, replay, or any audio UI — EPIC-02.
- Question generation or choosing which clip to play — EPIC-02.
- Re-tuning the DSP itself (band emphasis, normalization) — that's
  STORY-01; this story only verifies the encode preserves it.
- Per-clip metadata beyond what playback needs (frequency, gain, path).

## Technical notes

- ffmpeg handles the encode; the AC4 verification reuses STORY-01's band
  check script pointed at the encoded output rather than the WAVs.
- Manifest format: a generated TypeScript module is likely better than JSON
  here — it gives the app compile-time checking of the (frequency, gain)
  key space for free, and Expo requires `require()`-style static asset
  references to bundle files anyway. Refine to confirm against how
  expo-audio wants assets handed to it.
- The manifest should be **generated**, not hand-maintained, so it cannot
  drift from the asset directory (AC6).
- If 16kHz fails AC4 at 64kbps, prefer raising the bitrate over changing
  the band set — the size budget can absorb it.
- Affected areas: the encode script alongside STORY-01's generator, the
  bundled asset directory, and the generated manifest module.

## Definition of Done

See CLAUDE.md.
