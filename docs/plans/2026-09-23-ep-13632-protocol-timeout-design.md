# EP-13632 — Communication protocol generation times out

- **Story:** EP-13632 — *SEAS - generovanie protokolu - timeout*
- **Dev Sub-task:** EP-13634
- **Test Sub-task:** EP-13635
- **Epic:** EP-11898 (SEAS - SLA_26)

## Problem

Generating the *Protokol elektronickej komunikácie* (tender detail → *Poradie a Protokoly*
→ *Generovať protokol*) fails on tenders with a very large number of messages.

`MessageChronologicalPdfGeneratingService.generateProcurementChronologicalMessages` is a
plain `@Stateless` REST method with the default `REQUIRED` transaction and no
`@TransactionTimeout`, so the whole operation — loading every message, building the PDF and
writing the resulting file — runs inside one transaction bounded by the WildFly default of
300 seconds.

The operation is also slower than it needs to be. Inside the per-message loop it issues one
`fileService.findAllInternal(...)` query per message just to list attachment names, and the
message query loads `filesCount` data that the PDF never reads.

## Scope

Both the timeout and the N+1 are fixed. The ticket asks for the timeout; the N+1 is the
reason the timeout is reached and the fix is small and contained.

Out of scope: switching `findByProcurementIdForCurrentUser` to the all-users variant. That
filter is security behaviour, not a performance detail.

## Changes

### 1. Load message attachments in one query

`MessageChronologicalPdfGeneratingService.getTablesWithSuppliersAndMessagesByDomain`

The per-message `fileService.findAllInternal(...)` call moves out of the loop. All
`FileDescription` rows for the tender's messages are fetched once with
`QueryFilter.getIn(FileDescription.PROPERTY_NAME_REFERENCED_ID, messageIds)` and grouped by
message id; the loop then only looks the names up.

This mirrors `BaseService.fillWithFilesCount`, which already batches the same table the same
way. Two new private methods keep the loop readable:

- `loadAttachmentNamesByMessageId(List<Message>)` — the single query plus grouping
- `formatAttachmentNames(List<FileDescription>)` — the caption/name joining that used to be
  inline

### 2. Skip the unused files count

`MessageService` gains a sibling of `findByProcurementIdForCurrentUser` that applies
`FindParameters.withoutFiles()`. `BaseService.findAllInternal` then skips
`fillWithFilesCount`, whose per-item `stream().filter(...)` is `O(messages × files)`. The PDF
never reads `filesCount`.

### 3. Raise the transaction timeout

`@TransactionTimeout(3600)` (`org.jboss.ejb3.annotation.TransactionTimeout`, the import used
everywhere else in this codebase) on both entry points:

- `MessageChronologicalPdfGeneratingService.generateProcurementChronologicalMessages`
- `ProcurementService.generateAllProtocolosProcurement` — *Generovať všetky protokoly* runs
  this generator plus ~6 others in one untimed transaction, so it hits the same limit sooner

Existing precedent: `FileDownloadService.downloadZippedFiles`,
`ProcurementItemService.importItemPricesFromExcel`,
`ProcurementService.exportProcurementsFiles`, `AuctionService`, `ScheduleService`.

## Not changed

The client is untouched. The endpoint, its contract and the resulting PDF all stay the same —
the file is still saved as a `FileDescription` on the tender and the attachments table is
refreshed by the existing `EVENT_RELOAD_DATA` broadcast.

## Verification

The tender that fails exists only in production, so the acceptance criterion itself can only
be confirmed there. On the test environment:

1. **Regression.** Generate the protocol on an ordinary tender before and after the change
   and compare the two PDFs. They must be identical — this is the main risk of the change.
2. **Proof the N+1 is gone.** `BaseService` logs `Najdenych a vratenych {} objektov` on every
   `findAll`. Count those lines during one generation before and after; the count should drop
   from roughly the number of messages to a constant.

Confirming that generation now completes on the large tender falls to EP-13635 after deploy.
