"""
ingest.py
Fetches hourly weather data from Open-Meteo for the France 0.18° grid (~20 km)
and inserts it into PostgreSQL.

Usage: python ingest.py backfill 2026-03

Requirements: pip install requests pg8000
"""

import sys
import time
import logging
import requests
import pg8000.dbapi as pg
from datetime import datetime, timezone
from calendar import monthrange

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

DB = dict(host="localhost", port=5432, database="imperial_db",
          user="postgres", password="Imperial")

ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

LAT_START, LAT_END, LAT_STEP = 42.0, 51.25, 0.18
LON_START, LON_END, LON_STEP = -5.0,  8.25, 0.18
REQUEST_DELAY_S = 0.1


def france_grid() -> list[tuple[float, float]]:
    points, lat = [], LAT_START
    while lat <= LAT_END + 1e-9:
        lon = LON_START
        while lon <= LON_END + 1e-9:
            points.append((round(lat, 2), round(lon, 2)))
            lon += LON_STEP
        lat += LAT_STEP
    return points


def fetch_archive(lat: float, lon: float, start: str, end: str) -> list[dict]:
    r = requests.get(ARCHIVE_URL, params={
        "latitude": lat, "longitude": lon,
        "start_date": start, "end_date": end,
        "hourly": "temperature_2m", "timezone": "UTC",
    }, timeout=30)
    r.raise_for_status()
    data = r.json()["hourly"]
    return [
        {
            "observed_at": datetime.fromisoformat(ts).replace(tzinfo=timezone.utc),
            "temperature": data["temperature_2m"][i],
        }
        for i, ts in enumerate(data["time"])
    ]


def connect():
    return pg.connect(**DB)


def get_or_create_location(cur, lat: float, lon: float) -> int:
    cur.execute(
        "SELECT id FROM locations WHERE lat = %s AND lon = %s LIMIT 1",
        (lat, lon),
    )
    row = cur.fetchone()
    if row:
        return row[0]
    name = f"grid_{lat}_{lon}"
    cur.execute(
        "INSERT INTO locations (name, lat, lon) VALUES (%s,%s,%s) RETURNING id",
        (name, lat, lon),
    )
    return cur.fetchone()[0]


def upsert_observations(cur, location_id: int, rows: list[dict]) -> None:
    cur.executemany(
        """
        INSERT INTO weather_observations
            (location_id, observed_at, temperature)
        VALUES (%s, %s, %s)
        ON CONFLICT (location_id, observed_at) DO UPDATE SET
            temperature = EXCLUDED.temperature
        """,
        [(location_id, r["observed_at"], r["temperature"]) for r in rows],
    )


def backfill(year: int, month: int) -> None:
    days      = monthrange(year, month)[1]
    start_str = f"{year}-{month:02d}-01"
    end_str   = f"{year}-{month:02d}-{days:02d}"
    grid      = france_grid()

    log.info("Backfill %s → %s for %d grid points", start_str, end_str, len(grid))

    conn = connect()
    try:
        for idx, (lat, lon) in enumerate(grid, 1):
            log.info("[%d/%d] (%s, %s)", idx, len(grid), lat, lon)
            try:
                rows   = fetch_archive(lat, lon, start_str, end_str)
                cur    = conn.cursor()
                loc_id = get_or_create_location(cur, lat, lon)
                upsert_observations(cur, loc_id, rows)
                conn.commit()
            except Exception as exc:
                conn.rollback()
                log.warning("  SKIPPED (%s)", exc)
            time.sleep(REQUEST_DELAY_S)
    finally:
        conn.close()

    log.info("Backfill complete.")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "backfill":
        year, month = map(int, sys.argv[2].split("-"))
        backfill(year, month)
    else:
        print("Usage: python ingest.py backfill 2026-03")
        sys.exit(1)
