<!-- refreshed: 2026-06-03 -->
# Codebase Structure

**Analysis Date:** 2026-06-03

## Directory Layout

```
vse/                              # Workspace root
├── configS.bat                   # Windows setup script
├── publicERANET-client/          # AngularJS 1.x SPA subproject (Git repo)
│   ├── app/                      # Deployable SPA root
│   │   ├── index.html            # Single HTML shell; ng-app bootstrap point
│   │   ├── scripts/              # All JavaScript source
│   │   │   ├── ng.app.js         # Angular module declaration + $routeProvider config
│   │   │   ├── app.js            # SmartAdmin/jQuery shell initialization
│   │   │   ├── app.config.js     # SmartAdmin global config (throttle, menu speed, etc.)
│   │   │   ├── config.js         # Angular 'config' module (build timestamp constant)
│   │   │   ├── filters.js        # Angular filters module
│   │   │   ├── ng.directives.js  # Core layout/navigation directives
│   │   │   ├── bootstrap/        # bootstrap.min.js
│   │   │   ├── controllers/      # Angular controllers (screen logic)
│   │   │   ├── directives/       # Angular directives (reusable widgets)
│   │   │   ├── notification/     # SmartNotification plugin
│   │   │   ├── plugin/           # Vendored JS plugins (datatables, select2, etc.)
│   │   │   ├── service/          # Angular services
│   │   │   │   ├── resources/    # $resource + business service pairs (141 files)
│   │   │   │   └── business/     # Additional business-logic services (3 files)
│   │   │   └── smartwidgets/     # JarvisWidget code
│   │   ├── modules/              # VSE feature modules (jackrabbit/ — contract management)
│   │   ├── views/                # HTML partial templates (mirror of controllers/)
│   │   ├── styles/               # Minified CSS (SmartAdmin, Bootstrap, custom)
│   │   ├── styles.no.min/        # Non-minified CSS source
│   │   ├── scripts.no.min/       # Non-minified JS: i18n lang files in langs/
│   │   ├── data/                 # Static data files (PDFs, etc.)
│   │   ├── fonts/                # Web fonts
│   │   ├── images/ img/          # Static image assets
│   │   ├── sound/                # Audio files for notifications
│   │   └── bower_components/     # Vendored front-end dependencies (IGNORE)
│   ├── test/
│   │   └── spec/                 # Karma/Jasmine test specs
│   ├── Gruntfile.js              # Grunt build configuration (concat, uglify, copy, ngconstant)
│   ├── bower.json                # Bower dependency manifest
│   ├── package.json              # npm/Grunt task dependencies
│   └── nbproject/                # NetBeans project metadata
│
└── publicERANET-server/          # Java EE 7 WAR subproject (Git repo)
    ├── pom.xml                   # Maven WAR project (groupId: sk.innovis, Java 1.8)
    ├── src/
    │   ├── main/
    │   │   ├── java/sk/innovis/eranetpublic/server/
    │   │   │   ├── annotation/       # Custom JAX-RS annotations (PATCH.java)
    │   │   │   ├── configuration/    # Config beans (OIDC, Mail, Auction)
    │   │   │   ├── dao/              # JPA DAOs (~139 files + helpDto/)
    │   │   │   │   └── helpDto/      # Query helpers: FindParameters, FindResult, etc.
    │   │   │   ├── dto/              # JPA @Entity classes (~218 files)
    │   │   │   │   └── face/         # Interfaces: HasId, HasCopy, IsProcurement
    │   │   │   ├── exception/        # JAX-RS exception mapper
    │   │   │   ├── interceptor/      # JAX-RS request interceptors
    │   │   │   ├── saml/             # SAML 2.0 client
    │   │   │   ├── serialization/    # Jackson providers, XML adapters
    │   │   │   │   └── dto/          # Serialization-specific DTOs (Proebiz, statistics)
    │   │   │   ├── service/          # REST+EJB service classes (~188 files)
    │   │   │   │   ├── comparator/   # Comparator helpers
    │   │   │   │   ├── enums/        # Shared enums
    │   │   │   │   ├── excel/        # Excel export logic
    │   │   │   │   ├── help/         # Harmonogram interval helper
    │   │   │   │   ├── logic/        # HTML table builder, file description collector
    │   │   │   │   ├── pdf/          # PDF generation services
    │   │   │   │   └── supplier/     # Supplier-specific services
    │   │   │   ├── sso/              # SSO: UPVS (government) + VSE/eID (Azure AD)
    │   │   │   └── ws/               # WebSocket endpoints
    │   │   ├── resources/
    │   │   │   └── META-INF/
    │   │   │       ├── persistence.xml   # JPA persistence unit config
    │   │   │       ├── idp.metadata.xml  # SAML identity provider metadata
    │   │   │       ├── sp.metadata.xml   # SAML service provider metadata
    │   │   │       └── proebiz_schema.wsdl
    │   │   ├── setup/
    │   │   │   └── glassfish-resources.xml  # JDBC pool + JNDI resource definitions
    │   │   ├── sql/                  # Versioned DB migration scripts (1.2 → 2.11.0)
    │   │   └── webapp/
    │   │       └── WEB-INF/
    │   │           ├── web.xml           # Servlet 3.0 descriptor, security, session config
    │   │           ├── glassfish-web.xml # GlassFish context-root, alternatedocroot
    │   │           ├── jboss-web.xml     # WildFly/JBoss context-root, security domain
    │   │           ├── beans.xml         # CDI bean discovery marker
    │   │           └── antisamy-anythinggoes.xml  # AntiSamy XSS sanitizer config
    │   └── test/
    │       └── java/                 # Java test sources (minimal)
    ├── eranet-domain/                # Git submodule — external domain library
    │   └── src/main/resources/META-INF/  # Empty (no Java sources active)
    ├── public-eranet/                # Git submodule — shared service base
    │   └── src/main/java/...         # Empty (no Java sources active)
    └── lib/                          # Local Maven repository for Aspose JARs
        └── com/aspose/               # aspose-words, aspose-pdf, aspose-email, aspose-cells
```

