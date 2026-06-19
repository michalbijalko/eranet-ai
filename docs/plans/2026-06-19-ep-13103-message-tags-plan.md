# EP-13103 — Tags ("Štítky") in communication: Implementation Plan

> **For the executor agents:** Use `superpowers:executing-plans`. Backend slice → `executor-backend`,
> frontend slice → `executor-frontend`. **Execute and DEPLOY the BACKEND slice first** — the
> `message_tag` / `message_to_tag` tables and the `sc/messageTag` endpoints must exist before the
> client calls them. Do **not** start the frontend slice until the backend is built, the Liquibase
> changeset has run, and the endpoints answer.

**Ticket:** Story **EP-13103** · Dev **EP-13112** · Epic EP-12988
**Authoritative design (locked):** `docs/plans/2026-06-19-ep-13103-message-tags-design.md` — follow it; do not deviate.
**Goal:** Add a per-user **tag/label catalog** for messages — editable (multiselect + create) in the
message detail, shown read-only in the message overview, and usable as a dedicated free-text filter.
Each user sees only their own tags. All three folders (Odoslané, Koncepty, Externá komunikácia) in scope.

**Architecture:** A new user-owned tag catalog (`message_tag`) plus an assignment join (`message_to_tag`).
`MessageTagService extends BaseService` exposes create (owner forced server-side) + owner-scoped name search.
Tag assignments ride on the existing `currentMessage` save POST and are reconciled — for the current user
only — at the `MessageService.create()` choke point. The overview query LEFT-JOINs the catalog for a
`tagName` LIKE filter and populates each row's current-user tags for chip rendering. The client adds one
`ui-select multiple` (per-chip colours), a "Pridanie štítkov" modal, read-only overview chips, and a
dedicated "Štítky" filter input.

**Tech stack:** Java 8 / Java EE 7 / EclipseLink / RESTEasy / Liquibase / MySQL (server);
AngularJS 1.5 ES5 / `ui-select` / `ui.bootstrap` `$uibModal` (client).

**Commit pair (from `docs/TICKETS.md`, row already present):** `feat(EP-13103, EP-13112): …`
- Server repo: `feat(EP-13103, EP-13112): add per-user message tag catalog and assignments`
- Client repo: `feat(EP-13103, EP-13112): add tag chips, create modal and filter to communication`

---

## Locked decisions (do not deviate — from the design doc)

1. **New per-user tag catalog backend** (not a frontend-only reuse of supplier states).
2. **Dedicated "Štítky" free-text filter** in the overview — the existing subject filter is left untouched.
3. **All folders** (Odoslané, Koncepty, Externá komunikácia) support tagging + display + filter.
4. Colours stored as keys `green` / `orange` / `red` / `blue` (same convention as `CompanyTag`),
   mapped on the FE to the existing colour hex. Default colour in the create modal is **Zelený**.
5. Ownership is **always** taken from the authenticated user server-side (`BaseService.getCurrentUser()`) —
   never trusted from the client payload, on create, search, save-reconcile, and overview population.
6. The ≥3-char typeahead minimum is enforced on the **client**; the server scopes by owner regardless.

---

## Verified codebase facts (confirmed while writing this plan)

- **Owner source exists:** `BaseService.getCurrentUser()` (`service/BaseService.java:886`) returns the
  authenticated `SystemUser` via `sessionContext.getCallerPrincipal()`. `MessageService` already wires a
  `SessionContext` (`getSessionContext()` override, `MessageService.java:174-177`), so `getCurrentUser()`
  works there. Use it for every owner decision.
- **Save choke point:** `MessageService.create()` (`MessageService.java:179-203`) is the single save entry
  (used for send *and* draft via `sendDraft`/`save` on the client). EP-13100 already added
  `applyHtmlAndPlainBody(message)` at the top — the tag reconcile hooks in the same method, after the save
  returns an id (reconcile needs the persisted message id).
- **Overview filter location:** `MessageDao.processQueryFilter()` (`MessageDao.java:266-393`) is where named
  filters are handled; the subject LIKE filter is at lines **377-383**. The new `tagName` LIKE filter is a
  new `else if` branch here, plus a join set up in `getWhere()` (lines 57-264).
- **Entity style:** `CompanyTag` (`dto/CompanyTag.java`) is the colour/name reference; `Message` already has
  `@OneToMany(cascade = ALL, mappedBy = "message", orphanRemoval = true)` children (lines 100-113) — the new
  `messageToTags` collection mirrors them.
- **Service style:** `FileTagService` (`service/FileTagService.java`) is the `BaseService` REST reference
  (`@PostConstruct setDao(...)`, `createWithReturnObjectAsResponse`, `findAll`).
- **Liquibase style:** `src/main/sql/2.5.0/db.changelog-EP11632.xml` (changeSet/addColumn); use `createTable`
  + `addForeignKeyConstraint` + `createIndex`. Author **must** be `m.bijalko`. Master changelog tail:
  `src/main/sql/db.changelog-master.xml` — last include is `.\2.11.0\db.changelog-EP13108.xml`; append after it.
- **`ApplicationConfig.getClasses()`** lists each service **twice** (two `getClasses` blocks — e.g.
  `MessageService` at lines **48** and **236**, `FileTagService` at **136** and **225**). Register
  `MessageTagService` in **both** blocks, matching the existing pattern.
- **Resource style:** `app/scripts/service/resources/messages.js` — two-factory pattern
  (`MessagesResource` `$resource` + `Messages` wrapper). URL base `webresources/sc/`.
