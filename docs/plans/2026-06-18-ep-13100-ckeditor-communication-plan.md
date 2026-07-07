# EP-13100 — CKEditor in communication module: Implementation Plan

> **For the executor agents:** Use `superpowers:executing-plans`. Backend slice → `executor-backend`,
> frontend slice → `executor-frontend`. **Execute the BACKEND slice and deploy it before the FRONTEND
> slice** — the `html_body` column and the sanitizer must exist before the client starts sending HTML.

**Ticket:** Story **EP-13100** · Dev **EP-13108** · Test EP-13109 · Epic EP-12988
**Authoritative design (locked):** `docs/plans/2026-06-18-ep-13100-ckeditor-communication-design.md`
**Goal:** Add a rich-text CKEditor (full výzva toolbar) to the communication "write new message" screen,
and sanitize message HTML server-side to prevent XSS. New `html_body` column stores sanitized HTML;
existing `body` is repurposed as tag-free plain text (derived on the backend) for previews/filter/search.

**Architecture:** Client sends only `htmlBody`. At the single `MessageService.create()` choke point the
server sanitizes `htmlBody` (owasp-java-html-sanitizer) and derives plain-text `body` from it, then saves
through `BaseService` as today. Email/notification rendering is unchanged (still uses `body`).

**Tech stack:** Java 8 / Java EE 7 / EclipseLink / RESTEasy / Liquibase / MySQL (server);
AngularJS 1.5 ES5 / ng-ckeditor / CKEditor 4 (client).

**Commit pair (from `docs/TICKETS.md`):** `feat(EP-13100, EP-13108): …`
- Server repo: `feat(EP-13100, EP-13108): sanitize message HTML on save`
- Client repo: `feat(EP-13100, EP-13108): add CKEditor to message compose`

---

## Locked decisions (do not deviate)

1. Frontend uses the **full výzva toolbar**: `Settings.ckeditorSettings` (NOT `ckeditorSettingsCommunication`).
2. New `html_body` column stores sanitized CKEditor HTML; `body` is repurposed as tag-free plain text.
   Old rows: `html_body = body` (Liquibase UPDATE).
3. Plain-text `body` is derived on the **backend** on save (client sends only HTML).
4. Sanitization runs on **every save (draft + send)** at the single `MessageService.create()` choke point.
   New messages only; no retro-sanitization of old rows.
5. Allowlist matches the toolbar; constrained inline-`style` whitelist (`color, background-color,
   font-family, font-size, text-align, text-decoration`); links `http/https/mailto` + `rel=nofollow`;
   drop scripts/iframes/`on*`/`class`/`id`. Library: `owasp-java-html-sanitizer`. Liquibase author `m.bijalko`.
6. Email/notification rendering **left unchanged** (`sendEmail` keeps using `body`; `sendNotificationEmail`
   untouched). **No REST endpoint changes.**

---

## Pre-flight (umbrella repo, before any code commit)

### Task 0: Register the ticket pair in `docs/TICKETS.md`

**Files:** Modify `C:\Innovis\seas_test\docs\TICKETS.md` (the mapping table, currently ends at line 26).

**Step 1:** Add this row under the existing `Fulltext search…` row:

```markdown
| CKEditor in communication | `EP-13100` | `EP-13108` |
```

**Step 2: Commit (umbrella repo, scoped to that file only).** Do NOT `git add` the `publicERANET-*`
nested repos.

```bash
git -C C:/Innovis/seas_test commit -- docs/TICKETS.md -m "docs(EP-13100, EP-13108): add ticket pair to TICKETS.md"
```

Verification: `git -C C:/Innovis/seas_test log --oneline -1` shows the commit; no `publicERANET-*` paths staged.

---

# BACKEND SLICE — `publicERANET-server` (do this first, deploy, then start the client slice)

