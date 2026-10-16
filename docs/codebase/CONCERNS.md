# Codebase Concerns

**Analysis Date:** 2026-10-16

---

## EOL / Deprecated Frameworks & Build Tooling

### AngularJS 1.x (End of Life)

- **Severity:** HIGH
- **Issue:** The entire frontend is built on AngularJS 1.5.11 (confirmed via `publicERANET-client/app/bower_components/angular/angular.js` header). AngularJS reached end-of-life in December 2021. No security patches, no browser-compatibility fixes, and no community support will be issued.
- **Files:** `publicERANET-client/bower.json` (`"angular": "~1.5.5"`), all of `publicERANET-client/app/scripts/`
- **Impact:** Any future browser security changes or JavaScript engine updates may silently break the application. CVEs discovered in AngularJS will not be patched upstream.
- **Fix approach:** Full migration to Angular 2+ (or React/Vue). This is a multi-sprint effort requiring a complete rewrite of the 608-file JS codebase (347 controllers) under `publicERANET-client/app/scripts/`.

### Bower (Deprecated)

- **Severity:** HIGH
- **Issue:** Bower was officially deprecated in 2017. It is no longer maintained, its registry may go offline, and new packages are not published to it. The project uses `publicERANET-client/bower.json` exclusively for frontend dependency management.
- **Files:** `publicERANET-client/bower.json`, `publicERANET-client/Gruntfile.js` (task: `bowerInstall`)
- **Impact:** Dependency resolution at install time may fail or produce inconsistent results. Security auditing (e.g., `npm audit` equivalent) is not available for Bower packages.
- **Additional concern:** `publicERANET-client/app/bower_components/` is excluded by `.gitignore` and untracked, so the installed set drifts per machine (the local copy predates `bower.json` and lacks `iframe-resizer` and `angular-cookies`). The libraries that *are* committed live under `app/scripts.no.min/` and `app/scripts/plugin/` — including CKEditor 4.6.2 (superseded by 4 LTS), jQuery and select2 — which makes their upgrades invisible.
- **Fix approach:** Migrate to npm/yarn; remove `bower_components` from repo and restore via `.gitignore`; consolidate vendored assets.

### Grunt 0.4.x (Legacy)

- **Severity:** MEDIUM
- **Issue:** Grunt 0.4.1 (specified in `publicERANET-client/package.json`) was released in 2013. The plugin ecosystem (grunt-contrib-* series) has not been actively maintained for years. Many of the associated plugins are also frozen at circa-2013 versions.
- **Files:** `publicERANET-client/package.json`, `publicERANET-client/Gruntfile.js`
- **Specific old plugins:** `grunt-ngmin ~0.0.2`, `grunt-rev ~0.1.0`, `grunt-bower-install ^1.5.0`, `grunt-autoprefixer ~0.4.0` — all abandoned.
- **Impact:** The build pipeline cannot be updated incrementally. The Gruntfile was scaffolded on 2015-03-26 (`// Generated on 2015-03-26 using generator-angular 0.8.0`) and has not been modernised.
- **Fix approach:** Migrate build pipeline to Webpack or Vite when migrating off AngularJS.

### Karma / ng-scenario (Obsolete Test Runner)

- **Severity:** MEDIUM
- **Issue:** `karma ~0.12.31` and `karma-ng-scenario ~0.1.0` are used for client-side tests. `ng-scenario` was the original AngularJS e2e runner and was replaced by Protractor (itself now deprecated) and later Cypress. Only one test controller file exists: `publicERANET-client/test/spec/controllers/main.js`.
- **Files:** `publicERANET-client/karma.conf.js`, `publicERANET-client/karma-e2e.conf.js`, `publicERANET-client/package.json`
- **Impact:** Effectively no functioning automated tests for the frontend. The single test file is a yeoman-generated stub.

---

## Security Concerns

### Hardcoded Keystore Passwords in Source Code

