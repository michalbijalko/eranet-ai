<!-- refreshed: 2026-10-16 -->
# Codebase Structure

**Analysis Date:** 2026-10-16

## Directory Layout

```
zsd-wildfly/                        # Workspace root (umbrella repo, branch `zsd`)
├── .claude/                      # Project skills, agents, hooks
├── docs/                         # Project + codebase documentation
├── CLAUDE.md                     # Engineering working agreement
├── configS.bat                   # Liquibase `update` against the local DB
├── configR.bat                   # Liquibase `rollback-count --count=1` against the local DB
├── publicERANET-client/          # AngularJS 1.x SPA subproject (Git repo)
│   ├── app/                      # Deployable SPA root
│   │   ├── index.html            # Single HTML shell; ng-app bootstrap point; registers every app script
│   │   ├── scripts/              # All JavaScript source
│   │   │   ├── ng.app.js         # Angular module declaration + $routeProvider config + run block
│   │   │   ├── app.js            # SmartAdmin/jQuery shell initialization
│   │   │   ├── app.config.js     # SmartAdmin global config (throttle, menu speed, etc.)
│   │   │   ├── config.js         # Angular 'config' module (build timestamp constant)
│   │   │   ├── filters.js        # Angular filters module
│   │   │   ├── ng.directives.js  # Core layout/navigation directives (app.main, app.localize, app.smartui, ...)
│   │   │   ├── bootstrap/        # bootstrap.min.js
│   │   │   ├── controllers/      # Angular controllers (screen logic)
│   │   │   ├── directives/       # Angular directives (reusable widgets, incl. tableFilters/)
│   │   │   ├── notification/     # SmartNotification plugin
│   │   │   ├── plugin/           # Vendored JS plugins (datatables, select2, etc.)
│   │   │   ├── service/          # Angular services
│   │   │   │   ├── resources/    # $resource + business service pairs (116 files)
│   │   │   │   └── business/     # Additional business-logic services (3 files)
│   │   │   └── smartwidgets/     # JarvisWidget code
│   │   ├── views/                # HTML partial templates (mostly mirror controllers/; also directives/, tenders/)
│   │   ├── styles/               # custom.css, custom.not.min.css and theme CSS
│   │   ├── styles.no.min/        # *.min.css copies plus external-page.css, loading.css, zse.css
│   │   ├── scripts.no.min/       # Non-minified JS: langs/ (sk, en, hr), vendored CKEditor 4.6.2, jQuery, select2, registration/forgot-password scripts
│   │   ├── data/                 # Static files (import templates, PDFs in eranet/ and innovis/)
│   │   ├── fonts/                # Web fonts
│   │   ├── images/ img/          # Static image assets (incl. ZSD logos)
│   │   ├── sound/                # Audio files for notifications
│   │   └── bower_components/     # Bower-installed dependencies (untracked, IGNORE)
│   ├── test/
│   │   └── spec/                 # Karma/Jasmine test specs (single stub)
│   ├── Gruntfile.js              # Grunt build configuration (usemin, concat, uglify, cssmin, copy, ngconstant)
│   ├── bower.json                # Bower dependency manifest
│   ├── package.json              # npm/Grunt task dependencies
│   └── nbproject/                # NetBeans project metadata
│
└── publicERANET-server/          # Java EE 7 WAR subproject (Git repo)
    ├── pom.xml                   # Maven WAR project (groupId: sk.innovis, artifactId: eranet-server-zsdtest, Java 1.8)
    ├── docker-compose.yml        # Local MySQL 5.7 container
    ├── src/
    │   ├── main/
    │   │   ├── java/sk/innovis/eranetpublic/server/
    │   │   │   ├── annotation/       # JWTSecured
    │   │   │   ├── api/              # Versioned REST API (rest/ controllers, dto/, mapping/)
    │   │   │   ├── configuration/    # Config beans (General, Itender, MailServer, Secrets)
    │   │   │   ├── dao/              # JPA DAOs (~115 files + helpDto/)
    │   │   │   │   └── helpDto/      # Query helpers: FindParameters, FindResult, etc.
    │   │   │   ├── dto/              # JPA @Entity classes (~185 files)
    │   │   │   │   └── face/         # Interfaces: HasId, HasCopy, IsProcurement
    │   │   │   ├── exception/        # AccessLocalExceptionHandler (JAX-RS exception mapper)
    │   │   │   ├── filter/           # JAX-RS filters: BearerFilter, JWTAuthFilter, ResponseFilter, CustomDynamicFeature
    │   │   │   ├── saml/             # SAML 2.0 client
    │   │   │   ├── serialization/    # Jackson providers, XML adapters
    │   │   │   │   └── dto/          # Serialization-specific DTOs (Proebiz, statistics)
    │   │   │   ├── service/          # REST+EJB service classes (~146 files)
    │   │   │   │   ├── comparator/   # Comparator helpers
    │   │   │   │   ├── ecm/          # ECM integration
    │   │   │   │   ├── enums/        # Shared enums
    │   │   │   │   ├── excel/        # Excel export logic
    │   │   │   │   ├── help/         # Harmonogram interval helper
    │   │   │   │   ├── jms/          # JMS messaging
    │   │   │   │   ├── logic/        # HTML table builder, file description collector
    │   │   │   │   ├── pdf/          # PDF generation services
    │   │   │   │   └── supplier/     # Supplier-specific services
    │   │   │   ├── sso/              # SSO service + SAML assertion container
    │   │   │   └── ws/               # WebSocket endpoints (PingEndpoint, RealTimeEndpoint)
    │   │   │   # package root also holds the security annotations (OauthSecured*, KeySecured,
    │   │   │   # AdministratorRoleAllowed, ProcurerRoleAllowed, SupplierRoleAllowed), Utils,
    │   │   │   # PublicConstants and LoggerProducer
    │   │   ├── resources/
    │   │   │   └── META-INF/
    │   │   │       ├── persistence.xml   # JPA persistence unit config (PublicTestZsdPU)
    │   │   │       ├── idp.metadata.xml  # SAML identity provider metadata
    │   │   │       ├── sp.metadata.xml   # SAML service provider metadata
    │   │   │       ├── antisamy-anythinggoes.xml  # AntiSamy XSS sanitizer policy
    │   │   │       ├── *.jks             # SAML / ECM keystores
    │   │   │       └── xecm*.wsdl        # ECM web service definitions
    │   │   ├── setup/
    │   │   │   └── glassfish-resources.xml  # JDBC pool + JNDI resource definitions
    │   │   ├── sql/                  # Liquibase changelogs (db.changelog-master.xml) + versioned dirs 1.2 → 2.4.0
    │   │   └── webapp/
    │   │       └── WEB-INF/
    │   │           ├── web.xml           # Servlet descriptor, security constraint, session config
    │   │           ├── glassfish-web.xml # GlassFish context-root, alternatedocroot
    │   │           ├── jboss-web.xml     # WildFly/JBoss context-root (/public_zsd)
    │   │           ├── beans.xml         # CDI bean discovery marker
    │   │           ├── antisamy-slashdot-1.4.4.xml  # AntiSamy policy (alternative)
    │   │           └── proebiz_schema.wsdl          # ProEBiz web service definition
    │   └── test/
    │       └── java/test/TestWs.java     # Only Java test class
    └── lib/                          # Local Maven repository for Aspose JARs
        └── com/aspose/
```

