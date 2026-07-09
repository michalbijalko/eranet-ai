# Codebase Concerns

**Analysis Date:** 2026-06-03

---

## EOL / Deprecated Frameworks & Build Tooling

### AngularJS 1.x (End of Life)

- **Severity:** HIGH
- **Issue:** The entire frontend is built on AngularJS 1.5.11 (confirmed via `publicERANET-client/app/bower_components/angular/angular.js` header). AngularJS reached end-of-life in December 2021. No security patches, no browser-compatibility fixes, and no community support will be issued.
- **Files:** `publicERANET-client/bower.json` (`"angular": "~1.5.5"`), all of `publicERANET-client/app/scripts/`
- **Impact:** Any future browser security changes or JavaScript engine updates may silently break the application. CVEs discovered in AngularJS will not be patched upstream.
- **Fix approach:** Full migration to Angular 2+ (or React/Vue). This is a multi-sprint effort requiring a complete rewrite of the 679-file JS codebase under `publicERANET-client/app/scripts/`.

### Bower (Deprecated)

- **Severity:** HIGH
- **Issue:** Bower was officially deprecated in 2017. It is no longer maintained, its registry may go offline, and new packages are not published to it. The project uses `publicERANET-client/bower.json` exclusively for frontend dependency management.
- **Files:** `publicERANET-client/bower.json`, `publicERANET-client/Gruntfile.js` (task: `bowerInstall`)
- **Impact:** Dependency resolution at install time may fail or produce inconsistent results. Security auditing (e.g., `npm audit` equivalent) is not available for Bower packages.
- **Additional concern:** `publicERANET-client/app/bower_components/` is present in the repository despite being listed in `.gitignore` (line 5 of `publicERANET-client/.gitignore`). This means ~55 vendored frontend libraries — including CKEditor 4.6.2 (superseded by 4 LTS), jQuery, Bootstrap 3, etc. — are committed to version control, inflating repo size and making upgrades invisible.
- **Fix approach:** Migrate to npm/yarn; remove `bower_components` from repo and restore via `.gitignore`; consolidate vendored assets.

### Grunt 0.4.x (Legacy)

