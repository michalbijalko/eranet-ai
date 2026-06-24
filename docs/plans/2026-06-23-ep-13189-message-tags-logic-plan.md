# EP-13189 — Message tags: new role/context logic (Implementation Plan)

**Ticket:** Dev Sub-task **EP-13189** · Parent Story **EP-13103** ("štítky v komunikácii") · Epic EP-12988
**Design (signed off):** `docs/plans/2026-06-23-ep-13189-message-tags-logic-design.md`
**Builds on:** EP-13103 / EP-13112 (tags feature) · EP-13188 (supplier hiding).
**Commit pair:** `feat(EP-13103, EP-13189): …`
**Prerequisite before any commit:** add the row `| Message tags: role/context logic | EP-13103 | EP-13189 |`
to `docs/TICKETS.md` (not present today).

This plan turns the locked design into ordered, file-and-line-referenced steps. **Plan only — no app code is written here.**
Everything is enforced on the server; the client only mirrors it for UX.

> **Two previously-open items are now LOCKED (folded into this plan as the agreed defaults):**
> 1. **Cascade scope:** the "no related activity ⇒ delete tags" rule applies **only where removal can happen
>    today** — draft edit and parent-procurement cascade. **No new unlink endpoint for sent messages**; sent
>    messages keep their link and their tags.
> 2. **Multi-link authorization:** a user may write a message's tags if they are responsible/admin for **any one**
>    of the message's linked procurements (loop, pass if authorized for at least one).

---

## Resolved open items (research result)

### A. Server-side "responsible person OR admin/superadmin for this message's procurement" check
**Resolved.** The cleanest reusable analog already exists in
`service/SystemUserInProcurementService.java`:

- `isCurrentUserInAdditionalRole(Integer procurementId, Short role)` (line 552, `@PermitAll`) — runs the exact
  query needed for the responsible-person part:
  `system_user_id = currentUser AND additional_role = :role AND procurement_id = :procurementId`.
  Call it with `SystemUserInProcurement.ADDITIONAL_ROLE_RESPONSIBLE_PERSON` (value `0`, line 39 of the DTO).
- Admin / superadmin is checked exactly as the existing `checkIfIsAdminOrAuthorOrSystemAdmin` (line 361) does:
  `getCurrentUser().isInRole(SystemUserGroupType.systemAdministrator)` or `... .isInRole(SystemUserGroupType.administrator)`
  (`SystemUser.isInRole`, `SystemUser.java:423`; enum values `SystemUserGroupType.java:6,11`). This matches the
  client `hasAccessInProcurementAsResponsiblePerson()` which short-circuits `true` for admins (`main.js:860`).

**Decision:** add ONE new `@PermitAll` helper to `SystemUserInProcurementService` —
`isCurrentUserResponsibleOrAdminForProcurement(Integer procurementId)` — that returns
`isInRole(systemAdministrator) || isInRole(administrator) || isCurrentUserInAdditionalRole(procurementId, ADDITIONAL_ROLE_RESPONSIBLE_PERSON)`.
This keeps the admin-OR-responsible logic in one place, reuses existing query helpers, and uses no direct DAO
calls (it delegates to `findAllInternal` inside `isCurrentUserInAdditionalRole`). `MessageTagService` already has
the procurement id(s) available on each message via `message.getMessageToProcurement()` (see item B), so it injects
`SystemUserInProcurementService` and calls this helper **once per linked procurement (any-of semantics, LOCKED)** —
authorize if the helper returns true for at least one of the message's `MessageToProcurement` links.

**Where to call it:** inside `MessageTagService.reconcileCurrentUserTags(...)` (the single choke point — every
write path runs through it: `MessageService` create:210, update:306, sendDraft:367, setMyTags:419). One check
there covers all four entry points. No per-endpoint duplication.

### B. "Related activity = a MessageToProcurement link" + cascade-delete on last-link removal
**Resolved and LOCKED (cascade scope agreed below).**

- The procurement id(s) for a message are on `Message.messageToProcurement`
  (`dto/Message.java:108`, getter `getMessageToProcurement()` line 144) — a `@OneToMany(... orphanRemoval = true)`
  collection, already serialized to/from the client (the overview iterates it at `communication.html:250`).
