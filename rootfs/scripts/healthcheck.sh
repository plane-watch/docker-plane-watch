#!/usr/bin/with-contenv bash
#shellcheck shell=bash

# Import healthchecks-framework
# shellcheck disable=SC1091
source /opt/healthchecks-framework/healthchecks.sh

# Prepare EXITCODE variable
EXITCODE=0

echo "Ensure connection to beast provider $BEASTHOST:$BEASTPORT"
if ! check_tcp4_connection_established ANY ANY "$(get_ipv4 "$BEASTHOST")" "$BEASTPORT"; then
    EXITCODE=1
fi

echo "Ensure connection to plane.watch $PW_FEED_DESTINATION_HOSTNAME:$PW_FEED_DESTINATION_PORT"
if ! check_tcp4_connection_established ANY ANY "$(get_ipv4 "$PW_FEED_DESTINATION_HOSTNAME")" "$PW_FEED_DESTINATION_PORT"; then
    EXITCODE=1
fi

echo "Check service death tally"
if ! check_s6_service_abnormal_death_tally ALL; then
    EXITCODE=1
fi

exit "$EXITCODE"