All paths under `C:\Innovis\seas_test\publicERANET-server\`.
Branch: `seas-test`. One commit for the whole slice (see Task B6).

**Reference / analog files (read before editing):**
- Entity + converter reuse: `src/main/java/sk/innovis/eranetpublic/server/dto/Message.java`
  (`body` field lines **71-76**, getter `getBody()` lines **151-158**),
  `src/main/java/sk/innovis/eranetpublic/server/serialization/MessageBodyConverter.java` (whole file).
- Save choke point: `MessageService.create()` at **lines 179-200** (calls `createInternal()` → `BaseService`).
- Email path that must stay on `body`: `sendEmail(...)` builds the message at
  `MessageService.java:1994-2004` (`String body = …; email.setHtmlMsg(body);`).
- Closest Liquibase analog (same table, same column, author `m.bijalko`):
  `src/main/sql/2.11.0/db.changelog-EP13114.xml` (whole file).
- Master changelog (append include here): `src/main/sql/db.changelog-master.xml` (last include is
  `.\2.11.0\db.changelog-EP13114.xml` on the final line before `</databaseChangeLog>`).
- pom dependencies block: `pom.xml` `<dependencies>` opens line **44**, closes line **261**.

---

### Task B1: Add the `owasp-java-html-sanitizer` dependency

**Files:** Modify `pom.xml` (insert inside `<dependencies>`, just before the closing tag at line 261,
after the Lombok dependency that ends at line 260).

**Step 1:** Insert the dependency. Use a Java-8-compatible release (e.g. `20220608.1`):

```xml
        <dependency>
            <groupId>com.googlecode.owasp-java-html-sanitizer</groupId>
            <artifactId>owasp-java-html-sanitizer</artifactId>
            <version>20220608.1</version>
        </dependency>
```

**Step 2: Verify it resolves.**

Run: `mvn -q -f C:/Innovis/seas_test/publicERANET-server/pom.xml dependency:resolve -Dincludes=com.googlecode.owasp-java-html-sanitizer`
Expected: BUILD SUCCESS, the artifact (and its `guava` transitive) listed/downloaded.

> Note: do not add an explicit `guava` version — the sanitizer pulls a compatible one. If a Guava
> version clash appears at build time, surface it as a decision; do not silently pin a new Guava.

---

### Task B2: Add the `htmlBody` field to the `Message` entity

**Files:** Modify `src/main/java/sk/innovis/eranetpublic/server/dto/Message.java`.

**Step 1:** Add the field immediately after the existing `body` field (after line 76), mirroring it
exactly — same converter, same Byte-array JSON (de)serializers, column `html_body`. Keep it nullable
(no `@Basic(optional = false)`) so old rows and drafts are tolerated:

```java
	@Convert(converter = MessageBodyConverter.class)
	@Column(name = "html_body")
	@JsonDeserialize(using = ByteArrayDeserializer.class)
	@JsonSerialize(using = ByteArraySerializer.class)
	private byte[] htmlBody;
```

**Step 2:** Add getter/setter next to `getBody()/setBody()` (after line 158), mirroring the
`@XmlJavaTypeAdapter(StringByteAdapter.class)` on the getter so XML/JSON serialization matches `body`:

```java
	@XmlJavaTypeAdapter(StringByteAdapter.class)
	public byte[] getHtmlBody() {
		return htmlBody;
	}

	public void setHtmlBody(byte[] htmlBody) {
		this.htmlBody = htmlBody;
	}
```

**Step 3 (optional, follow existing convention):** add `public final static String PROPERTY_NAME_HTML_BODY = "htmlBody";`
near the other `PROPERTY_NAME_*` constants (line 58 area) only if a later step references it. YAGNI — skip if unused.

Verification: compiles in Task B5 build. JSON field name on the wire is `htmlBody` (matches the client model).

---

### Task B3: Create the `MessageHtmlSanitizer` helper

**Files:** Create
`src/main/java/sk/innovis/eranetpublic/server/service/MessageHtmlSanitizer.java`
(place beside `MessageService.java`; package `…server.service`).

**Step 1:** Implement a stateless helper holding one shared `PolicyFactory`. Two methods:
`sanitize(String rawHtml)` → safe HTML for `html_body`; `toPlainText(String rawHtml)` → tag-free text
for `body`. Allowlist per locked decision 5.

```java
package sk.innovis.eranetpublic.server.service;

