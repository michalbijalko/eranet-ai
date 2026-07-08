---
name: demo-material
description: Prepare material to present/demo a built SEPS feature to stakeholders or the client - a demo scenario/script, what to show in what order, talking points, and demo data or screenshots. Use when preparing a demo or presentation, or when the user mentions "demo", "demoscenár", "prezentácia", "odprezentovať", "ukázať klientovi", "demo scenario". Distinct from client-training (which teaches the user to operate the app); this is for showing and selling the result.
---

# Demo material (SEPS)

Part of delivery: material for *presenting* what was built — to stakeholders or the client.
Not a user manual (that's `client-training`); this is the narrative for a live showing.

## What to produce

- **Demo scenario / script** — the exact happy-path walkthrough: which screens to navigate,
  what to click, in the order that tells the best story (problem → solution → the "wow").
  Ground it in the procurement domain: use realistic procurement names, company names, and
  dates rather than "Test Procurement 1".
- **Talking points** — for each step, one line on *why it matters* (the business value to
  the procuring authority or supplier), not just what the button does.
- **Demo data / starting state** — what needs to be seeded or set up so the demo runs clean
  (a prepared procurement, a logged-in user, uploaded documents). Note how to reset it
  if the demo needs to be repeated.
- **Screenshots (optional)** — of the key moments, captured from the running app (manually
  or via the Playwright MCP if connected), as a fallback if the live demo glitches.

## How

1. Pick the **one story** the demo should land — the single most valuable thing built for
   this ticket/feature.
2. Write the click-through scenario end to end; run through it on the deployed app first
   to make sure the path actually works.
3. Add per-step talking points (value, not mechanics).
4. Prepare/seed the demo data and note the reset steps.
5. Optionally capture screenshots of the highlights as backup.

## Domain context

SEPS screens deal with: procurement tenders, qualification systems, electronic auctions,
company profiles, document signing, and reporting to UVO/EKS/URSO. Use terminology the
client recognizes — "obstarávateľ", "dodávateľ", "zákazka", "ponuka", etc. — not
internal field names.

## Keep it honest

Demo the real, running thing — not a mock dressed up as done. If something isn't ready,
say so in the script rather than faking it.
