# Productionize Interview

Questions to ask the user in Phase 2 to pin down the intended end state. Rules:

- Ask only what the Phase 1 investigation could not answer. Do not ask what you can verify in the repo.
- Ask a few at a time, not all at once. Provide a recommended default for each.
- Stop once you can state the intended end state in one or two sentences.
- The user's answers override your assumptions about what "production" means.

## End state & intent

1. **What is the intended end state?** Describe the product/UX and architecture as if it existed from day one — in a sentence or two.
   _Default: infer from the working parts of the repo and confirm._
2. **What is the target environment?** (local tool, internal service, public production, library/package, demo)
   _Default: treat as public production unless told otherwise._
3. **What is explicitly out of scope or should be left as-is?**
   _Default: nothing is off-limits, but confirm before touching anything load-bearing._

## Scope & risk

4. **Risk tolerance**: conservative (only clearly-safe + approved changes) or aggressive (reshape freely within plan)?
   _Default: conservative._
5. **Are there callers/consumers outside this repo** (other services, published API, downstream apps) that constrain what can be deleted or renamed?
   _Default: assume yes for any public/exported surface; confirm._
6. **Must-keep vs. deletable**: any modes, flags, routes, or compatibility paths that must be preserved even if they look unused?
   _Default: delete only with confirmed no-callers; ask about anything ambiguous._

## Per-dimension priorities

7. **Which dimensions matter most for this pass?** (code hygiene, architecture/tech-debt, correctness, security, tests, config/env, docs/CI)
   _Default: prioritize correctness + security, then architecture, then the rest._
8. **Any known pain points, fragile areas, or recent incidents** to weight the plan toward?
   _Default: derive from investigation findings._

## Verification & process

9. **How should changes be verified?** (existing test command, manual flow, CI)
   _Default: use the repo's existing build/test/lint; flag if none exists._
10. **Approval granularity**: approve the whole plan once, or batch-by-batch?
    _Default: approve the plan once, then execute in small batches with a summary at the end._
