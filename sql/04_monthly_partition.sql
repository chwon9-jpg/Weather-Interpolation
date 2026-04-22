-- 04_monthly_partition.sql
-- Creates one partition per month for weather_observations.
-- Run this BEFORE ingesting data for that month.
-- PostgreSQL will route INSERTs to the correct partition automatically.

CREATE TABLE IF NOT EXISTS weather_observations_2026_03
    PARTITION OF weather_observations
    FOR VALUES FROM ('2026-03-01 00:00:00+00')
               TO   ('2026-04-01 00:00:00+00');
