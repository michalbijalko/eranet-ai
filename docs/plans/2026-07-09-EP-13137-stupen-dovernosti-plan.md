# EP-13137 — Implementation Plan: new attribute "Stupeň dôvernosti"

**Story:** EP-13137 · **Dev sub-task:** EP-13161 · **Epic:** EP-13132
**Commit message (exact):** `feat(EP-13137, EP-13161): add "Stupeň dôvernosti" confidentiality-degree attribute to Požiadavky IO/VO`
**Authoritative design:** `docs/plans/2026-07-09-EP-13137-stupen-dovernosti-design.md`

> Scope: IO + VO procurement forms only. Single-select `SMALLINT` code column, `null` = empty. Settings-driven required flag. AC#8 restrict/reset via a `$watch`. All line numbers verified during exploration 2026-07-09 — **re-confirm by grepping the literal/symbol before editing** (files drift).

---

## Ordering & lockstep

- **Backend first** (column + Liquibase must exist before the client can save/reload for AC#7 verification), then **frontend**.
- Two independent **lockstep match-key groups** for the label `"Stupeň dôvernosti"` — every occurrence in a group must be byte-identical or the field/PDF section silently vanishes:
  - **CLIENT group:** `codebookGenerator.js` name entries == template `showByFieldOrderConfiguration`/`requiredByFieldConfiguration` args == controller validation arg.
  - **SERVER group:** `CodebookService` field-config value == PDF `.equals(field)` literal.
- **Value codes** `1..4` are the second lockstep: client option-list ids == server code constants == `CodebookService` HashMap keys.

---

## BACKEND slice (`publicERANET-server`) — executor-backend

### B1. Liquibase (do first)
- Create `src/main/sql/2.5.0/db.changelog-EP13137.xml`, author `m.bijalko`:
  - `changeSet` 1: `addColumn` `confidentiality_degree SMALLINT` to `internal_procurement_request` + `rollback dropColumn`.
  - `changeSet` 2: same for `external_procurement_request`.
  - Model exactly on `src/main/sql/2.5.0/db.changelog-EP8160.xml`.
- Append one `<include file=".../2.5.0/db.changelog-EP13137.xml"/>` at the end of `src/main/sql/db.changelog-master.xml` (after the last 2.5.0 include).

### B2. Entities
`eranet-domain/src/main/java/sk/innovis/eranetpublic/server/dto/InternalProcurementRequest.java`:
- Add `@Column(name = "confidentiality_degree") private Short degreeOfConfidentiality;` next to `contractContainsSensitiveInfo` (~L391), with getter/setter (~L1198-1203 area).
- Add value-code constants `INTERNAL_PROCUREMENT_REQUEST_DEGREE_OF_CONFIDENTIALITY_PUBLIC = 1`, `_INTERNAL = 2`, `_PROTECTED = 3`, `_STRICTLY_PROTECTED = 4` (Short).
- Add field-config id constant `INTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY = 53` (verify 53 is free; IO constants currently end at 52, L173-222). Add the matching `..._REQUIRED_FIELD_DEGREE_OF_CONFIDENTIALITY` if the required map keys off a separate constant series (check how the sibling's required id is declared).

`eranet-domain/.../dto/ExternalProcurementRequest.java`:
- Same field/getter/setter (~L412 / ~L1265).
- Value-code constants (mirror).
- Field-config id constant `EXTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY = 61` (verify free; VO constants end at 60, L185-242) + required counterpart.

### B3. CodebookService.java (`public-eranet/.../service/CodebookService.java`)
- Build `HashMap<Short,String> ...DegreeOfConfidentiality` (1→"Verejné", 2→"Interné", 3→"Chránené", 4→"Prísne chránené") for IO and VO; register each under `getFullName(ENTITY_NAME, "degreeOfConfidentiality")` in `shortCodebook` (same block style as `internalProcurementRequestType` ~L1113-1118).
- Add `internalProcurementRequestFieldsConfiguration.put(INTERNAL_...FIELD_DEGREE_OF_CONFIDENTIALITY, "Stupeň dôvernosti");` (~L1190-1241 block) and the VO equivalent in `externalProcurementRequestFieldsConfiguration` (~L1243-1301).

### B4. PDF
- `service/pdf/InternalProcurementRequestBasePdfGeneratingService.java` (~L4515 region, in the field loop): add `else if ("Stupeň dôvernosti".equals(field)) { ... }` — bold label `counter + ". Stupeň dôvernosti:"`, value = `codebookService.translate(InternalProcurementRequest.ENTITY_NAME + ".degreeOfConfidentiality", value.toString())` when non-null else `""`, `counter++`. Mirror the `noticeAnnouncement` single-code block.
- `service/pdf/ExternalProcurementRequestBasePdfGeneratingService.java` (~L1082 region): same for VO.

### B5. Statistics (`public-eranet/.../service/StatisticsService.java`)
- IO init list (~L599): `othersFields.add(new StatisticsField().identificator(Identificator.degreeOfConfidentialityIP).column("confidentiality_degree").readableName("Stupeň dôvernosti"));`
- VO init list (~L670): same with `degreeOfConfidentialityEP`.
- `serialization/dto/StatisticsField.java`: add `Identificator` enum constants `degreeOfConfidentialityIP`, `degreeOfConfidentialityEP` (near L391-392).
- Value-formatter switch (~L3018-3028): add cases for both identificators that return `codebookService.translate(<ENTITY>.degreeOfConfidentiality, value)` (mirror the single-code `TypeIP` case ~L3001-3003), so codes render as Slovak labels, not raw numbers.

### B6. History (optional, parity)
- `InternalProcurementRequestService.java` (~L1172) & `ExternalProcurementRequestService.java` (~L1153): add `saveHistoryItem(id, "degreeOfConfidentiality", ...)` next to the sibling's.

### B7. Backend verification
- Compile: `mvn -q -pl public-eranet,eranet-domain -am compile` (or full build per deployment skill).
- Liquibase applies cleanly on a dev DB; column present on both tables.
- Sanity grep: `"Stupeň dôvernosti"` appears in `CodebookService` (2×) and both PDF services (1× each), byte-identical.

---

## FRONTEND slice (`publicERANET-client`) — executor-frontend

### F1. i18n (`app/scripts.no.min/langs/sk.js` + `en.js`)
- Add label keys `INTERNAL_PROCUREMENT_REQUEST_DEGREE_OF_CONFIDENTIALITY` / `EXTERNAL_PROCUREMENT_REQUEST_DEGREE_OF_CONFIDENTIALITY` = "Stupeň dôvernosti" (place near the sibling keys ~L4406 sk / ~L4176 en).
- Add note keys `..._DEGREE_OF_CONFIDENTIALITY_NOTE` = "podľa smernice SM 04/2022 Klasifikácia informácií a nakladanie s klasifikovanými informáciami v SEPS".
- Add option-value keys `DEGREE_OF_CONFIDENTIALITY_PUBLIC` = "Verejné", `_INTERNAL` = "Interné", `_PROTECTED` = "Chránené", `_STRICTLY_PROTECTED` = "Prísne chránené".
- EN values: provisional — confirm with user. Verify one hit per key per lang file.

### F2. codebookGenerator.js (`app/scripts/service/codebookGenerator.js`)
- New option list `degreeOfConfidentiality` (`{id,name}[]`, empty option first) modeled on `internalProcurementRequestProcurementProcedure` (~L4247): `[{id:null,name:''},{id:1,name:'DEGREE_OF_CONFIDENTIALITY_PUBLIC'},{id:2,name:'DEGREE_OF_CONFIDENTIALITY_INTERNAL'},{id:3,name:'DEGREE_OF_CONFIDENTIALITY_PROTECTED'},{id:4,name:'DEGREE_OF_CONFIDENTIALITY_STRICTLY_PROTECTED'}]`. **Verify the empty-option idiom** against an existing clearable dropdown before finalizing (explicit `{id:null}` vs. `allow-clear`).
- Form-config entry `{id: Codebook.INTERNAL_PROCUREMENT_REQUEST_FIELD_DEGREE_OF_CONFIDENTIALITY, name: 'Stupeň dôvernosti'}` in `internalProcurementRequestFormFieldsConfiguration` (~L3852-3908, sibling at L3876) and VO array (~L4008).
- Required-config entry `{id: Codebook...REQUIRED_FIELD_DEGREE_OF_CONFIDENTIALITY, name: 'Stupeň dôvernosti'}` in `internalProcurementRequestRequiredFieldsConfiguration` (~L3910, sibling at L3934) and VO (~L4072).
- New `Codebook.*` constants matching the server fieldId numbers (locate where `Codebook` is defined; add alongside the sibling's constants).

### F3. Templates — insert `ui-select` block after the sibling block
Copy the sibling "Obsahuje limitované informácie" block and adapt: bind `request.degreeOfConfidentiality`, `name='degreeOfConfidentiality'`, `ui-select-choices repeat` over the controller option-list helper (F4), `label` key `..._DEGREE_OF_CONFIDENTIALITY`, `label-note` key `..._NOTE`, wrap in `showByFieldOrderConfiguration(field.fieldId, 'Stupeň dôvernosti')`, `*` via `requiredByFieldConfiguration('Stupeň dôvernosti')`.
- `app/views/planning/internalProcurementRequest/editInternalProcurementRequest.html` — after sibling block (~L646-674).
- `app/views/planning/externalProcurementRequest/editExternalProcurementRequest.html` — after sibling block (~L800-810).

### F4. Controllers — option list + AC#8 watch + required validation
`app/scripts/controllers/planning/internalProcurementRequest/editInternalProcurementRequest.js` and `externalProcurementRequest/editExternalProcurementRequest.js`:
- **Option-list helper** on `$scope` (e.g. `getDegreeOfConfidentialityOptions()`): returns the full `CodebookGenerator.degreeOfConfidentiality` when `request.contractContainsSensitiveInfo !== true`; returns only the `{id:null}` and `{id:4}` (Prísne chránené) entries when `=== true`. Referenced by the template `ui-select-choices repeat`.
- **AC#8 watch** (place with the other reset-watchers ~L2904-2967): `$scope.$watch('request.contractContainsSensitiveInfo', function(newVal, oldVal){ if(!$scope.request || oldVal === undefined) return; if(newVal === true) $scope.request.degreeOfConfidentiality = null; });`
- **Required validation** (copy sibling block, IO ~L1276 / VO ~L1288): gated on `requiredByFieldConfiguration('Stupeň dôvernosti')`, toggling `$scope.mainForm.degreeOfConfidentiality.$setValidity('select', …)`.

### F5. Frontend verification
- Karma/Jasmine suite green (`grunt test` / `karma start`) — no new failures. No behavioral unit test exists for this field; do not invent one unless a nearby pattern covers it.
- Manual smoke (below).
- Sanity grep: `'Stupeň dôvernosti'` byte-identical across codebookGenerator name entries, both template args, both controller validation args.

---

## Smoke test per acceptance criterion

- **AC#1/#2/#3:** open Požiadavky IO and VO edit forms → "Stupeň dôvernosti" dropdown present, offers *(empty)*/Verejné/Interné/Chránené/Prísne chránené, defaults to empty.
- **AC#4:** gray note "podľa smernice SM 04/2022 …" always visible under the field.
- **AC#5:** generate the "Požiadavka na obstarávanie" protocol for IO and VO → section present with correct label + selected value; empty renders blank.
- **AC#6 (statistics + settings):** the field appears in the statistics module for IO and VO with its selected value; in **Nastavenia** for IP and EP the "Stupeň dôvernosti" row appears and both the **display** (visibility/order) and **mandatory** toggles take effect on the form.
- **AC#7:** select a value, save, reopen → value persists and reloads.
- **AC#8:** with Limitované = Nie all 5 options show; set Limitované = Áno → only *(empty)* + Prísne chránené selectable; select Verejné under Nie, then flip Limitované to Áno → Stupeň dôvernosti resets to *(empty)*; reload of a record with Áno does not mutate a stored value (restrict-only on load).

## Lockstep integrity checklist (before claiming done)

1. Client: `codebookGenerator.js` name == template args == controller validation args == **`Stupeň dôvernosti`** (byte-identical). Field vanishes in a form ⇒ a client literal diverged.
2. Server: `CodebookService` value == PDF `.equals()` literal == **`Stupeň dôvernosti`**. PDF section vanishes ⇒ server literal diverged.
3. Codes `1..4` identical: client option ids == server value constants == `CodebookService` HashMap keys.

## Open questions / risks

1. EN wording for label/note/options — confirm with user (non-blocking).
2. Empty-option `ui-select` idiom — verify against an existing clearable dropdown before finalizing F2/F3.
3. Sibling coupling — AC#8 reads `request.contractContainsSensitiveInfo` (already exists). EP-13136 (sibling rename) is In Progress on another branch; confirm branch/merge order with the user before executing so the two don't collide on the shared forms.
4. fieldId 53 / 61 — re-verify they are unused before committing (constants drift).