- **ui-select chip + tagging transform:** `app/views/suppliers/editCompany.html:365-414` (4 separate
  per-colour `ui-select multiple`) + `controllers/general/editCompany.js:57-95,202-215`
  (`transformToObjectGreen` etc.). EP-13103 needs **one** multiselect with mixed colours — adapt, don't copy 4.
- **Colour classes (reuse the hex):** `app/styles/custom.css:857-889` —
  `suppliers-status-green #6ab5b4`, `-red #a90329`, `-blue #5a87d2`, `-orange #F48942` (matches the ticket).
- **Communication controller wiring:** `controllers/communication/communication.js` — `$uibModal` already
  injected (line 50); `saveMessage` (201), `storeFilterAndDoReload` + `FILTER_OR_SEARCH_CHANGED` (215-224),
  `currentMessage` is the bound detail model, `messageToSave = _.clone($scope.currentMessage)` on save
  (726, 769). Overview subject cell: `communication.html:235`; subject filter row: `:189` (`<text-filter name="subject">`).

---

## Pre-flight (umbrella repo)

### Task 0: Confirm the ticket pair row

`docs/TICKETS.md` already contains `| Tags ("Štítky") in communication | EP-13103 | EP-13112 |`
(line 28). **No edit needed.** If it were missing, add it before any commit. No commit in this task.

---

# BACKEND SLICE — `publicERANET-server` (do this first, deploy, run migration, then start the client)

All paths under `C:\Innovis\seas_test\publicERANET-server\`. Branch: `seas-test`. One commit (Task B8).

**Reference / analog files (read before editing):**
- Entity style: `src/main/java/sk/innovis/eranetpublic/server/dto/CompanyTag.java`;
  child-collection style: `dto/Message.java:100-113`.
- Service style: `service/FileTagService.java`; save choke point: `service/MessageService.java:179-223`.
- Owner: `service/BaseService.java:886` (`getCurrentUser()`).
- Query/filter: `dao/MessageDao.java` (`getWhere` 57-264, `processQueryFilter` 266-393, subject filter 377-383).
- Liquibase: `src/main/sql/2.5.0/db.changelog-EP11632.xml`; master tail `src/main/sql/db.changelog-master.xml`.
- Registration: `service/ApplicationConfig.java` (two `getClasses()` blocks).

---

### Task B1: Create the `MessageTag` entity (catalog)

**Files:** Create `src/main/java/sk/innovis/eranetpublic/server/dto/MessageTag.java`.

**Step 1:** Model the catalog row, following `CompanyTag` style but owned by a `SystemUser` and with a
creation timestamp. Columns: `id` (IDENTITY PK), `name` (varchar, not null), `color` (varchar, not null),
`system_user_id` (Integer FK → `system_user`, owner), `creation_datetime` (**DATETIME**,
`@Temporal(TemporalType.TIMESTAMP)`).

- Keep both a raw `@Column(name = "system_user_id") private Integer systemUserId;` **and** a
  `@ManyToOne @JoinColumn(name = "system_user_id", insertable=false, updatable=false) private SystemUser systemUser;`
  only if a later step needs the relation for a JPA join. **Simplest sufficient form:** a scalar
  `systemUserId` Integer plus a `@ManyToOne SystemUser` is the pattern used elsewhere — but YAGNI: if the
  `tagName` filter and search are written against `systemUserId` scalar (they can be), the entity needs only
  the scalar FK column. Decide based on B4/B6; do not add an unused relation.
- Add `PROPERTY_NAME_*` String constants (`name`, `color`, `systemUserId`) for use in `QueryFilter` /
  Criteria, matching the `Message`/`CompanyTag` constant convention.
- `@XmlRootElement`, `implements Serializable`. JSON field names on the wire: `id`, `name`, `color`
  (the client model is `{id, name, color}` — `systemUserId`/`creationDatetime` need not be serialized to
  the client; `@JsonIgnore` the owner if you expose the relation, exactly like `CompanyTag.getCompany()`).

**Verification:** compiles in B7 build. Confirm the static metamodel `MessageTag_` is generated by the
EclipseLink processor (needed by `MessageDao` Criteria joins) — it appears in `target/` after build.

---

### Task B2: Create the `MessageToTag` join entity

**Files:** Create `src/main/java/sk/innovis/eranetpublic/server/dto/MessageToTag.java`.

**Step 1:** Model the assignment: `id` (IDENTITY PK), `message_id` (FK → `message`),
`message_tag_id` (FK → `message_tag`). Expose:
- `@ManyToOne @JoinColumn(name = "message_id") @JsonIgnore @XmlTransient private Message message;`
  (back-reference; ignore in JSON like `CompanyTag.getCompany()`).
- `@ManyToOne(cascade = {}) @JoinColumn(name = "message_tag_id") private MessageTag messageTag;`
  (so the overview population and reconcile can read the tag's name/colour/owner). **No cascade ALL** on the
  tag side — deleting an assignment must never delete the catalog tag.
- A scalar `@Column(name = "message_tag_id", insertable=false, updatable=false) private Integer messageTagId;`
  if the reconcile compares by id (convenient).
- `PROPERTY_NAME_*` constants as needed by the DAO.

**Step 2:** Add the child collection to `Message` (`dto/Message.java`), mirroring its siblings at lines 100-113:

```java
@OneToMany(cascade = CascadeType.ALL, mappedBy = "message", orphanRemoval = true)
private List<MessageToTag> messageToTags;
```

…with a standard getter/setter. **Do not** JSON-serialize this raw collection to the client — the client
binds a separate transient `messageTags` list of `{id,name,color}` (see B6). Mark the raw `getMessageToTags()`
`@XmlTransient`/`@JsonIgnore` and expose the curated transient list instead, to avoid leaking other users'
assignments. (See B6 Step 3 for the transient `messageTags` getter.)

**Verification:** compiles; `Message_` metamodel gains `messageToTags`.

---

### Task B3: Create `MessageTagDao`

**Files:** Create `src/main/java/sk/innovis/eranetpublic/server/dao/MessageTagDao.java`.

**Step 1:** `@Stateless @LocalBean public class MessageTagDao extends BaseDao<MessageTag>` with the
no-arg constructor calling `super(MessageTag.class)` (mirror `MessageDao` constructor). Add one query method:

```java
List<MessageTag> findByOwnerAndNameLike(Integer systemUserId, String text)
```

implemented with Criteria (or a reuse of `findAll` + two `QueryFilter`s: equal `systemUserId`, like `name`).
**Prefer routing through `BaseService.findAll` with `QueryFilter`s** rather than hand-rolling the
EntityManager, to keep the layer discipline; only drop to Criteria in the DAO if the filter helper cannot
express the LIKE cleanly.

**Verification:** compiles; exercised by B4 search endpoint.

---

### Task B4: Create `MessageTagService` (create + owner-scoped search)

**Files:** Create `src/main/java/sk/innovis/eranetpublic/server/service/MessageTagService.java`.

**Step 1:** Mirror `FileTagService` structure:

```java
@Path("sc/messageTag")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Stateless
@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)
public class MessageTagService extends BaseService<MessageTag> {

