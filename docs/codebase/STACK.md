# Technology Stack

**Analysis Date:** 2026-10-16

---

## Overview

This repo contains two sibling subprojects:
- `publicERANET-client/` — AngularJS single-page application
- `publicERANET-server/` — Java EE 7 REST + WebSocket backend, packaged as a WAR

---

## Client — publicERANET-client/

### Language

**Primary:**
- JavaScript (ES5) — all application code under `publicERANET-client/app/scripts/`

### Runtime

**Environment:**
- Node.js `>=0.10.0` (declared in `publicERANET-client/package.json` `engines` field)
- Travis CI tested against Node.js `0.8` and `0.10` (`publicERANET-client/.travis.yml`)

**Package Manager:**
- npm — `publicERANET-client/package.json` (devDependencies only; no runtime npm packages)
- Bower — `publicERANET-client/bower.json` (runtime JS/CSS dependencies)
- Lockfile: `publicERANET-client/package-lock.json` present for npm; no `bower.lock`

### Framework

**Core:**
- AngularJS `~1.5.5` — SPA framework (`publicERANET-client/bower.json`)
  - `angular-route ~1.5.5` — client-side routing
  - `angular-resource ~1.5.5` — `$resource` REST helper
  - `angular-sanitize ~1.5.5` — HTML sanitisation
  - `angular-i18n ~1.5.5` — locale support
  - `angular-translate ~2.15.1` + `angular-translate-loader-static-files ~2.15.1` — i18n message loading

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
| `angularjs-oauth2` | `~1.2.3` | Declared and installed but **not loaded** (not in `index.html`, not an `eranetPublic` dependency); the real login is a redirect with a JWT, see ARCHITECTURE.md |
| `cookieconsent2` | `~1.0.10` | GDPR cookie banner |
| `ngdropzone` | `~1.0.5` | Drag-and-drop file upload |
| `iframe-resizer` | `~4.3.11` | Declared only; not installed and not referenced in `app/` |

Source: `publicERANET-client/bower.json`. The CKEditor build actually loaded by `index.html` is the vendored 4.6.2 copy in `app/scripts.no.min/ckeditor`, not the Bower `ckeditor` package.

### Build Tooling

**Task Runner:** Grunt `~0.4.1` — `publicERANET-client/package.json`, `publicERANET-client/Gruntfile.js`

**Key Grunt plugins** (all in `publicERANET-client/package.json` devDependencies):

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
| `grunt-concurrent`, `grunt-contrib-clean`, `grunt-contrib-copy`, `grunt-contrib-htmlmin` | Build orchestration, cleanup, asset copy, HTML minification |
| `grunt-google-cdn` | Replaces Bower script references with CDN URLs |
| `grunt-karma`, `grunt-newer`, `load-grunt-tasks`, `time-grunt`, `jshint-stylish` | Test runner hook, incremental tasks, task loading, timing, lint reporter |

The Gruntfile has an `imagemin` config, but `grunt-contrib-imagemin` is not declared in `package.json` and the task is commented out of `build`.

**Build output:** `publicERANET-client/dist/`

**Build commands:**
```bash
npm install          # Install Grunt plugins
bower install        # Install runtime dependencies
grunt serve          # Dev server at localhost:9000 with live-reload
grunt test           # clean:server, concurrent:test, autoprefixer, connect:test, karma (no JSHint)
grunt build          # Full production build to dist/
grunt                # Default task: newer:jshint, test, build
```

`grunt build` runs `ngconstant`, which needs `grunt-ng-constant`; run `npm install` first if `node_modules` is stale.

### Testing

**Framework:** Karma `~0.12.31` — `publicERANET-client/karma.conf.js`
- Test framework: Jasmine (`frameworks: ['jasmine']`)
- E2E config: `publicERANET-client/karma-e2e.conf.js` (uses `karma-ng-scenario`)
- `karma.conf.js` configures no preprocessors; `karma-ng-html2js-preprocessor` is declared but unused
- Browser: Chrome (configured in `karma.conf.js`)
- `karma-jasmine` and `karma-chrome-launcher` are not declared in `package.json`, so Karma will not start as installed (see TESTING.md)

