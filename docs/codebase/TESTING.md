# Testing Patterns

**Analysis Date:** 2026-06-03

## Summary

This project has **minimal test coverage**. The client has Karma/Jasmine infrastructure configured but only a single stub spec file exists. The server has a `src/test/java` directory that is completely empty. No test files of any kind exist in the server module. Testing is configured but largely absent in practice.

---

## Client Testing (AngularJS / Karma / Jasmine)

### Test Framework

**Runner:** Karma 0.12.31
- Unit config: `publicERANET-client/karma.conf.js`
- E2E config: `publicERANET-client/karma-e2e.conf.js`

**Assertion/Test Library:** Jasmine (loaded via `karma.conf.js` `frameworks: ['jasmine']`)

**E2E framework:** `ng-scenario` (angular-scenario runner, deprecated — from karma-e2e.conf.js `frameworks: ['ng-scenario']`)

**Run Commands:**
```bash
# From publicERANET-client/
npm test           # Runs: grunt test
grunt test         # clean:server -> concurrent:test -> autoprefixer -> connect:test -> karma
grunt karma        # Runs karma unit config directly (singleRun: true in Gruntfile)
```

### Test File Locations

**Unit tests:**
- Location: `publicERANET-client/test/spec/` (recursive)
- Pattern matched by Karma: `test/spec/**/*.js`
- Mock files: `test/mock/**/*.js` (directory exists in Karma config but no mock files are present)

**E2E tests:**
- Pattern in e2e config: `test/e2e/**/*.js`
- No `test/e2e/` directory exists — **e2e tests are configured but not created**

**What actually exists:**
```
publicERANET-client/test/
├── .jshintrc              # JSHint config for test files
├── runner.html            # Legacy e2e test runner HTML (references angular-scenario.js)
└── spec/
    └── controllers/
        └── main.js        # Single stub spec file (scaffold-generated)
```

The entire test suite consists of **one generated spec file** with a single trivial test.

### Existing Test Structure

The only actual spec (`publicERANET-client/test/spec/controllers/main.js`):

```javascript
'use strict';

describe('Controller: MainCtrl', function () {

  // load the controller's module
  beforeEach(module('yoemanTestApp'));

  var MainCtrl, scope;

  // Initialize the controller and a mock scope
  beforeEach(inject(function ($controller, $rootScope) {
    scope = $rootScope.$new();
    MainCtrl = $controller('MainCtrl', {
      $scope: scope
    });
  }));

  it('should attach a list of awesomeThings to the scope', function () {
    expect(scope.awesomeThings.length).toBe(3);
  });
});
```

Note: `yoemanTestApp` does not exist in the actual application (the real module is `eranetPublic`). This test would **fail** if run against the actual codebase. It is a Yeoman scaffold artifact that was never updated.

### How Karma is Configured

**Unit (karma.conf.js):**
- Loads: Angular core, angular-mocks, angular-resource, angular-cookies, angular-sanitize, angular-route (from `app/bower_components/`)
- Loads all app scripts: `app/scripts/*.js` and `app/scripts/**/*.js`
- Loads: `test/mock/**/*.js` and `test/spec/**/*.js`
- Browser: Chrome (not PhantomJS)
- `autoWatch: false`, `singleRun: false` (but overridden to `singleRun: true` in Gruntfile task config)
- Port: 8080

**E2E (karma-e2e.conf.js):**
- Framework: `ng-scenario`
- Only loads `test/e2e/**/*.js`
- No proxy configuration (commented out)
- The e2e runner HTML at `test/runner.html` references `vendor/angular-scenario.js` which does not exist at that path

### Mocking Approach

The `angular-mocks` package is loaded in `karma.conf.js` and available for use. The intended pattern (from the single existing spec) is:

```javascript
beforeEach(module('eranetPublic'));  // load the module

beforeEach(inject(function ($controller, $rootScope) {
    scope = $rootScope.$new();
    MainCtrl = $controller('ControllerName', { $scope: scope });
}));
```

No actual mock files exist. The `test/mock/` directory is referenced in Karma config but is empty/absent.

### JSHint for Tests

Test files use a separate JSHint config at `publicERANET-client/test/.jshintrc` which adds these globals (all set `false` = read-only):
- Jasmine globals: `describe`, `it`, `expect`, `beforeEach`, `afterEach`, `jasmine`, `spyOn`
- Angular globals: `inject`, `angular`, `browser`
- Setup hooks: `before`, `after`

### CI Configuration

**File:** `publicERANET-client/.travis.yml`

```yaml
language: node_js
node_js:
  - '0.8'
  - '0.10'
before_script:
  - 'npm install -g bower grunt-cli'
  - 'bower install'
```

- Tests Node.js 0.8 and 0.10 (severely outdated — both EOL)
- Does **not** include a `script:` section, so no test command runs on CI
- No browser installation step (Chrome required but not installed in CI)
- Travis CI configuration is effectively non-functional

---

## Server Testing (Java / Maven)

### Test Infrastructure

**Build tool:** Maven 3 with `maven-compiler-plugin` 3.1 (Java source/target 1.8)

**Test directory:** `publicERANET-server/src/test/java/` — **directory exists but contains no files**

No test dependencies are declared in `publicERANET-server/pom.xml`:
- No JUnit dependency
- No Mockito dependency
- No Arquillian dependency
- No `surefire-plugin` configuration

**Conclusion: Zero server-side tests exist. No test framework is configured.**

### eranet-domain module

`publicERANET-server/eranet-domain/` — secondary module containing only a `src/main/resources/META-INF/` directory. No test directory, no Java sources, no test configuration.

### public-eranet module

`publicERANET-server/public-eranet/` — contains service classes under `src/main/java/sk/innovis/eranetpublic/server/service/` but no `src/test/` tree. No tests.

---

## What Needs to Be Established Before Testing Can Be Done

### Client (AngularJS)

1. Update `test/spec/controllers/main.js` to reference `eranetPublic` (not `yoemanTestApp`)
2. Install Karma CLI and Chrome (or switch to `PhantomJS` or `ChromeHeadless` for CI)
3. Add `angular-mocks` to bower.json (verify it resolves from `bower_components/angular-mocks/`)
4. Create `test/mock/` files for services the controllers depend on
5. Pattern to use when writing new specs:

```javascript
'use strict';

describe('Controller: CompanyProfileController', function () {

  beforeEach(module('eranetPublic'));

  var CompanyProfileController, scope, rootScope;

  beforeEach(inject(function ($controller, $rootScope) {
    rootScope = $rootScope;
    scope = $rootScope.$new();
    CompanyProfileController = $controller('CompanyProfileController', {
      $scope: scope
    });
  }));

  it('should define shouldShowTabs', function () {
    expect(typeof scope.shouldShowTabs).toBe('function');
  });
});
```

### Server (Java)

1. Add JUnit 4 or JUnit 5 to `pom.xml` `<scope>test</scope>` dependencies
2. Add Mockito for mocking EJB/CDI injection points
3. Add Arquillian if integration/container tests are needed (given `@Stateless` EJBs)
4. Add `maven-surefire-plugin` configuration if custom test patterns required

---

## Coverage

**Client:** No coverage configuration exists. `karma-coverage` plugin is not installed.

**Server:** No coverage configuration exists. JaCoCo or equivalent is not in `pom.xml`.

No coverage requirements are enforced anywhere in the build.

---

*Testing analysis: 2026-06-03*
