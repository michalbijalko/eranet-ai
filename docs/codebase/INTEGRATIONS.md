# External Integrations

**Analysis Date:** 2026-10-16

---

## Domain Context

This system is a **Slovak public-procurement management platform** (ERANET / ZSD instance). The domain involves:
- Procurement tenders and qualification systems (supplier management)
- Electronic auctions with real-time bidding
- Document generation and archiving
- Integration with Slovak government e-government infrastructure and with the distribution company's supplier portal ("DP")

---

## Authentication & Identity

There is **no username/password login** in this server. Identity comes from an external system as a JWT bearer token, or from SAML (ÚPVS). See ARCHITECTURE.md for the request flow.

### 1. JWT bearer tokens (main mechanism)

**Issuer:** an external system (the supplier portal, labelled "DP" in the UI); this server never issues tokens.
- Verification: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/filter/BearerFilter.java` — validates the HS256 token with the `TokenSecretEranet` secret, reads the claims `user_name`, `authorities`, `LOCALE`, `EXTERNAL_AUTHORIZATION`, `EXTERNAL_FORMATTED_NAME`, then resolves the user through `BaseService.getCurrentUser()` (`SystemUserService.findByLogin`)
- Roles in the `authorities` claim: `ROLE_CLEN_KOMISIE`, `ROLE_ADMIN_ERANET`, `ROLE_DODAVATEL`, `ROLE_DODAVATEL_ADMIN`; mapped to the annotations `@ProcurerRoleAllowed`, `@AdministratorRoleAllowed`, `@SupplierRoleAllowed` (checked on the resource **method**)
- Class-level `@OauthSecured` requires a valid token on every endpoint of a service; `@OauthSecuredOptionally` makes the token optional on a method
- Libraries: `java-jwt 3.3.0` (verification in `BearerFilter`), `jjwt 0.12.6` (`JWTVerificationService`)
- Client side: redirect to the supplier portal (`$rootScope.generateOauthUrl()` in `publicERANET-client/app/scripts/controllers/main.js`); the token comes back in the URL fragment (`#/accessToken=<JWT>`), is parsed in `ng.app.js` (`loginWithToken`), stored in localStorage (`accesstoken`, `tokenExpiry`) and attached by `bearerAuthInterceptor` as `Authorization: Bearer`; `MainController` renews it silently through a hidden iframe

### 2. Other server-side gates

- `@OauthSecuredEcm` — HS256 token signed with `TokenSecretECM` and claim `system=ecm`, used by `service/ecm/EcmService.java`
- `@KeySecured` — header `ApiKey` must equal `ApiKeyDPConnector`; used by `service/jms/JmsReceiverService.java` (`/createPortfolio`, `/createSupplierPortfolio`, `/syncRoles`)
- `@JWTSecured` + `filter/JWTAuthFilter.java` — RSA-signed token, public key downloaded from the Setting `PublicKeyDownloadUrlJwtAuth`; protects the versioned API under `api/v1/*`

### 3. SAML 2.0 SSO — Slovak Government (slovensko.sk / ÚPVS)