### Code Quality

**Linting:** JSHint — `publicERANET-client/.jshintrc`, `publicERANET-client/test/.jshintrc`
**Editor standards:** `publicERANET-client/.editorconfig`

### Project Generator

Scaffolded from `generator-angular 0.8.0` (Yeoman), noted at top of `publicERANET-client/Gruntfile.js`.

---

## Server — publicERANET-server/

### Language

**Primary:**
- Java 8 (`source`/`target` = `1.8`) — `publicERANET-server/pom.xml` `<java.version>1.8</java.version>`

### Build Tool

**Maven** — `publicERANET-server/pom.xml`
- Group: `sk.innovis`, Artifact: `eranet-server-zsdtest`, Version: `1.0-SNAPSHOT`
- Packaging: **WAR**
- In-project local repo: `publicERANET-server/lib/` (hosts Aspose commercial JARs)
- Central repo: `https://repo1.maven.org/maven2`

**Maven plugins** (the pom declares only these three; there is no static-weaving plugin — `eclipselink.weaving=static` is set in `persistence.xml` only):

| Plugin | Version | Purpose |
|--------|---------|---------|
| `maven-compiler-plugin` | 3.1 | Compile Java 8 (endorsed dirs); the JPA metamodel annotation processor `jpa.modelgen.processor 2.6.4` is a declared dependency |
| `maven-war-plugin` | 2.3 | Package WAR, bundle SQL into `WEB-INF/sql/`, set logging profile `zsd_profile` |
| `maven-dependency-plugin` | 2.6 | Copy endorsed JARs |

> **Build JDK:** the Maven build must run under **JDK 8** (e.g. `JAVA_HOME=…\jdk1.8.0_351`). A
> default JDK 21/23 can break the Java 8 annotation processing (JPA modelgen).

### Application Server

**Target Runtime:** WildFly 11.0.0 (taken from the `c:\WildFly\11.0.0\...` driver path in `configS.bat`/`configR.bat`; the pom does not state it). Data source JNDI `PublicZsdDS` in `persistence.xml`; WAR context root `/public_zsd` (`jboss-web.xml`, `glassfish-web.xml`), module name `public-server-zsd` (`web.xml`)
- Originally also configured for GlassFish (legacy `publicERANET-server/src/main/setup/glassfish-resources.xml`)
- Application context path: `/webresources` (`@ApplicationPath("webresources")` in `ApplicationConfig.java`)

### API Framework

**JAX-RS:** JBoss RESTEasy `2.2.1.GA` (`provided` scope) — REST endpoints
- All resources registered manually in `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ApplicationConfig.java`
- REST base path: `webresources/`
- Multipart provider: `resteasy-multipart-provider 2.2.0.GA` (`provided`); `jackson-jaxrs-json-provider 2.3.2` is also `provided`

**WebSocket (JSR-356):** `javax.websocket` (Java EE 7 provided)
- Server endpoint: `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/PingEndpoint.java`
- Path: `/websockets/ping/{groupId}/{userId}/{guid}`
- Used for real-time procurement opening room chat and online-presence tracking
- Second endpoint: `ws/RealTimeEndpoint.java` at `/websockets/realtime` (`@Singleton`, 1-second `@Schedule`)

### Persistence

**JPA Provider:** EclipseLink `2.6.4` — `publicERANET-server/pom.xml`
- Persistence unit: `PublicTestZsdPU` (JTA)
- JTA data source JNDI: `PublicZsdDS`
- Static weaving enabled (`eclipselink.weaving=static`, `eclipselink.target-server=JBoss`)
- Persistence descriptor: `publicERANET-server/src/main/resources/META-INF/persistence.xml`
- 185 files under package `sk.innovis.eranetpublic.server.dto` (169 `@Entity`); `persistence.xml` lists 188 `<class>` entries