import org.owasp.html.HtmlPolicyBuilder;
import org.owasp.html.PolicyFactory;
import org.owasp.html.Sanitizers;

/**
 * Sanitizes CKEditor HTML coming from the communication module. The allowlist matches the
 * full výzva toolbar; everything else (scripts, iframes, event handlers, class/id) is dropped.
 */
public final class MessageHtmlSanitizer {

	private static final PolicyFactory POLICY = new HtmlPolicyBuilder()
			.allowElements(
					"b", "strong", "i", "em", "u", "s", "strike", "sub", "sup",
					"blockquote", "p", "br", "hr",
					"ul", "ol", "li",
					"span", "div",
					"a",
					"table", "thead", "tbody", "tr", "td", "th")
			// constrained inline style allowlist
			.allowAttributes("style").matching(MessageHtmlSanitizer::isAllowedStyle).globally()
			// links: http/https/mailto only, force rel=nofollow
			.allowAttributes("href").onElements("a")
			.allowStandardUrlProtocols()
			.requireRelNofollowOnLinks()
			.toFactory()
			// reuse the library's vetted table/formatting policies for cell attributes
			.and(Sanitizers.TABLES);

	private MessageHtmlSanitizer() {
	}

	public static String sanitize(final String rawHtml) {
		if (rawHtml == null) {
			return null;
		}
		return POLICY.sanitize(rawHtml);
	}

	public static String toPlainText(final String rawHtml) {
		if (rawHtml == null) {
			return null;
		}
		// Strip ALL tags (empty policy), then decode entities and collapse whitespace.
		final String noTags = new HtmlPolicyBuilder().toFactory().sanitize(rawHtml);
		return org.apache.commons.lang3.StringEscapeUtils
				.unescapeHtml4(noTags)
				.replaceAll("\\s+", " ")
				.trim();
	}