    @EJB private MessageTagDao messageTagDao;

    @PostConstruct public void initialize() { setDao(messageTagDao); }

    @Override protected SessionContext getSessionContext() { return sessionContext; } // inject SessionContext like MessageService
}
```

**Step 2 — create (PUT):** name + colour required; owner forced from the session. Return the saved tag so the
client can auto-attach it.

```java
@PUT
public Response createTag(final MessageTag tag) {
    if (tag.getName() == null || tag.getName().trim().isEmpty()
            || tag.getColor() == null || tag.getColor().trim().isEmpty()) {
        throw new WebApplicationException(Response.Status.BAD_REQUEST);
    }
    tag.setSystemUserId(getCurrentUser().getId());   // owner NEVER from payload
    tag.setCreationDatetime(new Date());
    return super.createWithReturnObjectAsResponse(tag);
}
```

> Validate the `color` value against the allowed set (`green|orange|red|blue`) so a crafted payload can't
> store an arbitrary colour. Reject otherwise with `BAD_REQUEST`.

**Step 3 — search (POST):** owner-scoped name LIKE. Owner injected server-side; the ≥3-char minimum is the
client's responsibility but the server must still scope by owner and tolerate short/empty input safely.

```java
@POST
@Path("/search")
public List<MessageTag> search(final SearchRequest request) {
    final Integer ownerId = getCurrentUser().getId();
    final String text = request == null ? null : request.getText();
    return messageTagDao.findByOwnerAndNameLike(ownerId, text);
}
```

> Use a tiny request DTO (or reuse an existing `RestString`-style helper if one is on the classpath — check
> `dao/helpDto/` before adding a new class; `RestInteger` exists, so a `RestString`/`SearchRequest` analog may
> too). Do not trust any owner field in the request.

**Step 4:** Register in **both** `ApplicationConfig.getClasses()` blocks
(`service/ApplicationConfig.java`, beside the `FileTagService` lines 136 and 225):

```java
resources.add(sk.innovis.eranetpublic.server.service.MessageTagService.class);
```

**Verification:** after deploy, `PUT webresources/sc/messageTag` with `{name,color}` returns the saved tag with
an id and the server-set owner; `POST webresources/sc/messageTag/search {text:"abc"}` returns only the caller's
matching tags. A second user's identical search returns none of the first user's tags.

---

### Task B5: Reconcile the current user's tag assignments on message save

**Files:** Modify `src/main/java/sk/innovis/eranetpublic/server/service/MessageService.java`
(method `create()`, lines 179-203) and add a private helper.

**Context:** The client adds a `messageTags` list (`[{id,name,color}, …]`) onto the saved message payload
(see B6 / frontend F-save). On save we must, **for the current user only**:
- add a `message_to_tag` row for each selected tag id that the user doesn't already have on this message,
- remove the user's `message_to_tag` rows for tags they de-selected,
- **leave other users' assignments on that message untouched.**

**Step 1:** The reconcile needs the persisted message id, so run it **after** `createInternal()` returns.
Capture the created message id from the response (the create returns the saved object), then reconcile:

```java
final Response response = createInternal(message);
reconcileCurrentUserTags(response, message);   // EP-13103
return response;
```

> Read the actual shape of what `createWithReturnObjectAsResponse` returns (entity in the response body) and
> extract the id from it; if cleaner, fetch the just-saved `Message` by id through the DAO/service. Keep the
> save itself untouched.

**Step 2:** Implement the helper (well-named, layered through `BaseService`/DAO — **no raw EntityManager**):

```java
/** EP-13103: sync only the current user's message_to_tag rows for this message. */
private void reconcileCurrentUserTags(final Response savedResponse, final Message incoming) {
    final List<MessageTag> desired = incoming.getMessageTags();   // transient list from the client
    final Integer messageId = /* id of the saved message */;
    final Integer ownerId = getCurrentUser().getId();

    // 1. load existing message_to_tag rows for (messageId) whose tag.systemUserId == ownerId
    // 2. compute add-set (desired tag ids not yet linked) and remove-set (linked but no longer desired)
    // 3. create / delete those join rows via a BaseService/DAO method (MessageToTagDao or MessageTagService helper)
    // Tags owned by other users on this message are never read or touched.
}
```

> Implementation choices for the executor (surface as a decision if non-trivial):
> - Add a small `MessageToTagDao extends BaseDao<MessageToTag>` (Task B5a) with
>   `findByMessageIdAndOwner(messageId, ownerId)` and use `BaseService` create/delete for the diff. This keeps
>   the service from calling the EntityManager directly.
> - Guard against a tag id in `desired` that is **not owned by the caller** (a crafted payload): only link tags
>   whose `systemUserId == ownerId`. Drop/ignore foreign tag ids; optionally `logger.warn`.
> - Drafts save through the same `create()` — tags must reconcile on drafts too (folder Koncepty in scope).

**Step 3 (B5a):** Create `src/main/java/sk/innovis/eranetpublic/server/dao/MessageToTagDao.java`
(`@Stateless @LocalBean extends BaseDao<MessageToTag>`) with the owner-scoped lookup used above.

**Verification:** save a message with two tags → two `message_to_tag` rows for the caller; re-save with one
removed → one row; a second user adding their own tag to the same message does not delete the first user's row.

---

### Task B6: Overview — `tagName` filter + per-user tag population in `MessageDao`

**Files:** Modify `src/main/java/sk/innovis/eranetpublic/server/dao/MessageDao.java` and add the transient
`messageTags` getter to `dto/Message.java`.

**Step 1 — filter constant:** add a filter name (e.g. `Message.FILTER_NAME_TAG_NAME = "tagName"` in
`dto/Message.java` near the other `FILTER_*` constants, lines 42-60) so the client and DAO agree on the key.

**Step 2 — join + LIKE predicate:** in `MessageDao`, set up a LEFT JOIN
`message → messageToTags → messageTag` only when the `tagName` filter is present (mirror how the other joins
are conditionally created in `getWhere()`), then handle it in `processQueryFilter()` as a new `else if`
branch next to the subject filter (lines 377-383):

```java
} else if (Message.FILTER_NAME_TAG_NAME.equals(filter.getFieldName())
        && QueryFilter.LIKE_FILTER_TYPE.equals(filter.getType())) {
    for (final String value : filter.getFilterValues()) {
        final String pattern = '%' + value.toLowerCase() + '%';
        final Predicate byName = criteriaBuilder.like(
                criteriaBuilder.lower(messageTagJoin.get(MessageTag_.name)), pattern);
        final Predicate byOwner = criteriaBuilder.equal(
                messageTagJoin.get(MessageTag_.systemUserId), getCurrentUserId());
        result.add(criteriaBuilder.and(byName, byOwner));   // scope to caller — never trust client
    }
}
```

> `MessageDao` is a DAO, not a `BaseService`, so `getCurrentUser()` is not directly available there. Resolve
> the current user id the way the existing owner-scoped filters do — check how `byCompanyIdSender` /
> `ownerCompanyId` get their value (the value is passed *in* via a filter from the service layer). **Preferred:
> the service/`Messages` client supplies the owner implicitly and the DAO scopes by the join owner =
> the caller.** If the DAO cannot see the principal, have `MessageService` inject the current user id into the
> query (as the codebase already does for supplier scoping) rather than reading the principal in the DAO.
> Keep `findItems` distinct (already `setDistinct(TRUE)` at line 396-398) so the tag join doesn't duplicate rows.

**Step 3 — populate per-user tags for chips:** after loading the overview page, each returned `Message` must
carry a transient `messageTags` list of the **current user's** `{id,name,color}` for that message. Two options
(pick the simpler that performs acceptably; surface as a decision):
- (a) In `MessageService` post-process the `FindResult<Message>`: for the page's message ids, load
  `message_to_tag` joined to `message_tag` filtered by `systemUserId = currentUser`, group by message id, and
  set each `Message.setMessageTags(list)`.
- (b) Map from the already-joined `messageToTags` on each entity, filtering to the caller's owner id.

Add the transient field + getter to `Message`:

```java
@Transient private List<MessageTag> messageTags;     // current user's tags, for FE chips
public List<MessageTag> getMessageTags() { return messageTags; }
public void setMessageTags(List<MessageTag> messageTags) { this.messageTags = messageTags; }
```

This `messageTags` is the **same wire field** the client sends on save (B5) and reads on overview — the
JSON contract is one list of `{id,name,color}` named `messageTags`. The raw `messageToTags` join collection
stays `@JsonIgnore`/`@XmlTransient` so other users' assignments never leak.

**Verification:** overview query with a `tagName` LIKE filter narrows to the caller's matching messages;
each returned message's `messageTags` contains only the caller's tags; a second user sees their own (or none)
on the same shared message.

---

### Task B7: Liquibase changeset (author `m.bijalko`)

**Files:**
- Create `src/main/sql/2.11.0/db.changelog-EP13112.xml`.
- Modify `src/main/sql/db.changelog-master.xml` (append one `<include>` as the **last** entry before
  `</databaseChangeLog>`, after the `.\2.11.0\db.changelog-EP13108.xml` line).

**Step 1:** Create the two tables with FKs and indexes (schema via Liquibase only — no raw SQL for schema):

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<databaseChangeLog xmlns="http://www.liquibase.org/xml/ns/dbchangelog" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-3.1.xsd">
    <!-- EP-13103: per-user message tag catalog + message-to-tag assignments. -->
    <changeSet author="m.bijalko" id="create_message_tag_table">
        <createTable tableName="message_tag">
            <column name="id" type="INT" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="name" type="VARCHAR(255)"><constraints nullable="false"/></column>
            <column name="color" type="VARCHAR(20)"><constraints nullable="false"/></column>
            <column name="system_user_id" type="INT"><constraints nullable="false"/></column>
            <column name="creation_datetime" type="DATETIME"/>
        </createTable>
        <addForeignKeyConstraint baseTableName="message_tag" baseColumnNames="system_user_id"
            constraintName="fk_message_tag_system_user" referencedTableName="system_user" referencedColumnNames="id"/>
        <createIndex tableName="message_tag" indexName="idx_message_tag_system_user_id">
            <column name="system_user_id"/>
        </createIndex>
        <rollback><dropTable tableName="message_tag"/></rollback>
    </changeSet>

    <changeSet author="m.bijalko" id="create_message_to_tag_table">
        <createTable tableName="message_to_tag">
            <column name="id" type="INT" autoIncrement="true">
                <constraints primaryKey="true" nullable="false"/>
            </column>
            <column name="message_id" type="INT"><constraints nullable="false"/></column>
            <column name="message_tag_id" type="INT"><constraints nullable="false"/></column>
        </createTable>
        <addForeignKeyConstraint baseTableName="message_to_tag" baseColumnNames="message_id"
            constraintName="fk_message_to_tag_message" referencedTableName="message" referencedColumnNames="id"/>
        <addForeignKeyConstraint baseTableName="message_to_tag" baseColumnNames="message_tag_id"
            constraintName="fk_message_to_tag_message_tag" referencedTableName="message_tag" referencedColumnNames="id"/>
        <createIndex tableName="message_to_tag" indexName="idx_message_to_tag_message_id">
            <column name="message_id"/>
        </createIndex>
        <rollback><dropTable tableName="message_to_tag"/></rollback>
    </changeSet>
</databaseChangeLog>
```