> **Git topology:** three independent repos — the two subprojects (each on branch `zsd_wildfly`) and the workspace-root/umbrella repo holding `docs/`, `.claude/`, `CLAUDE.md` (branch `zsd`). Code is committed in its subproject repo; docs and guidance in the umbrella. The `publicERANET-*` dirs are nested repos — never add them from the umbrella. There are no Git submodules in the server checkout.

## Directory Purposes

**`publicERANET-client/app/scripts/controllers/`:**
- Purpose: AngularJS controllers grouped by functional area (~347 files)
- Contains: `main.js`, `header.js`, `login.js`, `lang.js`, `ribbon.js` and other top-level files, plus subdirectories:
  - `procurement/` — procurement lifecycle phases (preparation, evaluation, contract, approval, permissions, publishing)
  - `planning/` — internal requests, yearly plans, merge requests
  - `qualification/` — qualification systems, applications, supplier input
  - `communication/`, `home/`, `buyers/`, `suppliers/`, `statistics/`, `eks/`, `publicLists/`, `publicQualification/`, `companyProfile/`, `personalProfile/`, `general/`, `include/`, `legislation/`
- Key files: `publicERANET-client/app/scripts/controllers/main.js` (MainController — session init, SSO redirect, token refresh)

**`publicERANET-client/app/scripts/service/resources/`:**
- Purpose: One file per domain entity; most export `XyzResource` ($resource) and `Xyz` (business wrapper)
- Contains: 116 resource service files matching server entity names (e.g., `procurements.js`, `companies.js`, `agreements.js`, `applications.js`)
- REST URL pattern: `webresources/sc/<entity>/:id` with POST `query` action at `webresources/sc/<entity>/query`

**`publicERANET-client/app/views/`:**
- Purpose: HTML partial templates; directory structure mostly mirrors `scripts/controllers/`
- Contains: `.html` files per screen/feature; `views/general/tabs.html` is a shared shell used by tab-based controllers; `views/directives/` holds directive templates

