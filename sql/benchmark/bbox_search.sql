-- benchmark/bbox_search.sql
-- Compares bounding-box search performance with no index vs. GiST index.
-- Target: all grid points inside southern France (lat 42–45°N, lon -2–8°E).

-- BASELINE: sequential scan
DROP INDEX IF EXISTS idx_locations_geog_gist;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon
FROM   locations l
WHERE  l.geog && ST_MakeEnvelope(-2.0, 42.0, 8.0, 45.0, 4326)::geography
ORDER  BY l.lat, l.lon;

-- WITH GiST INDEX
CREATE INDEX idx_locations_geog_gist ON locations USING GIST(geog);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon
FROM   locations l
WHERE  l.geog && ST_MakeEnvelope(-2.0, 42.0, 8.0, 45.0, 4326)::geography
ORDER  BY l.lat, l.lon;


-- BOUNDING BOX JOINED WITH weather_observations
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    ROUND(AVG(wo.temperature)::NUMERIC, 2) AS avg_temp_c,
    ROUND(AVG(wo.humidity)::NUMERIC,    2) AS avg_humidity_pct,
    ROUND(SUM(wo.rain)::NUMERIC,        2) AS total_rain_mm
FROM   training_observations wo
JOIN   locations l ON l.id = wo.location_id
WHERE  l.geog && ST_MakeEnvelope(-2.0, 42.0, 8.0, 45.0, 4326)::geography
  AND  wo.observed_at BETWEEN '2026-03-01 00:00:00+00'
                          AND '2026-03-31 23:00:00+00'
GROUP  BY l.name
ORDER  BY avg_temp_c DESC;