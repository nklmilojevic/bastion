ssh_dir="${HOME}/.ssh"
mkdir -p "${ssh_dir}"
chmod 700 "${ssh_dir}"

if [[ -n "${PUBLIC_KEY:-}" ]]; then
    printf '%s\n' "${PUBLIC_KEY}" >"${ssh_dir}/authorized_keys"
elif [[ -n "${PUBLIC_KEY_FILE:-}" && -f "${PUBLIC_KEY_FILE}" ]]; then
    cat "${PUBLIC_KEY_FILE}" >"${ssh_dir}/authorized_keys"
fi
[[ -f "${ssh_dir}/authorized_keys" ]] && chmod 600 "${ssh_dir}/authorized_keys"

host_key="${ssh_dir}/ssh_host_ed25519_key"
if [[ ! -f "${host_key}" ]]; then
    ssh-keygen -t ed25519 -f "${host_key}" -N "" -q
fi

if ! id -un >/dev/null 2>&1; then
    echo "uid $(id -u) has no /etc/passwd entry; run the container as uid 1000" >&2
    exit 1
fi

env_file="/tmp/ssh-environment"
: >"${env_file}"
chmod 600 "${env_file}"
for var in PATH TZ TZDIR LANG LOCALE_ARCHIVE TERMINFO_DIRS HOME \
    SSL_CERT_FILE NIX_SSL_CERT_FILE GIT_SSL_CAINFO \
    KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT KUBERNETES_SERVICE_PORT_HTTPS \
    TALOSCONFIG GH_TOKEN GIT_USER_NAME GIT_USER_EMAIL \
    CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN CLAUDE_PERMISSION_MODE CLAUDE_WORKDIR \
    DISABLE_AUTOUPDATER USE_BUILTIN_RIPGREP MOSH_PORT_RANGE \
    TELEGRAM_BOT_TOKEN TELEGRAM_STATE_DIR; do
    if [[ -n "${!var:-}" ]]; then
        printf '%s=%s\n' "${var}" "${!var}" >>"${env_file}"
    fi
done
ln -sfn "${env_file}" "${ssh_dir}/environment"

sa_dir="/var/run/secrets/kubernetes.io/serviceaccount"
if [[ -n "${KUBERNETES_SERVICE_HOST:-}" && -f "${sa_dir}/token" ]]; then
    context="${KUBE_CONTEXT_NAME:-in-cluster}"
    mkdir -p "${HOME}/.kube"
    cat >"${HOME}/.kube/config" <<KUBECONFIG
apiVersion: v1
kind: Config
clusters:
  - name: ${context}
    cluster:
      server: https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT:-443}
      certificate-authority: ${sa_dir}/ca.crt
users:
  - name: serviceaccount
    user:
      tokenFile: ${sa_dir}/token
contexts:
  - name: ${context}
    context:
      cluster: ${context}
      user: serviceaccount
      namespace: $(cat "${sa_dir}/namespace" 2>/dev/null || echo default)
current-context: ${context}
KUBECONFIG
    chmod 600 "${HOME}/.kube/config"
fi

if [[ -n "${GIT_CLONE_URL:-}" ]]; then
    repo_name="$(basename "${GIT_CLONE_URL%.git}")"
    repo_dir="${HOME}/${GIT_CLONE_DIR:-${repo_name}}"
    if [[ ! -d "${repo_dir}/.git" ]]; then
        git clone "${GIT_CLONE_URL}" "${repo_dir}"
    fi
fi
[[ -n "${GIT_USER_NAME:-}" ]] && git config --global user.name "${GIT_USER_NAME}"
[[ -n "${GIT_USER_EMAIL:-}" ]] && git config --global user.email "${GIT_USER_EMAIL}"
if [[ -n "${GH_TOKEN:-}" ]]; then
    gh auth setup-git --hostname github.com >/dev/null 2>&1 || true
fi

if [[ "${CLAUDE_CHANNEL_ENABLED:-true}" == "true" ]]; then
    tmux new-session -d -s claude -c "${HOME}" claude-channel
fi

exec @sshd@ -D -e \
    -p "${PORT:-2222}" \
    -h "${host_key}" \
    -o "PidFile=${ssh_dir}/sshd.pid" \
    -o "PasswordAuthentication=no" \
    -o "PubkeyAuthentication=yes" \
    -o "AuthorizedKeysFile=${ssh_dir}/authorized_keys" \
    -o "PermitUserEnvironment=yes" \
    -o "StrictModes=no" \
    -o "Subsystem=sftp @sftpServer@"
