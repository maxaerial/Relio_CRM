# Relio — Aufbau von `index.html`

Eine Datei, drei Zonen. Zeilennummern sind Stand des letzten Doku-Updates und wandern bei
Änderungen — sie dienen der Orientierung, nicht als Anker.

| Von | Bis | Inhalt |
|---|---|---|
| 1 | 16 | `<head>`: Meta, PWA-Tags, Google Fonts, CDN-Skripte (Supabase, Chart.js) |
| 17 | ~1320 | `<style>`: Theme-Variablen, Komponenten-CSS |
| ~1325 | ~2880 | Markup: Login-Screen, Sidebar, alle Seiten, alle Modals |
| ~2885 | 8511 | `<script>`: Konfiguration, i18n, Demo-Daten, Render- und Datenlogik |

## Markup-Zonen

| Zeile | Bereich |
|---|---|
| ~1325 | Login-/Register-Screen inkl. Demo-Account-Box |
| ~1380 | Mobile-Topbar |
| ~1427 | Sidebar (Relio-Logo × Firmenlogo, Navigation, User-Block). Reihenfolge seit 10.09.2026: Dashboard, Kontakte, Journey, Aktivitäten, Pipeline, E-Mail, Hilfe — Mobile-Nav (~1394) gleich halten |
| 1522 | `page-dashboard` |
| 1605 | `page-journey` |
| 1659 | `page-kontakte` |
| 1719 | `page-pipeline` |
| 1806 | `page-aktivitaeten` |
| 1879 | `page-email` |
| 2019 | `page-kontakt-detail` |
| 2040 | `page-journey-detail` |
| 2055 | `page-aktivitaet-detail` |
| 2070 | `page-deal-detail` |
| 2085 | `page-hilfe` |
| ~2140 | Einstellungen: Profil, Firmenlogo, Absender-Mail, Resend-Key, Domain, Team |

Seitenwechsel läuft über `showPage(id, el)` (index.html:4624) bzw.
`showPageMobile` (:4612) — beide toggeln nur die CSS-Klasse `active`. Es gibt **kein
Routing und keine URL-Hashes**; ein Reload landet immer auf dem Dashboard.

## Script-Zonen

| Zeile | Bereich |
|---|---|
| 2887 | Supabase-Client `sb`, Chart.js-Defaults, `getCurrentUserId()` (Cache in `window._userId`) |
| 2911 | `LANGS` — i18n für de/en/es/fr, flache Key-Value-Tabellen |
| 3038 | `PHASES`, `PHASE_COLORS` |
| 3046 | Persistente UI-Einstellungen: `lang`, `theme` (localStorage `crm_lang` / `crm_theme`) |
| 3156 | Demo-Modus: `DEMO_DATA`, `DEMO_USER`, `isDemoMode` |
| 3307 | Demo-Render-Funktionen (eigener Pfad, ohne Supabase) |
| 3545 | Auth-UI: Tabs, Login, Registrierung, Passwort-Reset |
| 3620 | `onLogin(user)` — der zentrale Einstiegspunkt nach Anmeldung |
| 3744 | Team-Einladungen (Edge Function `invite-team-member`) |
| 3867 | `profileData`, Profil laden/speichern, Avatar |
| 3923 | Absender-Domain (Edge Function `manage-domain`) |
| 4040 | Firmenlogo (Base64 in `companies.logo`) |
| 4147 | E-Mail-Signaturen (`email_signatures`) |
| 4560 | Boot: `sb.auth.getSession()` + `onAuthStateChange` (Invite-/Recovery-Redirects) |
| 4612 | `showPage` / `showPageMobile` |
| 4683 | Dashboard: KPIs und Charts |
| 4740 | Journey: State, Rendering, Filter |
| 4978 | `PHASE_TO_STATUS`, `JOURNEY_TO_PIPELINE`, `syncJourneyToPipeline()` |
| 5183 | Kontakte: State, Tabelle, Sortierung, CRUD |
| 5394 | Pipeline / Deals |
| 5729 | Aktivitäten |
| 5880 | E-Mail-Versand (`send-email`); darüber toter EmailJS-Code |
| 6074 | Laufende Nummern (`nr`) — clientseitig aus den letzten 100 Datensätzen |
| 6110 | Reaktions-Dialog (Journey → Status/Deal/Aktivität) |
| 6211 | Detailseiten (Kontakt, Journey, Aktivität, Deal) |
| 6538 | `HILFE_CONTENT` |
| 7939 | `showToast(msg, err)` |
| 8030 | E-Mail-Empfängerauswahl, Filter, Massenversand |

## Boot-Reihenfolge

```
Seite lädt
 └─ sb.auth.getSession()
     ├─ keine Session  → Login-Screen bleibt sichtbar
     ├─ Invite/Recovery-Redirect → showPasswordSetupUI()
     └─ Session         → onLogin(user)
                           ├─ Sidebar, i18n, Theme
                           ├─ loadTeamMembers / loadProfile / loadEmailConfig
                           │  loadCompanyLogo / loadEmailSignatures   (parallel, ungeawaited)
                           ├─ showPage('dashboard')
                           └─ renderAll()
```

`onLogin` startet die fünf Loader **ohne `await`**. Wer dort etwas ergänzt, darf sich
nicht darauf verlassen, dass Profil- oder Firmendaten beim ersten Render schon da sind.

## Muster, die man kennen sollte

**Demo-Weiche.** Jede Funktion, die Daten anzeigt, beginnt mit einer Variante von:

```js
const src = isDemoMode ? (window.DEMO_DATA?.kontakte || []) : (kontakteData || []);
```

Schreibende Funktionen steigen früh aus: `if(isDemoMode) return;`.

**Globale State-Arrays.** `kontakteData`, `journeyData`, `dealsData`, `aktivData` halten
den zuletzt geladenen Stand. Nach jedem Schreibvorgang wird die zugehörige `load*()`
erneut aufgerufen statt lokal zu mutieren.

**Chart-Instanzen.** `cStatus`, `cPipe`, `cJourney`, `cKStatus` … sind Modul-Globals.
Vor jedem Neuzeichnen `chart?.destroy()` — sonst stapeln sich Chart.js-Instanzen und die
Tooltips flackern.

**Laufende Nummern.** `nr` wird clientseitig vergeben (index.html:6074 ff.), indem die
letzten 100 Datensätze geladen und das Maximum erhöht wird. Das ist nicht
race-condition-sicher; bei parallelem Anlegen können Nummern doppelt vergeben werden.
Bekannt, bisher unkritisch bei der Nutzerzahl.
