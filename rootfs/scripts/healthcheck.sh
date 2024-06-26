#!/command/with-contenv bash
#shellcheck shell=bash

# Prepare EXITCODE variable
EXITCODE=0

# check pw-feeder to beasthost connection
echo -n "pw-feeder connected to $BEASTHOST:$BEASTPORT: "
if ! ss --tcp --processes state established dst "$BEASTHOST" \&\& dport "$BEASTPORT" 2>/dev/null| grep -q pw-feeder; then
    EXITCODE=1
    echo "FAIL"
else
    echo "OK"
fi

# check pw-feeder to plane.watch BEAST connection
echo -n "pw-feeder connected to $PW_BEAST_ENDPOINT: "
if ! ss --tcp --processes state established dst "$PW_BEAST_ENDPOINT" 2>/dev/null| grep -q pw-feeder; then
    EXITCODE=1
    echo "FAIL"
else
    echo "OK"
fi

# if MLAT enabled...
if [[ "${ENABLE_MLAT,,}" == "true" ]]; then

    # check mlat-client to beasthost connection
    echo -n "mlat-client connected to $BEASTHOST:$BEASTPORT: "
    if ! ss --tcp --processes state established dst "$BEASTHOST" \&\& dport "$BEASTPORT" 2>/dev/null | grep -q mlat-client; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check mlat-client to pw-feeder connection
    echo -n "mlat-client connected to pw-client ($MLATSERVERHOST:$MLATSERVERPORT): "
    if ! ss --tcp --processes state established dst "$MLATSERVERHOST" \&\& dport "$MLATSERVERPORT" 2>/dev/null| grep -q mlat-client; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check mlat-client to pw-feeder connection
    echo -n "pw-feeder connected to mlat-client: "
    if ! ss --tcp --processes state established src "$MLATSERVERHOST" \&\& sport "$MLATSERVERPORT" 2>/dev/null| grep -q pw-feeder; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

    # check pw-feeder to plane.watch MLAT connection
    echo -n "pw-feeder connected to $PW_MLAT_ENDPOINT: "
    if ! ss --tcp --processes state established dst "$PW_MLAT_ENDPOINT" 2>/dev/null| grep -q pw-feeder; then
        EXITCODE=1
        echo "FAIL"
    else
        echo "OK"
    fi

fi

exit "$EXITCODE"