	private static boolean isAllowedStyle(final String styleValue) {
		// Allow only: color, background-color, font-family, font-size, text-align, text-decoration.
		// Reject anything containing url(, expression(, or javascript:.
		final String lower = styleValue.toLowerCase();
		if (lower.contains("url(") || lower.contains("expression") || lower.contains("javascript:")) {
			return false;
		}
		for (final String declaration : lower.split(";")) {
			final String prop = declaration.split(":")[0].trim();
			if (prop.isEmpty()) {
				continue;
			}
			switch (prop) {
				case "color":
				case "background-color":
				case "font-family":
				case "font-size":
				case "text-align":
				case "text-decoration":
					break;
				default:
					return false;
			}
		}
		return true;
	}
}
```

> Implementation notes for the executor:
> - `StringEscapeUtils` — confirm whether the project already has `commons-lang3` (preferred) or only
>   `commons-lang` (`org.apache.commons.lang.StringEscapeUtils`). Use whichever is already on the
>   classpath; do not add a new lang dependency. If neither is present, fall back to a minimal manual
>   entity-decode rather than introducing a framework — flag it as a decision.
> - The `style`-attribute matcher above is a pragmatic property-name allowlist. The owasp library API
>   for per-attribute matching may differ slightly between versions; adapt to the version pulled in B1
>   while keeping the locked property set and the `url(`/`expression`/`javascript:` rejection.
> - The exact `HtmlPolicyBuilder` fluent calls (`.requireRelNofollowOnLinks()`, `.allowStandardUrlProtocols()`)
>   must match the resolved library version's API. Keep the **behavior** locked, adapt the **syntax**.

**Step 2 (TDD):** Add a unit test (see Task B4) that pins the behavior, written before/with this class.

Verification: covered by Task B4 unit test.

---

### Task B4: Unit-test the sanitizer (TDD)

**Files:** Create
`src/test/java/sk/innovis/eranetpublic/server/service/MessageHtmlSanitizerTest.java`
(create the `src/test/java/...` tree if it does not exist — check first with a `Glob` for existing
`src/test/java` tests; if the server module has no test harness configured, flag it and fall back to
documenting these as the manual XSS checklist in Task B6 instead of inventing a test runner).

**Step 1: Write failing tests** covering the locked allowlist:

```java
package sk.innovis.eranetpublic.server.service;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

public class MessageHtmlSanitizerTest {

	@Test
	public void stripsScriptTags() {
		String out = MessageHtmlSanitizer.sanitize("<p>hi</p><script>alert(1)</script>");
		assertFalse(out.toLowerCase().contains("script"));
		assertTrue(out.contains("hi"));
	}

	@Test
	public void dropsEventHandlers() {
		String out = MessageHtmlSanitizer.sanitize("<img src=x onerror=alert(1)>");
		assertFalse(out.toLowerCase().contains("onerror"));
	}

	@Test
	public void dropsJavascriptLinks() {
		String out = MessageHtmlSanitizer.sanitize("<a href=\"javascript:alert(1)\">x</a>");
		assertFalse(out.toLowerCase().contains("javascript:"));
	}

	@Test
	public void keepsBasicFormattingAndAddsNofollow() {
		String out = MessageHtmlSanitizer.sanitize(
				"<p><strong>b</strong> <a href=\"https://x.sk\">l</a></p>");
		assertTrue(out.contains("<strong>"));
		assertTrue(out.toLowerCase().contains("rel=\"nofollow\""));
	}

	@Test
	public void keepsAllowedStyleDropsDisallowed() {
		String out = MessageHtmlSanitizer.sanitize(
				"<span style=\"color:red;position:absolute\">x</span>");
		assertFalse(out.contains("position"));
	}

	@Test
	public void toPlainTextStripsAllTags() {
		assertEquals("Bold list item",
				MessageHtmlSanitizer.toPlainText("<p><strong>Bold</strong> list <em>item</em></p>"));
	}
}
```

**Step 2: Run** (only if the server module has a test runner):
Run: `mvn -q -f C:/Innovis/seas_test/publicERANET-server/pom.xml -Dtest=MessageHtmlSanitizerTest test`
Expected: red first, then green after B3 is correct.

---

### Task B5: Wire sanitization into the `create()` choke point

**Files:** Modify `src/main/java/sk/innovis/eranetpublic/server/service/MessageService.java`
(method `create()`, lines **179-200**).

**Step 1:** At the very top of `create()` (before the draft/send branching at line 185), normalize the
body fields so both draft and send go through sanitization, and `body` is always derived from the
sanitized HTML:

```java
		// EP-13100: client sends only HTML. Sanitize it for html_body and derive plain-text body.
		applyHtmlAndPlainBody(message);
```

**Step 2:** Add the private helper to `MessageService` (well-named method, per conventions):

```java
	private void applyHtmlAndPlainBody(final Message message) {
		final byte[] rawHtmlBytes = message.getHtmlBody();
		if (rawHtmlBytes == null || rawHtmlBytes.length == 0) {
			return; // empty draft / nothing to sanitize
		}
		final String rawHtml = new String(rawHtmlBytes, PublicConstants.STRING_CHARSET_ENCODING);
		final String safeHtml = MessageHtmlSanitizer.sanitize(rawHtml);
		final String plainText = MessageHtmlSanitizer.toPlainText(rawHtml);
		message.setHtmlBody(safeHtml == null ? null
				: safeHtml.getBytes(PublicConstants.STRING_CHARSET_ENCODING));
		message.setBody(plainText == null ? null
				: plainText.getBytes(PublicConstants.STRING_CHARSET_ENCODING));
	}
```

**Constraints (verify):**
- `checkMessageSubjectAndRecipients(message)` (line 186) validates after this runs, so a send with only
  HTML still passes its body check — confirm it does not reject because `body` was previously client-sent.
  If that method specifically requires `body`, the derivation above satisfies it.
- `sendEmail` (line 1994-2004) and `sendNotificationEmail` are **NOT touched** — they keep reading
  `message.getBody()`, now plain text. This is the locked decision; do not "improve" the email to use HTML.
- The save still flows through `createInternal()` → `BaseService.createWithReturnObjectAsResponse`
  (line 203-204). Do **not** call the DAO directly.

**Step 3: Build the server.**
Run: `mvn -q -f C:/Innovis/seas_test/publicERANET-server/pom.xml -DskipTests package`
Expected: BUILD SUCCESS, WAR produced.

---

### Task B6: Liquibase changeset — add `html_body` and backfill

**Files:**
- Create `src/main/sql/2.11.0/db.changelog-EP13108.xml` (same version folder as the related EP-13114).
- Modify `src/main/sql/db.changelog-master.xml` (append one `<include>` as the **last** entry before
  `</databaseChangeLog>`, after the `.\2.11.0\db.changelog-EP13114.xml` line).

**Step 1:** Create the changeset (author `m.bijalko`), mirroring the EP13114 style. Two changesets:
add the column, then backfill old rows:

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-3.1.xsd">
    <!-- EP-13100: html_body holds sanitized CKEditor HTML; body becomes tag-free plain text. -->
    <changeSet author="m.bijalko" id="add_message_html_body_column">
        <sql>ALTER TABLE message ADD COLUMN html_body LONGTEXT CHARACTER SET utf8mb4 NULL</sql>
        <rollback>ALTER TABLE message DROP COLUMN html_body</rollback>
    </changeSet>
    <!-- Backfill existing rows: their stored body is already the displayable content. -->
    <changeSet author="m.bijalko" id="backfill_message_html_body_from_body">
        <sql>UPDATE message SET html_body = body WHERE html_body IS NULL</sql>
        <rollback/>
    </changeSet>
</databaseChangeLog>
```

**Step 2:** Append the include to the master changelog as the final include:

```xml
    <include file=".\2.11.0\db.changelog-EP13108.xml" relativeToChangelogFile="true"/>
```

**Step 3: Verify Liquibase applies cleanly** (on deploy / against the dev DB):
- Run the app's normal Liquibase migration (deploy to WildFly, or `mvn liquibase:update` if the module
  exposes it). Expected: both changesets recorded in `DATABASECHANGELOG`, `message.html_body` exists,
  old rows have `html_body = body`.
