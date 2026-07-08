# EP-13235 — eZmluvy Export Súborov: Company Filter (implementation plan)

**Story:** EP-13235 — *VSDS – export údajov – eZmluvy – filtrovanie podľa Spoločnosti*
**Dev sub-task:** EP-13236
**Epic:** EP-13232
**Commit prefix (all commits for this work):** `feat(EP-13235, EP-13236): <description>`
**Design source (authoritative):** [`2026-07-07-ezmluvy-export-company-filter-design.md`](2026-07-07-ezmluvy-export-company-filter-design.md)
**Status:** Ready for execution. Brainstorming complete; design agreed.

> One ticket, one plan. Everything here traces to EP-13235/EP-13236. Do not mix other tickets.
> Confirm the change works in the running app before committing.

---

## Codebase drift found vs. the design (read before executing)

The design's file paths are directional; the real symbols/paths differ. Executors MUST use the paths below, not the design's.

| Design said | Actual in this repo |
|---|---|
| Java package `sk.eranet.eranet…` (implied) | **`sk.innovis.eranetpublic.server`** — all server classes. |
| `ContractService.java` path | `publicERANET-server/src/main/java/sk/innovis/eranetpublic/server/modules/jackrabbit/service/ContractService.java` |
| `ContractDao.java` path | `.../modules/jackrabbit/dao/ContractDao.java` |
| `Contract` filter constants | Confirmed present in `.../modules/jackrabbit/dto/Contract.java`: `FILTER_OWNER_COMPANY_ID` (single), `FILTER_OWNER_COMPANY_NAME`, `COLUMN_NAME_CONTRACT_ID`, `PROPERTY_NAME_ID`. |
| i18n: "reuse `ADD_ALL`/`REMOVE_ALL`, add if missing" | **They do NOT exist in the VSE client.** They must be ADDED to both langs files. |
| langs file (single) | Two files: `app/scripts.no.min/langs/sk.js` and `app/scripts.no.min/langs/en.js`. |
| Register endpoint in `ApplicationConfig.java` | **No change needed.** `ContractService` is already registered (`ApplicationConfig.java:171`). The new endpoint is just a new `@GET` method on the already-registered resource class. |
| Total count source (AK6 baseline) | `totalCount()` uses `getOnlyTotalCount(new FindParameters())` (empty filter, distinct). `ContractService.java:569`. |

**Generic IN cannot be reused for owner company.** BaseDao's generic IN handler (`BaseDao.java:299`) does `from.get(fieldName).in(...)` on a **direct entity field of `Contract`**. Owner company id lives on the joined `ContractToCompany` (with `domain = Owner`), so it needs a **custom handler in `ContractDao.getWhere`**, mirroring the existing single-value `FILTER_OWNER_COMPANY_ID` block (`ContractDao.java:101–109`) but with `.in(...)`. Confirmed correct per the design's "add an IN variant".

**No changeset / no Liquibase / no raw SQL INSERT.** This feature adds no schema and no data. No `m.bijalko` changeset is required. If an executor thinks one is needed, stop and flag it.

---

## Contract between backend and frontend (freeze this first)

- **New endpoint:** `GET webresources/sc/contract/ownerCompanyCounts`
  - Returns JSON array: `[ { "companyId": <int>, "count": <int> }, … ]` — distinct contract count grouped by owner company id.
  - `@RolesAllowed(SystemUserGroup.ROLE_NAME_SYSTEM_ADMINISTRATOR)`.
- **Extended endpoint:** `GET webresources/sc/contract/exportFiles?page=<n>&pageSize=<n>&companyIds=<id>&companyIds=<id>…`
  - `companyIds` is a repeated multi-value query param.
  - Absent ⇒ current behavior (all contracts). Present-and-non-empty ⇒ owner-company IN filter. Present-but-empty ⇒ empty result (guard).