- **Write-gate:** in `reconcileCurrentUserTags`, if `message.getMessageToProcurement()` is null/empty →
  the message has no related activity → **skip all tag writes** (return). This also blocks tag writes on
  qualification-system-only messages (item D) and on contact-notification messages.
- **Cascade-delete scope — LOCKED:** there is **no dedicated `MessageToProcurementService`/unlink endpoint** in
  the server (verified: grep for `MessageToProcurementService` / `MessageToProcurementDao` returns nothing; the
  link is managed only through `Message.messageToProcurement` cascade + orphanRemoval via message
  `create`/`update`). **Agreed decision:** apply the "no related activity ⇒ delete tags" rule ONLY where removal
  can actually happen today — **draft edit** (`MessageService.update`, line 282, when an incoming draft payload
  arrives with an emptied `messageToProcurement` list and orphanRemoval deletes the rows) and **parent-procurement
  cascade**. **No new unlink endpoint is added for sent messages**; sent (non-draft) messages keep their link and
  their tags — they are already blocked from `update` at `MessageService.java:293`, so the last link cannot be
  stripped from a sent message and no special handling is required.
- **Hook the cascade in `reconcileCurrentUserTags`:** when the message has no related activity, instead of only
  skipping, **also delete every `MessageToTag` row for that message id** (team-wide, not owner-scoped) via a
  `BaseService`-backed method on `MessageToTagService`. That single rule ("no related activity ⇒ no tag rows")
  implements both the write-gate and the cascade-delete in one branch, and is enforced regardless of which of the
  two agreed paths emptied the link.

### C. How the client learns a message has related activity
**Resolved — no new payload field needed.** `Message.messageToProcurement` is already serialized on every
message (overview binds `message.messageToProcurement` at `communication.html:250`; the opened message is loaded
via `MessageService.getEntityById`, same DTO). The client gates on
`currentMessage.messageToProcurement && currentMessage.messageToProcurement.length > 0`. **No server payload
change.** (The transient `messageTags` already rides along too, `dto/Message.java:123`.)

### D. Detecting a qualification-system context for a message
**Resolved — no new field needed.** `Message.messageToQualificationSystem`
(`dto/Message.java:111`, getter line 287) is already on the DTO and serialized. A message in a qualification-system
context has a non-empty `messageToQualificationSystem`. The server suppresses tags by the same
"related activity = MessageToProcurement" rule in item B: a qualification-system message has **no**
`MessageToProcurement` link, so `reconcile` already skips writes and `populate` simply returns no tags for it.
The client additionally hides the panel when `currentMessage.messageToQualificationSystem.length > 0` (belt-and-suspenders;
the procurement-link check already covers it).

---

## Backend slice (`publicERANET-server`)

Build after every step: `mvn -q -f publicERANET-server/pom.xml -DskipTests package` (JDK 8) → BUILD SUCCESS.

### B1. Add the procurement-role authorization helper
**File:** `service/SystemUserInProcurementService.java`
- Add a `@PermitAll public boolean isCurrentUserResponsibleOrAdminForProcurement(final Integer procurementId)`
  near the existing role helpers (after `isCurrentUserInAdditionalRole`, line 559).
- Body: `return getCurrentUser().isInRole(SystemUserGroupType.systemAdministrator)
  || getCurrentUser().isInRole(SystemUserGroupType.administrator)
  || isCurrentUserInAdditionalRole(procurementId, SystemUserInProcurement.ADDITIONAL_ROLE_RESPONSIBLE_PERSON);`
- Pattern to copy: `checkIfIsAdminOrAuthorOrSystemAdmin` (line 361) for the admin-role test;
  `isCurrentUserInAdditionalRole` (line 552) for the responsible-person query. No direct DAO calls.
- This helper checks **one** procurement; the any-of loop over a message's links lives in `reconcile` (B4 step 2).
- **Verify:** compiles; returns true for admin/superadmin regardless of procurement, and for a responsible
  person on that procurement.

