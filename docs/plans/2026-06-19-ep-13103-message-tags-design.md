# EP-13103 — Tags ("Štítky") in communication: Design

**Ticket:** Story **EP-13103** · Dev **EP-13112** · Epic EP-12988
**Reporter:** Martin Oravec
**Goal:** Add a per-user **tag/label catalog** for messages — editable in the message detail,
shown read-only in the message overview, and usable as a free-text filter.

**Tech stack:** Java 8 / Java EE 7 / EclipseLink / RESTEasy / Liquibase / MySQL (server);
AngularJS 1.5 ES5 / `ui-select` / `ui.bootstrap` modal (client).

**Commit pair (from `docs/TICKETS.md`):** `feat(EP-13103, EP-13112): …`

---

## What the ticket asks for

- **Message detail** — a separate "Štítky" section: multiselect of the user's existing tags;
  typeahead that searches after **≥3 characters**; a **"+"** that opens a "Pridanie štítkov" popup
  (name + colour, both required); **"X"** to remove a tag from the message; a newly-created tag
  **auto-attaches** to the message.
- **Overview** — tags shown **right of the subject**, **read-only**; **free-text** filter by tag.
- **4 colours** via select: Zelená `#6AB5B4`, Oranžová `#F48942`, Bordová `#A90329`, Modrá `#5A87D2`.
- Each user sees **only their own** tags. Deactivation of tags is **out of scope**.

## Reuse note (the ticket's "BE nie" assumption)

The ticket hoped to reuse the suppliers' "Stav dodávateľa" component and avoid backend work. After
review that only holds **cosmetically**:

- ✅ The 4 colours are **identical** to the existing supplier-status chips
  (`custom.css` classes `suppliers-status-green/red/blue/orange`, same hex as the ticket) — reuse the styling.
- ❌ The supplier component is **4 separate per-colour fields, free-text, local-only, stored per-company**.
  EP-13103 needs **one** multiselect with mixed per-chip colours, a **server-side 3-char typeahead** over the
  user's saved tags, a **create-tag popup**, and tags **owned by the user and reused across messages** — none
  of which exists today. **A real backend (new entity + endpoints + Liquibase) is required.** *(Confirmed with
  the team.)*

---

## Locked decisions

1. **New per-user tag catalog backend** (not a frontend-only reuse of supplier states).
2. **Dedicated "Štítky" free-text filter** in the overview (the existing subject filter is left untouched).
3. **All folders** (Odoslané, Koncepty, Externá komunikácia) support tagging + display + filter.
4. Colours stored as the keys `green` / `orange` / `red` / `blue` (same convention as `CompanyTag`),
   mapped to the existing colour classes on the FE.
5. Ownership is **always** taken from the authenticated user server-side — never trusted from the client.

---

## 1. Data model (server)

Two new JPA entities in `sk.innovis.eranetpublic.server.dto`, following the `CompanyTag` style.

**`MessageTag`** — the per-user tag *catalog* (table `message_tag`):

| Column | Type | Notes |
|---|---|---|
| `id` | Integer PK | auto-generated |
| `name` | varchar | tag text (the "Popis") |
| `color` | varchar | `green` / `orange` / `red` / `blue` |
| `system_user_id` | Integer FK → `system_user` | **owner** |
| `creation_datetime` | **DATETIME** | `@Temporal(TIMESTAMP)` on the field |

**`MessageToTag`** — assignment join (table `message_to_tag`): `id`, `message_id` FK, `message_tag_id` FK.
`Message` gets a `@OneToMany List<MessageToTag>` (cascade + orphan-removal, like its other children).

