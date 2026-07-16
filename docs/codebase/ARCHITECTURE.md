<!-- refreshed: 2026-06-03 -->
# Architecture

**Analysis Date:** 2026-06-03

## System Overview

```text
┌──────────────────────────────────────────────────────────────────────┐
│              Browser — AngularJS 1.x SPA                             │
│  publicERANET-client/app/index.html                                  │
│  ng-app="eranetPublic"  (bootstrap: ng.app.js)                       │
│                                                                      │
│   Controllers          Services (Resource)        Views              │
│  `scripts/controllers/`  `scripts/service/`     `views/**/*.html`   │
│                                                                      │
│  $http / $resource ──── JSON over HTTP/REST ──► webresources/**     │
│  ngWebSocket ─────────── WebSocket ───────────► websockets/realtime │
└──────────────────────────────────────────────────────────────────────┘
                              │  HTTP (same host, context-root /public)
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│          Java EE 7 WAR — publicERANET-server                         │
│          Deployed on GlassFish 4 (or WildFly/JBoss)                 │
│                                                                      │
│  JAX-RS (RESTEasy) REST layer                                        │
│  `src/main/java/sk/innovis/eranetpublic/server/service/*Service.java`│
│           @Path("webresources")  @ApplicationPath("webresources")    │
│                                                                      │
│  EJB Business/Service layer                                          │
│  `src/main/java/sk/innovis/eranetpublic/server/service/BaseService` │
│                                                                      │
│  JPA (EclipseLink) DAO layer                                         │
│  `src/main/java/sk/innovis/eranetpublic/server/dao/*Dao.java`        │
│                                                                      │
│  JPA Entities / DTOs                                                 │
│  `src/main/java/sk/innovis/eranetpublic/server/dto/*.java` (268 cls)│
└──────────────────────────────────────────────────────────────────────┘
                              │  JTA / JDBC
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│   MySQL database  (JNDI: EranetDS / PublicDS)                    │
│   Persistence unit: EranetPU                                     │
│   `src/main/resources/META-INF/persistence.xml`                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File / Path |
|-----------|----------------|-------------|
| AngularJS SPA bootstrap | Module declaration, `$routeProvider` config, global `$rootScope` run block | `publicERANET-client/app/scripts/ng.app.js` |
| SmartAdmin shell | jQuery-based layout, sidebar, widgets, date pickers | `publicERANET-client/app/scripts/app.js`, `app.config.js` |
| Angular controllers | Screen-level logic, UI state, calling services | `publicERANET-client/app/scripts/controllers/**/*.js` (15 top-level files; 435 total including subdirectories) |
| Angular resource services | `$resource` wrappers mapping to server REST URLs | `publicERANET-client/app/scripts/service/resources/*.js` (162 files) |
| Angular business services | Client-side business logic, caching, result manipulation | `publicERANET-client/app/scripts/service/business/*.js` |
| Angular directives | Reusable table widgets, file upload tables, form helpers | `publicERANET-client/app/scripts/directives/*.js` (45 top-level files + `tableFilters/` subdir; 56 total) |
| Angular filters | Display formatting (status icons, numeric, date) | `publicERANET-client/app/scripts/filters.js` |
| `ApplicationConfig.java` | JAX-RS `Application` subclass — registers all REST resource classes | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` |
| `BaseService<T>` | Abstract ancestor for all REST services: date formats, EJB injection, find/copy helpers | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java` |
| Concrete `*Service.java` | `@Stateless` EJBs annotated with `@Path`: expose CRUD + query endpoints for each domain object | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/*.java` (195 files directly under `service/`; 254 including subpackages `comparator/config/enums/excel/help/logic/pdf/supplier`) |
| `BaseDao<T>` | Generic JPA CRUD, criteria-builder queries, pagination | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java` |
| Concrete `*Dao.java` | Entity-specific queries extending BaseDao | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/*.java` (183 files directly under `dao/`; 276 including `helpDto/`) |
| JPA entities / DTOs | `@Entity` classes mapped to MySQL tables; also serialized directly as JSON responses | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/*.java` (268 classes directly under `dto/`; 302 including subpackages `face/`, `externalprocurement/`, `procurementManagement/`) |
| `AuthenticationService` | Form-login, SAML SSO, password reset, registration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java` |
| SAML/SSO | Slovak government UPVS SSO integration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/` |
| WebSocket endpoint | Real-time push notifications over WebSocket at `/websockets/realtime` | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/RealTimeEndpoint.java` |
| PDF generation services | Aspose-Word/PDF document generation | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/pdf/` |
| Excel services | Apache POI + Aspose Cells export | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/excel/` |
| SPINEX integration | External SPINEX service calls (execute request/response), used from `ProcurementService`, `ScheduleService`, `AgreementService`, `HarmonogramInProcurementService` | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/spinex/SpinexService.java` (plus a duplicate `sk/assecosolutions/spinex/` package) |
| WOPI integration | Office Web Apps viewing/editing protocol backing the e-contracts feature area | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/WopiService.java` (~819 lines), `META-INF/wopi.xml`, `EcontractService.java` (~2,859 lines) |
| Consul-backed config layer | Externalized runtime configuration with filesystem fallback | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/config/` (`ConfigService`, `ConfigurationFacade`, `ConsulFacade`, `FileSystemConfigFacade`), `rest/config/` (`InternalConfigREST`, `PrivateConfigREST`, `PublicConfigREST`) |

## Pattern Overview

**Overall:** Three-tier SPA + REST backend with direct entity serialization

**Key Characteristics:**
- Client and server are separate Git repositories under a parent workspace root
- The AngularJS SPA is served as static files; the server WAR uses GlassFish `alternatedocroot` to serve the client from an external path (configured in `glassfish-web.xml`, line 35)
- REST base path is `webresources/` — all client `$resource` URLs are relative, e.g. `webresources/sc/company/:companyId`
- JPA entities are used directly as REST response bodies (Jackson serialization) — there is no separate DTO/mapper layer between entity and HTTP
- EJB `@Stateless` beans are simultaneously JAX-RS resources (dual role: container-managed transactions + HTTP endpoints)

## Layers

**Client — Routing Layer:**
- Purpose: Hash-based `ngRoute` routing; maps URL fragments to controller + template pairs
- Location: `publicERANET-client/app/scripts/ng.app.js` (194 `.when(` calls spanning lines 39–743 in a 1060-line file)
- Contains: 194 `$routeProvider.when(...)` declarations
- Depends on: Angular `ngRoute`, `ui.bootstrap`
- Used by: Browser address bar; `$location.url()` calls in controllers

**Client — Controller Layer:**
- Purpose: Screen-specific logic, user interaction, calls services, sets `$scope` for view binding
- Location: `publicERANET-client/app/scripts/controllers/`
- Contains: 15 top-level controller files plus deeply nested subdirectories for procurement, qualification, planning, evaluation, communication (435 files total including subdirectories)
- Depends on: Angular services from `service/resources/` and `service/business/`
- Used by: View templates via `ng-controller` or route config

**Client — Service / Resource Layer:**
- Purpose: `$resource` factory wrappers (`*Resource` factories) + business-logic service objects that cache results and expose named methods
- Location: `publicERANET-client/app/scripts/service/resources/` (162 files), `publicERANET-client/app/scripts/service/business/` (3 files)
- Pattern: Each resource file exports two factories — `XyzResource` (raw `$resource`) and `Xyz` (higher-level service wrapping it)
- Depends on: `$resource`, `$http`, `$rootScope`, `ResultManipulator`, `Utils`, `FilterHelper`
- Used by: Controllers

**Client — Directive Layer:**
- Purpose: Reusable UI widgets (data tables, file attachment grids, approval tables)
- Location: `publicERANET-client/app/scripts/directives/` (45 top-level files + `tableFilters/` subdir; 56 total)
- Depends on: Angular services, `ngTable`
- Used by: View templates

**Client — View Layer:**
- Purpose: HTML templates with Angular bindings; mirrors controller directory structure
- Location: `publicERANET-client/app/views/` (mirrors `scripts/controllers/` hierarchy)
- Contains: `.html` partial templates loaded by `$routeProvider` or `ng-include`

**Server — REST/EJB Service Layer:**
- Purpose: HTTP endpoints + business logic in a single `@Stateless @Path` class; handles authorization, calls DAOs, sends emails
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/`
- Contains: 195 service files directly under `service/` (254 including subpackages `comparator/config/enums/excel/help/logic/pdf/supplier`); all extend `BaseService<T>`
- Depends on: DAO layer via `@EJB` injection; `EntityManager` indirectly via DAOs
- Used by: JAX-RS container via `ApplicationConfig.java`

**Server — DAO Layer:**
- Purpose: JPA/EclipseLink data access; `BaseDao<T>` provides generic CRUD, pagination, criteria-builder queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/`
- Contains: 183 DAO files directly under `dao/` (276 including `helpDto/`); all extend `BaseDao<T>`
- Depends on: `EntityManager` (`@PersistenceContext(name="EranetPU")`)
- Used by: Service layer via `@EJB`

**Server — Entity (DTO) Layer:**
- Purpose: `@Entity` JPA classes mapped to MySQL; also serialized as JSON responses via Jackson
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/`
- Contains: 268 entity classes directly under `dto/` (302 including subpackages `face/`, `externalprocurement/`, `procurementManagement/`); registered explicitly in `persistence.xml`
- Depends on: EclipseLink, Jackson, Apache Commons BeanUtils (for copy/clone helpers)

## Data Flow

### Authenticated REST CRUD request

1. Browser calls `ng-app` bootstrap → `eranetPublic` module loaded from `publicERANET-client/app/scripts/ng.app.js`
2. Route change → controller instantiated, calls `XyzResource.query(postData)` in `scripts/service/resources/xyz.js`
3. Angular `$resource` issues `POST webresources/sc/xyz/query` (or `GET/PUT/DELETE` for others)
4. HTTP request crosses to GlassFish WAR context `/public`
5. `ApplicationConfig.addRestResources()` routes request to correct `XyzService.java` method
6. `XyzService` (EJB `@Stateless`) validates auth via Java EE `@RolesAllowed`, delegates to `XyzDao.java`
7. `XyzDao` uses `EntityManager` (EclipseLink, JTA data source `EranetDS`) to query MySQL
8. Entity returned → Jackson serializes to JSON → response sent to client
9. Angular `$resource` resolves promise → controller updates `$scope` → Angular digest cycle re-renders view

### WebSocket real-time notification

1. Client connects to `wswebresources/websockets/realtime` via `ngWebSocket`
2. Server `RealTimeEndpoint.java` (`@ServerEndpoint("/websockets/realtime")`) stores session
3. Server-side event (e.g. message sent) pushes JSON to all open sessions
4. Client receives message, Angular updates notification badge/dropdown

### Authentication (form-login / SSO)

1. Unauthenticated user sees `views/login.html` (controlled by `$root.logged` flag in `ng.app.js`)
2. Credentials posted to `webresources/auth/login` (`AuthenticationService.java`)
3. Server validates via Java EE FORM login realm `EranetRM`; SAML SSO via `SAMLClient` (`saml/`)
4. On success, `$root.logged = true`; `$rootScope.currentUser` populated
5. Logout: `webresources/auth/logout` → `window.location.href = result.content` redirect

**State Management:**
- `$rootScope` holds global session state: `logged`, `currentUser`, `procurementId`, `currentProcurement`, `globalTabId`, `showProcurementMenu`, `showQualificationMenu`, etc.
- `WebStorage` service (localStorage wrapper) persists UI preferences such as current tab, language, return path
- No client-side store (NgRx/Redux) — all domain data is fetched on demand from REST endpoints

## Key Abstractions

**`$resource` + paired service pattern (client):**
- Purpose: Each domain object has two factories — `XyzResource` (raw REST binding) and `Xyz` (caching/business-logic wrapper)
- Examples: `publicERANET-client/app/scripts/service/resources/companies.js`, `agreements.js`
- Pattern:
  ```javascript
  angular.module('services').factory('XyzResource', ['$resource', function($resource) {
      return $resource('webresources/sc/xyz/:id', {id: '@id'}, { query: { method: 'POST', url: 'webresources/sc/xyz/query' } });
  }]);
  angular.module('services').factory('Xyz', ['XyzResource', '$rootScope', ... function(XyzResource, ...) { ... }]);
  ```

**`BaseService<T>` + `@Stateless @Path` (server):**
- Purpose: Unifies REST endpoint + EJB into one class; BaseService injects shared helpers
- Examples: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/CompanyService.java`, `ProcurementService.java`

**`BaseDao<T>` (server):**
- Purpose: Generic JPA CRUD; subclasses add entity-specific named queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`

**Tab controller pattern (client):**
- Purpose: Many routes share `views/general/tabs.html` with a named controller — the same generic tab shell hosts different feature areas
- Examples: `$routeProvider.when('/home/:tabId', { templateUrl: 'views/general/tabs.html', controller: 'HomeController' })`

## Entry Points

**Client SPA:**
- Location: `publicERANET-client/app/index.html`
- Bootstrap: `data-ng-app='eranetPublic'` on `<html>` tag; Angular bootstraps `eranetPublic` module from `ng.app.js`
- Main controller: `MainController` on `<body>` (`scripts/controllers/main.js`)
- SmartAdmin shell init: `app.config.js` (global jQuery config) + `app.js` (SmartAdmin jQuery plugin init)

**Server WAR:**
- Deployment descriptor: `publicERANET-server/src/main/webapp/WEB-INF/web.xml` (servlet 3.0, FORM auth, session timeout 30 min)
- GlassFish deployment: `publicERANET-server/src/main/webapp/WEB-INF/glassfish-web.xml` (context root `/public`, alternatedocroot for client files)
- WildFly/JBoss deployment: `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml` (context root `/public`, security domain `EranetRM`)
- JAX-RS app class: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` (`@ApplicationPath("webresources")`)
- JPA config: `publicERANET-server/src/main/resources/META-INF/persistence.xml` (persistence unit `EranetPU`, JTA data source `EranetDS`, EclipseLink, 269 `<class>` entries)
- JDBC pool setup: `publicERANET-server/src/main/setup/glassfish-resources.xml` (MySQL, database `public`, JNDI `PublicDS`)
- CDI beans: `publicERANET-server/src/main/webapp/WEB-INF/beans.xml`

## Multi-Module Server Structure

The `publicERANET-server` root `pom.xml` is a **single-module Maven WAR project** (not a true multi-module POM reactor). `.gitmodules` declares exactly **one** Git submodule — all active server code otherwise lives directly in `src/main/java/`.

| Directory | Maven role | Content |
|-----------|-----------|---------|
| `src/` | Active WAR source | All Java server code (service, dao, dto, ws, sso, serialization, configuration) |
| `src/main/java/sk/innovis/eranetpublic/server/modules/jackrabbit/` | Git submodule (`submodule-jackrabbit.git`) | Jackrabbit content-repository integration; currently uninitialized in this checkout |
| `lib/` | Local Maven repository | Aspose JARs (Words 16.3, PDF 16.10.0 [jar present: 17.12], Email 5.9, Cells 8.5.2) not in Maven Central |

## Architectural Constraints

- **Threading:** Java EE container manages threads; EJBs are `@Stateless` (pool-managed). WebSocket endpoint is `@Singleton`. No manual threading.
- **Global state (client):** `$rootScope` holds all session state. Access it through the `MainController` which is bound to `<body>`.
- **Global state (server):** `WebStorage` (client localStorage) persists UI prefs across reloads. Server is stateless per request except for the container-managed HTTP session (30-min timeout, cookie name `SESSIONID`).
- **Entity = JSON DTO:** JPA entities are serialized directly as REST responses. Changing entity field names or Jackson annotations affects both persistence and API simultaneously.
- **No Spring:** The pom.xml includes `spring-beans 2.5.6` but Spring is not used for dependency injection — CDI (`@Inject`) and EJB (`@EJB`) are used throughout.
- **REST URL convention:** All secured endpoints are under `/webresources/sc/` — the `web.xml` security constraint covers this prefix.

## Anti-Patterns

### Dual-purpose EJB/JAX-RS classes

**What happens:** Every `*Service.java` file is simultaneously a `@Stateless` EJB and a `@Path` JAX-RS resource. Business logic, transaction management, and HTTP response building are all mixed in the same class.
**Why it's wrong:** Changing a REST path requires touching business logic files; transaction-heavy methods sit next to HTTP response builders; unit testing business logic requires mocking the JAX-RS context.
**Do this instead:** Separate JAX-RS resource classes (thin HTTP layer) from EJB service classes (business logic). Reference: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java`

### Entities as REST DTOs

**What happens:** JPA `@Entity` classes in `dto/` are returned directly from REST endpoints and also used in persistence queries. There is no mapping layer.
**Why it's wrong:** Schema changes break API contracts without warning; `@JsonIgnore` and lazy-loaded collections interact unpredictably with Jackson serialization during transaction scope; adding a new entity column automatically exposes it in the API.
**Do this instead:** Create separate response DTOs for REST layers. Reference existing DTO face interfaces as a starting point: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/face/`

## Error Handling

**Strategy:** JAX-RS exception mapping via `AccessLocalExceptionHandler` (registered in `ApplicationConfig.java`); `WebApplicationException` thrown from services; HTTP status codes returned via `Response.status(...)`.

**Patterns:**
- Services throw `WebApplicationException` with appropriate HTTP status for auth/validation failures
- `BaseDao` logs and rethrows on `ConstraintViolationException`
- Client-side: Angular `$http` interceptors (`mainInterceptor`, `htmlCacheInterceptor`) registered in `ng.app.js`

## Cross-Cutting Concerns

**Logging:** SLF4J with JDK14 binding (`slf4j-jdk14 1.7.7`); `Logger` injected via CDI `@Inject` in both DAOs and services
**Validation:** Java Bean Validation (`validation-mode=NONE` in persistence.xml — disabled for JPA); manual validation in service methods
**Authentication:** Java EE FORM-based login; roles: `administrator`, `user`, `supplier`, `statutory`, `confirmancePerson`, `responsiblePerson`, `systemAdministrator`; SAML 2.0 SSO (`java-saml 2.2.0`, `opensaml 2.6.1`) — no OIDC/OpenID Connect integration in this instance
**i18n:** `angular-translate` with `pascalprecht.translate`; Slovak locale default (`sk`); translation files loaded from `scripts.no.min/langs/` as static JS files
**Document generation:** Aspose Words/PDF/Cells (local JAR repository `lib/`) + Apache POI for Excel

---

*Architecture analysis: 2026-06-03*
