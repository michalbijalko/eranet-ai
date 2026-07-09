# EP-13136 — Implementation Plan: rename to "Obsahuje limitované informácie" + legal help text

**Story:** EP-13136 · **Dev sub-task:** EP-13159 · **Epic:** EP-13132
**Commit message (exact):** `feat(EP-13136, EP-13159): rename attribute to "Obsahuje limitované informácie" and add legal help text`
**Authoritative design:** `docs/plans/2026-07-08-EP-13136-obsahuje-limitovane-informacie-design.md`

> Intent already brainstormed and approved with the user. This plan does not add scope beyond the ticket's 8 acceptance criteria. Jira could not be read directly (Atlassian MCP unauthenticated in this session); the design doc's transcribed ACs are used as the source of truth.

---

## STEP 0 — Critical verification (DONE — result recorded here, no code change)

**Question:** Is the field-order / required-field configuration persisted by numeric `fieldId` or by the label string? (If by string → a Liquibase data update, author `m.bijalko`, would be required.)

**Result: persisted by NUMERIC `fieldId`. No Liquibase / no DB change needed.** Evidence:

- Server entity `FieldOrder` (`eranet-domain/.../dto/FieldOrder.java`) stores column `field_id` as `Integer` + `order_number`; it is owned by `Setting` (`Setting.fieldOrder : List<FieldOrder>`). No label column anywhere.
- Server PDF loop: `for (FieldOrder fieldOrder : fieldsConfigOrder) { String field = codebookService.translate(<entity>.FIELDS_CONFIGURATION, fieldOrder.getFieldId().toString()); ... }` — the persisted value is the numeric id; the label is derived at render time via `CodebookService`.
- Client persists/reads by id too: pickers are `{id: <numeric>, name: '<label>'}` (`codebook.js` numeric constants → `codebookGenerator.js` `name:`), and `showByFieldOrderConfiguration(fieldId, label)` resolves the label from `CodebookGenerator.getNameByIdAbs(<map>, fieldId)`.

**Consequence:** the Slovak label literals in code are pure **match keys / display text**, safe to change, provided each match group changes in lockstep (see below). Renaming does not migrate or break any saved setting.

### Two independent lockstep groups (KEY FINDING — broader than the design doc noted)

The literal `"Obsahuje zmluva limitované informácie"` is used as a runtime **match key** in more places than the design's AC#8 list. Matching never crosses the client/server boundary (client matches the client codebook; server matches the server codebook), so there are **two independent groups**. Within each group every occurrence must become the **identical** new string, or the field will disappear / required-validation will silently break.

- **CLIENT match group** (compared via `name === fieldLabel` against `CodebookGenerator`):
  - `codebookGenerator.js` `name:` entries (the source of truth for the client)
  - 4 templates: `showByFieldOrderConfiguration(field.fieldId, '<literal>')` and `requiredByFieldConfiguration('<literal>')`
  - 3 form controllers: `requiredByFieldConfiguration('<literal>')` validation calls
- **SERVER match group** (compared via `"<literal>".equals(field)` against `CodebookService.translate(...)`):
  - `CodebookService.java` config-map values (IP + EP)
  - PDF `equals(field)` guards (IP + EP procurement PDFs)

