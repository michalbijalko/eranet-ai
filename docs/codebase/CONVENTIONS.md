# Coding Conventions

**Analysis Date:** 2026-06-03

## Overview

This project has two subprojects with distinct conventions:
- `publicERANET-client/` — AngularJS (1.x) frontend, JavaScript ES5
- `publicERANET-server/` — Java 8 / JAX-RS backend

---

## JavaScript (Client) Conventions

### Code Style Enforcement

**Linter:** JSHint, configured in `publicERANET-client/.jshintrc`

Key JSHint rules in force:
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

**Test files** use a relaxed `.jshintrc` at `publicERANET-client/test/.jshintrc`:
- Same base rules, but adds Jasmine globals (`describe`, `it`, `expect`, `beforeEach`, `afterEach`, `inject`, `spyOn`, `jasmine`, `browser`) as allowed undeclared globals

**Formatter:** EditorConfig, configured in `publicERANET-client/.editorconfig`
- Indent style: **tab** (not spaces)
- Indent size: 4
- End of line: LF
- Charset: UTF-8
- `*.js` files: single quotes

### Naming Patterns (JS)

**Files:**
- Controllers: `camelCase.js` in `app/scripts/controllers/` subdirectory matching feature area (e.g., `companyProfileBasicInformation.js`, `buyers.js`)
- Services (business): `camelCase.js` in `app/scripts/service/` (e.g., `mainInterceptor.js`, `dialogConfirmer.js`)
- Resources (REST wrappers): `camelCase.js` in `app/scripts/service/resources/` — name matches the entity (e.g., `procurements.js`, `companies.js`)
- Directives: `camelCase.js` in `app/scripts/directives/` — name matches the HTML element name in camelCase

**Angular identifiers:**
- Controller functions: `PascalCase` with `Controller` suffix (e.g., `CompanyProfileController`, `DatetimeCellController`)
- Factory/service functions: `PascalCase` without suffix for resources (e.g., `ProcurementsResource`), PascalCase for business services (e.g., `Procurements`, `Alerts`, `Utils`)
- Directive names: camelCase matching their HTML attribute/element name (e.g., `datetimeCell`, `decimalInput`, `attachmentsCell`)
- Filter functions: `camelCase` with `Filter` suffix (e.g., `harmonogramTaskStatusFilter`, `undefinedNumberFilter`)
- Constants: `SCREAMING_SNAKE_CASE` for values inside `.constant()` objects (e.g., `FILTER_NAME_CODEBOOK`, `COMPANY_TYPE_SUPPLIER`)
- Module-level variables: camelCase (e.g., `serviceResult`, `procurementsResult`)

**Variables:**
- camelCase throughout
- Service object pattern: internal state in `var`-declared variables, public API on a `var serviceResult = {}` object returned at end of factory

### AngularJS Module Structure

**Root module definition** in `publicERANET-client/app/scripts/ng.app.js`:
```javascript
var eranetPublic = angular.module('eranetPublic', [
    'ngRoute', 'ngResource', 'ui.bootstrap',
    'services', 'controllers', 'directives', 'filters', 'app.main', ...
]);
// Module declarations at the bottom of the same file:
angular.module('controllers', []);
angular.module('directives', []);
angular.module('filters', []);
angular.module('services', []);
```

All controllers belong to the `controllers` module, all Angular services/factories to `services`, all directives to `directives`, and all filters to `filters`. `app.main` is used for SmartAdmin theme directives and the `ribbon` factory.

**Route definitions** are in `publicERANET-client/app/scripts/ng.app.js` inside `eranetPublic.config([...])`.

### Controller Pattern

Use array DI notation with a named constructor function as the last element:

```javascript
// From publicERANET-client/app/scripts/controllers/companyProfile.js
'use strict';

angular.module('controllers')
    .controller('CompanyProfileController', ['$scope',
        '$rootScope',
        'WebStorage',
        function define($scope, $rootScope, WebStorage) {
            // scope assignments and methods here
        }]);
```

- First argument to `.controller()` is the `PascalCase` + `Controller` name
- DI array lists dependencies as strings, matching parameters in the function
- The constructor function parameter name is typically `define` (not the controller name)
- `$rootScope` is used frequently for cross-controller shared state (`currentProcurement`, `procurementId`, `currentUser`, etc.)
- Tab-based views share state via `$controller('TabController', {$scope: $scope})`

### Service/Factory Pattern

All business services follow the **serviceResult object** pattern:

```javascript
// From publicERANET-client/app/scripts/service/resources/procurements.js
'use strict';
angular.module('services').factory('Procurements', ['$resource', '$rootScope', ...,
    function Procurements($resource, $rootScope, ...) {
        var privateVar = ResultManipulator.getEmptyResult();

        var privateFunc = function (args) { ... };

        var serviceResult = {};

        serviceResult.publicMethod = function (params, callback) { ... };

        return serviceResult;
    }
]);
```

- Private state declared with `var` at the top of the factory function
- Private helpers as `var fn = function() {}` (not function declarations)
- Public API exposed as properties on `var serviceResult = {}`
- Callbacks (not Promises) used throughout: `function afterLoad(data) {}` naming convention for async callbacks

### Resource (REST client) Pattern

Each REST resource is a two-part file:
1. A `$resource` factory named `EntityNameResource` — defines URL templates and custom HTTP methods
2. A higher-level business factory named `EntityName` — wraps the resource with business logic

