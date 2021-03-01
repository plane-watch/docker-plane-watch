# plane-watch/plane-watch

[![Discord](https://img.shields.io/discord/207038656311984139)](https://discord.gg/QjKdHDFgkj)

Docker container to feed ADS-B data into [plane.watch](https://plane.watch/). Designed to work in tandem with [mikenye/readsb-protobuf](https://hub.docker.com/r/mikenye/readsb-protobuf) or another BEAST provider. Builds and runs on x86, x86_64, arm32v6, arm32v7 & arm64v8.

The container pulls ADS-B information from a BEAST provider and sends data to [plane.watch](https://plane.watch/).

[plane.watch](https://plane.watch/) is a small group of friends and aviation enthusiasts who operate an ADS-B data collection and display service for the benefit of the general public. While we are primarily based in Australia, we welcome data contributions from all over the world. We are a non-commercial entity - no data is sold or filtered/blocked.

For more information, please [join our Discord](https://discord.gg/QjKdHDFgkj) and say g'day.

## Supported tags and respective Dockerfiles

* `latest`: built nightly from the [`main` branch](https://github.com/plane-watch/docker-plane-watch/tree/main) [`Dockerfile`](https://github.com/plane-watch/docker-plane-watch/blob/main/Dockerfile) for all supported architectures.
* `latest_nohealthcheck` is the same as the `latest` version above. However, this version has the docker healthcheck removed. This is done for people running platforms (such as [Nomad](https://www.nomadproject.io)) that don't support manually disabling healthchecks, where healthchecks are not wanted.
* Specific version and architecture tags are available if required, however these are not regularly updated. It is generally recommended to run `latest`.

## Getting Started

### Register for a plane.watch feeder account

Head over to <https://atc.plane.watch> and sign up for an account.

### Create your feeder

Login to <https://atc.plane.watch>, click on **Resources**, **Feeders**, **+ New Feeder**. Fill out your details.

* Your **feed direction** should be set to **push**.
* Your **feed protocol** should be set to **beast**.

When you save your feeder, an **API Key** will be generated. Take note of this, as it will be required when deploying the feeder container.

## Up-and-Running with `docker run`

Our feeder container can be deployed with `docker run` as follows:

```shell
docker run \
 -d \
 --rm \
 --name planewatch \
 -e TZ=YOUR_TIMEZONE \
 -e BEASTHOST=YOUR_BEASTHOST \
 -e API_KEY=YOUR_API_KEY \
 --tmpfs=/run:exec,size=64M \
 --tmpfs=/var/log \
 plane-watch/plane-watch
```

Where:

* `YOUR_TIMEZONE` is your timezone in ["TZ database name" format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) (eg: `Australia/Perth`)
* `YOUR_BEASTHOST` is the hostname, IP address or container name of a beast protocol provider (eg: `piaware`)
* `YOUR_API_KEY` is your plane.watch feeder API Key

You can test to ensure your container is seeing ADS-B data by running:

```
docker exec -it planewatch viewadsb
```

## Up-and-Running with Docker Compose

```yaml
version: '3.8'

services:
  planewatch:
    image: plane-watch/plane-watch
    tty: true
    container_name: planewatch
    restart: always
    environment:
      - BEASTHOST=YOUR_BEASTHOST
      - TZ=YOUR_TIMEZONE
      - UUID=YOUR_API_KEY
    tmpfs:
      - /run:exec,size=64M
      - /var/log
```

Where:

* `YOUR_TIMEZONE` is your timezone in ["TZ database name" format](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List) (eg: `Australia/Perth`)
* `YOUR_BEASTHOST` is the hostname, IP address or container name of a beast protocol provider (eg: `piaware`)
* `YOUR_API_KEY` is your plane.watch feeder API Key

You can test to ensure your container is seeing ADS-B data by running:

```
docker exec -it planewatch viewadsb
```

## Runtime Environment Variables

There are a series of available environment variables:

| Environment Variable           | Purpose                                                                               | Default                 |
| ------------------------------ | ------------------------------------------------------------------------------------- | ----------------------- |
| `BEASTHOST`                    | Required. IP, hostname or container name of a Mode-S/BEAST provider (readsb/dump1090) |                         |
| `BEASTPORT`                    | Optional. TCP port number of Mode-S/BEAST provider (readsb/dump1090)                  | `30005`                 |
| `API_KEY`                      | Required. Your plane.watch API Key                                                    |                         |
| `TZ`                           | Optional. Your local timezone                                                         | `GMT`                   |
| `REDUCE_INTERVAL`              | Optional. How often beast data is transmitted for each tracked aircraft.              | `0.5`                   |
| `PW_FEED_DESTINATION_HOSTNAME` | Optional. Allows changing the hostname that ADS-B data is fed to.                     | `feed.push.plane.watch` |
| `PW_FEED_DESTINATION_PORT`     | Optional. Allows changing the TCP port that ADS-B data is fed to.                     | [`12345`](https://www.youtube.com/watch?v=a6iW-8xPw3k) |

## Ports

No ports are required to be mapped to this container.

## Logging

* All processes are logged to the container's stdout, and can be viewed with `docker logs [-f] container`.

## Getting help

Please feel free to:

* [Open an issue on the project's GitHub](https://github.com/plane-watch/docker-plane-watch/issues).
* [Join our Discord](https://discord.gg/QjKdHDFgkj) and say g'day.

## Changelog

See the [commit history](https://github.com/plane-watch/docker-plane-watch/commits/main) on GitHub.