> Verify the real `system_user` PK column name and the `message` PK type against an existing changeset before
> finalizing (the codebase uses `id INT` widely; confirm). Match column charset/collation conventions used by
> neighbouring tables if they set one explicitly.

**Step 2:** Append the include to the master changelog as the final entry:

```xml
    <include file=".\2.11.0\db.changelog-EP13112.xml" relativeToChangelogFile="true"/>
```

**Step 3 — verify migration:** run the app's normal Liquibase migration (deploy to WildFly, or `configS.bat`
per `app-foundation`). Expected: both changesets in `DATABASECHANGELOG`; `DESCRIBE message_tag;` shows
`creation_datetime DATETIME`; FKs and indexes present on both tables.

---

### Task B8: Build, deploy, and commit the backend slice

**Files (commit set):** `dto/MessageTag.java`, `dto/MessageToTag.java`, `dto/Message.java`,
`dao/MessageTagDao.java`, `dao/MessageToTagDao.java`, `dao/MessageDao.java`,
`service/MessageTagService.java`, `service/MessageService.java`, `service/ApplicationConfig.java`,
`src/main/sql/2.11.0/db.changelog-EP13112.xml`, `src/main/sql/db.changelog-master.xml`.

**Step 1 — build (JDK 8):**
Run: `mvn -q -f C:/Innovis/seas_test/publicERANET-server/pom.xml -DskipTests package`
Expected: BUILD SUCCESS, WAR produced. (Per `coding-conventions`: point `JAVA_HOME` at JDK 8 — JDK 21
crashes the EclipseLink static weaver.)

