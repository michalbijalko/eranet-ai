# EP-13104 — Full-text search in message body

**Story:** EP-13104 &nbsp;|&nbsp; **Dev:** EP-13114 &nbsp;|&nbsp; **Epic:** EP-12988
**Date:** 2026-06-17

## Problem

Search over the communication message list only matches the message **subject**
(`predmet`). It also, incorrectly, restricted subject search to *read* messages only.

Users need to find a message by words in its **body**, and to find messages
regardless of read status.

## Acceptance criteria (from ticket)

- Search over the message list matches both subject and body.
- A term present only in the body (not the subject) still returns the message.
- A term present in the subject still returns the message (original behaviour kept).
- Search spans **all** messages regardless of read status — unread messages are found.
- This applies to both subject search and body (full-text) search.
- Search reuses the **same filter** originally used for the subject.

## Key facts established during design

- `Message.body` is stored as a `@Lob byte[]`, written via `.getBytes(UTF-8)` —
  **no** Base64, compression, or encryption.
- **Today the body is plain text.** Rich-text/HTML storage (a separate `html_body`
  column) is planned under **EP-13100** and is not yet implemented. So markup
  false-positives are not a current concern.
- There is no separate plain-text copy of the body.

## Design

### 1. Server — one DAO-level interception (universal)

In `MessageDao.processQueryFilter`, when the incoming filter is `subject` + `LIKE`,
expand it to `LIKE subject OR LIKE body` using the same search term.

Because this lives at the DAO layer, **every** message list that routes a subject
filter through `MessageDao` (inbox, sent, drafts, and any other list with the
filter) inherits body search automatically — no per-screen wiring. This honours the
ticket's "use the same filter as for subject."

```java
} else if (Message.PROPERTY_NAME_SUBJECT.equals(filter.getFieldName())
        && QueryFilter.LIKE_FILTER_TYPE.equals(filter.getType())) {
    for (String value : filter.getFilterValues()) {
        String pattern = '%' + value + '%';
        Predicate subjectPredicate = criteriaBuilder.like(
                from.get(Message.PROPERTY_NAME_SUBJECT).as(String.class), pattern);
        Predicate bodyPredicate = criteriaBuilder.like(
                from.get(Message.PROPERTY_NAME_BODY).as(String.class), pattern);
        result.add(criteriaBuilder.or(subjectPredicate, bodyPredicate));
    }
}
```

### 2. Client — inbox read-status fix

`changeFilterBySubjectAndUnreadMessages` no longer restricts search to read messages
and no longer forces empty results when a term is combined with "show unread":

- term, checkbox **off** → search **all** messages (read + unread)
- term, checkbox **on** → search **within unread**
- the "show unread" checkbox stays inbox-only (sent/drafts have no read-by-me state).

### 3. Scope

Body search applies wherever the subject filter exists: inbox, sent, drafts, and any
other message list with the filter — satisfied automatically by the DAO-level change.

### 4. Future — EP-13100

When `html_body` is added, extend the server OR to
`subject OR body OR html_body`. Single, localised change at the same spot.

## Column types (confirmed)

From `publicERANET-server/src/main/sql/db.changelog-1.0.xml` (changeSet
`tabulky_pre_spravy`): `subject` is `VARCHAR(255)`, `body` is `BLOB`.

A `VARCHAR` `LIKE` is case-insensitive via collation; a `BLOB` `LIKE` is
case-*sensitive* (binary). To keep subject and body search consistent, both sides are
wrapped in `criteriaBuilder.lower(...)` with a lower-cased pattern — the established
pattern in `ProcurementDao` (lines 367/383/390). CLAUDE.md rule #7 (follow existing
patterns).

## Case-sensitivity — root cause and resolution

Confirmed by test: body search was case-*sensitive*. Root cause: `body` is a `BLOB`,
which has no collation, and MySQL `LOWER()` is a no-op on binary data — so
`LOWER(body)` returned the bytes unchanged. EclipseLink's `.as(String.class)` is a
Java-side type coercion and does not emit a real SQL `CAST`.

**Fix:** convert `message.body` `BLOB → LONGTEXT` (it only ever holds plain UTF-8 text;
attachments are stored separately in `attachment_ids` + the File subsystem). A
researcher pass over all ~85 `setBody`/`getBody` call sites confirmed no binary content
is ever stored and the `@Lob byte[]` mapping keeps working over `LONGTEXT` unchanged.
Once the column is `LONGTEXT`, the already-committed `lower(...)` predicate becomes
effective and search is case-insensitive.

Liquibase: `src/main/sql/2.11.0/db.changelog-EP13114.xml` (author `m.bijalko`),
registered in the master changelog. Uses an explicit
`ALTER TABLE message MODIFY body LONGTEXT CHARACTER SET utf8mb4` (with a rollback to
`BLOB`) rather than `modifyDataType`, so the charset is pinned: `BLOB → TEXT` relabels
the existing bytes without transcoding, so the target must be UTF-8 for the stored
Slovak text to read back correctly **regardless of the table's default charset** — safe
for test and production without needing to know their current charset.

## Resolution of the unread-filter report

"Unread messages never show when searching" was a **stale browser cache** — the old
client bundle still applied the previous `readDatetime = notNull` (read-only)
restriction on search. The current client source removes it. Confirmed working after a
hard refresh. No code change needed beyond the committed client fix.

## Remaining before "done"

- **Apply the migration** (deploy → Liquibase runs) and retest case-insensitive body
  search (e.g. search `faktura`, body contains `Faktúra`). Charset is pinned to
  utf8mb4 in the changeset, so this is safe in test and production without knowing the
  current table charset.
- Smoke matrix: term in body only / subject only / both; mixed case; inbox and sent.

## Implementation status

Implemented and committed (local only, branch `seas-test`):

- `publicERANET-server` `6ecb5c530` — `feat(EP-13104, EP-13114): search message body in addition to subject`
- `publicERANET-server` `741a85e51` — `fix(EP-13104, EP-13114): make subject/body search case-insensitive`
- `publicERANET-client` `b7e76dd3d` — `feat(EP-13104, EP-13114): search messages regardless of read status`
