---
id: STORY-01
epic: EPIC-01
status: draft
pr: null
---

# Generate the normalized pink-noise EQ clip matrix

## User story
As a developer building the quiz loop, I want a repeatable script that
generates the full matrix of pink-noise clips with exactly one EQ band
boosted or cut, so that the app has correct training audio to play and the
matrix can be regenerated when a parameter needs tuning.

## Context

The app does no real-time DSP (PRD FR8) — the pre-generated clip matrix *is*
the audio engine. If the band emphasis is wrong or inconsistent, the app
teaches the wrong ear and no UI work fixes it. See EPIC-01 and PRD FR8 /
NFR "Audio quality".

The critical correctness risk is **loudness**: if a +9dB boost clip is simply
louder overall than a +3dB one, the game becomes a volume test instead of a
frequency test. Normalization is therefore part of this story, not a
follow-up — generation without it produces unusable output.

This story produces uncompressed WAVs. Encoding and the app-facing manifest
are STORY-02.

## Acceptance criteria

1. Given the generation script, when it is run with no arguments, then it
   produces 60 WAV files — one for each combination of frequency
   {31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k} Hz and gain
   {+9, +6, +3, -3, -6, -9} dB — named so the (frequency, gain) pair is
   recoverable from the filename.
2. Given a generated **boost** clip for frequency F, when the signal energy
   in the octave band centred on F is compared with the same band of the
   unprocessed pink-noise reference, then it is measurably higher, and the
   increase is monotonic across +3 → +6 → +9 dB.
3. Given a generated **cut** clip for frequency F, when the same comparison
   is made, then the band energy is measurably lower, and the decrease is
   monotonic across -3 → -6 → -9 dB.
4. Given any two clips in the matrix, when their integrated (broadband)
   loudness is measured, then they fall within a stated tolerance of each
   other — so the only reliable cue is the affected band, not overall level.
5. Given any generated clip, when its duration is measured, then it is
   2.5s within a small tolerance.
6. Given any generated clip, when its true peak is measured, then it is
   below 0 dBFS with headroom (no clipping or distortion).
7. Given the script is run twice from a clean state, when the two output
   sets are compared, then they are identical — noise generation is seeded,
   not random per-run.

## Out of scope

- Encoding to AAC, asset bundling, and the (frequency, gain) → path
  manifest — STORY-02.
- Any runtime/real-time DSP (explicit PRD non-goal).
- Alternative base signals (synthetic pad/chord) — decided against, see
  `docs/adr/DECISIONS.md` 2026-08-22.
- A flat/unprocessed reference clip as a user-facing A/B feature (the
  reference is used for verification here, not shipped as a game feature).
- App-side playback code — EPIC-02.

## Technical notes

- **Suggested approach: ffmpeg alone, no language toolchain.** `anoisesrc`
  generates seeded pink noise, `equalizer` applies a single-band peaking EQ,
  `loudnorm` handles normalization, and `ebur128` / `astats` /
  `volumedetect` provide the measurements the acceptance criteria need. That
  makes both the generator and its checks a shell script with one system
  dependency, rather than adding a Python/numpy toolchain to what is
  otherwise a TypeScript project. Refine to confirm; a numpy/scipy generator
  is the fallback if ffmpeg's filters prove too coarse.
- Band emphasis verification (AC2/AC3) can be done by band-passing the
  output around F and comparing RMS against the same band of the reference —
  no spectral-analysis library required.
- Q / bandwidth must be constant across all bands so difficulty is set by
  gain, not by an incidentally wider filter at some frequencies.
- Watch the extremes: 31Hz and 16kHz sit near the edges of both typical
  phone-speaker response and the pink noise energy distribution. Verify
  these two bands are actually distinguishable before considering the
  matrix done.
- Affected areas: a new generation script + its check script (likely under
  `scripts/` or `audio/`), and a generated (git-ignored or committed —
  Refine to decide) WAV output directory.

## Definition of Done

See CLAUDE.md. Note that this story's **manual verification step is a real
listening pass** over the generated matrix (EPIC-01 acceptance signal): the
boosted band should be obvious at +9dB and perceptible at +3dB, and no clip
should sound merely louder than another.
