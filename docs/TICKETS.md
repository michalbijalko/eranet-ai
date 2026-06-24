# Jira Ticket Mapping

**Project key:** `EP` (commit ticket prefix `EP-XXXX`)

This file is the source of truth for the **Story → Dev ticket pairing** used in commits.
Look up the correct pair here **before every code commit**. Referenced from `CLAUDE.md`.

## Commit Rules (quick reference)

- Format: `feat|fix(STORY, DEV): description`
  - **Story ticket first**, **Dev ticket second**.
  - **Never** put the Epic in the first slot.
- One ticket's work per commit — never mix tickets.
- Simple, human-readable messages — no phase numbers or internal codes.

Example:
```
feat(EP-12688, EP-12689): add contract type enum to procurement form
fix(EP-13001, EP-13002): correct supplier qualification date validation
```

## Story → Dev ticket mapping

| Feature | Story | Dev |
|---|---|---|
| Fulltext search in message body | `EP-13104` | `EP-13114` |
| CKEditor in communication | `EP-13100` | `EP-13108` |
| Tags ("Štítky") in communication | `EP-13103` | `EP-13112` |
| Old-message formatting fix after CKEditor | `EP-13100` | `EP-13187` |
| Supplier view: hide message tags | `EP-13103` | `EP-13188` |
| Message tags: role/context logic | `EP-13103` | `EP-13189` |

<!-- Add a row per ticket pair as work arrives. -->

---
*Maintained as new EP tickets are picked up.*
