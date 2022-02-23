FROM python:3-slim

ENV BEASTPORT=30005 \
    PW_FEED_DESTINATION_HOSTNAME=feed.push.plane.watch \
    PW_FEED_DESTINATION_BEAST_PORT=12345 \
    PW_FEED_DESTINATION_ACARS_PORT=5550 \
    PW_FEED_DESTINATION_VDLM2_PORT=5555 \
    REDUCE_INTERVAL="0.5" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ACARS_PORT=15550 \
    VDLM2_PORT=15555

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY rootfs/ /

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Build dependencies
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(git) && \
    # Install stunnel
    KEPT_PACKAGES+=(ca-certificates) && \
    KEPT_PACKAGES+=(stunnel) && \
    # Dependencies for readsb
    TEMP_PACKAGES+=(libncurses-dev) && \
    KEPT_PACKAGES+=(libncurses6) && \
    TEMP_PACKAGES+=(libprotobuf-c-dev) && \
    KEPT_PACKAGES+=(libprotobuf-c1) && \
    TEMP_PACKAGES+=(librrd-dev) && \
    KEPT_PACKAGES+=(librrd8) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(protobuf-c-compiler) && \
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
    # Build readsb
    git clone --depth 1 --single-branch --branch dev https://github.com/Mictronics/readsb-protobuf.git "/src/readsb-protobuf" && \
    pushd "/src/readsb-protobuf" && \
    make BLADERF=no RTLSDR=no PLUTOSDR=no && \
    popd && \
    # Install readsb - Copy readsb executables to /usr/local/bin/.
    find "/src/readsb-protobuf" -maxdepth 1 -executable -type f -exec cp -v {} /usr/local/bin/ \; && \
    # Deploy acars_router
    git clone --depth 1 --single-branch --branch main https://github.com/sdr-enthusiasts/acars_router.git "/src/acars_router" && \
    python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir --requirement /src/acars_router/acars_router/requirements.txt && \
    cp -Rv /src/acars_router/acars_router /opt/ && \
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
    # Clean-up.
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
    find /var/log -type f -exec truncate --size=0 {} \; && \
    # Document versions.
    echo "readsb $(readsb --version | cut -d ' ' -f 2)" >> /VERSIONS && \
    set +o pipefail && \
    echo "stunnel $(stunnel 2>&1 | grep '\[\.\] stunnel' | cut -d ' ' -f 3)" >> /VERSIONS

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=300s --timeout=5s --start-period=60s --retries=3 CMD /scripts/healthcheck.sh
