# EP-13133 — Evaluation Activity Log ("Aktivity" in evaluation detail) — Implementation Plan

**Story:** EP-13133 · **Dev:** EP-13166 · **Epic:** EP-13132
**Commit pair (every commit for this ticket):** `feat(EP-13133, EP-13166): <description>`
**Design source of truth:** `docs/plans/2026-07-13-ep-13133-evaluation-activity-log-design.md`
**Plan date:** 2026-07-13

This plan turns the approved design into ordered, verifiable steps. It does **not**
re-open settled decisions. It resolves the two design open items and pins the
CREATED hook by codebase investigation (see "Investigation results").

---

## Investigation results (open items resolved)

1. **Org-unit ("organizačná zložka") field on `SystemUser`.**
   Relation `organizationDirectory` (`@ManyToOne OrganizationDirectory`, FK
   `organization_directory_id`), surfaced to JSON as
   `getOrganizationDirectoryName()` → `organizationDirectory.getName()` (null when
   the user has no org unit). This is exactly what the IO/VO Aktivity component
   renders (`creationAuthor.organizationDirectoryName`). Server resolves it to a
   string, `""` when null.

2. **IO/VO Aktivity component (visual reference).**
   `publicERANET-client/app/views/planning/internalProcurementRequest/editInternalProcurementRequest.html`,
   lines ~1737–1743. The activity line is:
   ```
   {{activity.type | codebookFilter: 'internalProcurementRequestActivityType' | translate}}
   {{::activity.creationAuthor.formattedName}} - {{::activity.creationAuthor.organizationDirectoryName}} ({{::activity.creationDatetime | ourDatetimeFilter}})
   ```
   So: name = `formattedName` (= `lastName + " " + firstName`, i.e. **Priezvisko
   Meno**), separator ` - `, org unit = `organizationDirectoryName`, date via
   `ourDatetimeFilter`, label via a translate filter. The backend analog entity is
   `InternalProcurementRequestActivity` (table `internal_procurement_request_activity`)
   — copy its entity shape for `SrRatingActivity`.

3. **CREATED hook point.**
   `SrRatingHeader` rows are created **only** via
   `SrRatingHeaderService.createInternal(rating)`, called from
   `ScheduleService.generateInitalRatingForEndedAgreement()` /
   `generateInitalRatingForLongTermAgreement()` (both build the entity in
   `generateSupplierRating(agreement)` with `creationAuthor = agreement.evaluator`)
   and from the POST `create()` endpoint. Hooking CREATED inside `createInternal`
   covers every path. Actor = `rating.getCreationAuthor()`.

4. **KEY CORRECTION to the design's hook list (do not skip).**
   There are **no** server methods `approveRating()` / `closeRating()`. Those are
   **client** functions in `editSupplierRating.js` that mutate `rating.status`
   (and `closingDatetime`) and then call the single server `update()` (POST
   `sc/srRatingHeader/{id}`). Therefore **OPENED, SENT_FOR_APPROVAL and APPROVED are
   all detected inside the server `update()` method** by comparing the persisted
   old status to the incoming status:
   - `Initial → InProgress` ⇒ `OPENED`
   - `InProgress → Sent` ⇒ `SENT_FOR_APPROVAL`
   - `InProgress → Closed` **or** `Sent → Closed` ⇒ `APPROVED` (covers both the
     "close" and "approve" client buttons)
   `REOPENED` (`reopenRating`), `APPROVAL_DELEGATED` (`delegateApproval`) and
   `EVALUATION_DELEGATED` (`sendNotificationForDelegatePerson`) are their own server
   endpoints and are hooked there. The reopen trap still holds: `reopenRating()`
   reassigns `delegateId`, so EVALUATION_DELEGATED must be hooked on the delegate
   notification path only — never on a "delegateId changed" check.

---

## Backend slice (executor-backend)

Modules:
`publicERANET-server/eranet-domain` (entity + persistence.xml),
`publicERANET-server/eranet-dao` (DAO),
`publicERANET-server/public-eranet` (services),
`publicERANET-server/src/main/sql` (Liquibase).

### B1. New entity `SrRatingActivity`
File: `eranet-domain/.../server/dto/SrRatingActivity.java`.
Copy the shape of `InternalProcurementRequestActivity.java`; use the scalar-FK +
read-only-relation pattern already used by `SrRatingHeader` (writable `xxxId` +
`@ManyToOne(insertable=false, updatable=false)`):

