
-- heat map
SELECT
  start_time as time,
  duration_ms
FROM ps_trace.span
WHERE $__timeFilter(start_time)
AND parent_span_id is null
ORDER BY 1
;

-- histogram
SELECT duration_ms
FROM ps_trace.span
WHERE $__timeFilter(start_time)
AND parent_span_id is null
;

-- percentiles
SELECT
    time_bucket('1 minute', start_time) as time,
    ROUND(approx_percentile(0.99, percentile_agg(duration_ms))::numeric, 3) as duration_p99,
    ROUND(approx_percentile(0.95, percentile_agg(duration_ms))::numeric, 3) as duration_p95,
    ROUND(approx_percentile(0.90, percentile_agg(duration_ms))::numeric, 3) as duration_p90,
    ROUND(approx_percentile(0.50, percentile_agg(duration_ms))::numeric, 3) as duration_p50
FROM span
WHERE
    $__timeFilter(start_time)
    AND parent_span_id is null
GROUP BY time
ORDER BY time
;

-- table
SELECT
  trace_id,
  start_time,
  duration_ms
FROM ps_trace.span
WHERE $__timeFilter(start_time)
AND parent_span_id is null
ORDER BY duration_ms DESC
LIMIT 10
;
