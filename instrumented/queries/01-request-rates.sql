
-- requests per second in each minute over the last 5 minutes
SELECT
    time_bucket('1 minute', start_time) as time,
    count(*) / 60.0 as req_per_sec
FROM ps_trace.span s
WHERE s.start_time >= now() - interval '5 minutes'
AND parent_span_id is null -- just the root spans
GROUP BY 1
ORDER BY 1
;

-- requests per second in each second over the last 5 minutes
SELECT
    time_bucket('1 second', start_time) as time,
    count(*) as req_per_sec
FROM ps_trace.span s
WHERE s.start_time >= now() - interval '5 minutes'
AND parent_span_id is null -- just the root spans
GROUP BY 1
ORDER BY 1
;

SELECT
    time_bucket('1 second', start_time) as time,
    count(*) as req_per_sec
FROM ps_trace.span s
WHERE $__timeFilter(start_time) -- grafana filtering
AND parent_span_id is null
GROUP BY 1
ORDER BY 1
;