Display-only occurrences (no match, change purely for AC#8 "old name nowhere"): PDF section headers, `StatisticsService.readableName(...)`.

**New string for every code literal:** `Obsahuje limitované informácie` (identical everywhere; do not vary punctuation/spacing).

---

## Naming summary

| Thing | Old | New |
|---|---|---|
| Visible field label (i18n **value** of key `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO`) | `Obsahuje zmluva limitované informácie` | `Obsahuje limitované informácie` |
| Code match/display literal (everywhere below) | `Obsahuje zmluva limitované informácie` | `Obsahuje limitované informácie` |
| New help-text i18n key | — | `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE` |
| Help-text SK value | — | `podľa zákona č. 367/2024 Z. z. o kritickej infraštruktúre` |
| Help-text EN value | — | (agree with user; provisional literal translation) |

The i18n **key** is unchanged (English-only rule is about identifiers; the key is fine). No entity/DB column rename (`contract_contains_sensitive_info` stays).

---

## FRONTEND slice (`publicERANET-client`) — executor-frontend

All line numbers verified 2026-07-08; re-confirm before editing (grep the literal / key).

### F1. i18n — rename value + add help-text key
File: `app/scripts.no.min/langs/sk.js`
- Line **4406**: change value of `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO` → `"Obsahuje limitované informácie"`.
- Add new key `"INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE":"podľa zákona č. 367/2024 Z. z. o kritickej infraštruktúre",` (place next to the existing key, mirroring how `INTERNAL_REQUEST_ATTACHMENT_NOTE` sits near its field key).

File: `app/scripts.no.min/langs/en.js`
- Line **4176**: update EN value of the same key (currently `"The contract contains sensitive information"`) to match the new Slovak meaning — confirm exact EN wording with the user; suggested `"Contains limited information"`.
- Add `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE` EN value (suggested `"pursuant to Act No. 367/2024 Coll. on critical infrastructure"`).

Note: only `scripts.no.min/langs` holds translations — there is **no** `scripts/langs` source; do not look for one. Verification: `grep -n INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE` returns one hit per lang file.

### F2. Add the always-visible gray help line in all 4 forms (AC#3)
Pattern to copy (exact): `<label class='label-note'> {{'KEY'|translate}}</label>` — live example at `app/views/planning/editExternalRequest/editExternalRequestBase.html:2447` (`INTERNAL_REQUEST_ATTACHMENT_NOTE`).
Insert the new line **inside the label's `<section class='col col-3…'>`, immediately after the closing `</label>` and before `</section>`**, using key `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE`.

- `app/views/planning/internalProcurementRequest/editInternalProcurementRequest.html` — after `</label>` at **651**, before `</section>` at **652** (field block 646–673).
- `app/views/planning/externalProcurementRequest/editExternalProcurementRequest.html` — after `</label>` at **807**, before `</section>` at **808** (field block 802–826).
- `app/views/planning/editInternalRequest/editInternalRequestBase.html` — after `</label>` at **2543**, before `</section>` at **2544** (field block 2538–2556).
- `app/views/planning/editExternalRequest/editExternalRequestBase.html` — same structure/offset as editInternalRequestBase (field block ~2538–2556); place after the field's `</label>`, before `</section>`. Confirm exact lines by grepping the literal in this file.

### F3. Client match-group literal rename (lockstep — all → `Obsahuje limitované informácie`)
Do **all** of these together; a partial change hides the field or breaks required validation.

`app/scripts/service/codebookGenerator.js` `name:` entries — lines **535, 694, 2715, 2989, 3053, 3876, 3934, 4008, 4072** (IR form/required, IR-other, IP-other, EP-other, IP form, IP required, EP form, EP required maps). Grep the literal to catch any shifted line.

Templates (`showByFieldOrderConfiguration` arg + `requiredByFieldConfiguration` arg):
- `editInternalProcurementRequest.html` **646** and **649**
- `editExternalProcurementRequest.html` **802** and **805**
- `editInternalRequestBase.html` **2538** and **2541**
- `editExternalRequestBase.html` **2538** and **2541**

Form controllers (`requiredByFieldConfiguration('<literal>')` validation calls):
- `app/scripts/controllers/planning/internalProcurementRequest/editInternalProcurementRequest.js` **1276**
- `app/scripts/controllers/planning/externalProcurementRequest/editExternalProcurementRequest.js` **1288**
- `app/scripts/controllers/planning/editInternalRequest/editInternalRequestBase.js` **1196**

Do **not** touch `showStatisticsList.js` (no occurrence of the literal there).

### F4. Frontend verification
- Karma/Jasmine: run the client unit suite (`grunt test` / `karma start karma.conf.js`) — ensure no new failures. No behavioral unit test exists for this label; do not invent one unless a nearby pattern covers it.
- Manual smoke (see checklist below): AC#1, #3, #4, #5, #7, #8.
- Global sanity grep after edits: `grep -rn "Obsahuje zmluva limitované" app/` → **zero** hits in client.

---

## BACKEND slice (`publicERANET-server`) — executor-backend

No DAO/service-layer logic, no endpoint, no security, no entity, no Liquibase — literal display/match-key edits only. (Confirmed against the working agreement: nothing here calls a DAO directly or changes transactions.)

### B1. Server match-group literal rename (lockstep — all → `Obsahuje limitované informácie`)
- `public-eranet/.../service/CodebookService.java` — **1211** (`internalProcurementRequestFieldsConfiguration`) and **1264** (`externalProcurementRequestFieldsConfiguration`) map values.
- `public-eranet/.../service/pdf/InternalProcurementRequestBasePdfGeneratingService.java` — **4515** `else if ("…".equals(field))` (match key — must equal CodebookService:1211).
- `public-eranet/.../service/pdf/ExternalProcurementRequestBasePdfGeneratingService.java` — **1082** `else if ("…".equals(field))` (match key — must equal CodebookService:1264).

### B2. PDF display headers (AC#6, AC#8 — display only)
- `InternalProcurementRequestBasePdfGeneratingService.java` **4517** — `counter + ". Obsahuje zmluva limitované informácie:"` → new label.
- `ExternalProcurementRequestBasePdfGeneratingService.java` **1084** — same header string → new label.
- `InternalRequestBasePdfGeneratingService.java` **5088** — `"10.4 Obsahuje zmluva limitované informácie: "` (static line, no match key) → `"10.4 Obsahuje limitované informácie: "`.

### B3. Statistics readable names (AC#8 — display only, keyed by enum `identificator`, safe)
- `StatisticsService.java` — **455** (`contractContainsSensitiveInfo`), **599** (`…InfoIP`), **670** (`…InfoEP`) `readableName("…")` → new label.
- Do **not** touch the `switch` cases at 3019–3020 (they key on the enum, no literal).

### B4. Backend verification
- Compile: `mvn -q -pl public-eranet -am compile` (or full `mvn install` per deployment skill).
- Global sanity grep after edits: `grep -rn "Obsahuje zmluva limitované" publicERANET-server/` → **zero** hits.
- Regenerate a Požiadavka-na-obstarávanie protocol PDF for IO and VO and confirm the section still renders (lockstep intact) with the new header (AC#6).

---

## Lockstep integrity checklist (run before claiming done)

1. Client: `codebookGenerator.js name:` == template args == controller args == **`Obsahuje limitované informácie`** (byte-identical). If field vanishes in a form → a client literal diverged.
2. Server: `CodebookService` value == PDF `equals()` literal == **`Obsahuje limitované informácie`**. If PDF section vanishes → server literal diverged.
3. Whole-repo: no `Obsahuje zmluva limitované` remains in `publicERANET-client/` or `publicERANET-server/`.

---

## Smoke test per acceptance criterion

- **AC#1 (renamed):** open Požiadavky IO and VO edit forms → field label reads "Obsahuje limitované informácie".
- **AC#2 (Áno/Nie enum):** already satisfied — confirm the `booleanVerbal` dropdown still shows Áno/Nie and saves.
- **AC#3 (help text):** gray `label-note` line "podľa zákona č. 367/2024 Z. z. o kritickej infraštruktúre" is always visible under the field in all 4 forms.
- **AC#4 / AC#5 (IO / VO correct):** value saves and reloads correctly on both InternalProcurementRequest (IO) and ExternalProcurementRequest (VO); also the InternalRequest / ExternalRequest base forms.
- **AC#6 (protocol PDF):** generate the "Požiadavka na obstarávanie" protocol for IO and VO → section present, header uses new label, Áno/Nie value correct.
- **AC#7 (settings editable, both modules):** in Nastavenia, for IP and EP, toggle field visibility/required/order for this field, save, reopen the form → the field respects the saved config (proves the numeric-id persistence still binds after rename).
- **AC#8 (old name nowhere):** the two sanity greps return zero; visually check form, protocol PDF header, statistics field picker, and settings picker show only the new label.

---

## Open questions / risks

1. **EN help-text and EN label wording** — the ticket only specifies the Slovak strings. Confirm the EN value for the field label and for the `_NOTE` key with the user (provisional values suggested in F1). Not blocking backend.
2. **Jira not directly read** — Atlassian MCP is unauthenticated in this session; ACs come from the authoritative design doc. If the live ticket added detail (esp. images the user must paste), reconcile before executing.
3. **`editExternalRequestBase.html` exact lines** — mirror of editInternalRequestBase but confirm by grep before inserting the label-note; that form's PDF (`ExternalRequestBasePdfGeneratingService`) has **no** occurrence of the literal, so no backend change for it.
4. **Lockstep is the only real hazard** — every literal in a match group must be byte-identical to the new string. Both greps in the integrity checklist must be green before commit. No DB migration is in scope (Step 0).
5. **Build artifact dir** — client source lives in `app/scripts` + `app/scripts.no.min/langs`; if a separate minified/`dist` build is deployed, ensure the Grunt build is re-run per the deployment skill so the new strings ship.
