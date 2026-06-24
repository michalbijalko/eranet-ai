# EP-13189 — Message tags: new role/context logic (Design)

**Ticket:** Dev Sub-task **EP-13189** · Parent Story **EP-13103** ("štítky v komunikácii") · Epic EP-12988
**Reporter:** Martin Oravec
**Builds on:** EP-13103 / EP-13112 (the message tags feature) and EP-13188 (supplier hiding).
**Commit pair (from `docs/TICKETS.md`):** `feat(EP-13103, EP-13189): …` *(add the row before committing — not yet present).*

**Goal:** Replace the original *private-per-user* tag model with a **role- and context-based** model on the
buyer side. Tags on a message become **visible to the whole buyer team**; **write access is gated by
procurement role**; the section only appears when the message has **related activity on the tender**; and
**qualification systems have no tags at all**.

---

## Scope clarification

The ticket title reads "Pohľad dodávateľa – Úprava zobrazenia štítkov" (supplier view) but the **entire
description is buyer-side**. Confirmed with the user: **the description is authoritative — implement the
buyer-side rules.** Supplier hiding is already delivered by EP-13188 and is left untouched.

---

## Locked decisions

1. **Tag visibility is now SHARED across the buyer team.** On a message, every buyer-side participant
   (responsible persons, admins, commission members, any other buyer with tender access) sees **all** tags,
   regardless of who added them. *(Was: each user saw only their own.)*
2. **The catalog stays per-user.** `MessageTag` is still owned via `system_user_id`; you create and search
   **only your own** tag definitions, and you can **add only your own** catalog tags to a message.
3. **Write access is BINARY and role-based:** only a **responsible person** *or* **admin/superadmin** for the
   message's procurement may **add / edit / delete** tags — and they may edit/delete **any** tag on **any**
   message (including ones another buyer added). **Everyone else is read-only** (commission members and any
   other buyer with access). "Druhý nákupca" = another responsible person.
4. **"Related activity on the tender" = a `MessageToProcurement` link.** A message with **no**
   `MessageToProcurement` row shows **no tags section** and accepts no tag writes. When the **last**
   `MessageToProcurement` link is removed, the message's tag assignments are **cascade-deleted** and the
   section disappears. Enforced on the server.
5. **Qualification systems have no tags** for anyone (hidden + blocked).
6. **Saving:** on a **new** message, tags persist with the message save/send. On an **already sent/received**
   message, tags **auto-save immediately** on each add/remove — the manual "save tags" button is removed.
7. **Enforced on the backend, not just hidden in the UI** (same principle as EP-13188).

### Decisions resolved during planning (previously open — now LOCKED)

8. **Cascade-delete scope.** The "no related activity ⇒ delete tags" rule is applied **only where removal can
   actually happen today**: **draft edit** (an emptied `messageToProcurement` on a draft update) and
   **parent-procurement cascade**. **No new unlink endpoint is added for sent messages** — sent (non-draft)
   messages cannot be updated (`MessageService` blocks it), so their link and tags are retained. The single
   "no related activity ⇒ no tag rows" branch in the tag reconcile is the complete hook.
9. **Multi-link authorization (any-of).** A message may carry several `MessageToProcurement` links. A user may
   write its tags if they are a responsible person or admin/superadmin for **any one** of those linked
   procurements (the reconcile loops over the links and passes on the first that authorizes).

---

## Permission matrix

| Actor (buyer side) | See tags (detail + overview) | Add own catalog tag | Edit/delete any tag on any message |
|---|---|---|---|
| **Responsible person** *or* **admin / superadmin** (for that procurement) | ✅ | ✅ | ✅ |
| **Commission member** & any other buyer with access | ✅ | ❌ | ❌ |
| **Supplier** (EP-13188) | ❌ | ❌ | ❌ |
| **Qualification-system context** | ❌ | ❌ | ❌ |

**Authorization pivot (server):** *"Is the current user a responsible person or admin/superadmin for the
procurement this message is linked to?"* — the server analog of the client's
`hasAccessInProcurementAsResponsiblePerson()` (which already returns true for admins). **Located during
planning:** reuse `SystemUserInProcurementService.isCurrentUserInAdditionalRole(procurementId,
ADDITIONAL_ROLE_RESPONSIBLE_PERSON)` for the responsible-person part and `getCurrentUser().isInRole(
systemAdministrator/administrator)` for the admin part, wrapped in a new
`isCurrentUserResponsibleOrAdminForProcurement(procurementId)` helper, applied with **any-of** semantics over
the message's `MessageToProcurement` links. See the implementation plan for exact steps.

---

## Server changes (`publicERANET-server`)

The current tag logic is entirely **owner-scoped** and must shift to **team-visible + role-gated**.

