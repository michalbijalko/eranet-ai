# EP-13135 — Design: Delegation of evaluation approval ("Delegovanie schvaľovania")

**Story:** EP-13135 · **Dev sub-task:** EP-13157 · **Epic:** EP-13132
**Builds on:** EP-13134 (approver column/filter — merged, READY FOR TESTING)

> Intent brainstormed and approved with the user (2026-07-10). Jira ticket read via Atlassian MCP;
> the popup mockup screenshot was pasted by the user. Codebase mapped by an exploration pass over
> both nested repos (branch `feat/EP-13132`).

---

## 1. What the ticket asks for

Allow delegating the **approval** of a supplier evaluation (Hodnotenie dodávateľov) to another
approver while it is in state **Odoslané na schválenie**.

**Acceptance criteria (from EP-13135):**
1. **Delegovať** button on the evaluation detail, shown only when status = Odoslané na schválenie.
2. Button visible only to the **current approver** and the **person responsible for supplier-evaluation management** (Osoba zodpovedná za správu hodnotenia dodávateľov).
3. Click opens popup **"Delegovanie schvaľovania"** with one required select of users from the approvers codebook (nastavuje sa v nastaveniach systému).
4. Empty select on submit → standard validation message **"Formulár obsahuje chyby."**
5. On save: the selected user becomes the approver; status stays Odoslané na schválenie; the original approver loses access (evaluation disappears from their approval tasks; they can no longer approve/reject); the new approver gains it.
6. The new approver receives the **same notifications as a standard send-for-approval**; the old approver receives nothing.
7. An activity record **"Delegovanie schvaľovania"** is created in Aktivity. (*Displaying* activities is another story — we only create the record.)
8. The EP-13134 "Schvaľovateľ" overview column and its filter reflect the new approver.

## 2. Key findings from exploration

- Entity **`SrRatingHeader`** (`sr_rating_header`) already stores the approver: `approverId`
  (`approver_id`) + `@ManyToOne SystemUser approver`. Status enum: `Initial(0) / InProgress(1) / Sent(2) / Closed(3)`;
  `Sent` = Odoslané na schválenie.
- **Approve/reject enforcement and the "awaiting my approval" list both key off `approverId`**
  (`SrRatingHeaderService.isCurrentApprover`, `FILTER_NAME_FOR_APPROVER`), so swapping `approverId`
  hides the evaluation from the old approver and shows it to the new one **with no extra code** (AC 5, 8).
- **Permission gap:** the generic `SrRatingHeaderService.update()` allows changes to a `Sent`
  rating only for the current approver or a system administrator (L110-113) — a responsible person
  delegating would be rejected. This drives the dedicated-endpoint decision below.
- Approvers codebook: setting **`sr_approval_persons`** (comma-separated `SystemUser` IDs),
  parsed in `SrRatingHeaderService.isApprover()` (L360-369). Responsible persons:
  **`sr_responsible_persons`** → `isResponsiblePerson()` (L386-395).
- Notification: `@GET sendNotificationForApprovers/{ratingId}` (L180-193) emails
  `rating.getApprover().getEmail()` with the standard approval mail — calling it **after** the swap
  satisfies AC 6 verbatim.
- "Aktivity" for ratings = generic **`EntriesHistory` / `CeChangeEntries`** records created
  client-side via `bulkSave` (`editSupplierRating.js` L208-211, `createHistoryItem` L89-97,
  `HISTORY_OBJECT_SUPPLIER_RATING`); the send-for-approval flow already writes a "Schvaľovateľ" item.
- Popup to clone: **`approverSupplierRatingPopup`** (js + html) — one required ui-select of the
  approvers codebook (`Users.loadUsersActiveAndInactiveByIds` over the parsed setting), Uložiť/Zrušiť,
  opened via `$uibModal` from `editSupplierRating.js` (L264-272).
- The existing "Delegovať" button (evaluator delegation, `delegatePerson`) shows only while
  status < `Sent`; the new approval-delegation button shows only at status == `Sent` — same label,
  never visible together, no conflict.

## 3. Decisions taken during brainstorm (user-confirmed 2026-07-10)

