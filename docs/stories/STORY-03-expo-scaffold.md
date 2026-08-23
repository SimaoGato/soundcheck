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

## Implementation Plan

No `## Design references` section exists on this story — skipped that step.

### Feasibility spike (real commands run during refine, not assumed)

Ran the actual scaffold end-to-end in a scratch directory to de-risk this
before handing it to implementation — "just run create-expo-app" hides
several non-obvious footguns on the current toolchain (`expo@~57.0.15`,
`react@19.2.3`, `react-native@0.86.2`, `typescript@~6.0.3`, this machine's
`node v20.11.1`):

1. **`create-expo-app` cannot run at repo root as-is.** It refuses to
   scaffold into a directory containing files it would overwrite, and this
   repo already has a root `CLAUDE.md` (confirmed: it aborts with "The
   directory has files that might be overwritten: CLAUDE.md"). It also
   auto-`git init`s and writes its own `CLAUDE.md` (a one-line `@AGENTS.md`
   stub), `AGENTS.md`, and `LICENSE` when run in an empty directory — all of
   which would collide with or shadow this repo's real `CLAUDE.md` and `.git`
   if ever forced. **Mitigation:** scaffold into a throwaway temp directory,
   then copy only the needed files into repo root; never copy `.git`,
   `.claude`, `AGENTS.md`, `CLAUDE.md`, or `LICENSE` from the scaffold output.
2. **Node version gate silently no-ops `expo lint`, but not other `expo`
   commands.** This machine's `node -v` is `20.11.1`; SDK 57's toolchain
   wants `>=20.19.4`. No nvm/volta/fnm/asdf is installed here and only one
   node binary exists, so this mismatch is not trivially fixable locally.
   Confirmed behavior: `npx expo lint` (and `npm run lint` wrapping it)
   prints the outdated-Node warning, then **exits 0 having done nothing at
   all** — no files checked, no output, `expo.config.js`'s lint issues would
   pass silently. That is a false-green trap for AC2. `npx tsc --noEmit`,
   `npx jest`, calling `./node_modules/.bin/eslint .` directly, and
   `npx expo start` all still work correctly on this same node version (only
   print a non-blocking warning banner). **Mitigation:** the `lint` npm
   script must invoke `eslint .` directly, not `expo lint`. Also add
   `"engines": { "node": ">=20.19.4" }` to `package.json` (self-documenting,
   no extra tooling) and note the constraint in CLAUDE.md's Environments
   section so this isn't rediscovered the hard way later.
3. **`@testing-library/react-native` v14's `render()` is `async` and must be
   `await`ed** (a breaking change from the v12-era examples that are still
   what most tutorials show online). Calling it synchronously silently
   returns `{}` from the render result, and doing a bare synchronous
   `react-test-renderer` `create()` instead throws "trying to `import` a file
   after the Jest environment has been torn down" because React 19's
   scheduler defers the commit past the synchronous call. Confirmed working
   pattern: `await render(<App />)` then query via the `screen` export.
4. **`tsc --noEmit` cannot see Jest's ambient globals (`test`, `expect`) out
   of the box** on this `typescript@~6.0.3` + `@types/jest@30` combination,
   even though nothing in `expo/tsconfig.base` restricts `@types`
   inclusion — confirmed by reproducing the "Cannot find name 'test'" error
   and confirming `"types": ["jest"]` added to `tsconfig.json`'s
   `compilerOptions` fixes it cleanly (AC1 needs this or the test file itself
   fails strict type check).
5. **Peer version pinning:** `react-test-renderer` must be installed at
   the *exact* React version the scaffold pins (`19.2.3` here) — a floating
   `react-test-renderer@latest` fails `npm install` with an ERESOLVE peer
   conflict.
6. Confirmed a real, working, TDD-shaped loop end-to-end in the spike: a
   failing `App.test.tsx` (querying `/soundcheck/i` text and a `start`
   `button` role against the untouched template) fails for the right reason,
   then passes once `App.tsx` is edited to render an "Soundcheck" heading and
   a `Pressable` with `accessibilityRole="button"` and "Start" label — and
   `npx tsc --noEmit` / `eslint .` both stay clean throughout.

### Design decisions

1. **Template: `blank-typescript`, not the `default` (expo-router/tabs)
   template.** The default template pulls in expo-router and a multi-tab nav
   shell, which conflicts with "no navigation between multiple screens" in
   Out of scope. `blank-typescript` gives a single `App.tsx` entry with
   nothing to strip out.
2. **Test runner: `jest-expo` + `@testing-library/react-native` + `jest`,
   added by hand** (`blank-typescript` doesn't bundle a test runner at all —
   confirmed absent from its generated `package.json`). This matches the
   Technical notes' "whatever the Expo template ships with (jest-expo)"
   intent; it just isn't pre-wired by this particular template, so it's an
   explicit added step rather than "already there."
3. **`assets/` merge, not replace.** `assets/audio/` already exists
   (STORY-02). The scaffold's own asset files (`icon.png`,
   `android-icon-*.png`, `favicon.png`, `splash-icon.png`) land as siblings
   under `assets/` with no name collision — confirmed in the spike.
