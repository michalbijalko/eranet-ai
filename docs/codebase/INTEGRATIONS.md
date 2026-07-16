# External Integrations

**Analysis Date:** 2026-06-03

---

## Domain Context

This system is a **Slovak public-procurement management platform** (ERANET / PSK — "Systém riadenia obstarávaní"). The domain involves:
- Procurement tenders and qualification systems (supplier management)
- Electronic auctions with real-time bidding
- Document generation and archiving
- Integration with Slovak government e-government infrastructure

---

## Authentication & Identity

### 1. Custom Local Authentication

**Approach:** Username/password login backed by the application's own `SystemUser` table in MySQL.
- Passwords hashed with SHA (`commons-codec DigestUtils`)
- Auth history tracked in `SystemUserAuthHistory` entity
- Implementation: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java`

### 2. SAML 2.0 SSO — Slovak Government (slovensko.sk / ÚPVS)

**Provider:** Slovak eGovernment portal — ÚPVS (Ústredný portál verejnej správy)
- IdP endpoint: `https://prihlasenie.slovensko.sk/oam/fed`
- IdP metadata: `publicERANET-server/src/main/resources/META-INF/idp.metadata.xml`
- IdP metadata for VSE (partner institution): `publicERANET-server/src/main/resources/META-INF/idp.vse.metadata.xml`
- SP metadata: `publicERANET-server/src/main/resources/META-INF/sp.metadata.xml`, `sp.vse.metadata.xml`
- Library: `java-saml 2.2.0` (OneLogin) + `opensaml 2.6.1`
- SAML logic: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/` (`SAMLClient.java`, `SAMLInit.java`, `SAMLUtils.java`, `IdPConfig.java`, `SPConfig.java`, `AttributeSet.java`)
- SSO service (UPVS-specific flow): `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/UpvsSsoService.java`
- SAML assertions: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/SamlAssertionContainer.java`
- Keystore for signing: `publicERANET-server/src/main/resources/META-INF/alice2.jks` and `prod.jks`
- Additional dev/test certs and metadata: `publicERANET-server/src/main/resources/META-INF/dev.jks`, `dev.idp.metadata.xml`, `dev.sp.metadata.xml`, `fix.jks`

This instance has no OIDC/OAuth2 integration — authentication is local form login and SAML 2.0 (ÚPVS) only.

---

## Data Storage

### Primary Application Database — MySQL

- **Type:** MySQL 5.7
- **Container name:** `eranet_mysql`
- **Database name:** `eranet_db`
- **JTA data source JNDI:** `EranetDS` (WildFly) / `PublicDS` (GlassFish legacy)
- **Port (Docker):** `${MYSQL_PORT:-3307}:3306`
- **Config:** `publicERANET-server/docker-compose.yml`
- **Charset:** `utf8mb4`, collation `utf8mb4_slovak_ci`
- **ORM:** EclipseLink 2.7.3 JPA; persistence unit `EranetPU`
- **Persistence descriptor:** `publicERANET-server/src/main/resources/META-INF/persistence.xml`
- **Schema migrations:** Liquibase — master changelog `publicERANET-server/src/main/sql/db.changelog-master.xml`; migration script runner `configS.bat`

### JCR Content Repository (Jackrabbit) Database — MySQL

- **Type:** MySQL 5.7 (dedicated instance for Apache Jackrabbit)
- **Container name:** `jackrabbit_mysql`
- **Database name:** `jackrabbit_db`
- **Port (Docker):** `${JACKRABBIT_PORT:-3308}:3306`
- **Config:** `publicERANET-server/docker-compose.yml`
- **Purpose:** Stores binary documents/files managed through the JCR API (`javax.jcr 2.0`, provided scope in `pom.xml`)
- **Note:** `publicERANET-server/buildPath.json` flag `"documentStore": false` suggests the JCR store can be toggled off

---

## File Storage

### Aspose Document Generation

