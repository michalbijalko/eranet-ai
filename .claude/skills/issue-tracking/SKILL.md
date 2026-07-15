---
name: issue-tracking
description: How we track work in Jira (EP project) - reading tickets before coding, commit format with Story→Dev pairs, and bug reporting. Use when starting a ticket, writing a commit message, reporting a bug, or when the user mentions "Jira", "EP-XXXX", "ticket", "úloha", "report bug". Every change traces to exactly one ticket.
---

# Issue tracking (Jira — EP project)

**Project key:** `EP` (e.g., `EP-12688`)

Every code change traces to exactly one Jira ticket. This is not optional — it is the
core discipline of VSE development.

## Before writing any code

1. **Read the Jira ticket** via the Atlassian MCP (`EP-XXXX`). Requirements come from the
   ticket, not from guessing or memory.
2. Note the **Story ticket** and its paired **Dev ticket** — both are needed for the commit
   message. Look them up in `docs/TICKETS.md`. The Dev ticket is typically the Story's
   **Dev Sub-task** (stories also carry a parallel Test Sub-task). If the pair isn't in
   `docs/TICKETS.md`, fetch the Story's subtasks (`getJiraIssue`, `fields: ["subtasks"]`) to
   find it, then add the TICKETS.md row.
3. If the ticket has images: Jira images cannot be read by the agent — **ask the user to
   paste the image** before assuming intent.
4. **Check cross-ticket dependencies** — read the ticket's Jira issue links (clone/relates/blocks)
   and scan its acceptance criteria for references to a column/field/attribute owned by *another*
   ticket. If a sibling must land first (its artifact is a precondition), sequence that one first
   and confirm the order with the user.

> **Jira reachable check:** a `system-reminder` listing some Atlassian connectors as needing
> auth does **not** mean Jira is unreachable — a working connector is usually present. Try
> `getAccessibleAtlassianResources` → `getJiraIssue` (site `innovis.atlassian.net`) before
> telling the user to paste the ticket; fall back to asking only if the call itself fails.

## Commit format (mandatory)

```
feat|fix(STORY, DEV): short human-readable description
```

- **Story ticket first**, Dev ticket second.
- **Never** put the Epic in the first slot.
- One commit per ticket — never mix multiple tickets.
- Simple, human-readable messages: no phase numbers, no internal codes.

Examples:
```
feat(EP-12688, EP-12689): add contract type enum to procurement form
fix(EP-13001, EP-13002): correct supplier qualification date validation
```

Look up the correct Story→Dev pair in `docs/TICKETS.md` **before every commit**.
If the pair is missing from the table, add a row before committing.

## Where commits go — three separate repos

The workspace is **three independent Git repos**, not one:
- `publicERANET-server/` — server code (branch `vse_test`)
- `publicERANET-client/` — client code (branch `vse_test`)
- the workspace root (umbrella) — `CLAUDE.md`, `docs/`, `.claude/` (branch `master`)

- Commit code in the repo it lives in. One ticket touching both sides → **one commit per
  repo**, same `feat|fix(STORY, DEV)` message.
- **Confirm the checked-out branch before committing.** Epic feature work lands on a shared
  `feat/EP-XXXX` branch checked out in *both* nested repos (e.g. `feat/EP-13132`), one commit
  per story; the umbrella sits on the current client-instance branch (e.g. `seps`), not always
  `master`/`sepsas_test`.
- The umbrella repo often holds unrelated staged/untracked changes. **Scope every umbrella
  commit to its files** (`git commit -- <path>`) so you don't sweep up in-flight work.
- Never `git add` the `publicERANET-*` directories from the umbrella — they are nested repos
  and would be committed as broken embedded-repo references.

## Reporting bugs

When you discover a bug (in code or during testing), report it via the Atlassian MCP:
- Title: clear one-line description of the bug.
- Context: which screen/endpoint/ticket area it is in.
- Severity: how bad if left unfixed.

If the Atlassian MCP is not connected, produce a structured bug description (component,
steps to reproduce, expected vs actual) and reference it in the commit for later triage.

## Keep the trail honest

The point is human oversight: a person must be able to read the git log or Jira board and
understand what was changed, why, and which ticket drove it — without reverse-engineering
the code. Reference ticket IDs in commits; update ticket status after completing work.
