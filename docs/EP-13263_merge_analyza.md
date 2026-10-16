# EP-13263 — Merge úprav na trnavavuc-test (Externé požiadavky CPS/OvZP) — 1. dávka

**Story:** EP-13263 · **Dev:** EP-13264 · **Test:** EP-13265 · **Epic:** EP-13256
**Vstupná analýza:** [EP-13257](https://innovis.atlassian.net/browse/EP-13257) — [`EP-13257_externe_poziadavky_rozdiely.xlsx`](EP-13257_externe_poziadavky_rozdiely.xlsx)
**Zdroj (source of truth):** `origin/poseidon-test` · **Cieľ:** `trnavavuc_test` (server + client)
**Pracovná vetva:** `feature/ttsk-merge-cps` (oba repozitáre) · **Stav k:** 17. 7. 2026

**Rozsah 1. dávky:** EP-11784, EP-11786, EP-11787 (ZFK → FK) a EP-11295 (rola pozorovateľa).
Ďalšie tickety z analýzy prídu v nasledujúcich dávkach — zoznam v časti 5.

---

## 1. Merge vetiev nie je možný — ide o ručný port

Podľa analýzy EP-13257 je spoločný predok `trnavavuc_test` a `poseidon-test` z **februára 2023** (server `de5d6a30f`, client `560c79794`). `git merge` by pritiahol \~3,5 roka zmien inej inštancie.

Port sa preto robí **cherry-pickom jednotlivých pôvodných commitov** (`git cherry-pick -x`), aby zostala zachovaná ich história — pôvodná správa, autor aj dátum, plus odkaz na zdrojový hash. Len to, čo pôvodný commit nemá (alebo sa nedá prevziať), ide pod `feat|fix(EP-13263, EP-13264)`.

### Ako to dopadlo

| Repo | Commit | Ticket | Konflikt |
|---|---|---|---|
| server | `be1d30035` ← `a5de872e0` | EP-11295 | bez konfliktu |
| server | `c032811aa` ← `d73e42851` | EP-11295 | bez konfliktu |
| server | `2f36b724d` ← `3bbbdf547` | EP-11787 | bez konfliktu |
| server | `b2470495f` ← `dc1bd1d26` | EP-11787 | bez konfliktu |
| client | `d7d6b174a` ← `8ebc755f6` | EP-11784 | bez konfliktu |
| client | `5780ee24f` ← `52ff04805` | EP-11786 | **konflikt** (langs + controller) |
| client | `7f57cfac6` ← `44e33b908` | EP-11787 | **konflikt** (html) |
| client | `75be37b7c` ← `7cbf4ff51` | EP-11787 | bez konfliktu |
| client | `9beccbfd4` ← `cf1abcac5` | EP-11787 | bez konfliktu |
| client | `390769644` | **EP-13263** | pozorovateľ — pôvodný commit nekompatibilný |
| client | `c788013e1` | **EP-13263** | kľúče e-zmlúv — pôvodný commit neexistuje |

`7cbf4ff51` (skryje tlačidlo) a `cf1abcac5` (odkryje) sú preberané **oba** — výsledok je viditeľný stav (2.7.1) a história zostáva úplná.

**Riešenie konfliktov:**
- `52ff04805` / langs — prevzatá len nová hodnota `EXT_REQ_ZFK_APPROVAL_INFO`. Kľúče `REQUEST_FOR_SECURING_VO`, `ANNUAL_PLAN_REQUEST(S)` z protistrany **neprevzaté** — patria iným ticketom/inštancii.
- `52ff04805` / `editExternalRequestBase.js` — ponechaná lokálna signatúra `$scope.confirm = function ()`, odstránená len validácia `help.approvalOption`. Protistrana má `function (observersForNotificationList)` z EP-11620/EP-11296, ktoré na `trnavavuc_test` nie sú (premenná `observersForNotification` tu neexistuje).
- `44e33b908` / `editExternalRequestBase.html` — prevzatý dropdown protistrany. Na zdroji nahrádzal **zakomentované** ZFK tlačidlo (EP-11736), na `trnavavuc_test` nahradil **živé** tlačidlo; podmienka `data-ng-show` je v oboch zhodná.

⚠️ **Na overenie pri teste:** dropdown z `44e33b908` používa `<a href='#'>` a `<b class='caret'>` bez ikon, kým susedný dropdown na tej istej obrazovke (`generateExternalRequestBasePdf`, \~riadok 730) používa `data-ng-click` bez `href` a ikony `fa fa-file-pdf-o`. Dva dropdowny vedľa seba teda vyzerajú odlišne a `href='#'` môže v hash routingu preskočiť na začiatok stránky. Ak bude prekážať, úprava pôjde ako samostatný commit pod EP-13263.

---

## 2. Vzťah `psk-test` → `poseidon-test` (kľúčové pre pochopenie rozsahu)

Všetky štyri story **vznikli na `psk-test`** (release `psk-2.7.0` / `psk-2.7.1`) a `poseidon-test` ich obsahuje. `poseidon-test` je však **`psk-test` + neskoršie tickety**, ktoré zasahujú do **toho istého kódu**.

Preto platí: **port 1. dávky = stav `poseidon-test` mínus neskoršie tickety.** To je zámer — nie nedostatok.

Overené na metóde `generateFKprotocol` (server): každý rozdiel medzi `poseidon-test` a portom 1. dávky patrí neskoršiemu ticketu a zodpovedá markeru z tabuľky v EP-13257:

| `poseidon-test` má | 1. dávka má | Ticket | Marker v EP-13257 |
|---|---|---|---|
| `externalRequestTypeResolver.resolveTypeName(...)` | pôvodný `codebookService.translate(...)` | EP-12640 | `ExternalRequestTypeCps` |
| názvy pozícií zo `SettingExternalRequestAgreementOrder` | 4 napevno zadané názvy pozícií | EP-12670 | `SettingExternalRequestAgreementOrder` |
| vetvy pre stav `ConditionallyConfirmed` | — | EP-12667 | `ZfkConditionalApproval` |
| vykreslenie `decisionComment` (odôvodnenie) | — | EP-12673, EP-12674 | `ZfkMandatoryDecisionComment` |

---

## 3. Čo sa v 1. dávke portuje

### ZFK → FK (EP-11784, EP-11786, EP-11787) — na `trnavavuc_test` chýbalo celé

**Bez Liquibase a SQL** — riziko migrácie nulové.

| Ticket | Strana | Súbor | Zmena |
|---|---|---|---|
| EP-11787 | server | `service/pdf/ExternalRequestBasePdfGeneratingService.java` | nový `@GET @Path("/{id}/fk")` `generateFKprotocol(...)`; fixná veta „S finančnou operáciou alebo jej časťou súhlasím.“; stará metóda premenovaná `generateInternalRequestSecureProcurement` → `generateZFKprotocol` (path `/zfk` bez zmeny) |
| EP-11784 | client | `langs/sk.js`, `langs/en.js` | 13 prekladových **hodnôt** ZFK → FK (kľúče nezmenené) |
| EP-11786 | client | `langs/*`, `controllers/planningExternal/editExternalRequestBase.js`, `views/planningExternal/editExternalRequestBase.html` | `BOOLEAN_NOT_ACCEPT` = „Nesúhlasím“, `EXT_REQ_ZFK_APPROVAL_INFO` = „S finančnou operáciou alebo jej časťou:“; tlačidlá `BOOLEAN_YES/NO` → `BOOLEAN_ACCEPT/BOOLEAN_NOT_ACCEPT`; zrušený výber z 3 možností (`zfkApprovalOptions`) a validácie `help.approvalOption` |
| EP-11787 | client | `service/resources/externalRequestBasePdfGenerating.js`, `editExternalRequestBase.js`, `editExternalRequestBase.html` | resource `generateFkProtocolPdf` → `GET .../externalRequestBasePdfGenerating/{id}/fk`; `uib-dropdown` s dvoma protokolmi |

**Prečo dva protokoly (a nie len premenovanie):** protokol je právny záznam o už vykonanom rozhodnutí. Finančná operácia z r. 2025 musí zostať zdokumentovaná podľa starého znenia a s možnosťou, ktorú schvaľovateľ vtedy vybral (`confirmanceOption`). Preto **„do 31.12.2025“** (starý, `/zfk`, bez zmeny) a **„od 01.01.2026“** (nový, `/fk`, fixná veta) existujú súbežne.

**Viditeľnosť FK tlačidla:** na PSK bolo BE nasadené v `psk-2.7.0` so **skrytým** tlačidlom, odkryté v `psk-2.7.1`. Keďže 1. 1. 2026 už uplynul, na `trnavavuc_test` ide **viditeľný stav** — dropdown ponúka obe možnosti.

**Názov prílohy:** oba protokoly sa ukladajú ako `Požiadavka_<uniqCode>.pdf` — **zhodne s `poseidon-test`** (overené), ponechané tak zámerne.

### EP-11295 (rola pozorovateľa) — \~90 % už na `trnavavuc_test`

Funkcionalita tu už raz bola (z MINZP, EP-7361) a bola **zámerne skrytá** ticketom EP-7922. Preto sa portuje len zvyšok:

1. `views/companyProfile/externalRequestSettings.html` — odkomentovaný blok „Správa pozorovateľov“ (bol v `<!-- Pre externe poziadavky zfk nefunguje pozorovatel spravne, EP-7922 -->`).
2. `controllers/companyProfile/externalRequestSettings.js` — doplnený `$scope.deleteRequestObserver` (vzor: `internalRequestSettings.js`).
3. `service/ExternalRequestService.java` — jednoriadková oprava, aby schvaľovateľ, ktorý je zároveň pozorovateľ, mohol požiadavku potvrdiť.

Už existuje (neportovať): DTO/DAO/Service `SystemUserAsObserverInExternalRequestInOrganizationDirectory*`, tabuľka, client resource, rola `USER_ROLE_EXTERNAL_REQUEST_OBSERVER`, prekladové kľúče aj samotné UI markup.

---

## 4. Otvorené riziká 1. dávky

### 4.1 EP-7922 — odkrývame to, čo bolo zámerne skryté ⚠️

**EP-7922 – „TTSK (externé požiadavky) – Pozorovatelia nie sú potrební“** (nahlásené na TRNAVAVUC-TEST, DONE 22. 10. 2024, epic EP-7691):

> „Túto časť je potrebné skryť, bola riešená pre minzp a **tu nefunguje úplne správne**.“

Konkrétny defekt **nikde nie je zapísaný** (analytická story EP-11791 v epicu EP-11785 je DONE, ale jej popis je prázdna šablóna). Rovnakú obavu uviedol Marcel Žec na EP-11295 (11. 12. 2025): kým nie je spísané, čo pozorovateľ smie a nesmie, pri merge z inej vetvy sa nedá overiť, či funguje.

Na `poseidon-test` boli neskôr opravené práve chyby oprávnení pozorovateľa (EP-12971, EP-12972, EP-12889 — viď časť 5). **V 1. dávke tieto opravy nie sú**, preto sekcia „Správa pozorovateľov“ vyžaduje **cielené pretestovanie**.

### 4.2 `confirmanceOption` pri požiadavkách rozdelených nasadením ⚠️

Starý `/zfk` protokol vypisuje uloženú možnosť schvaľovateľa (`confirmationStep.getConfirmanceOption()`). EP-11786 ruší výber 3 možností **naraz pre všetky požiadavky**, takže po nasadení sa `confirmanceOption` už neukladá.

Dôsledok pre požiadavku rozdelenú nasadením:

| | Kedy | Starý proces? | `confirmanceOption` |
|---|---|---|---|
| Schvaľovateľ 1 | jún 2026 | áno | ✅ uložená |
| Schvaľovateľ 2 | jún 2026 | áno | ✅ uložená |
| **nasadenie** | júl 2026 | — | — |
| Schvaľovateľ 3 | júl 2026 | nie (už FK) | ❌ žiadna |

Pri tlači protokolu **„do 31.12.2025“** sa pri schvaľovateľovi 3 nevypíše nič — bez chyby, bez varovania (kód má `if (confirmanceOption != null)`).

Na PSK to nevadilo (nasadzovali presne k 1. 1. 2026). **TTSK nasadzuje \~6 mesiacov po prechode**, a stále beží starý proces — požiadavky rozpracované cez nasadenie teda reálne existujú. Na `poseidon-test` je pre `null` doplnený medzerový placeholder (drží layout tabuľky), ale ten je viazaný na `ConditionallyConfirmed` z EP-12667 a **problém nerieši** — chýbajúcu vetu nedoplní.

**Rozhodnutie:** akceptované — protokol sa mení, to je zmyslom novely. Ponechané ako na `poseidon-test`, bez vetvenia navyše. Ak sa pri teste ukáže, že rozpracované ZFK požiadavky reálne prekážajú, rieši sa samostatne.

### 4.3 Premenovanie ZFK → FK zasahuje aj do modulu e-zmluvy ⚠️

Dva z 13 premenovaných kľúčov nie sú napriek prefixu `EXTERNAL_REQUEST_` len pre externé požiadavky:

| Kľúč | Používa aj |
|---|---|
| `EXTERNAL_REQUEST_BASIC_FINANCIAL_CONTROL` | `views/econtracts/econtractsOverview.html:32`, `econtractZfkDialog.html:2`, `zfkSettingsDialog.html:2`, `scripts/service/codebookGenerator.js:4271` (názov `ECONTRACT_ACTIVITY_ZFK` v **logu aktivít e-zmluvy**) |
| `EXTERNAL_REQUEST_EXECUTE_ZFK` | `views/econtracts/editEcontract.html:1255` |

Vlastné ZFK kľúče e-zmlúv zostávajú nezmenené (`ZFK_EXECUTORS` = „Vykonávajúci ZFK“, `MOVE_ZFK` = „Presunúť proces ZFK“, `ECONTRACT_START_ZFK_USERS_WARNING`). Na jednej obrazovke tak vznikne zmiešané názvoslovie a **historické záznamy v logu aktivít sa spätne prepíšu** zo ZFK na FK.

Týka sa to špeciálne TTSK — tu je celá epika „ZFK v e-zmluvách“ (EP-9030–EP-9431), ktorú PSK/poseidon v tejto podobe nemá. Rozsah EP-11784 je pritom výslovne **modul Požiadavky CPS**.

**Rozhodnutie:** e-zmluvy **zostávajú na ZFK**. Doplnené vlastné kľúče `ECONTRACT_BASIC_FINANCIAL_CONTROL` („Základná finančná kontrola“) a `ECONTRACT_EXECUTE_ZFK` („Vykonať ZFK“), na ktoré je prepnutých všetkých 5 volaní v module e-zmlúv (commit `c788013e1`). Premenované kľúče `EXTERNAL_REQUEST_*` tak používajú už len externé požiadavky.

Overené: `poseidon-test` funkcionalitu ZFK v e-zmluvách **vôbec nemá** (`econtractZfkDialog.html`, `zfkSettingsDialog.html`, `econtractZfkDialog.js` tam neexistujú), takže zdrojová vetva k tomuto nedáva žiadne vodidlo — ide o rozhodnutie špecifické pre TTSK.

---

## 5. Ďalšie dávky — čo z analýzy ešte chýba

Zoznam vychádza z analýzy EP-13257 (komentár + xlsx). **Zoradené podľa nadväznosti na 1. dávku.**

### 5.1 Priamo nadväzuje na FK proces (dokončí zhodu s poseidon)

| Ticket | Typ | Popis | Marker v kóde |
|---|---|---|---|
| EP-12667 (+ EP-12816) | Story | Nový stav požiadavky — Podmienečne súhlasím | `ZfkConditionalApproval` |
| EP-12673 (+ EP-12674) | Story | Povinný komentár pri zamietnutí / podmienečnom súhlase | `ZfkMandatoryDecisionComment` |
| EP-12670 | Story | Názvy pozícií do nastavení systému | `SettingExternalRequestAgreementOrder` |
| EP-12640 (+ EP-12806) | Story | Druhy požiadavky — samostatný číselník | `ExternalRequestTypeCps` |

### 5.2 Priamo nadväzuje na pozorovateľa (opravy oprávnení — viď riziko 4.1)

| Ticket | Typ | Popis | Poznámka |
|---|---|---|---|
| EP-12971 | Chyba | Pozorovateľ má práva zodpovednej osoby | pravdepodobne rieši to, na čo sa sťažoval EP-7922 |
| EP-12972 | Chyba | Používateľ nevidí svoje požiadavky, ak má právomoc pozorovateľa na iný druh | |
| EP-12889 | Story | Oprava právomocí [BUG] + zobrazenie požiadaviek pre pozorovateľa | |
| EP-12652 | Story | Radenie prístupov — zodpovedná osoba / pozorovateľ podľa druhu a OvZP | **závisí od EP-12640** |
| EP-13049 | Story | Pozorovateľ / zodpovedná osoba — skrytie nastavenia podľa druhu | **závisí od EP-12640** |
| EP-11296, EP-11620 | Story | Notifikácia na pozorovateľa pri schválení; výber pozorovateľa pre notifikáciu | |

### 5.3 Ostatné z analýzy (bez väzby na 1. dávku)

**EP-11645 – PSK_Externé požiadavky:** EP-11286, EP-11288, EP-11289, EP-11294, EP-11305, EP-11309, EP-11320, EP-11593, EP-11715, EP-11723 (+ EP-11724, EP-11756), EP-11757, EP-11763, EP-11821
**EP-11736 – skrytie protokolu:** EP-11737, EP-11752
**EP-12353 – EES zmenové požiadavky:** EP-12774, EP-12807, EP-12811, EP-12817, EP-12846, EP-12890, EP-12891, EP-12908
**EP-12792 – Termín spracovania:** EP-12793, EP-12794, EP-12809, EP-12848, EP-12852 (`processingDeadline`)
**EP-12818 – premenovania stavov + tlačidiel:** EP-12819, EP-12847
**EP-12821 – stornovanie požiadavky:** EP-12822
**EP-12538 – zjednocovanie verzií:** EP-13026, EP-13028, EP-13047
**Samostatné:** EP-9306, EP-10963/EP-10964, EP-11775

---

## 6. Čo neportovať (blokery)

**Liquibase — duplicitný changeset.** Tabuľku `system_user_as_observer_in_er_in_organization_directory` vytvárajú obe vetvy, schéma je zhodná, líšia sa len `id` a `author`:

| Vetva | Súbor | changeSet id | author |
|---|---|---|---|
| `trnavavuc_test` | `src/main/sql/2.4.0/db.changelog-EP7361.xml` | `pridany_pozorovatel_pre_externe_poziadavky` | `m.bijalko` |
| zdroj | `src/main/sql/2.6.0/db.changelog-EP7361.xml` | `create_system_user_as_observer_in_er_in_organization_directory_table` | `m.zec` |

Port `2.6.0/db.changelog-EP7361.xml` by Liquibase vyhodnotil ako nový changeset a pokúsil sa vytvoriť **existujúcu tabuľku** → **pád deploymentu**. Schéma sa nelíši, takže niet čo dopĺňať.

**`editAdminUser.js` neportovať.** Zdroj používa boolean resolves (`isExternalRequestObserver`…), `trnavavuc_test` jeden resolve `userRole` pre **9 rolí pozorovateľa**. Port by rozbil obrazovky pre interné požiadavky, ročný plán, prevádzkové požiadavky, bežný rozpočet, e-zmluvy a e-dokumenty.

**Ďalšie mimo rozsahu:** server `9127037c4` (triedy už existujú), `49a0e89cf` (zrušený `a67f391d3`), merge commity (miešajú EP-11296/11620/11757); client `3e4a64043`, `9ad432009`. Vetva `feature/trnavavuc_zfk_econtracts` je stale (0 ahead) a patrí inej epike (EP-9030–EP-9431).

---

## 7. Testovanie (EP-13265)

- **Oba protokoly** — „do 31.12.2025“ (pôvodný) aj „od 01.01.2026“ (nový: veta „Finančná kontrola…“ + „S finančnou operáciou alebo jej časťou súhlasím.“).
- **Proces FK** — tlačidlá Súhlasím / Nesúhlasím namiesto troch možností.
- **Rozpracované ZFK požiadavky** — overiť riziko 4.2 (požiadavka rozdelená nasadením).
- **Správa pozorovateľov** — cielene, reverzuje sa EP-7922 (pridanie, úprava, odstránenie, viac OZ, prístup len Superadmin).
- **Schvaľovateľ, ktorý je zároveň pozorovateľ** — musí vedieť potvrdiť požiadavku.
- **Modul e-zmluvy** — riziko 4.3 (zmiešané názvoslovie ZFK/FK, log aktivít).
- **Ostatné obrazovky pozorovateľov** (interné požiadavky, ročný plán, prevádzkové požiadavky, bežný rozpočet, e-zmluvy, e-dokumenty) — regresne, kvôli zdieľanému `userRole` resolve.

---

## 8. 2. dávka — prepínačmi riadené tickety (EP-11296, EP-11309)

Rozhodovacia analýza „je tam prepínač?“ pre epiku EP-11645 je v [`EP-13263_merge_rozhodnutia.xlsx`](EP-13263_merge_rozhodnutia.xlsx) (stĺpec „Mergovat do ttsk?“). Pravidlo: **portovať len ticket, ktorého správanie je za prepínačom, ktorý sa dá nechať vypnutý** a zachovať tak súčasné správanie TTSK. Bez prepínača → neportovať.

**Portované (majú prepínač, nasadené OFF):**
- **EP-11309** — `Setting ExternalRequestInstructionsForApproval`: editovateľné upozornenie (červený text) v detaile schvaľovania externej požiadavky, zobrazí sa len pri neprázdnej hodnote. **Seed prázdny** → defaultne skryté.
- **EP-11296** — `Setting ExternalRequestConfirmationNotificationToObservers`: notifikácia pozorovateľom pri potvrdení požiadavky. **Seed `false`** → defaultne len autor. Filter pozorovateľov je **verný port** (porovnáva id riadku pozorovateľa s id autora — id-space quirk, možná dvojitá notifikácia autora-pozorovateľa; ponechané s jednoriadkovým markerom, opraví sa tu aj na `poseidon-test`). Text emailu **ostáva TTSK** — Prešovský text z EP-11593 sa neportuje.

**Neportované (bez prepínača):** EP-11286, EP-11289, EP-11294, EP-11320 (+ `@NotNull`/FK), EP-11593, EP-11723. **Podmienené/odložené:** EP-11288 (konfiguračný JSON engine, fail-closed), EP-11305, EP-11620.

**Postup portu:** vždy `cherry-pick -x` pôvodného commitu + konflikty; `feat(EP-13263, EP-13264)` len na nutnú TTSK zmenu navyše (prepnutie seedov na OFF). Plán: [`plans/EP-13263-batch2-externe-poziadavky.md`](plans/EP-13263-batch2-externe-poziadavky.md).

**Commity (vetva `feature/ttsk-merge-cps`, lokálne, nepushnuté):**

| Repo | Commit | Ticket |
|---|---|---|
| server | `f0cc3bc1b` ← `4144b7c3c` | EP-11309 (pôvodný) |
| server | `a60eef890` ← `1a4be5650` | EP-11296 (pôvodný) |
| server | `c8762b7a3` ← `1fc549834` | EP-11296 (pôvodný, konflikt: bez EP-11593 textu a duplicitného EJB) |
| server | `966052963` | EP-13263 — seed EP-11309 prázdny (OFF) |
| server | `188646fa9` | EP-13263 — seed EP-11296 `false` (OFF) |
| client | `80e7bb4a9` ← `a91236fe5` | EP-11309 (pôvodný; doplnený chýbajúci `</div>`) |
| client | `d37efc959` ← `2b1389610` | EP-11296 (pôvodný) |

Server builduje (JDK 8, `mvn clean package` → WAR). **Na overenie v appke:** OFF stav (žiadna zmena oproti dnešku — bez červeného upozornenia, notifikácia len autorovi); po zapnutí prepínačov sa upozornenie zobrazí / pozorovatelia dostanú notifikáciu.
