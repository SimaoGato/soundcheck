---
id: CHORE-01
epic: EPIC-02
status: draft
pr: null
---

# Add `app-checks.yml` CI workflow for the Expo app

## User story
As a developer building on the Expo scaffold (STORY-03 onward), I want a CI
workflow that runs typecheck/lint/test on `package.json`/`App.tsx` changes,
so that "CI is green on the PR" (Definition of Done) is a real gate and not
vacuously true.

## Context

STORY-03 scaffolded the Expo + TypeScript app with working `lint`,
`typecheck`, and `test` npm scripts, but shipped no CI workflow to run them —
that was explicitly out of scope for that story (see STORY-03's Out of scope
and Implementation Plan, Design decision 5). Since then, nothing runs those
scripts on a PR touching app code; "CI is green" is vacuously true for any
such PR until this chore lands. Filed now (rather than left as an
unscheduled follow-up) because STORY-04 onward builds directly on this
scaffold with no CI safety net in the interim — see review finding on
STORY-03 PR #4 (docs/stories/STORY-03-expo-scaffold.md, Design decision 5).

Until this chore is done, the human manual-verification step on any PR
touching `package.json`/`App.tsx`/app source must explicitly confirm it ran
`npm run typecheck`, `npm run lint`, and `npm test` locally before approving
— see STORY-03's Risks section.

## Acceptance criteria

1. Given a PR that changes app files (`package.json`, `app.json`,
   `tsconfig.json`, `App.tsx`, or other app source paths), when CI runs,
   then it executes `npm ci`, `npm run typecheck`, `npm run lint`,
   `npm test`, and `./nvmrc_engines_sync.test.sh` (STORY-03's `.nvmrc`
   regression test, currently unwired to any workflow — see STORY-03 PR #4
   review), mirroring `audio-checks.yml`'s pattern (pinned runner image,
   scoped `paths:` filters, one step per check, including one explicit step
   per `*.test.sh`).
2. Given a PR that only touches unrelated paths (e.g. `audio/**`,
   `docs/**`), when CI runs, then this workflow does not run (scoped
   `paths:` filters, same pattern as `audio-checks.yml`).
3. Given any of the five steps fails, when CI reports status, then the
   workflow run fails (not a silent pass) — verified by intentionally
   breaking one check (e.g. a lint error) on a scratch branch and observing
   a red run before merging the workflow.

## Out of scope

- Native Android build/EAS CI — EPIC-05.
- Any new npm scripts beyond the three STORY-03 already added.

## Technical notes

- Mirror `.github/workflows/audio-checks.yml`: pinned `runs-on` (not
  `ubuntu-latest`), `paths:` filters on both `pull_request` and
  `push: branches: [main]`.
- Include `.nvmrc` in the `paths:` filters (alongside `package.json`,
  `app.json`, `tsconfig.json`, app source) — `nvmrc_engines_sync.test.sh`
  reads `.nvmrc` and would otherwise not trigger a run if `.nvmrc` alone
  changed.
- Add a dedicated `.nvmrc` / engines sync test step —
  `run: ./nvmrc_engines_sync.test.sh` — as its own step (not folded into
  the typecheck/lint/test steps), matching `audio-checks.yml`'s one-step-
  per-`*.test.sh` pattern.
- Affected areas: new `.github/workflows/app-checks.yml` only.

## Definition of Done

See CLAUDE.md.
