# EP-13665 — Požiadavky CPS: Rozšírené vyhľadávanie (popup „Rozšírený filter")

**Story:** [EP-13665](https://innovis.atlassian.net/browse/EP-13665) · **Dev:** EP-13666 (Test: EP-13667) · **Epic:** EP-13256
**Nahrádza:** EP-13342 (Obsolete) — tá závisela od perzistentného filtra EP-13339; tento tiket perzistenciu per používateľ nechce.
**Repozitáre / vetvy:** `publicERANET-server` a `publicERANET-client`, obe `trnavavuc_test`. Commit `feat(EP-13665, EP-13666): …` v každom repozitári zvlášť.
**Stav:** návrh schválený v brainstormingu (prístup, server, klient). Čaká na plán a implementáciu.

## 1. Rozsah

Na hlavnej stránke modulu Požiadavky (CPS tabuľka, route `All`) pribudne tlačidlo **Rozšírené vyhľadávanie** s ikonou **„×"** a popup **Rozšírený filter**. Presné požiadavky a 29 akceptačných kritérií sú v tikete; tu sú len rozhodnutia a technické zistenia.

- „Požiadavky" = CPS režim (`EXTERNAL_REQUESTS_CPS`). Non-CPS tabuľka (`externalRequestsTable.html`) sa nemení.
- Tlačidlo je len na route `All`, nie na karte „na schválenie" (`ForConfirmation`).
- Export modul nemá, nerieši sa.
- Existujúce tlačidlo „Vytvoriť" a ikona základného filtra ostávajú bez zmeny.

## 2. Rozhodnutia

| Téma | Rozhodnutie |
|---|---|
| Prenos na server | Existujúce generické `queryFilters` v `POST sc/externalRequest/query` (vzor Zákazky / `ProcurementDao`), nie nový endpoint s DTO. Stránkovanie, zoradenie a viditeľnosť (`visibleForCurrentUser`) ostávajú nedotknuté, čo pokrýva AC 28. |
| Vzťah k základnému filtru | Vzájomne výlučné (tiket): „Použiť" vyčistí základný filter, zmena základného filtra zruší rozšírený. |
| Perzistencia | Služba v pamäti (AngularJS singleton), nie `help.filters`. Prežije návrat z detailu, refresh ju zruší, odchod z modulu ju zruší. |
| Stav (multi-výber) | Číselník `externalRequestStatusCpsFilter` (EES: `...Filter EES`), rovnaký ako stĺpcový filter. Niektoré stavy sú zlúčené (napr. Vybavená = 103 + 203). |
| Dátum „ZFK ukončená" | `MAX(creation_datetime)` schválených krokov (`status` Confirmed alebo ConditionallyConfirmed) požiadavky v stave 202 alebo 203. Žiadny nový zápis ani zmena schémy. |
| Dátum „Vybavená" / „po ZFK" | Existuje aktivita v `external_request_activity` typu 103 / 203. Disjunktné samo od seba (103 patrí CPS/OvZP, 203 ZFK požiadavke). |
| Kolácia / diakritika | Neriešime nad rámec existujúcich filtrov (rozhodnutie používateľa). |

**Overenie dátumu „ZFK ukončená" na teste:** všetkých 17 požiadaviek v stave 202 a všetky 4 v stave 203 majú schválený krok s dátumom.

## 3. Server (`publicERANET-server`)

Nové vlastné `fieldName` v `ExternalRequestDao.getWhere` (existujúce vlastné filtre sú na začiatku metódy, ďalej padá na `BaseDao.getWhere`). Servis a `findAllInternal` sa nemenia.

- **Text — Kód (`uniqCode`), IČO a Názov organizácie, Číslo dokladu EIS (`eisDocumentNumber`):** `LIKE %x%` bez escapovania `%` a `_`, rovnako ako ostatné filtre v aplikácii (žiaden z 127 `like(` v 21 DAO ho nepoužíva; rozhodnutie používateľa, AC 5 sa v tejto časti neimplementuje). Vlastný predikát je potrebný len preto, že filter má vlastné `fieldName` (existujúce `organizationDirectoryIco`/`Name` v DAO sú len čiastočné — pre IČO equal alebo LIKE).
- **Popis (`description`):** obyčajné „obsahuje" ako ostatné texty. „Fulltext, OR medzi slovami" v tikete bola chyba v zadaní (rozhodnutie používateľa); v DB nie je FULLTEXT index.
- **Druh (`type`), Vlastník (`creationAuthorId`), Základná finančná kontrola (`basicFinancialControl`), Stav (`status`):** existujúce generické filtre.
- **Príjmy / Výdavky:** `income` alebo `expenses` (`Double`), interval Od–Do vrátane, 0 povolená. Treba jeden vlastný predikát s from/to, pretože generický `between` s číselnou hodnotou nad `Double` nie je pripravený.
- **Dátum — typ:**
  - Dátum požiadavky: `requestDate` (`TIMESTAMP`).
  - Vybavená: `EXISTS` aktivita typu 103 s `creation_datetime` v intervale.
  - Vybavená po ZFK: `EXISTS` aktivita typu 203 s `creation_datetime` v intervale.
  - ZFK ukončená: poddotaz `MAX(step.creation_datetime)` pre schválené kroky (`isApproved`, `ExternalRequestService.java:2144`), len pre `status IN (202, 203)`, porovnaný s intervalom. Dátum rozhodnutia kroku sa ukladá do `creation_datetime` v `setStepStatus` (`ExternalRequestService.java:740`) a UI ho zobrazuje v „Aktivitách".
  - Vzor `EXISTS` poddotazu: `ExternalRequestDao.buildRetentionDisjunct` (okolo riadku 482-496).
- **Interval:** Od > Do vráti prázdny výsledok bez chyby (prirodzene). Horná hranica dátumu je vrátane, takže sa porovnáva `< začiatok nasledujúceho dňa`.

## 4. Klient (`publicERANET-client`)

- **Tlačidlo a „×":** `views/directives/externalRequestsTableCps.html`. Sekcia s lievikom (`col pull-right`, `width: 5%`, riadky 21-23) je pre text príliš úzka, preto nová sekcia vedľa nej. Vzor: `procurementsList.html:17-29` (`btn btn-primary` + `btn btn-form` s `data-ng-class='{"filter-x-button": …}'`). Trieda `filter-x-button` existuje v `styles/custom.css:739`. „×" je vždy viditeľné: ružové pri aktívnom filtri, sivé pri neaktívnom. Funkciu `showAdvancedFilter` pridať do `ExternalRequestsTableController` (`directives/externalRequestsTable.js`), ktorý zdieľajú obe tabuľky, a tlačidlo zobraziť len v CPS šablóne.
- **Popup:** nový kontrolér a šablóna podľa `procurementAdvancedFilter.js/.html` (`$uibModal.open`, modal-header, riadky `smart-form` s ✖, `ui-select multiple` pre Stav, datepicker `dd.mm.yy`). Pole sumy: len nezáporné, najviac 2 desatinné miesta (obmedzenie vstupu). Predvolené typy: Dátum požiadavky, Príjmy. Vlastník: výber zo všetkých používateľov (existujúci zdroj `allUsers`, doplniť v pláne). Nové script tagy do `index.html`. Pri aktívnom filtri sa popup otvorí predvyplnený aplikovanými hodnotami (kópia, takže „Zrušiť" nič nemení), pri neaktívnom je prázdny — zmena oproti pôvodnému AC 26 po dohode s analytikom (14. 10. 2026), AC 26 v Jira treba upraviť.
- **Preklady:** nové anglické kľúče `EXTERNAL_REQUEST_ADVANCED_FILTER_*` s hodnotami v `scripts.no.min/langs/sk.js` (a `en.js`). Využiť existujúce: `FILTER_FROM`, `FILTER_TO`, `CANCEL`, `SUPPLIERS_ADVANCED_FILTER_USE`, `DEACTIVATE`, `BOOLEAN_YES`/`BOOLEAN_NO`, `EXTERNAL_REQUEST_EIS_DOCUMENT_NUMBER`, `EXTERNAL_REQUEST_INCOME`, `EXTERNAL_REQUEST_EXPENSES`. „Základná finančná kontrola" v takom znení existuje len ako `ECONTRACT_BASIC_FINANCIAL_CONTROL`, takže treba nový kľúč.
- **Aplikovaný filter:** nová služba v pamäti. Odchod z modulu: `$routeChangeStart` na route mimo `/planningExternal` (detail `/planningExternal/editExternalRequest` je pod rovnakým prefixom, `ng.app.js:708-711`).
- **Odoslanie:** `ExternalRequests.loadExternalRequestsInternal` (`service/resources/externalRequests.js:127-150`) pripojí filtre zo služby do `postData.queryFilters`. Pri zmene filtra reset na stranu 1.

## 5. Okrajové prípady a pasce

- **Nula v sume:** `FilterHelper` pri `between` zahadzuje hodnotu `0` (`filterHelper.js:66,70`, `!filter.from`). Rozšírený filter preto nesmie ísť cez toto `between`; musí mať vlastné filtre s `from`/`to` (0 povolená, AC 12).
- **Vyčistenie základného filtra:** programové vyčistenie `help.filters` pri „Použiť" spustí `FILTER_OR_SEARCH_CHANGED` (deep-watch v `search-and-filter.js`), ktoré by rozšírený filter hneď zrušilo. Nastaviť rozšírený filter až po vyčistení alebo použiť príznak.
- **Súvisiaca požiadavka:** v `externalRequestsTable.js:166-170` sa nastavuje `help.filters.uniqCode` a volá `storeFilterAndDoReload()` priamo (nie cez udalosť). Pri aktívnom rozšírenom filtri ho tiež zrušiť (vzájomná výlučnosť).
- **Návrat z detailu:** `reloadRequests(true)` obnovuje základný filter z `WebStorage`. Po „Použiť" je tam uložený prázdny filter, takže rozšírený sa neprebije.
- **Prázdny filter:** „Použiť" bez hodnôt aj „×" zrušia filter. Neaktívny filter = žiadne pole nie je vyplnené. Od/Do bez zvoleného typu použije predvolený typ.
- **Zoznam stavov:** ak by `status` skupiny (napr. `[103, 203]`) neprešli ako pole, treba ich splošťovať ako `handleMultipleStatusesFilter` (`externalRequests.js:90-108`).
- **Požiadavka bez schvaľovacích krokov v stave 202:** `checkConfirmationStateCps` ju prepne na 202 bez kroku, takže nemá dátum „ZFK ukončená" a pri tomto filtri sa nezobrazí. Okrajový prípad, tiket to pokrýva pravidlom „bez zvoleného dátumu sa nezobrazia".

## 6. Testovanie

- Klientsky Karma/Jasmine na modernom Node nebeží (viď `docs/codebase/TESTING.md`), server nemá žiadne testy. Overenie je manuálne v bežiacej aplikácii.
- Pred testom vygenerovať checklist zo skillu `acceptance-test-checklist` z 29 AC. Dôraz na: vzájomnú výlučnosť filtrov, farbu „×", návrat z detailu a refresh, 4 typy dátumu (najmä „Vybavená" vs. „po ZFK"), Od > Do, nulu v sume, viditeľnosť pre vlastníka, pozorovateľa a CPS.
- Dátumové typy overiť proti testovacej DB: 17 požiadaviek v stave 202 a 4 v stave 203.
