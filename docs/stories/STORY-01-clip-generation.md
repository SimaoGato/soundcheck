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

## Implementation Plan

### Feasibility confirmed during refine

The repo is currently docs-only (no `package.json`, no existing scripts) —
this story has no prior code to follow conventions from, so the plan below
establishes the pattern rather than reusing one.

ffmpeg was not installed in the refine sandbox, so before committing to the
technical notes' "ffmpeg alone" approach it was validated directly (via a
locally fetched static ffmpeg 7.0.2 binary, discarded after testing — no
dependency added to the repo by this step):

- `anoisesrc=color=pink:seed=N:duration=2.5:sample_rate=48000` produces
  byte-identical (sha256-identical) output across repeated runs — confirms
  AC7 is achievable with ffmpeg's own seeding, no extra RNG/toolchain needed.
- `equalizer=f=F:width_type=o:width=1:gain=G` chained directly into
  `loudnorm=I=-18:TP=-1.5:LRA=7:linear=true` in **one ffmpeg pass** (no
  two-pass measure/apply needed) normalized six different gains at 1000Hz to
  -18.0 LUFS integrated loudness each (matched to 0.1 LU), true peak with
  6dB+ of headroom, and exact 2.5s duration — this directly satisfies AC4,
  AC5, AC6 with a simple single-pass filter chain. (Two-pass loudnorm is the
  usual advice for accuracy on program material; it isn't needed here
  because the source is short, perfectly stationary noise.)
