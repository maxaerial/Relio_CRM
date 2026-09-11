# Relio — Supabase-Backend

- **Projekt:** `ftkriccztlcwccgetdqt` · `https://ftkriccztlcwccgetdqt.supabase.co`
- **Publishable Key:** `sb_publishable_qpOqA2VwlZDxXEJL86-Wpw_cv15argD`
  (steht bewusst öffentlich in `index.html:2900` — Supabase sieht das so vor, der Schutz
  muss aus RLS kommen)
- **Client:** `const sb = createClient(...)`, siehe `index.html:2900`

Es gibt **keine Staging-Instanz**. Lokale Entwicklung spricht gegen Produktion.

## Zugang einrichten

Ohne Konfiguration kommt man nur an das, was RLS oeffentlich freigibt — praktisch also
`kontakte`, `journey`, `aktivitaeten`. Fuer vollen Zugriff werden zwei Angaben gebraucht,
beide **ausschliesslich als Umgebungsvariable**, nie im Repo:

**1. Secret API Key** — Dashboard → Project Settings → API Keys → `secret` (frueher
`service_role`). Umgeht RLS, gilt fuer die REST-API:

```bash
export SUPABASE_SECRET_KEY='sb_secret_...'
tools/sb.py tables      # zeigt jetzt alle Tabellen
tools/sb.py schema      # alle Tabellen und Spalten aus der OpenAPI-Definition
```

**2. Datenbank-URL** — Dashboard → Project Settings → Database → Connection string →
URI (Session pooler). Erlaubt echtes SQL inklusive Policies, Indizes und Migrationen:

```bash
export SUPABASE_DB_URL='postgresql://postgres.ftkriccztlcwccgetdqt:<PASSWORT>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres'
tools/db.sh -c '\dt'
tools/db.sh -c "select tablename, rowsecurity from pg_tables where schemaname='public'"
```

`psql` und `pg_dump` sind vorhanden, die Supabase-CLI nicht.

Der Secret Key hat vollen Lese- und Schreibzugriff auf alle Kundendaten und die
DB-URL zusaetzlich DDL-Rechte. Beide gehoeren nicht in Chatverlaeufe, nicht in Commits
und nicht in `index.html`. `.gitignore` schuetzt `.env` — dort sind sie am besten
aufgehoben.

## Tabellen

Stand der Erhebung: siehe `tools/sb.py tables` für aktuelle Zahlen.

| Tabelle | Zeilen | Anonym lesbar | Zweck |
|---|---:|---|---|
| `kontakte` | 263 | **ja** ⚠️ | Kunden und Leads |
| `journey` | 267 | **ja** ⚠️ | Customer-Journey-Touchpoints |
| `aktivitaeten` | 12 | **ja** ⚠️ | Aufgaben und Follow-ups |
| `deals` | – | nein | Pipeline |
| `companies` | – | nein | Mandant (Firma), Logo, Domain-Status |
| `profiles` | – | nein | Nutzerprofil, `company_id`, E-Mail-Absender |
| `team_members` | – | nein | Teammitglieder je Firma |
| `email_vorlagen` | – | nein | E-Mail-Vorlagen |
| `email_signatures` | – | nein | Signaturen je Nutzer |

„Zeilen –" heißt: hinter RLS, ohne Login nicht zählbar.

### Spalten

**`kontakte`**
`id`, `nr`, `unternehmen`, `unternehmen_url`, `vorname`, `nachname`, `geschlecht`,
`ort`, `land`, `email`, `telefon`, `homepage`, `kanal`, `status`, `branche`, `dealwert`,
`erster_kontakt`, `letzter_kontakt`, `naechste_aktion`, `kommentar`,
`individueller_satz`, `sprache`, `newsletter`, `key_account` (Name aus `team_members`, seit 10.09.2026),
`created_at`, `user_id`, `company_id`

**`journey`**
`id`, `nr`, `kunde`, `kontakt_id`, `datum`, `phase`, `touchpoint`, `kanal`, `aktivitaet`,
`reaktion`, `naechster_schritt`, `score`, `created_at`, `user_id`, `company_id`

**`aktivitaeten`**
`id`, `nr`, `kunde`, `kontakt_id`, `typ`, `datum`, `prioritaet`, `beschreibung`,
`status`, `ergebnis`, `notizen`, `verantwortlich`, `created_at`, `user_id`, `company_id`