Commercial Aspose libraries are used to generate and process Office/PDF documents server-side:
- `aspose-words 16.3.0` — Word document generation
- `aspose-pdf 16.10.0` — PDF generation
- `aspose-email 5.9.0` — Email/MSG file processing
- `aspose-cells 8.5.2` — Excel file generation
- License: `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic` (loaded at startup in `AuthenticationService.java`)
- `aspose-pdf` is pulled from the official Aspose Maven repository (`https://releases.aspose.com/java/repo/`); `aspose-words`, `aspose-email`, and `aspose-cells` are served from the in-project local repo `publicERANET-server/lib/`

### Apache POI

- `poi 3.11` + `poi-ooxml 3.11` — additional Excel (OOXML) processing
- Source: `publicERANET-server/pom.xml`

---

## Email (SMTP)

**Library:** Apache Commons Email `1.3.3`
**Config class:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/configuration/MailServerConfiguration.java`

Config fields stored in the application's `Setting` table (DB-driven configuration):
- `HostName` — SMTP server hostname
- `SmtpPort` — SMTP port
- `Login` — SMTP account login
- `Password` — SMTP account password
- `SSLConnectionIsOn` — SSL toggle
- `From` — sender address
- `BccAddresses` — list of BCC recipients

Used extensively throughout the codebase for:
- Procurement notifications (invitations, status updates)
- Qualification system approval emails
- Company registration / password reset prompts
- Internal request email confirmations
- Undelivered email retry scheduler (`UndeliveredEmailNotificationSchedulerService.java`)

---

## Slovak Government / Regulatory Integrations

### UVO — Úrad pre verejné obstarávanie (Slovak Public Procurement Office)

**Purpose:** Publish procurement notices to the official Slovak procurement bulletin
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java`
- Scheduler: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoScheduleService.java`
- HTTP client: Unirest (`com.mashape.unirest 1.4.7`)

### EKS — Elektronické kontraktačné systém (Electronic Contracting System)

**Purpose:** Integration with the Slovak national electronic contracting platform
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/EksService.java`
- Request/response DTOs: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/helpDto/EksRequest.java`, `EksZipFileResponse.java`
- HTTP client: Unirest

### URSO — Úrad pre reguláciu sieťových odvetví (Regulatory Office for Network Industries)

**Purpose:** Publish/reporting to the Slovak network industries regulator
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UrsoPublishingService.java`

---

## Real-Time / WebSocket

**Protocol:** JSR-356 Java WebSocket
- Endpoint: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/PingEndpoint.java`
- URL path: `wss://<host>/websockets/ping/{groupId}` where `groupId` = procurement ID
- Configurator: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/CustomConfigurator.java`
- Client library: `angular-websocket ~2.0.0` (`publicERANET-client/bower.json`)
- **Use cases:**
  - Live online-presence tracking of companies during procurement opening sessions
  - Real-time chat messages in opening rounds (`ProcurementOpeningChatMessage`)
  - Broadcast signals: `refreshPage`, `closeOpening`, `refreshMessage`, `refreshUsers`

---

## External SOAP Web Service — ProEBiz Auction Engine

**Purpose:** SOAP integration with ProEBiz — a third-party electronic auction platform
- WSDL: `publicERANET-server/src/main/resources/META-INF/proebiz_schema.wsdl`
- Generated JAX-WS client: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/proebiz/WebserviceService.java`
- Type classes: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/proebiz/types/` (ArrayOfAuctionName, ArrayOfRounds, ArrayOfItems, etc.)
- WSDL location in code is commented out (`//file:/C:/Program%20Files/Java/jdk1.8.0_221/bin/proebiz.wsdl`) — integration is partially disabled/stub
- `LoggingHandler.java` present for SOAP message logging

---

## External SOAP Web Service — SPINEX

