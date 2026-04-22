-- 01_schema.sql
-- Core tables — NO indexes (managed in 02_indexes.sql)

CREATE EXTENSION IF NOT EXISTS postgis;

-- LOCATIONS
CREATE TABLE IF NOT EXISTS locations (
    id           SERIAL PRIMARY KEY,
    name         TEXT,
    lat          DOUBLE PRECISION NOT NULL,
    lon          DOUBLE PRECISION NOT NULL,
    is_test_zone BOOLEAN NOT NULL DEFAULT FALSE,
    elevation    DOUBLE PRECISION,

    geog GEOGRAPHY(Point, 4326)
         GENERATED ALWAYS AS (
             ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography
         ) STORED
);

-- TEST ZONES
CREATE TABLE IF NOT EXISTS test_zones (
    id          SERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    center_geog GEOGRAPHY(Point, 4326) NOT NULL,
    radius_m    DOUBLE PRECISION NOT NULL
);

-- WEATHER OBSERVATIONS (partitioned by month)
-- Each month is a separate physical sub-table (partition).

CREATE TABLE IF NOT EXISTS weather_observations (
    location_id INTEGER     NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    observed_at TIMESTAMPTZ NOT NULL,
    temperature DOUBLE PRECISION,   -- degrees Celsius (2 m air temperature)
    humidity    DOUBLE PRECISION,   -- %   (relative humidity at 2 m)
    rain        DOUBLE PRECISION,   -- mm  (hourly precipitation)
    soil_temp   DOUBLE PRECISION,   -- degrees CElsius  (soil temperature 7–28 cm depth)
    PRIMARY KEY (location_id, observed_at)
) PARTITION BY RANGE (observed_at);

-- TRAINING VIEW
CREATE OR REPLACE VIEW training_observations AS
SELECT wo.*
FROM   weather_observations wo
JOIN   locations l ON l.id = wo.location_id
WHERE  l.is_test_zone = FALSE;