- `Integer id` (IDENTITY).
- `Integer ratingHeaderId` — `@Column(name="rating_header_id")` (writable).
- `SrRatingHeader ratingHeader` — `@ManyToOne`, `@JoinColumn(name="rating_header_id", insertable=false, updatable=false)`, `@JsonIgnore @XmlTransient`.
- `ActivityType activityType` — `@Column(name="activity_type")`, stored as **ORDINAL int** (default EclipseLink enum mapping).
- `Integer actorId` — `@Column(name="actor_id")` (writable, **nullable**).
- `SystemUser actor` — `@ManyToOne`, `@JoinColumn(name="actor_id", insertable=false, updatable=false)`.
- `Date activityDatetime` — `@Column(name="activity_datetime")`, `@Temporal(TIMESTAMP)`.

`public enum ActivityType` declared in **this exact order** (the ordinal is the
DB value and is referenced by the backfill SQL — order is load-bearing):
```
CREATED(0), OPENED(1), REOPENED(2), SENT_FOR_APPROVAL(3),
APPROVED(4), EVALUATION_DELEGATED(5), APPROVAL_DELEGATED(6)
```
Add `public static final String FILTER_NAME_RATING_HEADER_ID = "ratingHeaderId";`
and `PROPERTY_NAME_ACTIVITY_DATETIME = "activityDatetime";` for the finder/sort.

**Verify:** entity compiles; enum ordinals match the list above.

### B2. Register the entity
File: `eranet-domain/src/main/resources/META-INF/persistence.xml` — add
`<class>sk.innovis.eranetpublic.server.dto.SrRatingActivity</class>` next to the
existing `SrRatingHeader` / `SrRatingItem` entries (~line 307).
**Verify:** class listed; deploy does not warn about an unmanaged entity.

### B3. DAO `SrRatingActivityDao`
File: `eranet-dao/.../server/dao/SrRatingActivityDao.java`. Minimal `BaseDao`
subclass (mirror a simple existing DAO): constructor `super(SrRatingActivity.class)`,
`getFieldsForSearch()` → `new String[0]`. Rely on `BaseDao.getWhere` for the
generic equality filter on `ratingHeaderId`. (If the generic scalar filter does
not resolve, add a tiny `getWhere` override building an equality predicate on the
`ratingHeaderId` attribute — verify which is needed at build time.)
**Verify:** `findAll` with `QueryFilter.getEqual("ratingHeaderId", <id>)` returns
only that rating's rows.

### B4. Service `SrRatingActivityService` (internal-only EJB, not a REST resource)
File: `public-eranet/.../server/service/SrRatingActivityService.java`.
`@Stateless` extends `BaseService<SrRatingActivity>`; inject `SrRatingActivityDao`,
`setDao(...)` in `@PostConstruct`; wire `SessionContext` like `SrRatingHeaderService`.
Expose `@PermitAll` internal methods only (no `@Path`, so **no ApplicationConfig
change**):
- `createInternal(SrRatingActivity a)` → `super.createWithReturnObject(a)`.
- `findByRatingHeaderIdInternal(Integer id)` → `findAllInternal` with
  `QueryFilter.getEqual(SrRatingActivity.FILTER_NAME_RATING_HEADER_ID, id)`,
  sorted **ascending** by `activityDatetime` (via FindParameters sort, or sort the
  returned list in Java).
**Verify:** unit-level call returns rows oldest-first.

### B5. Read DTOs
Add small English POJOs (e.g. in `eranet-domain/.../server/dto/` or as nested
static classes on the endpoint) for the JSON contract in the design:
- `SrRatingActivitiesDto { List<ActivityItem> activities; ActorLine lastChange; ActorLine waitingOn; }`
- `ActivityItem { String type; Date datetime; String actorFullName; String actorOrgUnit; }`
- `ActorLine { Date datetime; String actorFullName; String actorOrgUnit; }` (waitingOn has no datetime → leave null / omit)
Actor resolution helper: `actorFullName = user != null ? user.getFormattedName() : ""`,
`actorOrgUnit = (user != null && user.getOrganizationDirectoryName() != null) ? user.getOrganizationDirectoryName() : ""`.
`type` = `activityType.name()` (so JSON is `"CREATED"`, etc.).

### B6. `SrRatingHeaderService` — write hooks + read endpoint
File: `public-eranet/.../server/service/SrRatingHeaderService.java`.

