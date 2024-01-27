#!/command/with-contenv bash
#shellcheck shell=bash

NOCOLOR='\033[0m'
LIGHTRED='\033[1;31m'
YELLOW='\033[1;33m'

# If troubleshooting:
if [[ -n "$DEBUG_LOGGING" ]]; then
    set -x
fi

echo "[init] Setting timezone..."

# Set up timezone
if [ -z "${TZ}" ]; then
  echo -e "${YELLOW}WARNING: TZ environment variable not set${NOCOLOR}"
else
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

echo "[init] Checking environment variables..."

# Check to make sure the correct command line arguments have been set
EXITCODE=0
if [ -z "${BEASTHOST}" ]; then
  echo -e "${LIGHTRED}ERROR: BEASTHOST environment variable not set${NOCOLOR}"
  EXITCODE=1
fi
if [ -z "${API_KEY}" ]; then
  echo -e "${LIGHTRED}ERROR: API_KEY environment variable was not set${NOCOLOR}"
  EXITCODE=1
fi

# If mlat enabled...
if [[ "${ENABLE_MLAT,,}" == "true" ]]; then
  # ... make sure that the correct env vars are set
  if [ -z "$LAT" ]; then
    echo -e "${YELLOW}WARNING: No LAT environment variable, cannot use MLAT${NOCOLOR}"
  fi
  if [ -z "$LONG" ]; then
    echo -e "${YELLOW}WARNING: No LONG environment variable, cannot use MLAT${NOCOLOR}"
  fi
  if [ -z "$ALT" ]; then
    echo -e "${YELLOW}WARNING: No ALT environment variable, cannot use MLAT${NOCOLOR}"
  fi
fi

# If any errors above are fatal, don't proceed starting the container
if [ "$EXITCODE" -ne 0 ]; then
  exit 1
fi

echo "[init] Completed"

exit "$EXITCODE"