- **Severity:** HIGH (CRITICAL)
- **Issue:** The SAML signing credential initialisation hardcodes both the keystore password and the private key alias password directly in Java source code.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` lines 945–946 (the `password` and `ksPassword` locals in `intializeCredentials()`; the literal values are deliberately not repeated here)
- **Impact:** Any developer with repository access has the keystore and private key passwords. Earlier revisions of this document quoted the values verbatim, so they also remain in git history — treat them as exposed. Rotating credentials requires a code change and redeployment. The associated keystore files (`prod.jks`, `alice2.jks`) are also committed to the repository at `publicERANET-server/src/main/resources/META-INF/`.
- **Fix approach:** Move both passwords to JNDI resources or environment variables. Remove all `.jks` files from the repository and serve them from a secrets vault or application server configuration.

### Production Keystore Files Committed to Repository

- **Severity:** HIGH (CRITICAL)
- **Issue:** Multiple Java KeyStore (`.jks`) files are committed: `prod.jks`, `alice2.jks`, `xecm.jks` and `xemc-test.jks` under `publicERANET-server/src/main/resources/META-INF/`, plus `alice.jks`, `alice2.jks` and `prod.jks` under `publicERANET-server/src/main/webapp/WEB-INF/`. The SAML ones contain private keys used for signing (`SAMLClient` loads `META-INF/alice2.jks`); the Aspose license file is tracked in both locations as well.
- **Files:** `publicERANET-server/src/main/resources/META-INF/prod.jks`, `publicERANET-server/src/main/resources/META-INF/alice2.jks`, `publicERANET-server/src/main/webapp/WEB-INF/*.jks`
- **Impact:** Private keys for SAML identity federation (eID/UPVS) are stored in version control. Anyone who clones the repo can impersonate the service provider in SAML assertions.
- **Fix approach:** Immediately rotate SAML signing certificates, remove keystores from git history (`git filter-repo` or BFG), and inject keystore paths/passwords via server configuration at deploy time.

### Database Password in `configS.bat`

- **Severity:** HIGH
- **Issue:** `configS.bat` (project root) contains a Liquibase migration command with the database root password in plaintext in the `--password` flag; the rollback script `configR.bat` carries the same flag.
- **File:** `C:\Innovis\zsd-wildfly\configS.bat`
- **Impact:** The database root password is stored in a committed script. It is also used with `&ssl=false`, disabling TLS for the MySQL connection.
- **Fix approach:** Use a Liquibase `.properties` file (excluded from version control) or environment variable substitution. Enable SSL/TLS on the MySQL connection.

### Hardcoded Database Credentials in GlassFish Resources

- **Severity:** HIGH
- **Issue:** `glassfish-resources.xml` contains the database username and password in plaintext.
- **File:** `publicERANET-server/src/main/setup/glassfish-resources.xml` lines 7–9
  ```xml
  <property name="User"     value="public"/>
  <property name="Password" value="public"/>
  <property name="URL"      value="jdbc:mysql://localhost/public?user=public&amp;password=public"/>
  ```
- **Impact:** Default/trivial credentials. Any developer or process reading this file gains database access.
- **Fix approach:** Use GlassFish JNDI credential aliases or environment variable substitution; remove credentials from committed XML.

### Docker Compose Exposes Plaintext Passwords

- **Severity:** MEDIUM
- **Issue:** `docker-compose.yml` sets MySQL and Jackrabbit database passwords to the literal string `secret` for both `MYSQL_PASSWORD` and `MYSQL_ROOT_PASSWORD`.
- **File:** `publicERANET-server/docker-compose.yml` lines 16–17, 32–33
- **Impact:** Development environments with these defaults may be reused or cloned to staging/production. The `.env.example` file does not override these values.
- **Fix approach:** Move database passwords to `.env` (already gitignored per `publicERANET-server/.gitignore`); reference `${MYSQL_PASSWORD}` in docker-compose; document required variables in `.env.example`.

### Bearer-Token Role Checks Are Method-Level Only

- **Severity:** HIGH
- **Issue:** `BearerFilter` reads `@ProcurerRoleAllowed`, `@SupplierRoleAllowed` and `@AdministratorRoleAllowed` only from the resource **method** (`method.isAnnotationPresent(...)`). Class-level role annotations (for example `@ProcurerRoleAllowed` on `MessageService`) are never evaluated; only class-level `@OauthSecured` is. The custom `SecurityContext` it installs also returns `true` from `isUserInRole`, so any JAX-RS `isUserInRole` check always passes; `@RolesAllowed` is used by only three services.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/filter/BearerFilter.java`
- **Impact:** An endpoint relying on a class-level role annotation is reachable by any valid token. Always put the role annotation on each method.
- **Fix approach:** Resolve role annotations from the class as well as the method, and make `isUserInRole` reflect the token roles.

### No HTTPS Enforcement or Session Hardening in `web.xml`

- **Severity:** MEDIUM
- **Issue:** `web.xml` has a `<security-constraint>` listing roles but no `<web-resource-collection>`/`<url-pattern>`, no `<transport-guarantee>`, no `<login-config>` and no `<session-config>`. HTTPS is enforced only by external infrastructure; the server itself keeps no HTTP session state and relies on the JWT bearer token.
- **File:** `publicERANET-server/src/main/webapp/WEB-INF/web.xml`
- **Fix approach:** Enforce TLS at the reverse proxy or add a proper constraint with `CONFIDENTIAL`; remove the unused security constraint and the stray `FacesServlet` mapping and `javax.faces.CONFIG_FILES` parameter.

### SAML Library (OpenSAML 2.6.4) End of Life

- **Severity:** HIGH
- **Issue:** `opensaml` 2.6.4 (released ~2014) is the version used for SAML processing. OpenSAML 2.x reached end-of-life in 2016; the current stable is 4.x. The `java-saml` wrapper is at 2.2.0 (current is 3.x). Both libraries have known vulnerabilities (XML signature wrapping, XXE).
- **Files:** `publicERANET-server/pom.xml` lines 49–58
- **Fix approach:** Upgrade to `opensaml` 4.x and `java-saml-core` 3.x; the API is not backward-compatible — the `SAMLClient.java` implementation must be rewritten.

---

## Outdated / Vulnerable Java Dependencies

### jackson-databind 2.4.0

- **Severity:** HIGH
- **Issue:** `jackson-databind` 2.4.0 (2014) has numerous known critical CVEs including polymorphic deserialization RCE vulnerabilities: CVE-2019-14379, CVE-2020-8840, CVE-2020-9547, CVE-2020-9548, and others (collectively known as the "gadget chain" series).
- **File:** `publicERANET-server/pom.xml` line 140
- **Fix approach:** Upgrade to 2.17.x or later. Also note a second Jackson dependency via `jackson-jaxrs-json-provider 2.3.2` (`jackson-jaxrs-json-provider`, `provided` scope).

### commons-beanutils 1.9.2

- **Severity:** HIGH
- **Issue:** Known CVE-2019-10086 (ClassLoader manipulation). Upgrade to 1.9.4+.
- **File:** `publicERANET-server/pom.xml` line 94

### commons-io 2.4

- **Severity:** MEDIUM
- **Issue:** Version from 2012. Current is 2.16+. Several older utility method behaviors differ from modern expectations.
- **File:** `publicERANET-server/pom.xml` line 99

### Apache HttpClient 4.3.1

- **Severity:** MEDIUM
- **Issue:** CVE-2020-13956 (improper handling of malformed authority component). Upgrade to 4.5.14+.
- **File:** `publicERANET-server/pom.xml` line 134

### Guava 18.0

- **Severity:** MEDIUM
- **Issue:** CVE-2023-2976 (temp directory creation insecure on Unix). Upgrade to 32.0+.
- **File:** `publicERANET-server/pom.xml` line 145

### Spring Beans 2.5.6.SEC03

- **Severity:** HIGH
- **Issue:** Spring 2.5.6 (2010). This is a security backport release that itself is many years out of support. Spring Framework 2.x does not receive any patches. Spring4Shell (CVE-2022-22965) affects Spring 5.x — 2.x is simply abandoned with no fix path.
- **File:** `publicERANET-server/pom.xml` line 104
- **Fix approach:** Upgrade the Spring dependency to 6.x (requires Java 17 migration) or eliminate it entirely.

### RESTEasy 2.2.1.GA

- **Severity:** MEDIUM
- **Issue:** RESTEasy 2.2.1 is from 2011. Current stable is 6.x. No security patches are available for 2.x.
- **File:** `publicERANET-server/pom.xml` lines 70–80 (`provided` scope)

### Auth0 java-jwt 3.3.0

- **Severity:** MEDIUM
- **Issue:** CVE-2022-23529 (improper validation allowing header injection). Upgrade to 4.3.0+.
- **File:** `publicERANET-server/pom.xml` line 250 (used only to verify HS256 tokens in `BearerFilter`)

### MySQL 5.7 in Docker

- **Severity:** MEDIUM
- **Issue:** MySQL 5.7 reached end of life in October 2023. No security patches will be released. Used in `docker-compose.yml`.
- **File:** `publicERANET-server/docker-compose.yml` lines 7, 23
- **Fix approach:** Upgrade to MySQL 8.0 or later; note `collation-server=utf8mb4_slovak_ci` must be remapped as collation names changed in 8.0.

### Java 8 (Source/Target)

- **Severity:** MEDIUM
- **Issue:** `pom.xml` targets Java 1.8 (`<source>1.8</source>`, `<target>1.8</target>`). Java 8 reached Oracle end-of-life for public updates in 2019. While OpenJDK 8 still receives some updates, many dependencies (Spring 6, OpenSAML 4) require Java 17+.
- **File:** `publicERANET-server/pom.xml` lines 15, 322–323

---

## Technical Debt

### God-Class Service Files

- **Severity:** HIGH
- **Issue:** Several service classes are extremely large, combining REST endpoint definition, business logic, validation, and data access in a single file. This makes them hard to test, maintain, or modify safely.
- **Files and sizes:**
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ProcurementService.java` — 7,079 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java` — 6,439 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/CompanyInProcurementService.java` — 4,857 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/pdf/ProcurementAllPdfGeneratingService.java` — 5,171 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ParticipantConditionInProcurementService.java` — 3,151 lines
- **Impact:** High cyclomatic complexity, zero automated tests, fragile to any change.
- **Fix approach:** Extract business logic into dedicated domain service classes; separate REST layer from business logic layer; introduce unit tests incrementally.

### Large AngularJS Controller Files

- **Severity:** MEDIUM
- **Issue:** Several frontend controller files are 750–1,950 lines, violating single-responsibility.
- **Files:**
  - `publicERANET-client/app/scripts/controllers/communication/communication.js` — 1,562 lines
  - `publicERANET-client/app/scripts/controllers/procurement/preparationPhase/procurementDefinition/generalInformation.js` — 1,019 lines
  - `publicERANET-client/app/scripts/controllers/planning/editInternalRequest/editInternalRequestBase.js` — 766 lines
  - `publicERANET-client/app/scripts/app.js` — 1,945 lines (SmartAdmin jQuery shell; routes live in `ng.app.js`)

### Statistics Service Uses String-Concatenated SQL

- **Severity:** MEDIUM
- **Issue:** `StatisticsService.java` builds SQL queries by string concatenation using a `StringBuilder`, including dynamically inserting integer ID lists (sourced from other queries). While the IDs appear to be typed integers from JPA results (reducing injection risk), the approach bypasses `PreparedStatement` parameterization entirely for these queries.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/StatisticsService.java` lines 1618–1626 (the `#` placeholder replacement; raw `Statement`/`StringBuilder` queries sit around lines 837–1122)
- **Secondary:** 40 `setSqlQuery()` calls (about 75 `IN (#)` templates) across `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/statistics/` classes each contain a hardcoded native SQL template with `IN (#)` that gets string-replaced at runtime.
- **Fix approach:** Validate that all `#` substitution values are provably integer-typed before execution; alternatively convert to `PreparedStatement` with `setInt()`.

### Aspose Libraries as In-Project JARs

- **Severity:** MEDIUM
- **Issue:** Four Aspose commercial JARs (`aspose-words-16.3.0`, `aspose-pdf-10.6.2`, `aspose-email-5.9.0`, `aspose-cells-8.5.2`) are stored in `publicERANET-server/lib/` and installed via a local file-system Maven repository (`<url>file://${project.basedir}/lib</url>`). These are ~decade-old versions.
- **Files:** `publicERANET-server/lib/com/aspose/`, `publicERANET-server/pom.xml` lines 18–23, 223–246
- **Impact:** No automated security patching. License file is committed to resources at `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic`. Old Aspose versions have known bugs with newer PDF/DOCX formats.
- **Fix approach:** Use Aspose's official Maven repository or upgrade to current versions.

### `System.out.println` in SOAP Handler

- **Severity:** LOW
- **Issue:** `LoggingHandler.java` logs all inbound and outbound SOAP messages to `System.out` using `System.out.println`. This is a debug artifact left in production code. SOAP messages may contain sensitive data.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/proebiz/LoggingHandler.java` lines 27–46 (the `System.out.println` calls)
- **Fix approach:** Replace `System.out.println` with `logger.debug()`; gate behind a feature flag or remove entirely.

### `e.printStackTrace()` in Production Code

- **Severity:** LOW
- **Issue:** 13 occurrences of `e.printStackTrace()` in production Java code, most critically in `SAMLClient.java`'s `intializeCredentials()` method — meaning a keystore load failure (null `signingCredential`) will silently cause NPEs in SAML operations.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` line 968, plus `ws/PingEndpoint.java`, `ws/RealTimeEndpoint.java`, `filter/BearerFilter.java`, `service/UndeliveredEmailNotificationSchedulerService.java`, `service/FileService.java`, `service/CompanyProposalHashService.java` and `service/jms/BaseJmsService.java` (all under `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/`)
- **Fix approach:** Replace with proper logger error calls and rethrow or fail-fast.

### Swallowed Exceptions

- **Severity:** LOW
- **Issue:** A few catch blocks swallow exceptions silently, for example the `NumberFormatException` handler in `ProcurementDao.java` (line 206), which just sets the value to null; `BaseDao.create()` logs and swallows a `ConstraintViolationException` and then flushes.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/ProcurementDao.java`, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`
- **Fix approach:** At minimum log the exception; preferably rethrow as a typed application exception.

### `persistence.xml` Has Drifted From the Entity Classes

- **Severity:** LOW
- **Issue:** `persistence.xml` lists 188 classes, with duplicates (e.g. `Procurement`, `SystemUser`), four entries whose class does not exist (`OwnerCompany`, `ProcurementItemYearAmount`, `EvaluationDocument`, `ZsePublicListRecord`) and five that are not entities (e.g. `PublicListRecord`, `ProcurementList`). Two `@Entity` classes are unlisted (`CompanyInQualificationSystemCompletition`, `SyncRoles`); that is tolerated because `exclude-unlisted-classes` is false.
- **File:** `publicERANET-server/src/main/resources/META-INF/persistence.xml`
- **Fix approach:** Clean the list when touching entities; always register new entities explicitly.

### Proebiz WSDL Path Needs Verification

- **Severity:** LOW
- **Issue:** `ProebizService.getPort()` loads `META-INF/proebiz_schema.wsdl` from the classpath, but the WSDL sits in `publicERANET-server/src/main/webapp/WEB-INF/`, not in `src/main/resources/META-INF/`. It may fail to resolve if Proebiz auctions are used.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ProebizService.java` line 957

---

## TODO / FIXME Markers

### Unresolved Business Logic (UvoService)

- **Severity:** MEDIUM
- **Issue:** Three TODO comments in `UvoService.java` reference an unimplemented feature: sending an identifier for a dropdown field controlling qualification conditions.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java` lines 3082, 3326, 3333
  ```java
  // TODO: po novom musím poslať identifikator rozbaľovacieho poľa...
  ```

### LoggingHandler Unhandled Exception

- **Severity:** LOW
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/proebiz/LoggingHandler.java` lines 36, 48
  ```java
  // TODO: What do I have to do in this case?
  ```

### Stale Frontend Functions

- **Severity:** LOW
- **File:** `publicERANET-client/app/scripts/app.js` line 557
  ```javascript
  // TODO: delete this function later on - no longer needed (?)
  ```

---

## Test Coverage Gaps

### No Java Unit or Integration Tests

- **What's not tested:** Nearly the entire `publicERANET-server` backend — 835 Java source files, all REST endpoints, all business logic.
- **Files:** `publicERANET-server/src/test/java/test/TestWs.java` is the only test class (JUnit 4.6; one JAXB serialization smoke test).
- **Risk:** Any refactoring, dependency upgrade, or bug fix has no automated regression safety net.
- **Priority:** HIGH

### Frontend Tests Are a Stub

- **What's not tested:** All 347 AngularJS controller files, all services, all directives.
- **Files:** Only `publicERANET-client/test/spec/controllers/main.js` exists (yeoman scaffold boilerplate).
- **Risk:** UI regressions are undetectable programmatically.
- **Priority:** MEDIUM

---

## Fragile Areas

### SAML Authentication (`SAMLClient.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` (971 lines)
- **Why fragile:** Uses EOL `opensaml 2.6.4`, hardcoded keystore passwords, `e.printStackTrace()` on credential failure (which leaves `signingCredential` null and causes NPE on first SAML operation), and repeated `intializeCredentials()` calls (lines 162, 442, 517, 580) rather than singleton initialization.
- **Safe modification:** Any change must be tested against a live or mocked SAML IdP. Verify SAML SSO and SLO flows end-to-end after any modification.

### Statistics SQL Engine (`StatisticsService.java`, `StatisticsField.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/StatisticsService.java`, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/statistics/` (62 native SQL query classes)
- **Why fragile:** Hand-built SQL query construction using `StringBuilder` with filter chaining and string-replaced `IN (#)` ID lists. Any change to filter logic risks breaking query structure. No tests exist.
- **Safe modification:** Only modify one filter path at a time; test with the full statistics export UI after every change.
- **Two render paths — Excel ≠ on-screen.** The Excel export is server-rendered (`getFormattedValue` / `codebookService.translate` in `StatisticsService`), but the on-screen report is **client-rendered**: header from the `statisticsField` codebook (`codebookGenerator.js`), value from a `filters[identificator]` codebook filter (`showStatisticsList.js`). A new codebook statistics attribute needs the server `StatisticsField` **and** three client additions (`constants.js` identificator, `codebookGenerator.js` `statisticsField` header entry, `showStatisticsList.js` value filter) — otherwise Excel is correct while the browser report shows raw codes and a blank column header.

### File Binary Storage in MySQL (`FileDao.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/FileDao.java`
- **Why fragile:** Binary file data is stored as BLOBs directly in MySQL (`SELECT data FROM file WHERE id = ?`). Large file uploads will cause memory pressure. The DAO uses `PreparedStatement` with `?` placeholders correctly (no injection risk), but the pattern does not scale.
- **Test coverage:** None.

### `ServerSettings` global cache is app-wide — don't invalidate it for a local need

- **Files:** `publicERANET-client/app/scripts/service/resources/serverSettings.js`
- **Why fragile:** `ServerSettings` loads all settings once and caches them (`loaded` flag); many feature areas read that shared cache lazily. Forcing a full reload (resetting `loaded` and re-querying) makes unrelated screens re-fetch their dependent data (current rating, harmonogram, users, codebooks) — a visible cascade.
- **Safe modification:** never reset the global cache for a localized refresh. If one setting must be read fresh, issue a single targeted `setting/query` instead of re-loading everything.

---

## Performance Notes

### Binary File Storage in Database

- **Severity:** MEDIUM
- **Problem:** All file attachments are stored as MySQL BLOBs in the `file` table. At scale this severely impacts database size, backup time, and memory consumption when streaming large files.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/FileDao.java`
- **Improvement path:** Migrate to filesystem or object storage (S3-compatible); store only file metadata in the DB.

### No Frontend Build Minification in Development

- **Severity:** LOW
- **Problem:** The `app/scripts/` directory contains 608 unminified JavaScript files loaded individually in development. The bundled build (`dist/`) would be needed for production performance, but the Grunt build tooling is frozen at 2013 vintage.

---

## Missing Critical Features

### No HTTPS Enforcement

- **Problem:** `web.xml` declares no `transport-guarantee`. The application relies entirely on external infrastructure (reverse proxy) to enforce HTTPS; without a TLS proxy all traffic, including bearer tokens, is unencrypted.

### No CORS Configuration

- **Problem:** No CORS headers are configured anywhere in the Java backend; the existing JAX-RS filters (`BearerFilter`, `JWTAuthFilter`, `ResponseFilter`) set none. The application may only be functional when the frontend and backend share the same origin.
- **Risk:** Prevents multi-origin deployment without infrastructure-level CORS handling.

---

## Dependencies at Risk

| Package | Current Version | Risk | Impact |
|---------|----------------|------|--------|
| `opensaml` | 2.6.4 | EOL since 2016 | SAML auth completely unpatched |
| `java-saml` | 2.2.0 | EOL, CVEs known | SAML parsing vulnerabilities |
| `jackson-databind` | 2.4.0 | Multiple critical CVEs | Potential RCE via deserialization |
| `spring-beans` | 2.5.6.SEC03 | EOL since 2013 | No patches; Spring4Shell unaddressed |
| `resteasy-jaxrs` | 2.2.1.GA | EOL | REST layer unpatched |
| `commons-beanutils` | 1.9.2 | CVE-2019-10086 | ClassLoader manipulation |
| `httpclient` | 4.3.1 | CVE-2020-13956 | HTTP request hijacking |
| `guava` | 18.0 | CVE-2023-2976 | Insecure temp file creation |
| `com.auth0:java-jwt` | 3.3.0 | CVE-2022-23529 | JWT header injection |
| MySQL | 5.7 (Docker) | EOL Oct 2023 | No DB security patches |
| AngularJS | 1.5.11 | EOL Dec 2021 | No frontend security patches |
| CKEditor (scripts.no.min) | 4.6.2 | Superseded by 4 LTS | Known XSS vulnerabilities in old builds |

---

## Persistence / Search Caveats

### `Message.body` is a `@Lob byte[]` over a binary column

`Message.body` is mapped as `@Lob byte[]` (serialized with `ByteArraySerializer`/`ByteArrayDeserializer`); there is no JPA `AttributeConverter` in this checkout. If text search over it is ever added, note:

1. **`LOWER()`/`LIKE` on a MySQL `BLOB` is case-sensitive** (binary); case-insensitive search needs a character column such as `LONGTEXT`.
2. **`@Lob byte[]` does not map a `LONGTEXT` column** — EclipseLink reads it as `String` and throws `ConversionException`, so an `AttributeConverter<byte[], String>` would be needed, and a new `@Converter` class must be listed in `persistence.xml` (this PU enumerates every managed class).
3. **`BLOB → LONGTEXT` relabels the existing bytes without transcoding** — pin the charset (`CHARACTER SET utf8mb4`) in the Liquibase change; `modifyDataType` cannot express it, so use a `<sql>` change with a `<rollback>`.

---

## Server Dependency Caveats

### Third-party JARs must load on Java 8 / WildFly, not just compile

A WAR can build on Java 8 yet fail at class-load if a dependency contains Java 9+ bytecode.
JBoss Modules eagerly links classes, so a Java-10 class on the classpath throws
`UnsupportedClassVersionError` (class file 54.0 vs 52.0) at runtime even if never called.
Verify new deps by loading them under JDK 8, not just `mvn clean package`.

- The pom pins old libraries (Guava 18.0 and others); check transitive dependencies of anything new against the pins before adding it.

---

*Concerns audit: 2026-10-16*
