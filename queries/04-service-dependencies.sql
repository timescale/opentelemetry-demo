
-- nodes
SELECT
    service_name as id,
    service_name as title
FROM ps_trace.span
WHERE $__timeFilter(start_time)
GROUP BY service_name
;

-- edges
SELECT
    p.service_name || '->' || k.service_name || ':' || k.span_name as id,
    p.service_name as source,
    k.service_name as target,
    k.span_name as "mainStat",
    count(*) as "secondaryStat"
FROM ps_trace.span p
INNER JOIN ps_trace.span k
ON (p.trace_id = k.trace_id
AND p.span_id = k.parent_span_id
AND p.service_name != k.service_name)
WHERE $__timeFilter(p.start_time)
GROUP BY 1, 2, 3, 4
;

-- table
SELECT
    p.service_name as source,
    k.service_name as target,
    k.span_name,
    count(*) as calls,
    sum(k.duration_ms) as total_exec_ms,
    avg(k.duration_ms) as avg_exec_ms
FROM ps_trace.span p
INNER JOIN ps_trace.span k
ON (p.trace_id = k.trace_id
AND p.span_id = k.parent_span_id
AND p.service_name != k.service_name)
WHERE $__timeFilter(p.start_time)
GROUP BY 1, 2, 3
ORDER BY total_exec_ms DESC
;