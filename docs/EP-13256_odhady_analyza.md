# EP-13256 — Analýza tiketov pred odhadmi (31. 7. 2026)

Podklad na estimačné stretnutie k epicu [EP-13256](https://innovis.atlassian.net/browse/EP-13256)
*CPSTT / TTSK – úpravy v module Externé požiadavky / eZmluvy / eDokumenty*.

**Rozsah:** deti epicu okrem EP-13268, EP-13269 (neriešia sa teraz), EP-13257 a EP-13263 (Ready for testing)
a okrem prázdnych analytických tiketov EP-13270, EP-13348, EP-13351 (dohodnuté neriešiť).

## Prehľad pripravenosti

| Tiket | Téma | Pripravenosť na odhad |
|---|---|---|
| EP-13267 | eDokumenty – správca cez pravidlá | ⚠️ Dobrá, ale vnútorný rozpor v zadaní |
| EP-13337 | ZFK → FK premenovanie (eZmluvy) | ✅ Kód + preklady; DB dáta bez ZFK (overené v DB) |
| EP-13338 | FK popup + protokol | ⚠️ Chýba scenár „Nesúhlasím" |
| EP-13339 | Perzistentný filter per užívateľ | ✅ Dobrá |
| EP-13340 | Rozšírené vyhľadávanie – eZmluvy | ✅ Dobrá (vzor existuje), chýbajú screenshoty |
| EP-13341 | Rozšírené vyhľadávanie – eDokumenty | ✅ Dobrá |
| EP-13342 | Rozšírené vyhľadávanie – Požiadavky | ⚠️ Nové atribúty – overiť, či dáta existujú |
| EP-13343 | Filter „Aktívny používateľ" | ⚠️ Najdrahší filter (query cez workflow) |
| EP-13344 | Zoradenie „mojich" podľa dátumu priradenia | ✅ Zoradenie je v Jave (dnes `id DESC`); dátum odvodiť z predch. kroku |
| EP-13345 | Telefón vo Vlastníkovi | ✅ Triviálne (stĺpec existuje) |
| EP-13346 | Mailto vo Vlastníkovi | ✅ Jasné (vzor CRZ link) |
| EP-13347 | Notifikácia o komentári vždy | ⚠️ Mechanizmus je na `poseidon-test` — nutný port + DB konfig |
| EP-13349 | Delegovanie – interval platnosti | ⚠️ Dobrá spec, ale ploché stĺpce + veľa čítacích miest |
| EP-13350 | Prehľad delegovania (admin) | ✅ Dobrá |
| EP-13353 | Vyhľadávanie v schvaľovateľoch | ✅ Malé, frontend-only |
| EP-13354 | Pozorovateľ – tlačidlo „Vykonať FK" | ⚠️ Nejasné umiestnenie konfigu + server-side práva |

## Implementačné riziká zistené z kódu

### 1. EP-13337 — kde všade žije „ZFK" (overené vrátane DB)

Tiket predpokladá: *„labely idú z kódu, nový názov sa prejaví aj na historických záznamoch"*.
**Overené — premisa platí.** Rozloženie výskytov:

- klientske preklady: `sk.js` – 22 výskytov, vrátane `ZFK_EXECUTORS` = „Vykonávajúci ZFK"
  (riadok 8 tiketu je prekladová hodnota, nie DB dáta);
- serverové stringy natvrdo v **13 Java súboroch** (`EcontractService`,
  `EcontractDocxGeneratingService` – nadpis protokolu, PDF generátory, `CodebookService`…) —
  premenovanie sa prejaví aj na historických záznamoch, lebo texty sa renderujú z kódu;
- DB dáta: krok schvaľovania má perzistovaný `name` (`econtract_activity_confirmance_step.name`,
  snapshot z konfigu `activity_step_setting.name`, číta ho protokol FK ako pozíciu
  v schvaľovaní — `EcontractDocxGeneratingService:605`). Je to však **voľnotextové pole
  zadávané adminom** (`zfkSettingsDialog.html`), nie systémový label — a **overením v TTSK DB
  sa potvrdilo, že „ZFK" sa v `name` hodnotách nevyskytuje** → žiaden data-update nie je potrebný.

Dôsledky pre odhad:
- premenovanie = klientske preklady + serverové stringy; DB dáta netreba meniť;
- pre istotu pri implementácii spustiť kontrolné query na voľnotextové stĺpce
  (`activity_step_setting.name`, `econtract_activity_confirmance_step.name` LIKE '%ZFK%') —
  keby admin niekedy dopísal „ZFK" do vlastných názvov krokov.

### 2. EP-13344 — súčasné zoradenie preverené: „moje" záznamy idú podľa `id DESC`

**Ako to funguje dnes:** blok „mojich" záznamov navrch sa nerobí v SQL, ale **v Jave,
v pamäti** — `EcontractService.findAllAndSort` (:3732), identická kópia
v `EdocumentService` (:3107):
1. klient posiela sort `id DESC` (`econtractsOverview.js`),
2. server odloží limit/offset, natiahne celý prefiltrovaný zoznam a v cykle vyberie
   záznamy, kde má prihlásený používateľ aktívny krok (stav InCommenting/InApproval/
   ZfkInProgress + aktivita Started + krok Active + `confirmancePersonId == ja`),
3. „môj" blok dá na začiatok, zvyšok za neho, stránkovanie až v pamäti
   (`getByLimitAndOffset`).

„Moje" záznamy sú teda dnes medzi sebou zoradené **podľa `id DESC`** (najnovšia zmluva
hore) — žiadny dátum sa nepoužíva.

