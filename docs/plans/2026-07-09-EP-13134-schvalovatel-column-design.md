# EP-13134 — Design: "Schvaľovateľ" (Approver) column in the evaluation overview + filter + export

**Story:** EP-13134 · **Dev sub-task:** EP-13155 · **Test sub-task:** EP-13156 · **Epic:** EP-13132
**Commit message (exact, docs):** `docs(EP-13134): design + plan for "Schvaľovateľ" column in evaluation overview`

> Intent brainstormed and approved with the user. Jira ticket read directly (Atlassian MCP authenticated this session). ACs below are transcribed from the live ticket. Codebase patterns confirmed by two exploration passes (server + client). No image on this ticket.

---

## 1. What the ticket asks for

Add a new **"Schvaľovateľ"** (Approver) column to the supplier-evaluation overview list (**Prehľad hodnotení**), a **text filter** over it, and the same attribute in the **Excel export**.

**Acceptance criteria (from EP-13134):**
1. New **Schvaľovateľ** column in the evaluation overview, positioned **immediately to the right of the "Hodnotiteľ" (Evaluator) column**.
2. Cell-value logic by evaluation state:
   - Not yet sent for approval → **empty**.
   - Sent for approval → **approver's name** (format *Meno Priezvisko*).
   - Approved → approver's name **stays** visible.
   - Re-opened (back to the evaluator) → **empty** again.
3. A **text filter** above the new column. Records without an approver display normally; when the filter is applied, only matching records show.
4. The **Schvaľovateľ** attribute added to the **Excel export**.

## 2. Key finding — the approver already exists end-to-end

The evaluation entity is **`SrRatingHeader`**. It already carries the approver:

```java
// eranet-domain/.../dto/SrRatingHeader.java  (~L160-165)
@Column(name = "approver_id")
private Integer approverId;
@JoinColumn(name = "approver_id", referencedColumnName = "id", insertable = false, updatable = false)
@ManyToOne(optional = false)
private SystemUser approver;
```

The overview endpoint `POST webresources/sc/srRatingHeader/query` returns `FindResult<SrRatingHeader>` — the **entity is serialized directly to JSON**, and `approver` is a non-`@JsonIgnore` field with a public getter. So **`rating.approver` is already in the list-row payload**; no DTO/backend change is needed merely to display it.

**AC#2's cell logic falls out of the approver field's existing lifecycle for free** — no extra client state logic:

| Ticket state | Entity status | Approver field | Cell |
|---|---|---|---|
| Not yet sent | `Initial` / `InProgress` | `null` (client sets it on send) | empty ✓ |
| Sent for approval | `Sent` | set | name ✓ |
| Approved | `Closed` | stays set | name ✓ |
| Re-opened → back to evaluator | `InProgress` | `reopenRating` clears it (`setApprover(null); setApproverId(null)`) | empty ✓ |

Reference: `SrRatingHeaderService.reopenRating` clears the approver on re-open; the `Status` enum is `Initial(0)/InProgress(1)/Sent(2)/Closed(3)`.

## 3. Decisions taken during brainstorm

| # | Decision | Rationale |
|---|---|---|
| Scope | Overview list (the `supplierRatingTable` directive) + its Excel export **only**. No entity/DTO change. | Approver already exists on the entity and is already serialized. Ticket names only the overview + export. |
| Display value | `{{rating.approver ? rating.approver.firstAndLastName : ''}}` | The approver field's lifecycle already matches AC#2 exactly — empty/name/name/empty across states. No state-conditional code needed. |
| Filter | **Server-side** name `like` filter, mirroring the existing evaluator filter (user-confirmed). New `FILTER_NAME_APPROVER = "approver"` + a predicate in `SrRatingHeaderDao.getWhere`. | Every other column filter in this list is server-side; client-side-only would be inconsistent. Approver is a single relation, so the predicate is simpler than the evaluator's delegate-aware one. |
| Export column position | **Insert "Schvaľovateľ" right of Hodnotiteľ** (index 11), shifting Stav (11→12) and Hodnotenie (12→13) — to match the on-screen column order (user-confirmed). | Keeps the export consistent with the overview ("right of Hodnotiteľ"). Requires reindexing the two trailing cell writes; low but non-zero risk. |
| "Hodnotiteľ" source mismatch | Leave as-is. On screen the evaluator is `delegateId ? delegatePerson : creationAuthor`; in the export it is `Agreement.getEvaluator()`. The approver is `SrRatingHeader.approver` in **both**. | Pre-existing inconsistency in how "evaluator" is sourced; not in scope. Approver is unambiguous. |

## 4. Frontend slice (`publicERANET-client`)

All in the `supplierRatingTable` directive; columns are **three hand-maintained parallel `<th>/<td>` lists** (header row, filter row, data row) that must stay index-aligned. No ngTable / no columns-config abstraction.

- **`app/views/directives/supplierRatingTable.html`:**
  - **Header:** insert `<th>{{'SUPPLIER_RATING_APPROVER'|translate}}</th>` immediately **after** the evaluator header (L24), before the `PUBLIC_LIST_STATE` header (L25).
  - **Filter row:** insert `<th><text-filter name="approver"></text-filter></th>` immediately **after** the evaluator filter (L60-62), before the `status` codebook-filter (L63-65).
  - **Data row:** insert `<td>{{rating.approver ? rating.approver.firstAndLastName : ''}}</td>` immediately **after** the evaluator cell (L94), before the status cell (L95).
  - **Empty-row colspan:** increment the hard-coded `colspan='13'` (L74) to `14`.
