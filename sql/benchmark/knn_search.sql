-- benchmark/knn_search.sql
-- Compares kNN spatial search performance with and without a GiST index.
-- Target: 5 nearest grid points to Paris (48.857 degrees North, 2.352 degrees East).

-- BASELINE: sequential scan (no spatial index)
DROP INDEX IF EXISTS idx_locations_geog_gist;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon,
    ST_Distance(l.geog, ST_MakePoint(2.352, 48.857)::geography) AS dist_m
FROM   locations l
ORDER  BY l.geog <-> ST_MakePoint(2.352, 48.857)::geography
LIMIT  5;

-- STEP 2 — WITH GiST INDEX
CREATE INDEX idx_locations_geog_gist ON locations USING GIST(geog);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon,
    ST_Distance(l.geog, ST_MakePoint(2.352, 48.857)::geography) AS dist_m
FROM   locations l
ORDER  BY l.geog <-> ST_MakePoint(2.352, 48.857)::geography
LIMIT  5;

-- kNN JOINED WITH weather_observations (realistic query)
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon,
    wo.temperature,
    wo.humidity,
    wo.rain,
    wo.soil_temp,
    ST_Distance(l.geog, ST_MakePoint(2.352, 48.857)::geography) AS dist_m
FROM   training_observations wo
JOIN   locations l ON l.id = wo.location_id
WHERE  wo.observed_at = '2026-03-15 12:00:00+00'
ORDER  BY l.geog <-> ST_MakePoint(2.352, 48.857)::geography
LIMIT  5;