**`deals`** (aus dem Code abgeleitet, `index.html:5059` / `:5711`)
`id`, `nr`, `kunde`, `wert`, `wahrscheinlichkeit`, `phase`, `status`, `quelle`,
`abschlussdatum`, `created_at`, `user_id`, `company_id`

**`companies`** (aus dem Code): `id`, `name`, `logo`, `email_domain`, `domain_status`
**`profiles`** (aus dem Code): `id` (= `auth.users.id`), `vorname`, `nachname`, `firma`,
`telefon`, `avatar`, `company_id`, `email_from`, `email_from_name`, `email_bcc`,
`default_signature_id`

### Konventionen

- `kunde` ist in `journey`, `aktivitaeten` und `deals` ein **Firmenname als Text**, keine
  Fremdschlüssel-Beziehung. Verknüpfungen laufen per `ilike` auf `kontakte.unternehmen`
  (z. B. `index.html:6191`). `kontakt_id` existiert zusätzlich, wird aber nicht überall
  gepflegt — beim Auswerten beides berücksichtigen.
- `company_id` ist die Mandantengrenze und gehört auf **jede** neue Tabelle.
- `nr` ist eine clientseitig vergebene Anzeigenummer, kein Schlüssel (siehe
  `docs/ARCHITECTURE.md`).

## Edge Functions

Alle unter `https://ftkriccztlcwccgetdqt.supabase.co/functions/v1/…`, aufgerufen per
`fetch` mit dem Bearer-Token aus `sb.auth.getSession()`. Der Quellcode der Functions
liegt **nicht in diesem Repo** — er wird im Supabase-Dashboard gepflegt.

| Function | Aufrufer | Zweck |
|---|---|---|
| `send-email` | `index.html:5931`, `:8101` | Versand über Resend (Einzel- und Massenmail) |
| `invite-team-member` | `index.html:3747` | Teammitglied per Auth-Invite einladen |
| `manage-domain` | `index.html:3926` | Absender-Domain bei Resend anlegen/prüfen |

RPC: `delete_user` — löscht den eigenen Account (`sb.rpc("delete_user")`).

## E-Mail-Versand

Läuft ausschließlich über `send-email` → Resend. Jeder Nutzer hinterlegt in den
Einstellungen eine eigene Absenderadresse (`profiles.email_from`); die Domain wird
einmal pro Firma über `manage-domain` verifiziert (`companies.email_domain`,
`companies.domain_status`). Firmen können einen eigenen Resend-API-Key hinterlegen,
sonst läuft der Versand über den Test-Account.

Die `EMAILJS_*`-Konstanten in `index.html:5880` sind **toter Code**.

## Newsletter-Anbindung

Anmeldung auf paironloop.com → WP Webhooks → Make.com → Supabase Edge Function.
Legt einen Kontakt an und erzeugt einen Journey-Touchpoint „Newsletter-Anmeldung /
Bewusstsein". Beschrieben in der In-App-Hilfe (`index.html:6626`).

## RLS-Lücke

**`kontakte` (263 Zeilen), `journey` (267 Zeilen) und `aktivitaeten` (12 Zeilen) sind
mit dem öffentlichen Publishable Key ohne jede Anmeldung vollständig lesbar.**

Reproduzierbar mit:

```bash
curl -s "https://ftkriccztlcwccgetdqt.supabase.co/rest/v1/kontakte?select=*&limit=3" \
  -H "apikey: sb_publishable_qpOqA2VwlZDxXEJL86-Wpw_cv15argD"
```

Da der Key im ausgelieferten `index.html` steht, kann das jeder Besucher von
relio-crm.de nachvollziehen. Betroffen sind echte Kundendaten — Firmenname,
Ansprechpartner, E-Mail, Telefon, Deal-Wert, interne Kommentare. Das ist ein
DSGVO-relevanter Datenabfluss, kein theoretisches Risiko.

`deals`, `companies`, `profiles`, `team_members`, `email_vorlagen` und
`email_signatures` verhalten sich korrekt (liefern anonym leere Ergebnisse) — die
Policies dort taugen als Vorlage.

**Fix** (im Supabase-SQL-Editor, erfordert Projekt-Zugang — bewusst *nicht* von hier aus
ausgeführt):

```sql
alter table public.kontakte      enable row level security;
alter table public.journey       enable row level security;
alter table public.aktivitaeten  enable row level security;

-- Zugriff auf die eigene Firma; als Vorlage für alle drei Tabellen
create policy "kontakte_own_company" on public.kontakte
  for all
  to authenticated
  using (
    company_id = (select company_id from public.profiles where id = auth.uid())
  )
  with check (
    company_id = (select company_id from public.profiles where id = auth.uid())
  );
```

