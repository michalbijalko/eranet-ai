---
name: instance-setup
description: Rebrand and reset this wrapper repo for a new client instance of the ERANET platform. Use when starting work on a fresh instance branch, when the user says "rebrand", "set up this branch", "new client instance", "switch instance", or names a new instance label (e.g. "make this VSE"). Swaps the instance label, clears the previous instance's work log, and refreshes the client-variable codebase docs from the nested repos.
---

# Instance setup (per-branch rebrand & reset)

This repo (`C:\Innovis\<instance>`) is a **wrapper / meta repo**: it holds the AI setup
(`CLAUDE.md`, `.claude/skills`, `.claude/agents`, `.claude/hooks`, `docs/`) around two
**gitignored** nested app repos — `publicERANET-client` and `publicERANET-server` — cloned
from `bitbucket.org/eranetproject`.

Each **branch** of this wrapper repo is one **client instance** of the same **ERANET**
platform (e.g. `seas`, `vsds`/VSE). The nested code differs **per branch** (each client has
its own nested-repo branch, e.g. VSE → `vse_test`), so client-specific features live in the
current nested checkout.

The nested branch does **not** reliably follow `<label>_test` — PSK's nested repos sit on
`poseidon-test`. Always read it (`git -C publicERANET-server rev-parse --abbrev-ref HEAD`)
rather than deriving it from the label.

Use this skill to turn a freshly-branched wrapper into a clean setup for its client.

## What is instance-specific vs. shared

| Bucket | Files | Treatment |
|---|---|---|
| **Relabel** (shared; only the label differs) | `CLAUDE.md`, `.claude/skills/**`, `.claude/agents/**`, `.claude/hooks/*.sh`, `docs/{PROJECT,STATE,ROADMAP,REQUIREMENTS}.md` | Swap old label → new label in place |
| **Reset** (previous client's work log) | `docs/plans/*`, `docs/TICKETS.md` pair table | Delete plans; clear the Story→Dev table |
| **Refresh** (client-variable — features differ per client) | `docs/codebase/{ARCHITECTURE,STRUCTURE,INTEGRATIONS,CONCERNS}.md`, and **verify** `docs/codebase/{STACK,CONVENTIONS,TESTING}.md` | Re-derive from the nested checkout |
| **Cleanup** | stray files like `CLAUDE_backup.md` | Delete |

**`STACK`/`CONVENTIONS`/`TESTING` are not safely relabel-only.** They look platform-level but
carry client-variable facts: dependency versions, whether tests exist, and which cross-cutting
classes are present. On PSK all three were materially wrong — `TESTING.md` claimed "zero
server-side tests, no test framework configured" while the pom declares JUnit + Mockito +
surefire and 13 test classes exist; `STACK.md` listed a `nimbus-jose-jwt` that is absent from
the pom and an EclipseLink version taken from a plugin pin rather than the dependency;
`CONVENTIONS.md` documented a sanitizing interceptor that does not exist. Re-verify their
claims against the checkout, don't just swap the label.

**Never touch:** `ERANET` (the platform name), `publicERANET-client`/`publicERANET-server`,
the `EP` Jira project prefix, or anything inside the gitignored nested repos.

**Beware coincidental version numbers.** A blanket version swap is unsafe: on PSK `opensaml`
was wrong at `2.6.4` while EclipseLink's plugin pin was *legitimately* `2.6.4`. Change one
dependency at a time, each verified against `pom.xml`.

**Not every doc claim is a stale label — some are real.** PSK's `idp.vse.metadata.xml` /
`sp.vse.metadata.xml` look like leftover VSE branding but are a genuine partner-institution
IdP that exists in the checkout. Confirm a file is absent before deleting its reference.

**A shared file can still hold an instance-specific fact — and that edit must NOT be
cherry-picked.** The `authentication` and `security` skills described OIDC (`OIDCService`,
`OIDCConfiguration`, `nimbus-jose-jwt`) and a `FindParametersSanitizer` interceptor; none exist
on PSK, but they may exist on other instances. Those were removed **on the PSK branch only**.
When a shared file's *content* (not just its label) is instance-variable, fix it on the branch
and leave it out of the cherry-pick set — otherwise you break the instances where it is true.

**Shared changes propagate to all branches.** A new `.claude/skills/*`, agent, hook, or a
shared engineering rule in `CLAUDE.md` is not instance-specific — commit it on the current
branch, then `git cherry-pick -x <sha>` it onto every other instance branch (`git branch`)
so instances don't drift. Keep instance-specific work (`docs/plans/*`, ticket docs) on its
own branch only.

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

**Watch these traps the plain swap misses:**

- **Skill/doc bodies carry the label too.** Nested-repo branch names like `<label>_test`
  and absolute `C:\Innovis\<label>` paths inside `.claude/skills/**` and `docs/**` bodies are
  relabel targets, not just `CLAUDE.md`. After the swap run `grep -rni "$OLD" .claude docs`
  (and the old branch name / path) and fix residue by hand.
- **Case variants.** The label also appears lower/mixed-case (`seas_test`, `PublicSeasDS`), which
  a case-sensitive swap skips. After the swap, run `grep -rni "$OLD" CLAUDE.md .claude docs` and
  fix every residual by hand.
- **Deployment-specific tokens are NOT a label swap.** Some values are instance config and take
  *verified* per-instance values — read them from the nested checkout, never guess:

  | Token (SEAS example) | Where the real value lives |
  |---|---|
  | datasource JNDI `PublicSeasDS` | `publicERANET-server/src/main/resources/META-INF/persistence.xml` |
  | WildFly context root `/public_seas` | `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml` |
  | security domain `PublicSeasRM` | `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml` |
  | Maven artifact `eranet-server-seastest` | `publicERANET-server/pom.xml` (`artifactId`) |
  | logging profile `seas_profile` | `publicERANET-server/pom.xml` (`manifestEntries`) |
  | DB name / branch `seas_test` / `seas-test` | `configS.bat`, nested-repo branch |

  For VSE these resolved to `EranetVseTestDS`, `/public_vse`, `EranetVseTestRM`,
  `eranet-server-vsetest`, `vsds_profile`, and `vse_test`.

  Some instances are **not tokenized at all** — PSK's checkout uses the generic `EranetDS`,
  `/public`, `EranetRM`, `eranet-server`, `eranet_profile`, `EranetPU`. Read every value; a
  label-shaped substitution would have invented tokens that exist nowhere in the code.

- **Docs carry the *previous* client's tokens, not just its label.** PSK's docs still held
  `PublicTrnavavucDS`, `/public_trnavavuc`, `trnavavuc_profile`, and `C:\Innovis\trnavavuc\`
  from an instance two rebrands back — a `$OLD → $NEW` swap never touches them. After the
  swap, grep the docs for **every** past instance label (`git branch` lists them), not just
  `$OLD`, and re-verify each deployment token against the checkout.

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
