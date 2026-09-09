#!/usr/bin/env python3
"""Read-Tool für die Relio-Supabase.

Ohne Konfiguration laeuft es mit dem oeffentlichen Publishable Key aus index.html —
dann sind nur die Tabellen lesbar, deren RLS das erlaubt (siehe docs/SUPABASE.md).

Ist SUPABASE_SECRET_KEY gesetzt, nutzt das Skript diesen Key und sieht alle Tabellen
unter Umgehung von RLS. Den Key nie ins Repo committen — nur als Umgebungsvariable:

  export SUPABASE_SECRET_KEY='sb_secret_...'

  tools/sb.py tables
  tools/sb.py cols kontakte
  tools/sb.py rows kontakte --limit 5
  tools/sb.py rows kontakte --select unternehmen,email --where 'status=eq.Lead'
  tools/sb.py schema                      # alle Tabellen+Spalten, braucht Secret Key
"""
import argparse, json, os, re, sys, urllib.error, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = ["kontakte", "journey", "aktivitaeten", "deals", "companies",
          "profiles", "team_members", "email_vorlagen", "email_signatures"]


def credentials():
    """Liest URL und Key aus index.html, damit sie nur an einer Stelle gepflegt sind."""
    html = open(os.path.join(ROOT, "index.html"), encoding="utf-8").read()
    m = re.search(r'createClient\("(https://[^"]+)"\s*,\s*"([^"]+)"\)', html)
    if not m:
        sys.exit("createClient(...) nicht in index.html gefunden — Aufruf geaendert?")
    return m.group(1), m.group(2)


BASE, PUBLISHABLE = credentials()
SECRET = os.environ.get("SUPABASE_SECRET_KEY", "").strip()
KEY = SECRET or PUBLISHABLE


def mode():
    return "secret key (RLS umgangen)" if SECRET else "publishable key (RLS aktiv)"


def get(table, params, want_count=False):
    url = f"{BASE}/rest/v1/{table}"
    if params:
        url += "?" + urllib.parse.urlencode(params, safe="=.,*()")
    headers = {"apikey": KEY}
    if SECRET:
        headers["Authorization"] = f"Bearer {KEY}"
    if want_count:
        headers["Prefer"] = "count=exact"
        headers["Range"] = "0-0"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r), r.headers.get("Content-Range")
    except urllib.error.HTTPError as e:
        return {"error": e.code, "body": e.read().decode("utf-8", "replace")}, None


def cmd_schema(_):
    """Vollstaendiges Schema ueber den OpenAPI-Endpunkt (nur mit Secret Key)."""
    data, _rng = get("", {})
    if isinstance(data, dict):
        sys.exit(f"HTTP {data['error']}: {data['body']}\n"
                 "Dieser Endpunkt braucht SUPABASE_SECRET_KEY.")
    for name, spec in sorted(data.get("definitions", {}).items()):
        props = spec.get("properties", {})
        print(f"\n{name}")
        for col, meta in props.items():
            t = meta.get("format") or meta.get("type") or "?"
            print(f"  {col:<28}{t}")


def cmd_tables(_):
    print(f"Modus: {mode()}\n")
    print(f"{'Tabelle':<18}{'Zeilen':>8}  Zugriff")
    for t in TABLES:
        data, rng = get(t, {"select": "*", "limit": "1"}, want_count=True)
        if isinstance(data, dict):
            print(f"{t:<18}{'?':>8}  HTTP {data['error']}")
            continue
        total = rng.split("/")[-1] if rng else "?"
        if SECRET:
            print(f"{t:<18}{total:>8}  ok")
        elif data:
            print(f"{t:<18}{total:>8}  anonym lesbar  <-- RLS pruefen")
        else:
            print(f"{t:<18}{'-':>8}  RLS-geschuetzt oder leer")


def cmd_cols(args):
    data, _ = get(args.table, {"select": "*", "limit": "1"})
    if isinstance(data, dict):
        sys.exit(f"HTTP {data['error']}: {data['body']}")
    if not data:
        sys.exit(f"{args.table}: keine anonym lesbare Zeile — Spalten nicht ermittelbar.")
    for c in data[0]:
        print(c)


def cmd_rows(args):
    params = {"select": args.select, "limit": str(args.limit)}
    if args.order:
        params["order"] = args.order
    for w in args.where or []:
        k, _, v = w.partition("=")
        params[k] = v
    data, _ = get(args.table, params)
    if isinstance(data, dict):
        sys.exit(f"HTTP {data['error']}: {data['body']}")
    print(json.dumps(data, indent=2, ensure_ascii=False))


p = argparse.ArgumentParser(description=__doc__,
                            formatter_class=argparse.RawDescriptionHelpFormatter)
sub = p.add_subparsers(dest="cmd", required=True)

sub.add_parser("tables", help="Tabellen, Zeilenzahl und Lesbarkeit").set_defaults(fn=cmd_tables)
sub.add_parser("schema", help="Alle Tabellen und Spalten (braucht Secret Key)").set_defaults(fn=cmd_schema)

c = sub.add_parser("cols", help="Spalten einer Tabelle")
c.add_argument("table")
c.set_defaults(fn=cmd_cols)

r = sub.add_parser("rows", help="Zeilen als JSON")
r.add_argument("table")
r.add_argument("--select", default="*")
r.add_argument("--limit", type=int, default=10)
r.add_argument("--order", help="z.B. created_at.desc")
r.add_argument("--where", action="append", help="PostgREST-Filter, z.B. 'status=eq.Lead'")
r.set_defaults(fn=cmd_rows)

a = p.parse_args()
a.fn(a)
