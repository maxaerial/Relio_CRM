-- Kooperationsseite paironloop.com/kooperation/ → eine Datenbankfunktion statt
-- offener anon-Policies. Stand 10.09.2026.
--
-- Die Seite macht bisher mit dem öffentlichen Key direkt: Kontakt per Firmenname
-- suchen, Status/Kommentar/Newsletter ändern oder Kontakt anlegen, Journey-Eintrag
-- anlegen, bei Interesse eine Nachfass-Aufgabe. Dafür brauchte anon SELECT/UPDATE/INSERT
-- auf kontakte, journey, aktivitaeten — und damit konnte jeder alle PairOnLoop-Kontakte
-- lesen und ändern.
--
-- Diese Funktion macht dieselben Schritte serverseitig (SECURITY DEFINER), fest auf die
-- Firma PairOnLoop, und gibt nichts zurück außer ok/Fehler. Aufruf von der Seite:
--   sb.rpc("kooperation_antwort", { hotel: "Hotel Adler", antwort: "interested" })
-- Danach können die anon-Policies auf den drei Tabellen weg (docs/rls-fix.sql, Teil 2).

create or replace function public.kooperation_antwort(hotel text, antwort text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  co       constant uuid := '00000000-0000-0000-0000-000000000001';  -- PairOnLoop
  h        text := btrim(coalesce(hotel, ''));
  k        record;
  k_id     uuid;
  k_name   text;
  st       text; nl text; ph text; tp text; re text; sc int;
  next_nr  int;
  heute    date := current_date;
begin
  if length(h) < 2 or length(h) > 120 then
    raise exception 'Ungültiger Hotel-Name' using errcode = '22023';
  end if;

  case antwort
    when 'interested' then st := 'Aktiv';   nl := 'ja'; ph := 'Interesse';   tp := 'Kooperationsanfrage – Interesse bestätigt'; re := 'Interessiert – möchte mehr erfahren';               sc := 9;
    when 'maybe'      then st := 'Lead';    nl := 'ja'; ph := 'Bewusstsein'; tp := 'Kooperationsanfrage – Vielleicht später';    re := 'Aktuell kein Interesse – gerne in Kontakt bleiben'; sc := 5;
    when 'no'         then st := 'Inaktiv'; nl := null; ph := 'Bewusstsein'; tp := 'Kooperationsanfrage – Kein Interesse';       re := 'Kein Interesse – keine weiteren Nachrichten';       sc := 2;
    else raise exception 'Ungültiger Status: %', antwort using errcode = '22023';
  end case;

  -- Kontakt suchen (wie bisher: ilike auf den Firmennamen, nur PairOnLoop)
  select id, unternehmen, kommentar into k
    from kontakte where company_id = co and unternehmen ilike h
   order by created_at limit 1;

  if found then
    k_id := k.id; k_name := k.unternehmen;
    update kontakte set
      status          = st,
      letzter_kontakt = heute,
      newsletter      = coalesce(nl, newsletter),
      kommentar       = concat_ws(E'\n', nullif(k.kommentar, ''),
                          '[' || to_char(heute, 'DD.MM.YYYY') || '] Kooperationsseite: ' ||
                          case antwort when 'interested' then 'Ja, interessiert' when 'maybe' then 'Vielleicht später' else 'Kein Interesse' end ||
                          ' → ' || st)
    where id = k_id;
  else
    select coalesce(max(nullif(regexp_replace(nr, '\D', '', 'g'), '')::int), 0) + 1 into next_nr
      from kontakte where company_id = co;
    insert into kontakte (nr, unternehmen, vorname, nachname, status, kanal, branche, letzter_kontakt, kommentar, newsletter, company_id)
    values (lpad(next_nr::text, 3, '0'), h, '–', '–', st, 'E-Mail', 'Hospitality', heute,
            'Angelegt via Kooperationsseite (' || antwort || ')', nl, co)
    returning id, unternehmen into k_id, k_name;
  end if;

  -- Journey-Eintrag
  select coalesce(max(nullif(regexp_replace(nr, '\D', '', 'g'), '')::int), 0) + 1 into next_nr
    from journey where company_id = co;
  insert into journey (nr, kunde, kontakt_id, datum, phase, touchpoint, kanal, aktivitaet, reaktion, score, company_id)
  values ('T' || lpad(next_nr::text, 3, '0'), k_name, k_id, heute, ph, tp, 'E-Mail',
          'Kooperation Landing Page – ' ||
          case antwort when 'interested' then 'Ja, interessiert' when 'maybe' then 'Vielleicht später' else 'Kein Interesse' end,
          re, sc, co);

  -- Nachfass-Aufgabe nur bei Interesse
  if antwort = 'interested' then
    select coalesce(max(nullif(regexp_replace(nr, '\D', '', 'g'), '')::int), 0) + 1 into next_nr
      from aktivitaeten where company_id = co;
    insert into aktivitaeten (nr, kunde, kontakt_id, typ, datum, prioritaet, beschreibung, verantwortlich, status, company_id)
    values ('A' || lpad(next_nr::text, 3, '0'), k_name, k_id, 'Nachfassen', heute + 3, 'Hoch',
            k_name || ' hat Interesse signalisiert – Kontakt aufnehmen!', 'Max', 'Offen', co);
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.kooperation_antwort(text, text) from public;
grant execute on function public.kooperation_antwort(text, text) to anon, authenticated;
