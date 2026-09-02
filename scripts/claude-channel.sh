config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
workdir="${CLAUDE_WORKDIR:-${HOME}}"
plugin="telegram@claude-plugins-official"
mkdir -p "${config_dir}"
cd "${workdir}" 2>/dev/null || cd "${HOME}" || exit 1
workdir="$(pwd)"

if [[ ! -f "${config_dir}/.claude.json" ]]; then
    jq -n --arg dir "${workdir}" \
        '{hasCompletedOnboarding: true, projects: {($dir): {hasTrustDialogAccepted: true}}}' \
        >"${config_dir}/.claude.json"
fi

if [[ ! -f "${config_dir}/CLAUDE.md" ]]; then
    cat >"${config_dir}/CLAUDE.md" <<'EOF'
# Bastion

This session runs unattended inside the bastion pod of the home Kubernetes cluster and is driven from Telegram.

- Every message that arrives as a channel event from telegram comes from Nikola's phone. Nobody reads this terminal. Answer through the telegram reply tool with the chat_id from the event; text written only to the terminal is lost.
- Keep Telegram replies short and plain text. No Markdown tables. When a long task finishes, send a new reply so the phone pings.
- Use react with an emoji to acknowledge a task you are starting, and edit_message for interim progress.
- The home repo is cloned at /config/home and follows its own CLAUDE.md: kubectl is read-only, changes go through Git and Flux. kubectl, flux, talosctl and sofka are already authenticated in-cluster.
EOF
fi

if ! claude plugin list 2>/dev/null | grep -q "${plugin}"; then
    claude plugin marketplace add anthropics/claude-plugins-official || true
    claude plugin install "${plugin}" || true
fi

state_dir="${TELEGRAM_STATE_DIR:-${config_dir}/channels/telegram}"
if [[ -n "${TELEGRAM_ALLOW_FROM:-}" && ! -f "${state_dir}/access.json" ]]; then
    mkdir -p "${state_dir}"
    jq -n --arg ids "${TELEGRAM_ALLOW_FROM}" \
        '{dmPolicy: "allowlist", allowFrom: ($ids | split(",") | map(gsub("\\s"; "")) | map(select(length > 0)))}' \
        >"${state_dir}/access.json"
fi

project_dir="${config_dir}/projects/${workdir//\//-}"
while true; do
    args=(--channels "plugin:${plugin}" --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" --name bastion)
    transcripts=("${project_dir}"/*.jsonl)
    if [[ -e "${transcripts[0]}" ]]; then
        args+=(--continue)
    fi
    claude "${args[@]}"
    echo "[claude-channel] claude exited with status $?; restarting in 5s"
    sleep 5
done