- JSON field names (`companyId`, `count`) and the `companyIds` param name are load-bearing — keep both slices in sync.

---

# BACKEND SLICE (`publicERANET-server`) — executor-backend

All files under `src/main/java/sk/innovis/eranetpublic/server/`.

### B1 — Add multi-value owner-company IN filter constant to `Contract`
- **File:** `modules/jackrabbit/dto/Contract.java`
- **Change:** Add a new filter-name constant next to the existing owner filters, e.g.
  `public final static String FILTER_OWNER_COMPANY_IDS = "ownerCompanyIds";`
  (distinct name from the single-value `FILTER_OWNER_COMPANY_ID` so both can coexist).
- **Satisfies:** AK5 (plumbing). **Verify:** compiles; constant referenced in B2 and B4.

### B2 — Add owner-company IN handler in `ContractDao.getWhere`
- **File:** `modules/jackrabbit/dao/ContractDao.java`
- **Change:** In `getWhere(...)`, add a block modeled on the existing single-value `FILTER_OWNER_COMPANY_ID` block (lines 101–109):
  - `final QueryFilter ownerCompanyIdsFilter = findParameters.tryGetFilterByNameAndMarkAsNotEntityFilter(Contract.FILTER_OWNER_COMPANY_IDS);`
  - When non-null and has values: `LEFT` join `Contract_.contractToCompanyList`; `AND`( `domain = Owner`, `join.get(ContractToCompany_.companyId).in(<values as Integers>)` ).
  - Convert `getFilterValues()` (List<String>) to Integers for the `.in(...)`.
- **Pattern to copy:** the `ownerCompanyIdFilter` block already in this file (join + `PROPERTY_NAME_DOMAIN = DomainType.Owner`), changing `.equal(...)` to `.in(...)`.
- **Satisfies:** AK5. **Verify:** with a `FILTER_OWNER_COMPANY_IDS` filter present, generated SQL joins `contract_to_company` with `domain=0` and `company_id IN (...)`.

### B3 — Add grouped owner-company count query to `ContractDao`
- **File:** `modules/jackrabbit/dao/ContractDao.java`
- **Change:** New public method, e.g. `List<OwnerCompanyCount> countContractsByOwnerCompany()`:
  - Criteria query over `Contract` (root) joined to `contractToCompanyList` (`domain = Owner`).
  - `groupBy` the owner `companyId`; select `companyId` and `countDistinct(contract.id)`.
  - Use the inherited `protected EntityManager entityManager` (`BaseDao.java:37`) to build/execute the query. (Criteria multiselect into a tuple/DTO, or a typed `Object[]` list, then map to the DTO in B5.)
- **Contract count semantics:** count **distinct** `Contract.id` so a contract with duplicate owner rows is not double-counted; owner is 1:1 in practice so this is a safety net.
- **Satisfies:** AK4. **Verify:** returns one row per distinct owner `company_id` with a plausible count; sum over all rows equals the export total (see B7/AK6 gate).

### B4 — New count DTO (transport shape for the endpoint)
- **File:** new `modules/jackrabbit/dto/OwnerCompanyCount.java` (simple POJO, `@XmlRootElement` per existing DTO style — see `ContractToCompany.java` for annotation/style reference).
- **Fields:** `Integer companyId; Long count;` (or `Integer count`) with getters/setters. JSON serializes to `{ "companyId":…, "count":… }` — matches the frozen contract.
- **Satisfies:** AK4 contract. **Verify:** JSON field names are exactly `companyId` / `count`.

### B5 — New `ownerCompanyCounts` endpoint in `ContractService`
- **File:** `modules/jackrabbit/service/ContractService.java`
- **Change:** New method modeled on `totalCount()` (lines 566–575):
  ```java
  @GET
  @Path("ownerCompanyCounts")
  @RolesAllowed(SystemUserGroup.ROLE_NAME_SYSTEM_ADMINISTRATOR)
  public Response ownerCompanyCounts() { … }
  ```
  - Delegate to the new `contractDao.countContractsByOwnerCompany()` (do NOT bypass the DAO with inline SQL — respect the service→DAO layering; this is a new DAO method, which is the correct pattern).
  - Return the list as `Response.ok(list).build()` (JSON array).
