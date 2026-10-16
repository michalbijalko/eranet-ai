# Batch 2 — Externé požiadavky port to `trnavavuc_test` (EP-11309 + EP-11296)

**Effort:** Batch 2 of the EP-13263 merge (Externé požiadavky OvZP), continuing the cherry-pick-and-adapt port established in [`docs/EP-13263_merge_analyza.md`](../EP-13263_merge_analyza.md).
**Source of truth:** `origin/poseidon-test` · **Target:** `trnavavuc_test` (server + client)
**Working branch:** `feature/ttsk-merge-cps` (both repos)
**Method:** manual port between long-diverged branches (common ancestor Feb 2023) — `git cherry-pick -x` where an original commit applies cleanly, otherwise an adaptation commit under the batch Story/Dev pair. This is **not** a git merge.
**Tickets ported:** EP-11309 (configurable approval-instruction notice) and EP-11296 (observer notification on request approval).
**Hard requirement:** both features ship with their switch **OFF** so current TTSK behaviour is unchanged out of the box.

> **DECIDED — Story/Dev pair & commit strategy.**
> **ALWAYS `git cherry-pick -x` the original PSK commit and resolve conflicts** (even when adaptation is heavy — e.g. strip the EP-11593 Prešov email text and the redundant EJB during conflict resolution). The original commit (`feat(EP-11309): …` / `feat(EP-11296): …`, original author, `(cherry picked from …)`) must ALWAYS be present. Use **Story EP-13263 → Dev EP-13264** ONLY for the leftover TTSK-specific delta that remains after resolving conflicts (here: flipping the two seeded Setting values to ship the switches OFF). The `docs/TICKETS.md` row (currently labelled *"1. dávka"*) will be relabelled to cover the whole Externé požiadavky merge. See memory `[[merge-always-cherry-pick-original]]`.

---

## 0. What already exists on target (verified) — do NOT re-port

| Concern | Target state | Evidence |
|---|---|---|
| Observer plumbing (service, entity, group type `externalRequestObserver`) | present from batch-1 EP-11295 | `ExternalRequestService.java:113` EJB field `systemUserAsObserverInExternalRequestInOrganizationDirectoryService`; used at `:360` |
| `SystemUserAsObserverInExternalRequestInOrganizationDirectory.getSystemUser()` | present | entity `:63` |
| `ExternalRequest.getCreationAuthorId()` | present | `ExternalRequest.java:635` |
| Detail-controller load of the instruction setting (originally EP-5258) | **already present** — do NOT re-add | `controllers/planningExternal/editExternalRequestBase.js:65` (`= null`) and `:197` (`= ServerSettings.getSetting(ServerSettings.SETTING_NAME_EXTERNAL_REQUEST_INSTRUCTIONS_FOR_APPROVAL)`) |
| `deleteRequestObserver` in settings controller | present from batch-1 | `controllers/companyProfile/externalRequestSettings.js:195` |
| lang key `SYSTEM_SETTINGS_INSTRUCTIONS_FOR_APPROVAL` | present (sk + en) | `langs/sk.js:3876`, `langs/en.js:3718` |
| Imports `FindResult`, `FindParameters`, `Collectors`, observer entity | present (used at `:359-361`) | no new imports needed for EP-11296 server |

**Consequence for EP-11309 client:** the detail controller at `:197` already references `ServerSettings.SETTING_NAME_EXTERNAL_REQUEST_INSTRUCTIONS_FOR_APPROVAL`, but that key is **not yet defined** in `serverSettings.js` (target only has `SETTING_NAME_EXTERNAL_REQUEST_HIDE_EMPTY_POSITION_IN_APPROVAL` at `:119`). So `getSetting` currently returns `undefined`. Porting the `serverSettings.js` key (from `a91236fe5`) is what makes the existing load line functional — no extra load line is added.

**Liquibase folder note:** target has **no `src/main/sql/2.6.0/` folder** (source keeps both changesets there). Target's newest folder is `2.4.0/` and the last master include is `.\2.4.0\db.changelog-EP10516.xml` (`db.changelog-master.xml:749`). New changesets go under **`src/main/sql/2.4.0/`** and their includes are appended after line 749.

