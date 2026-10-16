# EP-13263 — Analýza závislostí zvyšných „To-DO" ticketov (Externé požiadavky)

**Cieľ:** zistiť, ktoré zvyšné tickety z [`EP-13263_merge_rozhodnutia.xlsx`](EP-13263_merge_rozhodnutia.xlsx) sa dajú portovať samostatne a ktoré sú **blokované** kódom z ticketov, ktoré neportujeme (alebo ešte neboli naportované).
**Cieľová vetva:** `feature/ttsk-merge-cps` (= `trnavavuc_test` + dávky 1–3). **Zdroj:** `origin/poseidon-test`. **Stav k:** 24. 7. 2026.

> **PROGRES (lokálne commity, nepushnuté):**
> - ✅ **Vlna 0 hotová** — EP-11821, 12774, 12807, 12817, 12821, 12891, 12908+13047, 12818, 12792(jadro), 13028 (EP-12954 už na targete). Server 18 + client 22 commitov. Build OK.
> - ✅ **Vlna 1 (FK-proces) hotová** — EP-12640 → 12670 → 12667 → 12673. Server 31 + client 57 commitov. Build OK. Nové FK-nastavenia (`ZfkConditionalApproval`, `ZfkMandatoryDecisionComment`) seedované `false` (OFF).
> - ✅ **Vlna 2 hotová** — EP-12652 (RP-scope, server 23 + client 18), EP-12890, EP-13026, EP-12809 (notifikácia termínu). Build OK.
> - ✅ **Vlna 3 hotová** — EP-12811 (delegovanie, server 8 + client 4), EP-12971, EP-13049. Build OK.
> - ✅ **Vlna 4 hotová** — EP-12846 (2), EP-12889 (30, union→dispatcher refaktor). Build OK.
> - ✅ **Vlna 5 hotová** — EP-12972. Build OK.
> - ✅ **EP-11763 client** — portnutá LEN bezpečná `disablePolicy` časť (observer/executor časti zahodené — závisia od vylúčených EP-11620/11288/11305).
> - 🏁 **CELÝ MERGE HOTOVÝ.** Server **115** + client **111** commitov (od batch-2 tipu). Všetko cherry-pick pôvodných commitov + 1 ručný server commit (`isTruthy` helper). Server builduje (JDK 8), žiadne markery, nič nepushnuté.
> - Changeset-autori v `EP12353.xml` (mix `dev`/`m.bijalko`) — ponechané (matchuje poseidon).
> - Flagy na test: pred-existujúci bug `checkIfExecutorEditIsDisabled` (volaná, nedefinovaná — EP-11724 medzera); notifikačné testy (EP-12652/12889) písané proti source štruktúre — prejsť pred spoľahnutím; karma/grunt v prostredí rozbité → unit testy nebežali, treba browser smoke test.

**Kľúčové zistenie:** „zmergovať všetky To-DO jednotlivo" nejde — tickety tvoria **závislostný reťazec**. Väčšina sa ale **dá** portovať, ak sa naportujú aj ich *interné* prerekvizity (FK-proces a RP-viditeľnosť) v správnom poradí. **Naozaj mimo dosahu** sú len 2 tickety (závisia od vylúčených / neanalyzovaných ticketov).

---

## 1. Vlny podľa závislostí (odporúčané poradie portu)

