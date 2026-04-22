-- benchmark/bbox_search.sql
-- Compares bounding-box search performance with no index vs. GiST index.
-- Target: all grid points inside southern France (lat 42–45°N, lon -2–8°E).
--
-- The && operator tests whether two geography bounding boxes overlap.
-- With a GiST index this becomes an R-tree lookup; without it, every
-- row's bounding box is computed and compared (sequential scan).


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