Dôsledky pre odhad (**jednoduchšie, než sa zdalo zo zadania**):
- keďže partition + stránkovanie už bežia v Jave nad celým výsledkom, zmena = dopočítať
  dátum priradenia v tom istom cykle a „môj" blok zoradiť vzostupne — žiadny SQL join
  ani DB zmena;
- dátum priradenia odvodiť: krok N>1 = `statusDecisionDatetime` kroku N−1, prvý krok =
  štart aktivity/`creationDatetime`. Nebrať `modificationDatetime` aktívneho kroku —
  stamping je nekonzistentný (`finishCommenting` ho ďalšiemu kroku nastavuje (:457),
  `finishApproval` nie (:493));
- zmenu spraviť 2× — Econtract aj Edocument služba (copy-paste kód).

### 3. EP-13349 — delegovanie sú ploché stĺpce, číta ho ~17+ súborov

Delegovanie žije ako stĺpce na `SystemUser`: `delegate_id`, `delegate_for_external_request_id`,
`delegate_for_annual_plan_id`, `delegate_for_operating_request_id`.

- Interval od/do = +8 dátumových stĺpcov (alebo normalizácia do tabuľky — rozhodnúť pri odhade).
- Delegáta číta ~17+ súborov naprieč službami (ExternalRequest/InternalRequest/OperatingRequest/
  AnnualPlan služby, DAO, PDF generátory) — **každé miesto musí odteraz kontrolovať interval**.
  Riziko vynechania → odporúčanie: centralizovať vyhodnotenie „aktívneho delegáta" do jednej
  metódy v BaseService a všetky čítania viesť cez ňu (zväčšuje rozsah, ale znižuje riziko).
- Overiť mapovanie 4 stĺpcov na 4 moduly z tiketu — hlavne „Požiadavky (zodpovedná osoba)".

### 4. EP-13343 — filter „Aktívny používateľ" je query cez workflow

Aktívna osoba = `confirmance_person` aktuálne čakajúceho kroku aktivity.
Filter v hlavnom zozname = join econtract/edocument → activity → confirmance step
+ logika „ktorý krok je aktuálny". Funkčne OK, odhadovať ako query prácu, nie ako UI pole.

## Pozitívne zistenia z kódu

- **Vzor rozšíreného vyhľadávania existuje** — Zákazky (`PROCUREMENTS_LIST_ADVANCED_FILTER`),
  Firmy, Kvalifikačné žiadosti. EP-13340/41/42 je prenesenie vzoru, nie nový koncept.
- **`telephoneNumber` na `SystemUser` existuje** — EP-13345 je naozaj triviálny.
- Komentárové služby sú per modul (`*CommentService`) — EP-13347 sa dá izolovať na jednu službu.

## Analýza súčasného stavu a návrhy riešenia (watch-out body tiketov)

Rozbor „Zdôraznených vecí" z tiketov, ktoré si vyžadovali pozrieť súčasný stav v kóde
alebo navrhnúť riešenie.

### EP-13347 — súčasný mechanizmus notifikácií (tiketom vyžiadaná analýza)

**Zistenie: mechanizmus existuje, ale nie na našej vetve — je na `poseidon-test`**
(pôvodné tikety EP-12494/EP-12495, fix bcc/cc EP-12494/EP-12503, import fix EP-12892).
Na `trnavavuc_test` nie je nič — send-path je tu bezpodmienečný.

Ako to funguje na `poseidon-test`:

- `SystemUser.notificationsEnabled` (stĺpec `system_user.notifications_enabled`,
  TINYINT(1) NOT NULL DEFAULT 1) — Liquibase `src/main/sql/2.5.0/db.changelog-EP12494.xml`.
- `MessageService.sendEmail()` pred odoslaním volá `filterNotificationsDisabledRecipients()` —
  vyfiltruje to/cc/bcc príjemcov, ktorí majú `notificationsEnabled = false`
  (lookup používateľa podľa e-mailu).
