---
name: code-review
description: SEAS team checklist for reviewing code changes before they ship. Use when reviewing a diff, a PR, or just-written code, or when the user asks to "review", "skontroluj", "prejdi zmeny". Run on changed code, not the whole codebase.
disable-model-invocation: false
---

# Code review

Review the change against SEAS standards. Focus on team-specific concerns.

## Checklist

- **Ticket traceability** — the change maps to exactly one Jira `EP-XXXX` ticket; the commit
  message uses the `feat|fix(STORY, DEV): description` format with the correct Story→Dev
  pair from `docs/TICKETS.md`. No mixed tickets in one commit.
- **Conventions** — matches the `coding-conventions` skill: Java EE / AngularJS 1.5
  patterns, naming, ES5 style, array DI in AngularJS, BaseService/BaseDao layering.
- **Layer discipline** — services never call `EntityManager` directly; they go through a
  DAO. The service layer is not bypassed. New service classes are registered in
  `ApplicationConfig.java`.
- **No duplication** — nothing re-implements an existing service, DAO, directive, or
  resource; no accidental copies of existing functionality.
- **Scope** — only what the ticket asked for; no stray extra functionality.
- **Security** — `@RolesAllowed` applied correctly (see `security` skill); no secrets in
  code or logs; external service calls go server-side only.
- **Database changes** — schema changes use Liquibase changesets (author `m.bijalko`), not
  raw DDL. Raw SQL only for INSERT data. New changesets added to the changelog master.
- **English-only identifiers** — no Slovak in code, field names, or translation keys.
  Slovak appears only in i18n value files.
- **Tests** — if the client-side logic is testable, a Karma/Jasmine spec is added or
  updated. See `testing`.

## Always also check

- **No leaked secrets** — no passwords, API keys, SAML keystores passphrases, or SMTP
  credentials in the diff. (OIDC/SMTP config lives in the `Setting` DB table; SAML
  keystores are committed but their passphrases must not be.)
- **Localization** — user-facing text uses translation keys (English key names) with Slovak
  values in `app/i18n/sk.json`; not hardcoded strings in controllers or templates.
- **Performance** — no N+1 query patterns in new DAO/service code; Criteria API queries
  are properly parameterized.
- **Error handling** — business violations throw `WebApplicationException` with an
  appropriate HTTP status; errors are logged, not swallowed.
- **Backward compatibility** — existing REST URLs and JSON field names preserved (the
  AngularJS client binds to them directly); any change must be backwards-compatible or
  coordinated with a client-side update.

## Output

Summarize the change in a few bullets, then list issues grouped by severity
(must-fix / should-fix / nice-to-have). Be specific with file and line references.
