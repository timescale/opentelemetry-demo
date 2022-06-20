
# OpenTelemetry Tracing Workshop

## Prerequisites

1. The demo system runs in Docker. You'll need [Docker](https://www.docker.com/products/docker-desktop/) installed.
2. You may prefer to have a PostgreSQL client installed, however it is not required.

## Survey

Please help us out by taking this [short survey](https://forms.gle/Dy8RZb49NbCSSrme6). Your feedback will help us build a better product.

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

The first dashboard is [here](http://localhost:3000/d/RHrebSCnk/07-workshop-1?orgId=1&refresh=1m).
The SQL queries in each panel are commented out. 
As we discuss each, uncomment the query, and the panel will start working.
There is a copy of the dashboard with all the queries uncommented [here](http://localhost:3000/d/P0oHCvC7k/08-workshop-1-finished?orgId=1&refresh=1m).
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

![Histogram of Latencies](/assets/histogram-of-latencies.png)

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

![P95 Latencies](/assets/p95-latencies.png)

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

#### Histogram of Latencies over Time

![Histogram of Latencies over Time](/assets/histogram-of-latencies-over-time.png)

We have already built a histogram of latencies, but it was for the entire time window. What if we want to see how the histogram of latencies varies over time? In other words, let's see a histogram of latencies for every
10 second bucket in the window. This will give us a more detailed picture of the variability over time.

```sql
SELECT
    time_bucket('10 seconds', s.start_time) as time,
    s.duration_ms
FROM ps_trace.span s
WHERE $__timeFilter(s.start_time)
AND s.parent_span_id IS NULL
```

#### Operation Execution Time Pie Chart

![Operation Execution Time Pie Chart](/assets/operation-pie-chart.png)

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

![Operation Execution Times Table](/assets/operation-table.png)

For each operation (combination of service and span names), let's compute the average duration and the P95 duration.

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

![Operation Execution Time over Time](/assets/operation-time-over-time.png)

We built a histogram of latencies over time. What if we want to know which operations are contributing most to the latencies? Let's compute the total execution time spent in each operation in each 10 second bucket in the time window. If we stack these values, it should show us the operations contributing most to latencies over time.

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

The first dashboard focused on the time series aspects of our tracing data, but it did not explore the structure of the traces. Our second dashboard will focus on visualizing the structure of the traces.

The second dashboard is [here](http://localhost:3000/d/gRq8Gdjnz/09-workshop-2?orgId=1), and there is a copy of the dashboard with all the queries uncommented [here](http://localhost:3000/d/5ujdNdj7z/10-workshop-2-finished?orgId=1).

#### Upstream Spans Table

![Upstream Spans Table](/assets/upstream-spans-table.png)

Given a service name and a span name, we can use recursion to find all the spans that are upstream in all the traces in a given time window. In other words, "trace" the execution path from that span to back to where the request first entered the system.

```sql
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms,
        0::int as dist
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        p.trace_id,
        p.span_id,
        p.parent_span_id,
        p.service_name,
        p.span_name,
        p.duration_ms,
        x.dist + 1 as dist
    FROM ps_trace.span p
    INNER JOIN x 
    ON (p.trace_id = x.trace_id
    AND p.span_id = x.parent_span_id)
    WHERE $__timeFilter(p.start_time)
)
SELECT
    x.service_name,
    x.span_name,
    x.dist,
    approx_percentile(0.95, percentile_agg(x.duration_ms)) as duration_p95
FROM x
WHERE x.dist != 0
GROUP BY x.service_name, x.span_name, x.dist
ORDER BY x.dist
```

#### Downstream Spans Table

![Downstream Spans Table](/assets/downstream-spans-table.png)

By reversing the direction of our recursion, we can "trace" the execution downstream from a given span. In other words, we figure out all the spans that are called both directly and indirectly by the given span.

```sql
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        s.duration_ms,
        0::int as dist
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        k.trace_id,
        k.span_id,
        k.parent_span_id,
        k.service_name,
        k.span_name,
        k.duration_ms,
        x.dist + 1 as dist
    FROM ps_trace.span k
    INNER JOIN x 
    ON (k.trace_id = x.trace_id
    AND k.parent_span_id = x.span_id)
    WHERE $__timeFilter(k.start_time)
)
SELECT
    x.service_name,
    x.span_name,
    x.dist,
    approx_percentile(0.95, percentile_agg(x.duration_ms)) as duration_p95
FROM x
WHERE x.dist != 0
GROUP BY x.service_name, x.span_name, x.dist
ORDER BY x.dist
```

#### Upstream Spans Graph

![Upstream Spans Graph](/assets/upstream-spans-graph.png)

The upstream and downstream tables are nice, but it is difficult to visualize the structure of the calls. We can use Grafana's Node Graph panel to draw the structure of the upstream and downstream calls trees. The Node Graph panel requires two queries. The first query identifies the distinct nodes. The second query identifies the distinct edges. We only need to make minor changes to the queries we already have to get this working.

```sql
-- nodes
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        p.trace_id,
        p.span_id,
        p.parent_span_id,
        p.service_name,
        p.span_name
    FROM ps_trace.span p
    INNER JOIN x 
    ON (p.trace_id = x.trace_id
    AND p.span_id = x.parent_span_id)
    WHERE $__timeFilter(p.start_time)
)
SELECT DISTINCT
    concat(x.service_name, '|', x.span_name) as id,
    x.service_name as title,
    x.span_name as "subTitle"
FROM x
```

```sql
-- edges
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        null::text as child_service_name,
        null::text as child_span_name
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        p.trace_id,
        p.span_id,
        p.parent_span_id,
        p.service_name,
        p.span_name,
        x.service_name as child_service_name,
        x.span_name as child_span_name
    FROM ps_trace.span p
    INNER JOIN x 
    ON (p.trace_id = x.trace_id
    AND p.span_id = x.parent_span_id)
    WHERE $__timeFilter(p.start_time)
)
SELECT DISTINCT
    concat(
        x.child_service_name, '|', 
        x.child_span_name, '|', 
        x.service_name, '|', 
        x.span_name
    ) as id,
    concat(x.service_name, '|', x.span_name) as source,
    concat(x.child_service_name, '|', x.child_span_name) as target,
FROM x
WHERE x.child_service_name IS NOT NULL
```

#### Downstream Spans Graph

![Downstream Spans Graph](/assets/downstream-spans-graph.png)

Creating the downstream graph is basically a one-line change to the two queries used for the upstream graph.
Having both the upstream and the downstream graphs gives us a visualization of a span's place in the structure
of the call tree from the perspective of that span. This can be a super powerful tool for understanding your system.

```sql
-- nodes
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        k.trace_id,
        k.span_id,
        k.parent_span_id,
        k.service_name,
        k.span_name
    FROM ps_trace.span k
    INNER JOIN x 
    ON (k.trace_id = x.trace_id
    AND k.parent_span_id = x.span_id)
    WHERE $__timeFilter(k.start_time)
)
SELECT DISTINCT
    concat(x.service_name, '|', x.span_name) as id,
    x.service_name as title,
    x.span_name as "subTitle"
FROM x
```

```sql
-- edges
WITH RECURSIVE x AS
(
    SELECT
        s.trace_id,
        s.span_id,
        s.parent_span_id,
        s.service_name,
        s.span_name,
        null::text as parent_service_name,
        null::text as parent_span_name
    FROM ps_trace.span s
    WHERE $__timeFilter(s.start_time)
    AND s.service_name = '$service'
    AND s.span_name = '$span_name'
    UNION ALL
    SELECT
        k.trace_id,
        k.span_id,
        k.parent_span_id,
        k.service_name,
        k.span_name,
        x.service_name as parent_service_name,
        x.span_name as parent_span_name
    FROM ps_trace.span k
    INNER JOIN x 
    ON (k.trace_id = x.trace_id
    AND k.parent_span_id = x.span_id)
    WHERE $__timeFilter(k.start_time)
)
SELECT DISTINCT
    concat(
        x.service_name, '|', 
        x.span_name, '|',
        x.parent_service_name, '|', 
        x.parent_span_name
    ) as id,
    concat(x.parent_service_name, '|', x.parent_span_name) as source,
    concat(x.service_name, '|', x.span_name) as target
FROM x
WHERE x.parent_service_name IS NOT NULL
```
