# Relio CRM — Arbeitsanleitung

**Relio** ist das CRM-Produkt (Relations · Rely · Grow) neben Presio, Vocaris und der
Actuvo-Ausgründung. Dieses Repo ist die komplette Anwendung.

- **Live:** https://relio-crm.de (GitHub Pages, `CNAME` im Repo-Root)
- **Repo:** `maxaerial/Relio_CRM` (bis 10.09.2026 `paironloop-crm`)
- **Backend:** Supabase-Projekt `ftkriccztlcwccgetdqt` (EU) — Postgres + Auth + Edge Functions
- **Stack:** Eine einzige `index.html` (~8.500 Zeilen), Vanilla JS, keine Build-Kette,
  keine Dependencies außer zwei CDN-Skripten (`@supabase/supabase-js@2`, `chart.js@4.4.1`)

## Wichtigste Regel: alles lebt in `index.html`

Es gibt **kein** Build-Tool, **kein** npm, **kein** Framework. Die Datei enthält in dieser
Reihenfolge: `<head>` → ein großer `<style>`-Block → das komplette Markup aller Seiten →
ein großer `<script>`-Block mit ~237 Funktionen.

Deshalb gilt:

- **Nie** die Datei neu formatieren, umsortieren oder „aufräumen". Diffs müssen klein und
  lesbar bleiben — sonst ist ein Review unmöglich.
- Neue Funktionen **beim thematisch passenden Block** einfügen (siehe
  [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) für die Zeilen-Landkarte).
- Der Code-Stil ist kompakt: `const {data}=await sb.from("x").select("*")`, wenig
  Whitespace, deutsche Bezeichner für Domänenbegriffe (`kontakte`, `dealwert`,
  `letzter_kontakt`), englische für Technik (`loadProfile`, `showPage`).
- Kommentare sind deutsch und sparsam. Sektionsheader im Stil
  `// ── SUPABASE ────────────────`.

## Lokal starten

```bash
tools/serve.sh          # http://localhost:8000
```

Die App spricht dabei gegen die **echte Produktions-Supabase** — es gibt keine
Staging-Instanz. Zum gefahrlosen Klicken den **Demo-Modus** nutzen: auf dem Login-Screen
„DEMO ACCOUNT → Testen". Der schaltet `isDemoMode = true` und rendert ausschließlich aus
`DEMO_DATA` (index.html:3157), ohne je Supabase zu schreiben.

**Beim Ändern von Listen-/Render-Code immer beide Pfade prüfen** — es gibt für Dashboard,
Journey, Pipeline und Aktivitäten je eine Demo-Render-Variante (ab index.html:3307).

## Daten ansehen

```bash
tools/sb.py tables                       # Tabellen + Zeilenzahl + Lesbarkeit
tools/sb.py cols kontakte                # Spalten
tools/sb.py rows kontakte --limit 5      # Zeilen als JSON
tools/sb.py rows journey --where 'phase=eq.Angebot'
```

Ohne Konfiguration nutzt das Skript den öffentlichen Publishable Key aus `index.html` —
damit ist seit dem 10.09.2026 nichts mehr anonym lesbar (nur noch eine Zeilenzahl-Übersicht
mit „RLS-geschuetzt"). Für vollen Zugriff gibt es zwei Wege:

- **Supabase-CLI** (empfohlen, kein Passwort nötig): in einem Ordner außerhalb des Repos
  `supabase link --project-ref ftkriccztlcwccgetdqt`, dann
  `supabase db query --linked "<sql>"` bzw. `--linked -f datei.sql`. Ausgabe ist JSON
  mit den Zeilen unter `rows`.
- `.env.example` nach `.env` kopieren und `SUPABASE_SECRET_KEY` bzw. `SUPABASE_DB_URL`
  eintragen; dann liefert `tools/sb.py schema` das Schema und `tools/db.sh` echtes SQL.

Keys gehören nie ins Repo. Der Stand der Policies (RLS überall an, nur noch anon-INSERT
für den Newsletter-Weg) steht in [`docs/SUPABASE.md`](docs/SUPABASE.md#rls-lücke).

## Deployen

GitHub Pages served `main` direkt. **Ein Push auf `main` ist ein Live-Deploy** — es gibt
keine Preview-Stufe und kein CI. Entsprechend:

1. Auf einem Branch arbeiten, nie direkt auf `main`.
2. Vor dem Push die Seite lokal öffnen und die geänderte Ansicht einmal durchklicken —
   im Demo-Modus **und**, wenn Supabase-Code betroffen ist, eingeloggt.
3. Browser-Konsole muss fehlerfrei sein. Ein JS-Fehler im großen `<script>`-Block legt
   die gesamte App lahm, nicht nur das Feature.

## Domänenmodell in Kürze

Fünf Journey-Phasen (`PHASES`, index.html:3038): Bewusstsein → Interesse → Angebot →
Kauf → Empfehlung. Zwei automatische Synchronisationen hängen daran:

- `PHASE_TO_STATUS` (index.html:4978) setzt aus der Journey-Phase den Kontakt-Status
  (Lead / Aktiv / Abgeschlossen).
- `JOURNEY_TO_PIPELINE` (index.html:5019) legt aus einem Journey-Touchpoint automatisch
  einen Deal an bzw. verschiebt ihn (Interesse → Erstgespräch, Angebot → Angebot,
  Kauf → Abschluss + Gewonnen).

Beide Tabellen sind mehrsprachig verschlüsselt — die Keys existieren auf DE/EN/ES/FR.
**Wer eine Phase umbenennt oder hinzufügt, muss `PHASES`, `PHASE_TO_STATUS`,
`JOURNEY_TO_PIPELINE`, `PHASE_COLORS` und die vier `LANGS`-Blöcke gemeinsam anfassen.**

Mandantenfähigkeit läuft über `company_id` auf jedem Datensatz, aufgelöst über
`profiles.company_id`. Neue Tabellen brauchen dieselbe Spalte plus passende RLS-Policy.

## Bekannte Altlasten

- `EMAILJS_SERVICE` / `EMAILJS_TEMPLATE` / `EMAILJS_PUBLIC` (index.html:5880) sind
  **toter Code** — der Versand läuft komplett über die Edge Function `send-email`
  (Resend). Nicht als Vorbild nehmen.
- Der Publishable Key steht hart in `index.html:2900`. Das ist bei Supabase so
  vorgesehen (er ist öffentlich), ersetzt aber **keine** RLS.
