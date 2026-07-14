# EP-13133 — Evaluation Activity Log ("Aktivity" in evaluation detail)

**Story:** EP-13133 · **Dev:** EP-13166 · **Epic:** EP-13132 (SEPS – zmenové požiadavky 06/2026)
**Commit pair:** `feat(EP-13133, EP-13166): …`
**Date:** 2026-07-13

## Goal

Add a new **Aktivity** section to the supplier-evaluation detail screen ("detail
hodnotenia") that shows a chronological log of the key events on an evaluation
plus two current-state lines. Restructure the detail layout so evaluation
attributes stack vertically on the left and the Aktivity section sits on the
right — mirroring the existing **IO/VO request ("Požiadavka IO/VO")** Aktivity
section, which is the visual reference.

Module in code: `SrRatingHeader` (table `sr_rating_header`), REST base
`sc/srRatingHeader`. Status lifecycle: `Initial → InProgress → Sent → Closed`.

## Display format

Each activity line follows the IO/VO reference component:

```
«label»    Priezvisko Meno - Organizačná zložka (DD.MM.RRRR HH:mm)
```

- Name order, separator, and link styling copy the existing IO/VO Aktivity
  component (do not hand-roll — reuse its markup/styles).
- Empty org unit renders as the ticket example: `Oravec Martin -  (…)` (empty
  string, no crash).
- `CREATED` shows the creator when known; date/time only when system-generated.
- The `waitingOn` line has **no** timestamp (like `Schvaľuje` in the reference).

## Decisions (brainstormed & confirmed with the user)

1. **Data source — new dedicated table.** Not a reuse of the existing
   `EntriesHistory` microservice (stores only login/fullname + old/new value, no
   org unit, no typed event, no "opening") and not derived from entity snapshot
   fields (can't represent opening, send-for-approval time, or multiple
   delegations). A purpose-built append-only log is the source of truth.

2. **Current-state lines are derived, not rows.** `Posledná zmena` and
   `Čaká na spracovanie` are computed live at read time; no row is written per
   save.

3. **Actor resolved live.** Rows store an `actor_id` reference only. Name and the
   **current** org unit are resolved at read time from `SystemUser`. This makes
   "deactivated user keeps their name" and "show current org unit / empty string
   if none" fall out for free — nothing is snapshotted.

4. **Backfill from known fields**, best-effort (see below).

## Data model

New entity + table **`sr_rating_activity`** (Liquibase changeset, author
`m.bijalko`):

| Column | Type | Notes |
|---|---|---|
| `id` | PK | |
| `rating_header_id` | FK → `sr_rating_header` | the evaluation |
| `activity_type` | int (enum ordinal) | see below |
| `actor_id` | FK → `system_user`, **nullable** | who did it; null for system-generated creation |
| `activity_datetime` | datetime | when it happened |

Append-only: one row per event, never mutated. Multiple delegations → multiple
rows.

**`ActivityType` enum** (English identifiers; Slovak lives only in i18n values):

| Enum | Meaning | Hooked on |
|---|---|---|
| `CREATED` | Vytvorenie hodnotenia (i18n value; shortened from ticket's "Vytvorenie iniciálneho hodnotenia" per user) | evaluation creation/generation |
| `OPENED` | Otvorenie hodnotenia | first `Initial → InProgress` transition |
| `REOPENED` | Znovuotvorenie hodnotenia | `reopenRating()` (`Closed → InProgress`) |
| `SENT_FOR_APPROVAL` | Odoslanie na schválenie | `InProgress → Sent` transition |
| `APPROVED` | Schválenie (uzatvorenie) | `approveRating()` and `closeRating()` (→ `Closed`) |
| `EVALUATION_DELEGATED` | Delegovanie hodnotenia | explicit delegate path |
| `APPROVAL_DELEGATED` | Delegovanie schvaľovania | `delegateApproval()` |

> The ticket text marks `Delegovanie schvaľovania` as blocked, but that predates
> EP-13135 (approval delegation), which has since landed — `delegateApproval()`
> exists. So `APPROVAL_DELEGATED` is fully wired, not reserved.

## Write hooks (server-side)

A small helper `recordActivity(header, type, actor)` appends one row, called via a
`BaseService` method (never DAO-direct). Hook points:

- `CREATED` — where evaluations are generated/persisted; actor = `creationAuthor`
  (null → date/time only).
- `OPENED` — in `update()` when status transitions `Initial → InProgress` (first
  save only); actor = current user.
- `SENT_FOR_APPROVAL` — on transition `InProgress → Sent`; actor = current user.
- `APPROVED` — in `approveRating()` (`Sent → Closed`) and `closeRating()`
  (→ `Closed`); actor = current user.
- `REOPENED` — in `reopenRating()`; actor = current user.
- `EVALUATION_DELEGATED` — on the **explicit** delegation path (piggyback
  `sendNotificationForDelegatePerson`, which fires only on a real delegation);
  actor = current user (the delegator).
- `APPROVAL_DELEGATED` — in `delegateApproval()`; actor = current user.

**Trap:** `reopenRating()` internally reassigns `delegateId = current user`.
`EVALUATION_DELEGATED` must therefore be emitted **only** from the explicit
delegation action, never from a generic "delegateId changed" check — otherwise
every reopen would look like a delegation.

## Backfill (in the Liquibase changeset)

Best-effort from fields we already store:

- `CREATED` ← `creation_datetime` + `creation_author_id` — **always** (real
  timestamp).
- `APPROVED` ← `closing_datetime` + `approver_id` — when `closing_datetime` is
  set.
- `REOPENED` ← `reopen_datetime`, actor ≈ `delegate_id` (reopen sets delegate to
  the reopener) — best-effort.

**Not backfilled** (no reliable stored timestamp): `OPENED`, `SENT_FOR_APPROVAL`,
`EVALUATION_DELEGATED`, `APPROVAL_DELEGATED`. These appear only for events after
deployment. (Confirmed with the user: honesty over approximation.)

## Read side

New endpoint **`GET sc/srRatingHeader/{id}/activities`** — reuses the detail
screen's existing access (no extra role guard; "každý to vidí"). Returns one
payload:

```json
{
  "activities": [
    { "type": "CREATED", "datetime": "...", "actorFullName": "...", "actorOrgUnit": "..." }
  ],
  "lastChange": { "datetime": "...", "actorFullName": "...", "actorOrgUnit": "..." },
  "waitingOn":  { "actorFullName": "...", "actorOrgUnit": "..." }
}
```

- `activities` ordered chronologically **ascending** (newest last, per ticket).
- Actor resolution: `actorFullName` = current name, `actorOrgUnit` = current org
  unit or `""`.
- `lastChange` ← `modificationDatetime` + `modificationAuthor` (fall back to
  creation if never modified).
- `waitingOn` ← from status:
  - `Initial` / `InProgress` → evaluator (`delegatePerson` if delegated, else
    `creationAuthor`)
  - `Sent` → `approver`
  - `Closed` → none (omit the line)

Planner to confirm the exact org-unit field/relation on `SystemUser`.

## Frontend

**File:** `publicERANET-client/app/views/supplierRating/editSupplierRating.html`
+ controller `editSupplierRating.js`. Existing Bootstrap 3 / SmartAdmin
components only — no new CSS or libraries.

- Wrap the info block in a **left column** (`col-md-8`) and stack the evaluation
  attributes vertically (single column) instead of today's two-column pairing.
- Add a **right column** (`col-md-4`) with an **Aktivity** panel copied from the
  IO/VO request Aktivity component's markup/styling.
- Panel content:
  1. `ng-repeat` over `activities` (chronological, newest last) — label from an
     i18n key per type (`SUPPLIER_RATING_ACTIVITY_*`), value formatted like the
     IO/VO component, date via the existing date filter.
  2. Below, visually separated: **Posledná zmena** (`lastChange`) and **Čaká na
     spracovanie** (`waitingOn`, hidden when `Closed`/none).
- Add `loadActivities(id)` to `srRatingHeaders.js`
  (`GET sc/srRatingHeader/{id}/activities`); call on detail load and after each
  action that already triggers a reload (save/send/approve/reopen/delegate).
- All Slovak text in translation values only.

## Testing & verification

**Manual smoke (primary), through the real flow:**
1. Create/generate → `CREATED` (date/time + creator).
2. First open/save → `OPENED`; `waitingOn` = evaluator.
3. Send for approval → `SENT_FOR_APPROVAL`; `waitingOn` = approver.
4. Approve/close → `APPROVED`; `waitingOn` cleared.
5. Reopen → `REOPENED`; `waitingOn` = evaluator; **no** spurious delegation row.
6. Delegate evaluation → `EVALUATION_DELEGATED` (delegator).
7. Delegate approval → `APPROVAL_DELEGATED` (delegator).
8. User with no org unit → empty org slot; deactivated user → name still shows.
9. Pre-migration evaluation → backfilled CREATED/APPROVED/REOPENED render;
   send/delegation absent.
10. Order chronological, newest last.

**Karma/Jasmine (client):** activity formatting helper (name/org/empty-org) and
controller load/reload wiring.

**Regression:** layout restructure must not break the evaluation sheet, save,
send, approve, reopen, or delegate flows.

## Key files

- View/controller:
  `publicERANET-client/app/views/supplierRating/editSupplierRating.html`,
  `publicERANET-client/app/scripts/controllers/supplierRating/editSupplierRating.js`
- Client resource:
  `publicERANET-client/app/scripts/service/resources/srRatingHeaders.js`
- Entity:
  `publicERANET-server/eranet-domain/src/main/java/sk/innovis/eranetpublic/server/dto/SrRatingHeader.java`
  (+ new `SrRatingActivity.java`)
- Service/endpoint:
  `publicERANET-server/public-eranet/src/main/java/sk/innovis/eranetpublic/server/service/SrRatingHeaderService.java`
- IO/VO Aktivity reference (visual pattern to copy): the
  `internalProcurementRequest` / `externalProcurementRequest` detail views.

## Open items

- Confirm the exact org-unit field/relation on `SystemUser` (planner).
- Locate and copy the IO/VO Aktivity component markup (planner).