**`publicERANET-client/app/scripts.no.min/langs/`:**
- Purpose: Translation files for `angular-translate`; loaded as static `.js` files (`sk.js`, `en.js`, `hr.js`)
- Key: Slovak language is the primary/fallback (`$translateProvider.fallbackLanguage('sk')`); the language selector offers only `sk` and `en`

**`publicERANET-server/src/main/java/.../service/`:**
- Purpose: All JAX-RS REST endpoints + EJB business logic (merged)
- Contains: ~146 `*Service.java` files; `ApplicationConfig.java` registers them explicitly
- Subdirectories: `pdf/` (11 PDF services), `supplier/`, `excel/`, `logic/`, `comparator/`, `enums/`, `help/`, `ecm/`, `jms/`

**`publicERANET-server/src/main/java/.../dao/`:**
- Purpose: JPA data access via EclipseLink; `BaseDao<T>` provides generic CRUD + criteria queries
- Contains: ~115 DAO files; `helpDto/` holds query helper objects (`FindParameters`, `FindResult`, `QueryFilter`, `OrderByField`)

**`publicERANET-server/src/main/java/.../dto/`:**
- Purpose: JPA `@Entity` classes for all domain objects; double as JSON response bodies
- Contains: ~185 entity classes; `face/` contains interfaces (`HasId`, `HasCopy`, `IsProcurement`) used for generic copy/clone operations in BaseService

**`publicERANET-server/src/main/java/.../api/`:**
- Purpose: Versioned REST API under `api/v1/...` (`InternalRequestCategoryApiController`, `PortfolioApiController`) with its own DTOs and mappers

**`publicERANET-server/src/main/java/.../filter/`:**
- Purpose: JAX-RS request filters; `BearerFilter` validates the JWT bearer token and checks the role annotations, `JWTAuthFilter` serves `@JWTSecured` endpoints, `CustomDynamicFeature` registers them

**`publicERANET-server/src/main/sql/`:**
- Purpose: Liquibase changelogs; `db.changelog-master.xml` includes the per-version changelogs
- Contains: Directories per version (1.2 through 2.4.0), plus top-level changelogs and standalone INSERT scripts; applied with `configS.bat`

**`publicERANET-server/lib/`:**
- Purpose: Local Maven repository for Aspose commercial JARs not available in Maven Central
- Generated: No — manually placed
- Committed: Yes (in the server Git repo)

## Key File Locations

**Entry Points:**
- `publicERANET-client/app/index.html`: SPA HTML shell, ng-app bootstrap
- `publicERANET-client/app/scripts/ng.app.js`: Angular module + all routes + run block
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java`: JAX-RS application class, registers all REST services

**Configuration:**
- `publicERANET-server/src/main/resources/META-INF/persistence.xml`: JPA persistence unit, data source, entity list
- `publicERANET-server/src/main/setup/glassfish-resources.xml`: JDBC pool, MySQL connection properties
- `publicERANET-server/src/main/webapp/WEB-INF/web.xml`: Servlet descriptor, security constraint, session config
- `publicERANET-server/src/main/webapp/WEB-INF/glassfish-web.xml`: GlassFish deployment — context root `/public`, client static file path
- `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml`: WildFly deployment — context root `/public_zsd`
- `publicERANET-client/app/scripts/config.js`: Angular `config` module with build timestamp constant
- `publicERANET-client/Gruntfile.js`: Build pipeline (usemin, concat, uglify, cssmin, copy, ngconstant for config.js)
- `publicERANET-client/bower.json`: Front-end dependency manifest

**Core Logic:**
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java`: Abstract base for all services
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`: Abstract base for all DAOs
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java`: Login, logout, SAML, password reset
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/filter/BearerFilter.java`: JWT bearer-token validation and role checks
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/PingEndpoint.java`: WebSocket endpoint used by the client (`/websockets/ping/{groupId}/{userId}/{guid}`)
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/RealTimeEndpoint.java`: WebSocket push (`/websockets/realtime`)

**SAML / SSO:**
- `publicERANET-server/src/main/resources/META-INF/idp.metadata.xml`: SAML IdP metadata (active)
- `publicERANET-server/src/main/resources/META-INF/sp.metadata.xml`: SAML SP metadata
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/SsoService.java`: SSO service

**Testing:**
- `publicERANET-client/test/spec/`: Karma/Jasmine test specs (single stub)
- `publicERANET-server/src/test/java/test/TestWs.java`: the only Java test class

## Naming Conventions

**Client — Files:**
- Controllers: camelCase name matching entity/feature, suffix not required (e.g., `buyerCompanyProfile.js`, `main.js`)
- Resource services: pluralised entity name, lowercase (e.g., `companies.js`, `agreements.js`, `procurements.js`)
- Directive files: camelCase description of widget (e.g., `filesTable.js`, `procurementsTable.js`)
- Views: camelCase HTML files matching feature (e.g., `procurementsList.html`, `planning/editInternalRequest/editInternalRequestBase.html`)

