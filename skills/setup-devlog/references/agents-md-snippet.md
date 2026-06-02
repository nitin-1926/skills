<!-- devlog-discipline -->

## Devlog discipline

This repo maintains an append-only `DEVLOG.md` at the root. Every substantive change you make must land with a new entry at the top of its `## Log` section, written **in the same session as the change**.

What counts as substantive: bug fixes, features, refactors with observable behavior, build/CI changes, docs that change facts. What does not: whitespace, typo fixes, doc link renames.

Entry shape is defined at the top of `DEVLOG.md`. Use it verbatim — type, scope, reasoning, implementation summary, optional follow-ups. Capture _why_ and _tradeoffs_, not _what_ — the diff already records what.

Before declaring any task done, verify: if you modified any tracked file in this session and didn't append a DEVLOG entry, you are not done. The log exists to make future agents (and humans) faster — skipping it leaks the most valuable context (the _why_) the moment the session ends.

<!-- /devlog-discipline -->
