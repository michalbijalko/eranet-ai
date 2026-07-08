# EP-13235 — eZmluvy Export Súborov: Company Filter (design)

**Story:** EP-13235 — *VSDS – export údajov – eZmluvy – filtrovanie podľa Spoločnosti*
**Epic:** EP-13232 — *VSDS – export údajov – eZmluvy*
**Date:** 2026-07-07
**Status:** Design agreed (brainstorming complete) — ready for planning.

## REVISION 2026-07-08 — B7 finding: owner identity is NAME, not id (supersedes id-based bits below)

Smoke-testing the AK6 gate on the test DB returned
`[{"count":37},{"companyId":42455,"count":3},{"companyId":42588,"count":2}]` — 37 of 42 contracts
have an Owner row with `company_id = NULL` (owner stored by `company_name`/`ico`, not a linked
`Company`; note `company_id` scalar and the `company` relation are the **same column**). An id-keyed
filter (the hardcoded `contractCompanies`) can't reach those 37, so all-selected ≠ full export → AK6
fails. **Decision (user): drive the list server-side by owner NAME.**

Supersedes decisions #2's per-company-count *display* nuance is unchanged, but #3 (hardcoded list) and
the id-based backend/frontend below are replaced by:
- **Owner identity = `COALESCE(ContractToCompany.company_name, company.name)`** ("owner name"), used
  identically for grouping (counts) and filtering (export). Covers id-linked and name-only owners.
- **Company list is server-driven** from `ownerCompanyCounts` (owners that actually have contracts),
  NOT the hardcoded `contractCompanies`. The duplicate-id 42455 concern is moot.
- **Backend:** replace `FILTER_OWNER_COMPANY_IDS` (remove the now-dead id IN handler) with
  `FILTER_OWNER_COMPANY_NAMES` (IN over the coalesced owner name, Owner-domain join). Count query
  groups by the coalesced owner name → `{ ownerName, count }`. `exportFiles` takes repeated
  `companyNames` (not `companyIds`); same present/absent/empty guard, same distinct + filtered-filename total.
- **Frontend:** `getOwnerCompanyCounts()` → `[{ ownerName, count }]`; build the multiselect from that
  (all selected by default); sum counts; each batch link appends URL-encoded `&companyNames=<name>`.
  Drop the `$rootScope.contractCompanies` dependency in this popup.
- **Frozen contract v2:**
  - `GET webresources/sc/contract/ownerCompanyCounts` → `[{ "ownerName": <string>, "count": <long> }, …]`
  - `GET …/exportFiles?page=&pageSize=&companyNames=<name>&companyNames=<name>…` — repeated,
    URL-encoded; absent ⇒ all, non-empty ⇒ owner-name IN, present-but-empty ⇒ empty zip.
- **Re-verify AK6:** `Σ ownerCompanyCounts.count == totalCount`.

Everything below is the original id-based design, kept for history.

## Goal

Add an owner-company **multiselect filter** to the existing "Export súborov" popup in eZmluvy,
so an admin can export contract attachments for a chosen subset of group companies, with the
total contract count (and therefore the batch links) recalculated live as the selection changes.

Today the popup exports **all** contract attachments in fixed-size batches with no company
scoping. This adds scoping without changing the default (all-selected) behavior.

## Acceptance criteria (from the ticket)

- **AK1** — Company multiselect shown in the popup; all companies selected by default.
- **AK2** — Companies can be checked/unchecked individually.
- **AK3** — **+ / −** controls beside the filter select-all / deselect-all at once.
- **AK4** — On any selection change, the displayed contract count recalculates; batch sizing follows it.
- **AK5** — Export produces attachments only for selected companies.
- **AK6** — All selected (default) ⇒ result identical to today's full export.

## Decisions made during brainstorming

1. **Which company** — the contract's **Owner** company (`ContractToCompany.domain = Owner`),
   which is mandatory and 1:1 per contract. Not partner/supplier.
2. **Recount (AK4)** — **preload per-company counts**, sum selected client-side (zero latency,
   exact because owner is 1:1). No per-toggle server round-trip.
3. **Company list source** — the **hardcoded `$rootScope.contractCompanies`** list already in the
   client ([contracts.js](../../publicERANET-client/app/modules/jackrabbit/service/contracts.js)),
   **including the `visible:false` entries**, so all-selected spans every group company and AK6 holds.
   The client already has the names; the backend only supplies counts.
4. **UI control** — `ui-select multiple` (matching existing usage, e.g. observers in `editContract.html`),
   with **+ / −** buttons beside it for bulk select/deselect.
5. **Access** — unchanged: `@RolesAllowed(SYSTEM_ADMINISTRATOR)` on both endpoints.

## Backend (`publicERANET-server`)

