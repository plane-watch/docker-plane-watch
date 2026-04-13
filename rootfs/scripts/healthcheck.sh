#!/command/with-contenv bash
#shellcheck shell=bash

# Prepare EXITCODE variable
EXITCODE=0

BESTHOST_RESOLVED=$(getent hosts "$BEASTHOST" | tr -s " " | cut -d " " -f 1)
PW_BEAST_ENDPOINT_HOST=$(echo "$PW_BEAST_ENDPOINT" | cut -d ":" -f 1)
PW_BEAST_ENDPOINT_PORT=$(echo "$PW_BEAST_ENDPOINT" | cut -d ":" -f 2)
PW_BEAST_ENDPOINT_HOST_RESOLVED=$(getent hosts "$PW_BEAST_ENDPOINT_HOST" | tr -s " " | cut -d " " -f 1)
PW_MLAT_ENDPOINT_HOST=$(echo "$PW_MLAT_ENDPOINT" | cut -d ":" -f 1)
PW_MLAT_ENDPOINT_PORT=$(echo "$PW_MLAT_ENDPOINT" | cut -d ":" -f 2)
PW_MLAT_ENDPOINT_HOST_RESOLVED=$(getent hosts "$PW_MLAT_ENDPOINT_HOST" | tr -s " " | cut -d " " -f 1)

# check pw-feeder to beasthost connection
echo -n "pw-feeder connected to \$BEASTHOST:\$BEASTPORT (proc pw-feeder && dst $BESTHOST_RESOLVED && dport $BEASTPORT): "
if ! ss --tcp --processes state established dst "$BESTHOST_RESOLVED" \&\& dport "$BEASTPORT" 2>/dev/null| grep -q pw-feeder; then
    EXITCODE=1
    echo "FAIL"
else
    echo "OK"
fi

# check pw-feeder to plane.watch BEAST connection
echo -n "pw-feeder connected to \$PW_BEAST_ENDPOINT (proc pw-feeder && dst $PW_BEAST_ENDPOINT_HOST_RESOLVED && dport $PW_BEAST_ENDPOINT_PORT): "
if ! ss --tcp --processes state established dst "$PW_BEAST_ENDPOINT_HOST_RESOLVED" \&\& dport "$PW_BEAST_ENDPOINT_PORT" 2>/dev/null| grep -q pw-feeder; then
    EXITCODE=1
    echo "FAIL"
else
    echo "OK"
fi

# if MLAT enabled...
if [[ "${ENABLE_MLAT,,}" == "true" ]]; then

    # check mlat-client to beasthost connection
    echo -n "mlat-client connected to \$BEASTHOST:\$BEASTPORT (proc mlat-cient && dst $BESTHOST_RESOLVED && dport $BEASTPORT): "
    if ! ss --tcp --processes state established dst "$BESTHOST_RESOLVED" \&\& dport "$BEASTPORT" 2>/dev/null | grep -q mlat-client; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check mlat-client to pw-feeder connection
    echo -n "mlat-client connected to pw-client (proc mlat-client && dst $MLATSERVERHOST && dport $MLATSERVERPORT): "
    if ! ss --tcp --processes state established dst "$MLATSERVERHOST" \&\& dport "$MLATSERVERPORT" 2>/dev/null| grep -q mlat-client; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check mlat-client to pw-feeder connection
    echo -n "pw-feeder connected to mlat-client (proc pw-feeder && src $MLATSERVERHOST && sport $MLATSERVERPORT): "
    if ! ss --tcp --processes state established src "$MLATSERVERHOST" \&\& sport "$MLATSERVERPORT" 2>/dev/null| grep -q pw-feeder; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check pw-feeder to plane.watch MLAT connection
    echo -n "pw-feeder connected to \$PW_MLAT_ENDPOINT (proc pw-feeder && dst $PW_MLAT_ENDPOINT_HOST_RESOLVED && dport $PW_MLAT_ENDPOINT_PORT): "
    if ! ss --tcp --processes state established dst "$PW_MLAT_ENDPOINT_HOST_RESOLVED" \&\& dport "$PW_MLAT_ENDPOINT_PORT" 2>/dev/null| grep -q pw-feeder; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

fi

exit "$EXITCODE"
