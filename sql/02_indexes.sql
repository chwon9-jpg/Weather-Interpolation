-- 02_indexes.sql
-- Index management for benchmarking.

DROP INDEX IF EXISTS idx_locations_geog_gist;
CREATE INDEX idx_locations_geog_gist ON locations USING GIST(geog);


DROP INDEX IF EXISTS idx_obs_time_brin;
CREATE INDEX idx_obs_time_brin ON weather_observations USING BRIN(observed_at);


DROP INDEX IF EXISTS idx_obs_time_btree;
CREATE INDEX idx_obs_time_btree ON weather_observations(observed_at);


DROP INDEX IF EXISTS idx_obs_loc_time;
CREATE INDEX idx_obs_loc_time ON weather_observations(location_id, observed_at);
