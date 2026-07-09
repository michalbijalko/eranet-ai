# EP-13137 — Design: new attribute "Stupeň dôvernosti" (degree of confidentiality)

**Story:** EP-13137 · **Dev sub-task:** EP-13161 · **Test sub-task:** EP-13162 · **Epic:** EP-13132
**Cloned from:** EP-13136 (sibling "Obsahuje limitované informácie", currently In Progress)
**Commit message (exact, docs):** `docs(EP-13137): design + plan for "Stupeň dôvernosti" confidentiality-degree attribute`

> Intent brainstormed and approved with the user. Jira ticket read directly (Atlassian MCP authenticated this session). ACs below are transcribed from the live ticket. Codebase patterns confirmed by two exploration passes (server + client).

---

## 1. What the ticket asks for

A **new single-select codebook attribute** "Stupeň dôvernosti" on the **Požiadavky IO** (InternalProcurementRequest) and **Požiadavky VO** (ExternalProcurementRequest) forms.

**Acceptance criteria (from EP-13137):**
1. New attribute available in Požiadavky IO and Požiadavky VO.
2. Codebook type; options: *(empty)*, **Verejné**, **Interné**, **Chránené**, **Prísne chránené**.
3. Default = *(empty)*.
4. Gray help note under the field: *"podľa smernice SM 04/2022 Klasifikácia informácií a nakladanie s klasifikovanými informáciami v SEPS"*.
5. Added to the protocol **Požiadavka na obstarávanie** (PDF); value renders correctly.
6. Added to the **statistics** module for IO and VO, and to **system settings** (Nastavenia — display + mandatory).
7. Value saves and reloads correctly.
8. **Conditional rule** against the sibling field *Obsahuje limitované informácie*:
   - Limitované = **Nie** → all 5 options selectable.
   - Limitované = **Áno** → only *(empty)* and **Prísne chránené** selectable.
   - Flipping Limitované **Nie → Áno** resets Stupeň dôvernosti to *(empty)*.

## 2. Decisions taken during brainstorm

| # | Decision | Rationale |
|---|---|---|
| Scope | **IO + VO procurement forms only** (2 entities/forms). Do **not** touch editInternalRequestBase / editExternalRequestBase. | Ticket names only Požiadavky IO/VO. Sibling lives on 4 forms; this one is scoped to 2. |
| Type | **Single-select**, one `SMALLINT` code column per entity; `null` = empty. | Screenshot + AC show one value. Matches the cheap existing enum-code pattern (`type`, `procurementProcedure`), not the heavy multi-select join-table pattern (`strategicProcurementList`). |
| Required | **Settings-driven flag** (like the sibling); empty is savable unless an admin marks it required. The red `*` shows only when the required flag is on. | Consistent with AC#3 (default empty) and the sibling field. |
| Legacy load | **Restrict-only on load; reset to empty only on a user flip to Áno.** | Simplest; the `$watch` is guarded so a loaded record is never silently mutated. User: "should never happen… make it simple." |
| AC#8 reset | On a user change of `contractContainsSensitiveInfo` to `true` (Áno), set `degreeOfConfidentiality = null`. Option list restricted to {empty, Prísne chránené} while Áno. | Mirrors the existing `procurementProcedure → procurementProcedureNonCompetitive` reset-watcher idiom. |

## 3. Data model

New column `confidentiality_degree SMALLINT` on `internal_procurement_request` and `external_procurement_request` (nullable, no default → `null` = empty).

Codes (shared meaning across client/server): `1` = Verejné, `2` = Interné, `3` = Chránené, `4` = Prísne chránené. Empty = `null`.

No new table, no FK, no join entity — single scalar column per entity, mirroring `contract_contains_sensitive_info`.

## 4. Backend slice (`publicERANET-server`)

Reference field throughout: the sibling boolean `contractContainsSensitiveInfo`.

