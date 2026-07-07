---
name: documentation
description: How we produce project documentation for VSE - generated alongside the feature into docs/ or Nuklino, not as an afterthought. Use whenever writing or generating docs, READMEs, technical/architecture/API/setup documentation, or when the user mentions "dokumentácia", "zdokumentuj", "docs", "Nuklino". Text is what AI does best - generate docs as part of delivery.
---

# Documentation

We don't ship only code. Documentation is part of delivery — and writing text is exactly
what the agent is best at, so generate it *with* the feature, not later by hand.

## What to produce

- **Technical / project docs** — what a feature does, which endpoints it adds, how to
  configure it, key decisions made. Enough for a teammate to pick it up.
- **Codebase docs** — the `docs/codebase/` files (`ARCHITECTURE.md`, `CONVENTIONS.md`,
  `STRUCTURE.md`, etc.) should be updated when a structural change is made.
- **Keep it in sync** — when a change alters behavior, update the affected docs in the same
  change. Stale docs are worse than none.

## Format & location

- **Markdown** — the project docs are in `docs/` and `docs/codebase/`. Write there.
- **Nuklino** — if Nuklino is set up and accessible, write there instead (or in addition).
  Nuklino is the team's wiki tool; it consumes markdown directly. If unsure where to put
  it, default to `docs/` and sync to Nuklino separately.
- Co-locate where it helps: a short `README.md` for a complex module is fine.

## How

1. Decide the doc set for the change (who needs to read it, what questions they have).
2. Generate the markdown as part of executing the plan — don't defer it.
3. Use code blocks and tables where they earn their place; link related pages.
4. For screens/flows, capture a screenshot manually or via the Playwright MCP if connected
   (see `testing`).

## Language

- Technical docs (architecture, API, setup): **English**.
- User-facing docs (training material, user guides): **Slovak (SK-SK)** — see
  `client-training`.
