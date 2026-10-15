# EP-13665 — Implementačný plán: Požiadavky CPS – Rozšírené vyhľadávanie (popup „Rozšírený filter")

**Story:** [EP-13665](https://innovis.atlassian.net/browse/EP-13665) · **Dev:** EP-13666 (Test: EP-13667) · **Epic:** EP-13256
**Pár v `docs/TICKETS.md`:** riadok 30 (`EP-13665` → `EP-13666`) — už existuje, súbor sa nemení.
**Commit (jeden na repozitár, obe vetvy `trnavavuc_test`):** `feat(EP-13665, EP-13666): add advanced filter to CPS external requests list`
**Záväzný vstup:** schválený návrh `docs/plans/EP-13665-poziadavky-cps-rozsirene-vyhladavanie.md` (rozhodnutia sa nemenia; odchýlky vynútené kódom alebo tiketom sú v sekcii 1) + aktuálna verzia tiketu z Jira.
**Dátum plánu:** 2026-10-14 · **Stav repozitárov pri plánovaní:** server aj klient čisté, vetva `trnavavuc_test`.

> **Stav vstupov.** Text tiketu EP-13665 (sekcie 3.1–3.3, pravidlá a 29 AC) dodal koordinátor z aktuálnej verzie v Jira; plán ho zapracúva. Obrázok (mockup popupu) agent nevie čítať — jeho obsah je známy len z opisu koordinátora (Druh/Vlastník/Stav sú v mockupe nakreslené ako obyčajné polia, **platí text tiketu**). Mapovanie 29 AC na kroky a testy je v sekcii 8.3. Otvorené otázky sú uzavreté alebo majú zapísaný predpoklad (sekcia 10).

---

## 0. Rozsah a čo sa NEMENÍ

- CPS tabuľka (`externalRequestsTableCps.html`), len route `All`. Karta „na schválenie" (`ForConfirmation`) a non-CPS tabuľka (`externalRequestsTable.html`) sa nemenia.
- Žiadna zmena DB schémy, **žiadny Liquibase changeset**, žiadny nový endpoint/DTO/EJB, **žiadna zmena `ApplicationConfig.java`**, `persistence.xml` ani `Gruntfile.js` (skripty sa zbierajú z `index.html` cez usemin, `Gruntfile.js:180-194`).
- Stránkovanie, zoradenie a `visibleForCurrentUser` ostávajú nedotknuté; nové predikáty sa k existujúcim iba **AND-ujú** (zoznam `result` v `getWhere` sa posiela do `criteriaQuery.where(Predicate[])`, `BaseDao.java:128-131`), takže viditeľnosť nemôžu rozšíriť (AC 28).
- Žiadny nový zápis aktivít, export modul nemá (tiket: „modul export nemá").
- Pôvodné tlačidlo „Vytvoriť" a ikona základného filtra zostávajú bez zmeny (AC 29).

## 1. Odchýlky od schváleného návrhu (kód alebo tiket) a opravené odkazy

| # | Zistenie | Dôsledok pre plán |
|---|---|---|
| D1 | Route `All` aj `ForConfirmation` renderujú tú istú šablónu stránky (`yearlyExternalRequestsCollecting.html:25-38`) a v pamäťovej službe by stav prežil prechod medzi kartami (obe sú pod `/planningExternal/`). Tiket rieši len odchod z modulu, nie prepnutie kariet. | Filter sa **uplatňuje len na route `All`** (guard `$routeParams.filter === Constants.EXTERNAL_REQUEST_STATUS_FILTER_ALL`, rovnaký typ podmienky ako `externalRequests.js:141-142`). Inak by na karte „na schválenie" skrytý filter potichu zužoval zoznam bez viditeľného „×". **Predpoklad na potvrdenie** (O4). |
| D2 | `FilterHelper.clearFilters` (`filterHelper.js:174-204`) pri typoch `in`/`between`/`startWith` **nahrádza objekty**, ale `CodebookFilterController`/`ComboFilterController` držia referenciu `$scope.filters = help.filters[name]` (`codebookFilter.js:26-31`) → po náhrade by UI a model rozišli. Navyše lokálny stav direktív (`text`, `help.from/to`) sa modelom neresetuje. | Vyčistenie základného filtra (AC 21) = **reset modelu na mieste** + reset lokálneho stavu direktív podľa precedensu `econtractsOverview.js:155-177` (`angular.element('[data-ng-controller=…]').scope()`), rozšírený o `TextStartWithFilterController` (stĺpec Vlastník). `clearFilters` sa nepoužije. |
| D3 | Vzájomnú výlučnosť netreba riešiť špeciálnym handlerom udalosti: stačí **jedna invariantná kontrola v `reloadRequests`** („ak je nastavený základný filter a platí rozšírený → zruš rozšírený"). Pokrýva písanie do základného filtra (AC 25), „súvisiacu požiadavku" (`externalRequestsTable.js:161-171`, volá `storeFilterAndDoReload` priamo) aj návrat z `WebStorage`. | Menej pohyblivých častí než v návrhu; pasca s `FILTER_OR_SEARCH_CHANGED` po programovom čistení sa rieši tým, že po „Použiť" je základný filter prázdny, takže invariant rozšírený filter nezruší (voliteľne handler-guard na vynechanie zbytočného druhého reloadu). |
| D4 | Návrh hovorí „zdroj `allUsers`" (`editExternalRequestBase.js:74`). Ten sa napĺňa cez `Users.loadUsersForCurrentCompany` (`editExternalRequestBase.js:1684`, `users.js:336`) = len **aktívni, nie externí** používatelia. Tiket: Vlastník = „jedna osoba zo **všetkých** používateľov". | Pre „Vlastník" použiť `Users.loadUsersForCurrentCompanyIncludeExternalAndInactiveUsers` (`users.js:340-342`, precedens `responsiblePersonDialog.js:86`). Uzavreté O6. |
| D5 | V `editExternalRequestBase.html:289` je atribút `data-formatted-only-numeric-input`, ktorý **neexistuje** (skutočná direktíva je `formattedNumericInput`, `formattedNumericInput.js`). Tá navyše limit 2 desatinných miest nevynucuje (`decimalCount` len doplní nuly vo formáte) a písmená v `keypress` nechá prejsť (`:97`). | Pole sumy (AC 12): existujúci globálny `validateString(evt, input, regex)` (`app.js:1845`) s vlastným regexom + `ng-pattern` ako poistka (precedens `editUser.html:20`), model ako **text** (sekcia 6c). Vloženie neplatnej hodnoty: O12. |
| D6 | Dátumové „Do" (oba okraje vrátane, AC 15) prevádza **klient** na exkluzívnu hornú hranicu (začiatok nasledujúceho dňa, DST-bezpečne cez `Date#setDate`). Server porovnáva `>= from` a `< toExclusive`. | Jasný, jednoznačný wire kontrakt (sekcia 2). |
| D7 | **Zmenené po dohode s analytikom (14. 10. 2026): AC 26 sa mení.** Pôvodný text „popup sa vždy otvorí s prázdnymi poľami" nebol používateľsky prívetivý. Platí: pokiaľ je filter aktívny, popup sa otvorí **predvyplnený aplikovanými hodnotami**; pri neaktívnom filtri je prázdny. Služba v pamäti drží *aplikovaný* model (na serverové filtre, „×" a predvyplnenie) a popup dostane jeho **kópiu** (`getForEdit()`), takže „Zrušiť" aplikovaný filter nezmení. | `getForEdit()` namiesto `getEmpty()` v `resolve.filter` (F1, F5). Každé „Použiť" **nahrádza** predošlý filter (nič sa nezlučuje). Prázdne „Použiť" zruší filter, len ak používateľ polia sám vymazal (AC 23). AC 26 v Jira treba upraviť. |
| D8 | Opravené odkazy: deep-watch je v `directives/tableFilters/searchAndFilter.js:53-88` (nie `search-and-filter.js`); `FilterHelper` `between` zahadzuje 0 na `filterHelper.js:66,70,75`; LIKE bez escapovania `BaseDao.java:277-285`. Overené: `ExternalRequestDao.getWhere` `57-153`, `buildRetentionDisjunct` `482-496`, `externalRequestsTable.js:149-155,161-171,405-408`, `externalRequests.js:90-108,127-150`. | — |
| D9 | **„Case-insensitive a bez diakritiky" (AC 5, AC 6):** rieši sa rovnako ako pri existujúcich filtroch — kód nerobí `lower()`/`stripDiacritics`. Výslovné rozhodnutie používateľa: kolácia/diakritika sa nerieši, Docker ani kolácia DB sa neskúmajú. | Plán v kóde nič nezavádza; test T06 len zaznamená, ako filter reaguje. |
| D11 | **Bez escapovania `%` a `_` v LIKE** (AC 5, druhá časť). Žiadny z ostatných filtrov v aplikácii (127 volaní `like(` v 21 DAO triedach) ho nepoužíva; rozhodnutie používateľa: texty idú cez `like(column, "%" + value + "%")` ako inde. | Žiadna konštanta `LIKE_ESCAPE_CHAR`, žiadna metóda `escapeLikeWildcards`; odpadá riziko R2 a dotaz Q6. AC 5 v tikete treba upraviť, aby sa nerozchádzal s kódom. |
| D10 | **Popis požiadavky = obyčajné „obsahuje"** (ako Kód, IČO, Názov a Číslo dokladu). „Fulltext, OR medzi slovami" v tikete (tabuľka 3.2 a AC 6) bola chyba v zadaní — rozhodnutie používateľa. | Žiadne delenie na slová a žiadna metóda `buildAnyWordPredicate`; Popis ide cez `addContainsPredicate`. |

## 2. Kontrakt FE ↔ BE (`POST webresources/sc/externalRequest/query`)

Žiadna zmena URL ani tela; do existujúceho poľa `queryFilters` pribudnú položky. Všetky hodnoty sú v `filterValues` ako **reťazce** (Jackson číslo/boolean skonvertuje, ale klient posiela reťazce explicitne, aby `0` nebola falsy). Prázdna hranica = `"###EMPTY_VALUE###"` (`QueryFilter.java:34`, `Constants.EMPTY_VALUE`). Klient neodosiela filter, ktorý nemá žiadnu hodnotu. Medzi vyplnenými atribútmi platí AND (AC 13).

| Pole v popupe | `fieldName` | `type` | `filterValues` | Spracovanie na serveri |
|---|---|---|---|---|
| Kód | `advancedUniqCode` | `like` | `[text]` | nový predikát, `LIKE %x%` |
| Organizácia – IČO | `advancedOrganizationIco` | `like` | `[text]` | join `organizationDirectory`, `ico`, `LIKE %x%` |
| Organizácia – Názov | `advancedOrganizationName` | `like` | `[text]` | join `organizationDirectory`, `name`, `LIKE %x%` |
| Číslo dokladu | `advancedEisDocumentNumber` | `like` | `[text]` | `eisDocumentNumber`, `LIKE %x%` |
| Popis požiadavky | `advancedDescription` | `like` | `[text]` (celý reťazec) | server: obsahuje (`LIKE %x%`) ako ostatné textové polia (D10) |
| Druh požiadavky | `type` | `in` | `[id]` (jedna hodnota) | existujúci generický filter |
| Vlastník | `creationAuthorId` | `in` | `[userId]` (jedna hodnota) | existujúci generický filter |
| Základná finančná kontrola | `basicFinancialControl` | `in` | `["true"]` alebo `["false"]` | existujúci generický filter (rovnako ako stĺpcový filter) |
| Stav | `status` | `in` | splošťené `[103, 203, …]` | existujúci generický filter |
| Príjmy | `advancedIncome` | `between` | `[from|EMPTY, to|EMPTY]` | vlastný predikát, hranice **vrátane**, `0` povolená |
| Výdavky | `advancedExpenses` | `between` | `[from|EMPTY, to|EMPTY]` | ako vyššie |
| Dátum – Dátum požiadavky | `advancedRequestDate` | `between` | `[fromTs|EMPTY, toExclusiveTs|EMPTY]` + `filterValueType: "datetime"` | `requestDate >= from AND < toExclusive` |
| Dátum – Vybavená | `advancedResolvedDate` | `between` | ako vyššie | `EXISTS` aktivita `type = 103` s `creationDatetime` v intervale |
| Dátum – Vybavená – po vykonaní ZFK | `advancedResolvedAfterFkDate` | `between` | ako vyššie | `EXISTS` aktivita `type = 203` s `creationDatetime` v intervale |
| Dátum – ZFK ukončená | `advancedFkFinishedDate` | `between` | ako vyššie | `status IN (202, 203)` AND `MAX(step.creationDatetime)` schválených krokov v intervale |

- Typ dátumu a typ sumy sa na wire prenáša **výberom `fieldName`**; server nepotrebuje samostatný parameter „typ". Naraz je odoslaný najviac jeden dátumový a jeden sumový filter (AC 17, AC 12).
- **Od > Do** → server pridá oba predikáty a výsledok je prirodzene prázdny, bez chyby a bez hlášky (AC 19).
- Ak sú obe hranice prázdne, server predikát nepridá. Požiadavky bez zvoleného dátumu/sumy (NULL, bez aktivity, bez schváleného kroku) pri aktívnom filtri nevyhovujú (AC 16).
- Veľkosť písmen a diakritiku kód nerieši, rovnako ako existujúce filtre (D9).
- Neparsovateľná hodnota (`Double.valueOf`, `Long.parseLong`) → výnimka → HTTP 500 (rovnako ako existujúce `Long.parseLong` v `ExternalRequestDao.java:132`); klient posiela len validované hodnoty. Zámerne sa nezužuje do „ignoruj" (to by potichu rozšírilo výsledky).
- Aktivita typu 103/203: typ aktivity sa zapisuje ako **nový stav požiadavky** (`ExternalRequestService.java:652` `addNewActivity(externalRequest, systemUser, newStatus)`; `STATUS_CPS_OVZP_RESOLVED = 103`, `STATUS_ZFK_RESOLVED = 203`, `ExternalRequest.java:148,156`). „Vybavená" a „po ZFK" sú disjunktné (AC 18).
- Dátum rozhodnutia schvaľovacieho kroku je `ExternalRequestConfirmanceStep.creationDatetime`, nastavuje ho `setStepStatus` (`ExternalRequestService.java:733-740`); „schválený" = `Confirmed` alebo `ConditionallyConfirmed` (`isApproved`, `:2144-2147`; ordinály 2 a 5 v `ExternalRequestConfirmanceStep.java:50-63`, stĺpec `status SMALLINT` — `db.changelog-EP5258.xml:165`).

---

## 3. BACKEND (`publicERANET-server`, agent `executor-backend`)

Všetko je v dvoch súboroch: `dto/ExternalRequest.java` a `dao/ExternalRequestDao.java`. Servis (`ExternalRequestService.findAll` `:146-162`, `findAllInternal` `:400-417`) sa **nemení**. Jedna zmena = jeden commit v tomto repozitári (po potvrdení používateľom).

### B1 — Konštanty filtrov
- **Edit:** `src/main/java/sk/innovis/eranetpublic/server/dto/ExternalRequest.java` — za riadok 112 (`FILTER_PROCESSING_DEADLINE_AND_ACTION_REQUIRED`) pridať `public static final String FILTER_ADVANCED_*` konštanty: `UNIQ_CODE`, `ORGANIZATION_ICO`, `ORGANIZATION_NAME`, `EIS_DOCUMENT_NUMBER`, `DESCRIPTION`, `INCOME`, `EXPENSES`, `REQUEST_DATE`, `RESOLVED_DATE`, `RESOLVED_AFTER_FK_DATE`, `FK_FINISHED_DATE` s hodnotami z tabuľky v sekcii 2.
- **Vzor:** existujúce `FILTER_ORGANIZATION_DIRECTORY_NAME` atď. (`:106-112`).
- **Verifikácia:** kompiluje sa (B6).

### B2 — Kostra v `getWhere` + pomocné metódy (AC 13, AC 28)
- **Edit:** `dao/ExternalRequestDao.java`.
- V `getWhere` pridať jedno volanie `addAdvancedFilterPredicates(result, findParameters, criteriaBuilder, criteriaQuery, from)` **tesne pred** `result.addAll(Arrays.asList(super.getWhere(...)))` (riadok 150), t. j. za blok `generalizedUnionFilter` (`:144-148`). Predikáty sa len pridávajú do `result` (AND), nikdy sa nekombinujú s predikátmi viditeľnosti cez OR.
- **Kritické pravidlo:** pre **každé** nové `fieldName` zavolať `findParameters.tryGetFilterByNameAndMarkAsNotEntityFilter(name)` (`FindParameters.java:158-168`) **vždy**, aj keď sa hodnota ignoruje. Inak by `BaseDao.processQueryFilter` (`:240-414`; preskočenie len pri `notEntityFieldFilter`, `:247`) skúsilo `from.get("advancedUniqCode")` a spadlo na neexistujúcom atribúte. `getWhere` sa volá dvakrát (`findItems` `BaseDao.java:128` a `getTotalCount` `:145`), filter sa hľadá podľa mena, takže druhé volanie ho nájde znova — v poriadku.
- Pomocné metódy (súkromné, malé, dobre pomenované):

```java
private void addContainsPredicate(List<Predicate> predicates, CriteriaBuilder cb, Expression<String> column, String value) {
	if (value != null) {
		predicates.add(cb.like(column, "%" + value + "%"));
	}
}

// Returns null for missing / blank / EMPTY_VALUE bound.
private String boundAt(QueryFilter filter, int index) { ... }
```

- Pridať `import javax.persistence.criteria.Expression;` a `ExternalRequestActivity_` (metamodel je generovaný: `target/generated-sources/.../ExternalRequestActivity_.java` obsahuje `externalRequest`, `type`, `creationDatetime`; `ExternalRequest_` má `uniqCode`, `description`, `eisDocumentNumber`, `income`, `expenses`, `requestDate`, `organizationDirectory`, `status`; `OrganizationDirectory_.ico`/`name`; `ExternalRequestConfirmanceStep_.creationDatetime`/`status`/`externalRequestId`).
- **Verifikácia:** `mvn` build (B6).

### B3 — Textové filtre a Popis (AC 5, 6, 7)
- **Edit:** `ExternalRequestDao.java`, nová metóda napr. `addAdvancedTextPredicates(...)` volaná z `addAdvancedFilterPredicates`.
- Kód → `addContainsPredicate(result, cb, from.<String>get(ExternalRequest_.uniqCode), value)`; Číslo dokladu → `eisDocumentNumber`.
- IČO a Názov organizácie: `from.join(ExternalRequest_.organizationDirectory)` **len ak je filter prítomný** (rovnaký vzor ako `ExternalRequestDao.java:105-119`; many-to-one join nezduplikuje riadky), potom `OrganizationDirectory_.ico` / `.name`. „Organizácia žiadateľa" = atribút `organizationDirectory` zobrazený v stĺpcoch „Organizácia – IČO/Názov" (O10).
- Popis → rovnako ako Kód: `addContainsPredicate(..., ExternalRequest_.description, text)` (obyčajné obsahuje, D10). Žiadne rozdeľovanie na slová a žiadny `MATCH`.
- Prázdna / whitespace hodnota → predikát sa nepridá.
- Escapovanie `%`, `_` a `\` sa nerobí (D11), rovnako ako veľkosť písmen a diakritika (D9) — texty idú ako v ostatných filtroch aplikácie.
- Existujúce `organizationDirectoryName`/`organizationDirectoryIco` filtre (`:105-119`) sa **nemenia** (používa ich stĺpcový filter a `ExternalRequestService.java:1782`).

### B4 — Príjmy / Výdavky (AC 12, AC 19)
- **Edit:** `ExternalRequestDao.java`, metóda `addAdvancedAmountPredicates(...)`.
- `income`/`expenses` sú `Double` (`ExternalRequest.java:312-316`, DB `DOUBLE` — `db.changelog-EP7089.xml:8-9`). Hranice **vrátane**: `from != null → cb.greaterThanOrEqualTo(expr, Double.valueOf(from))`, `to != null → cb.lessThanOrEqualTo(...)`. `0` je platná hranica (nikde netestovať `from` ako truthy; len `null`).
- Generický `between` sa nepoužíva (nepripravený na číselný `Double`, `BaseDao.java:341-350`).
- Riadky s `income`/`expenses = NULL` sa pri aktívnom filtri nezobrazia ani pri `Od = 0` (predpoklad O2: „porovnáva sa suma zadaná v požiadavke").

### B5 — Dátumové filtre (4 typy; AC 14, 15, 16, 18)
- **Edit:** `ExternalRequestDao.java`, metódy `addDateRange(List<Predicate>, cb, Expression<Date>, QueryFilter)` (`>= new Date(Long.parseLong(from))`, `< new Date(Long.parseLong(toExclusive))`) a trojica builderov:
  - `requestDate` → `addDateRange(..., from.<Date>get(ExternalRequest_.requestDate), filter)`.
  - `buildActivityDatePredicate(cb, cq, from, filter, activityType)` pre 103 a 203 — `EXISTS` podľa `buildRetentionDisjunct` (`:482-496`): `Subquery<Integer>`, `Root<ExternalRequestActivity>`, `cb.literal(1)`, `act.get(ExternalRequestActivity_.externalRequest).get(ExternalRequest_.id) = from.get(ExternalRequest_.id)`, `type = activityType`, plus `addDateRange` nad `creationDatetime`. Použiť konštanty `ExternalRequest.STATUS_CPS_OVZP_RESOLVED` a `STATUS_ZFK_RESOLVED`.
  - `buildFkFinishedDatePredicate(cb, cq, from, filter)`:

```java
Subquery<Date> lastApproval = cq.subquery(Date.class);
Root<ExternalRequestConfirmanceStep> step = lastApproval.from(ExternalRequestConfirmanceStep.class);
lastApproval.select(cb.greatest(step.<Date>get(ExternalRequestConfirmanceStep_.creationDatetime)))
	.where(cb.equal(step.get(ExternalRequestConfirmanceStep_.externalRequestId), from.get(ExternalRequest_.id)),
		step.get(ExternalRequestConfirmanceStep_.status).in((Object[]) APPROVED_STEP_STATUSES));
List<Predicate> where = new ArrayList<>();
where.add(from.get(ExternalRequest_.status).in(ExternalRequest.STATUS_ZFK_FINISHED, ExternalRequest.STATUS_ZFK_RESOLVED));
addDateRange(where, cb, lastApproval, filter);   // Subquery<Date> is an Expression<Date>
return cb.and(where.toArray(new Predicate[0]));
```

  `APPROVED_STEP_STATUSES = { Confirmed, ConditionallyConfirmed }` ako konštanta DAO s komentárom odkazujúcim na `ExternalRequestService.isApproved` (DAO nesmie závisieť od servisu).
- Ak sú obe hranice prázdne → bez predikátu (typ sám o sebe filter nevytvorí; AC 20 rieši klient).
- **Záložné riešenie (R3),** ak EclipseLink skalárny subquery v porovnaní nevygeneruje: „krok je najneskorší schválený krok" ako `EXISTS(s: schválený, dátum v intervale, NOT EXISTS(s2: schválený, s2.dátum > s.dátum))` — sémanticky to isté ako `MAX`.

### B6 — Build a overenie backendu
- Build: `mvn -q -DskipTests clean package` v `publicERANET-server/` **pod JDK 8** (pod JDK 21 padá statický weaver EclipseLink — pozri `coding-conventions`). Žiadne unit testy neexistujú (`TESTING.md`).
- Overenie bez klienta (backend je testovateľný pred hotovým FE): prihlásený v prehliadači, v konzole `fetch('webresources/sc/externalRequest/query', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(…)})`. Telo skopírovať z Network tabu bežného načítania zoznamu a doplniť položky z tabuľky v sekcii 2. Porovnať `totalCount` s SQL z 8.2 a skontrolovať SQL v `server.log`.
- Minimálna sada volaní: každý text (vrátane `100%`, `a_b`, `a\b`), Popis, `advancedIncome ["0","0"]`, `["500","100"]` (prázdny výsledok), každý zo 4 dátumových typov, kombinácia s `status` `[103,203]` a `basicFinancialControl ["false"]`; overiť aj to, že výsledok s novými filtrami je vždy podmnožinou výsledku bez nich pre toho istého používateľa (viditeľnosť sa nerozširuje, AC 28).
- Neprekročiť rozsah: žiadny Liquibase, žiadna zmena `ApplicationConfig.java`/`persistence.xml`.

---

## 4. FRONTEND (`publicERANET-client`, agent `executor-frontend`)

ES5, tabulátory, jednoduché úvodzovky, array DI, JSHint (`.jshintrc`). Identifikátory a kľúče anglicky; slovenčina len v hodnotách prekladov. Komentáre krátke, jednoriadkové.

**Dohodnuté názvy (aby F2–F6 mohli ísť paralelne po F1):**

| Čo | Názov |
|---|---|
| Služba (pamäť) | `ExternalRequestAdvancedFilter` — `app/scripts/service/externalRequestAdvancedFilter.js` (modul `services`) |
| Kontrolér popupu | `ExternalRequestAdvancedFilterController` — `app/scripts/controllers/planningExternal/externalRequestAdvancedFilter.js` |
| Šablóna popupu | `app/views/planningExternal/externalRequestAdvancedFilter.html` |
| `$uibModal` resolve | `filter` (kópia aplikovaného modelu `getForEdit()`, pri neaktívnom filtri prázdny, D7), `statusCodebookName` |
| Scope v `ExternalRequestsTableController` | `showAdvancedFilterButton`, `showAdvancedFilter()`, `clearAdvancedFilter()`, `isAdvancedFilterActive()` |

**Model filtra (dialóg aj služba), podľa tiketu 3.2 — Druh a Vlastník sú single, Stav multi:**

```js
{
	uniqCode: '', organizationIco: '', organizationName: '',
	type: undefined,                  // Druh požiadavky – jedno id z číselníka
	description: '',
	ownerId: undefined,               // Vlastník – jedno id
	eisDocumentNumber: '',            // „Číslo dokladu"
	basicFinancialControl: undefined, // true | false | undefined
	statuses: [],                     // Stav – viac hodnôt (id alebo polia id zlúčených stavov)
	amount: { type: 'income', from: '', to: '' },        // text; type: 'income' | 'expenses'; default Príjmy
	date: { type: 'requestDate', from: '', to: '' }      // 'dd.mm.yyyy' reťazce; default Dátum požiadavky
}
```

### F1 — Služba `ExternalRequestAdvancedFilter` (pamäť)
- **Create:** `app/scripts/service/externalRequestAdvancedFilter.js`. **Edit:** `app/index.html` — `<script src="scripts/service/externalRequestAdvancedFilter.js"></script>` hneď za `webStorage.js` (`index.html:180`).
- **Vzor:** službový vzor z `coding-conventions` (`serviceResult`, súkromné `var fn = function`), DI `['$rootScope', 'FilterHelper', 'Utils', 'Constants', …]`.
- **API:** konštanty `DATE_TYPE_REQUEST_DATE|FK_FINISHED|RESOLVED|RESOLVED_AFTER_FK`, `AMOUNT_TYPE_INCOME|EXPENSES`; `getEmpty()` (nový prázdny model s predvolenými typmi — AC 14, AC 20, AC 26); `set(model)` (uloží klon *aplikovaného* modelu a **nahradí** predošlý; ak je model prázdny → `clear()`, AC 23); `clear()`; `getForEdit()` (kópia aplikovaného modelu pre popup, D7); `isActive()`; `getServerFilters()`.
- **`isActive()`:** aspoň jedno pole má hodnotu — text po `trim`, `type`/`ownerId` `!== undefined && !== null`, neprázdne `statuses`, `basicFinancialControl !== undefined && !== null`, suma `from`/`to` **`!== ''`** (nie truthy test, `0` je hodnota), dátum `from`/`to` neprázdne. Samotný „typ" filter nevytvára. Ak je `amount.type`/`date.type` prázdny/`undefined`, použije sa predvolený typ (AC 20).
- **`getServerFilters()`** (pure funkcie, aby sa dali neskôr testovať):
  - text → `FilterHelper.getFilter([text], fieldName, FilterHelper.FILTER_TYPE_LIKE)` (alebo `FilterHelper.getLikeFilter`; nepoužívať `FilterHelper.getServerFilters`/`processOneFilter` — zahadzujú `0`, `filterHelper.js:66,70,75`).
  - `type` → `FilterHelper.getInFilter([type], 'type')`; `ownerId` → `getInFilter([ownerId], 'creationAuthorId')`; ZFK → `getInFilter([String(value)], 'basicFinancialControl')`; `statuses` → `getInFilter(_.flatten(statuses), 'status')` (rovnaký účel ako `handleMultipleStatusesFilter`, `externalRequests.js:90-108`).
  - suma → `FilterHelper.getFilter([from === '' ? Constants.EMPTY_VALUE : normalize(from), … ], 'advancedIncome'|'advancedExpenses', FilterHelper.FILTER_TYPE_BETWEEN)`, `normalize` = `trim` + `,`→`.` (zostáva reťazec, `'0'` ostáva `'0'`).
  - dátum → `from = Utils.dateToTimestamp(str)`; `toExclusive`: `var d = new Date(Utils.dateToTimestamp(toStr)); d.setDate(d.getDate() + 1); d.getTime()`; pár `String(ts)` / `Constants.EMPTY_VALUE`, `filterValueType` `FilterHelper.FILTER_VALUE_TYPE_DATETIME`, `fieldName` podľa typu (sekcia 2).
- **Odchod z modulu (AC 27):** `$rootScope.$on('$routeChangeSuccess', fn)` podľa precedensu `controllers/main.js:415-427`; ak `current && current.$$route && current.$$route.originalPath && current.$$route.originalPath.indexOf('/planningExternal/') < 0` → `clear()`. Detail (`/planningExternal/editExternalRequest`, `ng.app.js:711`) aj obe karty zoznamu majú tento prefix, takže stav prežije; refresh stránky ho zruší prirodzene (nič sa neperzistuje). Služba sa vytvára pri prvom vstreknutí; registrácia v tele továrne je v poriadku, lebo prvé vstreknutie nastáva už v module.
- **Verifikácia:** `node node_modules/jshint/bin/jshint app/scripts/service/externalRequestAdvancedFilter.js` → 0 upozornení.

### F2 — Pripojenie filtra k dotazu
- **Edit:** `app/scripts/service/resources/externalRequests.js` — vstreknúť `ExternalRequestAdvancedFilter` (nový posledný parameter DI poľa **aj** `define` funkcie, `:62-84`); v `loadExternalRequestsInternal` (`:127-150`) hneď za `handleMultipleStatusesFilter(postData.queryFilters)` (`:132`) pripojiť `Array.prototype.push.apply(postData.queryFilters, ExternalRequestAdvancedFilter.getServerFilters())` len keď `$routeParams.filter === Constants.EXTERNAL_REQUEST_STATUS_FILTER_ALL`.
- `loadExternalRequestsInternal` volá výhradne tabuľkový kontrolér (`externalRequestsTable.js:137`; ďalší volajúci neexistuje), takže bez aktívneho filtra je zmena neutrálna. `calculateTotalSum` (`:152-172`) sa nemení (stránka externých požiadaviek ho nepoužíva, žiadny `change_table_filters` poslucháč v `yearlyExternalRequestsCollecting.js`).
- **Verifikácia:** JSHint počet nesmie stúpnuť nad základ **17** (súbor už má 17 starých upozornení).

### F3 — Popup „Rozšírený filter" (kontrolér + šablóna) — AC 2, 3, 4, 8, 9, 10, 11, 12, 14, 17, 20, 22, 23, 26
- **Create:** `controllers/planningExternal/externalRequestAdvancedFilter.js`, `views/planningExternal/externalRequestAdvancedFilter.html`. **Edit:** `index.html` — script za `confirmanceCommentDetailDialogController.js` (`index.html:694`; skupina planningExternal `:690-694`).
- **Vzor:** kópia `controllers/procurement/procurementAdvancedFilter.js` + `views/procurement/procurementAdvancedFilter.html` (modal-header s `fa-times` a `CLOSE_DIALOG`, `smart-form` riadky `col-4` label / `col-6` ovládač / `col-1` `btn btn-circle` s `fa-times` a tooltipom `DEACTIVATE`, päta s `SUPPLIERS_ADVANCED_FILTER_USE` (primárne) a `CANCEL`, na konci `<script>pageSetUp();</script>`). Datepicker presne: `class='form-control datepicker' data-dateformat='dd.mm.yy'` + kalendárová ikona s `$root.datePickerFocus($event)` (`main.js:1166`; vzor `procurementAdvancedFilter.html:172-182`).
- **Poradie a typy polí — presne podľa tiketu 3.2 (11 riadkov, každý s ✖ vpravo):**

| # | Popisok | Ovládač | Model | ✖ resetuje na |
|---|---|---|---|---|
| 1 | Kód | `<input class="input-sm" type="text">` | `uniqCode` | `''` |
| 2 | Organizácia – IČO | text | `organizationIco` | `''` |
| 3 | Organizácia – Názov | text | `organizationName` | `''` |
| 4 | Druh požiadavky | `ui-select` **single**, zdroj `CodebookGenerator[CodebookGenerator.EXTERNAL_REQUEST_TYPES_CPS]` (všetky vrátane neaktívnych — ako stĺpcový filter, `codebookFilter.js:31`); vzor single `ui-select` `editExternalRequestBase.html:248-257` | `type` | `undefined` (nie `null` — `coding-conventions`) |
| 5 | Popis požiadavky | text (obsahuje) | `description` | `''` |
| 6 | Vlastník | `ui-select` **single** nad zoznamom `users`, `repeat='user.id as user in users | filter:{formattedName: $select.search} | orderBy:"formattedName"'` (vzor `editExternalRequestBase.html:712`) | `ownerId` | `undefined` |
| 7 | Číslo dokladu | text | `eisDocumentNumber` | `''` |
| 8 | Základná finančná kontrola | `ui-select` single, **Áno / Nie** nad `CodebookGenerator.booleanVerbal` (`BOOLEAN_YES`/`BOOLEAN_NO`, `codebookGenerator.js:1441-1445`) | `basicFinancialControl` | `undefined` |
| 9 | Stav | `ui-select multiple` nad `CodebookGenerator[statusCodebookName]` (dynamicky z číselníka; EES názov odovzdá tabuľka cez resolve), markup ako `codebookFilter.html` (`item.id as item`, `{{$item.name | translate}}`) | `statuses` | `[]` |
| 10 | Príjmy / Výdavky | riadok 1: výber typu (`ui-select` single: Príjmy / Výdavky, predvolené **Príjmy**, bez ✖); riadok „Od:" a riadok „Do:" — každý text s **vlastným ✖** | `amount.type`, `amount.from`, `amount.to` | ✖ pri Od/Do: `''` len pre ten riadok, typ ostáva |
| 11 | Dátum | riadok 1: výber typu (`ui-select` single, predvolené **Dátum požiadavky**, bez ✖), poradie položiek: Dátum požiadavky, ZFK ukončená, Vybavená, Vybavená – po vykonaní ZFK; riadky „Od:" a „Do:" — datepicker s ikonou kalendára a **vlastným ✖** | `date.type`, `date.from`, `date.to` | ✖ pri Od/Do: `''` len pre ten riadok, typ ostáva |

  Mockup kreslí Druh/Vlastník/Stav ako obyčajné polia; **platí text tiketu** (číselník / výber osoby / multi-výber).
- **Tlačidlá:** „Použiť" → `$uibModalInstance.close($scope.filter)` (model sa neprevádza na timestampy — to robí služba; AC 21); „Zrušiť" a záhlavné „×" → `$uibModalInstance.dismiss` (aktuálny filter ostáva, AC 22). Prázdne „Použiť" (nič nevyplnené) sa zachová ako platná akcia: služba filter zruší (AC 23).
- **Zdroj používateľov (AC 8):** `Users.loadUsersForCurrentCompanyIncludeExternalAndInactiveUsers(cb)` → `Users.getUsers().items`, namapovať na ľahké `{id, formattedName}` (D4).
- **Sumový vstup (AC 12):** `type="text"`, `onkeypress="validateString(event, this, /^\d{0,15}([,.]\d{0,2})?$/)"` (zakáže znamienko, písmená a 3. desatinné miesto; 0 povolená) + `data-ng-pattern` s rovnakým regexom ako poistka pre vloženie (paste); model zostáva reťazec. Pri neplatnej vloženej hodnote sa pole označí `state-error` (vzor `editExternalRequestBase.html:247`) a „Použiť" sa zablokuje, **bez textovej hlášky** (O12). Od > Do sa **nevaliduje** (prázdny výsledok bez hlášky, AC 19).
- **Dátumový vstup:** neúplný/neplatný dátum (`Utils.dateIsNotComplete`, `utils.js:68-80`) = neplatné pole (zablokuje „Použiť"), aby sa neplatný vstup potichu nezahodil (O5, ponechané).
- **Verifikácia:** JSHint nový súbor 0 upozornení; ručne podľa T03–T22.

### F4 — Preklady — AC 3, 14, 24
- **Edit:** `app/scripts.no.min/langs/sk.js` a `en.js` — nové kľúče pridať pred koncový `"":""` (`sk.js` ~4740, `en.js` na konci). `hr.js` sa nemení (nedrží ani ostatné `EXTERNAL_REQUEST_*`). Kľúče anglické, slovenčina len v hodnotách; tabuľky pre `en.js` sú návrh anglických hodnôt.

| Popisok z tiketu | Kľúč | `sk.js` hodnota | `en.js` (návrh) | Stav |
|---|---|---|---|---|
| Názov popupu | `EXTERNAL_REQUEST_ADVANCED_FILTER_TITLE` | Rozšírený filter | Advanced filter | **nový** |
| Tlačidlo v lište | `EXTERNAL_REQUEST_ADVANCED_FILTER_BUTTON` | Rozšírené vyhľadávanie | Advanced search | **nový** |
| Kód | `INTERNAL_REQUEST_TABLE_UNIQ_CODE` | Kód | (existuje) | existujúci (`sk.js:483`) |
| Organizácia – IČO | `EXTERNAL_REQUEST_ORGANIZATION_ICO` | Organizácia - IČO | (existuje) | existujúci (`sk.js:4580`; v tikete pomlčka „–", O11) |
| Organizácia – Názov | `EXTERNAL_REQUEST_ORGANIZATION_NAME` | Organizácia - Názov | (existuje) | existujúci (`sk.js:4579`; O11) |
| Druh požiadavky | `EXTERNAL_REQUEST_KIND` | Druh požiadavky | (existuje) | existujúci (`sk.js:4587`) |
| Popis požiadavky | `EXTERNAL_REQUEST_DESCRIPTION` | Popis požiadavky | (existuje) | existujúci (`sk.js:4588`) |
| Vlastník | `EXTERNAL_REQUEST_OWNER` | Vlastník | (existuje) | existujúci (`sk.js:4591`) |
| Číslo dokladu | `EXTERNAL_REQUEST_ADVANCED_FILTER_DOCUMENT_NUMBER` | Číslo dokladu | Document number | **nový** (existujúci `EXTERNAL_REQUEST_EIS_DOCUMENT_NUMBER` = „Číslo dokladu EIS", `sk.js:4595`; O11) |
| Základná finančná kontrola | `EXTERNAL_REQUEST_ADVANCED_FILTER_BASIC_FINANCIAL_CONTROL` | Základná finančná kontrola | Basic financial control | **nový** (existujúci `EXTERNAL_REQUEST_BASIC_FINANCIAL_CONTROL` = „Finančná kontrola", `sk.js:4600`; `ECONTRACT_BASIC_FINANCIAL_CONTROL` patrí e-zmluvám) |
| Áno / Nie | `BOOLEAN_YES` / `BOOLEAN_NO` | Áno / Nie | (existuje) | existujúce (`sk.js:399,402`) |
| Stav | `INTERNAL_REQUEST_TABLE_STATE` | Stav | (existuje) | existujúci (`sk.js:492`) |
| Príjmy / Výdavky (popisok) | `EXTERNAL_REQUEST_ADVANCED_FILTER_AMOUNT` | Príjmy / Výdavky | Income / Expenses | **nový** |
| položky typu sumy | `EXTERNAL_REQUEST_INCOME` / `EXTERNAL_REQUEST_EXPENSES` | Príjmy / Výdavky | (existujú) | existujúce (`sk.js:4589-4590`) |
| Dátum (popisok) | `EXTERNAL_REQUEST_ADVANCED_FILTER_DATE` | Dátum | Date | **nový** |
| typ „Dátum požiadavky" | `EXTERNAL_REQUEST_DATE` | Dátum požiadavky | (existuje) | existujúci (`sk.js:4584`) |
| typ „FK ukončená" (v tikete „ZFK ukončená") | `EXTERNAL_REQUEST_ADVANCED_FILTER_DATE_TYPE_FK_FINISHED` | FK ukončená | FK finished | **nový** |
| typ „Vybavená" | `EXTERNAL_REQUEST_ADVANCED_FILTER_DATE_TYPE_RESOLVED` | Vybavená | Resolved | **nový** |
| typ „Vybavená – po vykonaní FK" (v tikete „…ZFK") | `EXTERNAL_REQUEST_ADVANCED_FILTER_DATE_TYPE_RESOLVED_AFTER_FK` | Vybavená – po vykonaní FK | Resolved - after FK | **nový** |
| Od / Do | `FILTER_FROM` / `FILTER_TO` | Od: / Do: | (existujú) | existujúce (`sk.js:1714-1715`) |
| Použiť / Zrušiť | `SUPPLIERS_ADVANCED_FILTER_USE` / `CANCEL` | Použiť / Zrušiť | (existujú) | existujúce (`sk.js:3047,442`) |
| Tooltip „×" a ✖ | `DEACTIVATE` | Deaktivovať | (existuje) | existujúci (`sk.js:499`) |
| Zavrieť popup, placeholder dátumu | `CLOSE_DIALOG`, `CHOOSE_DATE` | — | (existujú) | existujúce (`sk.js:440,431`) |

- **Verifikácia:** súbory ostávajú platným JS objektom (aplikácia sa načíta bez konzolovej chyby); všetky použité kľúče sa prekladajú (žiadne holé `EXTERNAL_REQUEST_ADVANCED_FILTER_*` v UI).

### F5 — `ExternalRequestsTableController` — AC 2, 21, 22, 23, 24, 25, 26, 27
- **Edit:** `app/scripts/directives/externalRequestsTable.js` (kontrolér zdieľaný CPS aj non-CPS tabuľkou — všetky zmeny musia byť inertné, kým nie je rozšírený filter aplikovaný).
- DI (`:49-84`): pridať na koniec poľa a parametrov `'$routeParams'`, `'ExternalRequestAdvancedFilter'` (poradie poľa = poradie parametrov!).
- `$scope.showAdvancedFilterButton = $routeParams.filter === Constants.EXTERNAL_REQUEST_STATUS_FILTER_ALL;` (rovnaká podmienka ako `YearlyExternalRequestsCollectingController:17`, `showDocumentTable`).
- Súkromné `advancedFilterApplies()` = `$scope.showAdvancedFilterButton && ExternalRequestAdvancedFilter.isActive()`; `$scope.isAdvancedFilterActive = advancedFilterApplies`.
- **Invariant v `reloadRequests`** (`:123-140`) tesne pred `$scope.filterOn = …` (`:134`), teda aj po obnovení z `WebStorage`: `if (advancedFilterApplies() && Utils.checkIfSomeFilterSet($scope.help)) { ExternalRequestAdvancedFilter.clear(); }` (D3; AC 25: pokrýva písanie do základného filtra, „súvisiacu požiadavku" `:161-171` aj návrat z detailu).
- `$scope.showAdvancedFilter()`: `$uibModal.open({templateUrl: 'views/planningExternal/externalRequestAdvancedFilter.html', controller: 'ExternalRequestAdvancedFilterController', resolve: {filter: function () { return ExternalRequestAdvancedFilter.getForEdit(); }, statusCodebookName: function () { return $scope.externalRequestStatusCpsFilter; }}})` (názov číselníka sa mení podľa EES, `:414,447`). `result.then(applyAdvancedFilter)`; zatvorenie bez výsledku nič nerobí (AC 22).
- `applyAdvancedFilter(newFilter)`: `ExternalRequestAdvancedFilter.set(newFilter)` (nahradí predošlý, prázdny zruší); ak `isActive()` → `clearBasicFilters()` (AC 21; pri prázdnom výsledku sa základný filter **nemení**, O3); `$scope.help.paging.page = 1`; `storeFilterAndDoReload()` (uloží do `WebStorage` už **vyčistený** základný filter, `:149-155`, a zachová stránkovanie/zoradenie).
- `clearBasicFilters()` (D2): (1) **model na mieste:** pre každý `help.filters[name]` podľa `type` — `in` → `value = []`; `between` → `from = to = null`; `like`/`startWith`/ostatné → `value = null`; `_searchText`/`_realSearchText` → `''`; (2) **lokálny stav direktív** ako `econtractsOverview.js:155-177` pre `TextFilterController` (`scope().text = ''`), `TextStartWithFilterController` (`scope().text = ''`), `CodebookFilterController` (`scope().filters.value = []`), `DatetimeFilterController` (`scope().help.from = scope().help.to = null`). Model sa musí vyčistiť **synchrónne pred** `storeFilterAndDoReload()` (watch-e direktív bežia až po návrate z funkcie a `JSON.stringify($scope.help)` by uložil staré hodnoty).
- `$scope.clearAdvancedFilter()` („×", AC 24): `ExternalRequestAdvancedFilter.clear(); $scope.help.paging.page = 1; storeFilterAndDoReload();` (základný filter je v tomto stave prázdny). Robí to isté ako prázdne „Použiť" (AC 23).
- Listener `FILTER_OR_SEARCH_CHANGED` (`:405-408`): zachovať `storeFilterAndDoReload`; **voliteľne** handler-guard `if (advancedFilterApplies() && !Utils.checkIfSomeFilterSet($scope.help)) { return; }`, aby oneskorená udalosť (500 ms) po programovom čistení nespustila druhý, zbytočný reload. Bezpečné: pri aktívnom rozšírenom filtri nemôže základný filter užívateľsky „zmiznúť" bez toho, aby ho predtým invariant zrušil.
- **Verifikácia:** JSHint počet súboru nesmie stúpnuť nad základ **36**; `git diff` neobsahuje zmenu `externalRequestsTable.html` (non-CPS šablóna nedotknutá).

### F6 — CPS šablóna: tlačidlo a „×" — AC 1, 24, 29
- **Edit:** `app/views/directives/externalRequestsTableCps.html` — v hlavičkovom riadku (`:2-24`) pridať **novú** sekciu vedľa existujúcej 5 % sekcie s lievikom (`:21-23`; je pre text príliš úzka), `class="col pull-right" style="width: auto;"`, `data-ng-show="showSearchAndFilter && showAdvancedFilterButton"` (tiket 3.1: „v pravej časti lišty nad zoznamom"):

```html
<section class="col pull-right" style="width: auto;" data-ng-show="showSearchAndFilter && showAdvancedFilterButton">
	<button type="button" class="btn btn-default pull-right"
		data-ng-class='{"filter-x-button": isAdvancedFilterActive()}'
		data-ng-disabled="!isAdvancedFilterActive()"
		data-ng-click="clearAdvancedFilter()"
		data-tooltip="{{'DEACTIVATE'|translate}}"><i class="fa fa-times"></i></button>
	<button type="button" class="btn btn-primary pull-right" style="margin-right: 5px;"
		data-ng-click="showAdvancedFilter()">{{'EXTERNAL_REQUEST_ADVANCED_FILTER_BUTTON'|translate}}</button>
</section>
```

- Vzor „×": `econtractsOverview.html:40-47` (vždy viditeľné, `btn btn-default`, `ng-disabled` = sivé neaktívne, `filter-x-button` = aktívne; trieda `custom.css:739-746` sa len znovupoužije, nič sa nepridáva — je to existujúci „aktívny filter" štýl, odtieň je ružovo-červený; tiket hovorí „červená") a poradie `procurementsList.html:17-29` (v DOM prvý `pull-right` je vpravo). Výsledné poradie sprava: lievik · „×" · „Rozšírené vyhľadávanie". Presné poradie × vs. tlačidlo a medzery sú **vec na overenie s používateľom** na obrázku z tiketu (tiket hovorí „vedľa tlačidla"), nie blokátor (O7).
- Existujúce tlačidlo „Vytvoriť" (`:3-19`) a ikona základného filtra ostávajú bez zmeny (AC 29).
- **Verifikácia:** ručne T01–T02.

### F7 — Lint a finálne overenie klienta
- `node node_modules/jshint/bin/jshint <nové súbory>` → 0; zmenené súbory (`externalRequestsTable.js` ≤ 36, `externalRequests.js` ≤ 17) bez nových upozornení. (JSHint beží aj na Node 24; Karma nie.)
- Karma/Jasmine sa **nepíše ani nespúšťa**: Karma 0.12 na modernom Node nebeží a jediný spec je scaffold s neexistujúcim modulom (`docs/codebase/TESTING.md`). Čisté funkcie služby (F1) sú navrhnuté tak, aby sa dali dopísať testy po upgrade stacku.
- Overenie v bežiacej aplikácii podľa sekcie 8.

---

## 5. Poradie krokov a paralelizmus

```
Kontrakt (sekcia 2) + dohodnuté názvy a model (sekcia 4)  ───────────────────────┐
                                                                                  │
BACKEND (jeden agent, jeden súbor):  B1 → B2 → B3 → B4 → B5 → B6                  │  paralelne
FRONTEND:  F1 ─┬─ F2                                                             │
               ├─ F3 ─┐                                                           │
               ├─ F4 ─┼─ F7                                                       │
               ├─ F5 ─┤                                                           │
               └─ F6 ─┘                                                           │
                                                                                  │
INTEGRÁCIA (po B6 a F7): sekcia 8 (T01–T35) ◄────────────────────────────────────┘
```

- **Backend a frontend sa robia paralelne** (spoločný je len kontrakt). BE sa dá overiť cez `fetch` v konzole bez FE (B6).
- Vo FE je F1 prvý (API služby a model). F2–F6 sa potom dajú rozdeliť (rôzne súbory); `index.html` upravujú F1 a F3 — pozor na súbehovú editáciu, robiť sekvenčne. Poradie a typy polí pre F3/F4 sú už známe z tiketu.
- Pred ručným testom vygenerovať checklist skillom `acceptance-test-checklist` z 29 AC (sekcia 8.3 je podklad).
- Review: `code-reviewer-backend` a `code-reviewer-frontend` (len čítanie) po dokončení.

## 6. Vyriešené otvorené detaily (a)–(e)

- **(a) Zoznam všetkých používateľov pre „Vlastník":** `Users.loadUsersForCurrentCompanyIncludeExternalAndInactiveUsers` (`users.js:340-342` → `loadUsersForCurrentCompany(true, false, true, false, …)` `:272-307`; server vracia aj blokovaných vďaka filtru `includeInactive`, `SystemUserService.java:1469-1477`). `allUsers` z `editExternalRequestBase.js:74,1684` je len aktívni a interní (`users.js:336`) → nedostačuje (D4). `ui-select` (single) to zvládne: rovnaký vzor s `filter`/`orderBy` na `formattedName` už používa schvaľovateľský výber (`editExternalRequestBase.html:712`). Objekty používateľov sú veľké → mapovať na `{id, formattedName}`.
- **(b) Registrácia skriptov:** len `app/index.html` (usemin blok `scripts/scripts.js`, `:166-991`); `Gruntfile.js` nemá zoznam súborov (`useminPrepare` číta `index.html`, `:180-194`). Služba za `webStorage.js` (`:180`), kontrolér popupu za `confirmanceCommentDetailDialogController.js` (`:694`). Žiadny nový route, žiadna úprava `ng.app.js`.
- **(c) Suma ≥ 0, max 2 desatinné miesta (AC 12):** existujúci `validateString(evt, input, regex)` (`app.js:1845-1859`, rovnako sa používa `validateDecimal` v `editInternalRequestItem.html:54`) s regexom `^\d{0,15}([,.]\d{0,2})?$` na `keypress` (zakáže znamienko, písmená a 3. desatinné miesto) + `ng-pattern` (zachytí vloženie/paste; precedens `editUser.html:20`). Direktíva `formattedNumericInput` nevyhovuje (D5), `decimal-input` by `0` a prázdnu hodnotu zmenila na `NaN`/falsy — preto model ako text a konverzia až v službe.
- **(d) Obmedzenie na route `All` v zdieľanom kontroléri:** kontrolér `ExternalRequestsTableController` sa inštancuje cez `ng-controller` v oboch šablónach (CPS aj non-CPS); tlačidlo je len v CPS šablóne (non-CPS DOM sa nemení). Stránka renderuje CPS direktívu len keď `isCPS` (`yearlyExternalRequestsCollecting.html:37`). Route sa rozlišuje cez `$routeParams.filter` (`All` vs `ForConfirmation`, `constants.js:871,877`). Obmedzenie je na troch miestach: viditeľnosť tlačidla (`showAdvancedFilterButton`), uplatnenie v dotaze (guard v `externalRequests.js`, D1) a invariant/handler (`advancedFilterApplies()`).
- **(e) Odchod z modulu:** `$routeChangeSuccess` + `current.$$route.originalPath` bez `/planningExternal/` → `clear()` (precedens `main.js:415-427`). Všetky trasy modulu (`ng.app.js:708-712`) majú prefix, detail žiadosti je pod ním, takže návrat z detailu stav zachová. Pozor: detail otvorený mimo modulu (otvorené úlohy, `openTaskTable.js:300`) sa vracia na pôvodnú stránku mimo modulu — stav tam nevzniká.

## 7. Pasce (zhrnutie, každá má test v sekcii 8)

1. Nový `fieldName` bez `tryGetFilterByNameAndMarkAsNotEntityFilter` → `IllegalArgumentException` v `BaseDao` (B2).
2. `%` a `_` v hodnote sa správajú ako wildcard rovnako ako v ostatných filtroch (D11) — T06–T08 to len zaznamenajú.
3. `FilterHelper` `between`/`processOneFilter` zahadzuje `0` — nepoužiť; testovať prázdny reťazec vs. `'0'` — T14.
4. `FILTER_OR_SEARCH_CHANGED` sa vyšle aj po programovom vyčistení (`searchAndFilter.js:53-88`, 500 ms) — rieši invariant + voliteľný guard (F5) — T24.
5. Stale `help` v `WebStorage` ak sa model nevyčistí pred `storeFilterAndDoReload` — T24, T29.
6. „Súvisiaca požiadavka" volá `storeFilterAndDoReload` bez udalosti (`externalRequestsTable.js:161-171`) — rieši invariant — T26.
7. Zlúčené stavy sú polia v číselníku (`codebookGenerator.js:3821-3847`) → splošťiť pred odoslaním (F1) — T12.
8. Stav medzi kartami `All` ↔ `ForConfirmation` (D1) — T32.
9. `ui-select`: vyčistenie single výberu cez `undefined` (nie `null`); `false` ako hodnota ZFK „Nie" musí zostať vybraná — T11.
10. Zdieľaný kontrolér: žiadna zmena správania non-CPS tabuľky (T35).
11. Popup sa pri aktívnom filtri predvypĺňa aplikovanými hodnotami (D7) — dostane kópiu (`getForEdit()`), aby „Zrušiť" nesmel filter zmeniť (AC 22) — T05.
12. „Bez diakritiky" (AC 5/6) kód nerieši, rovnako ako existujúce filtre (D9) — T06.

---

## 8. Verifikačný plán

### 8.1 Statické kontroly
- Server: `mvn -q -DskipTests clean package` pod JDK 8 → úspech; `git diff --stat` = 2 súbory (`ExternalRequest.java`, `ExternalRequestDao.java`), žiadny Liquibase, žiadna zmena `ApplicationConfig.java`/`persistence.xml`.
- Klient: JSHint podľa F7; `git diff --stat` = `externalRequestsTable.js`, `externalRequests.js`, `externalRequestsTableCps.html`, `index.html`, `sk.js`, `en.js` + 3 nové súbory (služba, kontrolér popupu, šablóna popupu); `externalRequestsTable.html` nedotknutý.

### 8.2 Overenie dátumových typov a súm proti testovacej DB (MySQL)

```sql
-- Q1: rozdelenie stavov (očakávať 17 v 202 a 4 v 203 na teste)
SELECT status, COUNT(*) FROM external_request
 WHERE soft_deleted = 0 OR soft_deleted IS NULL GROUP BY status;

-- Q2: ZFK ukončená = MAX dátum schváleného kroku (2 = Confirmed, 5 = ConditionallyConfirmed);
--     očakávať 17 + 4 riadkov, všetky s nenulovým dátumom
SELECT r.id, r.status,
       (SELECT MAX(s.creation_datetime) FROM external_request_confirmance_step s
         WHERE s.external_request_id = r.id AND s.status IN (2, 5)) AS fk_finished
  FROM external_request r
 WHERE r.status IN (202, 203) AND (r.soft_deleted = 0 OR r.soft_deleted IS NULL);

-- Q3: typy aktivít (103 = vybavená, 203 = vybavená po ZFK)
SELECT type, COUNT(*) FROM external_request_activity GROUP BY type;

-- Q4: počty pre konkrétny mesiac (porovnať s totalCount v UI pre CPS RP, ktorý vidí všetko)
SELECT COUNT(DISTINCT r.id) FROM external_request r
  JOIN external_request_activity a ON a.external_request_id = r.id AND a.type = 103
 WHERE a.creation_datetime >= '2026-01-01' AND a.creation_datetime < '2026-02-01'
   AND (r.soft_deleted = 0 OR r.soft_deleted IS NULL);   -- zopakovať s a.type = 203

-- Q5: sumy: NULL / nula / kladné
SELECT SUM(income IS NULL), SUM(income = 0), SUM(income > 0),
       SUM(expenses IS NULL), SUM(expenses = 0), SUM(expenses > 0)
  FROM external_request WHERE soft_deleted = 0 OR soft_deleted IS NULL;

```

- Ak na teste nie je dosť dát na T06–T08, T14, T18–T20, doplniť dáta (INSERT je povolený) alebo vytvoriť požiadavky cez UI; nič iné v DB sa nemení.
- Q2 potvrdzuje, že „ZFK ukončená" má pre všetky relevantné požiadavky dátum; požiadavka v 202 bez kroku (`checkConfirmationStateCps`) dátum nemá a pri tomto filtri sa nezobrazí (AC 16).

### 8.3 Mapovanie 29 AC na kroky a testy

| AC | Požiadavka (skrátene) | Kroky | Testy |
|---|---|---|---|
| 1 | Tlačidlo „Rozšírené vyhľadávanie" v pravej časti lišty | F6, F4 | T01 |
| 2 | Klik otvorí popup „Rozšírený filter" | F5 (`showAdvancedFilter`), F3, F4 | T01, T03 |
| 3 | Popup obsahuje všetkých 11 atribútov z 3.2 v danom type filtrovania | F3, F4 | T03 |
| 4 | Každý atribút má vpravo ✖, ktorá vymaže jeho hodnotu | F3 | T03 |
| 5 | Texty (Kód, IČO, Názov org., Číslo dokladu): obsahuje, case-insensitive, bez diakritiky, `%` a `_` bežné znaky | B2, B3, F1; case/diakritika sa nerieši (**D9**), escapovanie sa nerobí (**D11**) | T06, T07 |
| 6 | Popis: v tikete „fulltext, viac slov = OR" — chyba v zadaní, platí obyčajné obsahuje (D10) | B3, F1; (**D9**) | T08 |
| 7 | Organizácia (IČO/Názov) = organizácia žiadateľa | B3 (join `organizationDirectory`, O10) | T07 |
| 8 | Vlastník = jedna osoba zo všetkých používateľov | F3 (loader používateľov, single), F1 (`creationAuthorId`) | T10 |
| 9 | Druh požiadavky z číselníka | F3 (single), F1 (`type`) | T09 |
| 10 | Stav dynamicky z číselníka, viac hodnôt = OR | F3 (`statusCodebookName`, multi), F1 (splošťovanie) | T12 |
| 11 | Základná finančná kontrola Áno / Nie | F3, F1 | T11 |
| 12 | Príjmy/Výdavky: jeden typ, interval Od–Do, hranice vrátane, vstup bez záporných a >2 desatinných, 0 povolená | B4, F1, F3 (sumový vstup, 6c) | T13, T14, T16 |
| 13 | AND medzi vyplnenými atribútmi | B2 (AND zoznam predikátov), F1 | T22 |
| 14 | Dátum: 4 typy + Od–Do, predvolený „Dátum požiadavky" | B5, F1, F3, F4 | T04, T17–T20 |
| 15 | Len Od alebo len Do; oba okraje vrátane | B5, F1 (`toExclusive`) | T17, T21 |
| 16 | Požiadavky bez zvoleného dátumu sa pri aktívnom dátumovom filtri nezobrazia | B5 (`EXISTS`, `MAX`, `requestDate` porovnanie) | T17–T21 |
| 17 | Naraz len jeden typ dátumu | F3, F1 (jeden `date.type`) | T04, T22 |
| 18 | „Vybavená" (bez ZFK) vs. „po vykonaní ZFK" disjunktné | B5 (aktivita 103 vs. 203) | T18, T19 |
| 19 | Od > Do (dátum aj suma) = prázdny výsledok bez hlášky | B4, B5, F3 (bez validácie) | T15 |
| 20 | Od–Do bez zvoleného typu = predvolený typ | F1 (`getEmpty`, defaulty), F3 | T04 |
| 21 | „Použiť" aplikuje, zatvorí popup, nahradí a vyčistí základný filter | F3 (`close`), F5 (`applyAdvancedFilter`, `clearBasicFilters`) | T24 |
| 22 | „Zrušiť" zatvorí popup bez zmeny aktuálneho filtra | F3 (`dismiss`), F5 | T05 |
| 23 | Prázdne „Použiť" pri aktívnom filtri filter zruší | F1 (`set`→`clear`), F5 | T23 |
| 24 | „×" vždy zobrazená: sivá/aktívna; klik filter zruší | F6, F5 (`clearAdvancedFilter`) | T02, T27 |
| 25 | Aktívny rozšírený + použitie základného → rozšírený sa zruší, „×" zosivie | F5 (invariant v `reloadRequests`) | T25, T26 |
| 26 | _Zmenené (D7):_ pri aktívnom filtri sa popup otvorí s aplikovanými hodnotami, inak prázdny | F3, F5 (`resolve` = `getForEdit()`), D7 | T05 |
| 27 | Po návrate z detailu ostane filter; po refreshi/odchode z modulu sa zruší | F1 (pamäť + `$routeChangeSuccess`), F5 | T29, T30, T31, T33 |
| 28 | Len nad viditeľnými požiadavkami; viditeľnosť sa nerozširuje | B2 (len AND, servis nezmenený) | T34 |
| 29 | „Vytvoriť" a ikona základného filtra bez zmeny | F6 (nemení sa), F5 (inertnosť) | T01, T35 |

### 8.4 Manuálny test v aplikácii

| Test | Čo overiť | Kroky / očakávanie | AC |
|---|---|---|---|
| T01 | Tlačidlo na správnom mieste | CPS zoznam `All`: „Rozšírené vyhľadávanie" v pravej časti lišty vedľa lievika; na karte „na schválenie" tlačidlo ani „×" nie je; „Vytvoriť" a lievik nezmenené | 1, 2, 29 |
| T02 | „×" farba a stav | Vždy viditeľné; bez filtra sivé a nekliknuteľné; s filtrom aktívny (`filter-x-button`) štýl; po kliknutí filter zrušený a znova sivé | 24 |
| T03 | Popup obsah | 11 atribútov v poradí z tiketu 3.2, správne typy (Druh/Vlastník single, Stav multi, ZFK Áno/Nie, Príjmy/Výdavky a Dátum s výberom typu + Od/Do); ✖ pri každom atribúte resetuje len jeho hodnotu (pri Od/Do každé zvlášť, typ ostáva); záhlavné „×" zatvorí popup | 2, 3, 4 |
| T04 | Predvolené typy a „bez zvoleného typu" | Nové otvorenie: dátum = Dátum požiadavky, suma = Príjmy; vyplniť len Od/Do bez zmeny typu → platí predvolený typ; typy dátumu v poradí Dátum požiadavky, ZFK ukončená, Vybavená, Vybavená – po vykonaní ZFK; naraz sa dá zvoliť len jeden typ | 14, 17, 20 |
| T05 | Predvyplnený popup a „Zrušiť" | Po „Použiť" a opätovnom otvorení sú v poliach aplikované hodnoty (aj Druh, Vlastník, Stav so zlúčenými stavmi, ZFK Nie, sumy, dátumy a ich typy); zmena a „Zrušiť" aplikovaný filter nezmení (zoznam aj červené „×" bez zmeny); po „×" je popup prázdny | 22, 26 |
| T06 | Kód | Čiastočná zhoda; veľkosť písmen a diakritika — len zaznamenať správanie (D9, D11) | 5 |
| T07 | Organizácia – IČO/Názov, Číslo dokladu | Ako T06; organizácia = tá, ktorá je v stĺpcoch zoznamu (O10) | 5, 7 |
| T08 | Popis | čiastočná zhoda (aj fráza s medzerou); prázdne = bez filtra | 6 |
| T09 | Druh požiadavky | Výber jednej hodnoty z číselníka | 9 |
| T10 | Vlastník | Výber jednej osoby zo všetkých používateľov (aj neaktívny/externý vlastník) | 8 |
| T11 | Základná finančná kontrola | „Áno" aj „Nie" (hodnota `false` musí filtrovať); ✖ vráti na „nevybrané" | 11 |
| T12 | Stav | Viac stavov = OR; zlúčené (Neodoslaná = 100+200, Vybavená = 103+203, Zrušená = 105+205); EES inštancia ukáže EES názvy | 10 |
| T13 | Suma Od/Do | Len Od, len Do, obe; hranice vrátane; jeden typ naraz (Príjmy/Výdavky) | 12 |
| T14 | Nula v sume | `Od = 0`, `Do = 0`, `Od = Do = 0`; `0` sa nezahodí | 12 |
| T15 | Od > Do (suma aj dátum) | Prázdny zoznam, bez hlášky/chyby | 19 |
| T16 | Obmedzenie vstupu sumy | Nejde zadať `-`, písmená, 3. desatinné miesto; `,` aj `.`; paste neplatnej hodnoty zablokuje „Použiť" bez hlášky (O12) | 12 |
| T17 | Dátum požiadavky | Od/Do; požiadavka z dňa „Do" (aj 23:59) je zahrnutá, deň po nie; požiadavka bez dátumu sa nezobrazí | 14, 15, 16 |
| T18 | Vybavená | Zhoda s Q4 (typ 103) | 14, 16, 18 |
| T19 | Vybavená – po vykonaní ZFK | Zhoda s Q4 (typ 203); disjunktné s T18 | 14, 16, 18 |
| T20 | ZFK ukončená | Iba stavy 202/203; dátum = Q2; požiadavky v iných stavoch sa nezobrazia | 14, 16 |
| T21 | Len Od / len Do pri dátume | Otvorený interval | 15, 16 |
| T22 | Kombinácia viacerých polí | Všetky podmienky naraz (AND), napr. Stav + Suma + Dátum; v jednom filtri jeden typ dátumu a jedna suma | 13, 17 |
| T23 | Prázdne „Použiť" | Pri aktívnom filtri prázdne „Použiť" ho zruší (rovnako ako „×"); základný filter sa nemení (O3) | 23 |
| T24 | Nahradenie základného filtra | Pri vyplnenom základnom filtri „Použiť" ho vyčistí: stĺpcové vstupy prázdne, lievik nie je červený, v `WebStorage` (`yearlyExternalRequestsCollecting`) je prázdny filter; zoznam nezačne blikať ani sa rozšírený filter hneď nezruší | 21 |
| T25 | Základný zruší rozšírený | Pri aktívnom rozšírenom filtri písanie do stĺpcového filtra → rozšírený sa zruší („×" sivé), zoznam sa filtruje len základným | 25 |
| T26 | Súvisiaca požiadavka | Pri aktívnom rozšírenom filtri klik na odkaz „Súvisiaca požiadavka" → rozšírený zrušený, základný `uniqCode` nastavený | 25 |
| T27 | „×" | Zruší len rozšírený filter, vráti stránku 1 a plný zoznam | 24 |
| T28 | Stránkovanie, zoradenie | Prechod na 2. stranu zachová filter; „Použiť" vráti stránku 1; zoradenie (`id desc`) a počet na stranu nezmenené; `totalCount` zodpovedá filtru (rozhodnutie návrhu, nie samostatné AC) | — |
| T29 | Návrat z detailu | Otvoriť detail a vrátiť sa (tlačidlo späť aj uloženie) → filter a stránka zachované; základný filter prázdny | 27 |
| T30 | Refresh (F5) | Rozšírený filter zmizne, zoznam je bez filtra | 27 |
| T31 | Odchod z modulu | Domov/iný modul a späť → filter zrušený | 27 |
| T32 | Medzi kartami | `All` → „na schválenie" → `All`: karta „na schválenie" nie je filtrom dotknutá; po návrate na `All` filter platí (predpoklad O4) | — |
| T33 | Odhlásenie a prihlásenie | Filter po novom prihlásení neexistuje | 27 |
| T34 | Viditeľnosť | Ako autor (len vlastné), pozorovateľ, CPS zodpovedná osoba: výsledky filtra sú podmnožinou toho, čo daná rola vidí bez filtra; počty zodpovedajú SQL | 28 |
| T35 | Regresia | Existujúce stĺpcové filtre a stránkovanie fungujú ako predtým; „Vytvoriť" a lievik nezmenené; non-CPS tabuľka nedotknutá (`git diff` bez `externalRequestsTable.html`; všetky nové vetvy v kontroléri sú podmienené `advancedFilterApplies()`/route `All`) | 29 |

Pred každým testom skontrolovať konzolu prehliadača (žiadna chyba) a pri B-testoch SQL v `server.log`.

---

## 9. Riziká

| # | Riziko | Zmiernenie |
|---|---|---|
| R2 | _Zrušené (D11): escapovanie sa nerobí, `LIKE ... ESCAPE` sa nepoužíva._ | — |
| R3 | Skalárny subquery `MAX` v porovnaní cez Criteria API. | Záložná formulácia „najneskorší schválený krok" cez vnorený `NOT EXISTS` (B5). |
| R4 | Časové pásmo/DST pri hraniciach dňa: klient počíta lokálnu polnoc, server porovnáva s `DATETIME` v pásme JVM. | Rovnaké správanie ako existujúce dátumové filtre; overiť T17 na hranici dňa. |
| R5 | Reset lokálneho stavu direktív cez `angular.element(...).scope()` je krehký (globálny DOM selektor). | Precedens existuje; vhodné len kým je na stránke jedna tabuľka. Záloha: znovu vyrenderovať riadok filtrov (`ng-if` prepínač) — vyžaduje opatrnosť so scope reťazcom `$parent.$parent` v direktívach. |
| R6 | Zdieľaný kontrolér (CPS aj non-CPS). | Všetko podmienené route `All` + `isActive()`; kód reviewer kontroluje inertnosť; non-CPS šablóna nedotknutá. |
| R7 | `WebStorage` kľúč `yearlyExternalRequestsCollecting` je zdieľaný kartami `All` a `ForConfirmation` (existujúce správanie). | Vyčistenie základného filtra pri „Použiť" sa prejaví aj na druhej karte — nezmenené, len ho poznať (T32). |
| R8 | Dlhý zoznam používateľov v `ui-select` (bez stránkovania). | Ľahké objekty + filter na klientovi; rovnaký vzor ako schvaľovatelia. |
| R9 | Nový `EXISTS`/`MAX` subquery bez indexu na `external_request_activity(external_request_id, type)`. | Malé tabuľky; zmena schémy je mimo rozsahu — ak by bol výkon problém, samostatný tiket. |
| R10 | `ui-select` a hodnota `false`/zlúčené stavy (polia ako model). | T11, T12; v prípade problému použiť multi-výber nad `booleanVerbal` ako stĺpcový filter. |

## 10. Otvorené otázky — stav po doplnení tiketu

| # | Otázka | Stav / rozhodnutie |
|---|---|---|
| O1 | Poradie a popisky polí, single/multi, AC | **Uzavreté** textom tiketu: Druh = single z číselníka, Vlastník = single, Stav = multi, ZFK = Áno/Nie; poradie a typy v F3, popisky v F4, AC v 8.3. |
| O2 | Požiadavky s prázdnou sumou (`NULL`) pri filtri Príjmy/Výdavky (aj pri `Od = 0`) | **Predpoklad na potvrdenie:** tiket to nešpecifikuje; `NULL` sa nezobrazí (prirodzené správanie intervalu; „porovnáva sa suma zadaná v požiadavke"). |
| O3 | Prázdne „Použiť" a základný filter | **Predpoklad na potvrdenie:** tiket hovorí, že prázdne „Použiť" robí to isté ako „×" (zruší rozšírený filter); základný filter sa pri prázdnom „Použiť" nemení. |
| O4 | Stav pri prepnutí kariet `All` ↔ `ForConfirmation` | **Predpoklad na potvrdenie:** tiket rieši len odchod z modulu (zrušenie); filter ostáva v pamäti, uplatňuje sa len na route `All` (D1). |
| O5 | Neplatný/neúplný dátum | **Ponechané:** zablokovať „Použiť" s `state-error` (tiket text, ktorý nie je platný dátum, nerieši). |
| O6 | Zoznam „Vlastník" | **Ponechané:** všetci používatelia podniku vrátane neaktívnych a externých (tiket: „zo všetkých používateľov"). |
| O7 | Poradie `[Rozšírené vyhľadávanie] [×] [lievik]` | **Vec na overenie s používateľom** na obrázku (tiket: „v pravej časti lišty", „×" „vedľa tlačidla"); nie blokátor. |
| O8 | Dátum a suma s výberom typu, jeden typ naraz | **Potvrdené** (AC 14, AC 17, AC 20; predvolené Dátum požiadavky a Príjmy). |
| O9 | „Bez diakritiky" (AC 5, AC 6) | **Uzavreté (používateľ):** nerieši sa nad rámec existujúcich filtrov; kolácia ani Docker sa neskúmajú (D9). |
| O10 | **Nová:** „Organizácia = organizácia žiadateľa" | **Predpoklad na potvrdenie:** filtruje sa `ExternalRequest.organizationDirectory` (ten istý atribút ako stĺpce „Organizácia – IČO/Názov" a stĺpcový filter). Pri vytvorení sa `organizationDirectoryId` nastavuje na OvZP príjemcu (`ExternalRequestService.java:170-172`), takže pri CPS požiadavkách ide o príjemcu — potvrdiť, že „žiadateľ" = organizácia zobrazená v stĺpci. |
| O11 | **Nová, kozmetická:** popisky „Organizácia – IČO/Názov" (v tikete pomlčka „–", v existujúcich hodnotách „-") a „Číslo dokladu" (existujúci kľúč „Číslo dokladu EIS") | **Predvolené:** existujúce kľúče pre organizáciu, nový kľúč pre „Číslo dokladu"; overiť na obrázku, nie blokátor. |
| O12 | **Nová:** vloženie (paste) neplatnej sumy — tiket „neplatný vstup sa nedovolí zadať, netreba post-validáciu" | **Predpoklad na potvrdenie:** `keypress` zakáže neplatné znaky; `ng-pattern` pri vloženej neplatnej hodnote len označí pole a zablokuje „Použiť" (bez hlášky). Alternatíva: zablokovať vkladanie (`onpaste`). |

## 11. Odovzdanie a commity

1. Implementácia podľa krokov (backend `executor-backend`, frontend `executor-frontend`), potom `code-reviewer-backend`/`code-reviewer-frontend`.
2. `acceptance-test-checklist` z 29 AC (podklad: 8.3 a 8.4) → ručný test používateľom v bežiacej aplikácii (WildFly s novým WAR; klient `grunt serve`).
3. **Commit len po potvrdení používateľom**, jeden na repozitár, rovnaká správa, bez miešania tiketov:
   - `publicERANET-server` (vetva `trnavavuc_test`): `feat(EP-13665, EP-13666): add advanced filter to CPS external requests list`
   - `publicERANET-client` (vetva `trnavavuc_test`): `feat(EP-13665, EP-13666): add advanced filter to CPS external requests list`
4. Nespúšťať `git add` na adresáre `publicERANET-*` z umbrella repozitára. Tento plán (`docs/plans/`) a `docs/TICKETS.md` sa necommitujú bez pokynu.
