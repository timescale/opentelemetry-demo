-- service variable
SELECT value#>>'{}' FROM _ps_trace.tag WHERE key_id = 1;

-- pie chart
SELECT
    service_name,
    count(*) as num_err
FROM ps_trace.span
WHERE $__timeFilter(start_time)
AND status_code = 'error'
GROUP BY 1
;

-- table
SELECT
    x.service_name,
    x.span_name,
    x.num_err::numeric / x.num_total as err_rate
FROM
(
    SELECT
        service_name,
        span_name,
        count(*) filter (where status_code = 'error') as num_err,
        count(*) as num_total
    FROM ps_trace.span
    WHERE $__timeFilter(start_time)
    AND (service_name IN (${service:sqlstring}))
    GROUP BY 1, 2
) x
ORDER BY err_rate desc
;

-- time series
SELECT
    x.time,
    x.service_name,
    x.span_name,
    x.num_err::numeric / x.num_total as err_rate
FROM
(
    SELECT
        time_bucket('1 minute', start_time) as time,
        service_name,
        span_name,
        count(*) filter (where status_code = 'error') as num_err,
        count(*) as num_total
    FROM ps_trace.span
    WHERE $__timeFilter(start_time)
    AND service_name = '${service}'
    GROUP BY 1, 2, 3
) x
ORDER BY time
;