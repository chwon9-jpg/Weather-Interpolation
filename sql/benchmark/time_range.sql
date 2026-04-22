-- benchmark/time_range.sql
-- Compares time-range query performance across three index strategies:
-- No indes, BRIN, B-tree

-- BASELINE: sequential scan (no index on observed_at)
DROP INDEX IF EXISTS idx_obs_time_brin;
DROP INDEX IF EXISTS idx_obs_time_btree;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*)
FROM   weather_observations
WHERE  observed_at BETWEEN '2026-03-01 00:00:00+00'
                       AND '2026-03-07 23:00:00+00';

-- WITH BRIN INDEX
CREATE INDEX idx_obs_time_brin ON weather_observations USING BRIN(observed_at);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*)
FROM   weather_observations
WHERE  observed_at BETWEEN '2026-03-01 00:00:00+00'
                       AND '2026-03-07 23:00:00+00';

-- REPLACE BRIN WITH B-tree
DROP INDEX IF EXISTS idx_obs_time_brin;
CREATE INDEX idx_obs_time_btree ON weather_observations(observed_at);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT COUNT(*)
FROM   weather_observations
WHERE  observed_at BETWEEN '2026-03-01 00:00:00+00'
                       AND '2026-03-07 23:00:00+00';

-- COMBINED: spatial filter + time range (realistic production query)
CREATE INDEX IF NOT EXISTS idx_locations_geog_gist ON locations USING GIST(geog);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    wo.observed_at,
    wo.temperature,
    wo.rain
FROM   weather_observations wo
JOIN   locations l ON l.id = wo.location_id
WHERE  ST_DWithin(l.geog, ST_MakePoint(2.352, 48.857)::geography, 200000)
  AND  wo.observed_at BETWEEN '2026-03-01 00:00:00+00'
                          AND '2026-03-07 23:00:00+00'
ORDER  BY wo.observed_at;
