#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

if [[ "${1:-}" == "new" ]]; then
    shift
    exec /usr/bin/mosh-server new -p "${MOSH_PORT_RANGE:-60001:60005}" "$@"
fi
exec /usr/bin/mosh-server "$@"
