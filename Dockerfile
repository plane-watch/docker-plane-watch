# syntax=docker/dockerfile:1

FROM debian:bookworm@sha256:813017f3d62be4b5891a7acca6a01bdcd4b8513daa81b1ab99d3a50385b26931 AS debian_base
RUN rm -f /etc/apt/apt.conf.d/docker-clean


FROM debian_base AS viewadsb_builder
ARG READSB_PROTOBUF_BRANCH
ARG READSB_PROTOBUF_REF=618c6e5faaf918fe1ff4e15e35abe8a7ab088c5e
ARG TARGETARCH
ARG TARGETVARIANT
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /src/readsb
RUN --mount=type=cache,id=apt-cache-${TARGETARCH}${TARGETVARIANT},target=/var/cache/apt,sharing=locked --mount=type=cache,id=apt-lists-${TARGETARCH}${TARGETVARIANT},target=/var/lib/apt,sharing=locked \
    set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      libncurses5-dev \
      libprotobuf-c-dev \
      librrd-dev \
      pkg-config \
      protobuf-c-compiler
RUN --mount=type=cache,id=readsb-src-${TARGETARCH}${TARGETVARIANT},target=/src/readsb,sharing=locked \
    set -x && \
    READSB_REPOSITORY=https://github.com/mictronics/readsb-protobuf.git && \
    if [[ ! -d /src/readsb/.git ]]; then \
      find /src/readsb -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + && \
      git -C /src/readsb init && \
      git -C /src/readsb remote add origin "${READSB_REPOSITORY}"; \
    fi && \
    git -C /src/readsb remote set-url origin "${READSB_REPOSITORY}" && \
    git -C /src/readsb config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && \
    if [[ "$(git -C /src/readsb rev-parse --is-shallow-repository)" == true ]]; then \
      git -C /src/readsb fetch --unshallow --force --prune --tags origin; \
    else \
      git -C /src/readsb fetch --force --prune --tags origin; \
    fi && \
    TARGET_REF="${READSB_PROTOBUF_BRANCH:-$READSB_PROTOBUF_REF}" && \
    if git -C /src/readsb show-ref --verify --quiet "refs/remotes/origin/${TARGET_REF}"; then \
      TARGET_REF="origin/${TARGET_REF}"; \
    fi && \
    git -C /src/readsb clean -ffdx && \
    git -C /src/readsb checkout --detach --force "${TARGET_REF}" && \
    git -C /src/readsb clean -ffdx && \
    make viewadsb && \
    cp -v ./viewadsb /usr/local/bin/viewadsb && \
    /usr/local/bin/viewadsb --help


FROM golang:1.26-bookworm@sha256:6c5605ab3a9a9fb3c4eafe5b3d63cdbf3881caf113262b67862547b54a9db599 AS pw_feeder_builder
ARG PW_FEEDER_BRANCH
ARG PW_FEEDER_REF=fac8bcc8959f3c53e29ce5ec8c80a87f458e63ed
ARG PW_FEEDER_VERSION=v0.0.11
ARG TARGETARCH
ARG TARGETVARIANT
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /src/pw-feeder
RUN --mount=type=cache,id=pw-feeder-src-${TARGETARCH}${TARGETVARIANT},target=/src/pw-feeder,sharing=locked --mount=type=cache,id=pw-feeder-go-build-${TARGETARCH}${TARGETVARIANT},target=/root/.cache/go-build --mount=type=cache,id=pw-feeder-go-mod,target=/go/pkg/mod \
    set -x && \
    PW_FEEDER_REPOSITORY=https://github.com/plane-watch/pw-feeder.git && \
    if [[ ! -d /src/pw-feeder/.git ]]; then \
      find /src/pw-feeder -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + && \
      git -C /src/pw-feeder init && \
      git -C /src/pw-feeder remote add origin "${PW_FEEDER_REPOSITORY}"; \
    fi && \
    git -C /src/pw-feeder remote set-url origin "${PW_FEEDER_REPOSITORY}" && \
    git -C /src/pw-feeder config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && \
    if [[ "$(git -C /src/pw-feeder rev-parse --is-shallow-repository)" == true ]]; then \
      git -C /src/pw-feeder fetch --unshallow --force --prune --tags origin; \
    else \
      git -C /src/pw-feeder fetch --force --prune --tags origin; \
    fi && \
    TARGET_REF="${PW_FEEDER_BRANCH:-$PW_FEEDER_REF}" && \
    if git -C /src/pw-feeder show-ref --verify --quiet "refs/remotes/origin/${TARGET_REF}"; then \
      TARGET_REF="origin/${TARGET_REF}"; \
    fi && \
    git -C /src/pw-feeder clean -ffdx && \
    git -C /src/pw-feeder checkout --detach --force "${TARGET_REF}" && \
    git -C /src/pw-feeder clean -ffdx && \
    pushd /src/pw-feeder/pw-feeder && \
    go mod download && \
    go generate -v ./... && \
    go build -mod=readonly -trimpath -v ./cmd/pw-feeder/ && \
    cp -v /src/pw-feeder/pw-feeder/pw-feeder /usr/local/sbin/pw-feeder && \
    popd && \
    echo "${PW_FEEDER_BRANCH:-$PW_FEEDER_VERSION}" > /PW_FEEDER_VERSION && \
    /usr/local/sbin/pw-feeder --help