- **i18n** (`app/scripts.no.min/langs/{sk,en,hr}.js`; there is **no** `scripts/langs` source):
  - Add `"SUPPLIER_RATING_APPROVER"` next to `SUPPLIER_RATING_EVALUATOR` (sk ~L4603 → `"Schvaľovateľ"`, en ~L4366 → `"Approver"`, plus `hr.js` for completeness).
- **No controller change.** `<text-filter>` self-registers into `help.filters['approver']` via `FilterHelper.getEmptyLikeFilter()`; the directive already collects `help.filters` and posts them on change. The data cell is a pure template expression.

## 5. Backend slice (`publicERANET-server`)

Two edits only — the filter predicate and the export column.

- **Filter constant** — `eranet-domain/.../dto/SrRatingHeader.java`: add `public static final String FILTER_NAME_APPROVER = "approver";` alongside `FILTER_NAME_EVALUATOR` (L38) / `FILTER_NAME_FOR_APPROVER` (L42). *(Note: `FILTER_NAME_FOR_APPROVER = "forApprover"` already exists but is a different filter — "rows awaiting the current user's approval" — do not reuse it.)*
- **DAO predicate** — `eranet-dao/.../dao/SrRatingHeaderDao.java`, in `getWhere` (mirror the evaluator block at L152-167, but simpler — single relation):
  - Fetch the filter: `final QueryFilter approver = findParameters.tryGetFilterByNameAndMarkAsNotEntityFilter(SrRatingHeader.FILTER_NAME_APPROVER);` (near L52).
  - Add a block (after the evaluator block ~L167):
    ```java
    if (approver != null) {
        final Join<SrRatingHeader, SystemUser> approverJoin = from.join(SrRatingHeader_.approver, JoinType.LEFT);
        final Predicate byFirstName = criteriaBuilder.like(approverJoin.get(SystemUser_.firstName).as(String.class), approver.getFilterValues().get(0) + '%');
        final Predicate byLastName  = criteriaBuilder.like(approverJoin.get(SystemUser_.lastName).as(String.class),  approver.getFilterValues().get(0) + '%');
        result.add(criteriaBuilder.or(byFirstName, byLastName));
    }
    ```
    Use `JoinType.LEFT` so records without an approver are simply excluded by the `like` (not dropped by an inner join) — consistent with AC#3 ("records without an approver display normally" when no filter is set).
- **Excel export** — `public-eranet/.../service/SrRatingHeaderService.java` (insert right of Hodnotiteľ to mirror the screen, per user decision):
  - In the `columnNames` list (L154-156) insert `"Schvaľovateľ"` **between** `"Hodnotiteľ"` and `"Stav"` → Schvaľovateľ becomes index 11, Stav shifts to 12, Hodnotenie to 13. `formatHeader(workbook, columnNames.size())` (L164) picks up the new count automatically.
  - In `createNewRowExcel` (L307-347), **reindex the trailing cell writes** and add the approver cell:
    - Stav (status) write `cells.get(index, 11)` → `cells.get(index, 12)` (currently L334-336).
    - Hodnotenie (score) writes `cells.get(index, 12)` → `cells.get(index, 13)` (currently L338-346, both the score-level and the "Nehodnotený" branch).
    - New approver cell at index 11:
      ```java
      if (item.getApprover() != null) {
          cells.get(index, 11).setValue(item.getApprover().getFirstAndLastName());
      }
      ```
  - Evaluator (index 10) and all earlier cells are unchanged.
- **No Liquibase, no entity column, no DTO, no service-layer transition change.** The column already exists in the DB and on the entity.

## 6. Data flow summary

- **Display:** `srRatingHeader/query` already returns `approver` on each row → template renders `approver.firstAndLastName`.
- **Filter:** client `<text-filter name="approver">` → `help.filters.approver` (like) → POST body → `SrRatingHeaderDao.getWhere` `FILTER_NAME_APPROVER` predicate → name `like` on the joined `approver` `SystemUser`.
- **Export:** `exportToExcel` reuses `findAll` (same rows, same `approver`) → new cell writes `approver.firstAndLastName`.

## 7. Open questions / risks

1. **Export column position** — RESOLVED (user, 2026-07-09): **insert right of Hodnotiteľ** (index 11), reindexing Stav (11→12) and Hodnotenie (12→13). Verify all trailing cell-write indices are shifted so no export column is silently overwritten.
2. **`@ManyToOne(optional = false)` vs. null approver** — the mapping declares `approver` non-optional, yet `reopenRating` sets it to `null` and un-sent evaluations never had one. This is a **pre-existing** inconsistency; display/filter/export all tolerate `null` (guarded by `? :` / `!= null` / `LEFT` join). Do **not** "fix" the mapping — out of ticket scope; note only.
3. **Index-aligned parallel lists** — the three `<th>/<td>` lists in `supplierRatingTable.html` plus the empty-row `colspan` must all stay aligned; a missed insertion point shifts a whole column visually. Verify by eye after editing.
4. **Downstream EP-13135 (delegation)** builds directly on this column + filter (its AC#12 updates the "Schvaľovateľ" column to the new approver and filters on the current approver). Nothing to do here, but this is why EP-13134 is sequenced first.
5. **EN/HR header wording** — `"Approver"` (en) provisional; confirm. Non-blocking.
