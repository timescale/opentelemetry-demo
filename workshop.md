
## Prerequisites

1. The demo system runs in Docker. You'll need [Docker](https://www.docker.com/products/docker-desktop/) installed.
2. You may prefer to have a PostgreSQL client installed, however it is not required.

## Setup

### Download the Demo System

Use git to clone the repository to your local machine:

```bash
git clone git@github.com:timescale/opentelemetry-demo.git
cd opentelemetry-demo
```

Alternatively, you may download the repo as a zip file and extract it:

```bash
wget https://github.com/timescale/opentelemetry-demo/archive/refs/heads/main.zip
unzip main.zip
cd opentelemetry-demo-main
```

### Start the Demo System

In the root directory of the demo system (i.e. where the `docker-compose.yaml` file is), run the following command to start the system in docker. This will download/build the images, create the containers, and start everything up.

```bash
docker compose up --detach
```

To "pause" the system, run `docker compose stop`. To tear everything down, run `docker compose down`.

### Connecting to Components

#### Database

If you have psql (the PostgreSQL command line client) installed, you can connect to the database via:

```bash
psql -h localhost -p 5999 -d otel_demo -U postgres
```

If you do not have a PostgreSQL client installed, you can get a terminal on the database container via:

```bash
docker compose exec -it timescaledb bash
```

The psql client is installed in the container. From the terminal in the container, run this:

```bash
psql -d otel_demo
```

#### Grafana

