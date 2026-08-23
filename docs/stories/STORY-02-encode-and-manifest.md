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

Depends on STORY-01 (needs its output to encode). Soft coupling, not
blocking: this story's asset layout (`assets/` at repo root) anticipates
STORY-03's not-yet-decided Expo scaffold location (STORY-03 is still
`status: draft` — no app or bundler exists yet). AC7 below is scoped to the
structural guarantee this story can actually verify without an Expo project
existing; see Implementation Plan design decision 2 for the reasoning and
`git mv` fallout if STORY-03 lands with a different layout.

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
7. Given the manifest and the asset directory, when inspected, then every
   one of the 60 clips is referenced by a literal `require('./clips/...')`
   call — not a dynamically constructed path — and the referenced file is
   committed to the repo as a static asset. This is the structural
   precondition Metro (the Expo/React Native bundler) needs to bundle every
   clip with no runtime download (PRD FR10). No Expo project exists yet
   (STORY-03 is still `status: draft`), so this story cannot inspect an
   actual built app bundle — full behavioral confirmation that a running app
   contains and plays these clips offline is STORY-04 AC5's job, once
   STORY-03 and STORY-04 exist.

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

## Implementation Plan

### Feasibility confirmed during refine (real numbers, not assumed)

No `## Design references` section exists on this story — skipped that step.