**Step 2 — commit:**
```bash
git -C C:/Innovis/seas_test/publicERANET-server add -A
git -C C:/Innovis/seas_test/publicERANET-server commit -m "feat(EP-13103, EP-13112): add per-user message tag catalog and assignments"
```
Verification: `git -C C:/Innovis/seas_test/publicERANET-server log --oneline -1` shows the exact message.

**Step 3 — DEPLOY + migrate before the frontend slice.** Deploy the WAR to WildFly and run the Liquibase
migration so the tables and `sc/messageTag` endpoints exist. The frontend slice must not start until a manual
`PUT`/`POST /search` against `webresources/sc/messageTag` answers correctly.

---

# FRONTEND SLICE — `publicERANET-client` (only after the backend is deployed + migrated)

All paths under `C:\Innovis\seas_test\publicERANET-client\`. Branch: `seas-test`. One commit (Task F7).

**Reference patterns (read first):**
- Resource: `app/scripts/service/resources/messages.js` (two-factory pattern, `query` POST style).
- ui-select chip + tagging transform: `app/views/suppliers/editCompany.html:365-414`,
  `app/scripts/controllers/general/editCompany.js:57-95,202-215`.
- Colour hex: `app/styles/custom.css:857-889` (`suppliers-status-*`).
- Controller wiring: `app/scripts/controllers/communication/communication.js`
  (`$uibModal` injected line 50; `saveMessage` 201; `storeFilterAndDoReload`/`FILTER_OR_SEARCH_CHANGED` 215-224;
  `messageToSave = _.clone($scope.currentMessage)` 726/769).
- View: `app/views/communication/communication.html` (overview subject cell `:235`; filter row `:189`;
  compose section starts `:258`).

---

### Task F0: Add parallel colour classes (semantic, same hex)

**Files:** Modify `app/styles/custom.css` (after the `suppliers-status-*` block ending ~line 889).

**Step 1:** Add `message-tag-green/orange/red/blue` classes with the **identical hex** to the supplier-status
classes (`#6ab5b4`, `#F48942`, `#a90329`, `#5a87d2`), so the communication markup reads semantically rather
than borrowing supplier classes (per the design doc "Open items / follow-ups"). Keep `border` + `color`
styling parity with the supplier chips.

