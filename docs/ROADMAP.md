# Roadmap: VSE / ERANET — Ticket-Driven Development

**Project:** VSE / ERANET — Ticket-Driven Development
**Granularity:** Coarse
**Mode:** MVP
**Coverage:** 11/11 requirements mapped

---

## Phases

- [ ] **Phase 1: Conventions & Jira Working Agreement** - Capture all engineering rules in CLAUDE.md and establish the ticket-first workflow scaffold so every agent change is traceable, consistent, and governed from day one.

---

## Phase Details

### Phase 1: Conventions & Jira Working Agreement
**Goal**: Every engineering rule is documented and discoverable; the Jira-ticket-first workflow is operational; agents have no ambiguity about commit format, language, UI reuse, or data-access patterns.
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: CONV-01, CONV-02, CONV-03, CONV-04, CONV-05, CONV-06, CONV-07, CONV-08, FLOW-01, FLOW-02, FLOW-03
**Success Criteria** (what must be TRUE):
  1. `CLAUDE.md` exists at the workspace root and contains all eight conventions (commit format, one-ticket-per-commit, English-only code, UI reuse, BaseService-first, Liquibase, readability) plus references to `docs/TICKETS.md` — readable and loaded automatically into every agent context.
  2. `docs/TICKETS.md` exists with a Story→Dev ticket mapping table scaffold and is referenced from `CLAUDE.md` so agents look it up before every commit.
  3. An agent starting a new ticket can verify the correct commit prefix by reading `CLAUDE.md` and `docs/TICKETS.md` without asking the user for format guidance.
  4. The English-only rule and the Jira-ticket-first rule are documented explicitly enough that a new agent session rejects Slovak identifiers/keys and refuses to plan work before reading the EP ticket.
**Plans**: TBD

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Conventions & Jira Working Agreement | 0/? | Not started | - |

---

*Roadmap created: 2026-06-03*
