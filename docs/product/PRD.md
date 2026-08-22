# PRD: Soundcheck

**Status:** Draft — pending confirmation
**Author:** Simão Vale de Gato
**Date:** 2026-08-22

## Problem & context

Live sound engineers (FOH techs) and church/venue AV volunteers need to identify
problem frequencies by ear, fast — e.g. ringing out a monitor or finding
feedback during soundcheck. That's a trained skill, and there's no good way to
practice it outside of live gigs.

Existing EQ ear-training apps (Freqy, MixSense, eqTrainer, Quiztones — all
iOS) frame the skill as "train your ears for music production/mixing." That
framing doesn't speak to the live-sound audience: different vocabulary,
different urgency (finding feedback in seconds vs. polishing a mix), different
context (a volunteer with five minutes before a service, not a producer at a
DAW). None of them are positioned for, or marketed to, FOH/church AV.

## Target users / personas

- **FOH technician** — semi-pro or full-time, wants to sharpen frequency ID
  speed for soundcheck and live troubleshooting. Already knows EQ theory;
  wants reps.
- **Church AV volunteer** — non-professional, runs sound for services on a
  rotation, often self-taught. Wants practical, low-jargon training that maps
  directly to "why is that mic feeding back."

Both personas want short, repeatable practice sessions (a few minutes),
on a phone, without needing headphones/studio gear to get value.

## Goals and non-goals

**Goals**
- Ship a focused, genuinely useful EQ frequency ID trainer to the Play Store,
  positioned for live-sound/AV, not music production.
- Free tier playable indefinitely and enjoyable on its own — not a demo stub.
- One-time IAP unlock as the sole monetization path.
- Solo-buildable in about a week.

**Non-goals (explicit, v1)**
- No iOS version.
- No accounts, login, or cloud sync.
- No leaderboards or social features.
- No ads, no subscription.
- No other ear-training exercise types (compression, reverb, panning,
  distortion) — that's a possible post-v1 direction, not v1 scope.
- No real-time DSP / live audio processing.

## Success metrics

- **Installs** and **IAP conversion rate** (% of installs that purchase the
  €0.99 unlock) — the direct monetization signal.
- **D1/D7 retention** — whether people come back to actually train, not just
  try it once.
- No formal launch target set; these are the numbers to watch post-launch,
  not a go/no-go gate for v1 shipping.

## Key user journeys

1. **First open (free tier)** — user opens app, no signup, immediately sees
   a "start" affordance. First question plays automatically or on tap: a
   clip with one of {125Hz, 1kHz, 8kHz} boosted +9dB. User picks from
   multiple choice, gets instant right/wrong feedback. On wrong, sees the
   correct answer plus a plain-language relationship to their guess (e.g.
   "You picked 250Hz — the correct answer, 1kHz, is about 2 octaves higher").
   Unlimited replay, no session limit, no ads interrupt.
2. **Discovering the paywall** — after every 5 questions answered, user sees
   a small dismissible banner (not a hard gate) that the full version has
   10 bands, cuts, more gain levels, adjacent-frequency hard mode, and a
   difficulty ladder, for a one-time €0.99. Never blocks play; easy to
   dismiss; reappears on the same cadence. No dark patterns, no modal nags.
3. **Purchase and unlock** — user taps unlock, Google Play Billing purchase
   flow via RevenueCat, unlock applies instantly and persists locally
   (no login) even across app reinstall via Play's purchase restore.
4. **Full-tier play** — user works through difficulty progression (obvious →
   intermediate → advanced → expert → cuts), practicing frequency ID under
   increasingly subtle conditions.

## Functional requirements

1. App presents a multiple-choice question: play a 2–3 second audio clip
   with exactly one frequency band boosted or cut from a flat reference;
   user selects which band/frequency they heard from a set of choices.
2. Instant feedback per answer: correct/incorrect, plus (on incorrect) the
   correct answer and its relationship to the user's guess (e.g. octave
   distance, "higher/lower").
3. Frequency set: standard 10-band graphic EQ — 31/62/125/250/500/1k/2k/4k/
   8k/16k Hz.
4. **Free tier:** 3 bands (125Hz, 1kHz, 8kHz), fixed +9dB boost only,
   unlimited play, no ads, no time/session cap.
5. **Paid tier (unlocked via one-time IAP):** all 10 bands; cuts as well as
   boosts; gain levels +9/+6/+3dB and -3/-6/-9dB; adjacent-frequency hard
   mode (choices are neighboring bands, not spread across the spectrum);
   difficulty progression: obvious → intermediate → advanced → expert → cuts.
   Choice-count ladder (widens then narrows to force fine discrimination at
   the top):

   | Tier | Choices | Gain | Notes |
   |---|---|---|---|
   | Obvious | 3, widely spaced (e.g. low/mid/high) | +9dB | |
   | Intermediate | 5, moderate spacing | +9/+6dB | |
   | Advanced | 7, most of the 10-band set | +6/+3dB | |
   | Expert | 10 (full band set) | +3dB | adjacent-hard mode on |
   | Cuts | 10 (full band set) | -3/-6/-9dB | cuts only, adjacent-hard mode on |