4. **App/package name: `soundcheck`,** not the scaffold's directory-derived
   default — set explicitly in `app.json` (`expo.name`, `expo.slug`) and
   `package.json` (`name`) after copying files in, so the visible app name
   (AC4) and the repo identity match.
5. **No new CI workflow in this story.** Out of scope explicitly excludes
   "CI workflow definition beyond what the pipeline already needs," and no
   AC requires one. This does leave "CI is green on the PR" (Definition of
   Done) vacuously true for this PR — nothing currently runs on
   `package.json`/`App.tsx` changes. That's a real gap, but it isn't this
   story's call to close by unilaterally overriding its own Out-of-scope
   bullet. **Follow-up filed now, not left open-ended:**
   `docs/stories/CHORE-01-app-checks-workflow.md` — add
   `.github/workflows/app-checks.yml` mirroring `audio-checks.yml`'s pattern
   (pinned runner, scoped `paths:` filters, `npm ci` / typecheck / lint /
   test steps). Filed as a chore (not just a prose TODO) because STORY-04
   onward builds directly on this scaffold with no CI safety net until it
   lands. Until CHORE-01 ships, **the human manual-verification step on this
   PR, and on any PR touching `package.json`/`App.tsx`/app source before
   CHORE-01 merges, must explicitly acknowledge that CI does not check app
   code and confirm `npm run typecheck` / `npm run lint` / `npm test` were
   run locally before approving** — this is not implicit in "CI is green."

### Steps (test-first where the AC allows it)

1. `npx create-expo-app@latest <scratch-dir> --template blank-typescript`
   in a throwaway location (e.g. `/tmp`), **not** repo root.
2. Copy into repo root: `App.tsx`, `index.ts`, `app.json`, `package.json`,
   `tsconfig.json`, and the new files under `assets/` (`icon.png`,
   `android-icon-*.png`, `favicon.png`, `splash-icon.png`). Do **not** copy
   `.git`, `.claude`, `AGENTS.md`, `CLAUDE.md`, `LICENSE`, or `node_modules`.
3. Merge the scaffold's `.gitignore` entries (`node_modules/`, `.expo/`,
   `dist/`, `web-build/`, `expo-env.d.ts`, `.kotlin/`, `*.orig.*`, `*.jks`,
   `*.p8`, `*.p12`, `*.key`, `*.mobileprovision`, `.metro-health-check*`,
   `npm-debug.*`, `yarn-debug.*`, `yarn-error.*`, `.DS_Store`, `*.pem`,
   `.env*.local`, `*.tsbuildinfo`, `/ios`, `/android`) into the repo's
   existing `.gitignore` (which currently only has `audio/output/`) —
   append, don't overwrite.
4. Set `app.json`'s `expo.name`/`expo.slug` and `package.json`'s `name` to
   `soundcheck`.
5. Add `"engines": { "node": ">=20.19.4" }` to `package.json`.
6. Add `"types": ["jest"]` to `tsconfig.json`'s `compilerOptions` (keep
   `strict: true`).
7. `npm install` at repo root to produce `package-lock.json`
   (git-ignored `node_modules/`, committed lockfile).
8. Add eslint: `npm install -D eslint@^9.0.0 eslint-config-expo@~57.0.1` and
   write `eslint.config.js`:
   ```js
   // https://docs.expo.dev/guides/using-eslint/
   const { defineConfig } = require('eslint/config');
   const expoConfig = require('eslint-config-expo/flat');

   module.exports = defineConfig([
     expoConfig,
     { ignores: ['dist/*'] },
   ]);
   ```
9. Add test deps, pinning `react-test-renderer` to the scaffold's exact React
   version:
   `npm install -D jest-expo jest @types/jest react-test-renderer@<exact react version from package.json> @testing-library/react-native`.
   Add to `package.json`: `"jest": { "preset": "jest-expo" }`.
10. Add npm scripts: `"lint": "eslint ."`, `"typecheck": "tsc --noEmit"`,
    `"test": "jest"`.
11. **Write `App.test.tsx` first** (red):
    ```tsx
    import { render, screen } from '@testing-library/react-native';
    import App from './App';

    test('renders the app name and a start affordance', async () => {
      await render(<App />);
      expect(screen.getByText(/soundcheck/i)).toBeTruthy();
      expect(screen.getByRole('button', { name: /start/i })).toBeTruthy();
    });
    ```
    Confirm it fails against the untouched template `App.tsx` (wrong text).
12. Edit `App.tsx` to render an "Soundcheck" title and a `Pressable` with
    `accessibilityRole="button"` and a visible "Start" label (no `onPress`
    behaviour required — Out of scope excludes quiz behaviour; the button
    just needs to exist as a visible affordance for AC4). No network calls,
    no signup UI. Confirm the test goes green.
13. Run `npm run typecheck`, `npm run lint`, `npm test` locally; all three
    must be clean (this was verified end-to-end in the spike).