```javascript
// Part 1: from publicERANET-client/app/scripts/service/resources/procurements.js
angular.module('services').factory('ProcurementsResource', ['$resource',
    function ProcurementsResource($resource) {
        return $resource('webresources/sc/procurement/:procurementId', { procurementId: '@id' }, {
            query: { method: 'POST', url: 'webresources/sc/procurement/query' },
            updateAttributes: { method: 'PATCH', ... }
        });
    }
]);
```

All REST base paths start with `webresources/sc/`.

### Directive Pattern

```javascript
// From publicERANET-client/app/scripts/directives/datetimeCell.js
'use strict';
var directives = angular.module('directives');
directives.directive('datetimeCell', [function defineDatetimeCell() {
    return {
        restrict: 'E',
        templateUrl: 'views/directives/datetimeCell.html',
        scope: { array: '=', index: '@', datePropertyName: '@', checkDate: '&' },
        link: function (scope, element, attrs) { ... }
    };
}]);
```

- Directives use `restrict: 'E'` (elements) predominantly
- Isolated scope with `=` for two-way bindings, `@` for attribute strings, `&` for callbacks
- Template URLs reference `views/directives/` folder

### Filter Pattern

```javascript
// From publicERANET-client/app/scripts/filters.js
filters.filter('harmonogramTaskStatusFilter', function defineHarmonogramTaskStatusFilter() {
    return function getHarmonogramTaskStatusIcon(input) { ... };
});
```

Named inner functions for both the factory and the returned filter function.

### Error Handling (Client)

- HTTP errors are handled centrally in `publicERANET-client/app/scripts/service/mainInterceptor.js` via an Angular HTTP interceptor factory registered on `$httpProvider.interceptors`
- The interceptor handles 400, 401, 403, 404, 405, 500 status codes with translated error messages via `$translate`
- Business errors are shown using `Alerts.error()` and `Alerts.longError()` from `publicERANET-client/app/scripts/service/alerts.js`
- `Alerts` wraps `$.smallBox()` from the SmartAdmin theme

### Logging (Client)

No Angular logging service is used. There is no `$log` usage in application code. Browser console is used only via commented-out `console.log` statements. No structured logging on the client.

### Comments (Client)

- Block comments for function descriptions (not JSDoc format)
- Inline comments in Slovak language (`// Načíta aktuálne vybrané obstarávanie...`)
- English comments also present (no strict language convention enforced)
- Commented-out code blocks are common (large sections in `app.js`, `app.config.js`, services)

### Import Organization (Client)

No ES module imports (ES5 codebase). All files are loaded via `<script>` tags or Karma `files` list. File load order matters: module declarations in `ng.app.js` must load before all other Angular files.

---

## Java (Server) Conventions

### Project Layout

Base package: `sk.innovis.eranetpublic.server`

Sub-packages:
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

**Classes:**
- Entities (DTOs): `PascalCase` matching the domain concept, no suffix (e.g., `Procurement`, `Addendum`, `Agreement`)
- DAOs: entity name + `Dao` suffix (e.g., `ProcurementDao`, `AgreementDao`)
- Services (which are also JAX-RS endpoints): entity name + `Service` suffix (e.g., `ProcurementService`, `AgreementService`)
- Interfaces used by DTOs: `Has` prefix + capability (e.g., `HasId`, `HasAttachment`, `HasFiles`, `HasCopy`)
- Exception mappers: what-maps + `Handler` suffix (e.g., `AccessLocalExceptionHandler`)
- Comparators: `EntityName` + `By` + `PropertyName` + `Comparator` (e.g., `FileDescriptionDatetimeComparator`)

**Methods:**
- camelCase throughout
- Service endpoint methods named by HTTP action + resource (e.g., `getProcurement`, `saveProcurement`, `deleteProcurement`)
- Post-construct callbacks follow no strict convention but often named for what they do

**Constants:**
- `SCREAMING_SNAKE_CASE` as `static final` fields (e.g., `FULL_DATETIME_FORMAT_TO_STRING`, `PROPERTY_NAME_PROCUREMENT_ID`)

### Service/DAO Pattern

**BaseService** (`publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/BaseService.java`):
- Abstract generic class `BaseService<T>` extended by all concrete services
- Injects `Logger` via CDI `@Inject`
- Injects EJB collaborators via `@EJB`
- Provides shared date format constants (`STANDARD_DATE_FORMAT`, `FULL_DATETIME_FORMAT`, etc.)

**BaseDao** (`publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dao/BaseDao.java`):
- Abstract generic class `BaseDao<T>` extended by all concrete DAOs
- Injects `EntityManager` via `@PersistenceContext(name = "PublicPU")`
- Provides `create`, `find`, `update`, `delete` operations using JPA Criteria API

**Concrete service example:**
```java
// From publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/ProcurementService.java
@Path("sc/procurement")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Stateless
@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)
public class ProcurementService extends BaseService<Procurement> { ... }
```

Service classes are simultaneously JAX-RS resources and EJB `@Stateless` session beans. They combine REST endpoint and business logic in a single class.

### Entity (DTO) Pattern

```java
// From publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/Addendum.java
@Entity
@Table(name = "addendum")
@XmlRootElement
public class Addendum implements Serializable, HasAttachment, HasId {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Integer id;

    @JoinColumn(name = "agreement_id") @ManyToOne
    private Agreement agreement;

    @Transient  // computed, not persisted
    private FileDescription fileDescription;
    ...
}
```

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

---

*Convention analysis: 2026-06-03*
