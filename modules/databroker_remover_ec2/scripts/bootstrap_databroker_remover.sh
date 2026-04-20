#!/bin/bash
set -Eeuo pipefail

exec > >(tee -a /var/log/databroker-remover-bootstrap.log | logger -t databroker-remover-bootstrap) 2>&1

source /etc/default/databroker-remover-bootstrap

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

run_as_app() {
  sudo -u "${APP_USER}" -H bash -lc "$*"
}

ensure_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    ca-certificates \
    curl \
    git \
    jq \
    nginx \
    unzip \
    build-essential \
    awscli \
    python3-certbot-nginx
}

ensure_node() {
  local current_major=""
  if command -v node >/dev/null 2>&1; then
    current_major="$(node -p 'process.versions.node.split(\".\")[0]')"
  fi

  if [[ "${current_major}" != "22" ]]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
  fi

  if ! command -v pnpm >/dev/null 2>&1; then
    corepack enable
    corepack prepare pnpm@latest --activate
  fi
}

ensure_user_and_dirs() {
  if ! id -u "${APP_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --shell /bin/bash "${APP_USER}"
  fi

  install -d -o "${APP_USER}" -g "${APP_USER}" -m 0755 "${APP_DIR}"
}

sync_repo() {
  if [[ ! -d "${APP_DIR}/.git" ]]; then
    rm -rf "${APP_DIR}"
    install -d -o "${APP_USER}" -g "${APP_USER}" -m 0755 "${APP_DIR}"
    run_as_app "git clone --branch '${GITHUB_BRANCH}' --single-branch '${GITHUB_REPO}' '${APP_DIR}'"
  else
    run_as_app "cd '${APP_DIR}' && git remote set-url origin '${GITHUB_REPO}' && git fetch --depth=1 origin '${GITHUB_BRANCH}' && git checkout '${GITHUB_BRANCH}' && git reset --hard FETCH_HEAD"
  fi
}

fetch_ssm_value() {
  local parameter_name="$1"
  aws ssm get-parameter \
    --region "${AWS_REGION}" \
    --with-decryption \
    --name "${parameter_name}" \
    --query 'Parameter.Value' \
    --output text
}

render_env_file() {
  local env_file="${APP_DIR}/.env.local"
  : > "${env_file}"

  for parameter_name in ${SSM_PARAMETER_NAMES}; do
    local key="${parameter_name##*/}"
    local value
    value="$(fetch_ssm_value "${parameter_name}")"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s="%s"\n' "${key}" "${value}" >> "${env_file}"
  done

  if [[ -n "${OPENAI_API_KEY_SECRET_ARN}" ]]; then
    local secret_value=""
    secret_value="$(aws secretsmanager get-secret-value --region "${AWS_REGION}" --secret-id "${OPENAI_API_KEY_SECRET_ARN}" --query 'SecretString' --output text 2>/dev/null || true)"

    if [[ -n "${secret_value}" && "${secret_value}" != "None" ]]; then
      secret_value="${secret_value//\\/\\\\}"
      secret_value="${secret_value//\"/\\\"}"
      printf 'OPENAI_API_KEY="%s"\n' "${secret_value}" >> "${env_file}"
    else
      log "OPENAI_API_KEY secret is configured but has no value yet."
    fi
  fi

  chown "${APP_USER}:${APP_USER}" "${env_file}"
  chmod 0600 "${env_file}"
}

install_dependencies_and_build() {
  run_as_app "cd '${APP_DIR}' && corepack enable && pnpm install --no-frozen-lockfile && pnpm build"
}

configure_systemd() {
  systemctl daemon-reload
  systemctl enable databroker-remover.service
  systemctl restart databroker-remover.service
}

configure_nginx() {
  rm -f /etc/nginx/sites-enabled/default
  ln -sf /etc/nginx/sites-available/databroker-remover.conf /etc/nginx/sites-enabled/databroker-remover.conf
  nginx -t
  systemctl enable nginx
  systemctl restart nginx
}

configure_https() {
  if [[ "${ENABLE_HTTPS}" != "true" ]]; then
    return
  fi

  if [[ -z "${HOSTNAME_VALUE}" || -z "${ACME_EMAIL}" ]]; then
    log "HTTPS requested but hostname/acme email is missing; skipping certbot."
    return
  fi

  if [[ -d "/etc/letsencrypt/live/${HOSTNAME_VALUE}" ]]; then
    log "LetsEncrypt certificate already exists for ${HOSTNAME_VALUE}."
    return
  fi

  certbot --nginx \
    --non-interactive \
    --agree-tos \
    --redirect \
    --email "${ACME_EMAIL}" \
    -d "${HOSTNAME_VALUE}"
}

main() {
  log "Starting databroker_remover bootstrap"
  ensure_packages
  ensure_node
  ensure_user_and_dirs
  sync_repo
  render_env_file
  install_dependencies_and_build
  configure_systemd
  configure_nginx
  configure_https
  log "Bootstrap completed successfully"
}

main "$@"