- Množina „vždy posielať" = `isExemptFromNotificationFilter(subject)` — **natvrdo v kóde,
  match na text subjectu**: subject obsahuje „Resetovanie hesla" alebo „Prihlasovacie meno".
- Klient: prepínač v osobnom profile (`app/views/personalProfile/personalProfileBasicInformation.html`).

**Dôsledok pre odhad — story má dve časti:**
1. **Port mechanizmu z `poseidon-test` na `trnavavuc_test`** (server: cherry-pick
   595decba6 + 366fb1cd4 + b9ad70112 vrátane Liquibase changesetu; klient: prepínač
   v profile) — podľa pravidla vždy cherry-pickovať originálne commity.
2. **Rozšírenie podľa tiketu:** pridať komentárovú notifikáciu Požiadaviek do bypass
   množiny + nahradiť subject-matching DB konfigom (AC: zmena bez zásahu do kódu).

**Návrh konfigurácie:** subject-matching je krehký (rozbije sa pri zmene textu subjectu —
komentárová notifikácia má navyše subject s prefixom názvu organizácie). Návrh:
1. zaviesť kódové označenie typu notifikácie (enum/konštanta, napr. `EXTERNAL_REQUEST_COMMENT`,
   `PASSWORD_RESET`, `LOGIN_NAME`) prenášané v `Message`,
2. `Setting` položka (zavedený vzor), napr. `NotificationsAlwaysSend` = CSV typov,
   ktoré obchádzajú globálne vypnutie,
3. `isExemptFromNotificationFilter` prepnúť zo subjectu na typ + konfig — jediná
   centrálna kontrola v send-path zostáva.

### EP-13267 — súčasný stav „Správca eDokumentov" + návrh migrácie

- Dnes: `SystemUser.edocumentManager` (Boolean, stĺpec `edocument_manager`),
  UI checkbox `COMPANY_PROFILE_EDIT_USER_EDOCUMENT_MANAGER` na karte používateľa.