6. Paywall UX: a small dismissible banner appears every 5 questions for
   free-tier users, advertising the full unlock. Never blocks play; no
   modal interruptions; also reachable any time via a persistent "Get full
   version" entry point in the UI.
7. IAP: single non-consumable purchase, €0.99, via RevenueCat wrapping
   Google Play Billing. Purchase state persists locally and restores via
   Play's standard purchase restore (no custom account system).
8. Audio playback uses pre-generated static clips (one per frequency ×
   gain combination), bundled as app assets — no real-time DSP at runtime.
   Base signal is pink noise (full-spectrum reference, standard for EQ
   testing, and the most objectively teachable signal for frequency ID —
   chosen over a synthetic pad/chord, which is more pleasant but has
   sparser harmonic content that makes some bands inconsistently audible).
   Clip spec: 2.5s, mono, AAC ~64kbps (~20KB/clip). Paid-tier matrix is
   10 frequencies × 6 gain levels = 60 clips (free tier's 3 clips are a
   subset) ≈ 1.2MB total — negligible bundle impact.
9. Local-only progress/state (e.g. last difficulty level reached, purchase
   flag) via AsyncStorage. No backend, no accounts.
10. App works fully offline after install (all audio assets bundled).

## Non-functional requirements

- **Performance:** clip playback starts with no perceptible delay
  (<200ms) after the user taps play/next; app cold start under ~2s on a
  mid-range Android device.
- **Platform:** Android only, v1. Target current Play Store minimum API
  level per Expo SDK's supported range at build time.
- **Audio quality:** pink noise base signal (see FR8), 2.5s mono AAC clips
  — must be tolerable to hear dozens of times in a session; sanity-check
  with real listening once the asset matrix is generated, since pink noise
  fatigue is a known risk even though it's the more teachable signal.
- **Accessibility:** legible text sizing and color contrast for outdoor/
  stage lighting conditions (a real use case: volunteers checking a phone
  in a bright sanctuary or venue); no reliance on color alone for
  correct/incorrect feedback (also use icon/text).
- **i18n:** English only for v1; no i18n infrastructure required now.
- **Privacy/legal:** no accounts, no PII collected, no analytics SDK unless
  added deliberately later. Standard Play Store content rating (general
  audience, not directed at children) — default IARC questionnaire
  answers apply. Play Billing purchase handling must follow Google Play's
  IAP policy (real product, delivers stated value, restorable).
- **Asset size:** 60-clip matrix (10 frequencies × 6 gain levels), 2.5s
  mono AAC ~64kbps each, ≈1.2MB total bundled — see FR8. No further
  bitrate/format tuning expected to be necessary at this size.

## Constraints, assumptions, open questions

**Constraints**
- Solo build, ~1 week of effort.
- Tech stack fixed: Expo (React Native) + TypeScript, expo-audio,
  react-native-purchases (RevenueCat) + Google Play Billing, AsyncStorage,
  EAS Build + EAS dev client (Expo Go can't test native IAP).

**Assumptions**
- A pre-generated clip matrix (not live DSP) is acceptable audio quality
  for the training purpose — the app is teaching relative pitch/frequency
  recognition, not mix-accurate EQ.
- €0.99 one-time price is viable without ads or subscription to sustain a
  solo hobby-scale app (no revenue target set — see Success metrics).
- Pink noise, while more clinical than a musical pad, is worth the
  trade-off for teaching accuracy; will revisit if real listening proves
  it fatiguing over a full session.

**Open questions**
1. App icon and final branding treatment for "Soundcheck" — not yet
   designed.
2. Play Store name-availability/trademark check for "Soundcheck" — not yet
   done; needs to happen before store submission, not before build.

## Rough scope / phasing

**v1 (this PRD, ~1 week solo)**
- Free tier: 3-band, fixed +9dB boost, multiple choice, instant feedback
  with octave-relationship explanation.
- Paid tier: full 10-band, boosts + cuts, 6 gain levels, adjacent-frequency
  hard mode, difficulty progression.
- One-time €0.99 IAP via RevenueCat/Play Billing.
- Pre-generated static audio asset matrix.
- Local-only state, no backend, Android only.

**Explicitly post-v1 (not scoped now, only if traction warrants it)**
- Broader ear-training platform: compression, reverb, panning, distortion
  detection.
- iOS version.
- Cloud sync / accounts / leaderboards.
