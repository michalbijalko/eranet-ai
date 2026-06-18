---
name: session-retro
description: End-of-session retrospective that turns this session's experience into durable guidance. Reviews the conversation for decisions made, errors that needed fixing, and user corrections, then PROPOSES minimal updates to CLAUDE.md, the project skills, and docs/codebase so future sessions don't repeat the same mistakes. Manually invoked — use when the user says "session retro", "retrospektíva", "update the skills/CLAUDE.md from this session", "extract learnings", "čo sme sa naučili", or asks to capture what was learned at the end of a session.
---

# Session retro → update guidance

Turn what just happened in this session into **durable rules** that change future behavior.
Run this **only when the user asks** (it is never automatic), typically at the end of a
session once the work is verified.

This is **not** MemPalace and **not** Jira. MemPalace stores session memory; Jira/commits
record what changed for this ticket. This skill updates the **persistent guidance** —
`CLAUDE.md`, `.claude/skills/*`, `.claude/agents/*`, `docs/codebase/*` — i.e. the rules and
workflows that steer every future session. If a lesson only matters to this one ticket, it
does **not** belong here.

## Step 1 — Review the session

Read back over the conversation and pull out:

- **Decisions** — choices made and *why* (approach taken, approach rejected, trade-offs the
  user weighed in on).
- **Errors that needed fixing** — anything that broke, was wrong, or had to be redone:
  failed builds/deploys, wrong assumptions, runtime exceptions, rework after user feedback.
  For each, note the **root cause** and the **fix**, because that is the reusable lesson.
- **User corrections** — every time the user pushed back, redirected, or said "no, do it
  this way". These are the highest-signal items.
- **Friction / rework** — steps repeated, time lost to a wrong path, surprises about how the
  codebase actually works.

## Step 2 — Keep only what is durable and new

For each candidate, apply this filter. Keep it **only if all three** hold:

1. **General** — it will recur in future sessions, not unique to this ticket.
2. **Actionable** — it can be written as a concrete rule or fact ("do X", "X works like Y",
   "watch out for Z"), not a vague reflection.
3. **Not already captured** — read the likely target file first; if CLAUDE.md / the skill /
   the doc already says it, drop it (or tighten the wording instead of duplicating).

Discard: one-off ticket details, things already in Jira/commits/MemPalace, and "nice
thoughts" with no future action.

## Step 3 — Map each lesson to the right file

| Kind of lesson | Target |
|---|---|
| Top-level rule / discipline that applies to all work | `CLAUDE.md` |
| Guidance specific to one activity (coding, deploy, review, testing, …) | the matching `.claude/skills/<name>/SKILL.md` |
| Wrong behavior, missing instruction, or bad tool/skill scope in a subagent (planner, executor, reviewer) | the matching `.claude/agents/<name>.md` |
| A fact about how the codebase/stack actually works, or a known caveat | `docs/codebase/*.md` (CONVENTIONS, ARCHITECTURE, CONCERNS, STACK, …) |
| A whole area no existing skill covers | a **new** `.claude/skills/<name>/SKILL.md` (only when it genuinely doesn't fit an existing one) |

When fixing an agent, also keep its row in the **Agents** table in `CLAUDE.md` in sync if the
trigger, tools, or loaded skills change. Edit an agent's body the same way as a skill —
**minimal, surgical** additions in the same tone; don't restructure the file or broaden a
reviewer's read-only toolset without the user explicitly agreeing.

Prefer **editing an existing file** over creating a new one. Prefer the **smallest** addition
that captures the rule.

## Step 4 — Propose, do not apply yet

Present a single concise table and stop for approval:

| # | Lesson | Target file | Proposed edit (exact text) | Why (session evidence) |
|---|---|---|---|---|

- One row per change. Show the **exact text** you would add and **where**.
- Keep each edit **minimal and surgical** — a sentence or a short bullet, in the same tone
  and format as the surrounding file. Do **not** rewrite sections or restructure files.
- Let the user approve, reject, or amend **each row** individually.

## Step 5 — Apply approved edits

- Apply **only** approved rows, as the minimal additions shown.
- Match the existing style; keep identifiers and rules **English-only** (project rule).
- Re-read each target before editing to place the addition where it fits and avoid
  duplication.

## Step 6 — Commit

- `CLAUDE.md`, `docs/`, and `.claude/` live in the **umbrella repo** (root, branch
  `master`) — not in the nested `publicERANET-server` / `publicERANET-client` repos.
- These guidance changes are **not tied to a Jira ticket**, so do **not** invent an EP
  number. Use a simple descriptive message, e.g. `docs(retro): record nested-repo layout`
  or `chore(skills): add EclipseLink LONGTEXT caveat to coding-conventions`.
- One commit per coherent change (or one grouped commit if the user prefers); keep the
  guidance edits separate from any application-code commit.

## Quality bar

- **Fewer, sharper rules win.** Five precise additions beat twenty vague ones. If a file is
  getting bloated, tighten existing wording instead of piling on.
- **Every rule earns its place** by pointing to something that actually went wrong or was
  decided this session — cite it in the "Why" column.
- **Never weaken existing rules** without the user explicitly agreeing.