- Príznak sa kontroluje na **~14 miestach v 5 službách**: `EdocumentService` (visibility,
  edit, práva, notifikácie), `EdocumentCommentService`, `EdocumentApprovalSettingsService`,
  `EdocumentCommentingSettingsService`, `SystemUserService` (export „Áno/Nie" + update).
- Nahradenie pravidlami = prepísať všetky tieto kontroly na scope-vyhodnotenie.
  **Scope musí ísť aj do list query (DAO filter)**, nie len do detailových kontrol —
  inak správca so zúženým rozsahom uvidí v zozname cudzie dokumenty.

**Návrh riešenia:**
- Nové tabuľky (Liquibase, author `m.bijalko`): priradenie správcu (user_id) + pravidlá
  (priradenie_id, organization_directory_id NULL, edocument_type_id NULL).
- Centralizovať vyhodnotenie do jednej metódy (napr. v `EdocumentRoleService` /
  BaseService vzor): vráti QueryFilter pre zoznamy + boolean check pre detail;
  všetkých ~14 miest volá túto metódu.
- Migrácia: pre každého `edocument_manager = 1` vytvoriť globálne pravidlo; checkbox z UI
  odstrániť a stĺpec prestať čítať (drop až v neskoršom release — bezpečnejší rollback).
- **Pozor:** reprezentácia „globálneho" pravidla je presne miesto, kde zadanie protirečí
  (prázdne pravidlo = nič nevidí vs. migrácia na „pravidlo bez filtrov = globál").
  Návrh: explicitný wildcard („všetky zložky/druhy" ako NULL s príznakom `all`),
  aby globál pokrýval aj zložky/druhy pridané v budúcnosti. Vyžaduje potvrdenie klienta.

### EP-13339 — návrh uloženia perzistentného filtra

- V kóde neexistuje žiadna per-user perzistencia UI stavu (žiadna user-settings entita).
- Návrh: nová tabuľka `system_user_module_filter` (user_id, module, filter_json,
  unique(user_id, module)) + malý REST endpoint (get/save per modul); klient filter
  aplikuje pri načítaní zoznamu (AC: automatická aplikácia po prihlásení).
- Ukladať ako JSON snapshot hodnôt popupu; pri deserializácii ignorovať neznáme atribúty
  (odolnosť voči budúcim zmenám filtrov). Prázdny filter je platný uložený stav.

### EP-13346 — vzor „CRZ link" potvrdený

- `ECONTRACT_CRZ_LINK` existuje v eZmluvách — režim zobrazenie/editácia sa dá prevziať.
- Pri súbehu s EP-13345 zobrazovací režim ukáže `Meno (email, telefón)`, klikateľný len e-mail.

### EP-13354 — kam patrí konfig + čo overiť

- Zavedený vzor pre konfigy je DB tabuľka `Setting` s pomenovanými položkami
  (`ShowInternalRequestConfirmanceSetting`, `HideApprovalEmail*`, …) — nová položka
  (napr. `ExternalRequestObserverCanPerformZfk`) tam prirodzene zapadne; bez UI v Nastaveniach
  (INSERT skript), pokiaľ klient nechce prepínač v UI — vyjasniť.
- Observer rola existuje (`SystemUserAsObserverInExternalRequestInOrganizationDirectory`);
  ZFK v Externých požiadavkách existuje (`ExternalRequestConfirmanceStep`, PDF generátor).
- **Server-side:** endpoint na spustenie FK musí pri zapnutom konfigu povoliť observera —
  nestačí zobraziť tlačidlo na klientovi.

### EP-13349 — mapovanie delegovaní (overiť pri odhade)

- Stĺpce na `SystemUser`: `delegate_id`, `delegate_for_external_request_id`,
  `delegate_for_annual_plan_id`, `delegate_for_operating_request_id` — 4 stĺpce na 4 moduly
  z tiketu, ale mapovanie na „Interné požiadavky / Požiadavky / Požiadavky (zodpovedná
  osoba) / Ročný plán" nie je z názvov jednoznačné (pozor: `InternalRequest` vs
  `OperatingRequest` vs `ExternalRequest` — slovenské názvy modulov sa líšia per inštancia).
  Pred odhadom potvrdiť, ktorý stĺpec patrí ku ktorému poľu na karte osoby.

## Body na prediskutovanie na stretnutí

1. **EP-13267 — rozpor v zadaní:** tabuľka aj AC 3 hovoria *prázdne pravidlo = správca nevidí nič*,
   ale migračná poznámka hovorí *existujúcich správcov preklopiť na „pravidlo bez filtrov
   (globálny správca)"*. Rozhodnúť sémantiku prázdneho pravidla. Ak migrácia = explicitne vybrať
   všetky zložky/druhy, pozor: **nové zložky/druhy pridané neskôr** už globálny správca neuvidí.
   Doplniť aj: čo presne sú „plné práva" (mazanie? zmena vlastníka?); dopad scope filtra na
   všetky list query v eDokumentoch.
2. **EP-13337 — vyriešené:** história sa premenuje sama (labely idú z kódu, DB dáta „ZFK"
   neobsahujú — overené v DB). K dispozícii musí byť špecifikácia
   `TTSK_upravy_FK_-_eZmluvy.docx` + obrázky.
3. **Konzistencia FK naprieč modulmi:** EP-13337 premenúva len eZmluvy, ale EP-13354 už používa
   „Vykonať FK" v Externých požiadavkách a EP-13342 filtruje „ZF" v Požiadavkách.
   Nemá sa premenovanie týkať aj Externých požiadaviek / Požiadaviek?
4. **EP-13338 — scenár „Nesúhlasím":** fixná veta protokolu je definovaná len pre súhlas.
   Čo sa vypíše do protokolu pri zamietnutí? Čo s historickými protokolmi so starými voľbami?
5. **EP-13342 — nové atribúty:** existujú „Číslo dokladu" a „Príjmy/Výdavky" na entite požiadavky,
   alebo sa musia najprv doplniť (iný odhad)? Z čoho sa derivuje „ZF Áno/Nie"?
6. **EP-13344 — overené v kóde:** schvaľovanie je sekvenčné — pri rozhodnutí kroku sa aktivuje
   vždy len nasledujúci krok (`getStepOnIndex(orderNumber + 1)`), takže „jeden aktívny
   používateľ" platí. Dátum priradenia netreba ukladať — dopočíta sa v existujúcom
   triediacom cykle (viď analýza č. 2).
7. **EP-13347 — mechanizmus je na `poseidon-test`, nie na `trnavavuc_test`:** odhad musí
   zahŕňať port (cherry-pick EP-12494/12495/12503 + Liquibase + klientsky prepínač v profile)
   plus rozšírenie o DB konfig namiesto natvrdo subject-matchingu (viď analýza vyššie).
   A uzavrieť: ignoruje komentárová notifikácia aj osobný prepínač používateľa,
   alebo len globálny default?
8. **EP-13354 — kde žije konfig:** DB-only alebo prepínač v UI Nastavení systému?
   A pozor: nestačí zobraziť tlačidlo — **server musí povoliť akciu FK pre rolu pozorovateľa**
   (endpoint permission), inak deravé alebo nefunkčné.
9. **EP-13339 — snapshot filtra:** uložený filter prežíva zmeny atribútov v budúcnosti —
   ošetriť deserializáciu starého uloženého filtra.
10. **EP-13349/13350:** stav „Naplánované" sa v EP-13349 AC 4 objavuje bez definície —
    definuje ho až EP-13350; odhadovať spolu. Závislosti: EP-13339 → EP-13340/41/42 → EP-13343;
    EP-13349 → EP-13350.
