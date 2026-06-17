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

## Engineering verification (before "done") — STILL OPEN

- **Runtime smoke test required.** `LOWER()` applied to a MySQL `BLOB` is a no-op on
  binary strings unless the value is first converted to a non-binary charset. Whether
  EclipseLink's `.as(String.class)` emits a `CAST(body AS CHAR)` (which would make
  `LOWER` effective and the whole `LIKE` work) cannot be verified statically — it must
  be tested against the real MySQL + EclipseLink. If case-insensitive body search does
  not work, the fix is `CONVERT(body USING utf8)` before `LOWER`, or the EP-13100
  plain-text column.
- Smoke test matrix: term in body only / subject only / both; mixed case; with and
  without "show unread"; on inbox and sent lists.
- Server has not yet been compiled in this environment.

## Implementation status

Implemented and committed (local only, branch `seas-test`):

- `publicERANET-server` `6ecb5c530` — `feat(EP-13104, EP-13114): search message body in addition to subject`
- `publicERANET-server` `741a85e51` — `fix(EP-13104, EP-13114): make subject/body search case-insensitive`
- `publicERANET-client` `b7e76dd3d` — `feat(EP-13104, EP-13114): search messages regardless of read status`
