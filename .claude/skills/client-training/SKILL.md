---
name: client-training
description: How we produce client-facing training and onboarding material for PSK - step-by-step guides with screenshots that teach the client to use the procurement system. Use when preparing training/onboarding material, user guides, or when the user mentions "školenie", "tréningový materiál", "podklady pre klienta", "návod pre používateľa", "onboarding klienta". Generated from the built feature, in Slovak.
---

# Client training material (PSK)

Part of delivery: material that **trains the client to use the procurement system** — not
internal technical docs (those are `documentation`). Audience is the end user (procuring
authority staff, suppliers), so it is task-oriented and visual.

## What to produce

- **Step-by-step guides** for real user tasks ("ako zverejniť zákazku", "ako odovzdať
  ponuku", "ako spustiť elektronickú aukciu"), each step in plain language.
- **Screenshots** of the actual UI for each step — this is the point; a training doc
  without screenshots is just text. Capture them from the running app (manually, or via
  the Playwright MCP if connected).
- Optionally short "čo táto obrazovka slúži" intros per feature.

## Style

- **Slovak (SK-SK)** and the client's vocabulary — not engineering jargon and not raw field
  names from the code. Use the domain terminology: "zákazka", "obstarávateľ", "dodávateľ",
  "ponuka", "harmonogram", "elektronická aukcia", etc.
- Task-first: organize by what the user wants to *do*, not by how the system is built.
- Short numbered steps, each paired with its screenshot.
- Re-capture screenshots when the UI changes — outdated visuals erode trust fast.

## How

1. Identify the user-facing tasks the material must cover (from the ticket/feature).
2. Drive the running app (via `grunt serve` or the deployed WAR), navigate to each step,
   and capture a screenshot. The Playwright MCP can automate this if connected.
3. Write the guide in markdown, interleaving numbered steps and images.
4. Because the guide is generated, it is cheap to regenerate per release — keep it current.

## Output location

Place training guides in `docs/training/` (or the agreed Nuklino page if available).
Name the file clearly: e.g., `docs/training/ponuka-odovzdanie.md`.