### B2. Add a team-wide "delete all tag rows for a message" method
**File:** `service/MessageToTagService.java`
- Add `public void deleteAllByMessageIdInternal(final Integer messageId)` that loads
  `findByMessageIdInternal(messageId)` (existing, line 27) and calls `super.delete(assignment.getId())` for each
  (mirrors `deleteInternalById`, line 48 — `BaseService`-backed, no direct DAO).
- **Verify:** compiles.

### B3. Make tag population team-wide (shared visibility)
**File:** `service/MessageTagService.java`, `populateCurrentUserTags(...)` (line 129)
- **Remove the owner filter** at line 145 (`!ownerId.equals(tag.getSystemUserId())`) so **all** assignments'
  tags are grouped per message — every buyer-side viewer sees the whole team's tags. Drop the now-unused
  `ownerId` local (lines 134) if it becomes dead.
- Rename the method to `populateMessageTags(...)` (no longer user-scoped) and update its one caller
  `MessageService.java:1219`. Keep it `@PermitAll` and keep the single batched query
  (`messageToTagService.findByMessageIdsInternal`).
- **Note:** suppliers still see nothing because EP-13188 hides the column client-side and suppliers own no tags;
  team-wide population is correct for buyers and harmless for suppliers (a supplier's messages have no buyer tags
  in their own view scope). No supplier regression — confirm in smoke.
- **Verify:** compiles; build green.

### B4. Role-gate + remove-any reconcile; keep add-own
**File:** `service/MessageTagService.java`, `reconcileCurrentUserTags(...)` (line 93)
- Inject `@EJB private SystemUserInProcurementService systemUserInProcurementService;` and
  `@EJB private MessageToTagService messageToTagService;` (already present).
- **Step 1 — related-activity gate + cascade (item B, LOCKED scope):** if
  `message.getMessageToProcurement() == null || message.getMessageToProcurement().isEmpty()`:
  - call `messageToTagService.deleteAllByMessageIdInternal(message.getId())` (cascade-delete) and **return**.
  This is the "no related activity ⇒ no tags" rule (also covers qualification-system context, item D). It fires
  only on the two paths that can empty the link (draft edit, parent-procurement cascade); sent messages never
  reach this branch with an emptied link because they cannot be updated.
- **Step 2 — authorization, any-of (item A, LOCKED):** **loop over `message.getMessageToProcurement()`**; for each
  link take `link.getProcurementId()` and call
  `systemUserInProcurementService.isCurrentUserResponsibleOrAdminForProcurement(procurementId)`. If **none** of
  the links return true → `throw new WebApplicationException(Response.Status.FORBIDDEN)`. Pass (continue to the
  reconcile) as soon as **any one** link authorizes. (A read-only viewer who somehow POSTs gets 403. Admins/superadmins
  pass on the first iteration regardless of the procurement.)
