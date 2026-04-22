-- benchmark/radius_search.sql
-- Compares radius search (ST_DWithin) with no index vs. GiST index.
-- Target: all grid points within 150 km of Lyon (45.764°N, 4.836°E).

-- BASELINE: sequential scan
DROP INDEX IF EXISTS idx_locations_geog_gist;

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon,
    ST_Distance(l.geog, ST_MakePoint(4.836, 45.764)::geography) AS dist_m
FROM   locations l
WHERE  ST_DWithin(l.geog, ST_MakePoint(4.836, 45.764)::geography, 150000)
ORDER  BY dist_m;


-- WITH GiST INDEX
CREATE INDEX idx_locations_geog_gist ON locations USING GIST(geog);

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    l.name,
    l.lat,
    l.lon,
    ST_Distance(l.geog, ST_MakePoint(4.836, 45.764)::geography) AS dist_m
FROM   locations l
WHERE  ST_DWithin(l.geog, ST_MakePoint(4.836, 45.764)::geography, 150000)
ORDER  BY dist_m;
