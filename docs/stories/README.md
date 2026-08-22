# Stories archive convention

Active stories live directly under `docs/stories/` as
`STORY-<NN>-<slug>.md`, `CHORE-<NN>-<slug>.md`, or `BUGFIX-<NN>-<slug>.md`.

Once a story's status becomes `done`, it is moved (`git mv`) into
`docs/stories/done/` in the same commit that flips its status. This keeps
the top-level directory to only what's still actionable.

Numbering for new stories/chores/bugfixes always scans **both**
`docs/stories/*.md` and `docs/stories/done/*.md` for the highest existing
number in that prefix, so archived files still reserve their number and
a new file never collides with one that's been archived.
