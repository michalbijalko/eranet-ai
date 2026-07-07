# Requirements: VSE / ERANET — Ticket-Driven Development

**Defined:** 2026-06-03
**Core Value:** Every change traces to exactly one Jira ticket, follows existing patterns, and ships in clean, disciplined commits — without breaking the live procurement platform.

## v1 Requirements

This milestone delivers the **engineering working agreement** for ongoing, ticket-driven work. Each requirement is an enforceable convention. Actual feature/bug requirements arrive per Jira ticket and are not enumerated here.

### Conventions

- [ ] **CONV-01**: All engineering rules are captured in `CLAUDE.md` so they load into every agent's context automatically
- [ ] **CONV-02**: Code commits use `feat|fix(STORY, DEV): description` with the story ticket first, dev ticket second; the epic is never in the first slot
- [ ] **CONV-03**: Each commit contains exactly one ticket's work — tickets are never mixed in a single commit
- [ ] **CONV-04**: All code, identifiers, and translation keys are written in English; Slovak appears only in translation values
- [ ] **CONV-05**: New UI reuses the existing system design (copy existing components/styles); no new component library or redesign
- [ ] **CONV-06**: Backend changes use a `BaseService` method when available instead of calling a DAO directly
- [ ] **CONV-07**: Liquibase governs schema changes — raw SQL only for INSERTs, all other changes as changesets authored by `m.bijalko`
- [ ] **CONV-08**: Commits, comments, and code are simple and human-readable (no phase numbers/internal codes except docs commits); logic is split into well-named methods following existing patterns

### Workflow

- [ ] **FLOW-01**: A Story→Dev ticket mapping table is maintained in `docs/TICKETS.md` and referenced from `CLAUDE.md`
- [ ] **FLOW-02**: Before any discussion or planning, the relevant `EP-XXXX` Jira ticket is read via the Atlassian integration so requirements come from the ticket, not from guessing
- [ ] **FLOW-03**: When a ticket depends on an image, the agent asks the user to paste it rather than guessing from text alone

## v2 Requirements

Per-ticket feature and bug work is planned individually as tickets arrive (read EP ticket → discuss/plan → implement → commit). No fixed v2 scope is enumerated for an open-ended stream.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Framework migration / rewrite (AngularJS → Angular, Java EE → Spring) | Brownfield production system; maintain existing stack |
| New UI component library or visual redesign | Reuse existing SmartAdmin/Bootstrap design |
| Relaxing commit/ticket-discipline rules | Locked by decision |
| Slovak text in code or translation keys | English-only code is a critical constraint |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONV-01 | Phase 1 | Pending |
| CONV-02 | Phase 1 | Pending |
| CONV-03 | Phase 1 | Pending |
| CONV-04 | Phase 1 | Pending |
| CONV-05 | Phase 1 | Pending |
| CONV-06 | Phase 1 | Pending |
| CONV-07 | Phase 1 | Pending |
| CONV-08 | Phase 1 | Pending |
| FLOW-01 | Phase 1 | Pending |
| FLOW-02 | Phase 1 | Pending |
| FLOW-03 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-03*
*Last updated: 2026-06-03 after roadmap creation*
