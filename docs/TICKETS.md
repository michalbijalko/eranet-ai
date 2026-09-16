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
| Analýza rozdielov v module Externé požiadavky OvZP — CPSTT a CP PSK | EP-13257 | EP-13259 |
| Merge úprav na trnavavuc-test — Externé požiadavky OvZP (1. dávka) | EP-13263 | EP-13264 |
| WOPI — oprava otvárania príloh v online editore Office 365 (bug) | EP-13620 | — (bug ticket, bez páru) |

<!-- Add a row per ticket pair as work arrives. -->

**Bug tickets:** a standalone bug ticket (issue type *Chyba*) has no Story→Dev pair — commit with the single ticket, e.g. `fix(EP-13620): description`.

---
*Maintained as new EP tickets are picked up.*
