import os
import argparse
import sqlite3
import requests
import sys

# Configuration
# Allow env vars: ATA_API_KEY, ATA_APIKEY, API_KEY, api_key
API_KEY = os.getenv("ATA_API_KEY") or os.getenv("ATA_APIKEY") or os.getenv("API_KEY") or os.getenv("api_key")
db_path = os.getenv("SHOOTATA_DB", "data/ata/ata.sqlite")
API_BASE = "https://dataapi.shootata.com/api/ShooterData"
# Optional override for a single header
HEADER_OVERRIDE = os.getenv("SHOOTATA_API_HEADER")

def build_headers():
    """
    Build headers for API key.
    Supports brute-force of common header names plus override:
    - ApiKey
    - api_key
    - apikey
    - X-Api-Key
    - Authorization (Bearer ...)
    """
    keys = []
    if HEADER_OVERRIDE:
        keys.append(HEADER_OVERRIDE)
    # common header keys
    keys.extend(["ApiKey", "api_key", "apikey", "X-Api-Key", "Authorization"])
    # dedupe preserving order
    unique_keys = list(dict.fromkeys(keys))
    headers = {}
    for key in unique_keys:
        if key.lower() == "authorization":
            headers[key] = f"Bearer {API_KEY}"
        else:
            headers[key] = API_KEY
    return headers

HEADERS = build_headers()

# Logging control via environment
env_verbose = os.getenv("SHOOTATA_VERBOSE", "true").lower()
VERBOSE = env_verbose in ("1", "true", "yes")
def log(message):
    if VERBOSE:
        print(message)


def init_db(path):
    log(f"[INIT] Initializing database at '{path}'")
    directory = os.path.dirname(path)
    if directory and not os.path.exists(directory):
        log(f"[INIT] Directory '{directory}' not found; creating...")
        os.makedirs(directory, exist_ok=True)
    is_new = not os.path.exists(path)
    conn = sqlite3.connect(path)
    if is_new:
        log("[INIT] Database file not found; creating schema...")
        create_schema(conn)
    else:
        log("[INIT] Database file exists; skipping schema creation.")
    return conn


def create_schema(conn):
    log("[SCHEMA] Creating tables ata_gunclubs and ata_shoots...")
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS ata_gunclubs (
            club_number TEXT PRIMARY KEY,
            name        TEXT,
            city        TEXT,
            state       TEXT
        );
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS ata_shoots (
            shoot_id     INTEGER PRIMARY KEY,
            club_number  TEXT,
            date         TEXT,
            title        TEXT,
            FOREIGN KEY(club_number) REFERENCES ata_gunclubs(club_number)
        );
    """)
    conn.commit()
    log("[SCHEMA] Schema creation complete.")


def fetch_gunclubs():
    log(f"[API] Fetching gun clubs with headers: {list(HEADERS.keys())}")
    resp = requests.get(f"{API_BASE}/Gunclubs", headers=HEADERS)
    log(f"[API] Request URL: {resp.request.url}")
    log(f"[API] Request Headers: {resp.request.headers}")
    resp.raise_for_status()
    clubs = resp.json()
    log(f"[API] Retrieved {len(clubs)} gun clubs.")
    return clubs


def import_gunclubs(conn):
    log("[IMPORT] Starting import of gun clubs...")
    clubs = fetch_gunclubs()
    cur = conn.cursor()
    for club in clubs:
        cur.execute(
            """
            INSERT OR REPLACE INTO ata_gunclubs(club_number, name, city, state)
            VALUES (?, ?, ?, ?)
            """,
            (
                club.get("GunClubNumber"),
                club.get("GunClubName"),
                club.get("City"),
                club.get("State")
            )
        )
    conn.commit()
    log(f"[IMPORT] Imported {len(clubs)} clubs.")


def fetch_shoots_by_date(begin, end, club_number=None):
    log(f"[API] Fetching shoots {begin} to {end} (club={club_number}) with headers: {list(HEADERS.keys())}")
    params = {"begin": begin, "end": end}
    if club_number:
        params["gunclubnumber"] = club_number
    resp = requests.get(f"{API_BASE}/ShootListByDate", params=params, headers=HEADERS)
    log(f"[API] Request URL: {resp.request.url}")
    log(f"[API] Request Headers: {resp.request.headers}")
    resp.raise_for_status()
    shoots = resp.json()
    log(f"[API] Retrieved {len(shoots)} shoots.")
    return shoots


def import_shoots(conn, begin, end, club_number=None):
    log("[IMPORT] Starting import of shoots...")
    shoots = fetch_shoots_by_date(begin, end, club_number)
    cur = conn.cursor()
    for item in shoots:
        cur.execute(
            """
            INSERT OR REPLACE INTO ata_shoots(shoot_id, club_number, date, title)
            VALUES (?, ?, ?, ?)
            """,
            (
                item.get("ShootID"),
                item.get("GunClubNumber"),
                item.get("ShootDate"),
                item.get("ShootTitle")
            )
        )
    conn.commit()
    log(f"[IMPORT] Imported {len(shoots)} shoots from {begin} to {end}.")


def main():
    log("[MAIN] Starting load_shootata script...")
    parser = argparse.ArgumentParser(description="Load ShootsATA data into local SQLite.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("clubs", help="Import/update gun club master list.")
    sp_shoots = subparsers.add_parser("shoots", help="Import/update shoots by date range.")
    sp_shoots.add_argument("--begin", required=True)
    sp_shoots.add_argument("--end", required=True)
    sp_shoots.add_argument("--club")
    sp_all = subparsers.add_parser("all", help="Import gun clubs and shoots together.")
    sp_all.add_argument("--begin", required=True)
    sp_all.add_argument("--end", required=True)
    sp_all.add_argument("--club")

    args = parser.parse_args()
    conn = init_db(db_path)
    log(f"[MAIN] Command parsed: {args.command}")

    if args.command == "clubs":
        import_gunclubs(conn)
    elif args.command == "shoots":
        import_shoots(conn, args.begin, args.end, args.club)
    elif args.command == "all":
        import_gunclubs(conn)
        import_shoots(conn, args.begin, args.end, args.club)

    log("[MAIN] Operation complete.")

if __name__ == "__main__":
    if not API_KEY:
        print("[ERROR] Missing ATA_API_KEY or API_KEY environment variable.", file=sys.stderr)
        sys.exit(1)
    log(f"[CONFIG] API key provided; testing headers: {list(HEADERS.keys())}")
    main()