1. **`MessageTagService.populateCurrentUserTags(...)`** (`service/MessageTagService.java:129`) — currently
   loads only the current user's tags (`ownerId.equals(tag.getSystemUserId())` filter at line 145). Change to
   load **all** assignments' tags for each message so the whole buyer team sees them. (Rename away from
   "CurrentUser" since it is no longer user-scoped.) Keep the single batched query.

2. **`MessageTagService.reconcileCurrentUserTags(...)`** (`service/MessageTagService.java:93`) — currently
   reconciles only the current user's assignments (`findOwnedAssignments`, line 101). Change to:
   - **Authorize first (any-of):** reject unless the caller is a responsible person/admin for **any one** of the
     message's linked procurements (else `403`).
   - **Reconcile all assignments** on the message — a responsible/admin may **remove any** existing assignment
     (including other users').
   - **Additions still restricted to the caller's own catalog** — keep `collectOwnedDesiredTagIds`
     (line 162) so a new chip must be one of the caller's own `MessageTag` rows.

3. **`MessageService.setMyTags`** (`service/MessageService.java:407`) — keep as the persist endpoint for an
   existing message, but enforce the new **procurement-role authorization** before reconciling. The
   `reconcile` calls inside `create` / `update` / `sendDraft` apply the same authorization (no-op for users
   without write rights).

4. **Related-activity gate (server):**
   - Block tag writes when the message has **no** `MessageToProcurement` link.
   - When the **last** `MessageToProcurement` link is removed (draft edit or parent-procurement cascade — the
     two paths that can happen today; **no new unlink endpoint for sent messages**), **delete the message's
     `MessageToTag` rows**. Via a `BaseService` method — no direct DAO calls.

5. **Qualification systems:** tag writes/reads are suppressed for messages in a qualification-system context
   (`MessageToQualificationSystem`). No schema change.

**No new entities or columns** — `MessageTag` / `MessageToTag` are reused. **No Liquibase** unless planning
finds a missing index. Authorization is taken from the server, never trusted from the client.

---

## Client changes (`publicERANET-client`)

In `controllers/communication/communication.js` + `views/communication/communication.html`:

1. **Tags panel visibility** — show only when **all** hold: not `$root.isSupplier()`, not a
   qualification-system context, the message **has related activity** (`MessageToProcurement` present, exposed
   on the loaded message), and — for the **editable** controls (add "+", "X" remove, multiselect) — the user is
   a **responsible person / admin** (`hasAccessInProcurementAsResponsiblePerson()`). Read-only viewers
   (commission/others) see chips **without** add/remove.

2. **Auto-save replaces the manual button** — remove `saveMessageTags()`'s button
   (`communication.html:511`) and instead persist on each add/remove for an already sent/received message
   (call `Messages.setMyTags` on chip add and on chip removal). New messages persist on send/save as today.

3. **Overview chips** — stay read-only for everyone; they now reflect **team** tags (server populates all).

4. **i18n:** reuse existing `communication.tags.*` keys; add any new label in English keys / Slovak values.

---

## Testing

- **Unit (Karma/Jasmine):** panel hidden without related activity; edit controls hidden for non-responsible /
  commission; auto-save fires on add and on remove for existing messages; add restricted to own catalog.
- **Manual smoke:**
  - Responsible person: add a tag, see it persist; delete a tag another responsible person added.
  - Commission member: sees the same chips, **no** add/remove controls, no writes possible (and `403` if forced).
  - Message with no related activity: **no** tags section; after removing the last related activity from a
    tagged **draft** message, the tags and section disappear.
  - Qualification system: no tags anywhere.
  - Supplier (regression, EP-13188): still no tags.

---

## Work split (for the executor agents)

- **Backend slice (`executor-backend`):** procurement-role authorization helper; team-wide `populate`;
  role-gated `reconcile` (remove-any / add-own, any-of authorization); `setMyTags` + create/update/sendDraft
  authorization; related-activity write-gate + cascade-delete on unlink (draft edit / procurement cascade only);
  qualification-system suppression.
- **Frontend slice (`executor-frontend`):** panel visibility (related-activity + role + qualification);
  auto-save on add/remove (drop the manual button); read-only rendering for viewers; unit tests.

## Open items for the planner — RESOLVED

All three previously-open items are resolved in `docs/plans/2026-06-23-ep-13189-message-tags-logic-plan.md`:

- **Server-side responsible-person/admin check** — `isCurrentUserResponsibleOrAdminForProcurement` reusing
  `isCurrentUserInAdditionalRole` + `isInRole`, applied any-of over the message's `MessageToProcurement` links,
  called from `reconcile`. *(Locked decision 9.)*
- **Unlink flow / cascade-delete** — hooked in `reconcile` via the "no related activity ⇒ delete tag rows" rule,
  scoped to draft edit and parent-procurement cascade only; no new endpoint for sent messages. *(Locked decision 8.)*
- **Client related-activity signal** — already on the loaded message (`Message.messageToProcurement` is
  serialized); no payload change. Qualification-system context likewise via `Message.messageToQualificationSystem`.
