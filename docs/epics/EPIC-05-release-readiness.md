# EPIC-05: Release readiness

**Depends on:** EPIC-01, EPIC-02, EPIC-03, EPIC-04 (ships what they built)

## Goal

Everything between "the app works on my device" and "it's live on the Play
Store": app identity (name, icon, branding), the EAS production AAB, Play
Console listing and declarations, and the pre-submission checks the PRD
left open.

## Why it matters

A one-week solo build dies in the last mile — store listing copy, content
rating questionnaires, and signing config are the unglamorous work that
blocks launch entirely. This epic also closes the PRD's two remaining open
questions (icon/branding, and the "Soundcheck" name availability check),
both of which are cheap now and expensive after submission.

## Scope (in)

- App icon, splash, and basic branding treatment.
- Play Store name-availability / trademark check for "Soundcheck"
  (PRD open question 2) — resolve *before* submitting.
- EAS Build production AAB with correct signing and versioning.
- Play Console listing: title, short/full description, screenshots,
  feature graphic — written in FOH/church-AV language, matching the
  positioning that separates this from producer-oriented competitors.
- Content rating (IARC questionnaire, general audience) and Data Safety
  declaration (no data collected, no accounts).
- Target API level compliance per current Play requirements.
- Final pre-submission pass on a real device: offline behavior, cold start
  under ~2s, purchase and restore on a production-track build.

## Out of scope

- iOS / App Store submission (explicit PRD non-goal).
- Analytics or crash-reporting SDKs (NFR: none in v1).
- Marketing beyond the store listing itself.
- Localized listings — English only for v1.

## Acceptance signals

- "Soundcheck" confirmed usable as the store name, or a replacement chosen
  and applied everywhere.
- Signed production AAB builds reproducibly via EAS.
- Listing complete and passing Play Console review checks.
- Content rating and Data Safety declarations submitted and accurate.
- Install from a production-track build works offline and completes a real
  purchase + restore.
- App is live (or submitted and pending review).

## Candidate stories

- App icon, splash, and branding
- "Soundcheck" name availability / trademark check
- EAS production build config, signing, versioning
- Play Console listing copy and screenshots
- Content rating + Data Safety declarations
- Pre-submission device verification pass