- **Liquibase** — `src/main/sql/2.5.0/db.changelog-EP13137.xml`, author `m.bijalko`, two `addColumn` changesets (IO + VO tables) each with a `rollback dropColumn`, EP8160 style. Append one `<include>` at the end of `src/main/sql/db.changelog-master.xml`.
- **Entities** `eranet-domain/.../dto/InternalProcurementRequest.java` & `ExternalProcurementRequest.java`:
  - `@Column(name = "confidentiality_degree") private Short degreeOfConfidentiality;` + getter/setter (mirror `contractContainsSensitiveInfo` at IO L391-392 / VO L412-413).
  - Value-code constants `..._DEGREE_OF_CONFIDENTIALITY_PUBLIC = 1` … `_STRICTLY_PROTECTED = 4`.
  - New field-config id constants: **IO `INTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY = 53`**, **VO `EXTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY = 61`** (next free ids; IO constants currently max 52, VO max 60).
- **CodebookService.java**:
  - `HashMap<Short,String>` (1→"Verejné" … 4→"Prísne chránené") registered under `getFullName(ENTITY_NAME, "degreeOfConfidentiality")` in both `shortCodebook` registrations — this is what `translate()` uses for PDF + statistics.
  - Field-config map entries `"Stupeň dôvernosti"` in `internalProcurementRequestFieldsConfiguration` (~L1211 area) and `externalProcurementRequestFieldsConfiguration` (~L1264 area), keyed by the new fieldId constants.
- **PDF** `service/pdf/InternalProcurementRequestBasePdfGeneratingService.java` (~L4515) & `ExternalProcurementRequestBasePdfGeneratingService.java` (~L1082): add a `"Stupeň dôvernosti".equals(field)` block that renders `codebookService.translate(ENTITY_NAME + ".degreeOfConfidentiality", value.toString())` (blank when `null`), mirroring the single-code `noticeAnnouncement` render.
- **StatisticsService.java**: add `new StatisticsField().identificator(Identificator.degreeOfConfidentialityIP).column("confidentiality_degree").readableName("Stupeň dôvernosti")` in the IO init list (~L599 area) and the VO equivalent (`degreeOfConfidentialityEP`, ~L670 area). Add the two `Identificator` enum constants in `serialization/dto/StatisticsField.java`, and a `translate()` case for each in the value-formatter switch (~L3018-3028) so codes render as their Slovak labels.
- **History** (optional, for parity): add a `saveHistoryItem(id, "degreeOfConfidentiality", ...)` line in `InternalProcurementRequestService` / `ExternalProcurementRequestService` next to the sibling's (IO ~L1172, VO ~L1153).

## 5. Frontend slice (`publicERANET-client`)

Reference block throughout: the sibling `ui-select` for "Obsahuje limitované informácie" (a `ui-select` over the `booleanVerbal` codebook), and the fixed-option dropdown `procurementProcedure`.

- **i18n** `app/scripts.no.min/langs/sk.js` + `en.js` (there is **no** `scripts/langs` source):
  - Label keys `INTERNAL_PROCUREMENT_REQUEST_DEGREE_OF_CONFIDENTIALITY` / `EXTERNAL_PROCUREMENT_REQUEST_DEGREE_OF_CONFIDENTIALITY` = "Stupeň dôvernosti".
  - Note keys `..._DEGREE_OF_CONFIDENTIALITY_NOTE` = "podľa smernice SM 04/2022 Klasifikácia informácií a nakladanie s klasifikovanými informáciami v SEPS".
  - Option-value keys `DEGREE_OF_CONFIDENTIALITY_PUBLIC` = "Verejné", `_INTERNAL` = "Interné", `_PROTECTED` = "Chránené", `_STRICTLY_PROTECTED` = "Prísne chránené".
  - EN values provisional — confirm with user (non-blocking).
