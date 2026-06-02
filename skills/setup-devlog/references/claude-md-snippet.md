<!-- devlog-discipline -->

# Devlog (`DEVLOG.md`) — non-negotiable

`DEVLOG.md` at the repo root is this project's append-only log of decisions, tradeoffs, bug fixes, and reasoning. The full template + entry shape lives at the top of the file. Read those rules once before writing your first entry.

Every substantive change to this repo (bug fix, feature, build/CI change, refactor with observable behavior, docs that change facts) MUST land with a new entry at the top of the `## Log` section in `DEVLOG.md`.

Hard rules:

- Write the entry **in the same session as the change**, before you declare the task done — not as a separate follow-up turn or "I'll log it next time."
- One entry per logically independent change. Do not batch unrelated work into one entry.
- Entries go at the **top** of `## Log` (reverse chronological).
- Use the entry template defined at the top of `DEVLOG.md`. Don't invent a new shape.
- Capture _why_, not _what_ — the diff already shows what. Record the decision, the alternatives considered, and the failed approaches that taught you the right one.
- Only skip the log for purely cosmetic edits (whitespace, typo, doc link rename). When in doubt, write the entry.

Before you say a task is done, do this self-check: if any tracked file under this repo has been modified in this session and you have not appended a `DEVLOG.md` entry covering it, you are not done. Append the entry first.

Whether `DEVLOG.md` is committed or gitignored is recorded in `.gitignore` — check there before staging anything related.

<!-- /devlog-discipline -->
