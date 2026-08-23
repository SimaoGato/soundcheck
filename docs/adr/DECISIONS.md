# Decision log

Dated bullets, one line each; a standalone `ADR-<NNN>-<slug>.md` in this same directory is the rare exception, not the default — see `CLAUDE.md`'s "Decision records" section.

- 2026-08-22: Base signal for EQ clips is pink noise, not a synthetic pad/chord — full-spectrum reference makes boosts/cuts objectively audible at every band; risk of listener fatigue accepted and flagged for a real-listening sanity check.
- 2026-08-22: Difficulty ladder widens then narrows choice count (3 → 5 → 7 → 10 → 10) across obvious/intermediate/advanced/expert/cuts tiers, forcing fine discrimination only at the top tiers.
- 2026-08-22: Paywall shown as a non-blocking dismissible banner every 5 questions, plus a persistent "Get full version" entry point — no modal gates, no session-count cutoff.
- 2026-08-22: App name "Soundcheck" kept as final for v1; trademark/availability check deferred to pre-submission, not a build blocker.
- 2026-08-22: Audio asset spec locked: 2.5s mono AAC ~64kbps clips, 60-clip paid-tier matrix (10 freq × 6 gain levels) ≈ 1.2MB total — no bitrate/format tuning needed at this size.
- 2026-08-23: Band-to-broadband RMS ratio (not absolute band RMS) used for clip verification in check.sh AC2/AC3 — gain-invariant metric isolates EQ effect from loudnorm's broadband compensation, structural fix rather than parameter-tuning.
