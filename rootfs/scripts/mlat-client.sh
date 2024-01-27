#!/command/with-contenv bash

# If mlat enabled...
if [[ "${ENABLE_MLAT,,}" == "true" ]]; then

    # Make sure we have the needed env vars
    if [[ -n "$LAT" ]] && [[ -n "$LONG" ]] && [[ -n "$ALT" ]]; then
    
        # shellcheck disable=SC2015
        [[ -z "${MLAT_DATASOURCE}" ]] && MLAT_DATASOURCE="${BEASTHOST}:${BEASTPORT}" || true

        # give other stuff some time to come up
        sleep 5

        # Launch mlat-client
        # shellcheck disable=SC2016
        /usr/local/bin/mlat-client \
            --input-type "$MLAT_INPUT_TYPE" \
            --input-connect "${MLAT_DATASOURCE}" \
            --lat "$LAT" \
            --lon "$LONG" \
            --alt "${ALT}" \
            --results "beast,listen,30105" \
            --server "${MLATSERVERHOST}:${MLATSERVERPORT}" \
            --user "${API_KEY}" \
        2>&1 \
        | stdbuf -o0 sed --unbuffered '/^$/d' \
        | stdbuf -o0 sed --unbuffered '/^        .*/d' \
        | stdbuf -o0 awk '{print "[mlat-client] " $0}'

    else

        sleep infinity

    fi

# If not enabled, sleep forever
else
    sleep infinity
fi