Vor dem Aktivieren prüfen, ob alle Bestandszeilen eine `company_id` haben — sonst
verschwinden Altdatensätze aus der App:

```sql
select count(*) from public.kontakte where company_id is null;
```

Zeilen ohne `company_id` vorher der richtigen Firma zuordnen oder die Policy übergangs-
weise um `or user_id = auth.uid()` erweitern.

### Korrektur 10.09.2026 (erhoben per `supabase db query --linked`)

Die Diagnose oben ist nur halb richtig. **RLS ist auf allen Tabellen aktiv**, und die
Policies für angemeldete Nutzer sind überall auf `company_id = profiles.company_id`
begrenzt. Presio-Daten sind weder anonym lesbar noch für PairOnLoop-Nutzer sichtbar.

Die anonyme Lesbarkeit stammt aus **gezielt angelegten `anon`-Policies**, alle auf die
Firma PairOnLoop (`…0001`) beschränkt: SELECT, INSERT und **UPDATE** auf `kontakte`,
SELECT und INSERT auf `journey` und `aktivitaeten`. Namen wie `kooperation_anon_select`
und `anon_select_kontakte_nr` deuten auf Kooperations-Links und den Newsletter-Weg
außerhalb dieses Repos. Bevor sie entfernt werden, muss klar sein, welche Seite sie
nutzt. Inventar und Minimal-Fix: [`docs/rls-fix.sql`](rls-fix.sql).

Weitere Befunde:
- Tabelle `company_integrations` (`company_id`, `resend_api_key`, `updated_at`) fehlt
  oben in der Liste.
- Edge Functions außer den drei dokumentierten: `newsletter-webhook`, `instagram-dm`,
  `quick-endpoint`, `smooth-endpoint`.
- Region des Projekts ist `eu-west-1`, nicht `eu-central-1`.
- Es existieren **zwei Firmen namens Presio**: `22de32b1…` (Juni 2026, Konto
  christoph.gerhardt@gmail.com, 4 Kontakte / 19 Journey / 2 Deals Testdaten) und
  `53c317ee…` (September 2026, max.weidmann@presio.eu + christoph.gerhardt@presio.eu,
  leer). Die zweite ist die produktive.
- Zugang von diesem Mac: `supabase link --project-ref ftkriccztlcwccgetdqt` in einem
  Ordner außerhalb des Repos, dann `supabase db query --linked "<sql>"`. Kein
  DB-Passwort nötig, läuft über die Management-API der eingeloggten CLI.

### Erledigt 10.09.2026

- Kooperationsseite `paironloop.com/kooperation/` ruft jetzt nur noch die Datenbankfunktion
  `kooperation_antwort(hotel, antwort)` auf (SECURITY DEFINER, fest auf PairOnLoop).
  Quelle: [`docs/kooperation-rpc.sql`](kooperation-rpc.sql); Widget-Inhalt in zwei Teilen
  (Elementor-Grenze ~150 Zeilen): `kooperation-widget-teil1.txt` (CSS + Karten) und
  `kooperation-widget-teil2.txt` (Skript).
- Anonyme SELECT- und UPDATE-Policies auf `kontakte`, `journey`, `aktivitaeten` entfernt.
  `tools/sb.py tables` zeigt alle drei als geschützt. Verblieben sind die anon-INSERT-Policies
  (`anon_insert_kooperation`, `kooperation_anon_insert`) für den Newsletter-Weg; ob
  `newsletter-webhook` sie braucht, ist ungeprüft (Quellcode-Download hängt).
- Live-Test mit „Testhotel Claude" bestanden, Testdaten wieder gelöscht.
- **Key Account je Unternehmen** (10.09.2026): Spalte `kontakte.key_account` (Text, Name des
  Teammitglieds wie bei `aktivitaeten.verantwortlich`). Dropdowns werden aus `teamMembers`
  gefüllt (`fillVerantwortlichDropdowns`), Filter und Sortierung in der Kontaktliste,
  Feld in Anlegen/Bearbeiten/Sammelbearbeitung, Detailseite, Import/Export. Für Presio
  sind drei `team_members` eingetragen und die 50 Leads reihum nach Priorität und
  Deal-Wert auf Max, Christoph und Elena verteilt.