**Why a catalog + join (not `CompanyTag`'s embedded rows):** tags must be *reused across messages* and
*searched from what the user has saved* — only possible if a tag is a first-class, user-owned row that many
messages reference.

**Privacy falls out of ownership:** a tag is owned by one user, so a message's tags are always loaded
**filtered to `messageTag.systemUserId = currentUser`**. A recipient never sees the sender's tags on the same
shared message — satisfying "každý vidí iba svoje štítky" without per-user copies of the assignment.

## 2. Endpoints, query/filter & Liquibase (server)

**`MessageTagService extends BaseService<MessageTag>`**, `@Path("sc/messageTag")`,
`@RolesAllowed(ROLE_NAME_USER)` — mirroring `MessageService` / `FileTagService`:

- **`PUT /sc/messageTag`** — create a tag. Name + colour required (validated server-side). Owner forced to
  the authenticated `systemUserId` (never from the payload). Returns the saved tag for the client to auto-attach.
- **`POST /sc/messageTag/search`** — search the user's tags by typed text: `name like %text% AND
  system_user_id = currentUser`, owner always injected server-side. The ≥3-char minimum is enforced on the
  client; the server scopes by owner regardless.

**Attaching tags to a message:** handled in the existing message-save flow (the client already POSTs the whole
`currentMessage`). Add a `messageTags` collection to the payload and, on save, **reconcile only the current
user's assignments** in `message_to_tag` — add new links, remove de-selected ones, leave other users' links on
that message untouched. Done via a `BaseService` method (no direct DAO calls).

**Filtering (overview):** extend `MessageDao.getWhere()` with a LEFT JOIN
`message → message_to_tag → message_tag` and predicate `messageTag.name like :text AND
messageTag.systemUserId = :currentUser`, driven by a new `tagName` filter field. The overview load also
**populates each message's current-user tags** (transient `messageTags` on the returned `Message`, scoped to
the current user) so the chips can render.

**Liquibase** (author `m.bijalko`): one changeset creating `message_tag` and `message_to_tag` (FKs + index on
`message_tag.system_user_id` and on `message_to_tag.message_id`). Schema via Liquibase only — no raw SQL.

## 3. Message-detail UX (client)

In `communication.html` (detail/compose) + `communication.js` (`CommunicationController`), a new **"Štítky"**
section — the `ui-select` chip pattern from `editCompany.html`, but as **one** multiselect with per-chip colours:

- **Multiselect** bound to `currentMessage.messageTags` (`{id, name, color}`):
  - `ui-select multiple`; `ui-select-match` renders each tag as a chip with `ng-class` → colour class; the
    built-in **"X"** removes it from the message.
  - `ui-select-choices` with `minimum-input-length="3"` + `refresh="searchTags($select.search)"`
    (small `refresh-delay`) calling `MessageTags.search`. Choices also render with their colour chip.
- **"+" button** in the section header opens a **"Pridanie štítkov"** modal (`$uibModal`, existing modal styling):
  - **Popis** (text) + **Farba** (select of the 4 colours, default *Zelený*). Both **required** — Uložiť
    disabled until both filled.
  - On Uložiť: `MessageTags.create` → **push the returned tag into `currentMessage.messageTags`** (auto-attach)
    → close. It persists on the next message save.
- **New resource** `app/scripts/service/resources/messageTags.js` (`webresources/sc/messageTag`) exposing
  `search` and `create`, in the `messages.js` factory style.

## 4. Overview, i18n & testing (client)

- **Read-only chips right of the subject:** in the message row, after `currentMessage.subject`, iterate
  `message.messageTags` (current-user tags from the server) rendering colour chips **without** an "X".
- **Dedicated "Štítky" filter:** a new free-text input in the existing filter row, wired through the
  established `filterHelper` / `textFilter` + `FILTER_OR_SEARCH_CHANGED` → `storeFilterAndDoReload()` path,
  adding a `tagName` `like` filter to the query POST (server scopes to the current user).
- **i18n:** English keys, Slovak values — e.g. `communication.tags.title` = "Štítky",
  `communication.tags.addTitle` = "Pridanie štítkov", `communication.tags.name` = "Popis",
  `communication.tags.color` = "Farba", plus the 4 colour labels. No Slovak in code or keys.
- **Tests (Karma/Jasmine + manual):**
  - Unit: search triggers only at ≥3 chars; create-tag → auto-attaches; removing a chip drops it from the
    model; create-form invalid until both fields set.
  - Manual smoke: create tag → appears on message → save → reload keeps it; a second user does not see the
    first user's tags; filter by tag name narrows the list; chips show correct colours in all three folders.

---

## Work split (for the executor agents)

- **Backend slice (`executor-backend`):** `MessageTag` + `MessageToTag` entities, `MessageTagService`
  (create + search), save-reconcile of assignments, `MessageDao` join/filter + per-user tag population,
  Liquibase changeset (`m.bijalko`).
- **Frontend slice (`executor-frontend`):** `messageTags.js` resource, "Štítky" detail section + create modal,
  overview chips + filter, i18n keys, unit tests.

## Acceptance criteria → coverage

| Acceptance criterion | Covered by |
|---|---|
| "Štítky" section editable on create + edit | §3 multiselect |
| One or more tags (multiselect) | §3 `ui-select multiple` |
| ≥3 chars → suggest the user's saved tags | §2 search + §3 `minimum-input-length` |
| "+" → name + colour, both required | §3 create modal |
| 4 defined colours | Locked #4, §3 |
| New tag auto-added to the message | §3 auto-attach |
| "X" removes a tag from the message | §3 chip remove |
| User sees/searches only their own tags | §1 ownership, §2 owner-scoped search |
| Overview shows tags right of subject | §4 chips |
| Overview tags read-only | §4 (no "X") |
| Free-text filter by tag | §2 filter, §4 filter input |
| Tags persist across reloads | §1 catalog + §2 reconcile |

---

## Open items / follow-ups

- **Colour CSS:** reuse the existing `suppliers-status-*` hex by adding parallel `message-tag-*` classes (same
  hex) so the markup reads semantically, rather than referencing supplier classes from the communication view.
- **External communication:** confirmed in scope; verify during smoke testing that its detail/overview share
  the same controller/templates (assumed from the module map).