- **Severity:** MEDIUM
- **Issue:** Grunt 0.4.1 (specified in `publicERANET-client/package.json`) was released in 2013. The plugin ecosystem (grunt-contrib-* series) has not been actively maintained for years. Many of the associated plugins are also frozen at circa-2013 versions.
- **Files:** `publicERANET-client/package.json`, `publicERANET-client/Gruntfile.js`
- **Specific old plugins:** `grunt-ngmin ~0.0.2`, `grunt-rev ~0.1.0`, `grunt-bower-install ~1.0.0`, `grunt-autoprefixer ~0.4.0` — all abandoned.
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
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` lines 945–946
  ```java
  char[] keystorePass = "jNTYEYEVYUJM0eanM2xV".toCharArray();
  char[] aliasPass    = "yz?dw\"XU%.bG8%;%:LGB".toCharArray();
  ```
- **Impact:** Any developer with repository access has the keystore and private key passwords. Rotating credentials requires a code change and redeployment. The associated keystore files (`prod.jks`, `alice2.jks`) are also committed to the repository at `publicERANET-server/src/main/resources/META-INF/`.
- **Fix approach:** Move both passwords to JNDI resources or environment variables. Remove all `.jks` files from the repository and serve them from a secrets vault or application server configuration.

### Production Keystore Files Committed to Repository

- **Severity:** HIGH (CRITICAL)
- **Issue:** Multiple Java KeyStore (`.jks`) files are committed under `publicERANET-server/src/main/resources/META-INF/`: `prod.jks` and `alice2.jks`. A third file `alice.jks` is present at `publicERANET-server/src/main/webapp/WEB-INF/alice.jks`. These contain private keys used for SAML signing.
- **Files:** `publicERANET-server/src/main/resources/META-INF/prod.jks`, `publicERANET-server/src/main/resources/META-INF/alice2.jks`, `publicERANET-server/src/main/webapp/WEB-INF/alice.jks`
- **Impact:** Private keys for SAML identity federation (eID/UPVS) are stored in version control. Anyone who clones the repo can impersonate the service provider in SAML assertions.
- **Fix approach:** Immediately rotate SAML signing certificates, remove keystores from git history (`git filter-repo` or BFG), and inject keystore paths/passwords via server configuration at deploy time.

### Database Password in `configS.bat`

- **Severity:** HIGH
- **Issue:** `configS.bat` (project root) contains a Liquibase migration command with the database root password in plaintext in the `--password` flag.
- **File:** `C:\Innovis\vse\configS.bat`
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

### Transport Guarantee Set to NONE (No HTTPS Enforcement)

- **Severity:** HIGH
- **Issue:** `web.xml` explicitly sets `<transport-guarantee>NONE</transport-guarantee>` for the security constraint protecting `/webresources/sc/*`. This means the container will not redirect HTTP to HTTPS, and sensitive data (including session cookies) can be transmitted in cleartext if the front-end proxy is misconfigured.
- **File:** `publicERANET-server/src/main/webapp/WEB-INF/web.xml` line 25
- **Fix approach:** Change to `<transport-guarantee>CONFIDENTIAL</transport-guarantee>` and ensure TLS termination is handled at the application server or reverse proxy layer.

### Session Cookie Not Marked Secure or HttpOnly

- **Severity:** MEDIUM
- **Issue:** `web.xml` renames the session cookie to `SESSIONID` but does not set `<secure>true</secure>` or `<http-only>true</http-only>` on the cookie configuration.
- **File:** `publicERANET-server/src/main/webapp/WEB-INF/web.xml` lines 6–8
- **Fix approach:** Add `<secure>true</secure>` and `<http-only>true</http-only>` inside `<cookie-config>`.

### SAML Library (OpenSAML 2.6.4) End of Life

- **Severity:** HIGH
- **Issue:** `opensaml` 2.6.4 (released ~2014) is the version used for SAML processing. OpenSAML 2.x reached end-of-life in 2016; the current stable is 4.x. The `java-saml` wrapper is at 2.2.0 (current is 3.x). Both libraries have known vulnerabilities (XML signature wrapping, XXE).
- **Files:** `publicERANET-server/pom.xml` lines 56–59, 52–54
- **Fix approach:** Upgrade to `opensaml` 4.x and `java-saml-core` 3.x; the API is not backward-compatible — the `SAMLClient.java` implementation must be rewritten.

---

## Outdated / Vulnerable Java Dependencies

### jackson-databind 2.4.0

- **Severity:** HIGH
- **Issue:** `jackson-databind` 2.4.0 (2014) has numerous known critical CVEs including polymorphic deserialization RCE vulnerabilities: CVE-2019-14379, CVE-2020-8840, CVE-2020-9547, CVE-2020-9548, and others (collectively known as the "gadget chain" series).
- **File:** `publicERANET-server/pom.xml` line 141
- **Fix approach:** Upgrade to 2.17.x or later. Also note a second Jackson dependency via `jackson-jaxrs-json-provider 2.3.2` (pom.xml line 84).

### commons-beanutils 1.9.2

- **Severity:** HIGH
- **Issue:** Known CVE-2019-10086 (ClassLoader manipulation). Upgrade to 1.9.4+.
- **File:** `publicERANET-server/pom.xml` line 95

### commons-io 2.4

- **Severity:** MEDIUM
- **Issue:** Version from 2012. Current is 2.16+. Several older utility method behaviors differ from modern expectations.
- **File:** `publicERANET-server/pom.xml` line 99

### Apache HttpClient 4.3.1

- **Severity:** MEDIUM
- **Issue:** CVE-2020-13956 (improper handling of malformed authority component). Upgrade to 4.5.14+.
- **File:** `publicERANET-server/pom.xml` line 133

### Guava 18.0

- **Severity:** MEDIUM
- **Issue:** CVE-2023-2976 (temp directory creation insecure on Unix). Upgrade to 32.0+.
- **File:** `publicERANET-server/pom.xml` line 145

### Spring Beans 2.5.6.SEC03

- **Severity:** HIGH
- **Issue:** Spring 2.5.6 (2010). This is a security backport release that itself is many years out of support. Spring Framework 2.x does not receive any patches. Spring4Shell (CVE-2022-22965) affects Spring 5.x — 2.x is simply abandoned with no fix path.
- **File:** `publicERANET-server/pom.xml` line 103
- **Fix approach:** Upgrade the Spring dependency to 6.x (requires Java 17 migration) or eliminate it entirely.

### RESTEasy 2.2.1.GA

- **Severity:** MEDIUM
- **Issue:** RESTEasy 2.2.1 is from 2011. Current stable is 6.x. No security patches are available for 2.x.
- **File:** `publicERANET-server/pom.xml` lines 72–80

### Auth0 java-jwt 3.3.0

- **Severity:** MEDIUM
- **Issue:** CVE-2022-23529 (improper validation allowing header injection). Upgrade to 4.3.0+.
- **File:** `publicERANET-server/pom.xml` line 243

### MySQL 5.7 in Docker

- **Severity:** MEDIUM
- **Issue:** MySQL 5.7 reached end of life in October 2023. No security patches will be released. Used in `docker-compose.yml`.
- **File:** `publicERANET-server/docker-compose.yml` lines 6, 22
- **Fix approach:** Upgrade to MySQL 8.0 or later; note `collation-server=utf8mb4_slovak_ci` must be remapped as collation names changed in 8.0.

### Java 8 (Source/Target)

- **Severity:** MEDIUM
- **Issue:** `pom.xml` targets Java 1.8 (`<source>1.8</source>`, `<target>1.8</target>`). Java 8 reached Oracle end-of-life for public updates in 2019. While OpenJDK 8 still receives some updates, many dependencies (Spring 6, OpenSAML 4) require Java 17+.
- **File:** `publicERANET-server/pom.xml` lines 15, 270–271

---

## Technical Debt

### God-Class Service Files

- **Severity:** HIGH
- **Issue:** Several service classes are extremely large, combining REST endpoint definition, business logic, validation, and data access in a single file. This makes them hard to test, maintain, or modify safely.
- **Files and sizes:**
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ProcurementService.java` — 9,596 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java` — 6,431 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/CompanyInProcurementService.java` — 5,369 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/pdf/ProcurementAllPdfGeneratingService.java` — 4,879 lines
  - `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ParticipantConditionInProcurementService.java` — 4,706 lines
- **Impact:** High cyclomatic complexity, zero automated tests, fragile to any change.
- **Fix approach:** Extract business logic into dedicated domain service classes; separate REST layer from business logic layer; introduce unit tests incrementally.

### Large AngularJS Controller Files

- **Severity:** MEDIUM
- **Issue:** Several frontend controller files are 600–1,626 lines, violating single-responsibility.
- **Files:**
  - `publicERANET-client/app/scripts/controllers/communication/communication.js` — 1,626 lines
  - `publicERANET-client/app/scripts/controllers/procurement/preparationPhase/procurementDefinition/generalInformation.js` — 1,281 lines
  - `publicERANET-client/app/scripts/controllers/planning/editInternalRequest/editInternalRequestBase.js` — 1,246 lines
  - `publicERANET-client/app/scripts/app.js` — 1,881 lines (routing + module config)

### Statistics Service Uses String-Concatenated SQL

- **Severity:** MEDIUM
- **Issue:** `StatisticsService.java` builds SQL queries by string concatenation using a `StringBuilder`, including dynamically inserting integer ID lists (sourced from other queries). While the IDs appear to be typed integers from JPA results (reducing injection risk), the approach bypasses `PreparedStatement` parameterization entirely for these queries.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/StatisticsService.java` lines 1352–1372
- **Secondary:** 124 `setSqlQuery()` calls across `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/statistics/` classes each contain a hardcoded native SQL template with `IN (#)` that gets string-replaced at runtime.
- **Fix approach:** Validate that all `#` substitution values are provably integer-typed before execution; alternatively convert to `PreparedStatement` with `setInt()`.

### Aspose Libraries as In-Project JARs

- **Severity:** MEDIUM
- **Issue:** Four Aspose commercial JARs (`aspose-words-16.3.0`, `aspose-pdf-10.6.2`, `aspose-email-5.9.0`, `aspose-cells-8.5.2`) are stored in `publicERANET-server/lib/` and installed via a local file-system Maven repository (`<url>file://${project.basedir}/lib</url>`). These are ~decade-old versions.
- **Files:** `publicERANET-server/lib/com/aspose/`, `publicERANET-server/pom.xml` lines 18–24, 220–238
- **Impact:** No automated security patching. License file is committed to resources at `publicERANET-server/src/main/resources/META-INF/Aspose.Total.Java.lic`. Old Aspose versions have known bugs with newer PDF/DOCX formats.
- **Fix approach:** Use Aspose's official Maven repository or upgrade to current versions.

### `System.out.println` in SOAP Handler

- **Severity:** LOW
- **Issue:** `LoggingHandler.java` logs all inbound and outbound SOAP messages to `System.out` using `System.out.println`. This is a debug artifact left in production code. SOAP messages may contain sensitive data.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/proebiz/LoggingHandler.java` lines 25, 38
- **Fix approach:** Replace `System.out.println` with `logger.debug()`; gate behind a feature flag or remove entirely.

### `e.printStackTrace()` in Production Code

- **Severity:** LOW
- **Issue:** Five occurrences of `e.printStackTrace()` in production Java code, most critically in `SAMLClient.java`'s `intializeCredentials()` method — meaning a keystore load failure (null `signingCredential`) will silently cause NPEs in SAML operations.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` line 967, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/ws/PingEndpoint.java`, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UndeliveredEmailNotificationSchedulerService.java`
- **Fix approach:** Replace with proper logger error calls and rethrow or fail-fast.

### Empty Catch Blocks

- **Severity:** MEDIUM
- **Issue:** 10 empty catch blocks found across `ProcurementDao.java` (8 occurrences) and `ProcurementDataRetentionService.java` (2 occurrences). Exceptions are silently swallowed.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/ProcurementDao.java`, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ProcurementDataRetentionService.java`
- **Fix approach:** At minimum log the exception; preferably rethrow as a typed application exception.

---

## TODO / FIXME Markers

### Unresolved Business Logic (UvoService)

- **Severity:** MEDIUM
- **Issue:** Three TODO comments in `UvoService.java` reference an unimplemented feature: sending an identifier for a dropdown field controlling qualification conditions.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/UvoService.java` lines 3078, 3318, 3325
  ```java
  // TODO: po novom musím poslať identifikator rozbaľovacieho poľa...
  ```

### Deferred Work Items (InternalRequestService)

- **Severity:** LOW
- **Issue:** TODOs reference Jira tickets that are deferred but not resolved.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/InternalRequestService.java` lines 1252, 1256 (`EP-3908`), 1477 (`EP-3569`)

### Notification Bug Suppressed (ScheduleService)

- **Severity:** MEDIUM
- **Issue:** Notification sending for qualification system levels with stages is intentionally disabled with a TODO referencing a Jira ticket.
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ScheduleService.java` line 1007
  ```java
  //TODO: fix v https://innovis.atlassian.net/browse/EP-8225, teraz len docasne neposiela notifikacie na KS so stupnami
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
- **File:** `publicERANET-client/app/scripts/controllers/procurement/preparationPhase/procurementDefinition/generalInformation.js` line 1261
  ```javascript
  // TODO consul
  ```

---

## Test Coverage Gaps

### No Java Unit or Integration Tests

- **What's not tested:** The entire `publicERANET-server` backend — 889 Java source files, all REST endpoints, all business logic.
- **Files:** `publicERANET-server/src/test/java/` directory exists but is empty.
- **Risk:** Any refactoring, dependency upgrade, or bug fix has no automated regression safety net.
- **Priority:** HIGH

### Frontend Tests Are a Stub

- **What's not tested:** All 389 AngularJS controller files, all services, all directives.
- **Files:** Only `publicERANET-client/test/spec/controllers/main.js` exists (yeoman scaffold boilerplate).
- **Risk:** UI regressions are undetectable programmatically.
- **Priority:** MEDIUM
- **VSE note:** the VSE-specific Jackrabbit contract module (`publicERANET-client/app/modules/jackrabbit/`) — contract lifecycle plus a board notification to `predstavenstvo@vse.sk` (hardcoded, requires a redeploy to change) — has no test coverage despite being mission-critical.

---

## Fragile Areas

### SAML Authentication (`SAMLClient.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/saml/SAMLClient.java` (970 lines)
- **Why fragile:** Uses EOL `opensaml 2.6.4`, hardcoded keystore passwords, `e.printStackTrace()` on credential failure (which leaves `signingCredential` null and causes NPE on first SAML operation), and repeated `intializeCredentials()` calls (lines 162, 442, 517, 580) rather than singleton initialization.
- **Safe modification:** Any change must be tested against a live or mocked SAML IdP. Verify SAML SSO and SLO flows end-to-end after any modification.

### Statistics SQL Engine (`StatisticsService.java`, `StatisticsField.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/StatisticsService.java`, `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/serialization/dto/statistics/` (124 native SQL query classes)
- **Why fragile:** Hand-built SQL query construction using `StringBuilder` with filter chaining and string-replaced `IN (#)` ID lists. Any change to filter logic risks breaking query structure. No tests exist.
- **Safe modification:** Only modify one filter path at a time; test with the full statistics export UI after every change.
- **Two render paths — Excel ≠ on-screen.** The Excel export is server-rendered (`getFormattedValue` / `codebookService.translate` in `StatisticsService`), but the on-screen report is **client-rendered**: header from the `statisticsField` codebook (`codebookGenerator.js`), value from a `filters[identificator]` codebook filter (`showStatisticsList.js`). A new codebook statistics attribute needs the server `StatisticsField` **and** three client additions (`constants.js` identificator, `codebookGenerator.js` `statisticsField` header entry, `showStatisticsList.js` value filter) — otherwise Excel is correct while the browser report shows raw codes and a blank column header. (EP-13137.)

### File Binary Storage in MySQL (`FileDao.java`)

- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/FileDao.java`
- **Why fragile:** Binary file data is stored as BLOBs directly in MySQL (`SELECT data FROM file WHERE id = ?`). Large file uploads will cause memory pressure. The DAO uses `PreparedStatement` with `?` placeholders correctly (no injection risk), but the pattern does not scale.
- **Test coverage:** None.

---

## Performance Notes

### Binary File Storage in Database

- **Severity:** MEDIUM
- **Problem:** All file attachments are stored as MySQL BLOBs in the `file` table. At scale this severely impacts database size, backup time, and memory consumption when streaming large files.
- **Files:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/FileDao.java`
- **Improvement path:** Migrate to filesystem or object storage (S3-compatible); store only file metadata in the DB.

### No Frontend Build Minification in Development

- **Severity:** LOW
- **Problem:** The `app/scripts/` directory contains 679 unminified JavaScript files loaded individually in development. The bundled build (`dist/`) would be needed for production performance, but the Grunt build tooling is frozen at 2013 vintage.

---

## Missing Critical Features

### No HTTPS Enforcement

- **Problem:** `transport-guarantee` is `NONE` in `publicERANET-server/src/main/webapp/WEB-INF/web.xml`. The application relies entirely on external infrastructure (reverse proxy) to enforce HTTPS. If deployed without a TLS proxy, all traffic — including credentials and session cookies — is unencrypted.

### No CORS Configuration

- **Problem:** No CORS filter or CORS headers are configured anywhere in the Java backend. No `@CrossOrigin` annotations, no servlet filter class matching `*Filter*` or `cors`. The application may only be functional when the frontend and backend share the same origin.
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

### Searching message text & the `@Lob byte[]` mapping

`Message.body` is mapped as `@Lob byte[]` over a binary column. When adding text search over
it, or changing the column type, watch for this chain (all hit during EP-13104):

1. **Case-insensitive search needs a character column.** `LOWER()` on a MySQL `BLOB` is a
   no-op (binary), so `LIKE`/`LOWER` on a `BLOB` is case-*sensitive*. A character type
   (`LONGTEXT`) is required for case-insensitive search.
2. **`@Lob byte[]` does not map a `LONGTEXT` column** — EclipseLink reads it as `String` and
   throws `ConversionException`. Keep the `byte[]` field/API by adding a JPA
   `AttributeConverter<byte[], String>` (see `MessageBodyConverter`).
3. **A new JPA `@Converter` must be listed in `persistence.xml`** — this PU enumerates every
   managed class, so an unlisted converter fails predeployment (EclipseLink-7351).
4. **`BLOB → LONGTEXT` relabels the existing bytes without transcoding** — pin the charset
   (`CHARACTER SET utf8mb4`) in the Liquibase change so UTF-8 (Slovak) text stays correct
   regardless of the table default. `modifyDataType` can't express charset — use a `<sql>`
   change with a `<rollback>`.

---

## Server Dependency Caveats

### Third-party JARs must load on Java 8 / WildFly, not just compile

A WAR can build on Java 8 yet fail at class-load if a dependency contains Java 9+ bytecode.
JBoss Modules eagerly links classes, so a Java-10 class on the classpath throws
`UnsupportedClassVersionError` (class file 54.0 vs 52.0) at runtime even if never called.
Verify new deps by loading them under JDK 8, not just `mvn clean package`.

- Case (EP-13100): `owasp-java-html-sanitizer` 20240325.1 ships a Java-10 shim
  (`org.owasp.shim.ForJava9AndLater`) → crash. Use **20220608.1** (last shim-free release)
  and `<exclusion>` its transitive Guava 30.1 — the pinned Guava 18.0 has every API it calls.

---

*Concerns audit: 2026-06-03*