> **Git topology:** three independent repos — the two subprojects (each on branch `vse_test`) and the workspace-root/umbrella repo holding `docs/`, `.claude/`, `CLAUDE.md` (branch `master`). Code is committed in its subproject repo; docs and guidance in the umbrella. The `publicERANET-*` dirs are nested repos — never add them from the umbrella.

## Directory Purposes

**`publicERANET-client/app/scripts/controllers/`:**
- Purpose: AngularJS controllers grouped by functional area
- Contains: `main.js`, `header.js`, `login.js`, `lang.js`, `ribbon.js`, plus subdirectories:
  - `procurement/` — procurement lifecycle phases (preparation, evaluation, contract, approval, permissions, publishing)
  - `planning/` — internal requests, yearly plans, merge requests
  - `qualification/` — qualification systems, applications, supplier input
  - `communication/`, `home/`, `buyers/`, `suppliers/`, `statistics/`, `eks/`, `dataRetention/`, `publicLists/`, `publicQualification/`, `supplierSection/`, `companyProfile/`, `personalProfile/`
- Key files: `publicERANET-client/app/scripts/controllers/main.js` (MainController — session init)

**`publicERANET-client/app/scripts/service/resources/`:**
- Purpose: One file per domain entity; each exports `XyzResource` ($resource) and `Xyz` (business wrapper)
- Contains: 141 resource service files matching server entity names (e.g., `procurements.js`, `companies.js`, `agreements.js`, `applications.js`)
- REST URL pattern: `webresources/sc/<entity>/:id` with POST `query` action at `webresources/sc/<entity>/query`

**`publicERANET-client/app/modules/jackrabbit/` (VSE instance):**
- Purpose: Contract-management feature for the VSE instance — contract lifecycle, activities, checklists
- Structure: `controller/` (e.g. `editContract.js`, `contractsOverview.js`), `service/contracts.js`, `view/`
- VSE-specific: on contract completion, notifies the VSE board at `predstavenstvo@vse.sk` (hardcoded in `controller/editContract.js`)

**`publicERANET-client/app/views/`:**
- Purpose: HTML partial templates; directory structure mirrors `scripts/controllers/`
- Contains: `.html` files per screen/feature; `views/general/tabs.html` is a shared shell used by tab-based controllers

