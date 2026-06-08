# Productionize Architecture-Deepening Lens

The `architecture` path. Surface architectural friction and propose **deepening opportunities** — refactors that turn shallow modules into deep ones. The aim is testability and AI-navigability, not churn.

This is also dimension 8 of an `audit` (see [dimensions.md](dimensions.md)); the same vocabulary and tests apply there.

## Glossary (use these terms exactly)

Consistent language is the point — don't drift into "component," "service," "API," or "boundary."

- **Module** — anything with an interface and an implementation (function, class, package, slice).
- **Interface** — everything a caller must know to use the module: types, invariants, error modes, ordering, config. Not just the type signature.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface: a lot of behaviour behind a small interface. **Deep** = high leverage. **Shallow** = interface nearly as complex as the implementation.
- **Seam** — where an interface lives; a place behaviour can be altered without editing in place. (Use this, not "boundary.")
- **Adapter** — a concrete thing satisfying an interface at a seam.
- **Leverage** — what callers get from depth.
- **Locality** — what maintainers get from depth: change, bugs, and knowledge concentrated in one place.

## Key principles

- **Deletion test** — imagine deleting the module. If complexity vanishes, it was a pass-through. If complexity reappears across N callers, it was earning its keep. A "yes, concentrates" is the signal you want.
- **The interface is the test surface.**
- **One adapter = hypothetical seam. Two adapters = real seam.** Don't build a seam for a single caller.

## Process

### 1. Explore

Read the project's domain glossary (`CONTEXT.md`) and any ADRs (`docs/adr/`) in the area first. Then walk the codebase with explore subagents — don't follow rigid heuristics, note where you experience friction:

- Where does understanding one concept require bouncing between many small modules?
- Where are modules **shallow** — interface nearly as complex as the implementation?
- Where have pure functions been extracted just for testability, but the real bugs hide in how they're called (no **locality**)?
- Where do tightly-coupled modules leak across their seams?
- Which parts are untested, or hard to test through their current interface?

Apply the **deletion test** to anything you suspect is shallow.

### 2. Present candidates

Present a numbered list. For each candidate:

- **Files** — which files/modules are involved.
- **Problem** — why the current architecture causes friction.
- **Solution** — plain-English description of what would change.
- **Benefits** — in terms of locality and leverage, and how tests would improve.

Use `CONTEXT.md` vocabulary for the domain and this glossary for the architecture. If `CONTEXT.md` defines "Order," talk about "the Order intake module" — not "the FooBarHandler," not "the Order service."

**ADR conflicts**: if a candidate contradicts an existing ADR, surface it only when the friction is real enough to warrant reopening the ADR. Mark it clearly (e.g. _"contradicts ADR-0007 — but worth reopening because…"_). Don't list every theoretical refactor an ADR forbids.

Do NOT propose interfaces yet. Ask: "Which of these would you like to explore?"

### 3. Grilling loop

Once the user picks a candidate, drop into a grilling conversation (one question at a time). Walk the design tree — constraints, dependencies, the shape of the deepened module, what sits behind the seam, what tests survive.

Side effects happen inline as decisions crystallize:

- **Naming a deepened module after a concept not in `CONTEXT.md`?** Add the term to `CONTEXT.md`. Create the file lazily if it doesn't exist.
- **Sharpening a fuzzy term during the conversation?** Update `CONTEXT.md` right there.
- **User rejects the candidate with a load-bearing reason?** Offer to record it as an ADR — _"Want me to record this as an ADR so future reviews don't re-suggest it?"_ — only when the reason would actually be needed by a future explorer to avoid re-suggesting the same thing. Skip ephemeral reasons ("not worth it right now") and self-evident ones.

A chosen, grilled candidate becomes a self-contained plan via [plans.md](plans.md). The deepening loop may write `CONTEXT.md` and ADRs; it does not modify source — that happens on the `execute` path.