- Confirm `DESCRIBE message;` shows `html_body LONGTEXT`.

---

### Task B7: Commit the backend slice

**Files:** `pom.xml`, `dto/Message.java`, `service/MessageHtmlSanitizer.java`, `service/MessageService.java`,
`src/test/.../MessageHtmlSanitizerTest.java` (if added), `src/main/sql/2.11.0/db.changelog-EP13108.xml`,
`src/main/sql/db.changelog-master.xml`.

```bash
git -C C:/Innovis/seas_test/publicERANET-server add -A
git -C C:/Innovis/seas_test/publicERANET-server commit -m "feat(EP-13100, EP-13108): sanitize message HTML on save"
```

Verification: `git -C C:/Innovis/seas_test/publicERANET-server log --oneline -1` shows the exact message.
Then **deploy the server and run the migration before starting the frontend slice.**

---

# FRONTEND SLICE — `publicERANET-client` (only after the backend is deployed)

All paths under `C:\Innovis\seas_test\publicERANET-client\`.
Branch: `seas-test`. One commit for the whole slice (see Task F5).

**Reference pattern (read first):** the výzva editor usage
`app/views/procurement/proposalPresentation/promptSending/promptSendingView.html:43-49`:

```html
<textarea ckeditor="editorOptions"
          name="messageBody"
          data-ng-model="help.body"
          data-ng-disabled="shouldBeDisabled()"
          ng-model-options="{ updateOn: 'default blur clear', debounce: { 'default': 500, 'blur': 0, 'clear': 0 } }"
