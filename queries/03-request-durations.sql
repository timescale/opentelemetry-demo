
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
    r.time,
    'p' || lpad((p.p * 100.0)::int::text, 2, '0') as percentile,
    approx_percentile(p.p, percentile_agg(r.duration_ms)) as duration
FROM
(
    SELECT
        time_bucket('1 minute', start_time) as time,
        duration_ms
    FROM ps_trace.span
    WHERE $__timeFilter(start_time)
    AND parent_span_id is null
) r
CROSS JOIN
(
    SELECT unnest(ARRAY[.01, .5, .75, .9, .95, .99]) as p
) p
GROUP BY r.time, p.p
ORDER BY r.time
;

-- table
SELECT
  trace_id,
  start_time,
  duration_ms,
FROM ps_trace.span
WHERE $__timeFilter(start_time)
AND parent_span_id is null
ORDER BY duration_ms DESC
LIMIT 10
;
