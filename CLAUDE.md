<!-- GSD:project-start source:PROJECT.md -->
## Project

**SEAS / ERANET — Ticket-Driven Development**

SEAS (ERANET Public) is a production Slovak public-procurement (e-tender) platform: a Java EE 7 REST/WebSocket backend (`publicERANET-server`) and an AngularJS 1.x SPA (`publicERANET-client`), backed by MySQL. This milestone is not a rewrite — it is an **ongoing, Jira-ticket-driven stream of new features and bug fixes** on the existing system, governed by a strict set of engineering conventions so that AI-assisted changes stay consistent, traceable, and faithful to the existing codebase.

**Core Value:** Every change traces to exactly one Jira ticket, follows the existing codebase patterns, and is delivered in clean, disciplined commits — without breaking the live procurement platform. If everything else is negotiable, **this discipline is not**.

### Constraints

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
<!-- GSD:project-end -->

## Engineering Working Agreement (READ FIRST)

These rules are mandatory for **all** code work on SEAS/ERANET. They exist because AI-assisted changes on a prior project caused real problems (bad commit attribution, mixed tickets, Slovak leaking into code, invented UI, ignored patterns).

### 1. Jira-ticket-first
- Before any discussion or planning, **read the relevant `EP-XXXX` Jira ticket** (via the Atlassian integration) so requirements come from the ticket, not from guessing.
- Jira images cannot be read by the agent — **ask the user to paste any image** the ticket depends on before assuming intent.

### 2. Commits
- Format: **`feat|fix(STORY, DEV): description`** — story ticket first, dev ticket second. **Never** put the Epic in the first slot.
- **Look up the correct Story→Dev pair in [`.planning/TICKETS.md`](.planning/TICKETS.md) before every commit.**
- **One ticket per commit** — never mix multiple tickets.
- Simple, human-readable messages and comments — **no phase numbers or internal codes** (GSD `.planning/` docs commits are exempt and use plain `docs:` messages).
- Example: `feat(EP-12688, EP-12689): add contract type enum to procurement form`

### 3. Language — English-only (CRITICAL)
- All code, identifiers, and **translation keys** must be in **English**.
- Slovak appears **only in translation values**, never in code or keys.

### 4. UI
- Reuse the **existing system design** — copy components/styles already present. Do **not** create a new component library or redesign.

### 5. Backend
- Do **not** call DAOs directly — use a **`BaseService` method** when one is available (respects the service-layer pattern and container-managed transactions).

### 6. Database / Liquibase
- Raw SQL scripts **only for INSERTs**; all other schema changes go through **Liquibase changesets**.
- Liquibase changeset **author = `m.bijalko`**.

### 7. Code quality
- Human-readable code; split logic into **well-named methods**.
- **Follow existing codebase patterns** (see `.planning/codebase/`) and modern practices where sensible. Do not introduce new frameworks without a decision.