---

## 1. Per-commit decision matrix (cherry-pick `-x` vs adapt)

| # | Source commit | Repo | Decision | Why |
|---|---|---|---|---|
| 1 | `4144b7c3c` (EP-11309 Liquibase) | server | **ADAPT** | seed value must be **empty** (source seeds a non-empty Slovak default); source path `2.6.0/` absent on target |
| 2 | `a91236fe5` (EP-11309 client) | client | **cherry-pick `-x`, expect conflict → adapt** | additive, but batch-1 shifted context in `externalRequestSettings.js`/`.html` |
| 3 | `1a4be5650` (EP-11296 Setting + Liquibase) | server | **cherry-pick `-x` → conflict on master.xml** | git rename-detection lands the changeset in `2.4.0/`; keep only the EP11296 include (drop poseidon's EP11305/11320/11288/EP7361). Then a follow-up EP-13263 commit flips the seed to `'false'` |
| 4 | `1fc549834` (EP-11296 service) | server | **cherry-pick `-x` → conflict on ExternalRequestService.java** | resolve the conflict by dropping the EP-11593 (Prešov) email text + the redundant EJB + the incompatible caller-side restructuring; keep target's email text and reuse the existing observer EJB. Original commit preserved |
| 5 | `2b1389610` (EP-11296 client) | client | **cherry-pick `-x` (after #2), expect conflict → resolve** | depends on EP-11309 client context; batch-1 shifted `externalRequestSettings.*` |

Two follow-up EP-13263 commits flip the seeds OFF (EP-11309 → `''`, EP-11296 → `'false'`) — the only leftover TTSK-specific delta.

**Apply in this order:** 1 → 2 → 3 → 4 → 5, then the two OFF-seed commits.

---

## 2. EP-11309 — configurable approval-instruction notice

**Feature:** Setting `ExternalRequestInstructionsForApproval` (editable text under company-profile → external-request settings) is shown as a **red notice** on the external-request approval detail; it renders only when the value is non-empty.
**OFF-by-default mechanism:** the notice is gated on a non-empty value (`data-ng-if="help.instructionsForApproval && help.instructionsForApproval.value"`). Seeding the setting **empty** keeps it hidden with zero client changes needed for the "off" state.

### 2A. Backend (server)

**Step 1 — create the Liquibase changeset (adapted, empty seed).**
- **Create:** `src/main/sql/2.4.0/db.changelog-EP11309.xml`
- **Pattern / example:** copy source `4144b7c3c`'s `2.6.0/db.changelog-EP11309.xml`, but **change the value to empty**:
  ```xml
  <changeSet id="insert_ExternalRequestInstructionsForApproval_setting" author="m.bijalko">
      <sql>
          INSERT INTO `setting` (`name`, `value`)
          VALUES ('ExternalRequestInstructionsForApproval', '');
      </sql>
      <rollback></rollback>
  </changeSet>
  ```
  - Raw SQL is allowed here (INSERT only) per the DB rule.
  - **DECIDED — author `m.bijalko`.** The seed value differs from source (empty vs the PSK default), so this is a **new** changeset on `trnavavuc_test` → author `m.bijalko` per CLAUDE.md rule 6. Provenance is preserved by referencing source `4144b7c3c` in the commit body.
- **Edit:** `src/main/sql/db.changelog-master.xml` — append after line 749:
  `<include file=".\2.4.0\db.changelog-EP11309.xml" relativeToChangelogFile="true"/>`
- **Verify:** Liquibase validates (`mvn ... liquibase:validate` or clean deploy); `SELECT value FROM setting WHERE name='ExternalRequestInstructionsForApproval'` returns an empty string.
- **Commit:** `feat(EP-13263, EP-13264): seed ExternalRequestInstructionsForApproval empty` *(pending Story/Dev decision; reference source `4144b7c3c`)*.

### 2B. Frontend (client)

**Step 2 — port `a91236fe5` (attempt cherry-pick, resolve to adapt).**
- Run `git cherry-pick -x a91236fe5`. Expected clean on `serverSettings.js`; expected **conflict** on `controllers/companyProfile/externalRequestSettings.js` and `views/companyProfile/externalRequestSettings.html` (batch-1 shifted context); `views/planningExternal/editExternalRequestBase.html` may conflict due to neighbouring batch-1 ZFK→FK edits.
- Files and what each must end up containing:
  1. **`app/scripts/service/resources/serverSettings.js`** — add key `SETTING_NAME_EXTERNAL_REQUEST_INSTRUCTIONS_FOR_APPROVAL: 'ExternalRequestInstructionsForApproval'` (near existing `SETTING_NAME_INTERNAL_REQUEST_INSTRUCTIONS_FOR_APPROVAL`). This activates the already-present detail-controller load at `editExternalRequestBase.js:197`.
  2. **`app/scripts/controllers/companyProfile/externalRequestSettings.js`** — add `getExternalRequestInstructionsForApprovalSettings()` (returns `.value` or `''`); add `instructionsForApproval` to the `setSetting(...)` block and to the `settingsToSave` array; assign `$scope.help.instructionsForApproval = getExternalRequestInstructionsForApprovalSettings()` in the load block. Preserve target's existing structure (do not drop batch-1's `deleteRequestObserver`).
  3. **`app/views/companyProfile/externalRequestSettings.html`** — add the `SYSTEM_SETTINGS_INSTRUCTIONS_FOR_APPROVAL` heading + `textarea` bound to `help.instructionsForApproval` (source block, `maxlength=250`, `rows=3`).
  4. **`app/views/planningExternal/editExternalRequestBase.html`** — at the confirmancePersons row (target `:659-661`, currently `col col-5`): change that section to `col col-4` and add the notice section:
     ```html
     <section class='col col-5' data-ng-if="$index === 0">
         <div data-ng-if="help.instructionsForApproval && help.instructionsForApproval.value">
             <span style="color:red">{{help.instructionsForApproval.value}}</span>
         </div>
     </section>
     ```
     *(Note: fix the source's unbalanced `</section>` — the source hunk is missing a closing `</div>`; close both tags.)*
- **Do NOT** add any new load line in `editExternalRequestBase.js` — lines 65 and 197 already do it (EP-5258).
- **Verify OFF-default:** with the setting empty, the settings textarea shows blank; the approval detail shows **no** red notice. Toggle ON = type text in settings, save, reopen a request approval detail → red notice appears.
- **Commit:** if cherry-pick stays clean, keep the original `-x` message; otherwise `feat(EP-13263, EP-13264): store and show external request instruction for approval` *(reference `a91236fe5`)*.

---

## 3. EP-11296 — observer notification on request approval

**Feature:** the "request confirmed" email gains a second recipient group — the request's observers — gated by Setting `ExternalRequestConfirmationNotificationToObservers`. Author notification is unchanged.
**OFF-by-default mechanism:** seed the setting `'false'`; when off, only the author is emailed (identical to today).

### 3A. Backend — setting constant + Liquibase (adapt `1a4be5650`)

**Step 3.**
- **Edit** `src/main/java/sk/innovis/eranetpublic/server/dto/Setting.java` — after line 91 (`SETTING_NAME_EXTERNAL_REQUEST_APPROVE_ORGANIZATION_CONTROL`) add:
  ```java
  public static final String SETTING_NAME_EXTERNAL_REQUEST_CONFIRMATION_NOTIFICATION_TO_OBSERVERS = "ExternalRequestConfirmationNotificationToObservers";
  ```
- **Create** `src/main/sql/2.4.0/db.changelog-EP11296.xml` — copy source but **seed `'false'`**:
  ```xml
  <changeSet id="insert_ExternalRequestConfirmationNotificationToObservers_setting" author="m.bijalko">
      <sql>
          INSERT INTO `setting` (`name`, `value`)
          VALUES ('ExternalRequestConfirmationNotificationToObservers', 'false');
      </sql>
      <rollback></rollback>
  </changeSet>
  ```
  (author `m.bijalko` — new changeset, seed differs from source; same decision as Step 1).
- **Edit** `src/main/sql/db.changelog-master.xml` — append include after the EP-11309 include:
  `<include file=".\2.4.0\db.changelog-EP11296.xml" relativeToChangelogFile="true"/>`
- **Verify:** setting value is `'false'` in DB; Setting.java compiles.
- **Commit:** `feat(EP-13263, EP-13264): add ExternalRequestConfirmationNotificationToObservers setting (off by default)` *(reference `1a4be5650`)*.

### 3B. Backend — service refactor (adapt `1fc549834`, hand-written)

**Cherry-pick `-x 1fc549834`** and resolve the `ExternalRequestService.java` conflict to the **minimal, behaviour-preserving** end-state below — i.e. drop from the incoming diff the EP-11593 Prešov email body, the redundant EJB, and the caller-side restructuring, keeping target's email text and reusing the existing observer EJB. This preserves the original `feat(EP-11296): sending external request confirmation notification when settings is turned on` commit while landing exactly the adapted content.

**Target confirmation path today (verified):**
- `checkConfirmationState(...)` (`:660-698`) sets the status **and** calls `sendNotificationToAuthor(externalRequest, true)` **inline** at `:690` and `:693`, then `return true`.
- `sendNotificationToAuthor(...)` (`:851-927`) builds `recipients = [author]`, builds the email body inline (target's own text: `" v časti Požiadavky."`, **no** Prešov block), and sends.
- Other callers of `sendNotificationToAuthor`: rejections (`:275`, `:594`), `confirmIfPossible` transition (`:653`), `checkConfirmationStateCps` ZFK-finished (`:727`), reactivate (`:767`).

**Step 4 — edits (keep target's message text throughout):**

1. **Extract send/build into `sendNotificationToRecipients`.** Move the body of `sendNotificationToAuthor` from the skip-check through the `try/catch` send (`:852-926`) into a new method that takes the recipient list as a parameter:
   ```java
   @PermitAll
   private void sendNotificationToRecipients(final ExternalRequest externalRequest, final List<String> recipients, boolean confirmed) {
       if (externalRequest.toSkipNotification()) { externalRequest.skipNotification(); return; }
       final Setting hostSetting = settingService.getByNameInternal(Setting.SETTING_NAME_HOST);
       final Message message = new Message();
       message.setEmailBccRecipients(String.join(";", recipients));
       // ... TARGET's existing body verbatim (subject, "Dobrý deň", confirmed/rejected branches,
       //     " v časti Požiadavky.", signature) ...
       message.setBody(builder.toString().getBytes(PublicConstants.STRING_CHARSET_ENCODING));
       try { messageService.sendEmail(message); }
       catch (EmailException | IOException ex) { logger.error("Chyba pri posielani notifikacneho emailu pri prijati poziadavky: {}", ex.toString()); }
   }
   ```

2. **Reduce `sendNotificationToAuthor` to a thin wrapper** (unchanged behaviour for all its current callers):
   ```java
   @PermitAll
   private void sendNotificationToAuthor(final ExternalRequest externalRequest, boolean confirmed) {
       final List<String> recipients = new ArrayList();
       recipients.add(externalRequest.getCreationAuthor().getEmail());
       sendNotificationToRecipients(externalRequest, recipients, confirmed);
   }
   ```

3. **Add `sendNotificationAboutConfirmation`** (author + observers, gated by the setting):
   ```java
   @PermitAll
   private void sendNotificationAboutConfirmation(final ExternalRequest externalRequest) {
       final List<String> recipients = new ArrayList();
       recipients.add(externalRequest.getCreationAuthor().getEmail());
       Setting settingNotificationToObservers = settingService.getByNameInternal(Setting.SETTING_NAME_EXTERNAL_REQUEST_CONFIRMATION_NOTIFICATION_TO_OBSERVERS);
       boolean sendEmailToObservers = settingNotificationToObservers != null
               && settingNotificationToObservers.getValue() != null
               && settingNotificationToObservers.getValue().equals("true");
       if (sendEmailToObservers) {
           FindResult findResult = systemUserAsObserverInExternalRequestInOrganizationDirectoryService.findAllInternal(new FindParameters());
           if (findResult.isNotEmpty()) {
               List<SystemUserAsObserverInExternalRequestInOrganizationDirectory> listOfObservers = findResult.getItems();
               // EP-11296: faithful port of poseidon-test — compares observer-row id to author's SystemUser id
               // (different id spaces), so an author who is also an observer is not excluded and may be notified
               // twice. Kept as-is intentionally; to be corrected here and on poseidon-test in a follow-up.
               listOfObservers.stream()
                       .filter(observer -> !observer.getId().equals(externalRequest.getCreationAuthorId()))
                       .forEach(observer -> recipients.add(observer.getSystemUser().getEmail()));
           }
       }
       sendNotificationToRecipients(externalRequest, recipients, true);
   }
   ```
   - **Reuse the existing EJB** `systemUserAsObserverInExternalRequestInOrganizationDirectoryService` (`:113`). Do **not** add the source's second, redundant `externalRequestObserversService` field.
   - No new imports (`FindResult`, `FindParameters`, entity, `List` all already used at `:359-361`).

4. **Route only the `checkConfirmationState` confirmed path through the new method.** In `checkConfirmationState` replace the two inline calls:
   - `:690` `sendNotificationToAuthor(externalRequest, true);` → `sendNotificationAboutConfirmation(externalRequest);`
   - `:693` `sendNotificationToAuthor(externalRequest, true);` → `sendNotificationAboutConfirmation(externalRequest);`
   - Leave `checkConfirmationStateCps` (`:727`), `confirmIfPossible` (`:653`), rejections (`:275`, `:594`), and reactivate (`:767`) calling `sendNotificationToAuthor` unchanged → author-only, exactly as today.

   > This mirrors the source's *intent* (observers only on the main confirmation path) while avoiding the source's larger caller-side restructuring — observable behaviour is identical when the switch is off, and the author path is untouched everywhere else.

   > **DECIDED — faithful port + marker.** Keep the source's `observer.getId()` comparison as-is (replicates the poseidon quirk where an author-who-is-observer may be notified twice), with the explanatory comment above. It will be corrected here **and** on poseidon-test in a later follow-up. The corrected form would be `!observer.getSystemUser().getId().equals(externalRequest.getCreationAuthorId())`. Also recorded in `docs/EP-13263_merge_analyza.md`.

- **Verify:** compiles; with the setting `'false'`, confirmation email goes to the author only (unchanged). With `'true'`, observers of that request are added as BCC. Rejection and ZFK-finished emails are unchanged (author only).
- **Commit:** `feat(EP-13263, EP-13264): send request-confirmation notification to observers when enabled` *(reference `1fc549834`)*.

### 3C. Frontend — settings toggle + labels (port `2b1389610`)

**Step 5 — port `2b1389610` (after Step 2 is in the tree).**
- Run `git cherry-pick -x 2b1389610`. Expected clean on `langs/*` and `serverSettings.js`; expected **conflict** on `externalRequestSettings.js`/`.html` (batch-1 + EP-11309 context).
- End state per file:
  1. **`serverSettings.js`** — add key `SETTING_NAME_EXTERNAL_REQUEST_CONFIRMATION_NOTIFICATION_TO_OBSERVERS: 'ExternalRequestConfirmationNotificationToObservers'`.
  2. **`controllers/companyProfile/externalRequestSettings.js`** — add `getConfirmationNotificationToObserversSettings()` (returns `value === 'true' || value === true`); add `confirmationNotificationToObservers` to the `setSetting` block and to `settingsToSave`; assign `$scope.help.confirmationNotificationToObservers` in the load block. Keep the EP-11309 `instructionsForApproval` lines already added in Step 2.
  3. **`views/companyProfile/externalRequestSettings.html`** — add the checkbox row (label `EXTERNAL_REQUEST_SETTING_CONFIRMATION_NOTIFICATION_TO_OBSERVERS`, bound to `help.confirmationNotificationToObservers`) in the external-request settings fieldset.
  4. **`langs/sk.js`** — `"EXTERNAL_REQUEST_SETTING_CONFIRMATION_NOTIFICATION_TO_OBSERVERS":"Notifikácia pre pozorovateľov pri schválení požiadavky"`.
  5. **`langs/en.js`** — `"EXTERNAL_REQUEST_SETTING_CONFIRMATION_NOTIFICATION_TO_OBSERVERS":"Confirmation notification to observers"`.
- **Verify OFF-default:** with the setting `'false'`, the checkbox loads **unchecked**. Toggling it on and saving persists `'true'`.
- **Commit:** keep the `-x` message if clean, else `feat(EP-13263, EP-13264): add confirmation-notification-to-observers setting toggle` *(reference `2b1389610`)*.

---

## 4. Verification checklist

**Build / migrate**
- [ ] Server compiles; `db.changelog-master.xml` validates; both new changesets apply on a clean DB.
- [ ] `setting` table: `ExternalRequestInstructionsForApproval` = `''`, `ExternalRequestConfirmationNotificationToObservers` = `'false'`.
- [ ] Client builds (Grunt) with no unresolved conflict markers; `langs/sk.js`/`en.js` remain valid.

**OFF-by-default (must be true out of the box — no behaviour change vs current TTSK)**
- [ ] EP-11309: approval detail shows **no** red notice.
- [ ] EP-11309: settings textarea is empty.
- [ ] EP-11296: confirming a request emails the **author only** (no observers), identical to today.
- [ ] EP-11296: settings checkbox is **unchecked**.
- [ ] Rejection emails and ZFK-finished emails unchanged (author only).

**Toggle ON (feature works)**
- [ ] EP-11309: set instruction text in settings → save → open a request approval detail → red notice shows the text; clear the text → notice disappears.
- [ ] EP-11296: check the observers-notification toggle → save → confirm a request that has observers → the request's observers receive the confirmation email (BCC) alongside the author.
- [ ] EP-11296: with the toggle on but a request that has no observers → author still notified, no error.

**Regression**
- [ ] Observer administration section (batch-1 EP-11295) still works.
- [ ] `checkConfirmationStateCps` / ZFK flows still notify the author.
- [ ] `sendNotificationToAuthor` callers (reject, transition, reactivate) unchanged.

**Client unit tests**
- [ ] Run Karma/Jasmine; no new failures in the company-profile settings or external-request controllers.

---

## 5. Out of scope (do not port)
- **EP-11593** Prešov-region email body carried inside source `1fc549834`'s `createConfirmationMessage` — keep target's existing confirmation text.
- **EP-11620** observer *selection* for the notification — explicitly out of scope.
- Source's duplicate EJB `externalRequestObserversService` — reuse the existing field instead.
- Source's caller-side send restructuring in `update()` / `confirmIfPossible()` — not needed; target keeps sending inside `checkConfirmationState`.

## 6. Risks
- **R1 — client conflicts.** `externalRequestSettings.js`/`.html` diverged in batch-1; both client cherry-picks will likely need manual conflict resolution. Mitigation: apply EP-11309 client before EP-11296 client, resolve preserving target structure.
- **R2 — observer double-email edge case.** DECIDED: faithful port kept with an explanatory comment (§3B); to be corrected here and on poseidon-test in a follow-up. Low impact (BCC).
- **R3 — Liquibase author / folder placement.** DECIDED: new adapted changesets under `2.4.0/` authored `m.bijalko`.
- **R4 — Story/Dev pair.** DECIDED: cherry-pick `-x` to preserve original commits; EP-13263/EP-13264 only for hand-adapted changes.
