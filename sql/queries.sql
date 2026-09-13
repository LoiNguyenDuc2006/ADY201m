
-- Step 3: sql/queries.sql
CREATE OR REPLACE TABLE rd AS SELECT * FROM 'data/processed/radar.parquet';
-- Q1: weekly traffic profile per location; traffic drop during outage hours
SELECT loc, dayofweek(ts) AS dow, hour(ts) AS hr, AVG(traffic) AS traffic FROM rd GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;
SELECT outage, AVG(traffic / NULLIF(w_mean, 0)) AS rel_traffic FROM (SELECT *, AVG(traffic) OVER (PARTITION BY loc, dayofweek(ts), hour(ts)) AS w_mean FROM rd) GROUP BY 1;
-- Q2: cloud incident hours: relative traffic change
SELECT cloud_inc, AVG(traffic / NULLIF(w_mean, 0)) AS rel_traffic FROM (SELECT *, AVG(traffic) OVER (PARTITION BY loc, dayofweek(ts), hour(ts)) AS w_mean FROM rd) GROUP BY 1;
-- Q3: features and targets: traffic 1 h and 24 h ahead, anomaly (relative drop below 0.7) in the next 3 h
CREATE OR REPLACE TABLE feat AS
SELECT loc, ts, traffic, outage, cloud_inc, hour(ts) AS hr, dayofweek(ts) AS dow,
       LAG(traffic, 1) OVER w AS t_lag1, LAG(traffic, 24) OVER w AS t_lag24, LAG(traffic, 168) OVER w AS t_lag168, AVG(traffic) OVER (w ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS t_ma24,
       traffic / NULLIF(AVG(traffic) OVER (w ROWS BETWEEN 167 PRECEDING AND CURRENT ROW), 0) AS rel_w, LEAD(traffic, 1) OVER w AS y_1h, LEAD(traffic, 24) OVER w AS y_24h,
       (MIN(traffic) OVER (w ROWS BETWEEN 1 FOLLOWING AND 3 FOLLOWING) / NULLIF(AVG(traffic) OVER (w ROWS BETWEEN 167 PRECEDING AND CURRENT ROW), 0) < 0.7)::INT AS y_drop_3h
FROM rd WINDOW w AS (PARTITION BY loc ORDER BY ts);
SELECT COUNT(*) AS n, COUNT(y_24h) AS n24, AVG(y_drop_3h) AS drop_share FROM feat;
