#!/usr/bin/env bash

set -o pipefail

SHELL="/bin/bash"
PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:$PATH"

# Environment variables
POOLS="${POOLS:-}"
mapfile -t NODES < <(seq -f "p%g" 1 "$POOLS")
set -f
NODES+=( $EXTRA_NODES )
set +f

PORT="${PORT:-3001}"
NETWORKMAGIC="${NETWORKMAGIC:-42}"
LIMIT="${LIMIT:-100}"
NCONNS="${NCONNS:-100}"

# Validate CHAINPOINT_FILEPATH
if [[ -z "${CHAINPOINT_FILEPATH}" ]]; then
	echo "Error: CHAINPOINT_FILEPATH environment variable is not set" >&2
	exit 1
fi

if [[ ! -f "${CHAINPOINT_FILEPATH}" ]]; then
	echo "Skipping: CHAINPOINT_FILEPATH does not point to a file: ${CHAINPOINT_FILEPATH}" >&2
	exit 0
fi

# echo "Checking flaky chain sync among the following nodes: $(IFS=', '; echo "${NODES[*]}")"

adversary "$NETWORKMAGIC" "$PORT" "$LIMIT" "$CHAINPOINT_FILEPATH" "$NCONNS" "${NODES[@]}"