> If the team would rather reuse `suppliers-status-*` directly, that's a one-line decision — surface it. The
> plan's default is parallel `message-tag-*` classes.

**Verification:** chips render in all four colours (manual smoke).

---

### Task F1: Create the `messageTags.js` resource

**Files:** Create `app/scripts/service/resources/messageTags.js`. Ensure it's picked up by the Grunt build
(glob in `Gruntfile.js` / index include — verify the resources dir is globbed like `messages.js`; if files are
listed explicitly, add it).

**Step 1:** Two-factory pattern, base URL `webresources/sc/messageTag`:

```javascript
'use strict';

angular.module('services').factory('MessageTagsResource', ['$resource',
    function MessageTagsResource($resource) {
        return $resource('webresources/sc/messageTag/:id', { id: '@id' }, {
            create: { method: 'PUT', url: 'webresources/sc/messageTag' },
            search: { method: 'POST', url: 'webresources/sc/messageTag/search', isArray: true }
        });
    }
]);

angular.module('services').factory('MessageTags', ['MessageTagsResource',
    function MessageTags(MessageTagsResource) {
        var serviceResult = {};

        serviceResult.search = function (text, afterLoad) {
            MessageTagsResource.search({}, { text: text }, afterLoad);
        };

        serviceResult.create = function (tag, afterSave) {
            MessageTagsResource.create({}, tag, afterSave);   // tag = { name, color }
        };

        return serviceResult;
    }
]);
```

**Verification:** injecting `MessageTags` resolves; `search('abc', cb)` POSTs to the search endpoint.

---

### Task F2: "Štítky" detail section — one `ui-select multiple` with per-chip colours

**Files:** Modify `app/views/communication/communication.html` (compose/detail block, after the subject section
~line 405-417, before the body/editor) and `app/scripts/controllers/communication/communication.js`.

**Step 1 (controller):** inject `MessageTags`; add `searchTags`:

```javascript
$scope.tagChoices = [];

$scope.searchTags = function (search) {
    if (!search || search.length < 3) {     // ≥3-char minimum enforced client-side
        $scope.tagChoices = [];
        return;
    }
    MessageTags.search(search, function afterLoad(tags) {
        $scope.tagChoices = tags;
    });
};
```

Bind tags on the detail model: `currentMessage.messageTags` is the array of `{id,name,color}` (already
populated from the server on load via B6; default to `[]` when composing a new message).

**Step 2 (view):** one multiselect with colour chips and the built-in remove "X":

```html
<section class="tags-section">
    <label class="label"><strong>{{'communication.tags.title'|translate}}</strong>
        <button type="button" class="btn btn-xs" data-ng-click="openAddTagModal()"
                data-ng-hide="help.readonlyMessageForm">+</button>
    </label>
    <ui-select multiple ng-model="currentMessage.messageTags"
               data-ng-disabled="help.readonlyMessageForm">
        <ui-select-match placeholder="{{'communication.tags.title'|translate}}">
            <span class="tag" data-ng-class="'message-tag-' + $item.color">{{$item.name}}</span>
        </ui-select-match>
        <ui-select-choices minimum-input-length="3" refresh-delay="300"
                           refresh="searchTags($select.search)"
                           repeat="tag in tagChoices track by tag.id">
            <span class="tag" data-ng-class="'message-tag-' + tag.color">{{tag.name}}</span>
        </ui-select-choices>
    </ui-select>
</section>
```

> The built-in `ui-select-match` close button is the "X" that removes a chip from `currentMessage.messageTags`.
> Place this section so it appears for create **and** edit, but render read-only (no add/remove) when
> `help.readonlyMessageForm` — F4 covers the read-only overview chips; the detail read-only state should show
> chips without the "X"/“+”.

**Verification:** typing <3 chars shows no choices; ≥3 chars lists the user's matching tags as colour chips;
selecting adds a chip; the "X" removes it from `currentMessage.messageTags`.

---

### Task F3: "Pridanie štítkov" create modal (Popis + Farba, both required, default Zelený)

**Files:** Modify `app/scripts/controllers/communication/communication.js`; create a small modal template
`app/views/communication/addTagModal.html` (or inline `template` — match how other `$uibModal.open` calls in
this controller pass templates; line ~483 already uses `$uibModal.open`).

**Step 1 (open + handle):**

```javascript
$scope.openAddTagModal = function () {
    var modal = $uibModal.open({
        templateUrl: 'views/communication/addTagModal.html',
        controller: 'AddMessageTagModalController'
    });
    modal.result.then(function (createdTag) {
        if (!createdTag) { return; }
        if (!$scope.currentMessage.messageTags) { $scope.currentMessage.messageTags = []; }
        $scope.currentMessage.messageTags.push(createdTag);   // auto-attach; persists on next save
    });
};
```

**Step 2 (modal controller):** new `AddMessageTagModalController` (in
`controllers/communication/communication.js` or a sibling file in the same dir, registered on the
`controllers` module, array DI, `define` param per conventions):

