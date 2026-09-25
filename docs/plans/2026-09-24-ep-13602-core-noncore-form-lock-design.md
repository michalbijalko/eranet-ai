# EP-13602 — PnO: oprávnenia na úpravu atribútu CORE/NONCORE

**Story:** EP-13602 · **Dev:** EP-13608 · **Epic:** EP-13600 (SEPS – zmenové požiadavky 09/2026)
**Dátum:** 2026-09-24 · **Nadväzuje na:** EP-13601 (`2026-09-22-ep-13601-core-noncore-form-design.md`)

## Zadanie

Formulár CORE/NONCORE smie vyplniť a meniť len autor požiadavky a len v stave „neodoslaná".
Po odoslaní je zamknutý aj pre autora. Ktokoľvek iný si popup vie otvoriť, vidí odpovede,
ale prvky sú disabled a Uložiť nie je dostupné. Ostatné atribúty požiadavky sa správajú
ako doteraz — je to výnimka len pre tento atribút.

## Rozhodnutia

- **Editovať smie výhradne autor v stave „neodoslaná"** — bez výnimky pre zodpovednú osobu
  (referenta VO), ktorá má inak editáciu povolenú vždy. Ticket ju nespomína; zámok je viazaný
  na stav požiadavky, nie na rolu.
- **Legacy číselníkový select ostáva bez zmeny.** Staré požiadavky bez formulára sa správajú
  ako doteraz (select riadi `isEditDisabled`); zámok sa týka formulára.
- **Len klient.** Serverový guard sa nerobí — `coreNoncoreForm` sa pri uložení inou rolou
  len vráti nezmenený, a guard by zasahoval do spoločnej ukladacej cesty všetkých atribútov.
- **`requiredFieldsValid()` sa nemení.** Odoslaná požiadavka má vždy vyplnený formulár alebo
  legacy hodnotu, takže schvaľovateľ sa na zamknutom povinnom poli nezasekne.
- **Úroveň schvaľovateľa sa nerozlišuje.**
- Formulár nemôže nechtiac zmazať ani `resetRequest()` — spúšťa sa len pri zmene typu,
  a tá je po odoslaní zamknutá (`isEditTypeDisabled`).

## Riešenie

`$scope.canEditCoreNoncoreForm()` v `editInternalProcurementRequest.js` — rovnaký výraz ako
`showSendForAcceptanceButton()`: `oldStatus === neodoslaná && (!request.id || isAuthor())`.
Rozhoduje stav pri načítaní, nie práve naklikaný stav. `calculateIfEditIsAllowed()` sa nemení.

Otvárač `openCoreNoncoreFormular()` stráži už len uloženú požiadavku (modál si ju ukladá sám)
a do modálu posiela resolve `readonly = !canEditCoreNoncoreForm()` — vzor
`ParticipantConditionInIPRequestPopupController`.

Modál: `$scope.isEditDisabled = readonly`, radiá `data-ng-disabled`, Uložiť `data-ng-if`.
Zrušiť a krížik zostávajú.

Riadok atribútu: ikona otvárača už nie je šedá podľa `isEditDisabled`, kurzor sa riadi
`request.id`. Label stĺpec (číslovanie) a legacy vetva sa nedotknú.