**Client — Angular symbols:**
- Module names: `eranetPublic` (app), `controllers`, `services`, `directives`, `filters`, `app.main`, `app.navigation`, `app.localize`, `app.activity`, `app.smartui`, `config`
- Controller names: PascalCase + `Controller` suffix (e.g., `MainController`, `ProcurementDefinitionController`)
- Service names: PascalCase (e.g., `Companies`, `CompaniesResource`, `WebStorage`, `Utils`)
- Directive names: camelCase in JS (e.g., `filesTable`), kebab-case in HTML (`files-table`)

**Server — Java packages:**
- Root: `sk.innovis.eranetpublic.server`
- Sub-packages match layer: `.service`, `.dao`, `.dto`, `.api`, `.filter`, `.ws`, `.sso`, `.saml`, `.serialization`, `.configuration`, `.annotation`, `.exception`

**Server — Java classes:**
- Entities: PascalCase noun (e.g., `Procurement`, `CompanyInProcurement`, `AuctionResult`)
- Services: PascalCase + `Service` suffix (e.g., `ProcurementService`, `AuthenticationService`)
- DAOs: PascalCase + `Dao` suffix (e.g., `ProcurementDao`, `CompanyDao`)
- Configuration: PascalCase + `Configuration` suffix (e.g., `GeneralConfiguration`, `MailServerConfiguration`)

**Server — REST URL convention:**
- Pattern: `webresources/sc/<entityPlural>/` for secured CRUD
- Query: POST to `webresources/sc/<entityPlural>/query`
- Auth: `webresources/auth/` (login/logout/token validation)
- Versioned API: `api/v1/<resource>` (`api/` package)

## Where to Add New Code

**New domain screen (client):**
- Controller: `publicERANET-client/app/scripts/controllers/<area>/<FeatureName>.js`
- View template: `publicERANET-client/app/views/<area>/<featureName>.html`
- Route: Add `$routeProvider.when(...)` entry in `publicERANET-client/app/scripts/ng.app.js`
- Register the new controller file with a `<script>` tag in `publicERANET-client/app/index.html` (every app script is listed there; unlisted files are not loaded or built)

**New API resource service (client):**
- Implementation: `publicERANET-client/app/scripts/service/resources/<entityPlural>.js`
- Pattern: Export both `XyzResource` ($resource) and `Xyz` (business wrapper) from same file
- REST URL: `webresources/sc/<entityPlural>/:id` with `query` action at `.../query`
- Register with a `<script>` tag in `publicERANET-client/app/index.html`

**New directive (client):**
- Implementation: `publicERANET-client/app/scripts/directives/<directiveName>.js`
- View template (if needed): `publicERANET-client/app/views/directives/<directiveName>.html`
- Register with a `<script>` tag in `publicERANET-client/app/index.html`

**New REST endpoint + entity (server):**
1. Entity: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/<EntityName>.java` — add `@Entity @Table @XmlRootElement @JsonIgnoreProperties(ignoreUnknown=true)`
2. Register entity in: `publicERANET-server/src/main/resources/META-INF/persistence.xml` — add `<class>` entry
3. DAO: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/<EntityName>Dao.java` — extend `BaseDao<EntityName>`
4. Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/<EntityName>Service.java` — extend `BaseService<EntityName>`, annotate `@Stateless @Path("webresources/sc/<entity>")`
5. Register service in: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` — add `resources.add(...)` in `addRestResources()`

**Database migration:**
- Add a Liquibase changeset (author `m.bijalko`) in the matching version dir under `publicERANET-server/src/main/sql/` and include it from `db.changelog-master.xml`; raw `.sql` scripts only for INSERTs

**New translation key:**
- Add to: `publicERANET-client/app/scripts.no.min/langs/<lang>.js`

## Special Directories

**`publicERANET-client/app/bower_components/`:**
- Purpose: Bower-installed front-end dependencies (Angular, Bootstrap, ui-select, ng-table, etc.)
- Generated: Yes (by `bower install`)
- Committed: No (excluded by `.gitignore`)

**`publicERANET-client/app/scripts/plugin/`:**
- Purpose: Vendored jQuery plugins bundled with SmartAdmin template
- Generated: No — manually included with the SmartAdmin purchase
- Committed: Yes

**`publicERANET-server/lib/`:**
- Purpose: Local Maven repository for Aspose commercial JARs (Words, PDF, Email, Cells)
- Generated: No
- Committed: Yes

**`publicERANET-server/src/main/sql/`:**
- Purpose: Liquibase changelogs and standalone INSERT scripts
- Generated: No
- Committed: Yes

---

*Structure analysis: 2026-10-16*
