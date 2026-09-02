if [[ "${1:-}" == "new" ]]; then
    shift
    exec @moshServer@ new -p "${MOSH_PORT_RANGE:-@moshPortRange@}" "$@"
fi
exec @moshServer@ "$@"