```javascript
angular.module('controllers')
    .controller('AddMessageTagModalController', ['$scope', '$uibModalInstance', 'MessageTags',
        function define($scope, $uibModalInstance, MessageTags) {
            $scope.colors = [
                { key: 'green',  labelKey: 'communication.tags.color.green'  },
                { key: 'orange', labelKey: 'communication.tags.color.orange' },
                { key: 'red',    labelKey: 'communication.tags.color.red'    },
                { key: 'blue',   labelKey: 'communication.tags.color.blue'   }
            ];
            $scope.newTag = { name: '', color: 'green' };   // default Zelený

            $scope.isValid = function () {
                return $scope.newTag.name && $scope.newTag.name.trim() && $scope.newTag.color;
            };

            $scope.save = function () {
                if (!$scope.isValid()) { return; }
                MessageTags.create($scope.newTag, function afterSave(createdTag) {
                    $uibModalInstance.close(createdTag);
                });
            };

            $scope.cancel = function () { $uibModalInstance.dismiss(); };
        }]);
```

**Step 3 (modal template `addTagModal.html`):** reuse existing modal markup (header/body/footer like other
`$uibModal` templates). **Popis** = text input bound to `newTag.name`; **Farba** = `ui-select` (or plain
`<select>`) over `colors` bound to `newTag.color`, each option showing a colour chip via
`message-tag-{{key}}`. **Uložiť** disabled until `isValid()`.

**Verification:** "+" opens the modal; Uložiť disabled until both Popis and Farba set; default colour is green;
on save the new tag appears as a chip on the message immediately.

---

### Task F4: Overview — read-only colour chips right of the subject

**Files:** Modify `app/views/communication/communication.html` (overview subject cell, line ~235).

**Step 1:** After the subject span (`{{message.subject}}`), iterate the server-populated `message.messageTags`
(current-user tags from B6) as **read-only** colour chips (no "X"):

```html
<span data-ng-repeat="tag in message.messageTags"
      class="tag" data-ng-class="'message-tag-' + tag.color"
      style="margin-left: 4px;">{{tag.name}}</span>
```

Apply to all three folder states (`inbox`/Odoslané, `drafts`/Koncepty, `external`/Externá komunikácia) — the
row template is shared, so placing it in the subject cell covers all folders; verify each during smoke testing.

**Verification:** the overview shows the caller's tags as coloured, non-removable chips beside each subject.

---

### Task F5: Dedicated "Štítky" free-text filter in the overview filter row

**Files:** Modify `app/views/communication/communication.html` (filter row ~line 186-191) and, if the filter
key needs mapping, `app/scripts/service/resources/messages.js` / the filter wiring.

**Step 1:** Add a new filter cell using the existing `<text-filter>` directive (same as `subject` at line 189),
with a new name `tagName` (must match `Message.FILTER_NAME_TAG_NAME` on the server). Add the matching header
cell so columns stay aligned:

```html
<td data-ng-show="showFilter"><text-filter name="tagName"></text-filter></td>
```

This routes through the established `FilterHelper`/`text-filter` → `FILTER_OR_SEARCH_CHANGED` →
`storeFilterAndDoReload()` path (`communication.js:215-224`), so the `tagName` LIKE filter is added to the
query POST automatically. **Do not** fold it into the subject filter — it is a separate input (locked decision 2).

> Verify `text-filter` emits a LIKE filter under the given `name`; the server scopes to the current user.
> Confirm column count in header vs. filter vs. data rows stays balanced after adding the cell.

**Verification:** typing in the "Štítky" filter narrows the list to messages with a matching caller-owned tag;
the subject filter still works independently.

---

### Task F6: i18n keys (English keys, Slovak values)

**Files:** Modify the Slovak i18n file(s) under `app/i18n/` (and any other locale files present — keep keys in
sync across locales; values translated).

**Step 1:** Add keys (English identifiers only):

```
communication.tags.title          = "Štítky"
communication.tags.addTitle       = "Pridanie štítkov"
communication.tags.name           = "Popis"
communication.tags.color          = "Farba"
communication.tags.color.green    = "Zelený"
communication.tags.color.orange   = "Oranžový"
communication.tags.color.red      = "Bordový"
communication.tags.color.blue     = "Modrý"
communication.tags.save           = "Uložiť"   (reuse an existing save key if one exists — check first)
```

> Reuse existing generic keys (Uložiť/Zrušiť) where they already exist rather than duplicating. No Slovak in
> code or keys — only in values.

**Verification:** the section title, modal title, field labels, and colour labels all render in Slovak; no raw
keys leak in the UI.

---

### Task F7: Karma/Jasmine unit tests + build, then commit

**Files:** Create `test/spec/controllers/communicationTags.js` (or extend the existing communication spec if one
was added by EP-13100). Mirror the harness reality note from the EP-13100 plan — confirm the real Angular module
name from `app/scripts/ng.app.js` and mock heavy DI; scope to verifiable units rather than fabricating coverage.

