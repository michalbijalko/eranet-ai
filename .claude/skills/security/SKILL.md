---
name: security
description: Security guidelines for SEAS - role-based access, secrets handling, input sanitization, and the rule that sensitive config never lives in code. Use whenever adding endpoints, handling credentials, integrating external systems, or when the user mentions "security", "oprávnenia", "API kľúč", "roly".
---

# Security

SEAS is a public-procurement platform with legal obligations. These rules are mandatory.

## Hard rules

- **No secrets in code.** OIDC `ClientSecret`, SMTP passwords, and any API credentials
  live in the `Setting` table (DB-driven config), not in source files. Never commit them.
- **Never call external/third-party systems from the browser.** All outbound calls to UVO,
  EKS, URSO, ProEBiz (SOAP), or any other external system go through the Java server.
  The AngularJS client only calls `webresources/sc/...` on our own backend.
- **Authorize on the server.** Never trust client-sent role or permission data. Always
  enforce `@RolesAllowed` on the server.

## Authorization (Java EE / EJB security)

- Default annotation on service classes: `@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)`.
- Use `@PermitAll` only for genuinely public endpoints (e.g., login, SAML callbacks, public
  procurement listings that require no login).
- The EJB container enforces `@RolesAllowed`; a violation throws `AccessLocalException`,
  which is mapped to HTTP 403 by `AccessLocalExceptionHandler`. Do not bypass this.
- For new endpoints, always ask: who can call this? If there are multiple roles with
  different access levels, check whether any existing role/group enum value applies before
  creating new ones.

## Input sanitization

- `FindParametersSanitizer` (JAX-RS interceptor) strips forbidden filter fields from
  `FindParameters` objects. Ensure new query parameters that must be server-controlled are
  registered there and cannot be overridden by a client request.
- Validate and reject malformed input at the REST layer; don't pass unvalidated data into
  JPA queries.

## Secrets location reference

| Secret | Location |
|--------|----------|
| OIDC ClientId, ClientSecret, TenantId, etc. | `Setting` table (DB) |
| SMTP host, port, login, password | `Setting` table (DB) |
| UVO / EKS API credentials | `Setting` table (DB) |
| SAML signing keystores | `META-INF/alice2.jks` (test), `prod.jks` (prod) — committed |
| Aspose license | `META-INF/Aspose.Total.Java.lic` — committed |
| MySQL DB credentials | WildFly data-source config / Docker `.env` file |

SAML keystores and the Aspose license are committed by design (they are binary license
files, not rotatable API keys), but their passphrases must **never** appear in logs or code.

## External integrations

All outbound HTTP calls (Unirest / Apache HttpClient) must originate server-side. The
browser must never receive a third-party URL, token, or API key. Example: the AngularJS
client requests `/webresources/sc/uvo/...`; `UvoService.java` makes the real UVO API call.

## CORS

The application is served same-origin (WildFly serves both WAR and static client files).
No CORS configuration is needed for normal operation. If a cross-origin setup is ever
required, configure an explicit allowlist — never `*` in production.

## What to check before an external integration

- Is the credential stored in `Setting` table, not in code?
- Does the call originate server-side, not from AngularJS?
- Is the endpoint protected by `@RolesAllowed` or `@PermitAll` (deliberately)?
- Are the inputs validated before being used in a query or passed to the external system?