**Provider:** Slovak eGovernment portal — ÚPVS (Ústredný portál verejnej správy). SAML only supplies the user's government identity; the application session itself still uses the bearer token.
- IdP endpoint: `https://prihlasenie.slovensko.sk/oam/fed`
- IdP metadata: `publicERANET-server/src/main/resources/META-INF/idp.metadata.xml`
- SP metadata: `publicERANET-server/src/main/resources/META-INF/sp.metadata.xml` (SP entityID under `zsdis.eranet.sk/upvs`)
- Library: `java-saml 2.2.0` (OneLogin) + `opensaml 2.6.4`
- SAML logic: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/` (`SAMLClient.java`, `SAMLInit.java`, `SAMLUtils.java`, `IdPConfig.java`, `SPConfig.java`, `AttributeSet.java`, `SAMLException.java`)
- Endpoints: `AuthenticationService` (`@Path("auth")`: `samlLogin`, `logout/{nameId}/{sessionIndex}`, `isAlive`) and `sso/SsoService.java` (`@Path("/saml")`: `/post/ac`, `/redirect/slo`, `/redirect/sloresponse`); after the assertion consumer step the browser is redirected to `#/associateUser/<hash>/...`
- SAML assertions: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/SamlAssertionContainer.java`
- Keystore for signing: `SAMLClient` loads `META-INF/alice2.jks` (`prod.jks` is also committed)

---

## Data Storage

### Primary Application Database — MySQL

- **Type:** MySQL 5.7 in Docker (`eranet_mysql`, database `eranet_db`, port `${MYSQL_PORT:-3307}:3306`); the local dev database used by `configS.bat` is `zsd-wildfly` on `localhost:3306`
- **JTA data source JNDI:** `PublicZsdDS` (WildFly) / `PublicDS` (GlassFish legacy)
- **Config:** `publicERANET-server/docker-compose.yml`
- **Charset:** `utf8mb4`, collation `utf8mb4_slovak_ci`
- **ORM:** EclipseLink 2.6.4 JPA; persistence unit `PublicTestZsdPU`
- **Persistence descriptor:** `publicERANET-server/src/main/resources/META-INF/persistence.xml`
- **Schema migrations:** Liquibase — master changelog `publicERANET-server/src/main/sql/db.changelog-master.xml` (includes root changelogs `1.0`, `1.1`, `hurtuk`, `spireng`, `dp-connector` and the per-version changelogs up to `2.4.0`); runners `configS.bat` (update) and `configR.bat` (rollback one changeset)
- **File storage:** uploaded files are stored as BLOBs in the MySQL `file` table (`dao/FileDao.java`)

### JCR Content Repository (Jackrabbit) — not used by code

- `docker-compose.yml` still defines a `jackrabbit_mysql` container (`jackrabbit_db`, port `${JACKRABBIT_PORT:-3308}`), but the pom has no `javax.jcr` dependency and no code references Jackrabbit.

---

## Document Generation

### Aspose

Commercial Aspose libraries generate and process Office/PDF documents server-side:
- `aspose-words 16.3.0`, `aspose-pdf 10.6.2`, `aspose-email 5.9.0` (license call only), `aspose-cells 8.5.2`
- License: `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic` (also tracked under `WEB-INF/`); the `License` objects are applied in `ProcurementService.java`
- JARs served from local Maven repo: `publicERANET-server/lib/`

### Apache POI

- `poi 3.11` + `poi-ooxml 3.11` — Excel (OOXML) processing in several services

---

## Email (SMTP)

**Library:** Apache Commons Email `1.3.3`
**Config class:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/configuration/MailServerConfiguration.java`

Mail settings are **not** in the `Setting` table: they are JNDI `Properties` read by `service/ConfigurationService.java` (see Environment Configuration):
- `HostName`, `SmtpPort`, `Login`, `Password`, `SSLConnectionIsOn`, `From`

Used for:
- Procurement notifications (invitations, status updates)
- Qualification system approval emails
- URSO publication notices (`UrsoPublishingService` sends an email to the Setting `UrsoEmail`)
- Undelivered email retry scheduler (`UndeliveredEmailNotificationSchedulerService.java`)

---

## Slovak Government / Regulatory Integrations

### UVO — Úrad pre verejné obstarávanie (Slovak Public Procurement Office)

**Purpose:** Publish procurement notices to the official Slovak procurement bulletin
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java` (Unirest calls to the Setting `UvoConnectorUrl`)
- Scheduler: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoScheduleService.java` (its `@Schedule` is commented out)

### EKS — Elektronické kontraktačné systém (Electronic Contracting System)

**Purpose:** Integration with the Slovak national electronic contracting platform
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/EksService.java` (`@Path("sc/eks")`, Setting `EksConnectorUrl`)
- Request/response DTOs: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/helpDto/EksRequest.java`, `EksZipFileResponse.java`

### URSO — Úrad pre reguláciu sieťových odvetví (Regulatory Office for Network Industries)

