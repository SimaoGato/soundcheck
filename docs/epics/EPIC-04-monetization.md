# EPIC-04: Monetization — one-time unlock

**Depends on:** EPIC-02 (a running app to gate); soft dependency on
EPIC-03 (what the unlock reveals — the entitlement flag can be built and
tested before that content lands)

## Goal

A single non-consumable €0.99 purchase via RevenueCat over Google Play
Billing that unlocks the full tier, persists locally, restores on
reinstall, and is advertised by a non-blocking dismissible banner every 5
questions plus a persistent "Get full version" entry point.

## Why it matters

It's the only revenue path — no ads, no subscription — and one of the
stated differentiators against competitors' subscription/XP-grind models.
It's also the epic with the most external-system risk: Play Console
product setup, RevenueCat configuration, and the fact that IAP can't be
tested in Expo Go at all (requires an EAS dev client), so it needs real
device testing rather than simulator confidence.

## Scope (in)

- RevenueCat (`react-native-purchases`) integration.
- Play Console: non-consumable product configured at €0.99.
- Purchase flow: initiate, handle success, handle cancel, handle failure.
- Entitlement state persisted locally (AsyncStorage) and gating the
  EPIC-03 content.
- Restore purchases (reinstall / new device with same Play account).
- Paywall banner: dismissible, appears every 5 answered questions for
  free-tier users, never blocks play, no modals.
- Persistent "Get full version" entry point in the UI.
- EAS dev client build so billing can actually be exercised on-device.

## Out of scope

- Ads of any kind (explicit PRD non-goal).
- Subscriptions, consumables, tiered pricing, promo codes, or free trials.
- Server-side receipt validation / any backend — local entitlement only,
  per PRD FR7/FR9.
- Accounts or login to carry the purchase (Play handles it).
- Analytics on paywall conversion — no analytics SDK in v1 (NFR);
  conversion is read from Play Console.

## Acceptance signals

- A real purchase on a device completes and unlocks full-tier content
  immediately, without restart.
- Cancelling or failing a purchase leaves the app in free tier, playable,
  with no error state that blocks play.
- Uninstall/reinstall restores the unlock without any login.
- Free-tier banner appears on the 5-question cadence, dismisses cleanly,
  and never gates a question.
- Paid users never see the banner.
- Play Billing behavior conforms to Play IAP policy (real product,
  delivers stated value, restorable — NFR privacy/legal).

## Candidate stories

- RevenueCat SDK integration + EAS dev client build
- Play Console non-consumable product setup (€0.99)
- Purchase flow: success, cancel, failure paths
- Local entitlement persistence and content gating
- Restore purchases
- Paywall banner (5-question cadence, dismissible)
- Persistent "Get full version" entry point
