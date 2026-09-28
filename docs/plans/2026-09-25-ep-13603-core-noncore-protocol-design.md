# EP-13603 — PnO IO: CORE/NONCORE v PDF protokole

**Story:** EP-13603 · **Dev:** EP-13610 · **Epic:** EP-13600 (SEPS – zmenové požiadavky 09/2026)
**Dátum:** 2026-09-25, prepracované 2026-09-28 · **Nadväzuje na:** EP-13601 (formulár), EP-13602 (zámok formulára)

## Zadanie

Pri atribúte „Core/noncore" v PDF protokole z PnO sa okrem výslednej hodnoty vypíšu otázky formulára
s odpoveďou „Odpoveď: áno / nie" a pod nimi „Vypracoval formulár:" s titulom, menom a priezviskom
autora požiadavky. Ostatné časti protokolu sa nemenia. Len IO.

## Zistenia z kódu

- **Protokol sa generuje opakovane a vždy ako nový súbor** — automaticky pri prechode do
  ACCEPTED / DISMISSED (klient `continueSave`, aj e-mailové schválenie cez `generateFinalProtocol`)
  a ručne z menu (systémový admin vždy). `FileService.createInternal` len pridáva. Predpoklad
  z EP-13601, že sa protokol nikdy nepregeneruje, neplatí — znenie otázok „v čase vyplnenia"
  sa preto musí uložiť.
- Server nemá lokalizáciu — PDF služba píše slovenské literály, serverový zdroj textov sú
  číselníky v `CodebookService`.

## Rozhodnutia

- **Formulár ukladá celý dotazník, ako ho autor vyplnil** (mení formát z EP-13601, ktorý ešte
  nebol nasadený, preto bez spätnej kompatibility):
  ```json
  {"questions":[{"id":"transmissionSystem","text":"Týka sa predmet zákazky…","answer":true}, …]}
  ```
  Pridanie, odobratie alebo zmena otázok tak nezmení staré formuláre — vyhodnotenie, popup aj
  protokol prechádzajú uložený zoznam, nie pevný zoznam kľúčov. Zvažovaná alternatíva s verziou
  znenia a pevnými kľúčmi by po pridaní otázky zneplatnila všetky staré formuláre.
- **Znenie otázok nie je v prekladoch.** Predvolené otázky sú v klientskom `Constants`
  (`INTERNAL_PROCUREMENT_REQUEST_CORE_NONCORE_FORM_QUESTIONS`), vždy po slovensky; uložený
  formulár zobrazí svoje uložené znenie. Server má kópiu predvoleného znenia v `CodebookService`
  len pre protokol nevyplneného formulára — obe kópie treba držať zhodné (komentáre).
- **Vyhodnotenie:** aspoň jedno áno → Core, všetky zodpovedané a nie → Noncore; prázdny zoznam,
  chýbajúca odpoveď alebo poškodený JSON → bez výsledku.
- **Výsledná hodnota v protokole:** výsledok formulára, inak legacy `coreNoncore`
  (`getEffectiveCoreNoncore()`), preklad cez existujúci číselník.

| Prípad | Hodnota | Blok otázok | Vypracoval formulár |
|---|---|---|---|
| formulár vyplnený | výsledok formulára | uložené otázky + odpovede | autor požiadavky |
| stará požiadavka, len legacy hodnota | legacy (vrátane „Zmiešané zákazky") | nie | nie |
| nič nevyplnené | prázdna | predvolené otázky s prázdnym „Odpoveď:" | prázdne |

## Rozloženie (podľa screenshotu v tickete)

```
30. Core/noncore:            (tučne)
Noncore

Formulár:
   1.  <znenie otázky>        (odsadené, číslo a znenie zarovnané hore)
   Odpoveď: nie

   ...
Vypracoval formulár: Ing. Martin Oravec
```

Otázka je bezrámová tabuľka (číslo | znenie), aby zalomené riadky ostali odsadené — Aspose 16.10
nemá odsadenie ďalších riadkov. Meno cez `SystemUser.getPredefinedFieldFormat()`.

## Zmeny

- Server: `CoreNoncoreFormQuestion` (dto), `InternalProcurementRequest` (parsovanie zoznamu,
  vyhodnotenie, efektívna hodnota), `CodebookService` (predvolené znenie),
  `InternalProcurementRequestBasePdfGeneratingService` (vetva „Core/noncore" + blok formulára).
- Klient: `Constants` (predvolené otázky), `CoreNoncoreFormularController` a šablóna
  (`ng-repeat` nad otázkami), odstránené preklady `CORE_NONCORE_FORMULAR_QUESTION_1..5`.
