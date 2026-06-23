# EP-13188 — Supplier view: hide message tags (Štítky): Implementation Plan

**Ticket:** Dev Sub-task **EP-13188** · Parent Story **EP-13103** ("štítky v komunikácii")
**Builds on:** EP-13103 / EP-13112 (the message tags feature). This sub-task only *gates* that
feature for suppliers — no new endpoints, no schema changes.

**Goal (from the ticket):** In the supplier view (pohľad dodávateľa):
1. the supplier **cannot add tags** to a message;
2. the **"Štítky" column is not shown** in their message overview (received **and** sent).

Plus: the restriction is **enforced on the backend**, not only hidden in the UI.

**Commit pair (from `docs/TICKETS.md`):** `feat(EP-13103, EP-13188): …`
- Server repo: `feat(EP-13103, EP-13188): block message tag endpoints for suppliers`
- Client repo: `feat(EP-13103, EP-13188): hide message tags for suppliers`

---

## How "supplier" is detected (verified)

- **Client:** `$root.isSupplier()` (`controllers/main.js:69`) — `currentUser.company.type === COMPANY_TYPE_SUPPLIER`.
  Already used throughout `communication.html` (e.g. the "New message" button is `data-ng-hide='$root.isSupplier()'`).
- **Server:** roles `user` and `supplier` are **disjoint** — suppliers have `supplier`, not `user`.
  Evidence: `MessageService` is class-level `@RolesAllowed(ROLE_NAME_USER)` and every supplier-reachable
  method explicitly re-adds `ROLE_NAME_SUPPLIER`; some methods are `ROLE_NAME_SUPPLIER`-only. So dropping
  `ROLE_NAME_SUPPLIER` from a `@RolesAllowed` cleanly blocks suppliers.

---

## Backend slice — `publicERANET-server` (declarative guard, per decision)

Guard via `@RolesAllowed` (no in-method `isSupplier()` checks).

1. **`service/MessageTagService.java:38`** — class annotation
   `@RolesAllowed({ROLE_NAME_USER, ROLE_NAME_SUPPLIER})` → `@RolesAllowed(ROLE_NAME_USER)`.
   Blocks `createTag` (PUT) and `search` (POST /search) for suppliers.
   *Leave* `reconcileCurrentUserTags` / `populateCurrentUserTags` as `@PermitAll` — they are called
   internally by `MessageService` in the supplier message-send/list flow and are inherently no-ops for
   suppliers (a supplier owns no tags; `collectOwnedDesiredTagIds` ignores foreign ids; `populate` returns
   empty). Putting `@RolesAllowed` on them would break supplier message send/list (EJBAccessException).

2. **`service/MessageService.java:409`** — `setMyTags` endpoint
   `@RolesAllowed({ROLE_NAME_USER, ROLE_NAME_SUPPLIER})` → `@RolesAllowed(ROLE_NAME_USER)`.
   This is the dedicated "persist my tags on an existing message" endpoint; it must not be reachable by
   suppliers. The `reconcile` calls inside `create`/`update`/`sendDraft` stay untouched (those methods
   must keep SUPPLIER so suppliers can still send messages; the reconcile is a no-op for them).

**Build:** `mvn -q -f publicERANET-server/pom.xml -DskipTests package` on JDK 8 → BUILD SUCCESS.

---

## Frontend slice — `publicERANET-client/app/views/communication/communication.html`

Gate on the existing `$root.isSupplier()`.

1. **Detail tag panel** (line 145): add `data-ng-hide="$root.isSupplier()"` to the
   `div.message-tags-panel`.
2. **Overview "Štítky" column** — hide all four cells of the column so columns stay aligned:
   - filter label `<td>` (line 202): `data-ng-show="showFilter"` → `data-ng-show="showFilter && !$root.isSupplier()"`
   - filter input `<td>` (line 210): `data-ng-show="showFilter"` → `data-ng-show="showFilter && !$root.isSupplier()"`
   - header `<th>` (line 217): add `data-ng-show="!$root.isSupplier()"`
   - data `<td class="inbox-data-tags">` (line 262): add `data-ng-show="!$root.isSupplier()"`

No controller change needed: the only tag write path (`saveMessageTags` → `Messages.setMyTags`,
`communication.js:232`) lives in the now-hidden panel, and the backend blocks it regardless.

**Build/lint:** `grunt test` (JSHint) clean; existing Karma specs stay green.

---

## Verification (before committing — confirm in the running app)

### Backend
- [ ] `mvn package` BUILD SUCCESS (JDK 8).
- [ ] As a supplier: `PUT sc/messageTag` and `POST sc/messageTag/search` → **403**.
- [ ] As a supplier: `POST sc/message/setMyTags` → **403**.
- [ ] As a non-supplier (user): all three still work (tags create/search/assign unaffected).
- [ ] Supplier can still send/save/list messages (create/update/sendDraft/query unaffected).

### Frontend (manual smoke)
- [ ] Logged in as a **supplier**: message detail shows **no** tag panel / "+" / tag select;
      message overview (prijaté **and** odoslané) shows **no** Štítky column (header, filter, cells);
      remaining columns stay aligned.
- [ ] Logged in as a **contracting authority (user)**: tags panel, chips, filter, and column all still
      present and working (no regression to EP-13103).
