# planewatch/plane-watch

![Docker Image Size (tag)](https://img.shields.io/docker/image-size/planewatch/plane-watch/latest_amd64) [![Discord](https://img.shields.io/discord/207038656311984139)](https://discord.gg/QjKdHDFgkj)

Docker container to feed ADS-B data into [plane.watch](https://plane.watch/). Designed to work in tandem with `readsb`/`dump1090` or another BEAST provider. Builds and runs on x86, x86_64, arm32v6, arm32v7 & arm64v8.

The container pulls ADS-B data from a BEAST provider and sends data to [plane.watch](https://plane.watch/).

[plane.watch](https://plane.watch/) is a small group of friends and aviation enthusiasts who operate an ADS-B, ACARS and VDLM2 data collection and display service for the benefit of the general public. While we are primarily based in Australia, we welcome data contributions from all over the world. We are a non-commercial entity - no data is sold or filtered/blocked.

For more information, please [join our Discord](https://discord.gg/QjKdHDFgkj) and say g'day.

## Supported tags and respective Dockerfiles

* `latest`: built nightly from the [`main` branch](https://github.com/plane-watch/docker-plane-watch/tree/main) [`Dockerfile`](https://github.com/plane-watch/docker-plane-watch/blob/main/Dockerfile) for all supported architectures.
* `latest_nohealthcheck` is the same as the `latest` version above. However, this version has the docker healthcheck removed. This is done for people running platforms (such as [Nomad](https://www.nomadproject.io)) that don't support manually disabling healthchecks, where healthchecks are not wanted.
* Specific version and architecture tags are available if required, however these are not regularly updated. It is generally recommended to run `latest`.

## Getting Started

### Register for a plane.watch feeder account

Head over to <https://atc.plane.watch> and sign up for an account.

### Create your feeder

Login to <https://atc.plane.watch>, click on **Feeders**, **+ New Feeder**. Fill out your details.

When you save your feeder, an **API Key** will be generated. Take note of this, as it will be required when deploying the feeder container.

## Basic Up-and-Running with `docker run`

Our feeder container can be deployed with `docker run` as follows:

```shell
docker run \
  -d \
  --rm \
  --name planewatch \
  -e TZ=YOUR_TIMEZONE \
  -e BEASTHOST=YOUR_BEASTHOST \
  -e API_KEY=YOUR_API_KEY \
  -e LAT=YOUR_LATITUDE \
  -e LONG=YOUR_LONGITUDE \
  -e ALT=YOUR_ALTITUDE \
  --tmpfs=/run:exec,size=64M \
  --tmpfs=/var/log \
  ghcr.io/plane-watch/docker-plane-watch:latest
```

Where:

* `YOUR_TIMEZONE` is your timezone in ["TZ database name" format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) (eg: `Australia/Perth`)
* `YOUR_BEASTHOST` is the hostname, IP address or container name of a beast protocol provider (eg: `piaware`)
* `YOUR_API_KEY` is your plane.watch feeder API Key
* `YOUR_LATITUDE` is the latitude of your antenna (xx.xxxxx)
* `YOUR_LONGITUDE` is the longitude of your antenna (xx.xxxxx)
* `YOUR_ALTITUDE` is the your antenna altitude, and should be suffixed with either `m` or `ft`. If no suffix, will default to `m`.

You can test to ensure your container is seeing ADS-B data by running:

```
docker exec -it planewatch viewadsb
```

## Basic Up-and-Running with Docker Compose

```yaml
version: '3.8'

services:
  planewatch:
    image: ghcr.io/plane-watch/docker-plane-watch:latest
    tty: true
    container_name: planewatch
    restart: always
    environment:
      - BEASTHOST=YOUR_BEASTHOST
      - TZ=YOUR_TIMEZONE
      - API_KEY=YOUR_API_KEY
      - LAT=YOUR_LATITUDE
      - LONG=YOUR_LONGITUDE
      - ALT=YOUR_ALTITUDE
    tmpfs:
      - /run:exec,size=64M
      - /var/log
```

Where:

* `YOUR_TIMEZONE` is your timezone in ["TZ database name" format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) (eg: `Australia/Perth`)
* `YOUR_BEASTHOST` is the hostname, IP address or container name of a beast protocol provider (eg: `piaware`)
* `YOUR_API_KEY` is your plane.watch feeder API Key
* `YOUR_LATITUDE` is the latitude of your antenna (xx.xxxxx)
* `YOUR_LONGITUDE` is the longitude of your antenna (xx.xxxxx)
* `YOUR_ALTITUDE` is the your antenna altitude, and should be suffixed with either `m` or `ft`. If no suffix, will default to `m`.

You can test to ensure your container is seeing ADS-B data by running:

```
docker exec -it planewatch viewadsb
```

## Runtime Environment Variables

There are a series of available environment variables:

| Environment Variable | Purpose | Default |
| --- | --- | --- |
| `API_KEY` | Required. Your plane.watch API Key | |
| `BEASTHOST` | Required. IP, hostname or container name of a Mode-S/BEAST provider (readsb/dump1090) | |
| `BEASTPORT` | Optional. TCP port number of Mode-S/BEAST provider (readsb/dump1090) | `30005` |
| `LAT` | Required for MLAT | Latitude of receiver antenna | |
| `LONG` | Required for MLAT | Longitude of receiver antenna | |
| `ALT` | Required for MLAT | Altitude of receiver antenna. Suffixed with `ft` or `m`. | |
| `ENABLE_MLAT` | Optional. Set to `false` to disable MLAT | `true` |
| `MLAT_DATASOURCE` | Optional. IP/Hostname and port of an MLAT data source | `BEASTHOST:BEASTPORT` setting if omitted |
| `TZ` | Optional. Your local timezone | `GMT` |

## Ports

No ports are required to be mapped to this container, however the following ports are available:

| TCP Port | Description                                                                                                                 |
|----------|-----------------------------------------------------------------------------------------------------------------------------|
| 2112     | Exposes Prometheus metrics for the pw-feeder binary.</br>These can then be accessed via `http://<dockerhost>:2112/metrics`. |
| 30105    | Exposes MLAT results in BEAST protocol                                                                                      |

## Logging

* All processes are logged to the container's stdout, and can be viewed with `docker logs [-f] container`.

## Getting help

Please feel free to:

* [Open an issue on the project's GitHub](https://github.com/plane-watch/docker-plane-watch/issues).
* [Join our Discord](https://discord.gg/QjKdHDFgkj) and say g'day.