- **codebookGenerator.js** (`app/scripts/service/codebookGenerator.js`):
  - New option list `degreeOfConfidentiality = [{id:null, name:''}, {id:1, name:'DEGREE_OF_CONFIDENTIALITY_PUBLIC'}, {id:2, ...INTERNAL}, {id:3, ...PROTECTED}, {id:4, ...STRICTLY_PROTECTED}]` (empty option first). *Implementation note: confirm the idiomatic empty-option representation against `procurementProcedure` / an existing clearable `ui-select` before finalizing.*
  - Form-config entry `{id: Codebook.INTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY, name: 'Stupeň dôvernosti'}` in `internalProcurementRequestFormFieldsConfiguration` (~L3876 area) and the VO array (~L4008 area).
  - Required-config entry `{id: Codebook...REQUIRED_FIELD_DEGREE_OF_CONFIDENTIALITY, name: 'Stupeň dôvernosti'}` in `internalProcurementRequestRequiredFieldsConfiguration` (~L3934) and VO (~L4072).
  - New `Codebook.*` constants for the field/required ids (match the server fieldId numbers).
- **Templates** — insert a `ui-select` block **immediately after** the "Obsahuje limitované informácie" block, copied from it:
  - `app/views/planning/internalProcurementRequest/editInternalProcurementRequest.html` (after the sibling block ~L646-674).
  - `app/views/planning/externalProcurementRequest/editExternalProcurementRequest.html` (after ~L800-810).
  - Bound to `request.degreeOfConfidentiality`; `ui-select-choices` iterate the **controller option-list function** (see AC#8); include the `label-note` help line + settings-driven `*` (`requiredByFieldConfiguration('Stupeň dôvernosti')`) wrapped in `showByFieldOrderConfiguration(field.fieldId, 'Stupeň dôvernosti')`.
- **Controllers** `app/scripts/controllers/planning/internalProcurementRequest/editInternalProcurementRequest.js` + `externalProcurementRequest/editExternalProcurementRequest.js`:
  - Option-list helper: returns all 5 when `request.contractContainsSensitiveInfo !== true`; returns `[empty, Prísne chránené]` when `=== true`.
  - `$scope.$watch('request.contractContainsSensitiveInfo', function(newVal, oldVal){ if(!$scope.request || oldVal === undefined) return; if(newVal === true) $scope.request.degreeOfConfidentiality = null; });` — mirrors the `procurementProcedure` reset-watcher; the `oldVal === undefined` guard = restrict-only on load.
  - Required-validation block copied from the sibling (~IO L1276 / VO L1288), gated on `requiredByFieldConfiguration('Stupeň dôvernosti')`, toggling `$setValidity('select', …)` on the new form control.

## 6. Settings (Nastavenia) — explicit (AC#6)

Adding the field-config entries to **both** maps, client and server, is what surfaces the attribute as a configurable row in the settings screen:
- **Display** (visibility + order): `...FieldsConfiguration` (server `CodebookService`) + `...FormFieldsConfiguration` (client `codebookGenerator`).
- **Mandatory**: `...RequiredFieldsConfiguration` (server + client).

No separate settings UI change is needed — the settings screen is data-driven off these maps. Verification must confirm the row appears for IP and EP and both toggles work.

## 7. Open questions / risks

1. **EN wording** for the label, note, and option values — ticket only gives Slovak. Provisional EN suggested; confirm with user. Not blocking.
2. **Empty-option representation** in the `ui-select` — confirm how an existing clearable dropdown offers "prázdna možnosť" (explicit `{id:null}` entry vs. `allow-clear`) and match it. Detail for the planner/executor to verify against `procurementProcedure`.
3. **Lockstep on the label match-key** "Stupeň dôvernosti" — it is a runtime match key in two independent groups (client: codebookGenerator name entries == template arg == controller validation arg; server: CodebookService value == PDF `.equals()` literal). Every occurrence in a group must be byte-identical or the field/section silently disappears. (Same hazard class as EP-13136.)
4. **AC#8 coupling to EP-13136** — the sibling field is In Progress on another branch. This feature reads `request.contractContainsSensitiveInfo`, which already exists; no dependency on EP-13136's rename beyond the field being present. Confirm branch/merge order with the user before executing.
5. **Statistics code rendering** — ensure the value-formatter switch translates the `SMALLINT` code to its label for IO and VO (not raw number).