**Database Schema Migrations:** Liquibase (external CLI, not Maven plugin)
- Master changelog: `publicERANET-server/src/main/sql/db.changelog-master.xml`
- Root changelogs `1.0`, `1.1`, `hurtuk`, `spireng`, `dp-connector` plus versioned folders `1.2` through `2.4.0` under `publicERANET-server/src/main/sql/`; the master includes them all
- Run via `configS.bat` (update) / `configR.bat` (rollback one changeset) using the WildFly-bundled MySQL connector

### Component Model

**Java EE CDI/EJB (javax.enterprise, javax.ejb):**
- Services are `@Stateless` EJBs
- Dependency injection via `@EJB` and `@Inject`
- Scheduling via `@Schedule` (e.g., WebSocket keepalive)

### Key Server Dependencies (pom.xml)

| Library | Version | Purpose |
|---------|---------|---------|
| `jjwt` (`io.jsonwebtoken` api/impl/jackson) | 0.12.6 | JWT verification in `JWTVerificationService` |
| `java-jwt` (auth0) | 3.3.0 | HS256 token verification in `BearerFilter` (the server never creates tokens) |
| `antisamy` (OWASP) | 1.5.7 | HTML sanitising of uploaded content (`FileService`) |
| Apache CXF (core, JAX-WS frontend, WS-Security, HTTP transports) | 3.4.5 | SOAP clients (`EcmService`, `ProebizService`) |
| `xmlsec` (Santuario) | 2.3.0 | XML signatures (`SAMLClient`) |
| `junit` | 4.6 (test) | the single `TestWs` class |
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
| `aspose-email` | 5.9.0 | Declared; only the license call uses it (commercial) |
| `aspose-cells` | 8.5.2 | Excel processing (commercial) |
| `httpclient` | 4.3.1 | Outbound HTTP calls |
| `unirest-java` | 1.4.7 | HTTP client (Unirest) |
| `jcabi-http` | 1.10.3 | Fluent HTTP client (declared, no imports in `src`) |
| `guava` | 18.0 | Google utilities (collections, net) |
| `spring-beans` | 2.5.6.SEC03 | `BeanWrapper` in `Utils` only |
| `slf4j-jdk14` | 1.7.7 | SLF4J logging bridge |

Provided-scope Java EE APIs: `javaee-web-api 7.0` (plus servlet, persistence, JAX-RS, CDI and EJB APIs).

License: `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic` (also tracked under `WEB-INF/`; applied in `ProcurementService`)

---

## Configuration

**Database (server):**
- Docker Compose: `publicERANET-server/docker-compose.yml` — two MySQL 5.7 containers
  - `eranet_mysql` — application DB (`eranet_db`), default port 3307
  - `jackrabbit_mysql` — JCR DB (`jackrabbit_db`), default port 3308; unused, no code references JCR
- The local dev database used by `configS.bat` is `zsd-wildfly` on `localhost:3306`
- Overridden via `.env` file; example: `publicERANET-server/.env.example`
- JNDI pool configured in `publicERANET-server/src/main/setup/glassfish-resources.xml` (legacy) and WildFly server config

**Migrations:**
- Run manually via `configS.bat` / `configR.bat` at project root using Liquibase CLI

**Client constants:**
- Build-time config injected into `dist/scripts/config.js` via `grunt-ng-constant` (`publicERANET-client/Gruntfile.js` `ngconstant` task)

**Logging:**
- Server: WildFly logging profile `zsd_profile` set via `MANIFEST.MF` (`maven-war-plugin` configuration)

---

## Platform Requirements

**Development:**
- JDK 8
- Maven 3.x
- Node.js 0.10+ (client build only)
- npm + Bower + Grunt CLI
- Docker (optional, for the MySQL container via docker-compose)
- WildFly 11.0.0 (application server)
- Liquibase CLI (database migrations via `configS.bat`)

**Production:**
- WildFly application server (WAR deployment)
- MySQL 5.7
- JNDI configuration (`java:/PublicServer/<AppName>/...`) provisioned in WildFly: mail, general, iTender and secrets (see INTEGRATIONS.md)

---

*Stack analysis: 2026-10-16*
