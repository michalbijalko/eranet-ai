# EP-13285 — ÚRSO notification sending drops the attachment

**Ticket:** EP-13285 (Podpora) — SEAS, module *Oznámenia ÚRSO*, competition ID18525
**Commit prefix:** `fix(EP-13285)` (no Story→Dev pair exists for this ticket)
**Date:** 2026-07-23

## Problem

On the *Oznámenia ÚRSO → Odosielanie* tab, sending the *Zoznam uchádzačov OVS* sends the
message **without the attached PDF**, silently. The checkbox still looks checked in the UI.

## Root cause

The server is correct — `UrsoPublishingService.createPublishing()` attaches exactly the file
IDs it receives in `SendRequest.attachmentIds`; an empty list means an email with no attachment,
no error.

The loss is on the client. Attachment selection is carried by a **shared, module-level singleton**
`fileDescriptionsResult` (`fileDescriptions.js`). The only record of "user checked this file" is a
`.checked` flag on the objects inside that array. At Send time,
`UrsoPublishings.save()` calls `FileDescriptions.getCheckedRecordIds()`, which reads whatever
`fileDescriptionsResult` points to **at that instant**. Every loader in the service does
`fileDescriptionsResult = value`, replacing it with fresh, unchecked objects. So if any reload
happens between checking the box and clicking Send — the directive's `FILE_LOADING_READY` handler,
the async procurement/publishings load, or a tab switch — `getCheckedRecordIds()` returns `[]` and
the email goes out empty. Property names match (`.checked` written and read), so it is intermittent,
not always-empty.

The picker directive already supports a durable selection store via `keep-checked` + `store-key`
(backed by `TemporaryStore`), but the ÚRSO sending view opts out of it.

## Decisions (brainstormed with the user)

1. **Robust fix** — decouple selection from the volatile singleton **and** add a guard.
2. **TemporaryStore path** (`keep-checked` + `store-key`) — lowest blast radius; the shared
   directive already implements it. Not the `FileDescriptions.checkedIds` map (would touch the
   shared directive, wider regression risk).
3. **Confirm dialog** on empty attachments — text-only sends stay possible; the silent bad send
   becomes impossible. Use the existing `DialogConfirmer` component.
4. **Two commits**, both `fix(EP-13285)` — attachment loss first, round-scoping second.

## Commit A — attachment loss

**View** — `app/views/procurement/ursoPublishing/ursoSending.html`, `<attachments-choose-table>`:
add
```
keep-checked='true'
store-key='ursoSendingAttachments-{{$root.procurementId}}'
```

**Controller** — `app/scripts/controllers/procurement/ursoPublishing/ursoSending.js`:
- Inject `TemporaryStore`, `DialogConfirmer`, `$translate`.
- Build the same key: `'ursoSendingAttachments-' + $rootScope.procurementId`.
- Extract the real send into a local `doSend()` (sets `sending.procurementId`, calls
  `UrsoPublishings.save`, resets, alerts, reloads).
- In `send()`, after the existing subject / email-setting validations, read
  `attachmentIds = TemporaryStore.get(key, [])` and set `$scope.sending.attachmentIds`.
  If empty → `DialogConfirmer.confirmMessage($translate.instant('URSO_SENDING_NO_ATTACHMENT_CONFIRM'), doSend)`
  and `return`; otherwise `doSend()`.
- On successful send, clear the key: `TemporaryStore.store(key, [])`.

**Service** — `app/scripts/service/resources/ursoPublishings.js`, `save()`:
- **Remove** `request.attachmentIds = FileDescriptions.getCheckedRecordIds()`. The controller now
  supplies `attachmentIds`; `save()` sends `request` as-is. This is the load-bearing decoupling.

**i18n** — new key (English key, Slovak value):
- `langs/sk.js`: `URSO_SENDING_NO_ATTACHMENT_CONFIRM: 'Správa neobsahuje žiadnu prílohu. Chcete pokračovať?'`
- `langs/en.js`: English value, e.g. `'The message contains no attachment. Do you want to continue?'`

**Why per-procurement key scoping:** file IDs are globally unique, so an unscoped key could carry
one procurement's selected IDs into another procurement's send.

**Tests:**
- Karma/Jasmine controller spec: `send()` sets `sending.attachmentIds` from the store key; empty
  store triggers the confirm and only sends on accept; successful send clears the key.
- Manual smoke: select the PDF, force a singleton reload (switch tab and back), Odoslať, verify the
  `POST sc/ursoPublishing` payload carries `attachmentIds: [<id>]` and the sent message has the
  attachment; then send with nothing selected to see the confirm.

## Commit B — round scoping (separate commit, after A is verified)

The picker loads `referenced-id='{{$root.procurementId}}'` (current round) while `send()` saves
against the root procurement, and the controller's own `getReferencedIds()` (root + repeated rounds)
is unused in this view. Switch the picker to `referenced-id-array='{{getReferencedIds()}}'`, matching
the *Príprava dokumentov* tab (`ursoDocuments.html`). Detail and verify after Commit A lands.

## Not changing

The server (`UrsoPublishingService`, `MessageService`, `SendRequest`) is correct and untouched.
The shared `attachmentsChooseTable` directive is untouched — the view only opts into attributes the
directive already supports, so other consumers are unaffected.