ffmpeg wasn't installed in the refine sandbox (same situation as STORY-01);
fetched the same static ffmpeg 7.0.2 binary, used it to actually generate
STORY-01's 31Hz and 16kHz clips and encode them with ffmpeg's **native**
`aac` encoder (not `libfdk_aac` — Ubuntu's `apt-get install ffmpeg`, which is
what CI uses, does not ship `libfdk_aac` for licensing reasons, so the native
encoder is the only one available in CI and must be what's validated),
discarded after testing:

- **The story's flagged risk is real and precisely located.** Using STORY-01's
  exact `check.sh` band-to-broadband ratio metric, at 64kbps native-AAC:
  - 31Hz: ratios (ref -10.15dB) run +9=-5.80→+6=-7.21→+3=-8.51dB (cut side
    -11.23→-12.45→-13.50dB) — clean, monotonic, well clear of the reference
    on both sides (smallest margin ~1.64dB at +3dB). **No risk at 31Hz.**
  - 16kHz: ratios (ref -10.03dB) run +9=-6.06→+6=-7.66→**+3=-9.55dB** (cut
    side -12.91→-14.24→-15.45dB) — still monotonic and technically on the
    correct side of the reference, but the **+3dB boost margin over the
    reference is only 0.48dB** at 64kbps (vs. 3.97dB at +9dB and 2.37dB at
    +6dB). That's not a comfortable pass, it's a near-miss that a slightly
    different ffmpeg build or measurement window could flip.
  - Re-encoding the same 16kHz clips at 128kbps native-AAC fixes this
    cleanly: +3dB ratio becomes -8.39dB vs. the same -10.03dB reference — a
    1.64dB margin, matching the WAV original almost exactly (-8.37dB). Every
    other 16kHz gain also moves closer to its WAV value at 128k.
  - Conclusion, resolving the technical notes' "if 16kHz fails AC4, prefer
    raising the bitrate" contingency in advance: **ship 16kHz at 128kbps by
    default**, not conditionally after a CI failure. The 0.48dB margin at
    64kbps is too close to trust as "passing" — this isn't a parameter to
    leave for the implementer to discover via a failing check.sh run, it's
    already known to be marginal.
- **Duration/mono/codec survive encoding cleanly.** `ffprobe` on the
  encoded files: `codec_name=aac`, `channels=1`, `sample_rate=48000`,
  `duration=2.500000` exactly (ffmpeg's edit-list handling of AAC encoder
  priming/padding is transparent here) — no tolerance-loosening needed
  versus STORY-01's `check.sh` duration constant.
- **Size budget has large headroom.** 12 sample clips (31Hz + 16kHz, all 6
  gains) at 64kbps averaged 21.6KB/clip; scaling to the full 60-clip matrix
  with 16kHz's 6 clips bumped to 128kbps estimates ≈1.35MB total — comfortably
  under a 2MB ceiling (see Design decision 5) despite the bitrate bump.
- **Bitrate reporting:** `ffprobe`'s `format=bit_rate` includes container
  overhead and reads high for a file this short (69.2kbps for a 64kbps
  clip); `stream=bit_rate` reads close to nominal (64.6kbps). AC2's bitrate
  check should read `stream` bit_rate with a generous tolerance (native AAC
  isn't strict CBR), not `format` bit_rate.

### Design decisions (resolving "Refine to confirm" items)

1. **Manifest format: generated TypeScript module, confirmed.** The
   technical notes' reasoning holds independent of whether an Expo project
   exists yet: Metro (React Native/Expo's bundler) only bundles assets
   referenced via a **static, literal** `require('./relative/path.ext')`
   call — it cannot resolve a `require()` built from a variable/template
   string at bundle time. So the manifest generator must emit one literal
   `require(...)` line per clip, not a runtime path-construction function.
   This is a general, stable Metro behavior, not something that needs a live
   Expo project to confirm.
2. **Known gap, not a blocker: no Expo project exists yet — this is why
   AC7 was narrowed to a structural claim (see Acceptance criteria above).**
   STORY-03 (Expo scaffold, still `status: draft`) hasn't run. This story
   cannot `tsc`/lint the generated manifest and cannot build a Metro bundle
   to inspect, so AC7's literal target is now "every clip is a committed
   static asset referenced by a literal `require()`" — the precondition for
   Metro bundling, which this story can fully verify against real files —
   rather than "inspect an app bundle," which it cannot. Full behavioral
   verification (a running app actually contains and plays all 60 clips with
   no network) is explicitly STORY-04 AC5's job, not this story's, and
   STORY-04 already depends on both STORY-02 and STORY-03 for exactly this
   reason. Separately, this story is choosing a file layout (`assets/` at
   repo root) that anticipates STORY-03's own technical notes ("Affected
   areas: repo root... `App.tsx`/`app/` entry"), i.e. an Expo scaffold
   created **at repo root**, matching `create-expo-app`'s default `assets/`
   folder location. This mirrors STORY-01's precedent of shipping without a
   `package.json`-based toolchain (shell assertions stood in for `tsc`/tests
   there); the same pattern is used here. **Flagging this explicitly rather
   than guessing silently** — if Refine/Challenge disagrees with running
   STORY-02 before STORY-03, or wants a different root asset path, that's the
   one call in this plan most worth double-checking, but it isn't a reason to
   stop: the layout choice is cheap to `git mv` later if STORY-03 lands
   differently, and everything else in this story (encode correctness, size,
   manifest self-consistency, and the now-narrowed AC7) is independently
   testable and fully passable without an Expo project existing.
3. **Two-tier output: git-ignored scratch, then a committed publish step.**
   - `audio/output/aac/` — new, git-ignored (add to the existing
     `audio/output/` ignore, no `.gitignore` change needed), sibling of
     `wav/` under `audio/output/`. This is where `encode.sh` writes and
     where `check.sh` is re-run unmodified, exactly matching STORY-01's
     design decision #6 contract ("place encoded output at
     `audio/output/<format>/`... for reference.wav resolution to work
     without changes to `check.sh`").
   - `assets/audio/clips/*.m4a` and `assets/audio/manifest.ts` — new,
     **committed to git** (not ignored). These are the actual shipped
     assets: unlike STORY-01's WAV intermediates, they need to exist without
     regeneration for a plain app build, and committing them means EAS Build
     never needs ffmpeg installed. `manifest.sh` publishes into this
     directory only after `audio/output/aac/` has passed `check.sh`, as a
     byte-identical `cp` (not a re-encode), so verifying the scratch copy is
     sufficient — no need to re-run `check.sh` against the published copy.
4. **Filename convention carried over unchanged**, `.m4a` extension:
   `{freq:05d}hz_{sign}{gain:02d}db.m4a`, e.g. `00031hz_+09db.m4a` — same
   regex STORY-01's `check.sh` already parses (extension is a script
   parameter), so `check.sh audio/output/aac m4a` works with zero code
   changes to `check.sh`.
5. **Bitrate: 64kbps default, 128kbps override for the 16000Hz frequency**
   (all 6 gains at that frequency, not just the marginal +3dB one — simpler
   and more robust than a per-gain override for one frequency's near-miss).
   `CEILING_BYTES = 2_000_000` (2MB) as the hard AC3 assertion — comfortably
   above the ≈1.35MB estimate above, matching the technical notes' "size
   budget has ample room." The ≈1.2MB PRD figure is logged, not asserted, as
   an informational target.
6. **`assets/audio/manifest.ts` shape:**
   ```ts
   // GENERATED FILE — do not hand-edit. Regenerate via `audio/manifest.sh`.
   export const FREQUENCIES = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000] as const;
   export type Frequency = (typeof FREQUENCIES)[number];

   export const GAINS = [9, 6, 3, -3, -6, -9] as const;
   export type Gain = (typeof GAINS)[number];

   type ClipKey = `${Frequency}_${Gain}`;

   export const CLIPS: Record<ClipKey, number> = {
     "31_9": require('./clips/00031hz_+09db.m4a'),
     "31_6": require('./clips/00031hz_+06db.m4a'),
     // ...60 literal entries total
     "16000_-9": require('./clips/16000hz_-09db.m4a'),
   };

   export function getClip(frequency: Frequency, gain: Gain): number {
     return CLIPS[`${frequency}_${gain}` as ClipKey];
   }
   ```
   `Record<ClipKey, number>` with all 60 literal keys present means a future
   `tsc` run (once STORY-03 exists) rejects a missing/extra key for free —
   the "compile-time checking" the technical notes wanted. `getClip` is the
   single lookup function playback code (EPIC-02) calls; no other per-clip
   metadata is added, per this story's "out of scope."

### Steps (test-first: `check.sh` reuse + self-checks are written/reasoned
about before the scripts they check)

1. Write `audio/encode.sh`:
   - Guard `command -v ffmpeg`, `command -v ffprobe`, and the same bash 4+
     guard `check.sh` uses (associative array for the bitrate-override map).
   - `rm -rf audio/output/aac && mkdir -p audio/output/aac` (clean state).
   - `DEFAULT_BITRATE=64k`; `declare -A BITRATE_OVERRIDE=( [16000]=128k )`.
   - Loop the 10×6 matrix, one `ffmpeg -i <wav> -c:a aac -b:a <bitrate> -ac 1
     -ar 48000 <aac>` per clip, bitrate looked up per-frequency from the map
     (default if absent).
   - Self-verify (mirrors `generate.sh`'s `verify_matrix`/AC1 pattern, new
     checks here since `check.sh` doesn't cover these):
     - AC1: exactly 60 `.m4a` files, one per WAV source, same
       (freq, gain) filename set as `audio/output/wav/*.wav`.
     - AC2 (mono/bitrate — duration is covered by `check.sh` below):
       `ffprobe` per file: `channels == 1`; `stream=bit_rate` within a
       generous tolerance (e.g. ±20%) of that file's expected bitrate from
       the same override map.
2. Run `check.sh audio/output/aac m4a` unmodified — covers AC2's duration
   and AC4 (band-ratio direction/monotonicity, reference resolved from
   `audio/output/reference.wav` automatically). All 10 frequencies are
   checked every run, so 16kHz and 31kHz are covered without special-casing;
   call this out explicitly when recording AC4 evidence.
3. Write `audio/manifest.sh`:
   - `rm -rf assets/audio && mkdir -p assets/audio/clips` (clean state,
     mirrors STORY-01's pattern).
   - Copy `audio/output/aac/*.m4a` → `assets/audio/clips/` (plain `cp`, byte
     for byte — no re-encode).
   - AC3: sum bytes of `assets/audio/clips/*.m4a`, log against the ≈1.2MB
     PRD figure, assert `<= CEILING_BYTES` (2,000,000).
   - Generate `assets/audio/manifest.ts` per the shape in design decision 6,
     iterating the same 10×6 matrix.
   - Self-verify AC5/AC6 by re-deriving the expected file list from the same
     loop (not by loading the `.ts` module — Node can't `require()` a
     `.m4a`): assert exactly 60 `require('./clips/...')` lines were written,
     each with a literal path (grep the generated file, reject anything
     that isn't `require\('\./clips/[0-9]{5}hz_[+-][0-9]{2}db\.m4a'\)` —
     this also structurally enforces AC7's "static references" requirement);
     assert every referenced filename exists in `assets/audio/clips/`; assert
     `assets/audio/clips/*.m4a` has no files absent from that reference list
     (orphan check, both directions per AC6).
4. Wire both scripts into `.github/workflows/audio-checks.yml` as new steps
   after the existing generate/check steps (`./audio/encode.sh`, then
   `./audio/check.sh audio/output/aac m4a`, then `./audio/manifest.sh`), and
   widen the workflow's `paths:` filters to include `assets/audio/**` too —
   otherwise a direct edit to committed assets/manifest without touching
   `audio/**` wouldn't retrigger CI.
5. Add `audio/manifest.assertions.test.sh` (mirrors
   `check.assertions.test.sh`'s mutation-test pattern per CLAUDE.md's
   "Conventions & gotchas"): stub a fake `assets/audio/clips/` with a
   missing file and an extra orphan file, assert `manifest.sh`'s self-check
   catches both directions (this is exactly the "silent failure in shell
   logic" class of bug that convention calls out).
6. Run the full local pipeline (`generate.sh` → `encode.sh` → `check.sh
   audio/output/aac m4a` → `manifest.sh`) once, confirm the 16kHz/31kHz AC4
   numbers land in the same neighborhood as the refine validation above (a
   different ffmpeg version, e.g. CI's apt 6.1.x vs. this refine's static
   7.0.x, could shift results slightly — that's the residual risk below).
   Fix the actual bitrate/margins if the real run disagrees materially with
   the refine estimates.
7. `git add assets/audio/` — this is the one place in this story where
   generated output is committed rather than git-ignored (see design
   decision 3); call that out in the PR description so it doesn't read as
   an accidental binary commit.

### Test plan (1:1 with acceptance criteria)

| AC | Check |
|---|---|
| 1 | `encode.sh` self-check: 60 `.m4a` files, one per WAV source, same (freq, gain) set. |
| 2 | `encode.sh` self-check: mono (`channels==1`) + bitrate within tolerance of the per-frequency target (64k default, 128k for 16000Hz). `check.sh audio/output/aac m4a`: duration 2.5s ± 0.05s (reused unmodified). |
| 3 | `manifest.sh`: total bytes of `assets/audio/clips/*.m4a` ≤ 2,000,000 (CEILING_BYTES), logged against the ≈1.2MB PRD target. |
| 4 | `check.sh audio/output/aac m4a`: band-to-broadband ratio vs. reference, correct direction + monotonic, for all 10 frequencies including 16kHz and 31kHz explicitly called out in QA evidence. 16kHz ships at 128kbps specifically because 64kbps's margin was empirically too thin during refine (0.48dB) — re-verify this margin on the real (non-refine-sandbox) ffmpeg build in CI. |
| 5 | `manifest.sh` self-check: exactly 60 literal `require()` entries in `manifest.ts`, each resolving to a file that exists in `assets/audio/clips/`. |
| 6 | `manifest.sh` self-check: no file in `assets/audio/clips/` is absent from the manifest's reference list, and no manifest entry references a missing file (both directions). `audio/manifest.assertions.test.sh` mutation-tests both directions of this. |
| 7 | `manifest.sh` self-check (same grep-assertion as AC5): every one of the 60 manifest entries is a literal `require('./clips/...')` string, not a dynamic path, and every referenced file is committed under `assets/audio/clips/` (not git-ignored). This is a full, exercisable PASS against real files/scripts — not a partial or deferred check — for the structural claim AC7 as written now makes. The separate behavioral claim ("a running app actually plays all 60 clips offline") is out of scope for AC7 as revised; that is STORY-04 AC5's job once STORY-03 and STORY-04 exist. |

### Risks / rollback

- **Residual risk: refine's ffmpeg (7.0.2 static) isn't CI's ffmpeg
  (Ubuntu 24.04 apt, 6.1.x, per STORY-01's pin).** The 16kHz +3dB margin at
  64kbps (0.48dB) was already too thin to trust from a *different* build
  than CI's; the 128kbps override was chosen instead of "wait and see if
  check.sh fails," but the real numbers should still be confirmed once this
  runs in CI/locally against the pinned ffmpeg version, per Step 6.
- **Risk: native AAC encoder is required, `libfdk_aac` is not available.**
  Worth a one-line comment in `encode.sh` (mirroring `generate.sh`'s ffmpeg
  version note) so a future implementer doesn't "improve" quality by
  switching encoders and silently invalidating the refine validation above.
- **Layout risk (flagged, not blocking):** `assets/` at repo root assumes
  STORY-03 scaffolds Expo at repo root with `create-expo-app`'s default
  asset location. If Challenge/a human disagrees, `git mv assets/ <new
  path>` plus updating `manifest.sh`'s output path is the only fallout —
  nothing else in this story depends on the exact path.
- **AC7 scope risk (resolved by narrowing the story's AC7 text, not just
  this plan):** the original AC7 wording ("app bundle, when inspected")
  could not be satisfied or QA'd against running code because no Expo
  project exists yet — that would have been a silent partial-pass against
  the DoD in CLAUDE.md. AC7 has been rewritten in the Acceptance criteria
  section above to the structural guarantee this story actually delivers
  (committed assets + literal `require()` manifest entries); the full
  behavioral "no runtime download" verification is STORY-04 AC5's
  responsibility, not implicitly assumed here.
- **Rollback:** `audio/encode.sh`, `audio/manifest.sh`, their `.test.sh`
  files, the new `audio/output/aac/` (git-ignored, nothing to revert) and
  `assets/audio/` (committed — `git rm -r assets/`) are fully self-contained
  additions; deleting them and the two new CI workflow steps fully reverts
  this story without touching STORY-01's files.

### Complexity: standard

Not trivial: real codec-behavior risk with a measured near-miss (16kHz
+3dB margin at 64kbps), a cross-cutting file-layout decision that
anticipates a not-yet-existing app scaffold, and committed-binary-asset
generation with a bidirectional consistency check (AC6) — genuine reasoning
risk, not mechanical. Not complex: single-repo, no auth/concurrency/money,
and it's an additive script pair following STORY-01's already-established
pattern closely, with the hardest empirical question (does band emphasis
survive AAC?) already answered with real numbers during this refine pass.
