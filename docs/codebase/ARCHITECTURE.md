<!-- refreshed: 2026-10-16 -->
# Architecture

**Analysis Date:** 2026-10-16

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
│     (Authorization: Bearer <JWT> on every call)                      │
│  ngWebSocket ─────────── WebSocket ───────────► websockets/ping/**  │
└──────────────────────────────────────────────────────────────────────┘
                              │  HTTP (same host, context-root /public_zsd)
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│          Java EE 7 WAR — publicERANET-server                         │
│          Deployed on WildFly (GlassFish descriptors kept for legacy) │
│                                                                      │
│  JAX-RS (RESTEasy) filters: BearerFilter / JWTAuthFilter             │
│  `src/main/java/sk/innovis/eranetpublic/server/filter/`              │
│                                                                      │
│  JAX-RS (RESTEasy) REST layer                                        │
│  `src/main/java/sk/innovis/eranetpublic/server/service/*Service.java`│
│                      @ApplicationPath("webresources")                │
│                                                                      │
│  EJB Business/Service layer                                          │
│  `src/main/java/sk/innovis/eranetpublic/server/service/BaseService` │
│                                                                      │
│  JPA (EclipseLink) DAO layer                                         │
│  `src/main/java/sk/innovis/eranetpublic/server/dao/*Dao.java`        │
│                                                                      │
│  JPA Entities / DTOs                                                 │
│  `src/main/java/sk/innovis/eranetpublic/server/dto/*.java` (185 cls)│
└──────────────────────────────────────────────────────────────────────┘
                              │  JTA / JDBC
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│   MySQL database  (JNDI: PublicZsdDS / PublicDS legacy)             │
│   Persistence unit: PublicTestZsdPU                                  │
│   `src/main/resources/META-INF/persistence.xml`                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File / Path |
|-----------|----------------|-------------|
| AngularJS SPA bootstrap | Module declaration, `$routeProvider` config, global `$rootScope` run block, token login | `publicERANET-client/app/scripts/ng.app.js` |
| SmartAdmin shell | jQuery-based layout, sidebar, widgets, date pickers | `publicERANET-client/app/scripts/app.js`, `app.config.js` |
| Angular controllers | Screen-level logic, UI state, calling services | `publicERANET-client/app/scripts/controllers/**/*.js` (~347 files; 15 at top level) |
| Angular resource services | `$resource` wrappers mapping to server REST URLs | `publicERANET-client/app/scripts/service/resources/*.js` (116 files) |
| Angular business services | Client-side business logic, caching, result manipulation | `publicERANET-client/app/scripts/service/business/*.js` |
| Angular directives | Reusable table widgets, file upload tables, form helpers | `publicERANET-client/app/scripts/directives/*.js` |
| Angular filters | Display formatting (status icons, numeric, date) | `publicERANET-client/app/scripts/filters.js` |
| `ApplicationConfig.java` | JAX-RS `Application` subclass — registers all REST resource classes and the `BearerFilter` singleton | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` |
| `BaseService<T>` | Abstract ancestor for most REST services: date formats, EJB injection, find/copy helpers, `getCurrentUser()` | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java` |
| Concrete `*Service.java` | `@Stateless` EJBs annotated with `@Path`: expose CRUD + query endpoints for each domain object | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/*.java` (146 files; 128 extend `BaseService`) |
| `BaseDao<T>` | Generic JPA CRUD, criteria-builder queries, pagination | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java` |
| Concrete `*Dao.java` | Entity-specific queries extending BaseDao | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/*.java` (115 files) |
| JPA entities / DTOs | `@Entity` classes mapped to MySQL tables; also serialized directly as JSON responses | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/*.java` (185 files, 169 `@Entity`) |
| `BearerFilter` | Validates the JWT bearer token, checks the role annotations, installs the security context | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/filter/BearerFilter.java` |
| `AuthenticationService` | SAML login/logout initiation, small public lookups (`cpvList`, `categoryList`, `isAlive`) — no password login | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java` |
| SAML/SSO | Slovak government UPVS SSO integration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/`, `saml/` |
| Versioned API | `api/v1/*` controllers secured with `@JWTSecured` | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/api/` |
| WebSocket endpoints | Procurement-opening room (`/websockets/ping/{groupId}/{userId}/{guid}`) and push (`/websockets/realtime`) | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/` |
| PDF generation services | Aspose-Word/PDF document generation | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/pdf/` |
| Excel services | Apache POI + Aspose Cells export | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/excel/` |
| `ConfigurationService` | Reads JNDI-provisioned mail, general, iTender and secrets configuration | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ConfigurationService.java` |

## Pattern Overview

**Overall:** Three-tier SPA + REST backend with direct entity serialization

**Key Characteristics:**
- Client and server are separate Git repositories under a parent workspace root
- The AngularJS SPA is served as static files; the server WAR uses GlassFish `alternatedocroot` to serve the client from an external path (configured in `glassfish-web.xml`)
- REST base path is `webresources/` — all client `$resource` URLs are relative, e.g. `webresources/sc/company/:companyId`
- JPA entities are used directly as REST response bodies (Jackson serialization) — the `api/` package is the only place with separate DTOs and mappers
- EJB `@Stateless` beans are simultaneously JAX-RS resources (dual role: container-managed transactions + HTTP endpoints)

## Layers

**Client — Routing Layer:**
- Purpose: Hash-based `ngRoute` routing; maps URL fragments to controller + template pairs
- Location: `publicERANET-client/app/scripts/ng.app.js` (config block ends near line 650)
- Contains: ~159 `$routeProvider.when(...)` declarations (about 81 under `/procurement`, 23 under `/qualification`, 11 under `/planning`)
- Depends on: Angular `ngRoute`, `ui.bootstrap`
- Used by: Browser address bar; `$location.url()` calls in controllers

**Client — Controller Layer:**
- Purpose: Screen-specific logic, user interaction, calls services, sets `$scope` for view binding
- Location: `publicERANET-client/app/scripts/controllers/`
- Contains: 15 top-level controller files plus deeply nested subdirectories for procurement, qualification, planning, evaluation, communication
- Depends on: Angular services from `service/resources/` and `service/business/`
- Used by: View templates via `ng-controller` or route config

**Client — Service / Resource Layer:**
- Purpose: `$resource` factory wrappers (`*Resource` factories) + business-logic service objects that cache results and expose named methods
- Location: `publicERANET-client/app/scripts/service/resources/` (116 files), `publicERANET-client/app/scripts/service/business/` (3 files)
- Pattern: Most resource files export two factories — `XyzResource` (raw `$resource`) and `Xyz` (higher-level service wrapping it)
- Depends on: `$resource`, `$http`, `$rootScope`, `ResultManipulator`, `Utils`, `FilterHelper`
- Used by: Controllers

**Client — Directive Layer:**
- Purpose: Reusable UI widgets (data tables, file attachment grids, approval tables)
- Location: `publicERANET-client/app/scripts/directives/` (35 files + `tableFilters/` subdir)
- Depends on: Angular services, `ngTable`
- Used by: View templates

**Client — View Layer:**
- Purpose: HTML templates with Angular bindings; mostly mirrors controller directory structure
- Location: `publicERANET-client/app/views/` (plus `views/directives/` for directive templates)
- Contains: `.html` partial templates loaded by `$routeProvider` or `ng-include`

**Server — REST/EJB Service Layer:**
- Purpose: HTTP endpoints + business logic in a single `@Stateless @Path` class; handles authorization annotations, calls DAOs, sends emails
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/`
- Contains: 146 service files (137 with `@Path`, all registered in `ApplicationConfig`); most extend `BaseService<T>`
- Depends on: DAO layer via `@EJB` injection; `EntityManager` indirectly via DAOs
- Used by: JAX-RS container via `ApplicationConfig.java`

**Server — DAO Layer:**
- Purpose: JPA/EclipseLink data access; `BaseDao<T>` provides generic CRUD, pagination, criteria-builder queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/`
- Contains: 115 DAO files; 114 extend `BaseDao<T>`
- Depends on: `EntityManager` (`@PersistenceContext(name="PublicPU")`)
- Used by: Service layer via `@EJB`

**Server — Entity (DTO) Layer:**
- Purpose: `@Entity` JPA classes mapped to MySQL; also serialized as JSON responses via Jackson
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/`
- Contains: 185 files (169 `@Entity`); registered explicitly in `persistence.xml` (the list has drifted, see CONCERNS.md)
- Depends on: EclipseLink, Jackson, Apache Commons BeanUtils (for copy/clone helpers)

## Data Flow

### Authenticated REST CRUD request

1. Browser loads `ng-app` bootstrap → `eranetPublic` module from `publicERANET-client/app/scripts/ng.app.js`
2. Route change → controller instantiated, calls `XyzResource.query(postData)` in `scripts/service/resources/xyz.js`
3. Angular `$resource` issues `POST webresources/sc/xyz/query` (or `GET/PUT/DELETE` for others); `bearerAuthInterceptor` adds `Authorization: Bearer <JWT>`
4. HTTP request reaches the WAR context `/public_zsd` on WildFly (`/public` on GlassFish)
5. `BearerFilter` (registered as a singleton in `ApplicationConfig.getSingletons()`) verifies the token and, for methods annotated `@ProcurerRoleAllowed` / `@SupplierRoleAllowed` / `@AdministratorRoleAllowed`, the `authorities` claim
6. `ApplicationConfig` routes the request to the correct `XyzService.java` method
7. `XyzService` (EJB `@Stateless`) resolves the user with `getCurrentUser()` and delegates to `XyzDao.java`
8. `XyzDao` uses `EntityManager` (EclipseLink, JTA data source `PublicZsdDS`) to query MySQL
9. Entity returned → Jackson serializes to JSON → response sent to client
10. Angular `$resource` resolves promise → controller updates `$scope` → Angular digest cycle re-renders view

### WebSocket (procurement opening room)

1. `controllers/procurement/evaluationPhase/onlineOpening.js` opens `$websocket(hostUrl + 'websockets/ping/<procurementId>/<userId>/<guid>')`; `hostUrl` comes from the `Host` server setting
2. Server `PingEndpoint.java` (`@ServerEndpoint("/websockets/ping/{groupId}/{userId}/{guid}")`) tracks sessions per procurement
3. Server events push signals (`refreshPage`, `refreshMessage`, `refreshUsers`, `refreshMessagesAndCompanies`, `closeOpening`) to the group
4. `RealTimeEndpoint.java` (`/websockets/realtime`) exists on the server, but no client code connects to it

### Authentication (supplier-portal token / SSO)

1. Unauthenticated user sees `views/login.html` (shown by an `ng-if` on `!$root.logged` in `index.html`); the buttons redirect to the external supplier portal ("DP") via `$rootScope.generateOauthUrl()` (`controllers/main.js`)
2. The portal returns the browser to the SPA with the token in the URL fragment (`#/accessToken=<JWT>`); `loginWithToken` in `ng.app.js` parses it and stores `accesstoken` / `tokenExpiry` in localStorage
3. Every call carries `Authorization: Bearer <JWT>`; `BearerFilter` verifies it (HS256, secret from JNDI) and maps the `authorities` claim to the role annotations
4. SAML SSO (ÚPVS): the client calls `webresources/auth/samlLogin/`; `SsoService` handles the assertion at `/saml/post/ac` and redirects to `#/associateUser/<hash>/...`
5. `MainController.checkTokenExpiry` polls every 30 s and renews the token silently through a hidden iframe
6. Logout: `webresources/auth/logout/<nameId>/<sessionIndex>` → SAML logout request, then `window.location.href` redirect

**State Management:**
- `$rootScope` holds global session state: `logged`, `currentUser`, `procurementId`, `currentProcurement`, `globalTabId`, `showProcurementMenu`, `showQualificationMenu`, etc.
- `WebStorage` service (localStorage wrapper) persists UI preferences such as current tab, language, return path
- `ServerSettings` is a global, server-driven configuration/feature-flag cache (`SETTING_NAME_*`: Host, URSO, EKS, ECM export URL, ...)
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

**Role annotations + `BearerFilter` (server):**
- Purpose: Class-level `@OauthSecured` demands a valid token; per-method `@ProcurerRoleAllowed` (113 uses), `@SupplierRoleAllowed` (54) and `@AdministratorRoleAllowed` (13) demand token roles; `@PermitAll` marks public endpoints
- Note: role annotations are read from the **method** only — see CONCERNS.md

**`BaseDao<T>` (server):**
- Purpose: Generic JPA CRUD; subclasses add entity-specific named queries
- Location: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`

**Tab controller pattern (client):**
- Purpose: Many routes share `views/general/tabs.html` with a named controller — the same generic tab shell hosts different feature areas
- Examples: `$routeProvider.when('/home/:tabId', { templateUrl: 'views/general/tabs.html', controller: 'HomeController' })`

## Entry Points

**Client SPA:**
- Location: `publicERANET-client/app/index.html`
- Bootstrap: `ng-app="eranetPublic"` with `data-ng-strict-di` on the `<html>` tag; Angular bootstraps `eranetPublic` from `ng.app.js`
- Main controller: `MainController` on `<body>` (`scripts/controllers/main.js`)
- SmartAdmin shell init: `app.config.js` (global jQuery config) + `app.js` (SmartAdmin jQuery plugin init)
- Every app script is registered with a `<script>` tag in `index.html` (inside the usemin build blocks); a few files on disk are not registered

**Server WAR:**
- Deployment descriptor: `publicERANET-server/src/main/webapp/WEB-INF/web.xml` (servlet 3.0; no `login-config` or `session-config`; a security constraint listing roles without URL patterns; a `FacesServlet` mapping)
- GlassFish deployment: `publicERANET-server/src/main/webapp/WEB-INF/glassfish-web.xml` (context root `/public_zsd`, alternatedocroot for client files, role-to-group mappings)
- WildFly/JBoss deployment: `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml` (context root `/public_zsd`; no security domain)
- JAX-RS app class: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` (`@ApplicationPath("webresources")`)
- JPA config: `publicERANET-server/src/main/resources/META-INF/persistence.xml` (persistence unit `PublicTestZsdPU`, JTA data source `PublicZsdDS`, EclipseLink static weaving, ~188 `<class>` entries)
- JDBC pool setup: `publicERANET-server/src/main/setup/glassfish-resources.xml` (MySQL, database `public`, JNDI `PublicDS`; legacy)
- CDI beans: `publicERANET-server/src/main/webapp/WEB-INF/beans.xml` (`bean-discovery-mode=all`)

## Server Module Structure

The `publicERANET-server` root `pom.xml` is a **single-module Maven WAR project** (no `<modules>`, no Git submodules). All active server code lives in `src/main/java/`.

| Directory | Maven role | Content |
|-----------|-----------|---------|
| `src/` | Active WAR source | Java server code (service, dao, dto, api, filter, ws, sso, saml, serialization, configuration) plus the generated-client roots `dperanet/` and `ixtent/` |
| `lib/` | Local Maven repository | Aspose JARs (Words 16.3, PDF 10.6.2, Email 5.9, Cells 8.5.2) not in Maven Central |
| `target/` | Build output | Local WAR and surefire reports (untracked build artefacts) |

## Architectural Constraints

- **Threading:** Java EE container manages threads; EJBs are `@Stateless` (pool-managed). WebSocket endpoints are `@Singleton`. No manual threading.
- **Global state (client):** `$rootScope` holds all session state. Access it through the `MainController` which is bound to `<body>`.
- **Global state (server):** the server is effectively stateless per request — identity comes from the bearer token on every call; no `HttpSession` use.
- **Entity = JSON DTO:** JPA entities are serialized directly as REST responses. Changing entity field names or Jackson annotations affects both persistence and API simultaneously.
- **No Spring DI:** The pom.xml includes `spring-beans 2.5.6` (used only for `BeanWrapper` in `Utils`); dependency injection is CDI (`@Inject`) and EJB (`@EJB`).
- **REST URL convention:** Most secured endpoints are under `/webresources/sc/`; others are `auth`, `saml`, `ecm`, `jms/receive`, `public` and `api/v1/*`.
- **HTTP method coverage:** there is no custom `@PATCH` annotation; use `PUT`/`POST`.

## Anti-Patterns

### Dual-purpose EJB/JAX-RS classes

**What happens:** Every `*Service.java` file is simultaneously a `@Stateless` EJB and a `@Path` JAX-RS resource. Business logic, transaction management, and HTTP response building are all mixed in the same class.
**Why it's wrong:** Changing a REST path requires touching business logic files; transaction-heavy methods sit next to HTTP response builders; unit testing business logic requires mocking the JAX-RS context.
**Do this instead:** Separate JAX-RS resource classes (thin HTTP layer) from EJB service classes (business logic). Reference: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java`

### Entities as REST DTOs

**What happens:** JPA `@Entity` classes in `dto/` are returned directly from REST endpoints and also used in persistence queries. Only the `api/` package has a mapping layer.
**Why it's wrong:** Schema changes break API contracts without warning; `@JsonIgnore` and lazy-loaded collections interact unpredictably with Jackson serialization during transaction scope; adding a new entity column automatically exposes it in the API.
**Do this instead:** Create separate response DTOs for REST layers, as in `api/dto` and `api/mapping`. Reference existing DTO face interfaces as a starting point: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/face/`

## Error Handling

**Strategy:** JAX-RS exception mapping via `AccessLocalExceptionHandler` (registered in `ApplicationConfig.java`); `WebApplicationException` thrown from services; HTTP status codes returned via `Response.status(...)`.

**Patterns:**
- Services throw `WebApplicationException` with appropriate HTTP status for auth/validation failures; `BearerFilter` aborts with an access-denied response for missing or invalid tokens
- `BaseDao.update()` rethrows `ConstraintViolationException`; `create()` logs and swallows it
- Client-side: Angular `$http` interceptors (`mainInterceptor`, `htmlCacheInterceptor`, `bearerAuthInterceptor`) registered in `ng.app.js`

## Cross-Cutting Concerns

**Logging:** SLF4J with JDK14 binding (`slf4j-jdk14 1.7.7`); `Logger` injected via CDI `@Inject` (`LoggerProducer`) in both DAOs and services
**Validation:** Java Bean Validation (`validation-mode=NONE` in persistence.xml — disabled for JPA); manual validation in service methods
**Authentication:** external JWT bearer token verified by `BearerFilter`; roles from the `authorities` claim (`ROLE_CLEN_KOMISIE`, `ROLE_ADMIN_ERANET`, `ROLE_DODAVATEL`, `ROLE_DODAVATEL_ADMIN`); SAML 2.0 for ÚPVS identity (`java-saml 2.2.0`, `opensaml 2.6.4`)
**Authorization groups:** `SystemUserGroup` roles `user`, `administrator`, `supplier`, `systemAdministrator` (plus `statutory`, `observer` in `SystemUserGroupType`)
**i18n:** `angular-translate` with `pascalprecht.translate`; Slovak locale default (`sk`); translation files loaded from `scripts.no.min/langs/` as static JS files (`sk`, `en`, `hr`; the selector offers `sk` and `en`)
**Document generation:** Aspose Words/PDF/Cells (local JAR repository `lib/`) + Apache POI for Excel

---

*Architecture analysis: 2026-10-16*
