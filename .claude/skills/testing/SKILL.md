---
name: testing
description: How we test SEPS - Karma/Jasmine unit tests for the AngularJS client, manual smoke testing in the browser. Use whenever writing tests, verifying a change, checking for regressions, or when the user mentions "testy", "regresné testy", "smoke test", "pretestovať".
---

# Testing

SEPS ships many small ticket-driven changes. Unit tests cover client-side logic; browser
smoke testing catches visual regressions and server integration issues.

## Layers

### Client unit tests — Karma + Jasmine

- **Framework:** Karma `~0.12.31` with Jasmine (`publicERANET-client/karma.conf.js`).
- **Run:** `grunt test` from `publicERANET-client/` — runs JSHint + Karma.
- **Caveat:** the pinned Karma (`~0.12`) + socket.io 0.9 stack crashes on modern Node (18+/24, `EventEmitter.prototype` removed), so `grunt test` only runs on the legacy Node toolchain. On modern Node, validate specs by reading and run them on a compatible Node/CI.
- **Test files:** `publicERANET-client/test/spec/` — mirror the `app/scripts/` structure.
- **Jasmine globals** available in tests: `describe`, `it`, `expect`, `beforeEach`,
  `afterEach`, `inject`, `spyOn`, `jasmine`, `browser`.
- Test files use a relaxed `.jshintrc` at `publicERANET-client/test/.jshintrc`.

Write or update a Karma spec when:
- A controller function has non-trivial logic (calculations, state transitions).
- A filter has edge cases worth asserting.
- A service method has business rules that could silently break.

### Server unit tests

No Maven test suite is currently in place for the server. New server-side logic that is
pure and testable (e.g., utility methods, comparators, DTO conversions) can be covered
with plain JUnit 4 tests in `publicERANET-server/src/test/java/` — but this is not
mandatory for every ticket.

### Browser / smoke testing

After a change, verify in the running app:
1. Start the client dev server: `grunt serve` in `publicERANET-client/` (port 9000,
   proxied to WildFly on port 8080).
2. Or build and deploy the WAR: `mvn clean package` then redeploy to WildFly.
3. Navigate to the affected screen(s) and verify the happy path.
4. Check adjacent screens for regressions (e.g., a shared service or directive change may
   affect multiple screens).

If the Playwright MCP is connected (`.mcp.json`), it can drive the browser interactively
for ad-hoc smoke checks without writing a spec first.

## Workflow for a change

1. Implement the change.
2. Run `grunt test` to catch JS lint errors and existing failing specs.
3. Write/update Karma specs for new or modified client-side logic.
4. Smoke-test the affected procurement screen(s) in the browser.
5. Note regression risk to adjacent areas and spot-check those too.

## Critical flows to always check

- **Login** (local form login, or SAML redirect if configured in the test env).
- **Procurement list and detail view** — the core screen; any shared service/directive
  change can break it.
- **File upload** — `ng-file-upload` flows are fragile; verify if touched.
- **Any screen using the changed service or directive** — grep for the factory/directive
  name before claiming "done."

## Note

A dedicated tester can use this to speed up regression checks rather than re-testing
by hand. The agent assists testing; it does not replace judgment about what to cover.