FROM debian_base AS mlat_client_builder
ARG MLAT_CLIENT_BRANCH
ARG MLAT_CLIENT_REF=28ae4f7409c9dfddd2bb8984baadce5d31fdc8e3
ARG TARGETARCH
ARG TARGETVARIANT
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
WORKDIR /src/mlat-client
RUN --mount=type=cache,id=apt-cache-${TARGETARCH}${TARGETVARIANT},target=/var/cache/apt,sharing=locked --mount=type=cache,id=apt-lists-${TARGETARCH}${TARGETVARIANT},target=/var/lib/apt,sharing=locked \
    set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      git \
      libpython3-dev \
      python3-venv
RUN --mount=type=cache,id=mlat-client-src-${TARGETARCH}${TARGETVARIANT},target=/src/mlat-client,sharing=locked --mount=type=cache,id=mlat-client-pip-${TARGETARCH}${TARGETVARIANT},target=/root/.cache/pip,sharing=locked \
    set -x && \
    MLAT_CLIENT_REPOSITORY=https://github.com/wiedehopf/mlat-client.git && \
    if [[ ! -d /src/mlat-client/.git ]]; then \
      find /src/mlat-client -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + && \
      git -C /src/mlat-client init && \
      git -C /src/mlat-client remote add origin "${MLAT_CLIENT_REPOSITORY}"; \
    fi && \
    git -C /src/mlat-client remote set-url origin "${MLAT_CLIENT_REPOSITORY}" && \
    git -C /src/mlat-client config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && \
    if [[ "$(git -C /src/mlat-client rev-parse --is-shallow-repository)" == true ]]; then \
      git -C /src/mlat-client fetch --unshallow --force --prune --tags origin; \
    else \
      git -C /src/mlat-client fetch --force --prune --tags origin; \
    fi && \
    TARGET_REF="${MLAT_CLIENT_BRANCH:-$MLAT_CLIENT_REF}" && \
    if git -C /src/mlat-client show-ref --verify --quiet "refs/remotes/origin/${TARGET_REF}"; then \
      TARGET_REF="origin/${TARGET_REF}"; \
    fi && \
    git -C /src/mlat-client clean -ffdx && \
    git -C /src/mlat-client checkout --detach --force "${TARGET_REF}" && \
    git -C /src/mlat-client clean -ffdx && \
    python3 -m venv /opt/mlat-client && \
    /opt/mlat-client/bin/pip install --use-pep517 /src/mlat-client && \
    /opt/mlat-client/bin/mlat-client --help && \
    /opt/mlat-client/bin/python -m pip uninstall --yes pip setuptools


FROM debian_base AS s6_overlay_builder
# S6_OVERLAY_VERSION and all SHA-256 values below must be updated together.
ARG S6_OVERLAY_VERSION=v3.2.3.2
ARG TARGETARCH
ARG TARGETVARIANT
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,id=apt-cache-${TARGETARCH}${TARGETVARIANT},target=/var/cache/apt,sharing=locked --mount=type=cache,id=apt-lists-${TARGETARCH}${TARGETVARIANT},target=/var/lib/apt,sharing=locked \
    set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      xz-utils
