# EP-13134 — Implementation Plan: "Schvaľovateľ" column in evaluation overview + filter + export

**Story:** EP-13134 · **Dev sub-task:** EP-13155 · **Epic:** EP-13132
**Commit message (exact):** `feat(EP-13134, EP-13155): add "Schvaľovateľ" column to evaluation overview with filter and Excel export`
**Authoritative design:** `docs/plans/2026-07-09-EP-13134-schvalovatel-column-design.md`

> Scope: display + filter + export of the already-existing `SrRatingHeader.approver`. **No DB / Liquibase / entity-column change.** All line numbers verified during exploration 2026-07-09 — **re-confirm by grepping the literal/symbol before editing** (files drift).

---

## Ordering & lockstep

- **Backend first** (the `FILTER_NAME_APPROVER = "approver"` key must exist server-side before the client `<text-filter name="approver">` resolves to a predicate), then **frontend**.
- **Filter-key lockstep:** client `<text-filter name="approver">` == `SrRatingHeader.FILTER_NAME_APPROVER` value `"approver"` == the key read in `SrRatingHeaderDao.getWhere`. All three must be byte-identical or the filter silently no-ops.
- **Column-order lockstep (client):** the three parallel lists in `supplierRatingTable.html` (header `<th>`, filter `<th>`, data `<td>`) plus the empty-row `colspan` must stay index-aligned.

---

## BACKEND slice (`publicERANET-server`) — executor-backend

### B1. Filter-name constant
`eranet-domain/src/main/java/sk/innovis/eranetpublic/server/dto/SrRatingHeader.java`:
- Add `public static final String FILTER_NAME_APPROVER = "approver";` next to `FILTER_NAME_EVALUATOR` (~L38). Do **not** reuse `FILTER_NAME_FOR_APPROVER = "forApprover"` (~L42) — that is the unrelated "awaiting my approval" flag.

### B2. DAO filter predicate
`eranet-dao/src/main/java/sk/innovis/eranetpublic/server/dao/SrRatingHeaderDao.java`, method `getWhere`:
- Near the other `tryGetFilterByNameAndMarkAsNotEntityFilter` calls (~L52) add:
  `final QueryFilter approver = findParameters.tryGetFilterByNameAndMarkAsNotEntityFilter(SrRatingHeader.FILTER_NAME_APPROVER);`
- After the evaluator block (~L167) add the predicate block (single-relation, LEFT join):
  ```java
  if (approver != null) {
      final Join<SrRatingHeader, SystemUser> approverJoin = from.join(SrRatingHeader_.approver, JoinType.LEFT);
      final Predicate byFirstName = criteriaBuilder.like(approverJoin.get(SystemUser_.firstName).as(String.class), approver.getFilterValues().get(0) + '%');
      final Predicate byLastName  = criteriaBuilder.like(approverJoin.get(SystemUser_.lastName).as(String.class),  approver.getFilterValues().get(0) + '%');
      result.add(criteriaBuilder.or(byFirstName, byLastName));
  }
  ```
- `JoinType` and `SystemUser_` are already imported/used by the evaluator block — confirm the imports are present (they are, for `delegatePerson` LEFT join at L154).

### B3. Excel export — insert right of Hodnotiteľ (index 11), reindex trailing columns
`public-eranet/src/main/java/sk/innovis/eranetpublic/server/service/SrRatingHeaderService.java` (user decision: mirror the on-screen order):
- `exportToExcel` — in `columnNames` (L154-156) insert `"Schvaľovateľ"` **between** `"Hodnotiteľ"` and `"Stav"` → Schvaľovateľ=11, Stav=12, Hodnotenie=13. (`formatHeader(..., columnNames.size())` at L164 auto-adjusts.)
- `createNewRowExcel` (L307-347) — **reindex the two trailing cell writes, then add the approver cell:**
  - Stav (status): change `cells.get(index, 11)` → `cells.get(index, 12)` (L334-336).
  - Hodnotenie (score): change `cells.get(index, 12)` → `cells.get(index, 13)` in **both** branches (score-level L342 and "Nehodnotený" L344).
  - New approver cell at index 11:
    ```java
    if (item.getApprover() != null) {
        cells.get(index, 11).setValue(item.getApprover().getFirstAndLastName());
    }
    ```
  - Leave evaluator (index 10) and all earlier cells untouched.
  - **After editing, grep every `cells.get(index, N)` in this method** and confirm indices 0-13 each appear once as intended — a missed shift silently overwrites a column.

