FROM golang:1.22.3-bullseye AS pw_feeder_builder

ARG PW_FEEDER_BRANCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -x && \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    git clone https://github.com/plane-watch/pw-feeder.git /src/pw-feeder && \
    pushd /src/pw-feeder && \
    LATEST_TAG=$(git describe --tags --abbrev=0) && \
    git checkout "${PW_FEEDER_BRANCH:-$LATEST_TAG}" && \
    pushd /src/pw-feeder/pw-feeder && \
    go mod tidy && \
    go generate -v ./... && \
    go build -v ./cmd/pw-feeder/ && \
    echo "${PW_FEEDER_BRANCH:-$LATEST_TAG}" > /PW_FEEDER_VERSION


FROM debian:bullseye-20240408

ENV BEASTPORT=30005 \
    MLATSERVERHOST=127.0.0.1 \
    MLATSERVERPORT=12346 \
    PW_BEAST_ENDPOINT=feed.push.plane.watch:12345 \
    PW_MLAT_ENDPOINT=feed.push.plane.watch:12346 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ENABLE_MLAT=true \
    MLAT_INPUT_TYPE=beast

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=pw_feeder_builder /src/pw-feeder/pw-feeder/pw-feeder /usr/local/sbin/pw-feeder
COPY --from=pw_feeder_builder /PW_FEEDER_VERSION /PW_FEEDER_VERSION

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Build dependencies
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(git) && \
    # For mlat-client
    KEPT_PACKAGES+=(python-is-python3) && \
    TEMP_PACKAGES+=(python3-distutils) && \
    TEMP_PACKAGES+=(python3-setuptools) && \
    TEMP_PACKAGES+=(libpython3-dev) && \
    # Install stunnel
    KEPT_PACKAGES+=(ca-certificates) && \
    # Dependencies for s6-overlay
    TEMP_PACKAGES+=(curl) && \
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(gnupg2) && \
    TEMP_PACKAGES+=(xz-utils) && \
    # Dependencies for healthcheck
    KEPT_PACKAGES+=(iproute2) && \
    # Better logging
    KEPT_PACKAGES+=(gawk) && \
    # Install packages
    apt-get update && \
    apt-get install --no-install-recommends -y \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    # install CA certificates
    curl -o /tmp/insrall_ca_certs.sh -s https://raw.githubusercontent.com/plane-watch/pw-feeder/main/install_ca_certs.sh && \
    bash /tmp/insrall_ca_certs.sh && \
    # mlat-client
    git clone --depth 1 --single-branch https://github.com/mutability/mlat-client.git "/src/mlat-client" && \
    pushd /src/mlat-client && \
    ./setup.py build && \
    ./setup.py install && \
    popd && \
    # Deploy s6-overlay
    curl -o /tmp/deploy-s6-overlay.sh -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay-v3.sh && \
    bash /tmp/deploy-s6-overlay.sh && \
    # Clean-up
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
    find /var/log -type f -exec truncate --size=0 {} \; && \
    # Simple tests
    mlat-client --help && \
    pw-feeder --version && \
    # Document versions
    set +o pipefail && \
    cat /PW_FEEDER_VERSION

COPY rootfs/ /

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=300s --timeout=15s --start-period=60s --retries=3 CMD bash /scripts/healthcheck.sh
