# EP-13189 — Fix false HTTP 403 in `setMyTags` (Design)

**Ticket pair:** Story **EP-13103** ("štítky v komunikácii") · Dev **EP-13189** (message tags role/context logic).
**Commit:** `fix(EP-13103, EP-13189): …` (pair confirmed in `docs/TICKETS.md`).
**Builds on:** the EP-13189 team-visible / role-gated tag model.

## Symptom

```
Failed to execute: javax.ws.rs.WebApplicationException: HTTP 403 Forbidden
  at sk.innovis.eranetpublic.server.service.MessageService.setMyTags(MessageService.java:420)
```

A **responsible person** in a procurement tried to **remove a tag added by another responsible
person** from a message and got a 403. Not reproducible by the developer.

## Root cause

The 403 at `MessageService.java:420` is **not** the role-based tag authorization — it is a false
rejection from the *message lookup* that runs before authorization is reached.

`setMyTags` loads the message via `getEntityById(request.getMessageId())`, which delegates to
`getEntityById(id, null, null)` — i.e. **procurementId = null**. The security-scoped `findAllInternal`
then runs, and its "may see other people's messages" branches
(`isCurrentUserResponsiblePersonInProcurement`, `isCurrentUserObserverInProcurement`, committee/admin)
**all require a procurement filter to be present in the parameters**. With none set, `findAllInternal`
falls into the `else` branch and filters strictly to `MessageToUser.systemUserId = currentUser.id` —
only messages where the caller is a direct sender/recipient/BCC.

So when responsible person **A** acts on a message **B** owns (A sees it only by virtue of the
procurement role, per EP-13189's team-visible tags), the lookup returns nothing → `getEntityById`
returns `null` → **403**, before `reconcileMessageTags` (the correct authorization gate) ever runs.

**Why it didn't reproduce:** it only fires when the acting responsible person is *not themselves a
participant* on that specific message.

### The design mismatch

EP-13189 moved tags to a team-visible, procurement-role-gated model and migrated three things
correctly — `isCurrentUserAllowedToEditTags` / `populateEditableTags` (edit flag by procurement role),
and `reconcileMessageTags` (authorizes by procurement role, any-of link, lets a responsible person
remove *any* tag). But `setMyTags`'s message **fetch** still used the old recipient-scoped visibility.
The UI offers the control and the correct backend gate would allow it — but the lookup in between
rejects the caller first. The lookup was acting as an incorrect second authorization gate.

## Fix

One server method changed, one helper added. **No schema / Liquibase. No client change.**

`MessageService.setMyTags` stops using the recipient-scoped lookup as a gate:

```java
@POST
@Path("/setMyTags")
@RolesAllowed(SystemUserGroup.ROLE_NAME_USER)
public void setMyTags(final MessageTagsUpdateRequest request) {
    if (request == null || request.getMessageId() == null) {
        throw new WebApplicationException(Status.BAD_REQUEST);   // 400 — malformed request
    }
    final Message message = getEntityByIdInternal(request.getMessageId());
    if (message == null) {
        throw new WebApplicationException(Status.NOT_FOUND);     // 404 — no such message
    }
    message.setMessageTags(request.getMessageTags());
    messageTagService.reconcileMessageTags(message);             // 403 here iff not responsible/admin
}
```

Add a named `getEntityByIdInternal(Integer)` to `MessageService` that wraps `super.getEntityById(id)`
(the raw `BaseService` fetch), matching the established `…Internal` pattern across the other services
(e.g. `SystemUserService.getEntityByIdInternal`).

### Why this is safe

- **Single authorization gate.** Authorization now lives in exactly one place —
  `reconcileMessageTags`, which checks procurement-role any-of-link and throws its own 403. The lookup
  only loads the row.
- **Cascade-delete is not wrongly triggered.** `reconcileMessageTags` deletes *all* tag assignments
  when `messageToProcurement` is null/empty (MessageTagService.java:106–110). `messageToProcurement`
  is a `@OneToMany` on `Message`; within `setMyTags`'s container-managed transaction,
  `reconcileMessageTags` reading `getMessageToProcurement()` lazy-loads the real links, so the
  cascade-delete branch only fires for messages that genuinely have no links — the same mechanism the
  `create` / `update` / `sendDraft` paths already rely on.

### Error semantics

| Case | Before | After |
|---|---|---|
| Null / blank request | 403 | **400** Bad Request |
| Message id not found | 403 | **404** Not Found |
| Caller not responsible/admin | 403 (from lookup) | **403** (from `reconcileMessageTags`) |
| Authorized responsible/admin acting on a teammate's message | **403 (bug)** | **succeeds** |

## Scope

`setMyTags` is the **only** endpoint that fed a message through the recipient-scoped lookup before
reconciling. `create` / `update` / `sendDraft` take the message from the request payload (already
carrying its links) and were never affected. No other call site changes. The client already sends the
full team-visible tag set and shows the controls correctly via `canEditMessageTags`; no client change.

## Testing

Backend authorization-path bug, so coverage is primarily server-side:

1. **Reported scenario** — responsible person A removes a tag added by responsible person B on a
   message A does not own → succeeds, tag removed (was 403).
2. **Cascade-delete safety** — responsible person calls `setMyTags` on a message that *has*
   `MessageToProcurement` links, submitting the same set (no-op) → tags **still present** afterward.
   Proves the lazy collection loaded and the cascade-delete branch did not wrongly fire. (Guards the
   catastrophic failure mode.)
3. **Genuine non-authorized user** (commission member) → 403 (now from `reconcileMessageTags`).
4. **Invalid message id** → 404; **null request** → 400.

Client: re-run existing `communicationTags.js` Karma specs to confirm no regression; no changes
expected.

## Work split

- **Backend (`executor-backend`):** add `MessageService.getEntityByIdInternal`; rewrite `setMyTags`
  per above; add/extend server tests for the four cases (esp. cascade-delete safety).
- **Frontend:** none.