### Vlna 0 — samostatné, bez blokerov (dajú sa hneď, v ľubovoľnom poradí)
| Ticket | S/C | Veľkosť | Pozn. |
|---|---|---|---|
| EP-11821 | 0/1 | malé | rebuild approval chain (clean) |
| EP-12774 | 7/4 | stredné | súvisiaca požiadavka |
| EP-12807 | 0/1 | malé | fix: skryť Uložiť (logout) |
| EP-12817 | 0/1 | triviálne | fix: Enter vytvorí požiadavku |
| EP-12821 | 1/1 | malé | stornovanie požiadavky |
| EP-12891 | 0/5 | malé | mazanie prílohy (aplikovať ako squash) |
| EP-12954 | 1/0 | triviálne | admin mení skupinu používateľa |
| EP-13028 | 1/1 | triviálne | oprava preklepu „príjmateľ" |
| EP-12908 **+** EP-13047 | 3/1 + 0/1 | malé | **portovať spolu** (rovnaké regióny); EP-12908 má Liquibase |
| EP-12818 | 3/1 | malé | EES prepínač `isEES` (seed `false`) + helper `SettingService.isTruthy`; nepodmienené premenovanie ZFK→FK stavov **— potvrdené klientom: portovať celé (rename naživo)** |
| EP-12792 (jadro) | ~5/6 | malé/stred | atribút `processingDeadline`, prepínač `ExternalRequestShowProcessingDeadline` (seed `false`). **Notifikačná časť EP-12809 = blokovaná** (viď nižšie) |

### Vlna 1 — FK-proces (základ, odomkne ďalšie); poradie zamknuté; zdieľaný Liquibase súbor
| Ticket | S/C | Pozn. |
|---|---|---|
| **EP-12640** | 11/21 | *musí byť prvý* — vytvára `db.changelog-EP12353.xml` + tabuľky (`external_request_type_cps`, `setting_external_request_agreement_order`) + `ExternalRequestTypeResolver`. Sub-task EP-12806. |
| EP-12670 | 4/12 | názvy pozícií do nastavení; potrebuje EP-12640 (tabuľka) |
| EP-12667 | 4/12 | stav „Podmienečne súhlasím"; potrebuje EP-12640; **pár s EP-12673** |
| EP-12673 | 12/12 | povinný komentár; potrebuje EP-12640 **a** EP-12667 |

### Vlna 2 — odomkne sa po Vlne 1 / Vlne 0
| Ticket | S/C | Odomkne | Pozn. |
|---|---|---|---|
| EP-12652 | 22/18 | po EP-12640 | radenie prístupov (RP/pozorovateľ scope). Server časť je nezávislá, client potrebuje EP-12640. Základ pre RP-viditeľnosť. |
| EP-12890 | 0/1 | po EP-12670 | max dĺžka názvu pozície (mení súbor vytvorený EP-12670) |
| EP-13026 | 0/1 | po EP-12818 | použiť hodnotu EES nastavenia |
| EP-12792 (notifikácia, EP-12809) | | po EP-12640 | scheduler termínu spracovania — potrebuje `ExternalRequestTypeResolver` z EP-12640 |

### Vlna 3 — po EP-12652
| Ticket | S/C | Pozn. |
|---|---|---|
| EP-12811 | 8/4 | delegovanie požiadaviek; potrebuje RP-scope z EP-12652; pridáva delegate stĺpec |
| EP-12971 | 0/1 | fix: pozorovateľ vidí tlačidlá RP; potrebuje helper `isExternalRequestResponsiblePerson` z EP-12652 |
| EP-13049 (=EP-13050) | 0/1 | gate „Druhy požiadavky" v admin dialógoch podľa CPS; potrebuje admin sekciu z EP-12652 |

### Vlna 4 — po EP-12811 (RP-viditeľnosť union)
| Ticket | S/C | Pozn. |
|---|---|---|
| EP-12846 | 2/0 | fix: OvZP nevidí novú požiadavku; rozširuje union z EP-12811/12812 |
| EP-12889 | ~29/0 | oprava právomocí + viditeľnosť pre pozorovateľa (**veľké**, refaktor union); potrebuje EP-12811/12812 |

### Vlna 5 — po EP-12889
| Ticket | S/C | Pozn. |
|---|---|---|
| EP-12972 | 1/0 | fix: OvZP viditeľnosť; potrebuje union dispatcher z EP-12889/12913 |

---

## 2. Špeciálne prípady

