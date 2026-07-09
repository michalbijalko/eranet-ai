## Project

**SEPS / ERANET — Ticket-Driven Development**

SEPS (ERANET Public) is a production Slovak public-procurement (e-tender) platform: a Java EE 7 REST/WebSocket backend (`publicERANET-server`) and an AngularJS 1.x SPA (`publicERANET-client`), backed by MySQL. This is not a rewrite — it is an **ongoing, Jira-ticket-driven stream of new features and bug fixes** on the existing system, governed by a strict set of engineering conventions so that changes stay consistent, traceable, and faithful to the existing codebase.

**Core Value:** Every change traces to exactly one Jira ticket, follows the existing codebase patterns, and is delivered in clean, disciplined commits — without breaking the live procurement platform. If everything else is negotiable, **this discipline is not**.

**Tech stack (fixed, brownfield):** Java 8 / Java EE 7 / EclipseLink / RESTEasy / WildFly / MySQL (server); AngularJS 1.5 / Bower / Grunt (client). Do not introduce new frameworks without a decision.

## Engineering Working Agreement (READ FIRST)

These rules are mandatory for **all** code work on SEPS/ERANET. They exist because AI-assisted changes on a prior project caused real problems (bad commit attribution, mixed tickets, Slovak leaking into code, invented UI, ignored patterns).

**Brainstorm before code.** No implementation or commits for a new feature or behavior change until intent and approach are brainstormed with the user — even when it "looks like a one-liner". Use `superpowers:brainstorming`.

### 1. Jira-ticket-first
- Before any discussion or planning, **read the relevant `EP-XXXX` Jira ticket** (via the Atlassian integration) so requirements come from the ticket, not from guessing.
- Jira images cannot be read by the agent — **ask the user to paste any image** the ticket depends on before assuming intent.

### 2. Commits
- Format: **`feat|fix(STORY, DEV): description`** — story ticket first, dev ticket second. **Never** put the Epic in the first slot.
- **Look up the correct Story→Dev pair in [`docs/TICKETS.md`](docs/TICKETS.md) before every commit.**
- **One ticket per commit** — never mix multiple tickets.
- Simple, human-readable messages and comments — no phase numbers or internal codes.
- **Confirm before committing.** Make the change and let the user verify it works (in the running app for UI/behaviour changes) before committing — don't commit a fix proactively.
- Example: `feat(EP-12688, EP-12689): add contract type enum to procurement form`

### 3. Language — English-only (CRITICAL)
- All code, identifiers, and **translation keys** must be in **English**.
- Slovak appears **only in translation values**, never in code or keys.

### 4. UI
- Reuse the **existing system design** — copy components/styles already present. Do **not** create a new component library or redesign.

### 5. Backend
- Do **not** call DAOs directly — use a **`BaseService` method** when one is available (respects the service-layer pattern and container-managed transactions).

### 6. Database / Liquibase
- Raw SQL scripts **only for INSERTs**; all other schema changes go through **Liquibase changesets**.
- Liquibase changeset **author = `m.bijalko`**.

### 7. Code quality
- Human-readable code; split logic into **well-named methods**.
- **Follow existing codebase patterns** (see Codebase Reference below) and modern practices where sensible. Do not introduce new frameworks without a decision.

### 8. Parallel execution & subagents (context hygiene)
- **Default to parallel.** When a task has independent subtasks (e.g., reading multiple files, researching multiple endpoints, writing server + client sides of a feature), run them in parallel tool calls — not sequentially.
- **Protect the main context window.** Use subagents (via the `Agent` tool) for any work that would flood the context with large outputs: deep codebase exploration, multi-file reads, research, code review, verification. The agent returns a summary; the raw output stays out of the main context.
- **Use `superpowers:dispatching-parallel-agents`** when fanning out multiple independent subagents — it structures the dispatch so nothing is missed and results are synthesized cleanly.
- **Use `superpowers:subagent-driven-development`** for large implementation tasks — each significant subtask gets its own subagent; the main context only sees the results.
- Sequential tool calls are only acceptable when a later call depends on the output of an earlier one.

## Codebase Reference

Detailed documentation lives in [`docs/codebase/`](docs/codebase/). Read the relevant file before working in that area:

- [`STACK.md`](docs/codebase/STACK.md) — full technology stack: runtimes, frameworks, dependencies, build tooling, platform requirements.
- [`CONVENTIONS.md`](docs/codebase/CONVENTIONS.md) — JavaScript (client) and Java (server) coding conventions, naming patterns, and code-style rules.
- [`ARCHITECTURE.md`](docs/codebase/ARCHITECTURE.md) — component responsibilities, layers, data flow, key abstractions, entry points, and architectural constraints.
- [`STRUCTURE.md`](docs/codebase/STRUCTURE.md) — directory and module layout.
- [`INTEGRATIONS.md`](docs/codebase/INTEGRATIONS.md) — external integrations (SAML/SSO, OIDC, email, document generation).
- [`TESTING.md`](docs/codebase/TESTING.md) — test setup and conventions.
- [`CONCERNS.md`](docs/codebase/CONCERNS.md) — known issues and cross-cutting concerns.

## Skills & Plugins

### Superpowers Plugin

The **superpowers** plugin provides structured workflows that improve quality on non-trivial tasks. Invoke these before/during the relevant activity — not after:

| Skill | When to use |
|-------|-------------|
| `superpowers:brainstorming` | **Before** any new feature, component, or behavior change — explore intent and requirements first |
| `superpowers:writing-plans` | When planning the implementation of a ticket — produces a step-by-step plan to follow |
| `superpowers:executing-plans` | When executing a written plan — tracks steps and handles deviations |
| `superpowers:systematic-debugging` | When diagnosing a bug — follows scientific method (hypothesis → test → fix) |
| `superpowers:test-driven-development` | When writing tests alongside implementation |
| `superpowers:requesting-code-review` | Before asking for a review — prepares the change and context |
| `superpowers:receiving-code-review` | When acting on review feedback — structured resolution |
| `superpowers:verification-before-completion` | Before marking a ticket done — verifies the change actually works |
| `superpowers:finishing-a-development-branch` | When wrapping up a branch — commit hygiene, PR prep |
| `superpowers:subagent-driven-development` | For large tasks that benefit from parallel subagents |
| `superpowers:using-git-worktrees` | When running parallel work that would conflict in one working tree |

### Project Skills (`.claude/skills/`)

These skills encode SEPS-specific rules for each activity. **Read the relevant skill before acting** — they are more detailed than the summaries below.

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `issue-tracking` | Starting any ticket | Read Jira ticket via Atlassian MCP; look up Story→Dev pair in `docs/TICKETS.md`; write correct commit message |
| `app-foundation` | Adding a new Java service or AngularJS screen | Layer setup checklist — EJB, DAO, route, Gruntfile registration |
| `coding-conventions` | Writing or editing any code | Java EE 7 and AngularJS 1.5 ES5 patterns, naming, array DI, BaseService/BaseDao layering |
| `code-review` | Reviewing a diff or PR | SEPS-specific review checklist: ticket trace, conventions, layer discipline, security, Liquibase, English-only identifiers |
| `security` | Adding endpoints, handling credentials, integrating external systems | `@RolesAllowed`, no secrets in code, server-side-only external calls, input sanitization |
| `authentication` | Touching login flows, session handling, SSO, protected endpoints | Local / SAML 2.0 (ÚPVS) / OIDC — which service to extend, what not to touch |
| `ui-design` | Building or restyling any UI | Bootstrap 3 + SmartAdmin + `ui.bootstrap` — reuse existing components, no new libs, localization rules |
| `testing` | Writing tests or verifying a change | Karma/Jasmine client tests; browser smoke testing; critical flows to always check |
| `acceptance-test-checklist` | Right before manually testing a finished ticket | Generate an in-session clickable Slovak test checklist from the ticket's acceptance criteria (Pass/Fail per step); results drive close+commit or fixes |
| `deployment` | Releasing / deploying a change | Maven WAR build → Liquibase migrations → WildFly hot-deploy; dev environment quick start |
| `feasibility` | New idea or unknown scope before planning | Go-no-go pass: frame the ask, check existing codebase, assess doability and effort, give a recommendation |
| `documentation` | Writing or updating docs | What to produce, format (`docs/` or Nuklino), keep in sync with code changes |
| `demo-material` | Preparing a stakeholder demo | Demo script, per-step talking points, demo data setup, screenshots |
| `client-training` | Creating training guides for end users | Step-by-step guides in Slovak, with screenshots, organized by user task |
| `instance-setup` | Setting up a fresh client-instance branch | Rebrand the instance label, reset the previous client's plans/tickets, refresh client-variable codebase docs from the nested repos |

## Agents (`.claude/agents/`)

Project-specific subagents that encode the SEPS workflow. Each loads the relevant skills above (and `superpowers:*`) itself. Delegate to them via the `Agent` tool; the typical flow is **brainstorm (with the user) → planner → executor → code-reviewer**.

| Agent | When to use | Tools | Loads |
|-------|-------------|-------|-------|
| `planner` | After intent is brainstormed with the user — turn one `EP-XXXX` ticket into a backend/frontend-split implementation plan | Read-only + Write (plans) + Atlassian | `issue-tracking`, `feasibility`, `app-foundation`, `coding-conventions`, `superpowers:writing-plans` |
| `executor-backend` | Implement the Java EE 7 server slice of an approved plan | Full edit + Bash | `coding-conventions`, `app-foundation`, `security`, `authentication`, `superpowers:executing-plans` / `test-driven-development` / `systematic-debugging` / `verification-before-completion` |
| `executor-frontend` | Implement the AngularJS 1.5 client slice of an approved plan | Full edit + Bash | `coding-conventions`, `app-foundation`, `ui-design`, `testing`, same `superpowers:*` set |
| `code-reviewer-backend` | Review a server diff before a PR/merge | Read-only (no Edit/Write) | `code-review`, `coding-conventions`, `security`, `authentication`, `issue-tracking` |
| `code-reviewer-frontend` | Review a client diff before a PR/merge | Read-only (no Edit/Write) | `code-review`, `coding-conventions`, `ui-design`, `testing`, `issue-tracking` |

Rules: **brainstorming stays in the main thread** with the user (a subagent can't brainstorm) — the planner requires it to have happened and stops to ask if intent is unclear. Reviewers are deliberately **read-only** so a review can never mutate code. All agents inherit the session model (`model: inherit`) and obey the same hard rules as the rest of this file (one ticket per commit, English-only identifiers, layer discipline, design reuse).