**Purpose:** Reporting to the Slovak network industries regulator — implemented as an email, not a remote API
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UrsoPublishingService.java` (`sc/ursoPublishing`), driven by `ScheduleService.everyDayUrso`

---

## Distribution-Company Systems

### DP supplier-portal connector

- Receiver: `service/jms/JmsReceiverService.java` (`jms/receive/*`, guarded by `@KeySecured`), plus `service/JmsMessageService.java`, `service/ErrorFromJmsService.java`, `service/SyncRolesService.java`
- Despite the `jms` name this is HTTP: outbound calls go through Unirest to the Setting `DPConnectorUrl` (`service/jms/BaseJmsService.java`)
- DTOs: package root `dperanet/` and `serialization/dto/dp`; Liquibase changelog `db.changelog-dp-connector.xml`

### xECM document system (SOAP)

- Service: `service/ecm/EcmService.java` (`@Path("ecm")`, `/createProcurement`, `/createDocument`), secured by `@OauthSecuredEcm`
- Generated JAX-WS client: package root `ixtent/ws/` (`EISOIXECMServices`); WSDLs `META-INF/xecm.wsdl`, `xecm-test.wsdl`; keystores `xecm.jks`, `xemc-test.jks`
- Libraries: Apache CXF `3.4.5` (core, JAX-WS frontend, WS-Security, HTTP transports)

### Other

- `TnefService` — Outlook appointment files via the Setting `TnefUrl`
- `PublicResourceService` / `SettingPublicService` (`@Path("public")`) — public (no-token) redirect and attachment endpoints
- `ScheduleService` + `ScheduleRestService` (`sc/schedule`) — hourly, daily, company-statistics and URSO jobs

---

## Real-Time / WebSocket

**Protocol:** JSR-356 Java WebSocket
- `ws/PingEndpoint.java` — `/websockets/ping/{groupId}/{userId}/{guid}` (`groupId` = procurement ID); used by the client in `publicERANET-client/app/scripts/controllers/procurement/evaluationPhase/onlineOpening.js` via `angular-websocket ~2.0.0`; the host comes from the `Host` server setting
- `ws/RealTimeEndpoint.java` — `/websockets/realtime`, a `@Singleton` pushing on a 1-second `@Schedule`; no client code connects to it
- **Use cases:**
  - Live online-presence tracking of companies during procurement opening sessions
  - Real-time chat messages in opening rounds (`ProcurementOpeningChatMessage`)
  - Broadcast signals: `refreshPage`, `closeOpening`, `refreshMessage`, `refreshUsers`, `refreshMessagesAndCompanies`

---

## Electronic Auction Engines

`AuctionService` selects the engine from the Setting `AuctionType`:

- **ProEBiz (SOAP):** `service/ProebizService.java` (uses the Setting `ProebizUrl`); generated JAX-WS client in `serialization/dto/proebiz/` (`WebserviceService.java`, `types/`); `LoggingHandler.java` logs SOAP messages (also reused by `EcmService`). The WSDL is `src/main/webapp/WEB-INF/proebiz_schema.wsdl`, while `getPort()` looks it up on the classpath under `META-INF/` — see CONCERNS.md.
- **iTender:** `service/ItenderService.java` is a stub (every method throws `UnsupportedOperationException`); `ItenderConfiguration` (JNDI) carries `Url`, `ClientId`, `Hash`, `CreationDelay`.

---

## CI / Deployment

### CI Pipeline

- Travis CI — `publicERANET-client/.travis.yml`
  - Tests Node.js `0.8` and `0.10`
  - Installs `bower` and `grunt-cli` globally, then runs `bower install` (no `script:` section)
  - No server-side CI config detected

### Database Migration

- Liquibase CLI (external tool, not Maven-managed)
- `configS.bat` (update) and `configR.bat` (`rollback-count --count=1`) at project root
- Connect to `localhost:3306/zsd-wildfly` with the WildFly-bundled MySQL connector (`c:\WildFly\11.0.0\...\mysql-connector-java-8.0.22.jar`)

### Containerisation

- Docker Compose: `publicERANET-server/docker-compose.yml` — MySQL containers only; no application container defined
- Service name pattern: `publiceranet-server${BRANCH}` — supports branch-based parallel environments

---

## Environment Configuration

**Docker env vars** (see `publicERANET-server/.env.example`): `BRANCH`, `MYSQL_PORT`, `JACKRABBIT_PORT`.

**JNDI configuration (must be provisioned in WildFly):** `ConfigurationService` reads `java:/PublicServer/<AppName>/<Name>` for:
- `MailServerConfiguration` — SMTP settings
- `GeneralConfiguration` — `Host`
- `ItenderConfiguration` — iTender connection
- `SecretsConfiguration` — `TokenSecretECM`, `TokenSecretEranet`, `ApiKeyDPConnector`

`BearerFilter` cannot validate tokens without the secrets.

**Additional config stored in DB (`Setting` entity):** connector URLs and credentials (`UvoConnectorUrl`, `EksConnectorUrl`, `DPConnectorUrl`, `ProebizUrl`, `TnefUrl`, `Ecm*`), `AuctionType`, `UrsoEmail`, `PublicKeyDownloadUrlJwtAuth`, and the notification settings.

**Secrets location:**
- Token secrets and API key: WildFly JNDI (`SecretsConfiguration`); SMTP password: WildFly JNDI (`MailServerConfiguration`)
- Connector credentials: MySQL `Setting` table (runtime)
- SAML/ECM keystores: `*.jks` under `META-INF/` and `WEB-INF/` — committed to repo
- Aspose license: `Aspose.Total.Java.lic` — committed to repo

---

## Client-Side External References

- Google Fonts: `https://fonts.googleapis.com/css?family=Roboto:400,700` (`publicERANET-client/app/index.html`)
- Supplier portal and public site hosts are hard-coded in client scripts (`main.js`, `login.js`, `mainInterceptor.js`, `publicList.js`, `publicListDetails.js`, `publicQualificationSystem.js`)
- `DpRemoteNotificationController` (`views/include/dpRemoteNotification*.html`) is driven by the server settings `RemoteSynchronization` and `RemoteSupplierPortalUrl`

---

*Integration audit: 2026-10-16*
