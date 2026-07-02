# Speylog — prosjektregler for Claude Code

Speylog er en bilingual (norsk/engelsk) PWA-fangstlogg for fluefiskere som setter ut igjen.
Magnus kommuniserer på norsk og foretrekker konsise svar.

## Arbeidsflyt (viktig)

1. **Alltid preview før implementering.** Vis et forslag (beskrivelse og/eller mockup) av
   endringen og vent på godkjenning før du endrer kode eller database.
2. Etter godkjenning: bygg endringen, og når den er ferdig og validert,
   **commit + push rett til main** (deployer live via GitHub Pages). Ingen PR.
3. Hold endringer små og fokuserte — én funksjon eller fiks om gangen.

## Arkitektur

- **Hele appen er én fil: `index.html`** — React 18 + Babel standalone, ingen byggetrinn.
  - Inline-styles via `S`/`t`-objekter, i18n via `STRINGS`-dictionary (nb/en), SVG-ikoner i `I`-objektet.
  - Outfit-font gjennomgående.
- **`sw.js`** — service worker. Cache-first for immutable storage-stier
  (`/storage/v1/object/public/catch-photos/`, `/avatars/`). `IMG_CACHE` skal ALDRI endres ved versjonsbump.
- **Backend: Supabase** (prosjekt `sygxotiqbljukaekiipc`) — Postgres, Auth (OTP), Storage, RLS med anon key.
- **Hosting:** GitHub Pages på app.speylog.com (dette repoet). Markedsside speylog.com ligger på one.com (eget).

## Release-rutine (obligatorisk ved hver endring i index.html)

1. Bump cache-versjonen i `sw.js`: mønster `speylog-debug-vNN` → `vNN+1`.
2. Bump den synlige versjonslabelen i `index.html` (finnes **to** steder, søk etter `>vNN<`).
3. Disse to skal alltid være i sync — stale SW har historisk skapt mye forvirring.

## Validering før commit

- Ekstraher `<script type="text/babel">`-blokken fra `index.html` og kjør den gjennom
  `@babel/core` med `@babel/preset-react`. Commit aldri hvis transformen feiler.
- NB: JSX-tekst tolker IKKE `\uXXXX`-escapes — bruk ekte tegn (°, ³, ↑) i JSX-tekst.
- Vær forsiktig med `str_replace`-lignende endringer: verifiser med grep før og etter.

## Vær- og vanndata (NVE/Frost/MET)

- Edge Function `fetch-conditions` (Supabase) har tre moduser:
  - `{ river, timestamp }` — måledata for ett tidspunkt (brukes ved lagring + live preview i skjemaet)
  - `{ backfill: true }` — fyller `conditions.measured` på inntil 8 fangster per kall
  - `{ rivers: true }` — vannføring nå + fiskeforhold-nivå + trend + regnvarsel, 15 min cache i `river_stations`
- **Alle moduser bruker kun `verified=true`-stasjoner** (godkjenningsflyt for brukerforslag, se under).
- **Fiskeforhold-nivå** (`level`: low/good/high/flood + `level_estimated`):
  admin-satte terskler `fish_min`/`fish_max` (m³/s) vinner; uten terskler brukes persentil-estimat
  (<p25=low, ≥p75=high, ≥p95=flood). Flom sjekkes alltid mot p95, også med terskler.
- **NVE-persentiler** hentes fra `HydAPI /Percentiles/{stasjon}/1001` én gang per stasjon og caches i
  `river_stations.flow_percentiles` som `{ "MMDD": [p25,p50,p75,p95] }`. Sentinel `{ none: true }` =
  stasjonen mangler statistikk (f.eks. Suldalslågen) — ingen badge. Nullstill kolonnen for re-fetch.