></textarea>
```

The `ckeditor` directive (ng-ckeditor) is already registered app-wide (used by výzva; module wired in
`app/scripts/ng.app.js`). The full toolbar config lives at `app/scripts/service/settings.js:22-39`
(`ckeditorSettings`); the reduced one at `:41-54` (`ckeditorSettingsCommunication`, currently unused).

---

### Task F1: Switch the communication editor options to the full toolbar

**Files:** Modify `app/scripts/controllers/communication/communication.js` line **74**.

**Step 1:** Change:

```js
$scope.editorOptions = Settings.ckeditorSettingsCommunication;
```
to:

```js
$scope.editorOptions = Settings.ckeditorSettings;
```

> Leave `ckeditorSettingsCommunication` in `settings.js` as-is (do not delete — out of scope, and other
> code may reference it; verify with a grep before any removal, which is NOT part of this ticket).

Verification: covered by the Karma spec in F4 and manual smoke in the testing checklist.

---

### Task F2: Replace the compose textarea with the CKEditor-bound textarea

**Files:** Modify `app/views/communication/communication.html` lines **447-456** (the compose block,
inside `data-ng-if="!help.readonlyMessageForm"`).

**Step 1:** Replace the plain textarea (lines 449-454) and the redundant mirror `<div id="message-content">`
(line 455) with a CKEditor-bound textarea on `currentMessage.htmlBody`, matching the výzva attributes:

```html
<textarea ckeditor="editorOptions"
          id="messageBody"
          name="messageBody"
          class="hide-on-print"
          data-ng-model="currentMessage.htmlBody"
          ng-model-options="{ updateOn: 'default blur clear', debounce: { 'default': 500, 'blur': 0, 'clear': 0 } }"></textarea>
```

> Keep the `hide-on-print` class (carried over from the original). Drop the fixed inline
> `height/width/font-size` style and the `rows='3'` — CKEditor manages its own sizing (výzva sets height
> via the directive/config). If a specific height is desired, set it in `ckeditorSettings`, not on the
> textarea; that is a design tweak, not part of this ticket — flag it rather than hand-rolling CSS.

Verification: manual smoke (editor renders with the full toolbar on "write new message").

---

### Task F3: Read-only view binds sanitized `htmlBody`

**Files:** Modify `app/views/communication/communication.html` lines **458-464** (the
`data-ng-if="help.readonlyMessageForm"` block).

**Step 1:** Change the read-only binding from `currentMessage.body` to `currentMessage.htmlBody`
(server-sanitized, safe to render):

```html
<div class='inbox-message no-padding' data-ng-if="help.readonlyMessageForm">
    <div id='emailbody'>
        <p ng-bind-html="currentMessage.htmlBody"></p>
    </div>