- **Access:** `@RolesAllowed(SystemUserGroup.ROLE_NAME_SYSTEM_ADMINISTRATOR)` — unchanged access model (Decision 5).
- **No `ApplicationConfig` change** — class already registered.
- **Satisfies:** AK4. **Verify:** `GET webresources/sc/contract/ownerCompanyCounts` (as system admin) returns the array; a non-admin gets 403.

### B6 — Extend `exportFiles` to accept `companyIds`
- **File:** `modules/jackrabbit/service/ContractService.java`, method `exportFiles` (lines 577–610)
- **Change:**
  - Signature: `exportFiles(@QueryParam("page") Integer page, @QueryParam("pageSize") Integer pageSize, @QueryParam("companyIds") List<Integer> companyIds)`.
  - **Guard (design §B):** if `companyIds != null && companyIds.isEmpty()` → return an empty zip / empty archive descriptor. Never fall back to "all" when the param was supplied empty. (When `companyIds == null` — param absent — keep current all-contracts behavior for backward compatibility.)
  - When `companyIds` is non-empty: before the existing ordering/pagination, add
    `findParameters.getQueryFilters().add(QueryFilter.getIn(Contract.FILTER_OWNER_COMPANY_IDS, companyIds));`
    (`QueryFilter.getIn(String, List)` exists and handles `List<Integer>` → String values — see `QueryFilter.java:153`.)
  - Keep ordering by `Contract.PROPERTY_NAME_ID asc` and the limit/offset pagination **after** the filter, unchanged.
- **Note on the ZIP file-index label:** the current code computes `fileIndexFrom/To` from the **unfiltered** `getOnlyTotalCount` (lines 591–598). With a company filter the naming will be relative to the global total, not the filtered total. The design does not call for changing the label; **leave label logic as-is** and surface this as a decision (see Open questions). Do not silently redesign it.
- **Satisfies:** AK5, AK6 (absent param path unchanged). **Verify:** with `companyIds` set, the zip contains only selected companies' contracts; with param absent, identical to today.

### B7 — Backend smoke verification (AK6 gate)
- Deploy; as system admin call:
  1. `GET webresources/sc/contract/ownerCompanyCounts` → note the sum of all `count` values.
  2. `GET webresources/sc/contract/totalCount` → note the total (~16 407).
- **Gate:** if the two do not match, some contracts have an owner company outside the counted set (or a non-Owner-domain data quirk). **Stop and flag** — the front-end list source (hardcoded `contractCompanies`) then cannot represent "all", and the design's list-source decision must be revisited (fall back to a DB-driven owner-company list).

---

# FRONTEND SLICE (`publicERANET-client`) — executor-frontend

All feature files under `app/modules/jackrabbit/`. i18n under `app/scripts.no.min/langs/`.

### F1 — Add `getOwnerCompanyCounts` resource + service method
- **File:** `modules/jackrabbit/service/contracts.js`
- **Change:**
  - In the `ContractsResource` `$resource` action map (near `getTotalCount`, lines 71–74), add:
    ```js
    getOwnerCompanyCounts: { method: 'GET', isArray: true, url: 'webresources/sc/contract/ownerCompanyCounts' }
    ```
  - Expose on the service object (near `serviceResult.getTotalCount`, line 218):
    `serviceResult.getOwnerCompanyCounts = ContractsResource.getOwnerCompanyCounts;`
- **Satisfies:** AK4 wiring. **Verify:** service method returns the counts array.
- **Note:** the company list itself comes from `$rootScope.contractCompanies` (already defined, lines 165–182), used as-is including `visible:false` entries (Decision 3). Do not re-fetch names.