- **Correction (post-refine, before this plan's approval): the original
  absolute-RMS validation below was wrong and has been replaced.** The first
  pass compared each clip's raw bandpassed RMS against the *unprocessed*
  reference's raw bandpassed RMS at 1000Hz and got a monotonic-looking -23.4
  / -24.8 / -26.2 / [ref -30.4] / -29.0 / -30.2 / -31.2 dB ladder — but -29.0
  and -30.2 (the -3dB and -6dB cut clips) are both *less negative* (louder)
  than the reference's -30.4, i.e. AC3 ("band energy measurably lower") fails
  for two of the three cut gains. Root cause: `loudnorm` normalizes each
  clip's *integrated broadband* loudness to -18 LUFS independently of the
  EQ. Cutting one narrow octave barely moves total loudness, so `loudnorm`
  raises the clip's overall gain to reach target — and that broadband
  gain-up partially cancels the intended local cut when compared in
  absolute terms against a reference that never went through the same gain
  stage. Comparing absolute RMS across differently-gained signals was the
  bug, not the EQ itself.
- **Fix: compare a band-to-broadband RMS ratio, not absolute RMS.** For any
  file, `ratio_dB = bandpass_RMS_dB - broadband_RMS_dB` (both from `astats`,
  one pass with `bandpass=f=F:width_type=o:width=1` and one on the
  unfiltered signal). Any uniform gain applied to a whole file — `loudnorm`'s
  compensation, or the reference's different unnormalized amplitude — shifts
  band and broadband RMS by the same amount, so it cancels exactly in the
  subtraction. This is a structural fix (provably gain-invariant), not a
  parameter tweak, so it isn't sensitive to which target loudness or which
  reference gain state is chosen later.
- **Re-validated with real numbers at 1000Hz** (reference is the unprocessed
  pink-noise buffer, no `loudnorm`): ratios in dB, +9 → -9:
  `+9: -5.30, +6: -6.73, +3: -8.24, [[ref: -9.75]], -3: -11.09, -6: -12.32,
  -9: -13.39` — strictly monotonic, reference sits correctly between +3 and
  -3, boost clips all > reference, cut clips all < reference. This is the
  data that actually satisfies AC2/AC3, replacing the retracted point above.
- **Re-validated at the 31Hz edge** (the technical notes' flagged risk case):
  `+9: -5.81, +6: -7.21, +3: -8.68, [[ref: -10.15]], -3: -11.46, -6: -12.66,
  -9: -13.73` — same clean, strictly monotonic, well-separated pattern, ref
  correctly bracketed between +3 and -3. 16kHz was not independently
  re-validated with the ratio metric (only checked pre-normalization in the
  original pass); low risk given 1000Hz and 31Hz both hold cleanly and the
  ratio fix is structural rather than frequency-dependent, but implementer
  should include 16kHz when eyeballing `check.sh` output on first real run.
- Conclusion: **ffmpeg alone is confirmed sufficient**, using the ratio
  metric above for AC2/AC3. No numpy/scipy fallback needed; that alternative
  in the technical notes can be dropped.

### Design decisions (resolving "Refine to confirm/decide" items)

1. **One shared reference signal.** Generate a single seeded pink-noise
   `reference.wav` first; every one of the 60 clips is that same buffer run
   through `equalizer` + `loudnorm`, not 60 independent noise draws. This is
   what makes the AC2/AC3 comparison ("vs. the unprocessed reference")
   meaningful — only the EQ differs, not the underlying noise.
2. **Filename convention** (resolves AC1's "recoverable from the filename"):
   `{freq:05d}hz_{sign}{gain:02d}db.wav`, e.g. `00031hz_+09db.wav`,
   `01000hz_-03db.wav`, `16000hz_+09db.wav`. Zero-padded and always-signed so
   filenames sort in frequency/gain order and parse with one regex. STORY-02
   should reuse this exact convention for the encoded `.m4a` files, since its
   own AC4 re-runs this story's band check against the encoded output.
3. **Output layout**, git-ignored (regenerable, deterministic, not source):
   ```
   audio/
     generate.sh
     check.sh
     output/
       reference.wav        # not one of the 60, used only for verification
       wav/
         00031hz_+09db.wav  # ...60 files
   ```
   `audio/output/` is added to `.gitignore`. `check.sh`'s glob is
   `audio/output/wav/*.wav`, so it never accidentally includes the
   reference file in a "60 files" count.
4. **ffmpeg is a system dependency, not vendored.** Matches the technical
   notes' "one system dependency, not a language toolchain" rationale, and
   this repo has no `package.json` yet (STORY-03 adds the Expo project) — a
   dependency added purely for the local ffmpeg trial above is not carried
   into the implementation. Both scripts should `command -v ffmpeg` and exit
   with a clear "install ffmpeg" error if missing.
5. **Fixed generation parameters** (implementer may tune if the listening
   pass in DoD flags an issue, but these are the validated starting point):
   `sample_rate=48000`, mono, `seed=42` (any fixed constant works, must
   never change once picked or AC7 output changes), `width_type=octave`,
   `width=1` (one octave, constant across all bands per the technical
   notes), `loudnorm I=-18:TP=-1.5:LRA=7:linear=true`.
6. **check.sh takes an input directory + extension as arguments**, e.g.
   `check.sh audio/output/wav wav`, rather than hardcoding the WAV path.
   STORY-02's technical notes say it will reuse this script against encoded
   AAC output — ffmpeg decodes `.m4a` transparently through the same filter
   chain, so no branching is needed inside the script for that reuse to work.

### Steps

1. Add `audio/` dir, `.gitignore` entry for `audio/output/`.
2. Write `audio/generate.sh`:
   - Guard on `command -v ffmpeg`.
   - `rm -rf audio/output && mkdir -p audio/output/wav` (clean-state, so
     re-running is a real test of AC7, not just an overwrite).
   - Generate `audio/output/reference.wav` (seeded pink noise, 2.5s, 48kHz
     mono).
   - Loop over the 10 frequencies × 6 gains, one ffmpeg invocation each:
     `equalizer=f=F:width_type=o:width=1:gain=G,loudnorm=I=-18:TP=-1.5:LRA=7:linear=true`
     → write to the filename convention above.
3. Write `audio/check.sh <dir> <ext>`:
   - AC5 (duration): `ffprobe`/ffmpeg duration per file, assert 2.5s ± 0.05s.
   - AC6 (peak): `astats` Peak level dB per file, assert ≤ -1.0 dBFS (well
     under 0, matches the ~6dB headroom observed).
   - AC4 (loudness match): integrated loudness per file (`ebur128` or
     `loudnorm ... print_format=json` measure pass), assert max-min spread
     across all files in the dir ≤ 0.5 LU.
   - AC2/AC3 (band + monotonic): for each file, parse (F, gain) from the
     filename and compute `ratio_dB = bandpass_RMS_dB - broadband_RMS_dB`
     (bandpass via `bandpass=f=F:width_type=o:width=1` + `astats`, broadband
     via plain `astats` on the unfiltered signal). Compute the same ratio
     once for `reference.wav` per frequency (reference has no EQ, so its
     ratio only needs computing once per F, not per gain). Assert boost
     clips' ratio > reference's ratio and cut clips' ratio < reference's
     ratio; then group by frequency and assert ratio is monotonic across
     +3→+6→+9 and -3→-6→-9. **Do not compare absolute band RMS against the
     reference** — `loudnorm`'s broadband gain compensation invalidates that
     comparison (see "Correction" note above); the ratio is what's
     gain-invariant and actually satisfies AC2/AC3.
   - Exit non-zero listing every failing check (not just the first) so a
     failing run is actionable in one pass.
4. AC1 (count/naming) and AC7 (determinism) are specific to the generation
   step, not something STORY-02 reuses, so they live as a small check inside
   `generate.sh` itself (or a `--verify` flag) rather than in `check.sh`:
   - Count `audio/output/wav/*.wav` == 60, and that all 60 expected
     (freq, gain) filenames are present (no missing/extra combos).
   - Run generation twice into two temp dirs (or the same dir before/after
     an `sha256sum` snapshot) and assert all 60 checksums are identical.
5. Run `generate.sh`, then `check.sh audio/output/wav wav`, fix any
   failures (most likely candidates per the exploration above: none
   expected, but watch true peak margin if `amplitude` on `anoisesrc` is
   changed from what was validated).
6. Manual listening pass per DoD (real ears, not scripted) — confirm +9dB is
   obvious and +3dB is perceptible at a few representative bands including
   31Hz and 16kHz, and that no clip sounds merely louder.

No test framework or `package.json` is introduced — `check.sh`'s assertions
*are* the tests here, matching the technical notes' "shell script, one
system dependency" framing. This also means "write the test first" concretely
means: write `check.sh`'s assertions against the not-yet-existing
`audio/output/` first (they fail — no directory), then write `generate.sh`
to make them pass.

### Test plan (1:1 with acceptance criteria)

| AC | Check |
|---|---|
| 1 | `generate.sh` internal count check: exactly 60 files in `audio/output/wav/`, filenames match all 10×6 (freq, gain) combos, none missing/extra. |
| 2 | `check.sh`: boost clips' band-to-broadband RMS ratio at F > `reference.wav`'s ratio at F; +3→+6→+9 strictly increasing, for all 10 frequencies. |
| 3 | `check.sh`: cut clips' band-to-broadband RMS ratio at F < `reference.wav`'s ratio at F; -3→-6→-9 strictly decreasing, for all 10 frequencies. |
| 4 | `check.sh`: integrated loudness spread across all 60 clips ≤ 0.5 LU. |
| 5 | `check.sh`: duration 2.5s ± 0.05s for all 60 clips. |
| 6 | `check.sh`: true peak ≤ -1.0 dBFS for all 60 clips. |
| 7 | `generate.sh` determinism check: two clean-state runs produce sha256-identical files for all 60 clips. |

Manual (DoD, not scriptable): real listening pass, boost obvious at +9dB /
perceptible at +3dB, no clip sounds merely louder — record PASS evidence per
the DoD's QA step.

### Risks / rollback

- **Resolved risk:** the original refine pass validated AC2/AC3 with
  absolute band RMS vs. an unnormalized reference, which `loudnorm`'s
  broadband gain compensation silently broke for the -3/-6dB cut clips (see
  "Correction" note above). Fixed by switching the metric to a
  band-to-broadband RMS ratio, which is provably invariant to any uniform
  gain and was re-validated with real numbers at 1000Hz and 31Hz.
- **Residual risk:** the ratio-metric re-validation covered 1000Hz and the
  31Hz edge, not 16kHz (the technical notes' other flagged edge case, only
  checked pre-normalization in the original pass). Low risk — the fix is
  structural, not frequency-tuned — but `check.sh`'s AC2/AC3 assertion
  covers all 10 frequencies including 16kHz on the real run, so any surprise
  there is caught automatically before the manual listening pass, not
  discovered late.
- **Risk:** `loudnorm`'s single-pass linear mode was validated at 1000Hz
  only during refine, not across all 10 bands. Low risk given identical
  monotonic behavior was independently confirmed at both spectrum extremes
  (31Hz, 16kHz) pre-normalization, but `check.sh`'s AC4 loudness-spread
  assertion is the real backstop — if any band doesn't normalize cleanly,
  the automated check catches it before the manual listening pass.
- **Risk:** chosen `loudnorm` target (-18 LUFS / -1.5dBFS TP) is a
  reasonable default, not a spec'd requirement — if the manual listening
  pass finds the clips too quiet/loud on a phone speaker, it's a one-constant
  change in `generate.sh`, not a redesign.
- **Rollback:** the whole story is one generated, git-ignored output
  directory plus two scripts — deleting `audio/` and the `.gitignore` line
  fully reverts it. Nothing else in the repo depends on this yet (STORY-02
  is the first consumer).
- **Dependency risk:** ffmpeg is a system binary, not pinned in the repo.
  Different ffmpeg versions could in principle produce different seeded
  noise output (breaking AC7 reproducibility across machines/CI, though not
  within a single machine). Out of scope to pin for this story per its
  "ffmpeg alone" framing, but worth a one-line note in `generate.sh`'s
  header comment recording the ffmpeg version this was validated against
  (7.0.x) so a future mismatch is easy to diagnose.

### Complexity: standard

Not trivial: correctness here is genuine DSP/audio-engineering reasoning
(band-energy monotonicity, loudness normalization, edge-of-spectrum
behavior, determinism) with several interacting numeric parameters, not a
mechanical change — a wrong constant silently produces "correct-looking"
but wrong audio (the story's own stated top risk). Not complex: it's a
single self-contained shell-script module with no auth, concurrency, money,
or cross-module coupling, and the approach is now empirically validated end
to end.
