# EP-13625 — Zákazka: predvyplnené podmienky účasti a požiadavky na ponuku

**Story:** EP-13625 · **Dev:** EP-13626 · **Epic:** EP-13600 (SEPS – zmenové požiadavky 09/2026)
**Dátum:** 2026-09-22

## Zadanie

Pri vytvorení novej zákazky sa majú sekcie *Podmienky účasti* a *Požiadavky na ponuku*
predvyplniť odkazom na súťažné podklady a mať definovaný predvolený zapnutý/vypnutý stav.

| Sekcia | Predvyplnený text | Default stav |
|---|---|---|
| Požiadavky na ponuku | „Požiadavky na ponuku sú uvedené v samostatnom dokumente „Súťažné podklady“.“ | zapnuté |
| JED | bez textu | vypnuté (bez zmeny) |
| Osobné postavenie (§32) | „Podmienky účasti sú uvedené v samostatnom dokumente „Súťažné podklady“.“ | vypnuté |
| Finančné a ekonomické postavenie (§33) | to isté | vypnuté |
| Technická alebo odborná spôsobilosť (§34) | to isté (už existuje) | **zmena zo zapnuté na vypnuté** |
| Ďalšie informácie a dôvody na vylúčenie | to isté | zapnuté |

## Rozhodnutia

- **Rozsah: len Interný postup.** Tabuľka „Aktuálny stav“ v tickete popisuje dnešnú IRA vetvu
  (§34 s textom a zapnutý), ktorá vznikla v EP-13251. Ostatné typy zákaziek sa nemenia.
- **Platí aj pri zákazke založenej z IO/VO požiadavky**, nielen pri prázdnej novej zákazke.
- **Nový riadok v Požiadavkách na ponuku patrí do obálky *Ponuka/všeobecné*** (`DOMAIN_CRITERIA`),
  kde sedia všetky ostatné predvyplnené riadky Interného postupu.

## Ako to v kóde funguje

„Zapnuté/vypnuté“ nie je stav sekcie — je to `inUse` na jednotlivom riadku (stĺpec *Vyžadovať*).
Sekcia sa len skryje, ak je prázdna. Texty aj počiatočný stav vyrába server pri založení zákazky,
klient iba renderuje, čo dostane. Zmena je preto čisto serverová: bez klienta, bez Liquibase,
bez zásahu do schémy.

Vstupné body: `ProcurementService.create()` → `ParticipantConditionInProcurementService.setupConditionForNewProcurement()`
a `OfferConditionInProcurementService.setupConditionForNewProcurement()`.

## Zmeny

### Podmienky účasti

`ParticipantConditionInProcurement` — nové identifikátory vedľa existujúceho `IRATD`:
`IRAPD` (§32), `IRAFD` (§33), `IRAED` (ďalšie informácie).

`ParticipantConditionInProcurementService`:

- text „Podmienky účasti sú uvedené…“ vytiahnutý do konštanty `IRA_DEFAULT_CONDITION_TEXT`
  a použitý na všetkých štyroch miestach,
- v IRA vetve `getParticipationConditions()` pribudli tri riadky, každý ako prvý vo svojej doméne:
  `IRAPD` (`inUse = false`), `IRAFD` (`inUse = false`), `IRAED` (`inUse = true`),
- `IRATD` má `setInUse(false)` namiesto `true`,
- `setupConditionForNewProcurementEPRequest` prepúšťa okrem `IRATD` aj `IRAPD` a `IRAFD`
  (`setupConditionForNewProcurementIPRequest` ich prepustí sám — filtruje len `DOMAIN_TECHNICAL`).

§32 musí mať `inUse` nastavené explicitne na `false`: default pre `DOMAIN_PERSONAL` v IRA vetve
je `true`, takže ponechanie `null` by riadok zaplo. Rovnako `IRAED` potrebuje explicitné `true`,
lebo default domény `DOMAIN_EXCLUDE` je `false`.

### Požiadavky na ponuku

`OfferConditionInProcurement` — nový identifikátor `IRAOD`.

`OfferConditionInProcurementService`:

- `getConditionsForIRA()` pridáva `IRAOD` ako prvý riadok v `DOMAIN_CRITERIA` s `inUse = true`,
- seedovací cyklus na SEPS inštancii všetkým požiadavkám prepisuje `inUse` na `false`;
  `IRAOD` je z tohto prepisu vyňatý, inak by nová požiadavka nikdy nezostala zapnutá.

## Čo sa nemení

- Existujúce zákazky — seedovanie beží len pri založení, takže netreba migráciu (AK 8).
- Duplikovanie zákazky kopíruje riadky tak, ako sú.
- JED, ostatné typy zákaziek, klient, databázová schéma.