### B4. Backend verification
- Compile: `mvn -q -pl public-eranet,eranet-domain,eranet-dao -am compile` (or full build per deployment skill).
- Filter smoke: POST `sc/srRatingHeader/query` with `filters` containing `approver` = a known approver's surname → only matching rows return; omit it → all rows return (no regression).
- Export smoke: POST `sc/srRatingHeader/exportToExcel` → XLSX has "Schvaľovateľ" **between Hodnotiteľ and Stav**, populated for sent/approved rows, blank for un-sent/re-opened; confirm **Stav and Hodnotenie still render correctly** (the reindex didn't shift their values).

---

## FRONTEND slice (`publicERANET-client`) — executor-frontend

### F1. i18n (`app/scripts.no.min/langs/{sk,en,hr}.js`)
- Add `"SUPPLIER_RATING_APPROVER"` next to `SUPPLIER_RATING_EVALUATOR`:
  - `sk.js` (~L4603): `"SUPPLIER_RATING_APPROVER": "Schvaľovateľ",`
  - `en.js` (~L4366): `"SUPPLIER_RATING_APPROVER": "Approver",`  *(EN provisional — confirm)*
  - `hr.js`: add the same key for completeness.
- Verify exactly one hit per key per lang file.

### F2. Table template (`app/views/directives/supplierRatingTable.html`)
Insert three aligned pieces (all "right of Hodnotiteľ"):
- **Header** — after L24 (`SUPPLIER_RATING_EVALUATOR`), before L25 (`PUBLIC_LIST_STATE`):
  `<th>{{'SUPPLIER_RATING_APPROVER'|translate}}</th>`
- **Filter** — after the evaluator filter `<th>` (L60-62), before the status filter (L63):
  ```html
  <th>
      <text-filter name="approver"></text-filter>
  </th>
  ```
- **Data cell** — after L94 (evaluator cell), before L95 (status cell):
  `<td>{{rating.approver ? rating.approver.firstAndLastName : ''}}</td>`
- **Colspan** — change `<td colspan='13'>` (L74) to `colspan='14'`.

### F3. No controller / service change
- `<text-filter name="approver">` self-registers into `$scope.help.filters['approver']` (like filter) via `FilterHelper`; `SupplierRatingTableController` already collects `help.filters` and calls `SrRatingHeaders.loadSrRatingHeaders(...)` on filter change. Nothing to wire.
- Row model already includes `approver` (served by the query endpoint). No `$resource` change.

### F4. Frontend verification
- Karma/Jasmine suite green (`grunt test`) — no new failures; no existing unit test covers this list column, do not invent one unless a nearby pattern applies.
- Manual smoke (below).

---

## Smoke test per acceptance criterion

- **AC#1:** open Prehľad hodnotení → a "Schvaľovateľ" column appears immediately right of "Hodnotiteľ", left of "Stav".
- **AC#2:** a rating not yet sent → cell empty; send for approval → approver's *Meno Priezvisko* shows; approve → name stays; re-open the rating → cell empty again.
- **AC#3:** type an approver surname into the new column filter → only matching rows remain; clear it → all rows return (rows without an approver reappear).
- **AC#4:** export to Excel → the sheet has a "Schvaľovateľ" column **right of Hodnotiteľ (left of Stav)**, populated for sent/approved rows and blank for un-sent/re-opened; Stav and Hodnotenie columns still show correct values.

## Lockstep integrity checklist (before claiming done)

1. Filter key `"approver"` byte-identical across: `supplierRatingTable.html` `<text-filter name>`, `SrRatingHeader.FILTER_NAME_APPROVER`, DAO usage. A typo = filter silently returns unfiltered results.
2. Column alignment: header `<th>`, filter `<th>`, and data `<td>` for the approver are each in the same ordinal position (right of Hodnotiteľ), and `colspan` bumped to 14.
3. Export: Schvaľovateľ header sits between Hodnotiteľ and Stav (index 11); every `cells.get(index, N)` in `createNewRowExcel` covers 0-13 once — Stav shifted to 12, Hodnotenie to 13, nothing overwritten.

## Open questions / risks

1. **Export column position** — RESOLVED (user, 2026-07-09): insert right of Hodnotiteľ (index 11), reindex Stav→12 / Hodnotenie→13. Grep all cell indices post-edit.
2. **EN/HR wording** — `"Approver"` provisional; confirm. Non-blocking.
3. **`@ManyToOne(optional=false)` on `approver`** despite nullable usage — pre-existing; display/filter/export are all null-safe. Do not touch the mapping.
4. **Re-verify line numbers** — `supplierRatingTable.html` (L24/L60-62/L74/L94), `SrRatingHeaderDao.getWhere` (L52/L152-167), `SrRatingHeaderService` (L154-156/L307-347), lang keys — grep the literal/symbol before editing; files drift.