An instance of Grafana is running in docker. Access it via [http://localhost:3000/](http://localhost:3000/). When you first connect, it will prompt you for a username and password. Both the username and password are `admin`. It will then prompt you to set a new password, which you may set to whatever you wish. 

#### Jaeger

An instance of Jaeger is running in docker. Access it via [http://localhost:16686/search](http://localhost:16686/search).

#### Microservices

Each of the microservices making up the demo system are exposed to the host so that you can easily "poke" each.

* Password Generator [http://localhost:5050/](http://localhost:5050/)
* Digit Service [http://localhost:5051/](http://localhost:5051/)
* Special Service [http://localhost:5052/](http://localhost:5052/)
* Upper Service [http://localhost:5053/](http://localhost:5053/)
* Lower Service [http://localhost:5054/](http://localhost:5054/)
  
## Building the Dashboard

### Filtering by Time

Grafana uses a template that can be inserted into SQL queries to utilize the time filter from the UI in the queries.

```sql
SELECT * FROM ps_trace.span s WHERE $__timeFilter(s.start_time);
```

The template from above expands to:

```sql
SELECT * FROM ps_trace.span s WHERE s.start_time BETWEEN <start> AND <end>;
```

### Dashboard 1

#### Trace Count

![Trace Count](/assets/trace-count.png)

How many traces are in the time window we have filtered on?
There can be many spans in a single trace, so we will only count the root spans.

```sql
SELECT count(*) as nbr_traces
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL -- only root spans
```

#### Throughput

![Throughput](/assets/throughput.png)

How many traces are collected in each 10 second bucket in the time window? As long as we are collecting all traces (i.e. not sampling), a count of traces is equivalent to throughput.

`time_bucket` is a timescaledb function, but you can acheive basically the same thing with `date_trunc`. `time_bucket` is more powerful and flexible.

```sql
SELECT
    time_bucket('10 seconds', s.start_time) as time,
    count(*) as nbr_traces
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL
GROUP BY time
ORDER BY time
```

##### Slowest Traces

![Slowest Traces](/assets/slowest-traces.png)

What are the top 10 slowest traces in the time window?
Each root span's duration encompasses all the childrens', so the duration of the root span IS the duration of the trace.

```sql
SELECT
    s.trace_id,
    s.duration_ms
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL
ORDER BY s.duration_ms DESC
LIMIT 10
```

#### Histogram of Latencies

A root span's duration is equivalent to request latency. The only difference is that it does not include the network time to and from the client. It is just the processing time.

Do all the requests take the same amount of time to process, or is there variation?
Let's build a histogram of the trace durations.

```sql
SELECT
    s.trace_id,
    s.duration_ms
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL
```

#### P95 Latencies

Do the latencies vary over time? Let's see how the P95 durations look over time.


```sql
SELECT
    time_bucket('10 seconds', s.start_time) as time,
    approx_percentile(0.95, percentile_agg(s.duration_ms)) as duration_p95
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL
GROUP BY time
ORDER BY time
```

#### Operation Execution Time Pie Chart

Each span's duration encompasses both the time spent in the span itself AND any time spent in it's children. 
If we want to know how much time was spent in the span alone, excluding the children, we can compute that.
We just need to subtract the sum of the durations of the direct child spans.

Let's build a pie chart. Each slice of the pie will correspond to an operation (combination of service and span names).
The value will be the total execution time spent in that operation (excluding children) for the time window we filtered on.

What does this tell us? It tells us which chunks of code across our entire system are consuming the most processing time. In other words, it tells us where to look if we want to eliminate bottlenecks.

```sql
SELECT
    s.service_name || ' ' || s.span_name as operation,
    sum(
        s.duration_ms - -- the parent's duration minus the sum of the direct childrens' durations
        coalesce(
        (
            -- the sum of the durations of the direct children
            SELECT sum(k.duration_ms)
            FROM ps_trace.span k -- kids
            WHERE k.trace_id = s.trace_id
            AND k.parent_span_id = s.span_id -- where the kid's parent is s
            AND $__timeFilter(k.start_time)
        ), 0)
    ) as total_exec_ms
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
GROUP BY s.service_name, s.span_name
```

#### Operation Execution Times Table

```sql
SELECT 
    x.service_name,
    x.span_name,
    avg(x.duration_ms) as avg_duration_ms,
    approx_percentile(0.95, percentile_agg(x.duration_ms)) as duration_p95
FROM
(
    SELECT
        s.trace_id,
        s.service_name,
        s.span_name,
        sum(
            s.duration_ms -
            coalesce(
            (
                -- the sum of the durations of the direct children
                SELECT sum(k.duration_ms)
                FROM ps_trace.span k
                WHERE k.trace_id = s.trace_id
                AND k.parent_span_id = s.span_id
                AND $__timeFilter(k.start_time)
            ), 0)
        ) as duration_ms
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    GROUP BY s.trace_id, s.service_name, s.span_name
) x
GROUP BY x.service_name, x.span_name
ORDER BY 4 DESC
```

#### Operation Execution Time over Time

```sql
SELECT
    time_bucket('10 seconds', s.start_time) as time,
    s.service_name || ' ' || s.span_name as operation,
    sum(
        s.duration_ms -
        coalesce(
        (
            -- the sum of the durations of the direct children
            SELECT sum(k.duration_ms)
            FROM ps_trace.span k
            WHERE k.trace_id = s.trace_id
            AND k.parent_span_id = s.span_id
            AND $__timeFilter(k.start_time)
        ), 0)
    ) as total_exec_ms
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
GROUP BY time, s.service_name, s.span_name
ORDER BY time, total_exec_ms
```

### Dashboard 2

#### Service Map

```sql
SELECT DISTINCT 
    s.service_name as id,
    s.service_name as title
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
```

```sql
SELECT
    src.service_name || '|' || tgt.service_name as id,
    src.service_name as source,
    src.service_name as target
FROM ps_trace.span src
INNER JOIN ps_trace.span tgt
ON (src.trace_id = tgt.trace_id
AND src.span_id = tgt.parent_span_id
AND src.service_name != tgt.service_name
)
WHERE $__timeFilter(src.start_time)
AND $__timeFilter(tgt.start_time)
GROUP BY src.service_name, tgt.service_name
```

#### Service Dependencies

```sql
SELECT
    src.service_name as source,
    tgt.service_name as target,
    tgt.span_name,
    sum(tgt.duration_ms) as total_exec_ms,
    avg(tgt.duration_ms) as avg_exec_ms,
    approx_percentile(0.95, percentile_agg(tgt.duration_ms)) as duration_p95
FROM ps_trace.span src
INNER JOIN ps_trace.span tgt
ON (src.trace_id = tgt.trace_id
AND src.span_id = tgt.parent_span_id
AND src.service_name != tgt.service_name)
WHERE $__timeFilter(src.start_time)
AND $__timeFilter(tgt.start_time)
GROUP BY 1, 2, 3
ORDER BY total_exec_ms DESC
```
