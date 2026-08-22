# EPIC-01: Audio asset pipeline

**Depends on:** nothing (foundation)

## Goal

Produce the full matrix of pre-generated audio clips the app plays: pink
noise, 2.5s, mono, AAC ~64kbps, one clip per frequency × gain combination
(10 frequencies × 6 gain levels = 60 clips, ≈1.2MB). Delivered as a
repeatable offline generation script plus the bundled asset files and a
manifest the app can index by (frequency, gain).

## Why it matters

Every other epic is blocked on these files existing. The app does no
real-time DSP (PRD FR8), so the clip matrix *is* the audio engine — if the
boost at 500Hz isn't audible the way it should be, the app teaches the wrong
ear and no amount of UI work fixes it. Making generation a checked-in script
rather than hand-exported files means the matrix can be regenerated when the
listening check (NFR: audio quality) says a parameter needs tuning.

## Scope (in)

- A script that generates pink noise and applies a single-band peaking EQ at
  each of 31/62/125/250/500/1k/2k/4k/8k/16k Hz.
- Gain levels: +9, +6, +3, -3, -6, -9 dB.
- Consistent Q/bandwidth across bands, matching a graphic-EQ-like curve.
- Loudness normalization so gain level is the only perceptible difference
  between clips — a boost clip must not simply sound *louder overall*, or
  the game becomes a volume test instead of a frequency test.
- Output encoding to 2.5s mono AAC ~64kbps.
- A manifest (e.g. JSON or a generated TS module) mapping
  (frequency, gain) → asset path.
- A listening sanity-check pass over the generated matrix.

## Out of scope

- Any runtime/real-time DSP (explicit PRD non-goal).
- A flat/unprocessed reference clip UI feature (A/B comparison) — not in v1.
- Alternative base signals (synthetic pad/chord) — decided against,
  see `docs/adr/DECISIONS.md` 2026-08-22.
- App-side playback code — that's EPIC-02.

## Acceptance signals

- All 60 clips exist, are bundled, and load offline.
- Regenerating from the script reproduces the matrix deterministically.
- Blind listening: the boosted/cut band is identifiable at +9dB, and
  perceptibly present (if subtle) at +3dB.
- No clip is audibly louder overall than another at the same absolute gain
  magnitude — level differences track the band, not the whole signal.
- Total bundled audio ≈1.2MB, no single clip clipping or distorting.

## Candidate stories

- Pink noise generation + single-band peaking EQ script
- Loudness normalization across the matrix
- Encode/export to mono AAC at target size
- Generate the (frequency, gain) → asset manifest
- Listening verification pass over all 60 clips
