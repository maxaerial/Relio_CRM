-- Relio: anonyme Policies auf kontakte / journey / aktivitaeten
-- ERLEDIGT 10.09.2026: Teil 2 ausgeführt, Kooperationsseite auf kooperation_antwort() umgestellt,
-- Live-Test bestanden. Verbleibend: nur noch anon INSERT auf den drei Tabellen (Newsletter-Weg).
-- Stand 10.09.2026, erhoben über `supabase db query --linked` (Projekt ftkriccztlcwccgetdqt,
-- Organisation PairOnLoop). Hintergrund: docs/SUPABASE.md#rls-lücke
--
-- KORREKTUR zur Übergabe vom 10.09.: RLS ist auf ALLEN Tabellen aktiv, und die Policies
-- für angemeldete Nutzer (kontakte_user, journey_user, aktivitaeten_user, deals_user …)
-- sind sauber auf company_id = profiles.company_id begrenzt. Presio-Daten sind weder
-- anonym lesbar noch für PairOnLoop-Nutzer sichtbar.
--
-- Die anonyme Lesbarkeit kommt aus GEZIELT ANGELEGTEN anon-Policies, alle auf die
-- Firma PairOnLoop (company_id 00000000-0000-0000-0000-000000000001) begrenzt:
--
--   kontakte      anon SELECT  anon_select_kontakte_nr, anon_select_kooperation, kooperation_anon_select
--   kontakte      anon UPDATE  anon_update_kooperation, kooperation_anon_update   <-- jeder darf ändern!
--   kontakte      anon INSERT  anon_insert_kooperation, kooperation_anon_insert
--   journey       anon SELECT  anon_select_journey_nr
--   journey       anon INSERT  anon_insert_kooperation, kooperation_anon_insert
--   aktivitaeten  anon SELECT  anon_select_aktivitaeten_nr
--   aktivitaeten  anon INSERT  anon_insert_kooperation, kooperation_anon_insert
--
-- Die Namen deuten auf zwei Abnehmer außerhalb dieses Repos: die Kooperations-Links
-- ({{unternehmen_url}} in E-Mail-Vorlagen → Seite auf paironloop.com?) und den
-- Newsletter-Weg (Make.com → Edge Function newsletter-webhook). Die "_nr"-Policies
-- dienen vermutlich der clientseitigen Nummernvergabe. Welche Seite genau anonym liest
-- und schreibt, ist von hier nicht sichtbar — vor dem Entfernen klären.
--
-- Risiko bis dahin: Jeder mit dem Publishable Key (steht in index.html) kann alle
-- 263 PairOnLoop-Kontakte lesen UND beliebig ändern (UPDATE ohne WITH CHECK).

-- ── 1. Inventar (nur lesen) ───────────────────────────────────────────────
select tablename, policyname, roles, cmd, qual, with_check
  from pg_policies
 where schemaname = 'public' and 'anon' = any(roles)
 order by tablename, cmd, policyname;

-- ── 2. Minimal-Fix: anonymes ÄNDERN und LESEN abschalten, INSERT behalten ─
-- Damit laufen Newsletter-/Kooperations-Formulare, die nur anlegen, weiter.
-- Eine Kooperations-Seite, die per anon-Key liest oder aktualisiert, bricht hier —
-- die gehört auf eine Edge Function mit Secret Key und Prüfung eines Tokens pro Kontakt.
begin;
drop policy if exists "anon_update_kooperation"      on public.kontakte;
drop policy if exists "kooperation_anon_update"      on public.kontakte;
drop policy if exists "anon_select_kooperation"      on public.kontakte;
drop policy if exists "kooperation_anon_select"      on public.kontakte;
drop policy if exists "anon_select_kontakte_nr"      on public.kontakte;
drop policy if exists "anon_select_journey_nr"       on public.journey;
drop policy if exists "anon_select_aktivitaeten_nr"  on public.aktivitaeten;
commit;

-- ── 3. Nachprüfung ────────────────────────────────────────────────────────
-- tools/sb.py tables  → alle drei Tabellen müssen "RLS-geschuetzt oder leer" zeigen.
-- Danach: Newsletter-Anmeldung auf paironloop.com testen, Kooperations-Link testen,
-- als PairOnLoop-Nutzer einloggen und prüfen, dass alles weiterhin angezeigt wird.