**`publicERANET-client/app/scripts.no.min/langs/`:**
- Purpose: Translation files for `angular-translate`; loaded as static `.js` files
- Key: Slovak language is the primary/fallback (`$translateProvider.fallbackLanguage('sk')`)

**`publicERANET-server/src/main/java/.../service/`:**
- Purpose: All JAX-RS REST endpoints + EJB business logic (merged)
- Contains: 188 `*Service.java` files; `ApplicationConfig.java` registers all of them explicitly
- Subdirectories: `pdf/` (11 PDF services), `supplier/` (2 supplier-specific services), `excel/`, `logic/`, `comparator/`, `enums/`, `help/`

**`publicERANET-server/src/main/java/.../dao/`:**
- Purpose: JPA data access via EclipseLink; `BaseDao<T>` provides generic CRUD + criteria queries
- Contains: 139 DAO files; `helpDto/` holds query helper objects (`FindParameters`, `FindResult`, `QueryFilter`, `OrderByField`)

**`publicERANET-server/src/main/java/.../dto/`:**
- Purpose: JPA `@Entity` classes for all domain objects; double as JSON response bodies
- Contains: 218 entity classes; `face/` contains interfaces (`HasId`, `HasCopy`, `IsProcurement`) used for generic copy/clone operations in BaseService

**`publicERANET-server/src/main/sql/`:**
- Purpose: Versioned SQL migration scripts organized by version number (1.2 through 2.11.0)
- Contains: Directories per version; applied manually (no Flyway/Liquibase detected)

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
- `publicERANET-server/src/main/webapp/WEB-INF/web.xml`: Servlet descriptor, security roles, session config
- `publicERANET-server/src/main/webapp/WEB-INF/glassfish-web.xml`: GlassFish deployment — context root `/public`, client static file path
- `publicERANET-server/src/main/webapp/WEB-INF/jboss-web.xml`: WildFly deployment — context root `/public_vse`
- `publicERANET-client/app/scripts/config.js`: Angular `config` module with build timestamp constant
- `publicERANET-client/Gruntfile.js`: Build pipeline (concat, uglify, copy, ngconstant for config.js)
- `publicERANET-client/bower.json`: Front-end dependency manifest

**Core Logic:**
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java`: Abstract base for all services
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`: Abstract base for all DAOs
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/AuthenticationService.java`: Login, logout, SAML, OIDC, password reset
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/OIDCService.java`: OpenID Connect / JWT
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/RealTimeEndpoint.java`: WebSocket push

**SAML / SSO:**
- `publicERANET-server/src/main/resources/META-INF/idp.metadata.xml`: SAML IdP metadata (active)
- `publicERANET-server/src/main/resources/META-INF/sp.metadata.xml`: SAML SP metadata
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/UpvsSsoService.java`: UPVS government SSO (`@ApplicationPath("upvs")`)
- `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/sso/VseSsoService.java`: VSE / eID SSO (Azure AD SAML; `@ApplicationPath("vse")`)
- `publicERANET-server/src/main/resources/META-INF/idp.vse.metadata.xml`, `sp.vse.metadata.xml`: VSE SAML metadata

**Testing:**
- `publicERANET-client/test/spec/`: Karma/Jasmine test specs (minimal)
- `publicERANET-server/src/test/java/`: Java test directory (minimal)

## Naming Conventions

**Client — Files:**
- Controllers: camelCase name matching entity/feature, suffix not required (e.g., `buyerCompanyProfile.js`, `main.js`)
- Resource services: pluralised entity name, lowercase (e.g., `companies.js`, `agreements.js`, `procurements.js`)
- Directive files: camelCase description of widget (e.g., `filesTable.js`, `procurementsTable.js`)
- Views: camelCase HTML files matching feature (e.g., `procurementsList.html`, `editInternalRequestBase.html`)

**Client — Angular symbols:**
- Module names: `eranetPublic` (app), `controllers`, `services`, `directives`, `filters`, `app.main`, `app.navigation`, `config`
- Controller names: PascalCase + `Controller` suffix (e.g., `MainController`, `ProcurementDefinitionController`)
- Service names: PascalCase (e.g., `Companies`, `CompaniesResource`, `WebStorage`, `Utils`)
- Directive names: camelCase in JS (e.g., `filesTable`), kebab-case in HTML (`files-table`)

