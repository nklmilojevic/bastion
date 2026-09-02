# mosh clients start the server over SSH as plain `mosh-server new ...`, which
# would pick any UDP port in 60000-61000. Force the small range the
# LoadBalancer Service exposes; a client-supplied -p still wins (last flag).
if [[ "${1:-}" == "new" ]]; then
    shift
    exec @moshServer@ new -p "${MOSH_PORT_RANGE:-@moshPortRange@}" "$@"
fi
exec @moshServer@ "$@"