- Inject `@EJB private SrRatingActivityService srRatingActivityService;`
- Private helper (the only writer; respects service-layer/no-direct-DAO rule):
  ```
  private void recordActivity(SrRatingHeader header, SrRatingActivity.ActivityType type, SystemUser actor) {
      SrRatingActivity a = new SrRatingActivity();
      a.setRatingHeaderId(header.getId());
      a.setActivityType(type);
      a.setActorId(actor != null ? actor.getId() : null);
      a.setActivityDatetime(new Date());
      srRatingActivityService.createInternal(a);
  }
  ```
- **CREATED** — in `createInternal(...)`: after `super.createWithReturnObjectAsResponse(srRatingHeader)`,
  record `CREATED` with `actor = srRatingHeader.getCreationAuthor()`. Confirm the
  entity id is populated after persist; if the passed entity id is not set, read
  the id from the returned Response entity.
- **Status transitions** — in `update(...)`: it already loads
  `oldRating = getEntityById(id)`. Capture `oldStatus = oldRating.getStatus()` and
  `newStatus = srRatingHeader.getStatus()`. In each branch that returns a
  successful `updateWithReturnObjectAsResponse`, after the update call a private
  `recordStatusTransition(oldStatus, newStatus, currentUser, srRatingHeader)`:
  - `Initial → InProgress` ⇒ OPENED
  - `InProgress → Sent` ⇒ SENT_FOR_APPROVAL
  - `(InProgress|Sent) → Closed` ⇒ APPROVED
  Do nothing for other/equal transitions. **Do not** emit EVALUATION_DELEGATED here.
- **REOPENED** — in `reopenRating(...)`: after `updateInternal(rating)`, record
  REOPENED with `actor = currentUser`.
- **APPROVAL_DELEGATED** — in `delegateApproval(...)`: after `updateInternal(rating)`,
  record APPROVAL_DELEGATED with `actor = getCurrentUser()`.
- **EVALUATION_DELEGATED** — in `sendNotificationForDelegatePerson(...)`: inside the
  existing `if (rating.getDelegatePerson() != null)` block (a real delegation),
  record EVALUATION_DELEGATED with `actor = getCurrentUser()` (the delegator).
