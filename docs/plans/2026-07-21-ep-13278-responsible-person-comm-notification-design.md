# EP-13278 — Notification e-mails on tender communication for all responsible persons

**Design document** · 2026-07-21
Story: EP-13278 · Dev sub-task: EP-13279 · Test sub-task: EP-13280 · Epic: EP-12988

## Goal

Add a global system-settings checkbox that, when enabled, delivers the "new message in
tender communication" notification e-mail to **all responsible persons** of the tender —
not only the direct addressee. Default **OFF**; applies **only to the Zákazky (tender)
module**; e-mail content and format unchanged.

## Locked decisions (from brainstorming)

1. **Trigger** — expand to all responsible persons **only if an actual addressee of the
   message is itself a responsible person** of the tender. A message to a non-responsible
   internal user does not fan out.
2. **Who counts as a responsible person** — `ADDITIONAL_ROLE_RESPONSIBLE_PERSON` (role `0`)
   **only**. Excludes `RESPONSIBLE_PERSON_INVESTMENT` (2) and the committee chairman.
3. **Placement** — the change lives **only in the notification fan-out**
   (`getEmailsAndSendNotification`), not in `checkMessageSubjectAndRecipients`. The stored
   `messageToUsers` (visibility, threading, "to" list) is left unchanged; we only widen who
   receives the e-mail.
4. **Module guard** — resolve the tender via `MessageToProcurement`; no tender ⇒ skip.
   Excludes the qualification-system path.
5. **Setting storage** — `confident` left `NULL` (matching every existing setting, incl. the
   analogous `ProcurementAnnouncementNotification`); default treated as OFF when the row is
   absent or `"false"`. Not confident so the standard `getByNameInternal` read returns it in
   every context — including a supplier sender — which is required by AC #4.

## Backend

**File:** `publicERANET-server/.../service/MessageService.java`
(+ constant in `dto/Setting.java`).

**Setting.** New name/value row in the `setting` table, seeded via Liquibase with `value
= 'false'` and `confident` left `NULL` (omit the column, per existing convention). Constant:
`SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION =
"ProcurementResponsiblePersonCommunicationNotification"`. Read with
`settingService.getByNameInternal(name)`; enabled when `"true".equals(getValue())`. Because
the row is not confident, this read returns the value regardless of the sender's role (a
supplier can be the sender — AC #4), so no role-independent read variant is needed.

**Logic in `getEmailsAndSendNotification(Message message)` (~`MessageService.java:874`),
applied after the existing recipient-ID set is built and before the `findAll`:**

1. Resolve the tender for the message via `MessageToProcurement`. If none → skip expansion
   (module guard, AC #8).
2. If the setting is OFF → unchanged behavior (AC #7).
3. Query the tender's responsible persons: `SystemUserInProcurement` where
   `procurementId == tender` and `additionalRole == ADDITIONAL_ROLE_RESPONSIBLE_PERSON`
   (role `0` only).
4. **Trigger check** — proceed only if at least one current addressee is in that
   responsible-person set.
5. Union the responsible-person user IDs into the existing recipient user-ID set. Because a
   single ID set feeds one `findAll`, **deduplication is automatic** — one e-mail per person
   (AC #5).
6. Supplier-bound notifications (`systemUserId == null`) are never added by this path, so the
   supplier recipient circle is unchanged (AC #6).

Responsible persons are queried live at send time, so a mid-tender change to the
responsible-person list is respected automatically (AC #9).

Split the new steps into well-named private helpers (e.g. `isResponsiblePersonNotification`,
`collectResponsiblePersonUserIds`) rather than inlining.

## Frontend

Follows the existing `AuctionConcatSteps` checkbox pattern; admin-only; no new UI paradigm.

1. **`app/scripts/service/resources/serverSettings.js`** (~line 68) — add
   `SETTING_NAME_PROCUREMENT_RESPONSIBLE_PERSON_COMMUNICATION_NOTIFICATION:
   'ProcurementResponsiblePersonCommunicationNotification'` (must match the backend string
   exactly).
2. **`app/scripts/controllers/companyProfile/systemSettings.js`** — a getter mirroring
   `getAuctionContactStepsSettings()` sets
   `$scope.help.procurementResponsiblePersonCommunicationNotification` on load (absent ⇒
   `false`, default OFF); `save()` builds the setting via `ServerSettings.setSetting(...)`
   and pushes it into `settingsToSave` for the existing `bulkSave`.
3. **`app/views/companyProfile/systemSettings.html`** — copy the `AuctionConcatSteps` row
   (~lines 131–147): `data-ng-if="$root.isSystemAdmin()"`, an
   `<input type='checkbox' data-ng-model='help.procurementResponsiblePersonCommunicationNotification'>`,
   the translated label, plus an **"i" tooltip** reusing the app-wide `uib-tooltip`
   directive (`<i class="fa fa-info-circle" uib-tooltip="{{'..._TOOLTIP'|translate}}">`).
4. **i18n** — translations live only in `app/scripts.no.min/langs/`. Add to **`sk.js`** and
   **`en.js`**:
   - `SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION`
     — SK: "Notifikačné emaily pre zodpovednú osobu – komunikácia v zákazke".
   - `SYSTEM_SETTINGS_PROCUREMENT_RESPONSIBLE_PERSON_COMM_NOTIFICATION_TOOLTIP`
     — SK: "Notifikácie o novej správe v komunikácii k zákazke sa odošlú všetkým zodpovedným
     osobám zákazky, aj keď neboli priamym adresátom správy."
   - English equivalents for both.

## Verification (acceptance criteria)

Tender with responsible persons A and B, with the setting **ON**:

| Scenario | Expected |
| --- | --- |
| Supplier message addressed to A | A **and** B notified (AC #3, #4) |
| Internal message addressed to A | A **and** B notified (AC #3, #4) |
| Message addressed to A and B | A and B, exactly one e-mail each (AC #5) |
| Notification destined for the supplier | Supplier only, unchanged (AC #6) |
| Message addressed to a non-responsible internal user | No fan-out (trigger decision) |

Setting **OFF** → only the addressee is notified (AC #7). Other modules unaffected (AC #8).
Changing the setting affects only messages sent afterwards (AC #9). E-mail content/format
unchanged (AC #10).

## Out of scope / non-goals

- No change to persisted message recipients, message visibility, or threading.
- No change to supplier-bound notifications.
- No change to the qualification-system communication path.
- No retroactive re-sending of notifications for past messages.

## Estimate

~2–3 dev-days (backend 1–1.5, frontend 0.5–1, verification 0.5). Formal QA tracked under
EP-13280.