RUN --mount=type=cache,id=s6-overlay-downloads-${TARGETARCH}${TARGETVARIANT},target=/downloads,sharing=locked \
    set -x && \
    case "${TARGETARCH}${TARGETVARIANT}" in \
      amd64) \
        S6_OVERLAY_ARCH=x86_64; \
        S6_OVERLAY_ARCH_SHA256=e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408; \
        ;; \
      arm64) \
        S6_OVERLAY_ARCH=aarch64; \
        S6_OVERLAY_ARCH_SHA256=b17f17a82e7a515c682a91edaf2ffdabb73f891981b6c1fd712115693a2f8b4c; \
        ;; \
      armv7) \
        S6_OVERLAY_ARCH=arm; \
        S6_OVERLAY_ARCH_SHA256=9fc621c84370ab8fdf72dee51ba16c85a882d01bd2f3b388f8e1ee6bc03e00d3; \
        ;; \
      *) \
        echo "Unsupported target architecture: ${TARGETARCH}/${TARGETVARIANT}" >&2; \
        exit 1; \
        ;; \
    esac && \
    S6_OVERLAY_NOARCH_SHA256=5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 && \
    S6_OVERLAY_BASE_URL="https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}" && \
    S6_OVERLAY_DOWNLOAD_DIR="/downloads/${S6_OVERLAY_VERSION}" && \
    mkdir -p "${S6_OVERLAY_DOWNLOAD_DIR}" /out && \
    download_and_verify() { \
      local url="$1" output="$2" checksum="$3"; \
      if [[ -f "${output}" ]] && printf '%s  %s\n' "${checksum}" "${output}" | sha256sum --check --status; then \
        return; \
      fi; \
      rm -f "${output}"; \
      curl --fail --location --retry 3 --retry-all-errors --silent --show-error --output "${output}" "${url}"; \
      printf '%s  %s\n' "${checksum}" "${output}" | sha256sum --check; \
    } && \
    download_and_verify \
      "${S6_OVERLAY_BASE_URL}/s6-overlay-noarch.tar.xz" \
      "${S6_OVERLAY_DOWNLOAD_DIR}/s6-overlay-noarch.tar.xz" \
      "${S6_OVERLAY_NOARCH_SHA256}" && \
    download_and_verify \
      "${S6_OVERLAY_BASE_URL}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
      "${S6_OVERLAY_DOWNLOAD_DIR}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" \
      "${S6_OVERLAY_ARCH_SHA256}" && \
    tar -C /out -Jxpf "${S6_OVERLAY_DOWNLOAD_DIR}/s6-overlay-noarch.tar.xz" && \
    tar -C /out -Jxpf "${S6_OVERLAY_DOWNLOAD_DIR}/s6-overlay-${S6_OVERLAY_ARCH}.tar.xz" && \
    test -x /out/init && \
    test -x /out/command/s6-echo


FROM debian_base
ARG TARGETARCH
ARG TARGETVARIANT
ENV PATH="/opt/mlat-client/bin:${PATH}" \
    BEASTPORT=30005 \
    PW_METRICSHOST=0.0.0.0 \
    PW_METRICSPORT=2112 \
    MLATSERVERHOST=127.0.0.1 \
    MLATSERVERPORT=12346 \
    PW_BEAST_ENDPOINT=feed.push.plane.watch:12345 \
    PW_MLAT_ENDPOINT=feed.push.plane.watch:12346 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ENABLE_MLAT=true \
    MLAT_INPUT_TYPE=beast
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN --mount=type=cache,id=apt-cache-${TARGETARCH}${TARGETVARIANT},target=/var/cache/apt,sharing=locked --mount=type=cache,id=apt-lists-${TARGETARCH}${TARGETVARIANT},target=/var/lib/apt,sharing=locked \
    set -x && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gawk \
      iproute2 \
      libncurses6 \
      libprotobuf-c1 \
      libtinfo6 \
      openssl \
      python3
COPY --from=s6_overlay_builder /out/ /
COPY --from=mlat_client_builder /opt/mlat-client /opt/mlat-client
COPY --chmod=755 --from=viewadsb_builder /usr/local/bin/viewadsb /usr/local/bin/viewadsb
COPY --chmod=755 --from=pw_feeder_builder /usr/local/sbin/pw-feeder /usr/local/sbin/pw-feeder
COPY --chmod=644 --from=pw_feeder_builder /PW_FEEDER_VERSION /PW_FEEDER_VERSION
COPY rootfs/ /
RUN \
    set -x && \
    test -x /etc/s6-overlay/s6-rc.d/mlat-client/run && \
    test -x /etc/s6-overlay/s6-rc.d/pw-feeder/run && \
    test -x /scripts/healthcheck.sh && \
    test -x /scripts/initialise.sh && \
    test -x /scripts/mlat-client.sh && \
    test -x /scripts/pw-feeder.sh && \
    find /var/log -type f -exec truncate --size=0 {} \; && \
    # Simple tests: check CA certs: \
    openssl s_client -verify_return_error -connect "${PW_BEAST_ENDPOINT}" && \
    openssl s_client -verify_return_error -connect "${PW_MLAT_ENDPOINT}" && \
    # Simple tests: ensure binaries work: \
    /command/s6-echo "s6-overlay is working" && \
    viewadsb --help && \
    mlat-client --help && \
    pw-feeder --version && \
    # Document versions: \
    cat /PW_FEEDER_VERSION
ARG IMAGE_REVISION=unknown
ARG IMAGE_VERSION=dev
ENV IMAGE_REVISION="${IMAGE_REVISION}"
LABEL org.opencontainers.image.title="Plane Watch feeder" \
      org.opencontainers.image.description="Feeds ADS-B and MLAT data to Plane Watch" \
      org.opencontainers.image.source="https://github.com/plane-watch/docker-plane-watch" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.version="${IMAGE_VERSION}"
ENTRYPOINT ["/init"]
HEALTHCHECK --interval=60s --timeout=15s --start-period=60s --start-interval=5s --retries=3 CMD ["bash", "/scripts/healthcheck.sh"]

# Expose metrics port
EXPOSE 2112

# Expose MLAT results
EXPOSE 30105
