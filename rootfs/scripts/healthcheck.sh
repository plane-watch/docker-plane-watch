#!/command/with-contenv bash
# shellcheck shell=bash

set -uo pipefail

EXITCODE=0

BEASTHOST="${BEASTHOST//[$'\r']/}"
BEASTPORT="${BEASTPORT//[$'\r']/}"
MLATSERVERHOST="${MLATSERVERHOST//[$'\r']/}"
MLATSERVERPORT="${MLATSERVERPORT//[$'\r']/}"
PW_BEAST_ENDPOINT="${PW_BEAST_ENDPOINT//[$'\r']/}"
PW_MLAT_ENDPOINT="${PW_MLAT_ENDPOINT//[$'\r']/}"

resolve_ips() {
    local host=$1
    getent ahosts "$host" 2>/dev/null | awk '{print $1}' | sort -u
}

extract_host() {
    local endpoint=$1

    if [[ "$endpoint" =~ ^\[(.+)\]:[0-9]+$ ]]; then
        echo "${BASH_REMATCH[1]}"                      # [IPv6]:port -> IPv6
    elif [[ "$endpoint" =~ ^(.*):[0-9]+$ ]]; then
        echo "${BASH_REMATCH[1]}"                      # Handles host:port and ::ffff:IPv4:port
    else
        echo "$endpoint"                               # fallback (no port or bare IPv6)
    fi
}

extract_port() {
    local endpoint=$1
    if [[ "$endpoint" =~ :([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

extract_ip() {
    local peer=$1
    local ip
    ip=$(extract_host "$peer")
    echo "${ip#::ffff:}"
}

check_dualstack_connection() {
    local process=$1
    local host=$2
    local description=$3

    echo -n "$description: "

    local valid_ips
    valid_ips=$(resolve_ips "$host")

    if [[ -z "$valid_ips" ]]; then
        echo "FAIL (could not resolve $host)"
        EXITCODE=1
        return 1
    fi

    local peer_addresses
    peer_addresses=$(
        ss -tnp state established 2>/dev/null \
        | grep "\"$process\"" \
        | awk '{print $(NF-1)}'
    )

    while IFS= read -r peer; do
        [[ -z "$peer" ]] && continue
        local peer_ip
        peer_ip=$(extract_ip "$peer")

        if grep -Fqx "$peer_ip" <<< "$valid_ips"; then
            echo "OK"
            return 0
        fi
    done <<< "$peer_addresses"

    echo "FAIL"
    EXITCODE=1
    return 1
}

check_connection_to_port() {
    local process=$1
    local host=$2
    local port=$3
    local description=$4

    echo -n "$description: "

    if [[ -z "$port" ]]; then
        echo "FAIL (missing or invalid port definition)"
        EXITCODE=1
        return 1
    fi

    local valid_ips
    valid_ips=$(resolve_ips "$host")

    if [[ -z "$valid_ips" ]]; then
        echo "FAIL (could not resolve $host)"
        EXITCODE=1
        return 1
    fi

    local peer_addresses
    peer_addresses=$(
        ss -tnp state established 2>/dev/null \
        | grep "\"$process\"" \
        | awk '{print $(NF-1)}'
    )

    while IFS= read -r peer; do
        [[ -z "$peer" ]] && continue

        local peer_ip peer_port
        peer_ip=$(extract_ip "$peer")
        peer_port=$(extract_port "$peer")

        if grep -Fqx "$peer_ip" <<< "$valid_ips" && (( peer_port == port )); then
            echo "OK"
            return 0
        fi
    done <<< "$peer_addresses"

    echo "FAIL"
    EXITCODE=1
    return 1
}

check_listening_on_sport() {
    local process=$1
    local sport=$2
    local description=$3

    echo -n "$description: "

    if [[ -z "$sport" ]]; then
        echo "FAIL (missing or invalid local port definition)"
        EXITCODE=1
        return 1
    fi

    if ss -tnp state established sport = ":${sport}" 2>/dev/null | grep -q "\"$process\""; then
        echo "OK"
        return 0
    fi

    echo "FAIL"
    EXITCODE=1
    return 1
}

check_dualstack_connection \
    "pw-feeder" \
    "$BEASTHOST" \
    "pw-feeder connected to $BEASTHOST:$BEASTPORT"

PW_BEAST_HOST=$(extract_host "$PW_BEAST_ENDPOINT")
PW_BEAST_PORT=$(extract_port "$PW_BEAST_ENDPOINT")

check_connection_to_port \
    "pw-feeder" \
    "$PW_BEAST_HOST" \
    "$PW_BEAST_PORT" \
    "pw-feeder connected to $PW_BEAST_ENDPOINT"

if [[ "${ENABLE_MLAT,,}" == "true" ]]; then

    check_dualstack_connection \
        "mlat-client" \
        "$BEASTHOST" \
        "mlat-client connected to $BEASTHOST:$BEASTPORT"

    check_connection_to_port \
        "mlat-client" \
        "$MLATSERVERHOST" \
        "$MLATSERVERPORT" \
        "mlat-client connected to pw-client ($MLATSERVERHOST:$MLATSERVERPORT)"

    check_listening_on_sport \
        "pw-feeder" \
        "$MLATSERVERPORT" \
        "pw-feeder connected to mlat-client"

    PW_MLAT_HOST=$(extract_host "$PW_MLAT_ENDPOINT")
    PW_MLAT_PORT=$(extract_port "$PW_MLAT_ENDPOINT")

    check_connection_to_port \
        "pw-feeder" \
        "$PW_MLAT_HOST" \
        "$PW_MLAT_PORT" \
        "pw-feeder connected to $PW_MLAT_ENDPOINT"
fi

exit "$EXITCODE"
