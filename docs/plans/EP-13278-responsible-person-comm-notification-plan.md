# EP-13278 — Implementation Plan

**Comms notification e-mail to all responsible persons of a tender**

- **Story / Dev:** `EP-13278` / `EP-13279` · **Test:** `EP-13280` · **Epic:** `EP-12988`
- **Commit format (from `docs/TICKETS.md`):** `feat(EP-13278, EP-13279): <description>`
  One ticket per commit; server slice and client slice may be separate commits, both under the same pair.
- **Authoritative design doc:** `docs/plans/2026-07-21-ep-13278-responsible-person-comm-notification-design.md` (updated in commit `947cff7`)
- **Ticket source note:** The Atlassian MCP is unauthorized in this environment, so EP-13278 could not be
  re-read live. This plan is built against the committed design doc (which enumerates the locked decisions
  and AC #1–#10). **Before execution, re-open EP-13278 in Jira and confirm the 10 acceptance criteria match
  the verification table below.**

---

## Locked decisions (do not revisit)

1. Fan out to all responsible persons **only if an actual addressee of the message is itself a responsible person** of the tender.
2. Responsible person = `ADDITIONAL_ROLE_RESPONSIBLE_PERSON` (role `0`) **only**. Not investment role (2), not committee chairman.
3. Change lives **only** in `getEmailsAndSendNotification()`. Do **not** touch `checkMessageSubjectAndRecipients` or persisted `messageToUsers`.
4. Resolve tender via `MessageToProcurement`; no tender ⇒ skip (excludes qualification-system path).
5. Setting default treated as OFF when the row is absent or `"false"`. The setting is **not confident**
   (`confident` NULL) — matching every existing `setting` INSERT in the codebase.

---

## Code-anchor verification (done — with drift flagged)

| Design-doc anchor | Reality in repo | Status |
|---|---|---|
| Package `sk.eranet.eranet.…` | Actual: `sk.innovis.eranetpublic.server.…` | **Drift — placeholder path.** Use real paths below. |
| `getEmailsAndSendNotification()` ~L874 | Present at **L874** (`@PermitAll private void`) | OK |
| Recipient set built ~L879–881 | `QueryFilter byUserId = QueryFilter.getIn(HasId.PROPERTY_NAME_ID)`; loop **L879–883**; `findAll` **L924–925** | OK (minor line shift) |
| Responsible-person query | Exact live example already in this file at **L969–970**: `systemUserInProcurementService.findByProcurementId(procurementId, isResponsiblePerson)` | OK — reuse it |
| `SystemUserInProcurement.ADDITIONAL_ROLE_RESPONSIBLE_PERSON` = 0 | `SystemUserInProcurement.java:39` | OK |
| Setting read `settingService.getByNameInternal(name)` | Exists; supplier filter in `findAllInternal` is `confident=FALSE OR confident IS NULL`. Row is **not confident** ⇒ passes for suppliers too. | OK — use as-is |
| Setting constants in `Setting.java` | Confirmed (e.g. `SETTING_NAME_AUCITON_CONCAT_STEPS` L55) | OK |
| FE `serverSettings.js` ~L68 | Constants block ends L69–70 (`SETTING_NAME_AUCTION_CONCAT_STEPS`) | OK |
| FE controller getter/save/load | `getAuctionContactStepsSettings` L51–54; `save` L61–83; load L131 | OK |
| FE view AuctionConcatSteps row | `systemSettings.html` L131–147 | OK |
| i18n only in `scripts.no.min/langs/{sk,en}.js` | Confirmed (`SYSTEM_SETTINGS_AUCTION_DEACTIVATE_CHAT` present) | OK |

### Note — setting read works in supplier context because the row is not confident

`getEmailsAndSendNotification()` runs **synchronously in the sender's security context** (called from
message create L196, update L302, send L366), and **a supplier can be the sender** (AC#4). Because the new
setting row is **not confident** (`confident` NULL), `SettingService.findAllInternal`'s supplier filter
(`confident = FALSE OR confident IS NULL`, `SettingService.java:95–99`) lets it through. The standard
`settingService.getByNameInternal(name)` therefore returns the value regardless of who is sending — same as
the AuctionConcatSteps example. No special read path is needed.

---

## Contract between backend and frontend

- **REST:** none new. Frontend reuses `webresources/sc/setting/bulkSave` (and the settings query) —
  `ApplicationConfig.java` needs **no** change.
- **Shared key (must match byte-for-byte):** setting name string
  `"ProcurementResponsiblePersonCommunicationNotification"` — backend constant and frontend constant must be identical.
- **Values:** `"true"` (ON) / `"false"` or absent (OFF).

---

# BACKEND slice (`EP-13279`)

Java EE 7 · module `publicERANET-server` · package `sk.innovis.eranetpublic.server`.

### B1 — Add the setting-name constant
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/dto/Setting.java`
- Add next to the other `SETTING_NAME_*` constants (~L55):
  ```java
  public static final String SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION =
          "ProcurementResponsiblePersonCommunicationNotification";
  ```
- **Verify:** compiles; string exactly equals the frontend constant (step F1).

### B2 — Add the fan-out expansion in `getEmailsAndSendNotification()`
- **File:** `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/service/MessageService.java`
- **Method:** `getEmailsAndSendNotification(Message message)` (L874). `settingService` is already injected (L106);
  `systemUserInProcurementService` is already used in this method (L891).
- **Where:** after the addressee `byUserId` filter is populated (after the loop at L879–883) and **before**
  `if (!byUserId.getFilterValues().isEmpty())` at L923. Reuse the procurement resolved in the existing
  `MessageToProcurement` loop (L886–900) — capture its id rather than re-querying.
- **Logic (extract into well-named private helpers — locked decision, and CLAUDE.md rule 7):**
  1. **Module guard (AC #8):** if no `MessageToProcurement` / no resolved procurement id ⇒ skip expansion, leave behaviour unchanged. (Qualification-system path is thereby excluded.)
  2. **Setting gate (AC #7):** read via the standard, layer-correct
     `settingService.getByNameInternal(Setting.SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION)`
     (matches the AuctionConcatSteps example; works in supplier context because the row is not confident).
     Enabled iff `setting != null && "true".equals(setting.getValue())`; else skip.
  3. **Load responsible persons (role 0 only):** reuse the existing pattern from this file (L969–970):
     ```java
     final QueryFilter isResponsiblePerson = QueryFilter.getEqual(
         SystemUserInProcurement.PROPERTY_NAME_ADDITIONAL_ROLE,
         SystemUserInProcurement.ADDITIONAL_ROLE_RESPONSIBLE_PERSON);
     final FindResult<SystemUserInProcurement> responsiblePersons =
         systemUserInProcurementService.findByProcurementId(procurementId, isResponsiblePerson);
     ```
     Collect their `getSystemUserId()` into a `Set<Integer>`. (Queried live at send time ⇒ AC #9 for free.)
  4. **Trigger check (locked decision 1):** proceed only if the intersection of the current addressee ids
     (`byUserId.getFilterValues()`, which are the non-sender, non-null `systemUserId`s from L880–882) and the
     responsible-person id set is **non-empty**. Otherwise leave the recipient set unchanged.
  5. **Union (AC #3/#4/#5):** add every responsible-person `systemUserId` into `byUserId`
     (`byUserId.addFilterValue(id)`), skipping any already present. One id set → one `findAll` (L924) →
     **automatic dedup, one e-mail per person** (AC #5).
  6. **Supplier circle untouched (AC #6):** this path only ever adds internal `systemUserId`s; supplier-bound
     notifications (`systemUserId == null`) are never added — confirm no code path here touches them.
- **Suggested helpers:** `resolveProcurementIdForNotification(message)`,
  `isResponsiblePersonCommunicationNotificationEnabled()`,
  `collectResponsiblePersonUserIds(procurementId)`,
  `anyAddresseeIsResponsiblePerson(currentAddresseeIds, responsibleIds)`.
- **Do NOT touch:** `checkMessageSubjectAndRecipients`, persisted `messageToUsers`, e-mail body/subject
  building (AC #10 — content/format unchanged), or the qualification-system branch (L902–916).
- **Verify:** `mvn -pl publicERANET-server compile` succeeds; manual trace of the five verification scenarios
  below against the new code.

### B3 — Seed the setting row (default OFF, not confident) via Liquibase
- **Why:** provide a default-OFF row so the feature reads `"false"` before an admin ever toggles it. The row
  is **not confident** (`confident` NULL), matching every existing `setting` INSERT (verified across
  `src/main/sql` history; even `2.4.0/db.changelog-EP6398.xml` leaves `ProcurementAnnouncementNotification`
  confident NULL). The admin's `setSetting` reuses this seeded row's id, so no duplicate is inserted.
- **New file:** `publicERANET-server/src/main/sql/2.11.0/db.changelog-EP13279.xml`
  (2.11.0 is the current active version folder — EP-13114/13108/13112 live there). **Author `m.bijalko`**
  (CLAUDE.md rule 6). Pattern copied from `2.4.0/db.changelog-EP6398.xml` (omit the `confident` column so it stays NULL):
  ```xml
  <changeSet author="m.bijalko" id="seed_procurement_responsible_person_communication_notification_setting">
      <sql>INSERT INTO `setting` (`name`, `value`)
           VALUES ('ProcurementResponsiblePersonCommunicationNotification', 'false');</sql>
      <rollback>DELETE FROM `setting`
           WHERE `name` = 'ProcurementResponsiblePersonCommunicationNotification';</rollback>
  </changeSet>
  ```
- **Register:** add an `<include>` for this file in
  `publicERANET-server/src/main/sql/db.changelog-master.xml` immediately before `</databaseChangeLog>`
  (after L713):
  ```xml
  <include file=".\2.11.0\db.changelog-EP13279.xml" relativeToChangelogFile="true"/>
  ```
- **Verify:** Liquibase update runs clean; `SELECT` shows one row, `value='false'`, `confident` NULL; the
  settings query returns it for both admin and supplier roles (not confident).

---

# FRONTEND slice (`EP-13279`)

AngularJS 1.5 (ES5) · module `publicERANET-client`. Mirror the **AuctionConcatSteps** checkbox exactly.

### F1 — Add the setting-name constant
- **File:** `publicERANET-client/app/scripts/service/resources/serverSettings.js`
- In the constants object (next to `SETTING_NAME_AUCTION_CONCAT_STEPS`, L69):
  ```js
  SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION: 'ProcurementResponsiblePersonCommunicationNotification',
  ```
- **Verify:** string identical to backend constant (B1).

### F2 — Controller: load getter + save wiring
- **File:** `publicERANET-client/app/scripts/controllers/companyProfile/systemSettings.js`
- Add a getter mirroring `getAuctionContactStepsSettings` (L51–54); absent ⇒ `false` (default OFF):
  ```js
  var getProcurementResponsiblePersonCommunicationNotificationSettings = function () {
      var s = ServerSettings.getSetting(ServerSettings.SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION);
      return s && (s.value === 'true' || s.value === true);
  };
  ```
- In `save()` (L61–83): build the setting and add it to `settingsToSave` (L73–74):
  ```js
  var responsiblePersonCommNotification = ServerSettings.setSetting(
      ServerSettings.SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION,
      $scope.help.procurementResponsiblePersonCommunicationNotification);
  // ...push responsiblePersonCommNotification into the settingsToSave array
  ```
- In the `loadSettings` callback (near L131): set the scope flag:
  ```js
  $scope.help.procurementResponsiblePersonCommunicationNotification =
      getProcurementResponsiblePersonCommunicationNotificationSettings();
  ```
- **Verify:** toggling and saving persists `'true'`/`'false'`; reload reflects the stored value.

### F3 — View: admin-only checkbox row + info tooltip
- **File:** `publicERANET-client/app/views/companyProfile/systemSettings.html`
- Copy the AuctionConcatSteps row (L131–147). Keep `data-ng-if="$root.isSystemAdmin()"`; bind
  `data-ng-model='help.procurementResponsiblePersonCommunicationNotification'`; label uses the new i18n key;
  add an "i" tooltip reusing the existing `uib-tooltip` directive (do not hand-roll):
  ```html
  <label class='label'>
      {{'SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION'|translate}}
      <i class="fa fa-info-circle"
         uib-tooltip="{{'SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION_TOOLTIP'|translate}}"></i>
  </label>
  ```
- **Verify:** row shows only for system admins; checkbox reflects/edits the flag; tooltip renders the translated text.

### F4 — i18n (both files, English key)
- **Files:** `publicERANET-client/app/scripts.no.min/langs/sk.js` **and**
  `publicERANET-client/app/scripts.no.min/langs/en.js` (only location — no `scripts/langs` edit).
- Add both keys to each file:
  - `SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION`
    - SK: `"Notifikačné emaily pre zodpovednú osobu – komunikácia v zákazke"`
    - EN: `"Notification e-mails to the responsible person – tender communication"`
  - `SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION_TOOLTIP`
    - SK: `"Notifikácie o novej správe v komunikácii k zákazke sa odošlú všetkým zodpovedným osobám zákazky, aj keď neboli priamym adresátom správy."`
    - EN: `"Notifications about a new message in the tender communication are sent to all responsible persons of the tender, even if they were not a direct addressee of the message."`
- **Verify:** both languages render (no raw key on screen); no duplicate keys introduced.

### F5 — Client tests (Karma/Jasmine)
- If a spec exists for `systemSettings` controller, extend it to assert: getter returns `false` when the
  setting is absent, `true` when `value==='true'`; `save()` includes the new setting in the `bulkSave`
  payload. Otherwise, at minimum manual smoke test (below). Run `grunt test` / `karma start`.

---

## Verification — steps → acceptance criteria

Fixture: tender with responsible persons **A** and **B** (role 0), setting **ON**.

| # | Scenario | Expected | Covered by |
|---|---|---|---|
| AC#1 | Feature exists behind the admin setting | Admin-only checkbox, default OFF | F1–F4, B3 |
| AC#2 | Setting persists / reloads | Value saved via `bulkSave`, reflected on reload | F2, B3 |
| AC#3 | Supplier message addressed to A | A **and** B notified (read works in supplier context — row not confident) | B2.2/2.5 |
| AC#4 | Internal message addressed to A | A **and** B notified | B2.4/2.5 |
| AC#5 | Message addressed to A **and** B | Exactly one e-mail each (single id set → one `findAll`) | B2.5 |
| AC#6 | Notification destined for the supplier | Supplier only, unchanged | B2.6 |
| AC#7 | Setting OFF | Only the addressee notified | B2.2 |
| AC#8 | Other modules (KS/qualification, no `MessageToProcurement`) | No fan-out | B2.1 |
| AC#9 | Change responsible-person list mid-tender | Only messages sent afterwards are affected (live query) | B2.3 |
| AC#10 | E-mail content/format | Unchanged | B2 (body building untouched) |
| — | Message to a non-responsible internal user | No fan-out (trigger not met) | B2.4 |

Before marking done: `superpowers:verification-before-completion` — build the server, run client tests,
smoke-test the five scenarios in the running app, and confirm against the live EP-13278 acceptance criteria.

---

## Out of scope (from design doc)
No change to persisted recipients / visibility / threading; no change to supplier-bound notifications;
no change to the qualification-system path; no retroactive re-send for past messages.

## Open questions / risks
1. **Re-read EP-13278 in Jira** once Atlassian is authorized; reconcile the AC table if any criterion differs.
2. Confirm `2.11.0` is still the correct target changelog folder at execution time (append, do not renumber existing changesets).
