# Jira Ticket Mapping

**Project key:** `EP` (commit ticket prefix `EP-XXXX`)

This file is the source of truth for the **Story → Dev ticket pairing** used in commits.
Look up the correct pair here **before every code commit**. Referenced from `CLAUDE.md`.

## Commit Rules (quick reference)

- Format: `feat|fix(STORY, DEV): description`
  - **Story ticket first**, **Dev ticket second**.
  - **Never** put the Epic in the first slot.
  - A bug with no parent Story is committed alone: `fix(EP-XXXX): description` (no pair, no row here).
  - A Bug Sub-task under a Story: parent Story first, the bug second; add its row below.
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
| Evaluation: "Aktivity" activity-log section in evaluation detail | EP-13133 | EP-13166 |
| Evaluation: "Schvaľovateľ" (Approver) column in overview + filter + export | EP-13134 | EP-13155 |
| Evaluation: delegation functionality for approver | EP-13135 | EP-13157 |
| Požiadavky IO/VO: rename attribute to "Obsahuje limitované informácie" | EP-13136 | EP-13159 |
| Požiadavky IO/VO: new attribute "Stupeň dôvernosti" | EP-13137 | EP-13161 |
| Zákazky: Interný postup — default §34 participation condition (enabled + pre-filled) | EP-13251 | EP-13252 |
| Požiadavky IO/VO: sequential presentation numbering of attributes ("1. Názov") | EP-13248 | EP-13249 |
| Zákazky: Interný postup — default participation conditions and offer requirement texts | EP-13625 | EP-13626 |
| Požiadavky IO: Core/noncore attribute determined by a five-question form | EP-13601 | EP-13606 |
| Požiadavky IO: Core/noncore form editable only by the author before sending | EP-13602 | EP-13608 |
| Požiadavky IO: Core/noncore form questions and answers in the PDF protocol | EP-13603 | EP-13610 |
| Požiadavky IO: copy of an old request does not take over the manual Core/noncore value (bug) | EP-13601 | EP-13646 |
| Požiadavky IO: copy of a request resets the filled Core/noncore formular (bug) | EP-13602 | EP-13647 |

<!-- Add a row per ticket pair as work arrives. -->

---
*Maintained as new EP tickets are picked up.*
