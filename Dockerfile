FROM golang:1.20 AS pw_feeder_builder
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN set -x && \
    git clone https://github.com/plane-watch/pw-feeder.git /src/pw-feeder && \
    pushd /src/pw-feeder/pw-feeder && \
    go build ./...

FROM debian:bullseye-20230522-slim

ENV BEASTPORT=30005 \
    MLATRESULTSHOST=127.0.0.1 \
    MLATRESULTSPORT=12346 \
    PW_BEAST_ENDPOINT=feed.push.plane.watch:12345 \
    PW_MLAT_ENDPOINT=feed.push.plane.watch:12346 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ENABLE_MLAT=true \
    MLAT_INPUT_TYPE=beast
    # ACARS_PORT=15550 \
    # VDLM2_PORT=15555 \
    # PW_FEED_DESTINATION_ACARS_PORT=5550 \
    # PW_FEED_DESTINATION_VDLM2_PORT=5555 \

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=pw_feeder_builder /src/pw-feeder/pw-feeder/pw-feeder /usr/local/sbin/pw-feeder

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Build dependencies
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(git) && \
    # For mlat-client
    KEPT_PACKAGES+=(python-is-python3) && \
    TEMP_PACKAGES+=(python3-distutils) && \
    TEMP_PACKAGES+=(libpython3-dev) && \
    # Install stunnel
    KEPT_PACKAGES+=(ca-certificates) && \
    # Dependencies for s6-overlay
    TEMP_PACKAGES+=(curl) && \
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(gnupg2) && \
    # Better logging
    KEPT_PACKAGES+=(gawk) && \
    # Dependencies for healthcheck
    KEPT_PACKAGES+=(net-tools) && \
    # Install packages
    apt-get update && \
    apt-get install --no-install-recommends -y \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    # mlat-client
    git clone --depth 1 --single-branch https://github.com/mutability/mlat-client.git "/src/mlat-client" && \
    pushd /src/mlat-client && \
    ./setup.py build && \
    ./setup.py install && \
    cp -v ./mlat-client /usr/local/bin/mlat-client && \
    popd && \
    # Deploy s6-overlay.
    curl -s --location -o /tmp/deploy-s6-overlay.sh https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh && \
    bash /tmp/deploy-s6-overlay.sh && \
    # Install 
    # Deploy healthchecks framework
    git clone \
      --depth=1 \
      https://github.com/mikenye/docker-healthchecks-framework.git \
      /opt/healthchecks-framework \
      && \
    rm -rf \
      /opt/healthchecks-framework/.git* \
      /opt/healthchecks-framework/*.md \
      /opt/healthchecks-framework/tests \
      && \
    # Get version before clean-up
    IMAGE_VERSION=$(git ls-remote https://github.com/plane-watch/docker-plane-watch.git | grep HEAD | tr '\t' ' ' | cut -d ' ' -f 1) && \
    # Clean-up.
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
    find /var/log -type f -exec truncate --size=0 {} \; && \
    # Simple tests
    mlat-client --help && \
    pw-feeder --version && \
    # Document versions.
    set +o pipefail && \
    echo ${IMAGE_VERSION::7} > /IMAGE_VERSION && \
    cat /IMAGE_VERSION

COPY rootfs/ /

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=300s --timeout=5s --start-period=60s --retries=3 CMD /scripts/healthcheck.sh
