agent_dir="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}"
workdir="${BASTION_WORKDIR:-${HOME}}"
telegram_package="npm:@llblab/pi-telegram"
default_packages="npm:@odinlayer/pi-provider-litellm,npm:pi-meridian-extension"
default_packages+=",npm:pi-subagents,npm:pi-web-access,npm:pi-mcp-adapter,npm:pi-lens"
default_packages+=",npm:pi-background-tasks,npm:pi-hermes-memory,npm:pi-simplify"
default_packages+=",npm:@juicesharp/rpiv-todo,npm:@juicesharp/rpiv-ask-user-question"
default_packages+=",npm:@narumitw/pi-plan-mode,npm:@narumitw/pi-goal"
default_packages+=",npm:pi-powerline-footer,npm:pi-markdown-preview"
default_packages+=",git:github.com/earendil-works/pi-review"
packages="${telegram_package},${BASTION_PI_PACKAGES:-${default_packages}}"
default_model="litellm/chatgpt/gpt-5.6-sol"
mkdir -p "${agent_dir}"
cd "${workdir}" 2>/dev/null || cd "${HOME}" || exit 1
workdir="$(pwd)"

settings="${agent_dir}/settings.json"
if [[ ! -f "${settings}" ]]; then
    jq -n '{quietStartup: true, packages: []}' >"${settings}"
fi
if [[ "$(jq -r '.defaultModel // empty' "${settings}")" == "" ]]; then
    jq --arg p "${default_model%%/*}" --arg m "${default_model#*/}" \
        '.defaultProvider = $p | .defaultModel = $m' \
        "${settings}" >"${settings}.tmp" && mv "${settings}.tmp" "${settings}"
fi

if [[ ! -f "${agent_dir}/AGENTS.md" ]]; then
    cat >"${agent_dir}/AGENTS.md" <<'EOF'
# Bastion

This session runs unattended inside the bastion pod of the home Kubernetes cluster and is driven from Telegram through pi-telegram.

- Prompts arrive from Nikola's phone. Nobody reads this terminal. Your final answer for each turn is delivered to Telegram automatically; write it as the reply.
- Keep replies short and plain. No Markdown tables. Long tasks should end with a clear one-line summary so the phone notification is useful on its own.
- The home repo is cloned at /config/home and follows its own AGENTS.md: kubectl is read-only, changes go through Git and Flux. kubectl, flux, talosctl and sofka are already authenticated in-cluster.
EOF
fi

IFS=',' read -r -a wanted <<<"${packages}"
installed="$(jq -r '.packages[]? | if type == "string" then . else .source end' "${settings}")"
for pkg in "${wanted[@]}"; do
    pkg="${pkg// /}"
    [[ -z "${pkg}" ]] && continue
    grep -qxF "${pkg}" <<<"${installed}" && continue
    if [[ "${pkg}" == "${telegram_package}" ]]; then
        until pi install "${pkg}"; do
            echo "[pi-channel] ${pkg} is required; retrying in 30s" >&2
            sleep 30
        done
    else
        pi install "${pkg}" || echo "[pi-channel] failed to install ${pkg}" >&2
    fi
done

mcp_config="${HOME}/.config/mcp/mcp.json"
mcp_url="${BASTION_MCP_URL:-https://mcp.nikola.wtf/mcp}"
if [[ -n "${mcp_url}" && ! -f "${mcp_config}" ]]; then
    mkdir -p "$(dirname "${mcp_config}")"
    jq -n --arg url "${mcp_url}" '{mcpServers: {home: {url: $url, lifecycle: "lazy"}}}' >"${mcp_config}"
fi

telegram_config="${agent_dir}/telegram.json"
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && ! -f "${telegram_config}" ]]; then
    # shellcheck disable=SC2016
    token_ref='$TELEGRAM_BOT_TOKEN'
    jq -n --arg ref "${token_ref}" --arg owner "${TELEGRAM_ALLOWED_USER_ID:-}" '
        {profiles: {default: ({botToken: $ref}
            + (if ($owner | length) > 0 then {allowedUserId: ($owner | tonumber)} else {} end))}}' \
        >"${telegram_config}"
    chmod 600 "${telegram_config}"
fi

owners="${agent_dir}/tmp/telegram/owners.json"
if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && ! -f "${owners}" ]]; then
    mkdir -p "$(dirname "${owners}")"
    jq -n --arg cwd "${workdir}" '{default: {pid: 2147483647, cwd: $cwd, heartbeatMs: 0}}' >"${owners}"
fi
session_dir="${agent_dir}/sessions/--${workdir//\//-}--"
while true; do
    args=(--name bastion)
    if [[ -n "${BASTION_MODEL:-}" ]]; then
        args+=(--model "${BASTION_MODEL}")
    fi
    sessions=("${session_dir}"/*.jsonl)
    if [[ -e "${sessions[0]}" ]]; then
        args+=(--continue)
    fi
    pi "${args[@]}"
    echo "[pi-channel] pi exited with status $?; restarting in 5s"
    sleep 5
done
