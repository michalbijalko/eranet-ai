---
name: security
description: Security guidelines for ZSD - role-based access, secrets handling, input sanitization, and the rule that sensitive config never lives in code. Use whenever adding endpoints, handling credentials, integrating external systems, or when the user mentions "security", "oprávnenia", "API kľúč", "roly".
---

# Security

ZSD is a public-procurement platform with legal obligations. These rules are mandatory.

## Hard rules

- **No secrets in code.** Token secrets, the connector API key and the SMTP password live in
  WildFly JNDI (`SecretsConfiguration`, `MailServerConfiguration`); connector URLs and credentials
  live in the `Setting` table (DB-driven config). Never put them in source files or commit them.
- **Never call external/third-party systems from the browser.** All outbound calls to UVO,
  EKS, URSO, ProEBiz (SOAP), or any other external system go through the Java server.
  The AngularJS client only calls `webresources/sc/...` on our own backend.
- **Authorize on the server.** Never trust client-sent role or permission data. Always
  put the role annotation on the server endpoint method (see Authorization below).

## Authorization (bearer token + role annotations)

- Services carry class-level `@OauthSecured` (a valid bearer token is required); `BearerFilter`
  verifies the token and reads the `authorities` claim.
- Role checks are **method-level** annotations: `@ProcurerRoleAllowed`, `@SupplierRoleAllowed`,
  `@AdministratorRoleAllowed` (both procurer and supplier annotations = either role may call).
  `BearerFilter` does **not** read them from the class, so a class-level role annotation protects nothing.
- `@RolesAllowed` is used by only three services; don't add it to new endpoints.
- Public endpoints (login helpers, SAML callbacks, public listings) are marked `@PermitAll`; do not
  put `@OauthSecured` or a role annotation on them.
- Connector endpoints use their own gates: `@KeySecured` (API key), `@OauthSecuredEcm` (ECM token),
  `@JWTSecured` (`api/v1/*`). Don't invent a new mechanism.
- An EJB security violation throws `AccessLocalException`, mapped to HTTP 403 by
  `AccessLocalExceptionHandler`. Do not bypass this.
- For new endpoints, always ask: who can call this? If there are multiple roles with
  different access levels, check whether an existing role annotation already applies before
  creating new ones.
- Suppliers write messages. Communication/messaging endpoints (and anything attached to
  them) must allow BOTH procurers and suppliers — annotate the method with both
  `@ProcurerRoleAllowed` and `@SupplierRoleAllowed`.

## Input sanitization

- There is no central request sanitizer. Supplier-scoped filtering is enforced by the `BaseService`
  helpers `checkIfSupplierFilterPresent` and `checkIfSupplierWorkWithOwnCompany` — use them for any
  new query a supplier can reach, so a client cannot override server-controlled filters.
- Uploaded HTML is cleaned with AntiSamy (`FileService`, policy `META-INF/antisamy-anythinggoes.xml`).
- Validate and reject malformed input at the REST layer; don't pass unvalidated data into
  JPA queries.

## Secrets location reference

| Secret | Location |
|--------|----------|
| `TokenSecretEranet`, `TokenSecretECM`, `ApiKeyDPConnector` | WildFly JNDI `java:/PublicServer/<AppName>/SecretsConfiguration` |
| SMTP host, port, login, password | WildFly JNDI `.../MailServerConfiguration` |
| iTender URL, client id, hash | WildFly JNDI `.../ItenderConfiguration` |
| UVO / EKS / DP-connector URLs and credentials | `Setting` table (DB) |
| SAML / ECM keystores | `META-INF/*.jks` (and `WEB-INF/*.jks`) — committed |
| Aspose license | `META-INF/Aspose.Total.Java.lic` (and `WEB-INF/`) — committed |
| MySQL DB credentials | WildFly data-source config / Docker `.env` file |

The keystores and the Aspose license are committed (see CONCERNS.md for the risk), but their
passphrases must **never** appear in logs, docs or new code.

## External integrations

All outbound HTTP calls (Unirest / Apache HttpClient) must originate server-side. The
browser must never receive a third-party URL, token, or API key. Example: the AngularJS
client requests `/webresources/sc/uvo/...`; `UvoService.java` makes the real UVO API call.

## CORS

The application is served same-origin (WildFly serves both WAR and static client files).
No CORS configuration is needed for normal operation. If a cross-origin setup is ever
required, configure an explicit allowlist — never `*` in production.

## What to check before an external integration

- Is the credential stored in WildFly JNDI or the `Setting` table, not in code?
- Does the call originate server-side, not from AngularJS?
- Is the endpoint protected by `@OauthSecured` plus a method-level role annotation, or `@PermitAll` (deliberately)?
- Are the inputs validated before being used in a query or passed to the external system?
