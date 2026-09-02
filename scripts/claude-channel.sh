# Keeps a Claude Code session alive with the Telegram channel plugin attached.
# Runs inside the `claude` tmux session the entrypoint starts. Attach with
# `tmux attach -t claude` to watch it, answer a permission prompt, or run the
# one-off /login and /telegram:access commands.

config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
workdir="${CLAUDE_WORKDIR:-${HOME}}"
plugin="telegram@claude-plugins-official"
mkdir -p "${config_dir}"
# The repo clone may be missing (no GIT_CLONE_URL); fall back to the home volume.
cd "${workdir}" 2>/dev/null || cd "${HOME}" || exit 1
workdir="$(pwd)"

# Best effort: skip the first-run onboarding and the folder trust dialog, both
# blocking TUI prompts nobody is around to answer. If a future version renames
# these keys, attach to tmux once and click through.
if [[ ! -f "${config_dir}/.claude.json" ]]; then
    jq -n --arg dir "${workdir}" \
        '{hasCompletedOnboarding: true, projects: {($dir): {hasTrustDialogAccepted: true}}}' \
        >"${config_dir}/.claude.json"
fi

# The plugin is installed into the persistent config dir on first boot, so the
# image itself stays plugin-free and CLAUDE_CONFIG_DIR carries it across restarts.
if ! claude plugin list 2>/dev/null | grep -q "${plugin}"; then
    claude plugin marketplace add anthropics/claude-plugins-official || true
    claude plugin install "${plugin}" || true
fi

# Pre-seed the Telegram allowlist from TELEGRAM_ALLOW_FROM (comma-separated
# numeric user ids) so no pairing round-trip is needed; later edits through
# /telegram:access are preserved because the file is only written when absent.
state_dir="${TELEGRAM_STATE_DIR:-${config_dir}/channels/telegram}"
if [[ -n "${TELEGRAM_ALLOW_FROM:-}" && ! -f "${state_dir}/access.json" ]]; then
    mkdir -p "${state_dir}"
    jq -n --arg ids "${TELEGRAM_ALLOW_FROM}" \
        '{dmPolicy: "allowlist", allowFrom: ($ids | split(",") | map(gsub("\\s"; "")) | map(select(length > 0)))}' \
        >"${state_dir}/access.json"
fi

# Claude Code stores transcripts per working directory under
# projects/<cwd with / replaced by ->; if one exists, resume it so the
# conversation survives pod restarts.
project_dir="${config_dir}/projects/${workdir//\//-}"
while true; do
    args=(--channels "plugin:${plugin}" --permission-mode "${CLAUDE_PERMISSION_MODE:-auto}" --name bastion)
    if compgen -G "${project_dir}/*.jsonl" >/dev/null; then
        args+=(--continue)
    fi
    claude "${args[@]}"
    echo "[claude-channel] claude exited with status $?; restarting in 5s"
    sleep 5
done