**Purpose:** SOAP integration with SPINEX, called from procurement, scheduling, agreement, and framework-agreement (harmonogram) flows
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/spinex/SpinexService.java`
- Request/response types: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/spinex/ExecuteRequest.java`, `ExecuteResponse.java`, `ObjectFactory.java`
- Serialization DTOs: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/spinex/serialization/` (Action, Actions, Parameters, Procurement, ProcurementPart, Procurements, Status, WsReturn, plus date/timestamp XML adapters)
- Duplicate generated client package: `publicERANET-server/src/main/java/sk/assecosolutions/spinex/` (`definitions/Spinex.java`, `definitions/SpinexService.java`, `schemas/`)
- Callers: `ProcurementService.java`, `ScheduleService.java`, `AgreementService.java`, `HarmonogramInProcurementService.java`
- WSDL: `publicERANET-server/src/main/resources/META-INF/spinex_schema.wsdl`
- Truststores: `publicERANET-server/src/main/resources/META-INF/spinexrs-truststore-ca-prod.jks`, `spinexrs-truststore-ca-test.jks`
- Test coverage: `publicERANET-server/src/test/java/sk/innovis/eranetpublic/server/spinex/SerializationTest.java`

---

## WOPI — Document Editing (e-Contracts)

**Purpose:** Backs the e-contracts document-editing feature area, allowing in-browser editing of contract documents
- Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/WopiService.java` (~819 lines)
- Config: `publicERANET-server/src/main/resources/META-INF/wopi.xml`
- Registered in: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java`
- Tied into: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/EcontractService.java` (~2,859 lines)

---

## Consul-Backed Configuration

**Purpose:** Application configuration resolved from Consul at runtime, with a filesystem fallback when Consul is unavailable
- Facade layer: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/config/` (`ConfigService.java`, `ConfigurationFacade.java`, `ConsulFacade.java`, `FileSystemConfigFacade.java`)
- REST surface: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/rest/config/` (`InternalConfigREST.java`, `PrivateConfigREST.java`, `PublicConfigREST.java`)
- **Behavior:** `ConfigurationFacade` resolves values via `ConsulFacade` first, falling back to `FileSystemConfigFacade` when Consul is not reachable

---

## CI / Deployment

### CI Pipeline

- Travis CI — `publicERANET-client/.travis.yml`
  - Tests Node.js `0.8` and `0.10`
  - Installs `bower` and `grunt-cli` globally, then runs `bower install`
  - No server-side CI config detected

### Database Migration

- Liquibase CLI (external tool, not Maven-managed)
- Run via `configS.bat` at project root
- Connects to `localhost:3306/psk` with the WildFly-bundled MySQL connector (`mysql-connector-java-8.0.22.jar`)

### Containerisation

- Docker Compose: `publicERANET-server/docker-compose.yml` — MySQL containers only; no application container defined
- Service name pattern: `publiceranet-server${BRANCH}` — supports branch-based parallel environments

---

## Environment Configuration

**Required env vars** (see `publicERANET-server/.env.example`):
- `BRANCH` — branch name suffix for container naming (e.g., `stable`)
- `MYSQL_PORT` — host port for application MySQL container (default `3307`)
- `JACKRABBIT_PORT` — host port for JCR MySQL container (default `3308`)

**Additional config stored in DB (`Setting` entity):**
- SMTP settings (host, port, credentials)
- UVO / EKS API endpoints and credentials

**Secrets location:**
- SMTP passwords stored in the MySQL `Setting` table (runtime)
- SAML keystores: `publicERANET-server/src/main/resources/META-INF/alice2.jks` (test) and `prod.jks` (production) — committed to repo
- Aspose license: `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic` — committed to repo

---

## Google Fonts (CDN)

The client HTML loads a Google Fonts stylesheet at runtime:
- `https://fonts.googleapis.com/css?family=Roboto:400,700`
- Source: `publicERANET-client/app/index.html`

---

*Integration audit: 2026-06-03*
