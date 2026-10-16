---
name: authentication
description: How authentication works in ZSD - external JWT bearer tokens verified by BearerFilter, SAML 2.0 SSO via slovensko.sk (ÚPVS), and the API-key / ECM / RSA-JWT gates on connector endpoints. Use whenever touching login flows, token handling, protected endpoints, role annotations, or SSO. Do not reinvent — extend BearerFilter and the existing annotations.
---

# Authentication

ZSD has **no username/password login** in the server. Identity arrives as a JWT bearer token
issued by an external system (the supplier portal, shown as "DP" in the UI), plus SAML 2.0 for
ÚPVS government identity. Do not build a new auth system — extend or fix the existing one.

## Mechanisms

### 1. JWT bearer token (main mechanism)

- The token is issued **outside** this server; the server only verifies it (HS256, secret `TokenSecretEranet`).
- Verification: `filter/BearerFilter.java` (registered as a singleton in `ApplicationConfig.getSingletons()`).
  It reads the claims `user_name`, `authorities`, `LOCALE`, `EXTERNAL_AUTHORIZATION`, `EXTERNAL_FORMATTED_NAME`;
  `BaseService.getCurrentUser()` then resolves the user with `SystemUserService.findByLogin`.
- Roles come from the `authorities` claim: `ROLE_CLEN_KOMISIE`, `ROLE_ADMIN_ERANET`, `ROLE_DODAVATEL`, `ROLE_DODAVATEL_ADMIN`.
- Libraries: `java-jwt 3.3.0` (in `BearerFilter`), `jjwt 0.12.6` (`JWTVerificationService`).
- Client flow: `$rootScope.generateOauthUrl()` (`controllers/main.js`) redirects to the supplier portal; the token
  returns as `#/accessToken=<JWT>`, is parsed by `loginWithToken` in `ng.app.js`, stored in localStorage
  (`accesstoken`, `tokenExpiry`) and attached by `bearerAuthInterceptor`. `MainController` renews it silently
  through a hidden iframe. `angularjs-oauth2` is installed but **not loaded** — don't use it.

### 2. SAML 2.0 SSO — Slovak government (slovensko.sk / ÚPVS)

- Identity provider: `https://prihlasenie.slovensko.sk/oam/fed` (ÚPVS — Ústredný portál verejnej správy).
- Library: `java-saml 2.2.0` (OneLogin) + `opensaml 2.6.4`.
- SP and IdP metadata: `publicERANET-server/src/main/resources/META-INF/` (`sp.metadata.xml`, `idp.metadata.xml`).
- SAML signing keystore: `SAMLClient` loads `META-INF/alice2.jks`; `prod.jks` is also committed.
- Code: `.../saml/` (`SAMLClient`, `SAMLInit`, `SAMLUtils`), `.../sso/SsoService.java` (`/saml/post/ac`,
  `/redirect/slo`, `/redirect/sloresponse`) and `AuthenticationService` (`auth/samlLogin`, `auth/logout/{nameId}/{sessionIndex}`).
- SAML only supplies the government identity; after the assertion the browser is redirected to `#/associateUser/<hash>/...`.
- Changes here require careful testing — the ÚPVS integration is government-regulated.

### 3. Other gates (connectors and API)

- `@OauthSecuredEcm` — HS256 token signed with `TokenSecretECM`, claim `system=ecm` (`EcmService`).
- `@KeySecured` — header `ApiKey` must equal `ApiKeyDPConnector` (`JmsReceiverService`).
- `@JWTSecured` + `JWTAuthFilter` — RSA-signed token; public key downloaded from the Setting `PublicKeyDownloadUrlJwtAuth` (`api/v1/*`).

## Rules

- Token validation and secret-bearing exchanges happen **server-side only** — never expose a token secret, API key or private key to the browser.
- The token secrets (`TokenSecretEranet`, `TokenSecretECM`, `ApiKeyDPConnector`) live in WildFly JNDI
  (`java:/PublicServer/<AppName>/SecretsConfiguration`, read by `ConfigurationService`) — never in code or the repo.
- SAML/ECM keystores (`alice2.jks`, `prod.jks`, `xecm.jks`, …) are already committed; treat them with care and never log their passphrases.
- **Class-level `@OauthSecured`** makes every endpoint of a service require a valid token. Put the role annotations
  (`@ProcurerRoleAllowed`, `@SupplierRoleAllowed`, `@AdministratorRoleAllowed`) **on each method** — `BearerFilter`
  reads them from the method only, so a class-level role annotation does nothing.
- Role enforcement is done by the custom annotations in `BearerFilter`, not by `@RolesAllowed` (only three services use it);
  don't add `@RolesAllowed` to new endpoints. The `SecurityContext` that `BearerFilter` installs answers `true` to `isUserInRole`.
- `AccessLocalException` (EJB security rejection) is still mapped to HTTP 403 by `AccessLocalExceptionHandler`.
- Never log tokens, secrets or passphrases.

## What to check before changing auth

- Identify which mechanism is involved (bearer token / SAML / connector gate) and read `BearerFilter` or the relevant service before writing code.
- For a new endpoint, decide who may call it (procurer, supplier, administrator, public) and annotate the method accordingly.
- SAML changes require re-testing the ÚPVS redirect and logout flow.
- `BearerFilter` cannot validate tokens unless the JNDI secrets are provisioned in WildFly.