</div>
```

> `ng-bind-html` requires `ngSanitize` or a trusted value; the existing read-only view already used
> `ng-bind-html` on `currentMessage.body`, so the app is already configured for it. Because the server
> sanitizes on save, the stored HTML is safe. Do not add `$sce.trustAsHtml` — keep parity with the
> existing pattern.

---

### Task F4: Reply/quote preserves formatting

**Files:** Modify `app/scripts/controllers/communication/communication.js`, `replyOrForwardMessage`
(**lines 289-344**, specifically the quote-building block **335-343**).

**Step 1:** The current code quotes `message.body` as plain text and rewrites `<br>` to newlines
(lines 335-343). Per locked decision, quote `htmlBody` to preserve formatting. Minimal change:
build the quoted prefix as HTML and prepend it to `htmlBody` (not `body`), since the compose now binds
`htmlBody`:

- Build `newBody` (the header lines at 301-333) as HTML — the header already uses `<br>` (line 301, 306);
  replace the `'\r\n'` plain-newline separators in the header with `<br>` so it renders in the editor.
- Replace the body-quoting block (335-343) with:

```js
if (message.htmlBody) {
    newBody += '<blockquote>' + message.htmlBody + '</blockquote>';
}
message.htmlBody = newBody;
delete message.body; // backend re-derives plain text from htmlBody on save
```

> The executor must read the full 289-380 method and keep all the recipient/CC/kyc logic intact —
> only the body source (`body` → `htmlBody`) and the quote rendering change. If the header-string
> construction is heavily plain-text oriented and risky to convert, the safe, faithful minimum is:
> set `message.htmlBody` from the original `message.htmlBody` wrapped in `<blockquote>`, and stop
> touching `message.body` (let the backend derive it). Surface any larger refactor as a decision.

Verification: manual smoke — reply to a formatted message; the quoted original keeps its formatting.

---

### Task F5: Karma spec — compose binds `htmlBody`; existing specs stay green

**Files:** Create `test/spec/controllers/communication.js`
(the only existing spec is `test/spec/controllers/main.js`).

> Reality check (flag to user): the Karma harness (`karma.conf.js`) loads module **`yoemanTestApp`**,
> not the real app module, and the real `CommunicationCtrl` has many injected dependencies
> (`Settings`, `MessageContextManipulator`, `Codebook`, `$filter`, `$rootScope`, etc.). A meaningful
> controller spec needs those mocked and the real app module loaded. The executor should: (1) confirm
> the real Angular module name from `app/scripts/ng.app.js`; (2) write a focused spec that loads that
> module and asserts the locked contract; (3) if the harness cannot bootstrap the controller without
> large mocking scaffolding, scope the spec to the smallest verifiable unit (e.g. that
> `Settings.ckeditorSettings` is the full toolbar and is what the controller assigns) and record the
> rest as manual smoke. Do NOT fabricate green tests.

**Step 1:** Spec intent (adapt module/mocks to reality):

```js
'use strict';

