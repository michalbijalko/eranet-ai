---
name: authentication
description: How authentication works in SEPS - local username/password, SAML 2.0 SSO via slovensko.sk (ÚPVS), and OIDC/OAuth2. Use whenever touching login flows, session handling, protected endpoints, or SSO. Do not reinvent — work with the existing AuthenticationService and OIDCService.
---

# Authentication

SEPS supports three authentication mechanisms, all implemented in the existing codebase.
Do not build a new auth system — extend or fix the existing one.

## Mechanisms

### 1. Local login (username + password)

- User record in `SystemUser` table; passwords hashed with SHA-256 via Apache Commons Codec `DigestUtils`.
- Login history tracked in `SystemUserAuthHistory`.
- Implementation: `AuthenticationService.java`.
- Do not store passwords in plaintext; never log passwords.

### 2. SAML 2.0 SSO — Slovak government (slovensko.sk / ÚPVS)

- Identity provider: `https://prihlasenie.slovensko.sk/oam/fed` (ÚPVS — Ústredný portál verejnej správy).
- Library: `java-saml 2.2.0` (OneLogin) + `opensaml 2.6.4`.
- SP and IdP metadata: `publicERANET-server/src/main/resources/META-INF/` (`sp.metadata.xml`, `idp.metadata.xml`, SEPS variants).
- SAML signing keystore: `alice2.jks` (test) / `prod.jks` (production) — both committed to the repo.
- Code: `publicERANET-server/.../saml/` (`SAMLClient`, `SAMLInit`, `SAMLUtils`) and `.../sso/UpvsSsoService.java`.
- Changes here require careful testing — the ÚPVS integration is government-regulated.

### 3. OIDC / OAuth2 (OpenID Connect)

- Configurable OIDC provider (Microsoft Entra / Azure AD inferred from `TenantId`).
- Config: `OIDCConfiguration.java` — fields `BaseURL`, `TenantId`, `ClientId`, `ClientSecret`, `StateSecret`, `Scope`, `RedirectURIPostfix` are stored in the `Setting` table (DB-driven), not in code.
- JWT validation: `nimbus-jose-jwt 9.37.3` + `java-jwt 3.3.0`.
- Server-side flow: `OIDCService.java`.
- Client-side: `angularjs-oauth2 ~1.2.3` (Bower) — the existing AngularJS OAuth2 library.

## Rules

- Token validation and secret-bearing exchanges happen **server-side only** — never expose `ClientSecret` or private keys to the browser.
- The `ClientSecret` and SMTP credentials live in the `Setting` DB table — update them via the admin UI or direct DB row, never commit them to the repo.
- SAML keystores (`alice2.jks`, `prod.jks`) are already committed; treat them with care and never log their passphrases.
- Protected REST endpoints must carry `@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)` (class-level default); use `@PermitAll` only for genuinely public endpoints.
- The `AccessLocalException` (EJB security rejection) is mapped to HTTP 403 by `AccessLocalExceptionHandler` — this is the existing security backstop; don't bypass it.

## What to check before changing auth

- Identify which mechanism is involved (local / SAML / OIDC) and read the relevant service class before writing code.
- SAML changes require re-testing the ÚPVS redirect flow; OIDC changes may require updating the `Setting` table entries in each environment.
- Never change the password-hashing algorithm without a migration plan for existing hashes.