- **Step 3 — reconcile ALL assignments (remove-any):** replace `findOwnedAssignments(message.getId(), ownerId)`
  (line 101) with `messageToTagService.findByMessageIdInternal(message.getId())` so an authorized user may
  **remove any** existing assignment (including other buyers'). Drop the `findOwnedAssignments` helper (line 181)
  once unused.
- **Step 4 — additions stay own-catalog:** keep `collectOwnedDesiredTagIds(message.getMessageTags(), ownerId)`
  (line 162 / 99) unchanged — a newly added chip must still be one of the caller's own `MessageTag` rows. The
  remove loop now compares against the full assignment set; the add loop still only adds caller-owned tag ids.
- Update the Javadoc (lines 87–91) to describe the new shared/role-gated behavior; rename the method to
  `reconcileMessageTags(...)` and update the four callers (`MessageService` 210, 306, 367, 419).
- **Verify:** compiles; a responsible user can remove a tag another user added; a non-responsible user gets 403;
  a tag id not owned by the caller is still ignored on add; a user responsible for any one linked procurement passes.

### B5. Endpoint authorization is covered by B4
**File:** `service/MessageService.java`
- `setMyTags` (line 407) and the reconcile calls in `create`/`update`/`sendDraft` (210/306/367/419) **need no
  per-method change** — they all funnel through `reconcileMessageTags`, which now authorizes (B4 step 2) and
  gates on related activity (B4 step 1). Leave `@RolesAllowed(ROLE_NAME_USER)` on `setMyTags` (EP-13188 already
  dropped SUPPLIER). The reconcile inside `create`/`update`/`sendDraft` becomes a **no-op for users without write
  rights** only when they have no related activity; if a non-responsible buyer somehow sends a procurement-linked
  message with tags, the 403 in reconcile is acceptable per the design (server-enforced). Confirm during smoke
  that a normal responsible-person send still succeeds (it will: they pass the auth check).
- **Verify:** build green; existing send/create flows for responsible persons unaffected.

### B6. Qualification systems — no schema change
Covered by B4 step 1 (no `MessageToProcurement` ⇒ skip + delete). No code beyond B4. `MessageToQualificationSystem`
is read-only context here. **No Liquibase changeset** is introduced by this ticket (no new entity/column/index).
If B3's team-wide population surfaces a missing index on `message_to_tag.message_id`, note it — but the EP-13103
changeset already added that index, so none is expected.

---

## Frontend slice (`publicERANET-client`)

Build/lint after changes: `grunt test` (JSHint + Karma) → clean & green.

### F1. Compute tag-permission flags in the controller
**File:** `controllers/communication/communication.js` (`CommunicationController`)
- Add two helpers on `$scope` near the tag code (after `searchTags`, line 206):
  - `$scope.messageHasRelatedActivity = function () { return $scope.currentMessage
    && $scope.currentMessage.messageToProcurement && $scope.currentMessage.messageToProcurement.length > 0; };`
  - `$scope.canEditMessageTags = function () { return $scope.messageHasRelatedActivity()
    && !$root.isSupplier() && $root.hasAccessInProcurementAsResponsiblePerson(); };`
  (`hasAccessInProcurementAsResponsiblePerson` already returns true for admins — `main.js:860`; `isSupplier` —
  `main.js:69`.)
- **Verify:** JSHint clean; helpers return expected booleans in unit tests.

### F2. Panel visibility — show only with related activity, hide editing for viewers
**File:** `views/communication/communication.html`
- **Panel container** (line 145): change the gate from `data-ng-hide="$root.isSupplier()"` to
  `data-ng-show="messageHasRelatedActivity() && !$root.isSupplier()
  && (!currentMessage.messageToQualificationSystem || currentMessage.messageToQualificationSystem.length === 0)"`.
  (No related activity / qualification-system / supplier ⇒ no section at all.)
- **Add "+" button** (line 147): wrap in `data-ng-show="canEditMessageTags()"` so read-only viewers don't see it.
- **`ui-select` editing** (lines 149–161): for read-only viewers render chips **without** remove. Simplest faithful
  approach: keep the `ui-select multiple` only when `canEditMessageTags()`; for viewers render a read-only chip list
  (reuse the overview chip markup, lines 263–264) bound to `currentMessage.messageTags`. Use
  `data-ng-show="canEditMessageTags()"` on the editable `ui-select` and a sibling read-only `<div>` with
  `data-ng-show="!canEditMessageTags()"`.
- **Verify (manual):** responsible person sees editable multiselect + "+"; commission/other buyer sees chips only;
  message with no related activity shows no panel.

### F3. Auto-save on add/remove; remove the manual button
**File:** `controllers/communication/communication.js`
- **Remove** the manual `saveMessageTags()` button at `communication.html:511` (whole `<button>`).
- Rework `saveMessageTags` (line 232) into an internal `persistTagsForExistingMessage()` that calls
  `Messages.setMyTags($scope.currentMessage.id, $scope.currentMessage.messageTags, ...)` and is invoked on each
  **add** and **remove** for an already sent/received message (`$scope.currentMessage.id` set and
  `$scope.help.readonlyMessageForm`). New messages keep persisting on send/save (no change).
- **Wire add:** in `openAddTagModal`'s `attachCreatedTag` (line 221) and on `ui-select` model change for an
  existing message, call `persistTagsForExistingMessage()`. **Wire remove:** add an `on-remove` /
  `ng-change`/`$select` removal hook on the editable `ui-select` (line 149) that calls it. Keep auto-save guarded
  so it never fires for a brand-new (unsaved) message.
- Drop the now-unused `COMMUNICATION_TAGS_SAVED` success toast if the design prefers silent auto-save, or keep a
  lightweight success (design says "auto-save"; prefer silent or a brief `Alerts.success`). Match existing UX.
- **Verify (unit):** auto-save fires once on add and once on remove for an existing message; never for a new one.

### F4. Overview chips stay read-only and now reflect team tags
**File:** `views/communication/communication.html` (lines 262–266) — **no change needed**; the server now
populates team-wide tags (B3) into `message.messageTags`, and the overview already renders them read-only. Confirm
the supplier-hide gates from EP-13188 (lines 202, 210, 217, 262) are untouched.

### F5. i18n
- Reuse existing `COMMUNICATION_TAGS_*` keys. The removed save button drops the need for `COMMUNICATION_TAGS_SAVE`
  in markup (leave the key defined; harmless). Add any new label (e.g. a read-only "Štítky" caption) as an English
  key with a Slovak value only — no Slovak in code/keys.

### F6. Unit tests (Karma/Jasmine)
**File:** the existing communication controller spec (under `test/`).
- Panel hidden when `currentMessage.messageToProcurement` empty.
- `canEditMessageTags()` false for supplier, false when not responsible/admin, true for responsible/admin with
  related activity.
- Auto-save (`Messages.setMyTags`) called on add and on remove for an existing message; not called for a new one.
- Add restricted to own catalog is server-side (no client assertion needed beyond passing the selected tags).

---

## Verification checklist (before committing — confirm in the running app)

### Backend
- [ ] `mvn -q -f publicERANET-server/pom.xml -DskipTests package` (JDK 8) → BUILD SUCCESS.
- [ ] Responsible person / admin / superadmin: `POST sc/message/setMyTags` on a procurement-linked message
      succeeds; can **remove** a tag another responsible person added.
- [ ] Multi-link message: a user responsible/admin for **any one** linked procurement can write its tags;
      a user responsible for **none** of them → **403**.
- [ ] Commission member / other buyer: `POST sc/message/setMyTags` → **403**.
- [ ] Message with no `MessageToProcurement`: tag write is a no-op and any existing `message_to_tag` rows for it
      are deleted; populate returns no tags.
- [ ] Qualification-system message: no tag reads/writes.
- [ ] Supplier (regression): still 403 on `messageTag` create/search and `setMyTags` (EP-13188 intact).
- [ ] Responsible-person send/save/sendDraft of a tagged, procurement-linked message still works.

### Frontend (manual smoke per design §Testing)
- [ ] Responsible person: add a tag → it persists immediately (auto-save), reload keeps it; delete a tag added by
      another responsible person.
- [ ] Commission member: sees the same chips, **no** add "+"/remove/multiselect; cannot write.
- [ ] Message with no related activity: **no** tags section; after the last related activity is removed from a
      **draft** tagged message, tags and section disappear.
- [ ] Qualification system: no tags anywhere.
- [ ] Supplier (regression, EP-13188): still no tag panel and no Štítky column.
- [ ] `grunt test` clean (JSHint + Karma green).

---

## Commit plan
- `docs/TICKETS.md`: add the `EP-13103 → EP-13189` row **first** (separate from code, or in the docs commit).
- Server: `feat(EP-13103, EP-13189): share message tags across buyer team and gate writes by procurement role`
- Client: `feat(EP-13103, EP-13189): role/context-gate message tags and auto-save on add/remove`
- One ticket per commit; confirm behavior in the running app before committing.

## Locked decisions (previously open)
1. **Cascade scope — LOCKED.** Apply "no related activity ⇒ delete tags" ONLY where removal can happen today:
   **draft edit** and **parent-procurement cascade**. **No new unlink endpoint for sent messages.** Sent messages
   keep their link and their tags (they cannot be updated — `MessageService.java:293`). The single rule in
   `reconcileMessageTags` is the complete and sufficient hook; no further wiring is needed.
2. **Multi-link authorization — LOCKED.** A user may write a message's tags if they are a responsible person or
   admin/superadmin for **any one** of the message's linked `MessageToProcurement` procurements. `reconcile`
   loops over the links and passes on the first that authorizes (B4 step 2); admins/superadmins pass immediately.
