---
name: instance-setup
description: Rebrand and reset this wrapper repo for a new client instance of the ERANET platform. Use when starting work on a fresh instance branch, when the user says "rebrand", "set up this branch", "new client instance", "switch instance", or names a new instance label (e.g. "make this VSE"). Swaps the instance label, clears the previous instance's work log, and refreshes the client-variable codebase docs from the nested repos.
---

# Instance setup (per-branch rebrand & reset)

This repo (`C:\Innovis\vse`) is a **wrapper / meta repo**: it holds the AI setup
(`CLAUDE.md`, `.claude/skills`, `.claude/agents`, `.claude/hooks`, `docs/`) around two
**gitignored** nested app repos — `publicERANET-client` and `publicERANET-server` — cloned
from `bitbucket.org/eranetproject`.

Each **branch** of this wrapper repo is one **client instance** of the same **ERANET**
platform (e.g. `seas`, `vsds`/VSE). The nested code differs **per branch** (each client has
its own nested-repo branch, e.g. VSE → `vse_test`), so client-specific features live in the
current nested checkout.

Use this skill to turn a freshly-branched wrapper into a clean setup for its client.

## What is instance-specific vs. shared

| Bucket | Files | Treatment |
|---|---|---|
| **Relabel** (shared; only the label differs) | `CLAUDE.md`, `.claude/skills/**`, `.claude/agents/**`, `.claude/hooks/*.sh`, `docs/codebase/{STACK,CONVENTIONS,TESTING}.md`, `docs/{PROJECT,STATE,ROADMAP,REQUIREMENTS}.md` | Swap old label → new label in place |
| **Reset** (previous client's work log) | `docs/plans/*`, `docs/TICKETS.md` pair table | Delete plans; clear the Story→Dev table |
| **Refresh** (client-variable — features differ per client) | `docs/codebase/{ARCHITECTURE,STRUCTURE,INTEGRATIONS,CONCERNS}.md` | Re-derive from the nested checkout |
| **Cleanup** | stray files like `CLAUDE_backup.md` | Delete |

**Never touch:** `ERANET` (the platform name), `publicERANET-client`/`publicERANET-server`,
the `EP` Jira project prefix, the tech-stack/convention text, or anything inside the
gitignored nested repos.

## Inputs

- **New instance label** — the short display name (e.g. `VSE`). Ask the user if not given.
- **Old instance label** — detect it from `CLAUDE.md`'s header line
  `**<LABEL> / ERANET — Ticket-Driven Development**` (the word before ` / ERANET`).

## Procedure

Run from the repo root. Confirm the new label with the user before starting.

**1. Relabel (mechanical swap, scoped to wrapper files only):**

```bash
OLD=SEAS   # detect from CLAUDE.md header
NEW=VSE    # from the user
for f in $(grep -rl "$OLD" CLAUDE.md .claude docs 2>/dev/null); do
  sed -i "s/$OLD/$NEW/g" "$f"
done
grep -rc "$OLD" CLAUDE.md .claude docs 2>/dev/null | grep -v ':0$'   # expect: none
```

Scope `grep` to `CLAUDE.md .claude docs` so the gitignored nested repos are never scanned.
A plain `$OLD → $NEW` swap covers `SEAS / ERANET`, `SEAS/ERANET`, and standalone `SEAS`.

**2. Reset the previous client's work log:**

```bash
git rm -q docs/plans/*.md 2>/dev/null || true
```

Then clear the body of the Story→Dev table in `docs/TICKETS.md` (keep the header row,
the rules, and the `EP` project key).

**3. Cleanup:** remove any stray files (e.g. `git rm CLAUDE_backup.md`).

**4. Refresh client-variable codebase docs** — `ARCHITECTURE.md`, `STRUCTURE.md`,
`INTEGRATIONS.md`, `CONCERNS.md` under `docs/codebase/`. These describe *features*, which
differ per client, so a relabel is not enough. Dispatch **exploration subagents** (client +
server in parallel) over the **current nested checkout** to verify each doc's claims against
the real code and report inaccuracies + client-specific additions; then apply the edits.
Keep `STACK/CONVENTIONS/TESTING` as relabel-only (platform-level, same everywhere).

**5. Verify & commit.** Check the LF-pinned hook stayed LF (`git ls-files --eol`), show the
diff for review, then commit. Suggested commits:
- `chore(claude): rebrand AI setup to <NEW> instance and reset instance artifacts`
- `docs: refresh codebase docs for <NEW> instance`

## Trigger

Invoke manually on a fresh instance branch. A `post-checkout` reminder hook may print a
nudge, but this skill **never** runs destructive steps automatically — resets always happen
under an explicit invocation so a routine `git checkout` can't wipe a work log.