**Step 1 — unit tests (the design doc's required cases):**
- `searchTags` triggers `MessageTags.search` only at ≥3 chars (and clears choices below 3).
- creating a tag via the modal controller auto-attaches the returned tag to `currentMessage.messageTags`.
- removing a chip drops it from `currentMessage.messageTags`.
- the create-modal `isValid()` is false until both Popis and Farba are set; default colour is `green`.

```javascript
'use strict';
describe('Communication tags', function () {
    beforeEach(module('<REAL_APP_MODULE_NAME>'));   // from ng.app.js

    it('search only fires at >= 3 chars', inject(function ($controller, $rootScope) {
        var searched = null;
        var MessageTags = { search: function (t) { searched = t; } };
        var scope = $rootScope.$new();
        // instantiate the controller with mocked deps, then:
        scope.searchTags('ab'); expect(searched).toBeNull();
        scope.searchTags('abc'); expect(searched).toBe('abc');
    }));
    // ...remaining cases per the design doc
});
```

**Step 2 — run:** `npx karma start karma.conf.js --single-run`
Expected: existing specs stay green; new specs pass (or are scoped per the harness reality note — do not
fabricate green tests).

**Step 3 — lint/build:** `grunt test` (JSHint per `coding-conventions`: camelcase, single quotes, tabs).

**Step 4 — commit:**
```bash
git -C C:/Innovis/seas_test/publicERANET-client add -A
git -C C:/Innovis/seas_test/publicERANET-client commit -m "feat(EP-13103, EP-13112): add tag chips, create modal and filter to communication"
```
Verification: `git -C C:/Innovis/seas_test/publicERANET-client log --oneline -1` shows the exact message.

---

## Verification & testing checklist (run before claiming done — `superpowers:verification-before-completion`)

### Backend
- [ ] `mvn package` BUILD SUCCESS on JDK 8.
- [ ] Liquibase: `create_message_tag_table` + `create_message_to_tag_table` in `DATABASECHANGELOG`;
      `DESCRIBE message_tag;` shows `creation_datetime DATETIME`; FKs + indexes present.
- [ ] `PUT sc/messageTag {name,color}` returns the saved tag with server-set owner + id; bad/empty
      name or colour → 400; an invalid colour value → 400.
- [ ] `POST sc/messageTag/search {text}` returns only the caller's matching tags; a second user sees none of
      the first user's tags.
- [ ] Save a message with tags → correct `message_to_tag` rows for the caller; re-save with a tag removed →
      row deleted; a second user's tag on the same shared message is untouched.
- [ ] A crafted save payload referencing a **foreign** tag id does not create a link to it.

### Frontend (manual smoke, all three folders)
- [ ] Detail: typing <3 chars shows no suggestions; ≥3 chars suggests the user's saved tags as colour chips.
- [ ] "+" opens "Pridanie štítkov"; Uložiť disabled until Popis + Farba set; default colour Zelený; on save the
      new tag auto-attaches to the message.
- [ ] Chip "X" removes a tag from the message; save → reload keeps the remaining tags.
- [ ] Overview: tags render read-only (no "X") right of the subject in Odoslané, Koncepty, and Externá komunikácia.
- [ ] "Štítky" filter narrows the list by tag name (independent of the subject filter).
- [ ] A second user does not see the first user's tags anywhere (detail, overview, search, filter).
- [ ] Chip colours are correct (green/orange/red/blue) in all three folders.

### Automated
- [ ] Karma: existing specs green + new tag specs pass (or scoped per the harness reality note).
- [ ] `grunt test` (JSHint) clean.

---

## Open questions / risks (surface to the user; do not unilaterally resolve)

1. **Jira ticket not read directly.** The Atlassian MCP `getJiraIssue` tool was **not available** in this
   environment, so EP-13103 could not be pulled live. This plan is built on the **locked, committed design
   doc** (`2026-06-19-ep-13103-message-tags-design.md`), which carries an explicit acceptance-criteria → coverage
   table. If the live ticket has acceptance criteria not reflected in that design doc, this plan must be revisited.
   **Recommendation:** confirm the design doc is the authoritative source, or paste the ticket text.
2. **Current-user id inside `MessageDao`.** `getCurrentUser()` lives on `BaseService`, not the DAO. The
   owner-scoping for the `tagName` filter and the overview population must get the caller id from the service
   layer (as the existing supplier/`ownerCompanyId` scoping does) rather than reading the principal in the DAO.
   The executor must verify the cleanest existing mechanism and follow it — flag if neither path is clean.
3. **Where to populate per-user `messageTags` on the overview** (DAO join-mapping vs. service post-query). Both
   work; the service-side post-query (option a in B6) is simpler and avoids row duplication from the tag join,
   but adds a second query per page. Pick one; surface the trade-off rather than guessing.
4. **`messageTags` wire field doubling as input and output.** The same JSON field is sent on save (desired set)
   and returned on load (current set). This is intentional and keeps the contract small, but the executor must
   ensure the raw `messageToTags` join collection is **not** serialized (no leaking of other users' assignments).
5. **Search request DTO.** Check `dao/helpDto/` for an existing `RestString`-style single-field request before
   adding a new `SearchRequest` class (a `RestInteger` exists). Reuse if present.
6. **Karma harness reality.** As noted in the EP-13100 plan, `karma.conf.js` may load a test module rather than
   the real app module, and `CommunicationController` has heavy DI. Scope the specs to verifiable units; do not
   fabricate green controller tests.
7. **External communication shares the controller/templates.** The design doc assumes Externá komunikácia uses
   the same `communication.js`/`communication.html`. Verify during smoke testing that its detail + overview pick
   up the tag section, chips, and filter — if it uses a separate template, the FE tasks must be applied there too.
8. **Grunt file registration.** New `messageTags.js` and any new modal/spec files must be included by the Grunt
   build (glob or explicit list). Confirm before assuming pickup.
```
