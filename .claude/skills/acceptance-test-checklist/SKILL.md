---
name: acceptance-test-checklist
description: Generate an interactive, clickable manual-test checklist from a ticket's acceptance criteria, rendered inline in the session (not saved, not shared). Each step has Pass/Fail toggles + notes; results are sent back into the chat to drive close+commit or fixes. Use right BEFORE manually testing a finished ticket, or when the user says "testovací checklist", "klikací zoznam na test", "vygeneruj postup testovania", "pred testom", "akceptačný test", "otestujem to".
---

# Acceptance-Test Checklist

Turns a ticket's **acceptance criteria** into a concrete, clickable Slovak test procedure the
user clicks through while manually testing the running app. It is the gate **between code review
and commit**: the user marks each step Prešlo / Zlyhalo, sends the result back, and that decides
whether we **close + commit** the ticket or **do fixes**.

**In-session only.** Render the checklist as an inline interactive widget. Do **not** write it to
`docs/`, do **not** publish an Artifact, do **not** persist it. It lives in the conversation.

## When to run

After the executors + code reviewers are clean, and **before** the manual browser smoke test.
Workflow position: brainstorm → planner → executor → code-reviewer → **this skill** → user tests
in the app → (all pass ⇒ commit) / (any fail ⇒ fix & re-check).

## Steps

### 1. Identify the ticket and gather the source of truth
- Get the `EP-XXXX` story id (ask if not given).
- **Read the acceptance criteria from Jira** via the Atlassian MCP (`getJiraIssue`,
  `responseContentFormat: "markdown"`, include the description/AC). The ACs are the backbone of
  the checklist — one checklist section per AC.
- **Read the ticket's design + plan** in `docs/plans/YYYY-MM-DD-EP-XXXX-*.md`. This is what makes
  the steps concrete: exact forms/screens, field labels, the protocol PDF, statistics module,
  Nastavenia (settings) rows, and any conditional/edge-case rules.
- If Jira is unreachable, fall back to the ACs transcribed in the design doc and say so.

### 2. Expand each AC into concrete Slovak test steps
For every acceptance criterion, write **one or more** click-level steps a tester can follow
without guessing — grounded in the plan, not generic:
- **Kde**: which screen / module / form (use the real Slovak screen names, e.g. *Požiadavky IO*,
  *Požiadavky VO*, *Nastavenia*, protokol *Požiadavka na obstarávanie*).
- **Čo urob**: the action (open, select, save, reopen, generate PDF, toggle a settings row…).
- **Očakávaný výsledok**: the observable pass condition.
- Cover **both modules** when the ticket spans IO + VO, and always include the **edge / conditional
  cases** explicitly (e.g. a field that restricts/resets based on another field) — these are the
  steps most likely to fail.
- Keep each step atomic so Pass/Fail is unambiguous. Steps are in **Slovak** (the testers' language);
  keep any code identifiers as-is.

### 3. Render the clickable checklist (interactive widget)
- Load the widget guidance first: `mcp__visualize__read_me` with `modules: ["interactive"]`
  (silently — don't narrate it), then `mcp__visualize__show_widget`.
- Structure: a header (ticket id + one-line scope), then sections **AC#1 … AC#N**, each with its
  steps. Each step row has three states — **Neotestované / Prešlo / Zlyhalo** — plus an optional
  free-text **poznámka** field for failures.
- Show a **live súhrn** (counts: prešlo / zlyhalo / zostáva) that updates on click.
- Add an **"Odoslať výsledky"** button that calls the global `sendPrompt(text)` with a compiled
  Slovak summary: overall verdict, per-AC pass/fail, and every failure's step text + note. That
  message coming back into the chat is what drives step 4.
- **Widget house rules:** self-contained (no external CDN/fonts/images — CSP blocks them); inline
  all CSS/JS; theme-aware via the provided CSS variables (`--bg`, `--surface-1/2`, `--text-primary`,
  `--text-secondary`, `--text-muted`, `--border`, `--border-strong`, `--text-accent`, `--bg-accent`,
  `--radius`, `--font-sans`); start with a visually-hidden `<h2 class="sr-only">` summary; no
  horizontal page scroll. Use green for Prešlo, red for Zlyhalo, neutral for Neotestované.

### 4. Act on the result
When the user sends the results back (via the button or by telling you):
- **All Prešlo** ⇒ the manual-test gate is passed. Proceed per `issue-tracking`: commit each repo's
  slice with the correct `feat|fix(STORY, DEV): …` message (confirm first, per CLAUDE.md). Optionally
  offer to move the Jira testing sub-task forward.
- **Any Zlyhalo** ⇒ do **not** commit. Triage each failure (use `systematic-debugging` if the cause
  isn't obvious), fix it in the right slice, re-verify, and re-render the checklist for the affected
  steps so the user can re-click them.

## Notes
- The checklist is a **manual-test aid**, not automated tests — it complements the `testing` skill
  (Karma/Jasmine + browser smoke), it does not replace judgment about coverage.
- Do not invent ACs. If a criterion is ambiguous, ask the user rather than guessing a pass condition.
- Because nothing is persisted, if the widget is lost (context reset) just regenerate it from the
  ticket + plan.
