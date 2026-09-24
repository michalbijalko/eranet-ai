# EP-13601 — PnO IO: atribút CORE/NONCORE určovaný formulárom

**Story:** EP-13601 · **Dev:** EP-13606 · **Epic:** EP-13600 (SEPS – zmenové požiadavky 09/2026)
**Dátum:** 2026-09-22

## Zadanie

Ručný výber hodnoty „Core/noncore" z číselníka v požiadavke na obstarávanie sa nahrádza
formulárom piatich otázok ÁNO/NIE. Aspoň jedna odpoveď ÁNO → CORE, všetkých päť NIE → NONCORE.
Hodnotu nie je možné meniť inak než vyplnením a uložením formulára.

## Rozhodnutia

- **Len IO** (interná požiadavka). VO má iný číselník (Core / Zmiešaná zákazka) a ticket sa
  volá „PnO IO".
- **Všetkých päť otázok je povinných** pred uložením. Akceptačné kritérium 4 („aspoň jedna
  otázka") je nepresná formulácia, nie pravidlo o čiastočnom uložení.
- **Do `coreNoncore` sa už nezapisuje nič.** Atribút je len read-only výsledok formulára.
  Staré požiadavky si tým podržia svoju hodnotu vrátane „Zmiešané zákazky", ktorú už nikto
  nemôže nanovo vybrať — čím sa rieši otvorený bod ticketu.
- **Odpovede sa ukladajú ako JSON v jednom stĺpci**, nie do samostatnej tabuľky. Znenie otázok
  sa neukladá: protokol je PDF uložený ako súbor pri požiadavke, takže sa nikdy nepregeneruje,
  a nikde inde sa historické znenie nevyžaduje.
- **PDF protokol sa v tomto tickete nemení** — rieši ho EP-13603. Kým nepríde, protokol novej
  požiadavky vypíše pri Core/noncore prázdnu hodnotu.
- **Do histórie ide len výsledná hodnota** pod dnešným `fieldId = "coreNoncore"`.

## Úložisko

Nový stĺpec `core_noncore_form` (`TEXT`, nullable) na `internal_procurement_request`,
Liquibase changeset `src/main/sql/2.5.0/db.changelog-EP13606.xml`, autor `m.bijalko`.

```json
{"transmissionSystem":true,"inseparablePart":false,"sectorActivity":false,
 "localPurpose":false,"necessaryOperation":false}
```

Vyhodnotenie žije na jednom mieste — statická metóda `InternalProcurementRequest.evaluateCoreNoncore(String)`
(Gson 2.6.1 je v `eranet-domain` k dispozícii): aspoň jedno `true` → `0` CORE, všetkých päť
`false` → `1` NONCORE, prázdny formulár → `null`. `@Transient` getter vystaví výsledok klientovi.

## Zobrazenie atribútu

| Stav požiadavky | Zobrazenie |
|---|---|
| vyplnený formulár | výsledok (Core / Noncore) + tlačidlo na otvorenie formulára |
| formulár prázdny, `coreNoncore` vyplnené | pôvodný číselníkový výber (legacy) |
| ani jedno | „Kliknutím na tlačidlo vyplňte formulár" + tlačidlo |

## Klient

- Riadok atribútu v `editInternalProcurementRequest.html`: **label stĺpec `col-3-ob` ostáva
  nedotknutý**, inak atribút vypadne z číslovania (CSS `counter-increment`, EP-13248). Mení sa
  len tretia sekcia s ovládacím prvkom.
- Modál podľa vzoru `commonlyAvailableGoodsFormular` — tabuľka piatich otázok s radio dvojicou
  Áno/Nie, úvodný text, spodná poznámka, Uložiť/Zrušiť.
- Modál si požiadavku **ukladá sám** cez `InternalProcurementRequests.saveInternalProcurementRequest()`
  a volajúci potom prekreslí obrazovku — rovnako ako referenčný modál. Formulár tým nie je blokovaný
  kontrolou ostatných povinných polí, ktorá beží v `continueSave()` obrazovky.
- Povinnosť atribútu: dnešná kontrola na `request.coreNoncore` sa prepíše na „vyplnený formulár
  alebo legacy hodnota".
- História: záznam sa zapíše explicitne pri uložení formulára — dnešný mechanizmus sleduje
  `$dirty` form controls a takto vypočítanú hodnotu by nezachytil.

## Štatistiky

`StatisticsService` pre pole `coreNoncoreIP` vyhodnotí JSON, ak je vyplnený, inak použije stĺpec
`core_noncore`. Preklad na „Core" / „Noncore" cez existujúci číselník zostáva.