**Server — Java packages:**
- Root: `sk.innovis.eranetpublic.server`
- Sub-packages match layer: `.service`, `.dao`, `.dto`, `.ws`, `.sso`, `.saml`, `.interceptor`, `.serialization`, `.configuration`, `.annotation`

**Server — Java classes:**
- Entities: PascalCase noun (e.g., `Procurement`, `CompanyInProcurement`, `AuctionResult`)
- Services: PascalCase + `Service` suffix (e.g., `ProcurementService`, `AuthenticationService`)
- DAOs: PascalCase + `Dao` suffix (e.g., `ProcurementDao`, `CompanyDao`)
- Configuration: PascalCase + `Configuration` suffix (e.g., `OIDCConfiguration`, `MailServerConfiguration`)

**Server — REST URL convention:**
- Pattern: `webresources/sc/<entityPlural>/` for secured CRUD
- Query: POST to `webresources/sc/<entityPlural>/query`
- Auth: `webresources/auth/` (unsecured login/logout)

## Where to Add New Code

**New domain screen (client):**
- Controller: `publicERANET-client/app/scripts/controllers/<area>/<FeatureName>.js`
- View template: `publicERANET-client/app/views/<area>/<featureName>.html`
- Route: Add `$routeProvider.when(...)` entry in `publicERANET-client/app/scripts/ng.app.js`

**New API resource service (client):**
- Implementation: `publicERANET-client/app/scripts/service/resources/<entityPlural>.js`
- Pattern: Export both `XyzResource` ($resource) and `Xyz` (business wrapper) from same file
- REST URL: `webresources/sc/<entityPlural>/:id` with `query` action at `.../query`

**New directive (client):**
- Implementation: `publicERANET-client/app/scripts/directives/<directiveName>.js`
- View template (if needed): `publicERANET-client/app/views/directives/<directiveName>.html`

**New REST endpoint + entity (server):**
1. Entity: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/<EntityName>.java` — add `@Entity @Table @XmlRootElement @JsonIgnoreProperties(ignoreUnknown=true)`
2. Register entity in: `publicERANET-server/src/main/resources/META-INF/persistence.xml` — add `<class>` entry
3. DAO: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/<EntityName>Dao.java` — extend `BaseDao<EntityName>`
4. Service: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/<EntityName>Service.java` — extend `BaseService<EntityName>`, annotate `@Stateless @Path("webresources/sc/<entity>")`
5. Register service in: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java` — add `resources.add(...)` in `addRestResources()`

**Database migration:**
- Add SQL script in: `publicERANET-server/src/main/sql/<new-version>/` (follow existing version numbering)

**New translation key:**
- Add to: `publicERANET-client/app/scripts.no.min/langs/<lang>.js`

## Special Directories

**`publicERANET-client/app/bower_components/`:**
- Purpose: Bower-installed front-end dependencies (Angular, Bootstrap, ui-select, ng-table, etc.)
- Generated: Yes (by `bower install`)
- Committed: Yes (present in repo — no `.gitignore` exclusion detected)

**`publicERANET-client/app/scripts/plugin/`:**
- Purpose: Vendored jQuery plugins bundled with SmartAdmin template
- Generated: No — manually included with the SmartAdmin purchase
- Committed: Yes

**`publicERANET-server/lib/`:**
- Purpose: Local Maven repository for Aspose commercial JARs (Words, PDF, Email, Cells)
- Generated: No
- Committed: Yes

**`publicERANET-server/src/main/sql/`:**
- Purpose: Versioned SQL migration scripts; applied manually to MySQL
- Generated: No
- Committed: Yes

**`publicERANET-server/eranet-domain/` and `public-eranet/`:**
- Purpose: Git submodules for shared libraries
- Java source: Not present in current checkout — both directories contain only resources or are empty
- Committed: Submodule references committed; Java source must be fetched via `git submodule update --init`

---

*Structure analysis: 2026-06-03*