File: `modules/jackrabbit/service/ContractService.java`, `modules/jackrabbit/dao/ContractDao.java`.

### A. New endpoint — owner-company counts
- `GET webresources/sc/contract/ownerCompanyCounts`, `@RolesAllowed(SYSTEM_ADMINISTRATOR)`.
- Returns a list of `{ companyId, count }` (contract counts grouped by owner company).
- New `ContractDao` method: criteria query over `Contract` joined to `contractToCompanyList`
  filtered to `domain = Owner`, grouped by owner company id, counting **distinct** contracts.

### B. Filter the export
- Extend `exportFiles(page, pageSize)` → `exportFiles(page, pageSize, companyIds)`
  (`@QueryParam("companyIds")`, multi-value).
- When `companyIds` is present, apply an **owner-company `IN`** filter via `FindParameters`
  before the existing id-ordered pagination.
- Add a multi-value owner-company-id filter to `ContractDao` (existing `FILTER_OWNER_COMPANY_ID`
  is single-value; add an `IN` variant).
- **Guard:** if `companyIds` is present but empty → return empty (never fall back to "all").

Pagination/ordering unchanged (by `Contract.id asc`), applied after the filter, so batches stay
consistent with the filtered count.

## Frontend (`publicERANET-client`)

Files: `modules/jackrabbit/controller/exportAllFilesController.js`,
`modules/jackrabbit/view/exportAllFilesDialog.html`,
`modules/jackrabbit/service/contracts.js`.

- On open, call new `Contracts.getOwnerCompanyCounts()` → cache `{ companyId: count }`. Build
  `companies` from `$rootScope.contractCompanies` (all entries, incl. hidden); `help.selectedCompanies`
  starts as **all** companies (AK1).
- `selectedCount` = Σ count of selected companies → drives the displayed total and `updateParts()`
  (AK4). Counts are used only for the total — **not shown per-company** (matches the reference widget).
- `addAllCompanies()` / `removeAllCompanies()` for the **+ / −** buttons (AK3); chip removal /
  re-add via `ui-select` handles individual toggles (AK2). All recompute `selectedCount`.
- `updateParts()`: each batch link gets `&companyIds=<selected ids>` appended (AK5). If
  `selectedCount === 0`, render no batch links (nothing selected ⇒ nothing exports).

**UI pattern — copy the PSK `editAdminUser.html` org-directory row** (proven pattern):
```html
<section class='col col-7'>
  <ui-select multiple name='companies' data-ng-model='help.selectedCompanies'>
    <ui-select-match>{{$item.name}}</ui-select-match>
    <ui-select-choices repeat='company in companies | filter: {name: $select.search} | orderBy:"name"'>
      <div ng-bind-html="company.name | highlight: $select.search"></div>
    </ui-select-choices>
  </ui-select>
</section>
<section class="col col-1" style='padding: 0;'>
  <a class="btn btn-circle" data-ng-click="addAllCompanies()" data-tooltip="{{'ADD_ALL'|translate}}">
    <i class="fa fa-plus-square"></i></a>
  <a class="btn btn-circle" data-ng-click="removeAllCompanies()" data-tooltip="{{'REMOVE_ALL'|translate}}"
     data-ng-if="help.selectedCompanies.length > 0">
    <i class="fa fa-minus-square"></i></a>
</section>
```
Placed above the existing "Počet zmlúv v jednej dávke" input. `btn-circle` + `fa fa-plus-square` /
`fa fa-minus-square`; minus renders only when a selection exists.

## i18n

English keys, Slovak values. Reuse **`ADD_ALL`** / **`REMOVE_ALL`** (already used by the PSK widget)
for the +/− tooltips — verify they exist in the vse langs file; add them if missing. Add a label
key for the company filter (Slovak value "Spoločnosť").

## Known quirks / risks

- `contractCompanies` has a **duplicate id `42455`** ("iSK plyn" hidden + "BioplynR" visible).
  Counting by id will attribute the same count to both rows. Confirm intended display during
  implementation; likely a data quirk to leave as-is.
- **AK6 verification:** all-selected count must equal the current `totalCount` (≈16 407). If it
  doesn't, some contracts are owned by a company **not** in `contractCompanies` — revisit the
  list source (fall back to a DB-driven owner-company list). This is the key smoke-test gate.

## Testing

- **Karma/Jasmine** (controller): default all-selected; sum recomputes on toggle and +/−;
  `updateParts()` appends `companyIds` and yields the right batch count; empty selection ⇒ 0 parts.
- **Manual smoke:** open ⇒ all selected, count == current total (AK6); deselect some ⇒ count drops,
  batches rebuild; download a batch ⇒ only selected companies' attachments (AK5); deselect all ⇒
  nothing to download.
- No server unit-test harness; backend verified via smoke-testing the two endpoints.
