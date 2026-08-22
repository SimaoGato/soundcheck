---
id: STORY-03
epic: EPIC-02
status: draft
pr: null
---

# Expo + TypeScript app scaffold with working quality gates

## User story
As a developer on this project, I want a running Expo + TypeScript app with
lint, type check and tests wired up, so that every later story has somewhere
to put code and a green baseline to break.

## Context

The repo currently contains documentation only — there is no `package.json`.
Every other story in EPIC-02 needs an app to live in, and the Definition of
Done in `CLAUDE.md` requires lint, type checks and a test suite to be green,
which means the tooling has to exist before the first feature story runs.

Stack is fixed by the PRD ("Constraints"): Expo (React Native) + TypeScript,
Android only for v1. This story is scaffolding only — no quiz behaviour.

## Acceptance criteria

1. Given a clean checkout, when dependencies are installed and the type
   check command is run, then it completes with no errors under TypeScript
   strict mode.
2. Given a clean checkout, when the lint command is run, then it completes
   with no errors.
3. Given a clean checkout, when the test command is run, then the suite runs
   and passes with at least one real test (a rendering test of the initial
   screen, not a placeholder assertion like `expect(true)`).
4. Given the app is started, when the initial screen renders, then it shows
   the app name and a visible "start" affordance, with no signup, no network
   request and no crash.
5. Given the three commands above, when their names are looked up, then they
   are discoverable as `package.json` scripts (so CI and later stories invoke
   one documented command each, not ad-hoc flags).
6. Given `CLAUDE.md`, when the scaffold is complete, then the "Environments"
   section states how to run the app locally for the QA stage.

## Out of scope

- Any quiz behaviour: audio, questions, answers, feedback, persistence.
- Navigation between multiple screens — one screen is enough until there is
  a second one to navigate to.
- EAS Build configuration, app icon, splash screen, store metadata —
  EPIC-05.
- RevenueCat / IAP dependencies — EPIC-04.
- CI workflow definition beyond what the pipeline already needs.

## Technical notes

- `create-expo-app` with the TypeScript template is the intended starting
  point; prefer its defaults over hand-rolled config.
- Test runner: whatever the Expo template ships with (jest-expo) unless it is
  broken on the current SDK — don't introduce a second one.
- Keep `strict: true` in `tsconfig.json`; loosening it later is much harder
  than starting strict.
- Affected areas: repo root (new `package.json`, `tsconfig.json`, lint
  config, `app.json`), `App.tsx` / `app/` entry, `CLAUDE.md` Environments
  section.

## Definition of Done

See CLAUDE.md.