| # | Decision | Rationale |
|---|---|---|
| Server API | **Dedicated endpoint** `delegateApproval` in `SrRatingHeaderService`, analogous to `reopenRating`. Do **not** widen the generic `update()` permission. | `update()` would need a responsible-person branch that lets them change *any* field of a `Sent` rating — broader than the ticket. A dedicated endpoint keeps the permission exactly as narrow as the AC. |
| Field label | **"Osoba"** (per the ticket's mockup screenshot), not "Schvaľovateľ" (AC table). | Screenshot reflects the client's latest intent. |
| Select contents | **Full approvers codebook**, select starts empty. Current approver not excluded. | Exactly AC 6; re-picking the same approver is a harmless no-op. |
| Server-side permission | current approver **or** responsible person **or** system administrator. | Button shows only to the first two (AC 3), but sysadmin is allowed server-side for consistency with `reopenRating`. |
| Codebook validation | Endpoint rejects a `newApproverId` not present in `sr_approval_persons`. | Server must not trust the client's list. |

## 4. Backend slice (`publicERANET-server`)

One new endpoint in `SrRatingHeaderService` (`sc/srRatingHeader`), modelled on `reopenRating` (L212-228):

- **`delegateApproval(ratingId, newApproverId)`**:
  1. Load the rating; require `status == Sent`, else error.
  2. Require caller = current approver (`isCurrentApprover`) OR responsible person
     (`isResponsiblePerson`) OR system administrator; else error.
  3. Require `newApproverId` ∈ parsed `sr_approval_persons` setting; else error.
  4. Set `approverId` + `approver`; merge. Status untouched.
- **No Liquibase, no entity change, no DTO change, no DAO change.** The approver column and its
  filter (EP-13134) pick the new value up automatically.
- Notification is **not** sent from this endpoint — the client calls the existing
  `sendNotificationForApprovers` afterwards, mirroring how send-for-approval works today.

## 5. Frontend slice (`publicERANET-client`)

- **Button** — `app/views/supplierRating/editSupplierRating.html`, action-button block (L339-372),
  next to Schváliť: `Delegovať` (reuse key `SUPPLIER_RATING_DELEGATE`), shown by new
  `showDelegateApproval()` in `editSupplierRating.js`:
  `status === Codebook.SUPPLIER_RATING_STATUS_SENT && (isApprover() || $rootScope.isSupplierRatingResponsiblePerson())`.
- **Popup** — new `delegateApprovalSupplierRatingPopup.js/.html`, a clone of
  `approverSupplierRatingPopup`:
  - title **"Delegovanie schvaľovania"** (new key), field label **"Osoba"** (reuse an existing
    generic key if one exists, else add one), required, ui-select over the approvers codebook,
    starts empty (`undefined`, not `null` — ui-select reset caveat), Uložiť/Zrušiť.
  - invalid submit → existing "Formulár obsahuje chyby." mechanism (same as the cloned popup).
- **Save flow** (controller, on popup confirm):
  1. call new resource action `delegateApproval` (add to `srRatingHeaders.js`);
  2. push `EntriesHistory` record — attribute **"Delegovanie schvaľovania"**, oldValue = old
     approver's name, newValue = new approver's name — via the existing `createHistoryItem` +
     `bulkSave` mechanism;
  3. call existing `SrRatingHeaders.sendNotificationForApprovers(ratingId)` (now targets the new approver);
  4. success toast + reload the rating.
- **i18n** — `app/scripts.no.min/langs/{sk,en,hr}.js` (no `scripts/langs` source): popup title key
  (sk "Delegovanie schvaľovania"), field label key if a generic "Osoba" key doesn't already exist.
  All identifiers/keys English-only.

## 6. Data flow summary

Delegovať click → popup (approvers codebook via `Users.loadUsersActiveAndInactiveByIds`) →
Uložiť → `delegateApproval(ratingId, newApproverId)` sets `approverId` server-side →
client writes "Delegovanie schvaľovania" history record → client triggers
`sendNotificationForApprovers` → standard approval email goes to the **new** approver →
old approver's task list, approve/reject rights, and the overview "Schvaľovateľ" column/filter all
follow `approverId` automatically.

## 7. Open questions / risks

1. **History vs. future Aktivity story** — the activity record is a `CeChangeEntries` row with
   attribute name "Delegovanie schvaľovania"; if the separate Aktivity-display story later wants a
   typed activity, this may need mapping. Accepted — matches today's rating-history pattern.
2. **Race:** if the approver approves while the responsible person delegates, last write wins.
   Matches existing behaviour of the module (no optimistic locking on these actions); not in scope.
3. **Attribute-name language** — existing rating history items already use Slovak attribute names
   ("Stav", "Schvaľovateľ") as *data values*, not identifiers; "Delegovanie schvaľovania" follows
   that precedent and does not violate the English-only identifier rule.
