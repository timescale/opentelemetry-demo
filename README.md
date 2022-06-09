# OpenTelemetry Demo

## Summary

This repo contains a environment for demonstrating OpenTelemetry tracing
support in [Promscale](https://www.timescale.com/promscale).

## Workshop

This repo is used to deliver workshops on OpenTelemetry Traces and SQL. If you are here
to explore the workshop, head to this [page](./workshop.md).

## The Password Generator Service

A password generator service is instrumented with 
[OpenTelemetry tracing](https://opentelemetry-python.readthedocs.io/en/stable/). 
This is an absurd service and should not be taken as a shining example
of architecture nor coding. It exists as a playground example to generate
traces. The [lower service](./instrumented/lower) generates random lowercase letters. The 
[upper service](./instrumented/upper) service generates random uppercase letters. The 
[digit service](./instrumented/digit) generates random digits, and the 
[special service](./instrumented/special) generates random special characters. There is 
a [generator](./instrumented/generator) service which makes calls to the other services
to compose a random password. Finally, there is a [load script](./instrumented/load) which
continuously calls the generator service in order to simulate user load.

The **lower** service is a Ruby app using Sinatra framework while the other
services use Python with Flask.

There are two versions of the services. Those under the [instrumented](./instrumented/) 
directory have explicit instrumentation for tracing, whereas the versions under the 
[uninstrumented](./uninstrumented/) directory solely use auto-instrumentation.

## The Observability Infrastructure

All of the microservices forward their traces to an instance of the 
[OpenTelemetry Collector](https://opentelemetry.io/docs/collector/).
The collector sends the traces on to an instance of the 
[Promscale Collector](https://www.timescale.com/promscale) which 
stores them in a [TimescaleDB](https://www.timescale.com/products) 
database. An instance of the 
[Jaeger UI](https://www.jaegertracing.io/docs/1.30/frontend-ui/) 
is pointed to the Promscale instance, and an instance of 
[Grafana](https://grafana.com/grafana/) is pointed at both Jaeger
and the TimescaleDB database. In this way, you can use SQL to query
the traces directly in the database, and visualize tracing data in
Jaeger and Grafana dashboards.

## Running the System in Docker

When the system runs in docker it is configured via the 
[docker compose file](./docker-compose.yaml), and is operated with
docker-compose. Run the following command from the root of the repo
to (re)start the system.

```
docker-compose up --remove-orphans --build --detach
```

Once running, the following links will let you explore the
various components of the system:

- [password generator service](http://localhost:5050/)
- [digit service](http://localhost:5051/)
- [special service](http://localhost:5052/)
- [lower service](http://localhost:5053/)
- [upper service](http://localhost:5054/)
- [Grafana](http://localhost:3000/)
- [Jaeger](http://localhost:16686/search)

When you are ready to shutdown the system, use the following command.

```
docker-compose down
```

## Running the System in Kubernetes

When you want to run the system in k8s you can use the following commands (if you have certmanager installed skip that step):

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.0/cert-manager.yaml
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
kubectl apply -k ./yaml
```

You should wait for the OpenTelemetry Operator pod to come up before you run the second
command. 

You should see data flowing into Grafana automatically.

To access individual services as per the Docker instructions below you will need to run
```
sh ./yaml/port-forward.sh
```


## Connecting to TimescaleDB

You can use any SQL client that supports PostgreSQL to connect to the TimescaleDB
database. The database is not password protected.

Use the psql client to connect to the Timescaledb instance via:

```bash
psql -h localhost -p 5999 -d otel_demo -U postgres
```
## Examples

_Note: the default Grafana login credentials are user "admin" and password "admin". Once you log in for the first time you will be asked to update your password._

### Request Rates

[Grafana Dashboard](http://localhost:3000/d/QoZDH91nk/01-request-rate?orgId=1)

[Queries](instrumented/queries/01-request-rates.sql)

### Error Rates

[Grafana Dashboard](http://localhost:3000/d/CiE9l917z/02-error-rates?orgId=1)

[Queries](instrumented/queries/02-error-rates.sql)

### Request Durations

[Grafana Dashboard](http://localhost:3000/d/GkrS6rJ7z/03-request-durations?orgId=1)

[Queries](instrumented/queries/03-request-durations.sql)

### Service Dependencies

[Grafana Dashboard](http://localhost:3000/d/scyq99J7k/04-service-dependencies?orgId=1)

[Queries](instrumented/queries/04-service-dependencies.sql)

### Upstream Spans

[Grafana Dashboard](http://localhost:3000/d/lyIow61nz/05-upstream-spans?orgId=1)

[Queries](instrumented/queries/05-upstream-spans.sql)

### Downstream Spans

[Grafana Dashboard](http://localhost:3000/d/SdzI3eJnk/06-downstream-spans?orgId=1)

[Queries](instrumented/queries/06-downstream-spans.sql)