- **Regnvarsel** (`rain48`, mm neste 48 t) fra MET Locationforecast per stasjonskoordinat, cachet i
  `latest` (rain_at), maks ett MET-kall/time per stasjon. Krever identifiserende User-Agent.
  MET-lisensen krever attribusjon — «Værvarsel fra MET/Yr»-linjen i RiversView skal ikke fjernes.
  Regn-sirkelen i appen lenker til `pent.no/{lat},{lon}` (yr.no støtter ikke koordinat-URL-er).
- Tabellen `river_stations` mapper elvenavn → NVE-stasjons-ID. Navn/koordinater
  auto-fylles fra NVE ved første bruk.

## Elveforslag og godkjenning

- Brukere foreslår elver (RiversView, Sildre-lenke); insert med `verified=false` + `submitted_by`.
  Dup-sjekk klient-side: eksakt navn (case-insensitivt), stasjons-ID (også unik constraint i DB),
  og fuzzy (editDist ≤ 2) med «Legg til likevel»-bekreftelse.
- Admin godkjenner/avviser i admin.html → Elver-fanen (UPDATE/DELETE-RLS gated på magnus@jepson.no).
  Samme fane har fisketerskel-editor (med dagens persentiler som hint), stasjonshelse og backfill-knapp.
- Godkjente elver flettes inn i fangstskjemaets elveliste for alle (lastes fra DB ved app-start).
- `catches.conditions` (jsonb): manuelle felt (`weather`, `wind`, `waterLevel`, `waterColor`,
  `airTemp`, `waterTemp`) + `measured`-subobjekt (`water_flow`, `water_temp`, `air_temp`,
  `nve_station`, `fetched_at`). **Rør aldri manuelle felt ved auto-henting** — merge kun `measured`.
  Manuelle verdier vinner alltid i visning.
- Vi bruker IKKE vannstand (water_stage) — kun vannføring (m³/s) og temperaturer.

## Databasevett

- `name_set boolean` på `profiles` gater navneoppsamling — bruk eksplisitt flagg, aldri verdi-inferens.
- Gruppelogikk håndheves av triggere: eier kan ikke forlate ikke-tom gruppe
  (`trg_prevent_owner_leaving`), gruppe auto-slettes når siste medlem forlater.
- Postgres `time`-kolonner returnerer `HH:MM:SS` — normaliser til `HH:MM` ved tidsbygging.
- Fangster lagres i norsk lokaltid; fiskesesongen er alltid CEST, bruk `+02:00` ved rekonstruksjon.

## localStorage-nøkler

`fl_rivers` (egendefinerte elver), `fl_riverOrder` (sortering i Elver-visningen),
`fl_lastConditions` (siste forhold-valg, uten temp), `fl_feedLastSeen` (feed-badge).
Alle er enhetsspesifikke.

## Designsystem (mørkt tema)

- Farger: bg `#0f1a17`, bg-nested `#162320`, kort `#1c2e28`, border `#2a4038`,
  primær `#5ee6a0` (neongrønn — brukes sparsomt, maks 2–3 elementer per skjerm),
  primary-light `#1c3a2e`, chip-bg `#243832`, chip-tekst `#8fc4a5`, danger `#f87171`.
  Tekst: `#e8f0ec` / `#9bb5a8` / `#5f7d6e`. Aldri ren svart.
- Typografi: Outfit. 24/500 heading, 16/400 input+body (min 16px på inputs mot iOS-zoom),
  15/500 knapp, 14/400 kortinnhold, 12/500 chips.
- Radius: 10px input, 12px kort, 14px container, 50% avatar. Rolig kontrast, myke hjørner.

## iOS-fallgruver (lært på den harde måten)

- `<input type="date">` kan ikke høyde-normaliseres med CSS på iPhone — bruk custom overlay.
- `loading="lazy"` på avatarer gir blink — bruk `decoding="sync"`.
- Dropdown-scroll: track `touchstart`-Y og utløs valg kun ved bevegelse < 10px.
- iOS kaster HTTP-cache for PWA-er aggressivt — derav eksplisitt SW-caching av bilder.