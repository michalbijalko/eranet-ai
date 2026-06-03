# SEAS / ERANET — Ticket-Driven Development

## What This Is

SEAS (ERANET Public) is a production Slovak public-procurement (e-tender) platform: a Java EE 7 REST/WebSocket backend (`publicERANET-server`) and an AngularJS 1.x SPA (`publicERANET-client`), backed by MySQL. This milestone is not a rewrite — it is an **ongoing, Jira-ticket-driven stream of new features and bug fixes** on the existing system, governed by a strict set of engineering conventions so that AI-assisted changes stay consistent, traceable, and faithful to the existing codebase.

## Core Value

Every change traces to exactly one Jira ticket, follows the existing codebase patterns, and is delivered in clean, disciplined commits — without breaking the live procurement platform. If everything else is negotiable, **this discipline is not**.

## Requirements

### Validated

<!-- Inferred from the existing codebase (.planning/codebase/). These already work and are relied upon. -->

- ✓ Public-procurement lifecycle: procurement, qualification, planning, evaluation, communication domains — existing
- ✓ Authentication & SSO: Java EE FORM login, UPVS SAML 2.0 SSO, OIDC/JWT — existing
- ✓ Role-based authorization (administrator, user, supplier, statutory, confirmancePerson, responsiblePerson, systemAdministrator) — existing
- ✓ REST API (JAX-RS / RESTEasy) over JPA/EclipseLink entities on MySQL — existing
- ✓ Real-time WebSocket notifications / procurement-room chat — existing
- ✓ Document generation: Aspose Words/PDF + Apache POI/Aspose Cells (Excel) — existing
- ✓ Internationalization via `angular-translate` (Slovak default locale) — existing
- ✓ Liquibase-managed database schema migrations — existing

### Active

<!-- This milestone's setup deliverables. Hypotheses until shipped. Feature/bug work is planned per Jira ticket as it arrives. -->

- [ ] Engineering conventions captured and enforced in `CLAUDE.md` (always in context)
- [ ] Story→Dev ticket mapping maintained in `.planning/TICKETS.md`, referenced from `CLAUDE.md`
- [ ] Jira-ticket-first workflow established: read the EP ticket (via Atlassian integration) before any discussion or planning
- [ ] Ongoing: each new feature / bug fix delivered per ticket, following all conventions

### Out of Scope

- Framework migration / rewrite (AngularJS → modern Angular, Java EE → Spring) — maintain the existing stack; not this milestone
- New UI component library or visual redesign — reuse the existing SmartAdmin/Bootstrap design already in the system
- Relaxing the commit / ticket-discipline rules — locked by decision
- Slovak text anywhere in code (including translation keys) — Slovak belongs only in translation values

## Context

- **Why these rules exist:** On a prior project, AI-assisted commits caused problems — incorrect commit attribution, mixed tickets, Slovak leaking into code, inventing new UI instead of reusing existing components, and ignoring established patterns. This milestone front-loads those lessons as enforced constraints.
- **Two separate git repositories:** `publicERANET-client` and `publicERANET-server` each have their own `.git`. The workspace root is a coordination/planning repo; planning docs stay local (multi-repo workspace).
- **Jira access:** The Atlassian/Jira integration is connected — ticket **text** can be read directly. Images cannot; Claude must ask the user to paste any image a ticket depends on.
- **Existing patterns to follow** (from `.planning/codebase/`): paired `$resource` + service factories (client); `@Stateless @Path` services extending `BaseService<T>` with `BaseDao<T>` data access (server); entities serialized directly as JSON; Liquibase changesets for schema.

## Constraints

- **Commit format**: `feat|fix(STORY, DEV): description` — story ticket first, dev ticket second. **Never** put the epic in the first slot. Look up the correct pair in `.planning/TICKETS.md` before every commit. — Traceability; prevents the attribution bugs seen on the prior project.
- **One ticket per commit**: never mix multiple tickets in a single commit. — Clean, revertable history.
- **Commit/comment style**: simple, human-readable messages and comments; no phase numbers or internal codes (GSD `.planning/` docs commits are exempt and use plain `docs:` messages). — Readable history for humans.
- **English-only code**: all code, identifiers, and **translation keys** in English. Slovak only in translation values. — *Critical.* Mixed-language code was a real problem before.
- **Reuse existing UI**: when adding UI, copy the design already in the system; do not create new components or styles. — Visual consistency, lower maintenance.
- **Backend data access**: do not call DAOs directly — use a `BaseService` method if one is available. — Respects the service-layer pattern and container-managed transactions.
- **Liquibase**: raw SQL scripts only for INSERTs; all other schema changes via Liquibase changesets. Changeset author = `m.bijalko`. — Consistent, auditable migrations.
- **Code quality**: human-readable code; split logic into well-named methods; follow existing codebase patterns and modern practices where sensible.
- **Ticket-first**: read the Jira ticket before discussing or planning so requirements come from the ticket, not from guessing. Ask the user for any image the ticket references.
- **Tech stack (fixed)**: Java 8 / Java EE 7 / EclipseLink / RESTEasy / WildFly / MySQL (server); AngularJS 1.5 / Bower / Grunt (client). — Brownfield; do not introduce new frameworks without a decision.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Open-ended ticket-driven stream (no fixed feature roadmap) | Work arrives as Jira tickets; plan each per ticket | — Pending |
| Jira project key / commit prefix = `EP` | Project convention (EP-XXXX) | — Pending |
| Story→Dev mapping in separate `.planning/TICKETS.md` | Keep CLAUDE.md lean; dedicated, easy-to-update table | — Pending |
| Jira tickets read via Atlassian integration (text); images pasted by user | MCP can read text but not images | — Pending |
| Conventions enforced in CLAUDE.md, always loaded | Guarantees every agent follows the rules | — Pending |
| Maintain existing stack; no rewrite/migration | Brownfield production system; minimize risk | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-03 after initialization*