- **Read endpoint** — new method:
  ```
  @GET @Path("{id}/activities")
  public SrRatingActivitiesDto getActivities(@PathParam("id") Integer id) { ... }
  ```
  No extra `@RolesAllowed` (inherits class-level `ROLE_NAME_USER`, matching "každý
  to vidí"). Build the payload:
  - `activities`: map `srRatingActivityService.findByRatingHeaderIdInternal(id)`
    (ascending) to `ActivityItem`s, resolving actor live via `activity.getActor()`.
  - `lastChange`: from `rating.getModificationAuthor()` + `getModificationDatetime()`;
    fall back to `getCreationAuthor()` + `getCreationDatetime()` if never modified.
  - `waitingOn`: from `rating.getStatus()`:
    - `Initial` / `InProgress` → evaluator = `delegatePerson` if `delegateId != null` else `creationAuthor`
    - `Sent` → `approver`
    - `Closed` → `null` (omit the line)

**Verify:** hit `GET webresources/sc/srRatingHeader/{id}/activities` for a rating in
each status; confirm rows + derived lines match the rules.

### B7. Liquibase changeset (author `m.bijalko`)
New file: `publicERANET-server/src/main/sql/2.5.0/db.changelog-EP13166.xml`
(place in the current `2.5.0` folder, mirroring the sibling `db.changelog-EP13137.xml`).
Register it as the **last** `<include>` before `</databaseChangeLog>` in
`publicERANET-server/src/main/sql/db.changelog-master.xml`.

Contents:
- **changeSet 1** `create_sr_rating_activity` (author `m.bijalko`): `createTable`
  `sr_rating_activity` with `id` (INT, PK, autoIncrement), `rating_header_id`
  (INT, not null), `activity_type` (SMALLINT/INT, not null), `actor_id` (INT,
  **nullable**), `activity_datetime` (DATETIME, not null); then
  `addForeignKeyConstraint` `rating_header_id → sr_rating_header(id)` and
  `actor_id → system_user(id)`. Include a `<rollback><dropTable .../></rollback>`.
- **changeSet 2** `backfill_sr_rating_activity_created` (INSERT is allowed as raw
  SQL): `INSERT INTO sr_rating_activity (rating_header_id, activity_type, actor_id, activity_datetime)
  SELECT id, 0, creation_author_id, creation_datetime FROM sr_rating_header
  WHERE (soft_deleted = 0 OR soft_deleted IS NULL)` — **always**.
- **changeSet 3** `backfill_sr_rating_activity_approved`: same shape, `activity_type = 4`,
  `actor_id = approver_id`, `activity_datetime = closing_datetime`,
  `WHERE closing_datetime IS NOT NULL`.
- **changeSet 4** `backfill_sr_rating_activity_reopened`: `activity_type = 2`,
  `actor_id = delegate_id`, `activity_datetime = reopen_datetime`,
  `WHERE reopen_datetime IS NOT NULL`.
- **Not backfilled:** OPENED, SENT_FOR_APPROVAL, EVALUATION_DELEGATED,
  APPROVAL_DELEGATED (no reliable stored timestamp).
Each backfill changeSet gets a `<rollback>` deleting rows of that `activity_type`.
**The `activity_type` integers (0/4/2) must match the enum ordinals in B1.**

**Verify:** run migrations against a dev DB; table + FKs exist; a pre-existing
closed/reopened rating shows backfilled CREATED/APPROVED/REOPENED and no
send/delegation rows.

---

## Frontend slice (executor-frontend)

Module: `publicERANET-client`. Bootstrap 3 / SmartAdmin only; no new libs/CSS.

### F1. Client resource + service
File: `app/scripts/service/resources/srRatingHeaders.js`.
- Add a `$resource` action:
  ```
  activities: { method: 'GET', url: 'webresources/sc/srRatingHeader/:ratingId/activities' }
  ```
- Add `serviceResult.loadActivities = function (id, doneCallback) { ... }` that
  calls `SrRatingHeadersResource.activities({ratingId: id}, ...)` and passes the
  payload to the callback (or stores it on a service field). Keep JSON field
  names exactly as the server returns (`activities`, `lastChange`, `waitingOn`,
  `type`, `datetime`, `actorFullName`, `actorOrgUnit`).

### F2. Controller wiring
File: `app/scripts/controllers/supplierRating/editSupplierRating.js`.
- Add `$scope.activities = []`, `$scope.lastChange = null`, `$scope.waitingOn = null`.
- Add `var reloadActivities = function () { SrRatingHeaders.loadActivities(ratingId, function (data) { $scope.activities = data.activities; $scope.lastChange = data.lastChange; $scope.waitingOn = data.waitingOn; }); };`
- Call `reloadActivities()` from `reloadRating`'s `afterLoad`, and from
  `afterRatingSaved` (covers save/close/send/approve/delegate-approval), and in the
  `reopenRating` success path. This piggybacks the reloads that already happen after
  each action.

### F3. View restructure + Aktivity panel
File: `app/views/supplierRating/editSupplierRating.html`.
- Wrap the top info `<fieldset>` (currently two `col-sm-6` blocks, ~lines 25–94)
  so the evaluation attributes sit in a **left column `col-md-8`** stacked
  vertically in a single column (keep every existing row, incl. the `Hodnotiteľ`
  history button and `data-ng-if` on `procurementItemGroupId`).
- Add a **right column `col-md-4`** containing the **Aktivity** panel, copying the
  IO/VO markup/styling from
  `views/planning/internalProcurementRequest/editInternalProcurementRequest.html`
  (~lines 1737–1743). Panel body:
  1. `ng-repeat="activity in activities"` (already ascending from server; may add
     `| orderBy:'datetime'` to be safe). Each line:
     - label: `{{('SUPPLIER_RATING_ACTIVITY_' + activity.type) | translate}}`
     - value: `{{activity.actorFullName}} - {{activity.actorOrgUnit}} ({{activity.datetime | ourDatetimeFilter}})`
       (empty org unit renders `Name -  (date)`, matching the ticket example).
  2. Visually separated below: **Posledná zmena** (`lastChange` →
     `actorFullName - actorOrgUnit (datetime | ourDatetimeFilter)`) and **Čaká na
     spracovanie** (`waitingOn` → `actorFullName - actorOrgUnit`, **no** timestamp),
     with `data-ng-if="waitingOn"` so it hides when the rating is Closed.
- Reuse existing panel/jarviswidget classes from the IO/VO component; do not
  hand-roll CSS.

### F4. Translations
Files: `app/scripts.no.min/langs/sk.js` and `app/scripts.no.min/langs/en.js`.
Add English keys (Slovak values only in `sk.js`; English values in `en.js`):
`SUPPLIER_RATING_ACTIVITY_CREATED` ("Vytvorenie iniciálneho hodnotenia"),
`_OPENED` ("Otvorenie hodnotenia"), `_REOPENED` ("Znovuotvorenie hodnotenia"),
`_SENT_FOR_APPROVAL` ("Odoslanie na schválenie"), `_APPROVED` ("Schválenie"),
`_EVALUATION_DELEGATED` ("Delegovanie hodnotenia"),
`_APPROVAL_DELEGATED` ("Delegovanie schvaľovania"),
plus `SUPPLIER_RATING_ACTIVITY_PANEL_TITLE` ("Aktivity"),
`SUPPLIER_RATING_LAST_CHANGE` ("Posledná zmena"),
`SUPPLIER_RATING_WAITING_ON` ("Čaká na spracovanie").
Confirm final Slovak wording with the user if any label is ambiguous.

### F5. Karma/Jasmine tests
Per `docs/codebase/TESTING.md`, add a client spec covering:
- activity line formatting (name / org unit / **empty org unit** → no crash), and
- controller load + reload wiring (`loadActivities` called on detail load and after
  a save/reopen).

---

## Contract between backend and frontend

- **URL:** `GET webresources/sc/srRatingHeader/{id}/activities`
- **JSON (backward-compatible, do not rename):**
  ```json
  { "activities": [ { "type": "CREATED", "datetime": "...", "actorFullName": "...", "actorOrgUnit": "" } ],
    "lastChange": { "datetime": "...", "actorFullName": "...", "actorOrgUnit": "" },
    "waitingOn":  { "actorFullName": "...", "actorOrgUnit": "" } }
  ```
  `waitingOn` omitted/null when the rating is Closed. `type` values are the enum
  names. Slovak never appears in payloads — labels are resolved client-side via the
  `SUPPLIER_RATING_ACTIVITY_*` keys.

---

## Verification (before any executor claims done)

**Manual smoke (primary), through the real flow:**
1. Generate/create → CREATED (creator + real date/time).
2. First open + save → OPENED; `waitingOn` = evaluator.
3. Send for approval → SENT_FOR_APPROVAL; `waitingOn` = approver.
4. Approve/close → APPROVED; `waitingOn` cleared.
5. Reopen → REOPENED; `waitingOn` = evaluator; **no** spurious EVALUATION_DELEGATED row.
6. Delegate evaluation → EVALUATION_DELEGATED (delegator).
7. Delegate approval → APPROVAL_DELEGATED (delegator).
8. User with no org unit → empty org slot (`Name -  (date)`); deactivated user → name still shows.
9. Pre-migration rating → backfilled CREATED/APPROVED/REOPENED render; send/delegation absent.
10. Order chronological, newest last.

**Karma/Jasmine:** F5 specs green.

**Regression:** layout restructure must not break the evaluation sheet, save, send,
approve, close, reopen, or delegate flows.

**Build/deploy:** Maven WAR build (JDK 8) succeeds; Liquibase migrations apply
cleanly; WildFly hot-deploy OK (see `docs/codebase/` deployment notes).

---

## Open questions for the user

- Confirm the Slovak label wording for the three panel headings and seven activity
  types (F4 values are proposals from the design/ticket).
- Confirm the `col-md-8 / col-md-4` split is acceptable on the widest evaluation
  sheets (the sheet grid uses custom `col-*-ob` widths); if the sheet is too wide
  for `col-md-8`, the Aktivity panel may instead sit above/below rather than
  beside it — flag rather than silently change the layout.

## Risks / watch-items

- **Enum ordinal ↔ backfill coupling.** `activity_type` is stored as the enum
  ordinal; the backfill SQL hard-codes 0/4/2. If the enum order is ever changed,
  both must change together. Keep the enum order fixed (B1).
- **`createInternal` id availability.** CREATED needs the persisted rating id;
  confirm the id is set on the passed entity after
  `createWithReturnObjectAsResponse` (else read it from the returned entity).
- **`sendNotificationForDelegatePerson` as the delegation signal.** It records
  EVALUATION_DELEGATED whenever `delegatePerson != null`. This matches the design
  (fires only on a real delegate action) and avoids the reopen trap, but is a
  behavioral coupling — do not add a generic "delegateId changed" hook in
  `update()`.
- **Generic scalar filter in the DAO.** If `BaseDao.getWhere` cannot filter on the
  scalar `ratingHeaderId`, add a small `getWhere` override (B3).
- **APPROVED backfill actor.** For ratings closed via the plain "close" button
  (no approver), `approver_id` is null, so the backfilled APPROVED line has an
  empty actor — acceptable per the design (honesty over approximation).