### F2 — Controller: preload counts, default all-selected, live recount, +/− handlers
- **File:** `modules/jackrabbit/controller/exportAllFilesController.js`
- **Inject** `Contracts` is already injected. Add whatever else is needed only if used.
- **Changes:**
  1. On open, call `Contracts.getOwnerCompanyCounts().$promise.then(...)` → build a `countsById` map `{ companyId: count }`.
  2. `$scope.companies = $rootScope.contractCompanies;` (all entries, incl. hidden — Decision 3).
  3. `$scope.help = { selectedCompanies: <all companies> };` — default ALL selected (AK1). (Use a copy of `companies` so removing chips does not mutate the source.)
  4. `computeSelectedCount()`: `selectedCount = Σ countsById[c.id] for c in help.selectedCompanies`. Because `contractCompanies` has a **duplicate id 42455** (iSK plyn hidden + BioplynR visible), summing by id would double-count if both are selected — de-duplicate the **set of ids** before summing (sum each distinct selected id's count once). This keeps AK6 (all-selected total == server total) correct.
  5. `selectedCount` replaces `totalCount` as the driver of `updateParts()` (keep loading `totalCount` for the "Celkový počet zmlúv" display, or show `selectedCount` — see F3/Open questions).
  6. `addAllCompanies()` → `help.selectedCompanies = companies.slice()`; `removeAllCompanies()` → `help.selectedCompanies = []`; both call `computeSelectedCount()` then `updateParts()` (AK3). ui-select chip add/remove triggers the same recompute (AK2) — wire via `on-select` / `on-remove` or a `$watch` on `help.selectedCompanies`.
  7. In `updateParts()`: iterate against `selectedCount` (not `totalCount`); append `&companyIds=<id>` for each distinct selected id to each `part.link`. Build the suffix once: e.g. `_.uniq(selected ids).map(function(id){return '&companyIds='+id;}).join('')`.
  8. If `selectedCount === 0` → `$scope.parts = []` (render no batch links — nothing selected exports nothing) (AK4/AK5 edge).
- **Satisfies:** AK1, AK2, AK3, AK4, AK5. **Verify:** default all-selected count == server total; toggling a company changes count and rebuilds parts; empty selection → 0 parts; each link carries the selected `companyIds`.

### F3 — View: add the company multiselect block with +/− buttons
- **File:** `modules/jackrabbit/view/exportAllFilesDialog.html`
- **Change:** Insert a new `row` **above** the existing "Počet zmlúv v jednej dávke" row (currently lines 16–29), copying the proven PSK org-directory pattern.
- **Reference to copy (verbatim structure):** `C:\Innovis\psk\publicERANET-client\app\views\companyProfile\editAdminUser.html` lines 59–86 (the `directories` row): `col-7` `<ui-select multiple>` + `col-1` with two `btn btn-circle` anchors (`fa fa-plus-square` add-all, `fa fa-minus-square` remove-all; minus wrapped in `data-ng-if="help.selectedCompanies.length > 0"`; tooltips `ADD_ALL` / `REMOVE_ALL`).
- **Bind:** `data-ng-model='help.selectedCompanies'`; choices `repeat='company in companies | filter: {name: $select.search} | orderBy:"name"'`; match `{{$item.name}}`; buttons call `addAllCompanies()` / `removeAllCompanies()`.
- **Label:** add a label cell using a new key (F4), Slovak value "Spoločnosť".
- Counts are **not** shown per company (Decision 2) — only names in the select.
- Optionally update the "Celkový počet zmlúv: {{totalCount}}" line to reflect the selected count; decide in review (Open questions). Keep it truthful — if it stays `totalCount`, the batch links (driven by `selectedCount`) must still be correct.
- **Satisfies:** AK1, AK2, AK3. **Verify in browser:** multiselect renders with all companies preselected; +/− work; layout matches existing dialogs.

### F4 — i18n keys (ADD both langs files — they are MISSING)
- **Files:** `app/scripts.no.min/langs/sk.js` and `app/scripts.no.min/langs/en.js`
- **Change:** Add three keys to **both** files (English keys, localized values):
  - `ADD_ALL` — sk: "Pridať všetky", en: "Add all"
  - `REMOVE_ALL` — sk: "Odobrať všetky", en: "Remove all"
  - a company-filter label key, e.g. `EXPORT_FILES_COMPANY` — sk: "Spoločnosť", en: "Company"
- **Placement:** alongside existing dialog keys (e.g. near `ADD_PREDEFINED_FIELD_CLOSE`, sk.js ~1118 / en.js ~1103). English-only keys; Slovak only in values.
- **Satisfies:** AK3 (tooltips), AK1 (label). **Verify:** tooltips and label render translated, no raw keys shown.

### F5 — Karma/Jasmine controller test
- **File:** new spec beside existing client tests for this controller (follow the project's Karma spec location/naming; check `testing` skill and existing `*.spec.js` layout).
- **Cases (from design Testing):**
  1. Default: `help.selectedCompanies` = all; `selectedCount` == sum of all distinct counts.
  2. Toggle off one company → `selectedCount` drops by that company's count; `updateParts()` rebuilds with correct number of parts.
  3. `addAllCompanies()` / `removeAllCompanies()` set full/empty selection and recompute.
  4. `updateParts()` appends `&companyIds=<id>` for each selected id; part count matches `ceil(selectedCount / pageSize)`.
  5. Empty selection → `parts.length === 0`.
  6. Duplicate id 42455 selected via both rows → counted once (no double-count).
- **Verify:** `grunt`/Karma run green.

### F6 — Frontend smoke verification
- Open the "Export súborov" popup as system admin:
  - All companies preselected; displayed count == server total (**AK6**).
  - Uncheck some companies → count drops, batch links rebuild.
  - Download a batch → archive contains only selected companies' attachments (**AK5**).
  - Deselect all → no batch links.

---

## Execution order & parallelism

- Backend (B1→B7) and Frontend (F1→F6) are largely independent once the **contract** (endpoint URLs, `companyId`/`count`, `companyIds`) is frozen at the top. They can run in parallel.
- Frontend F6 (and AK6) needs the backend deployed. Do backend smoke (B7) first; it is the gating check for the whole design.
- Suggested commits (each `feat(EP-13235, EP-13236): …`, confirm in app before committing):
  1. backend: owner-company IN filter + counts endpoint + export filter
  2. frontend: counts service + controller + view + i18n
  3. frontend: karma spec
  (Do not mix with any other ticket.)

## Open questions / risks (surface to user; do not decide unilaterally)

1. **AK6 gate (highest risk).** If sum of `ownerCompanyCounts` ≠ `totalCount`, the hardcoded `contractCompanies` list cannot represent "all" and the list source must change to DB-driven. This is the make-or-break check — run B7 before building the frontend.
2. **Duplicate company id 42455** ("iSK plyn" hidden + "BioplynR" visible) — both rows map to one id. Plan de-duplicates ids when summing and when building `companyIds`. Confirm the intended display (two rows, one underlying company) is acceptable, or whether one row should be dropped — a data quirk, likely leave as-is.
3. **ZIP file-index label** (`contract_files_NNN__MMM`) is computed from the global total, not the filtered total (B6 note). Design does not ask to change it. Confirm whether the label should reflect filtered counts, or stay global.
4. **"Celkový počet zmlúv" display** — keep showing `totalCount` (global) or switch to `selectedCount` (F3). Decide in review; batch links must remain driven by `selectedCount` regardless.
5. **Count query cost** — a grouped `countDistinct` over `contract` ⨝ `contract_to_company` runs once per popup open; acceptable. If slow at ~16k contracts, cache is not needed but note it.
