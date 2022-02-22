
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
    AND x.parent_span_id = s.span_id)
)
SELECT
    md5(service_name || '-' || span_name) as id,
    span_name as title,
    service_name as "subTitle",
    count(distinct span_id) as "mainStat"
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
        null::text as target,
        null::text as source
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
        md5(x.service_name || '-' || x.span_name) as target,
        md5(s.service_name || '-' || s.span_name) as source
    FROM x
    INNER JOIN ps_trace.span s
    ON (x.trace_id = s.trace_id
    AND x.parent_span_id = s.span_id)
)
SELECT DISTINCT
    x.id,
    x.target,
    x.source 
FROM x
WHERE id is not null
;