| Ticket | Rozhodnutie | Pozn. |
|---|---|---|
| **EP-13049 / EP-13050** | **NIE hneď — patrí do Vlny 3 (po EP-12652)** | `EP-13050` NIE je samostatný ticket — je to story-číslo **toho istého commitu** `531bf1ed3 feat(EP-13050, EP-13049)`. Gating „Druhy požiadavky" v admin dialógoch závisí od **EP-12652** (ktoré tú sekciu stavia — `emptyScopeHintVisible`, `REQUEST_TYPES_LABEL`, `2e98d5b74`/`18b50b6c2`) + loader z EP-12806/EP-12640. Po EP-12652 to je čistý malý gating commit. *(Pôvodná analýza mylne uviedla „blokované EP-13050".)* |
| **EP-11763 (client časť)** | **odložiť na úplný koniec**, detailný pohľad | odkazuje `confirmWithObserversList` (EP-11620), `requiredAttribute("executor")`/`help.category`/`disablePolicy` kind (EP-11288/11305/11320 — vylúčené). *(server časť EP-11763 už naportovaná)* — pozrieť samostatne, čo z toho dáva na targete zmysel |

---

## 3. Už na targete (nič neportovať)

| Ticket | Stav |
|---|---|
| EP-9306 | prázdny cherry-pick — zmena už je na targete |
| EP-11775 | prázdny cherry-pick — už na targete |
| EP-10963 | dev práca = EP-10964, už zmergované (server `52ad60985`, client `2333fd2bb`) |

## 3b. Už naportované (dávka 3)
EP-11715, EP-11757 (potvrdzovací dialóg), EP-11763 (server časť).

---

## 4. Dôležité poznámky pre port

- **Zdieľaný Liquibase súbor** `2.6.0/db.changelog-EP12353.xml`: vytvára EP-12640, dopĺňajú EP-12667/12670/12673 **a** EP-12652/12811. Server slice týchto ticketov mimo poradia → konflikt. Portovať v poradí ticketov; EP-12640 prvý.
- **Prepínače už seedované `false`** (EP-12792 `ExternalRequestShowProcessingDeadline`, EP-12818 `isEES`) — **netreba nič prepínať**, len prebrať seed. *(Pôvodný predpoklad „prepnúť na FALSE" je zbytočný — už sú FALSE.)*
- **⚠ EP-12818 nesie nepodmienené premenovanie** default stavov ZFK→FK („ZFK prebieha"→„FK prebieha" atď.), ktoré sa aplikuje **bez ohľadu na `isEES`**. Je konzistentné s dávkou 1 (ZFK→FK), ale nech to klient potvrdí.
- **Liquibase author** je v zdrojoch `dev` / `s.kacmarik` / `m.zec`; nové/adaptované changesety → `m.bijalko` (CLAUDE.md).
- **Zdieľané súbory s konfliktami** (bez symbolového blokera): `ExternalRequestBasePdfGeneratingService.java` (EP-12640/12667/12673), `SystemUserGroupType.java` enum-tail (EP-12652), `persistence.xml`/`ApplicationConfig`.
- **Sub-tasky** cestujú s parentom: EP-12806→EP-12640, EP-12816→EP-12667, EP-12653→EP-12652, EP-12812→EP-12811, EP-12913→EP-12889.

---

## 5. Zhrnutie / odporúčanie

- **Hneď portovateľných: 11 ticketov** (Vlna 0) — malé/stredné, bez blokerov, rýchla hodnota.
- **FK-proces (Vlna 1, 4 tickety)** je veľký, ale súdržný a **odomyká** EP-12652, EP-12890, EP-13026 a notifikáciu EP-12792.
- **RP-viditeľnosť (EP-12652 → EP-12811 → EP-12846/12889 → EP-12972)** je druhý reťazec — treba ho celý, aby sadli opravy oprávnení pozorovateľa.
- **Len 2 tickety sú naozaj blokované** vylúčenými/neanalyzovanými ticketmi: **EP-11763 client** (EP-11620/11288/11305/11320) a **EP-13049** (EP-13050).

**Návrh:** začať Vlnou 0 (rýchle nezávislé tickety), potom sa rozhodnúť o Vlne 1 (FK-proces) a RP-viditeľnosti — to sú dva väčšie súvislé bloky, ktoré odomknú takmer všetko ostatné.
