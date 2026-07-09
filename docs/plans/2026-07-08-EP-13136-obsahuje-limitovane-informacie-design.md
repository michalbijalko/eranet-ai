# EP-13136 — Rename attribute to "Obsahuje limitované informácie" + legal help text

**Epic:** EP-13132 (SEPS zmenové požiadavky 06/2026)
**Story:** EP-13136 · **Dev sub-task:** EP-13159
**Commit pair:** `feat(EP-13136, EP-13159): ...`

## Goal

Rename the existing procurement-requirement attribute
*"Obsahuje zmluva limitované informácie"* → *"Obsahuje limitované informácie"*, and show a
static legal help text under the field. Applies to Požiadavky IO and Požiadavky VO, plus the
protocol, statistics, and system settings. The old name must appear nowhere in the system (AC #8).

## Current state (from codebase exploration)

- **i18n key:** `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO`
  - `sk.js:4406` = `"Obsahuje zmluva limitované informácie"`
  - `en.js:4176` = `"The contract contains sensitive information"`
- **Entity field:** `contractContainsSensitiveInfo`, column `contract_contains_sensitive_info`
  (Boolean / `BIT(1)`), on `ExternalProcurementRequest`, `InternalProcurementRequest`,
  `InternalRequest`.
- Already rendered as an **Áno/Nie `booleanVerbal` dropdown** in all 4 forms → the
  "enum Áno/Nie" acceptance criterion is **already satisfied**; no control change needed.
- **No static help-text key exists today** — field info is a hover `getFieldInfo(fieldId)` tooltip.

## Scope correction (2026-07-09)

The change applies to **Internal Procurement Request** and **External Procurement Request only**
(modules Požiadavky IO / VO). The **Internal Request** and **External Request** base modules are
**out of scope** and must stay unchanged. Because the visible label was a single shared i18n key
(`INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO`) used by all four forms, the rename is scoped
by introducing **per-module keys** — `INTERNAL_PROCUREMENT_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO`
(+ `_NOTE`) and `EXTERNAL_PROCUREMENT_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO` (+ `_NOTE`) — and
pointing only the two procurement templates at them. The shared key keeps its original value so the
Request forms render exactly as before. Server-side, only the InternalProcurementRequest /
ExternalProcurementRequest paths (CodebookService IP/EP, the two procurement PDF services,
StatisticsService IP/EP fields) change; the InternalRequest PDF and base statistics field keep the
old label.

## Decisions

1. **Label rename** = change the i18n **value** of the existing key (key stays; English-only rule
   is about identifiers, which are unaffected).
2. **Help text** = new always-visible gray line under the label, rendered with the existing
   `<label class='label-note'>{{'KEY'|translate}}</label>` pattern (same as
   `INTERNAL_REQUEST_ATTACHMENT_NOTE` — *"(Dokumenty je možné nahrať v sekcii \"Prílohy\")"*).
   New i18n key, e.g. `INTERNAL_REQUEST_CONTRACT_CONTAINS_SENSITIVE_INFO_NOTE`
   = *"podľa zákona č. 367/2024 Z. z. o kritickej infraštruktúre"*.
3. **AC #8 (old name nowhere):** the literal string is reused as display text in statistics
   `readableName`, in the PDF protocol headers, and as the field-config picker `name:` in
   nastavenia. All must change to the new label. In the **PDF** and **field-config** the literal
   also doubles as a **match key**, so client + server + PDF literals must change **in lockstep**
   and remain identical to each other.

## Open verification (must be the plan's first step)

- **How is the field-order/required configuration persisted?** If keyed by numeric `fieldId`,
  changing the display literals is safe. If anything persists the label **string**, a Liquibase
  data update is required. Confirm before editing any match literals.

## Change surface

**Client (`publicERANET-client`)**
- `scripts.no.min/langs/sk.js`, `en.js` — change existing value; add new `_NOTE` key.
  (Verify whether the non-minified `scripts/langs` sources must also change.)
- 4 templates — add the `label-note` line: `editInternalProcurementRequest.html`,
  `editExternalProcurementRequest.html`, `editInternalRequestBase.html`,
  `editExternalRequestBase.html`.
- `scripts/service/codebookGenerator.js` — field-config picker `name:` entries.

**Server (`publicERANET-server` / `eranet-domain`)**
- `CodebookService.java` (IP + EP config-map values).
- 3 PDF services — `InternalProcurementRequestBasePdfGeneratingService`,
  `ExternalProcurementRequestBasePdfGeneratingService`, `InternalRequestBasePdfGeneratingService`
  (display text; keep match keys consistent).
- `StatisticsService.java` — 3 `readableName(...)` strings.

## Out of scope

- No DB column rename (label-only change).
- No control-type change (already an Áno/Nie dropdown).
- EP-13137 ("Stupeň dôvernosti") is a separate story; it reuses this help-text pattern.

## Acceptance criteria (from ticket)

1. Attribute renamed to "Obsahuje limitované informácie".
2. Enum with Áno / Nie. *(already satisfied)*
3. Help text "podľa zákona č. 367/2024 Z. z. o kritickej infraštruktúre" under the field.
4. Correct in Požiadavky IO.
5. Correct in Požiadavky VO.
6. Correct in protocol *Požiadavka na obstarávanie*.
7. Editable in system settings for both modules; changes save correctly.
8. Old name appears nowhere (UI, protocol, settings).