describe('Communication compose', function () {
  beforeEach(module('<REAL_APP_MODULE_NAME>')); // from ng.app.js

  it('uses the full vyzva CKEditor toolbar (ckeditorSettings)', inject(function (Settings) {
    expect(Settings.ckeditorSettings).toBeDefined();
    // full toolbar includes clipboard/styles/links/table that the reduced one omits
    var names = Settings.ckeditorSettings.toolbar_MyToolbar.map(function (g) { return g.name; });
    expect(names).toContain('links');
    expect(names).toContain('insert');
  }));
});
```

**Step 2: Run the client tests.**
Run (from `publicERANET-client`): `npx karma start karma.conf.js --single-run`
Expected: existing `MainCtrl` spec stays green; the new spec passes (or is scoped per the reality note).

---

### Task F6: Commit the frontend slice

**Files:** `app/scripts/controllers/communication/communication.js`,
`app/views/communication/communication.html`, `test/spec/controllers/communication.js`.
(Note: `settings.js` is NOT modified — F1 only switches which existing config the controller uses.)

```bash
git -C C:/Innovis/seas_test/publicERANET-client add -A
git -C C:/Innovis/seas_test/publicERANET-client commit -m "feat(EP-13100, EP-13108): add CKEditor to message compose"
```

Verification: `git -C C:/Innovis/seas_test/publicERANET-client log --oneline -1` shows the exact message.

---

## Verification & testing checklist (run before claiming done — `superpowers:verification-before-completion`)

### Automated
- [ ] Server: `MessageHtmlSanitizerTest` green (script/onerror/javascript-link dropped; basic formatting
      + `rel=nofollow` kept; disallowed style dropped; `toPlainText` strips all tags).
- [ ] Server: `mvn package` BUILD SUCCESS.
- [ ] Client: `npx karma start karma.conf.js --single-run` — existing specs green + new compose spec.

### Liquibase
- [ ] Both changesets (`add_message_html_body_column`, `backfill_message_html_body_from_body`) recorded
      in `DATABASECHANGELOG`; `DESCRIBE message;` shows `html_body LONGTEXT`.
- [ ] Old rows: `SELECT id FROM message WHERE html_body IS NULL` returns 0 rows after backfill.

### Manual smoke (browser, communication module)
- [ ] **Compose:** "write new message" shows the **full výzva toolbar** (clipboard, font/color, links,
      table, source). Type bold + bulleted list + colored text + a table + an http link.
- [ ] **Send → reopen:** open the sent message (read-only view) — all formatting preserved via
      `ng-bind-html` on `htmlBody`.
- [ ] **Draft round-trip:** save as draft, close, reopen the draft — HTML editor reloads with the same
      formatted content; send it; still correct.
- [ ] **Old message render:** open a message created **before** this change — it still renders (its
      `html_body` was backfilled from `body`); no blank body, no raw tags.
- [ ] **Email unchanged:** the notification/email for a sent message still arrives using `body`
      (plain text) — `sendEmail`/`sendNotificationEmail` behavior unchanged.
- [ ] **Reply/forward:** reply to a formatted message — the quoted original keeps its formatting.

### Security (XSS) — the load-bearing test
- [ ] In compose, paste (via Source view) `<script>alert(1)</script>`,
      `<img src=x onerror=alert(1)>`, and a `<a href="javascript:alert(1)">x</a>` link. Send.
- [ ] Also POST a raw message directly to `webresources/sc/...` (the message create endpoint) with a
      malicious `htmlBody` to bypass the client.
- [ ] In the DB, confirm `html_body` has the script/onerror/javascript-link **stripped** and `body` is
      plain text. Reopen in the app — nothing executes.

---

## Open questions / risks (surface to the user; do not unilaterally resolve)

1. **`StringEscapeUtils` source** — `toPlainText` needs entity decoding. Use whichever commons-lang is
   already on the classpath (`commons-lang3` preferred). If neither exists, do **not** add a new
   dependency without a decision; fall back to minimal manual decoding.
2. **owasp-java-html-sanitizer version & Guava** — pin a Java-8-compatible release (e.g. `20220608.1`);
   watch for a Guava transitive clash with the existing WildFly/EE classpath. If a clash surfaces,
   raise it rather than pinning a new Guava silently.
3. **Style-attribute matcher API** — the per-attribute `matching(...)` API varies by sanitizer version.
   Keep the locked property set + `url(`/`expression`/`javascript:` rejection; adapt the syntax to the
   resolved version.
4. **Server test harness** — confirm the server module actually runs JUnit (`src/test/java` may be
   absent). If there is no runner, the sanitizer is verified via the manual XSS checklist; flag the gap.
5. **Karma module/mocks** — `karma.conf.js` loads `yoemanTestApp`, not the real app module, and
   `CommunicationCtrl` has heavy DI. Scope the spec to a verifiable unit (the toolbar contract) rather
   than fabricating a fully-mocked controller test. Do not claim coverage that isn't real.
6. **Reply/quote conversion** — the existing `replyOrForwardMessage` builds a plain-text quote with
   `\r\n` and `>>>` markers. Converting it to HTML faithfully is the riskiest client change; the safe
   minimum (blockquote-wrap `htmlBody`, stop touching `body`) is specified — larger reformatting is a
   decision, not a unilateral change.
7. **`@Basic(optional=false)` on `body`** — `body` is currently non-null at the entity level (line 71).
   Since `body` is now derived from `htmlBody`, an empty draft (no HTML) leaves `body` null. Confirm an
   empty draft can still be saved (the existing `createEmptyMessage` already creates a body-less draft,
   so this is likely fine) — verify during the draft round-trip smoke test.