> Tech stack is fixed (brownfield): Java 8 / Java EE 7 / EclipseLink / RESTEasy / WildFly / MySQL (server); AngularJS 1.5 / Bower / Grunt (client).

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Overview
- `publicERANET-client/` — AngularJS single-page application
- `publicERANET-server/` — Java EE 7 REST + WebSocket backend, packaged as a WAR
## Client — publicERANET-client/
### Language
- JavaScript (ES5) — all application code under `publicERANET-client/app/scripts/`
### Runtime
- Node.js `>=0.10.0` (declared in `publicERANET-client/package.json` `engines` field)
- Travis CI tested against Node.js `0.8` and `0.10` (`publicERANET-client/.travis.yml`)
- npm — `publicERANET-client/package.json` (devDependencies only; no runtime npm packages)
- Bower — `publicERANET-client/bower.json` (runtime JS/CSS dependencies)
- Lockfile: `publicERANET-client/package-lock.json` present for npm; no `bower.lock`
### Framework
- AngularJS `~1.5.5` — SPA framework (`publicERANET-client/bower.json`)
### Key Bower Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `jquery` | `~2.0.0` | DOM utilities |
| `jquery-ui` | `~1.10.0` | UI widgets |
| `bootstrap` | `~3.2.0` | CSS framework |
| `angular-bootstrap` | `~1.3.3` | Bootstrap directives for AngularJS |
| `angular-ui-select` | `~0.17.1` | Select2-style dropdowns |
| `angular-ui-select2` | `~0.0.5` | Legacy Select2 wrapper |
| `ng-table` | `~0.3.3` | Data tables |
| `ng-file-upload` | `~12.0.4` | Multipart file upload |
| `ng-ckeditor` | git `4dee2e10` | Rich-text editor (CKEditor wrapper) |
| `lodash` | `~4.13.1` | Utility functions |
| `angular-websocket` | `~2.0.0` | WebSocket service |
| `angularjs-oauth2` | `~1.2.3` | OAuth2 client flow |
| `cookieconsent2` | `~1.0.10` | GDPR cookie banner |
| `ngdropzone` | `~1.0.5` | Drag-and-drop file upload |
| `iframe-resizer` | `~4.3.11` | Cross-origin iframe sizing |
### Build Tooling
| Plugin | Purpose |
|--------|---------|
| `grunt-contrib-concat` | Bundle JS files |
| `grunt-contrib-uglify` | Minify JS |
| `grunt-contrib-cssmin` | Minify CSS |
| `grunt-contrib-connect` | Dev server on port 9000 |
| `grunt-contrib-watch` | File watching + live-reload |
| `grunt-bower-install` | Auto-inject Bower components into `index.html` |
| `grunt-ngmin` | AngularJS DI-safe pre-minification |
| `grunt-ng-constant` | Inject build-time constants (`config.js` in `dist/scripts/`) |
| `grunt-rev` | Cache-busting asset fingerprinting |
| `grunt-usemin` | Replaces `build:*` blocks in HTML |
| `grunt-svgmin` | Minify SVG assets |
| `grunt-autoprefixer` | CSS vendor prefixes |
| `grunt-contrib-jshint` | JS linting |
### Testing
- Test framework: Jasmine
- E2E config: `publicERANET-client/karma-e2e.conf.js`
- Preprocessors: `karma-ng-html2js-preprocessor`, `karma-ng-scenario`
- Browser: Chrome (configured in `karma.conf.js`)
### Code Quality
### Project Generator
## Server — publicERANET-server/
### Language
- Java 8 (`source`/`target` = `1.8`) — `publicERANET-server/pom.xml` `<java.version>1.8</java.version>`
### Build Tool
- Group: `sk.innovis`, Artifact: `eranet-server-seastest`, Version: `1.0-SNAPSHOT`
- Packaging: **WAR**
- In-project local repo: `publicERANET-server/lib/` (hosts Aspose commercial JARs)
- Central repo: `https://repo1.maven.org/maven2`
| Plugin | Version | Purpose |
|--------|---------|---------|
| `maven-compiler-plugin` | 3.1 | Compile Java 8, run Lombok annotation processing |
| `maven-war-plugin` | 2.3 | Package WAR, bundle SQL into `WEB-INF/sql/`, set logging profile `seas_profile` |
| `maven-dependency-plugin` | 2.6 | Copy endorsed JARs |
| `eclipselink-staticweave-maven-plugin` | 1.0.3 | EclipseLink static weaving for JPA entities |
### Application Server
- Originally also configured for GlassFish (legacy `publicERANET-server/src/main/setup/glassfish-resources.xml`)
- Application context path: `/webresources` (`@ApplicationPath("webresources")` in `ApplicationConfig.java`)
### API Framework
- All resources registered manually in `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java`
- REST base path: `webresources/`
- Multipart provider: `resteasy-multipart-provider 2.2.0.GA`
- Server endpoint: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/PingEndpoint.java`
- Path: `/websockets/ping/{groupId}`
- Used for real-time procurement opening room chat and online-presence tracking
### Persistence
- Persistence unit: `PublicTestPU` (JTA)
- JTA data source JNDI: `PublicSeasDS`
- Static weaving enabled (`eclipselink.weaving=static`, `eclipselink.target-server=JBoss`)
- Persistence descriptor: `publicERANET-server/src/main/resources/META-INF/persistence.xml`
- 130+ entity classes under package `sk.innovis.eranetpublic.server.dto`
- Master changelog: `publicERANET-server/src/main/sql/db.changelog-master.xml`
- Versioned changelogs from `1.0` through `2.11.0` under `publicERANET-server/src/main/sql/`
- Run via `configS.bat` using WildFly-bundled MySQL connector
### Component Model
- Services are `@Stateless` EJBs
- Dependency injection via `@EJB` and `@Inject`
- Scheduling via `@Schedule` (e.g., WebSocket keepalive)
### Key Server Dependencies (pom.xml)
| Library | Version | Purpose |
|---------|---------|---------|
| `nimbus-jose-jwt` | 9.37.3 | JWT parsing/validation |
| `java-jwt` (auth0) | 3.3.0 | JWT creation |
| `java-saml` (onelogin) | 2.2.0 | SAML 2.0 SP support |
| `opensaml` | 2.6.4 | SAML low-level library |
| `eclipselink` | 2.6.4 | JPA ORM |
| `resteasy-jaxrs` | 2.2.1.GA | JAX-RS implementation |
| `jackson-jaxrs-json-provider` | 2.3.2 | JSON serialisation |
| `jackson-databind` | 2.4.0 | Object mapping |
| `gson` | 2.6.1 | JSON (Gson) used alongside Jackson |
| `gson-javatime-serialisers` | 1.1.1 | Java 8 time type support for Gson |
| `commons-email` | 1.3.3 | SMTP email sending |
| `commons-io` | 2.4 | File I/O utilities |
| `commons-beanutils` | 1.9.2 | Bean property utilities |
| `commons-lang` | 2.6 | String/object utilities |
| `commons-codec` | 1.8 | Hashing (SHA, Base64) |
| `poi` + `poi-ooxml` | 3.11 | Excel file generation |
| `aspose-words` | 16.3.0 | Word document generation (commercial) |
| `aspose-pdf` | 10.6.2 | PDF generation (commercial) |
| `aspose-email` | 5.9.0 | Email processing (commercial) |
| `aspose-cells` | 8.5.2 | Excel processing (commercial) |
| `httpclient` | 4.3.1 | Outbound HTTP calls |
| `unirest-java` | 1.4.7 | HTTP client (Unirest) |
| `jcabi-http` | 1.10.3 | Fluent HTTP client |
| `guava` | 18.0 | Google utilities (collections, net) |
| `spring-beans` | 2.5.6.SEC03 | Spring Bean IoC (minimal use) |
| `jcr` | 2.0 | JCR (Java Content Repository) API — provided scope |
| `lombok` | 1.18.20 | Boilerplate reduction (`@Data`, etc.) |
| `slf4j-jdk14` | 1.7.7 | SLF4J logging bridge |
## Configuration
- Docker Compose: `publicERANET-server/docker-compose.yml` — two MySQL 5.7 containers
- Overridden via `.env` file; example: `publicERANET-server/.env.example`
- JNDI pool configured in `publicERANET-server/src/main/setup/glassfish-resources.xml` (legacy) and WildFly server config
- Run manually via `configS.bat` at project root using Liquibase CLI
- Build-time config injected into `dist/scripts/config.js` via `grunt-ng-constant` (`publicERANET-client/Gruntfile.js` `ngconstant` task)
- Server: WildFly logging profile `seas_profile` set via `MANIFEST.MF` (`maven-war-plugin` configuration)
## Platform Requirements
- JDK 8
- Maven 3.x
- Node.js 0.10+ (client build only)
- npm + Bower + Grunt CLI
- Docker (for MySQL containers via docker-compose)
- WildFly 26.1.3 (application server)
- Liquibase CLI (database migrations via `configS.bat`)
- WildFly application server (WAR deployment)
- MySQL 5.7 (two instances: application DB + JCR DB)
- JCR content repository (Apache Jackrabbit, backed by `jackrabbit_mysql`)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Overview
- `publicERANET-client/` — AngularJS (1.x) frontend, JavaScript ES5
- `publicERANET-server/` — Java 8 / JAX-RS backend
## JavaScript (Client) Conventions
### Code Style Enforcement
- `"camelcase": true` — all identifiers must use camelCase
- `"curly": true` — all control blocks require braces
- `"eqeqeq": true` — use `===` not `==`
- `"quotmark": "single"` — use single quotes
- `"strict": true` — `'use strict';` required in every file
- `"undef": true` — no undeclared variables
- `"unused": true` — no unused variables
- `"latedef": true` — variables must be declared before use
- `"newcap": true` — constructors must start with uppercase
- `"trailing": true` — no trailing whitespace
- Globals permitted without declaration: `angular`, `_`, `$`
- Same base rules, but adds Jasmine globals (`describe`, `it`, `expect`, `beforeEach`, `afterEach`, `inject`, `spyOn`, `jasmine`, `browser`) as allowed undeclared globals
- Indent style: **tab** (not spaces)
- Indent size: 4
- End of line: LF
- Charset: UTF-8
- `*.js` files: single quotes
### Naming Patterns (JS)
- Controllers: `camelCase.js` in `app/scripts/controllers/` subdirectory matching feature area (e.g., `companyProfileBasicInformation.js`, `buyers.js`)
- Services (business): `camelCase.js` in `app/scripts/service/` (e.g., `mainInterceptor.js`, `dialogConfirmer.js`)
- Resources (REST wrappers): `camelCase.js` in `app/scripts/service/resources/` — name matches the entity (e.g., `procurements.js`, `companies.js`)
- Directives: `camelCase.js` in `app/scripts/directives/` — name matches the HTML element name in camelCase
- Controller functions: `PascalCase` with `Controller` suffix (e.g., `CompanyProfileController`, `DatetimeCellController`)
- Factory/service functions: `PascalCase` without suffix for resources (e.g., `ProcurementsResource`), PascalCase for business services (e.g., `Procurements`, `Alerts`, `Utils`)
- Directive names: camelCase matching their HTML attribute/element name (e.g., `datetimeCell`, `decimalInput`, `attachmentsCell`)
- Filter functions: `camelCase` with `Filter` suffix (e.g., `harmonogramTaskStatusFilter`, `undefinedNumberFilter`)
- Constants: `SCREAMING_SNAKE_CASE` for values inside `.constant()` objects (e.g., `FILTER_NAME_CODEBOOK`, `COMPANY_TYPE_SUPPLIER`)
- Module-level variables: camelCase (e.g., `serviceResult`, `procurementsResult`)
- camelCase throughout
- Service object pattern: internal state in `var`-declared variables, public API on a `var serviceResult = {}` object returned at end of factory
### AngularJS Module Structure
### Controller Pattern
- First argument to `.controller()` is the `PascalCase` + `Controller` name
- DI array lists dependencies as strings, matching parameters in the function
- The constructor function parameter name is typically `define` (not the controller name)
- `$rootScope` is used frequently for cross-controller shared state (`currentProcurement`, `procurementId`, `currentUser`, etc.)
- Tab-based views share state via `$controller('TabController', {$scope: $scope})`
### Service/Factory Pattern
- Private state declared with `var` at the top of the factory function
- Private helpers as `var fn = function() {}` (not function declarations)
- Public API exposed as properties on `var serviceResult = {}`
- Callbacks (not Promises) used throughout: `function afterLoad(data) {}` naming convention for async callbacks
### Resource (REST client) Pattern
### Directive Pattern
- Directives use `restrict: 'E'` (elements) predominantly
- Isolated scope with `=` for two-way bindings, `@` for attribute strings, `&` for callbacks
- Template URLs reference `views/directives/` folder
### Filter Pattern
### Error Handling (Client)
- HTTP errors are handled centrally in `publicERANET-client/app/scripts/service/mainInterceptor.js` via an Angular HTTP interceptor factory registered on `$httpProvider.interceptors`
- The interceptor handles 400, 401, 403, 404, 405, 500 status codes with translated error messages via `$translate`
- Business errors are shown using `Alerts.error()` and `Alerts.longError()` from `publicERANET-client/app/scripts/service/alerts.js`
- `Alerts` wraps `$.smallBox()` from the SmartAdmin theme
### Logging (Client)
### Comments (Client)
- Block comments for function descriptions (not JSDoc format)
- Inline comments in Slovak language (`// Načíta aktuálne vybrané obstarávanie...`)
- English comments also present (no strict language convention enforced)
- Commented-out code blocks are common (large sections in `app.js`, `app.config.js`, services)
### Import Organization (Client)
## Java (Server) Conventions
### Project Layout
- `dto` — JPA entity classes (annotated with `@Entity`, `@Table`, `@XmlRootElement`)
- `dto/face` — interfaces implemented by DTOs (e.g., `HasId`, `HasAttachment`, `HasFiles`, `IsProcurement`)
- `dao` — Data Access Objects (extend `BaseDao<T>`)
- `dao/helpDto` — helper/wrapper POJOs for queries and results
- `service` — JAX-RS endpoint + EJB service classes (extend `BaseService<T>`)
- `service/comparator` — `Comparator` implementations
- `service/enums` — enum types used in services
- `service/excel` — Excel export helpers
- `service/pdf` — PDF generation services
- `service/logic` — standalone logic helpers
- `service/supplier` — supplier-specific service logic
- `interceptor` — JAX-RS reader interceptors
- `exception` — JAX-RS `ExceptionMapper` providers
- `annotation` — custom annotations (e.g., `@PATCH`)
- `configuration` — CDI/EJB configuration beans
- `saml` / `sso` — SAML/SSO authentication code
- `serialization` — serialization DTOs for external integrations
- `ws` — WebSocket endpoints
### Naming Patterns (Java)
- Entities (DTOs): `PascalCase` matching the domain concept, no suffix (e.g., `Procurement`, `Addendum`, `Agreement`)
- DAOs: entity name + `Dao` suffix (e.g., `ProcurementDao`, `AgreementDao`)
- Services (which are also JAX-RS endpoints): entity name + `Service` suffix (e.g., `ProcurementService`, `AgreementService`)
- Interfaces used by DTOs: `Has` prefix + capability (e.g., `HasId`, `HasAttachment`, `HasFiles`, `HasCopy`)
- Exception mappers: what-maps + `Handler` suffix (e.g., `AccessLocalExceptionHandler`)
- Comparators: `EntityName` + `By` + `PropertyName` + `Comparator` (e.g., `FileDescriptionDatetimeComparator`)
- camelCase throughout
- Service endpoint methods named by HTTP action + resource (e.g., `getProcurement`, `saveProcurement`, `deleteProcurement`)
- Post-construct callbacks follow no strict convention but often named for what they do
- `SCREAMING_SNAKE_CASE` as `static final` fields (e.g., `FULL_DATETIME_FORMAT_TO_STRING`, `PROPERTY_NAME_PROCUREMENT_ID`)
### Service/DAO Pattern
- Abstract generic class `BaseService<T>` extended by all concrete services
- Injects `Logger` via CDI `@Inject`
- Injects EJB collaborators via `@EJB`
- Provides shared date format constants (`STANDARD_DATE_FORMAT`, `FULL_DATETIME_FORMAT`, etc.)
- Abstract generic class `BaseDao<T>` extended by all concrete DAOs
- Injects `EntityManager` via `@PersistenceContext(name = "PublicPU")`
- Provides `create`, `find`, `update`, `delete` operations using JPA Criteria API
### Entity (DTO) Pattern
- All entities annotated with `@Entity`, `@Table`, `@XmlRootElement`
- Implement `Serializable`
- `@Transient` fields used for computed or helper data sent to client
- Public constant strings for property names (e.g., `AGREEMENT_ID_PROPERTY_NAME`, `FILE_REFERENCED_TYPE_NAME`)
- Lombok `@Data`/`@Getter`/`@Setter` used in newer or helper classes (Lombok is on the classpath as v1.18.20)
### Annotations
- `@Stateless` — all service EJBs are stateless session beans
- `@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)` — default role for service classes
- `@PermitAll` — overrides class-level security for public endpoints
- `@Path`, `@GET`, `@POST`, `@PUT`, `@DELETE`, `@PATCH` (custom annotation) — JAX-RS HTTP methods
- `@Produces(MediaType.APPLICATION_JSON)` / `@Consumes(MediaType.APPLICATION_JSON)` — JSON in/out
- `@Provider` — JAX-RS providers (exception mappers, interceptors)
- Custom `@PATCH` annotation in `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/annotation/PATCH.java` since JAX-RS 2.0 did not include PATCH
### Error Handling (Server)
- `AccessLocalException` (EJB security) → mapped to HTTP 403 by `AccessLocalExceptionHandler`
- Business rule violations → `WebApplicationException` with appropriate `Response.Status`
- Input sanitization via `FindParametersSanitizer` interceptor (`publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/interceptor/FindParametersSanitizer.java`) which strips forbidden filter fields from `FindParameters` objects
- `logger.warn()` used when forbidden operations are attempted
### Logging (Server)
- SLF4J via `slf4j-jdk14` binding
- Logger injected via CDI: `@Inject protected Logger logger;`
- Pattern: `logger.debug("Vkladam novy objekt {}", entity.toString())` (Slovak-language log messages throughout)
- No structured logging framework (Logback, Log4j2)
### Comments (Java)
- In-line comments and block comments in Slovak (matches the application domain language)
- No Javadoc in service/DAO layer
- `// TODO:` comments reference Jira tickets (e.g., `//TODO bude sa riesit neskor EP-3908`)
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## System Overview
```text
```
## Component Responsibilities
| Component | Responsibility | File / Path |
|-----------|----------------|-------------|
| AngularJS SPA bootstrap | Module declaration, `$routeProvider` config, global `$rootScope` run block | `publicERANET-client/app/scripts/ng.app.js` |
| SmartAdmin shell | jQuery-based layout, sidebar, widgets, date pickers | `publicERANET-client/app/scripts/app.js`, `app.config.js` |
| Angular controllers | Screen-level logic, UI state, calling services | `publicERANET-client/app/scripts/controllers/**/*.js` (~34 top-level files + subdirs) |
| Angular resource services | `$resource` wrappers mapping to server REST URLs | `publicERANET-client/app/scripts/service/resources/*.js` (129 files) |
| Angular business services | Client-side business logic, caching, result manipulation | `publicERANET-client/app/scripts/service/business/*.js` |
| Angular directives | Reusable table widgets, file upload tables, form helpers | `publicERANET-client/app/scripts/directives/*.js` |
| Angular filters | Display formatting (status icons, numeric, date) | `publicERANET-client/app/scripts/filters.js` |
| `ApplicationConfig.java` | JAX-RS `Application` subclass — registers all REST resource classes | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` |
| `BaseService<T>` | Abstract ancestor for all REST services: date formats, EJB injection, find/copy helpers | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java` |
| Concrete `*Service.java` | `@Stateless` EJBs annotated with `@Path`: expose CRUD + query endpoints for each domain object | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/*.java` (166 files) |
| `BaseDao<T>` | Generic JPA CRUD, criteria-builder queries, pagination | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java` |
| Concrete `*Dao.java` | Entity-specific queries extending BaseDao | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/*.java` (128 files) |
| JPA entities / DTOs | `@Entity` classes mapped to MySQL tables; also serialized directly as JSON responses | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/*.java` (208 classes) |
| `AuthenticationService` | Form-login, SAML/OIDC SSO, password reset, registration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java` |
| `OIDCService` | OpenID Connect / JWT token handling using Nimbus JOSE | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/OIDCService.java` |
| SAML/SSO | Slovak government UPVS SSO integration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/` |
| WebSocket endpoint | Real-time push notifications over WebSocket at `/websockets/realtime` | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/RealTimeEndpoint.java` |
| PDF generation services | Aspose-Word/PDF document generation | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/pdf/` |
| Excel services | Apache POI + Aspose Cells export | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/excel/` |
| `FindParametersSanitizer` | JAX-RS request interceptor for input sanitization | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/interceptor/FindParametersSanitizer.java` |
## Pattern Overview
- Client and server are separate Git repositories under a parent workspace root
- The AngularJS SPA is served as static files; the server WAR uses GlassFish `alternatedocroot` to serve the client from an external path (configured in `glassfish-web.xml`, line 35)
- REST base path is `webresources/` — all client `$resource` URLs are relative, e.g. `webresources/sc/company/:companyId`
- JPA entities are used directly as REST response bodies (Jackson serialization) — there is no separate DTO/mapper layer between entity and HTTP
- EJB `@Stateless` beans are simultaneously JAX-RS resources (dual role: container-managed transactions + HTTP endpoints)
## Layers
- Purpose: Hash-based `ngRoute` routing; maps URL fragments to controller + template pairs
- Location: `publicERANET-client/app/scripts/ng.app.js` (lines 28–656)
- Contains: ~100 `$routeProvider.when(...)` declarations
- Depends on: Angular `ngRoute`, `ui.bootstrap`
- Used by: Browser address bar; `$location.url()` calls in controllers
- Purpose: Screen-specific logic, user interaction, calls services, sets `$scope` for view binding
- Location: `publicERANET-client/app/scripts/controllers/`
- Contains: ~34 top-level controller files plus deeply nested subdirectories for procurement, qualification, planning, evaluation, communication
- Depends on: Angular services from `service/resources/` and `service/business/`
- Used by: View templates via `ng-controller` or route config
- Purpose: `$resource` factory wrappers (`*Resource` factories) + business-logic service objects that cache results and expose named methods
- Location: `publicERANET-client/app/scripts/service/resources/` (129 files), `publicERANET-client/app/scripts/service/business/` (3 files)
- Pattern: Each resource file exports two factories — `XyzResource` (raw `$resource`) and `Xyz` (higher-level service wrapping it)
- Depends on: `$resource`, `$http`, `$rootScope`, `ResultManipulator`, `Utils`, `FilterHelper`
- Used by: Controllers
- Purpose: Reusable UI widgets (data tables, file attachment grids, approval tables)
- Location: `publicERANET-client/app/scripts/directives/` (35 files + `tableFilters/` subdir)
- Depends on: Angular services, `ngTable`
- Used by: View templates
- Purpose: HTML templates with Angular bindings; mirrors controller directory structure
- Location: `publicERANET-client/app/views/` (mirrors `scripts/controllers/` hierarchy)
- Contains: `.html` partial templates loaded by `$routeProvider` or `ng-include`
- Purpose: HTTP endpoints + business logic in a single `@Stateless @Path` class; handles authorization, calls DAOs, sends emails
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/`
- Contains: 166 service files; all extend `BaseService<T>`
- Depends on: DAO layer via `@EJB` injection; `EntityManager` indirectly via DAOs
- Used by: JAX-RS container via `ApplicationConfig.java`
- Purpose: JPA/EclipseLink data access; `BaseDao<T>` provides generic CRUD, pagination, criteria-builder queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/`
- Contains: 128 DAO files; all extend `BaseDao<T>`
- Depends on: `EntityManager` (`@PersistenceContext(name="PublicPU")`)
- Used by: Service layer via `@EJB`
- Purpose: `@Entity` JPA classes mapped to MySQL; also serialized as JSON responses via Jackson
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/`
- Contains: 208 entity classes; registered explicitly in `persistence.xml`
- Depends on: EclipseLink, Jackson, Apache Commons BeanUtils (for copy/clone helpers)
## Data Flow
### Authenticated REST CRUD request
### WebSocket real-time notification
### Authentication (form-login / SSO)
- `$rootScope` holds global session state: `logged`, `currentUser`, `procurementId`, `currentProcurement`, `globalTabId`, `showProcurementMenu`, `showQualificationMenu`, etc.
- `WebStorage` service (localStorage wrapper) persists UI preferences such as current tab, language, return path
- No client-side store (NgRx/Redux) — all domain data is fetched on demand from REST endpoints
## Key Abstractions
- Purpose: Each domain object has two factories — `XyzResource` (raw REST binding) and `Xyz` (caching/business-logic wrapper)
- Examples: `publicERANET-client/app/scripts/service/resources/companies.js`, `agreements.js`
- Pattern:
- Purpose: Unifies REST endpoint + EJB into one class; BaseService injects shared helpers
- Examples: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/CompanyService.java`, `ProcurementService.java`
- Purpose: Generic JPA CRUD; subclasses add entity-specific named queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`
- Purpose: Many routes share `views/general/tabs.html` with a named controller — the same generic tab shell hosts different feature areas
- Examples: `$routeProvider.when('/home/:tabId', { templateUrl: 'views/general/tabs.html', controller: 'HomeController' })`
## Entry Points
- Location: `publicERANET-client/app/index.html`
- Bootstrap: `data-ng-app='eranetPublic'` on `<html>` tag; Angular bootstraps `eranetPublic` module from `ng.app.js`
- Main controller: `MainController` on `<body>` (`scripts/controllers/main.js`)
- SmartAdmin shell init: `app.config.js` (global jQuery config) + `app.js` (SmartAdmin jQuery plugin init)
- Deployment descriptor: `publicERANET-server/src/main/webapp/WEB-INF/web.xml` (servlet 3.0, FORM auth, session timeout 30 min)
- GlassFish deployment: `publicERANET-server/src/main/webapp/WEB-INF/glassfish-web.xml` (context root `/public`, alternatedocroot for client files)
- WildFly/JBoss deployment: `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml` (context root `/public_seas`, security domain `PublicSeasRM`)
- JAX-RS app class: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` (`@ApplicationPath("webresources")`)
- JPA config: `publicERANET-server/src/main/resources/META-INF/persistence.xml` (persistence unit `PublicTestPU`, JTA data source `PublicSeasDS`, EclipseLink, 230+ entity registrations)
- JDBC pool setup: `publicERANET-server/src/main/setup/glassfish-resources.xml` (MySQL, database `public`, JNDI `PublicDS`)
- CDI beans: `publicERANET-server/src/main/webapp/WEB-INF/beans.xml`
## Multi-Module Server Structure
| Directory | Maven role | Content |
|-----------|-----------|---------|
| `src/` | Active WAR source | All Java server code (service, dao, dto, ws, sso, interceptor, serialization, configuration) |
| `eranet-domain/` | Git submodule (external domain library) | `src/main/resources/META-INF/` only — no Java sources present |
| `public-eranet/` | Git submodule (shared service base) | `src/main/java/sk/innovis/eranetpublic/server/service/` — empty at present |
| `lib/` | Local Maven repository | Aspose JARs (Words 16.3, PDF 10.6.2, Email 5.9, Cells 8.5.2) not in Maven Central |
## Architectural Constraints
- **Threading:** Java EE container manages threads; EJBs are `@Stateless` (pool-managed). WebSocket endpoint is `@Singleton`. No manual threading.
- **Global state (client):** `$rootScope` holds all session state. Access it through the `MainController` which is bound to `<body>`.
- **Global state (server):** `WebStorage` (client localStorage) persists UI prefs across reloads. Server is stateless per request except for the container-managed HTTP session (30-min timeout, cookie name `SESSIONID`).
- **Entity = JSON DTO:** JPA entities are serialized directly as REST responses. Changing entity field names or Jackson annotations affects both persistence and API simultaneously.
- **No Spring:** The pom.xml includes `spring-beans 2.5.6` but Spring is not used for dependency injection — CDI (`@Inject`) and EJB (`@EJB`) are used throughout.
- **REST URL convention:** All secured endpoints are under `/webresources/sc/` — the `web.xml` security constraint covers this prefix.
- **HTTP method coverage:** `@PATCH` is a custom annotation (`annotation/PATCH.java`) because JAX-RS 2.0 does not include it.
## Anti-Patterns
### Dual-purpose EJB/JAX-RS classes
### Entities as REST DTOs
## Error Handling
- Services throw `WebApplicationException` with appropriate HTTP status for auth/validation failures
- `BaseDao` logs and rethrows on `ConstraintViolationException`
- Client-side: Angular `$http` interceptors (`mainInterceptor`, `htmlCacheInterceptor`) registered in `ng.app.js`
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
