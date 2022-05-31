
-- nodes
WITH RECURSIVE x AS
(
    SELECT
        trace_id,
        span_id,
        parent_span_id,
        service_name,
        span_name
    FROM ps_trace.span
    WHERE $__timeFilter(start_time)
    AND service_name = '${service}'
    AND span_name = '${operation}'
    UNION ALL
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.span_id = s.parent_span_id)
)
SELECT
    md5(service_name || '-' || span_name) as id,
    span_name as title,
    service_name as "subTitle",
    count(*) as "mainStat"
FROM x
GROUP BY service_name, span_name
;

-- edges
WITH RECURSIVE x AS
(
    SELECT
        trace_id,
        span_id,
        parent_span_id,
        service_name,
        span_name,
        null::text as id,
        null::text as source,
        null::text as target
    FROM ps_trace.span
    WHERE $__timeFilter(start_time)
    AND service_name = '${service}'
    AND span_name = '${operation}'
    UNION ALL
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        md5(s.service_name || '-' || s.span_name || '-' || x.service_name || '-' || x.span_name) as id,
        md5(x.service_name || '-' || x.span_name) as source,
        md5(s.service_name || '-' || s.span_name) as target
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.span_id = s.parent_span_id)
)
SELECT DISTINCT
    x.id,
    x.source,
    x.target 
FROM x
WHERE id is not null
;

-- pie chart
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '${service}'
    AND s.span_name = '${operation}'
    UNION ALL
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.span_id = s.parent_span_id)
)
SELECT
    service_name,
    span_name,
    sum(duration_ms) as total_exec_time
FROM x
GROUP BY 1, 2
ORDER BY 3 DESC
;

-- time series graph
WITH RECURSIVE x AS
(
    SELECT
        time_bucket('15 seconds', s.start_time) as time,
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '${service}'
    AND s.span_name = '${operation}'
    UNION ALL
    SELECT
        time_bucket('15 seconds', s.start_time) as time,
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.span_id = s.parent_span_id)
)
SELECT
    time,
    service_name || ' ' || span_name as series,
    sum(duration_ms) as exec_ms
FROM x
GROUP BY 1, 2
ORDER BY 1
;

-- table
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms,
        s.status_code
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '${service}'
    AND s.span_name = '${operation}'
    UNION ALL
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms - coalesce(
        (
            SELECT sum(z.duration_ms)
            FROM ps_trace.span z
            WHERE s.trace_id = z.trace_id
            AND s.span_id = z.parent_span_id
        ), 0.0) as duration_ms,
        s.status_code
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.span_id = s.parent_span_id)
)
SELECT
    service_name,
    span_name as operation,
    sum(duration_ms) as total_exec_time,
    approx_percentile(0.5, percentile_agg(duration_ms)) as p50,
    approx_percentile(0.95, percentile_agg(duration_ms)) as p95,
    approx_percentile(0.99, percentile_agg(duration_ms)) as p99
FROM x
GROUP BY 1, 2
ORDER BY 3 DESC
;