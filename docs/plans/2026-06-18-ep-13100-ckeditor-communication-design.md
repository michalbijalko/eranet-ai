# EP-13100 — CKEditor in communication messages (design)

**Story:** EP-13100 · **Dev sub-task:** EP-13108 · **Test sub-task:** EP-13109 · **Epic:** EP-12988
**Commit pair:** `feat(EP-13100, EP-13108): …`

## Goal

Add a rich-text CKEditor to the communication module's *write new message* screen, using the
**full výzva toolbar**, and sanitize message HTML server-side to prevent XSS
(`owasp-java-html-sanitizer`). Acceptance criterion: CKEditor integrated within the
communication module.

## Key findings (existing code)

- Compose body is a plain `<textarea id="messageBody" data-ng-model="currentMessage.body">`
  at `publicERANET-client/app/views/communication/communication.html:449`.
- CKEditor is already integrated in SEAS via the `ckeditor="editorOptions"` directive
  (ng-ckeditor). The výzva screen uses it with `$scope.editorOptions = Settings.ckeditorSettings`.
- The communication controller already sets
  `$scope.editorOptions = Settings.ckeditorSettingsCommunication` (reduced toolbar) at
  `communication.js:74`, but the template never uses it — half-wired.
- `Message` entity stores `body` as `byte[]` → `MessageBodyConverter` → LONGTEXT utf8mb4.
  Save flows through `MessageService.create()` → `BaseService` (no direct DAO).
- `sendEmail()` already does `email.setHtmlMsg(body)`.
- `owasp-java-html-sanitizer` is not yet in `pom.xml`; no existing HTML sanitizer utility.
- EP-13104 (fulltext search in message body) is already tracked — the tag-free `body`
  supports it.

## Decisions (brainstormed & confirmed)

1. **Toolbar:** reuse the full výzva toolbar `Settings.ckeditorSettings` (not the reduced
   `ckeditorSettingsCommunication`).
2. **Data model:** new `html_body` column holds sanitized CKEditor HTML; existing `body` is
   repurposed as tag-free plain text for previews/filter/search. Old messages:
   `html_body = body`.
3. **Plain-text derivation:** backend, on save (client sends only HTML; server strips tags).
4. **Sanitization scope:** every save (draft + send), at the single `create()` choke point.
   New messages only — old stored messages are not retro-sanitized.
5. **Allowlist:** match the toolbar with a constrained inline-`style` allowlist
   (`color, background-color, font-family, font-size, text-align, text-decoration`); links
   limited to `http/https/mailto` with `rel=nofollow`; scripts/iframes/`on*`/`class`/`id`
   dropped.
6. **Email/notifications:** **left unchanged.** `sendEmail()` keeps using `body` (now plain
   text); `sendNotificationEmail()` untouched. Rich HTML is for in-app display/editing only.

## 1. Data model & migration (server)

- `Message` gains `private byte[] htmlBody;` mapped to `@Column(name = "html_body")` reusing
  `MessageBodyConverter` + the Byte array JSON (de)serializers, identical to `body`.
- Liquibase changeset (author `m.bijalko`):
  1. `addColumn` `html_body LONGTEXT CHARACTER SET utf8mb4` on `message` (nullable).
  2. data migration `UPDATE message SET html_body = body` for existing rows.

## 2. Sanitization & save path (server)

- Add dependency `com.googlecode.owasp-java-html-sanitizer:owasp-java-html-sanitizer`
  (Java 8 compatible) to `pom.xml`.
- New helper `MessageHtmlSanitizer` built from one shared `PolicyFactory`:
  - `String sanitize(String rawHtml)` → safe HTML for `html_body`.
  - `String toPlainText(String rawHtml)` → tags stripped for `body`.
- Allowed tags: `b/strong, i/em, u, s/strike, sub, sup, blockquote, p, br, hr, ul/ol/li,
  span, div, a, table/thead/tbody/tr/td/th`. Constrained `style` + link policy as above.
- Wire at the `MessageService.create()` choke point, before `createInternal()`/`BaseService`:
  sanitize `htmlBody`, then set `body` from the stripped HTML. Runs for draft and send.
  Only the entity fields are transformed — the save still flows through `BaseService`.

## 3. Read / email path (server)

- **No changes** to `sendEmail()` / `sendNotificationEmail()`.
- GET endpoint already returns the full `Message`, so `html_body` rides along for the UI; no
  REST change. List/preview keep using plain `body`.

## 4. Frontend — editor wiring (client)

- `communication.html`: replace the plain textarea with
  `<textarea ckeditor="editorOptions" data-ng-model="currentMessage.htmlBody" ...>` using the
  same `ng-model-options` debounce as výzva.
- `communication.js:74`: switch `$scope.editorOptions` to `Settings.ckeditorSettings`.
- Read-only view: `ng-bind-html` `currentMessage.htmlBody` (sanitized server-side, safe).
- Reply/quote: quote `htmlBody` instead of `body` to preserve formatting.

## 5. Commits, testing & sequencing

- Add the row to `docs/TICKETS.md`:
  `CKEditor in communication | EP-13100 | EP-13108`.
- Two repos, two commits (same pair):
  - Server: `feat(EP-13100, EP-13108): sanitize message HTML on save`
  - Client: `feat(EP-13100, EP-13108): add CKEditor to message compose`
- Testing:
  - Karma/Jasmine: compose binds `htmlBody`; existing communication specs stay green.
  - Manual smoke: compose with bold/list/color/table/link → Send → reopen → formatting
    preserved; draft round-trip; old message still renders.
  - Security: paste `<script>` / `<img onerror=…>` / `javascript:` link (or POST raw via API)
    → stored `html_body` stripped, `body` plain text.
- Sequencing: server first (column + sanitizer must exist before the client sends HTML),
  then client. Liquibase runs on deploy.