14. Update CLAUDE.md's "Environments" section: fill in the `dev` row with
    `npx expo start --android` (or `npm run android`), noting it needs an
    Android emulator or a device running Expo Go, and that this SDK requires
    Node `>=20.19.4` locally (this sandbox's default `node` is below that —
    `expo start` still runs with a warning banner, but `expo lint`
    specifically no-ops below that version, which is why the `lint` script
    calls `eslint` directly instead). Delete the `staging`/`production` rows
    or mark them not-applicable — this project has no deployed environment,
    only local dev and eventual Play Store release (EPIC-05).
15. `git add` the new/changed files (`package.json`, `package-lock.json`,
    `tsconfig.json`, `app.json`, `eslint.config.js`, `App.tsx`,
    `App.test.tsx`, `index.ts`, `assets/icon.png` + siblings, `.gitignore`,
    `CLAUDE.md`). No `.github/workflows/` changes in this story — see Design
    decision 5.

### Test plan (1:1 with acceptance criteria)

| AC | Check |
|---|---|
| 1 | `npm run typecheck` (`tsc --noEmit` with `strict: true`) exits 0 on a clean checkout after `npm install`. Verified in the spike, including the `"types": ["jest"]` fix needed for the test file itself to type-check. |
| 2 | `npm run lint` (`eslint .`, not `expo lint` — see spike finding 2) exits 0 on a clean checkout. Spike confirmed `eslint` catches a real issue (unused var → warning) when introduced, so this isn't a rubber stamp. |
| 3 | `npm test` (`jest` via `jest-expo` preset) runs `App.test.tsx`, which renders the real `App` component and asserts on real text/role queries (not `expect(true)`). Spike confirmed it fails against the untouched template and passes once `App.tsx` has the required content — a real red-then-green cycle. |
| 4 | Manual run via `npx expo start --android` (Android emulator or Expo Go) at QA time: initial screen shows "Soundcheck" text and a visible "Start" button, no signup UI, no network call (nothing in `App.tsx` makes one), no crash. `App.test.tsx` covers the same assertions at the unit level as a fast regression check. |
| 5 | `package.json` has `lint`, `typecheck`, `test` scripts (confirmed by reading the file / `npm run <name>` resolving). |
| 6 | CLAUDE.md's "Environments" section, read after the change, states the local run command and Android-target requirement. |

### Risks / rollback

- **Node version mismatch (`20.11.1` vs required `>=20.19.4`) is a standing
  environment risk, not just a one-time gotcha.** Any *future* story that
  shells out to `expo <command>` should check first whether that specific
  subcommand degrades on old Node the way `expo lint` does (silent no-op)
  versus just warning (`expo start`, `tsc`, `jest`, direct `eslint`) — this
  plan works around it for AC1-3 but doesn't fix the underlying Node
  install. Documented in CLAUDE.md's Environments section per Step 14 so
  it's not rediscovered per-story.
- **AC4 cannot be fully verified in this sandbox** — no Android
  emulator/device is available here. The unit test (AC3) exercises the same
  content assertions; the actual "started, no crash" claim needs QA on a
  real Android target (emulator or Expo Go), which is expected to happen at
  the QA stage, not during refine or implementation.
- **No CI workflow ships with this story (see Design decision 5), so "CI is
  green on the PR" is vacuously true for this PR** — no check currently runs
  against `package.json`/`App.tsx` changes. This is a known gap, not an
  oversight: the follow-up is filed now as
  `docs/stories/CHORE-01-app-checks-workflow.md` rather than left
  unscheduled, since STORY-04 onward builds directly on this scaffold with
  no CI safety net until it lands. **Before promoting this PR, the human
  manual-verification step must explicitly acknowledge this trade-off** —
  i.e. confirm they understand no CI check ran against this PR's app code,
  and that they (or QA) ran `npm run typecheck` / `npm run lint` / `npm
  test` locally as a substitute. Not a reason to block this story's own
  scaffold work, but it is a reason to not silently treat "CI is green"
  (vacuous, in this case) as sufficient.
- **Rollback:** every artifact this story adds is new (no existing file is
  behaviorally changed except `.gitignore`, appended-only, and CLAUDE.md's
  Environments section). Reverting is `git rm` the new files/dirs
  (`App.tsx`, `App.test.tsx`, `index.ts`, `app.json`, `package.json`,
  `package-lock.json`, `tsconfig.json`, `eslint.config.js`,
  `assets/icon.png` + siblings) and reverting the two appended-only edits
  (`.gitignore`, CLAUDE.md).

### Complexity: standard

Not trivial: the spike surfaced several genuine, non-obvious toolchain traps
on the current SDK/React/Node combination (a lint command that silently
no-ops instead of failing, an async breaking change in the testing library,
a scaffold tool that would collide with this repo's own `CLAUDE.md`) that
carry real reasoning risk if hit blind — getting AC2 "green" the naive way
(`expo lint` in the script) would be a false pass, not a working
implementation. Not complex: single new toolchain in an otherwise-empty repo
area, no auth/concurrency/money/multi-service coordination, and this plan
already resolved every one of those traps with a verified working command
sequence, so implementation is mechanical from here.
