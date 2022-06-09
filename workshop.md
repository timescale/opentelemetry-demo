
## Prerequisites

1. The demo system runs in Docker. You'll need [Docker](https://www.docker.com/products/docker-desktop/) installed.
2. You may prefer to have a PostgreSQL client installed, however it is not required.

## Setup

### Download the Demo System

```bash
git clone git@github.com:timescale/opentelemetry-demo.git
cd opentelemetry-demo
```

or

```bash
wget https://github.com/timescale/opentelemetry-demo/archive/refs/heads/main.zip
unzip main.zip
cd opentelemetry-demo-main
```

### Start the Demo System

In the root directory of the demo system (i.e. where the `docker-compose.yaml` file is), run the following command to start the system in docker. This will download/build the images, create the containers, and start everything up.

```bash
docker compose up
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
  


