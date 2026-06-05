#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${FRAPPE_BENCH_DIR:-/workspace/frappe-bench}"
SITE_NAME="${FRAPPE_SITE_NAME:-frappe.localhost}"
APPS_SRC="/workspace/apps"

wait_for_tcp() {
  local host="$1"
  local port="$2"
  python - "$host" "$port" <<'PY'
import socket
import sys
import time

host = sys.argv[1]
port = int(sys.argv[2])
deadline = time.time() + 120

while time.time() < deadline:
    try:
        with socket.create_connection((host, port), timeout=3):
            sys.exit(0)
    except OSError:
        time.sleep(2)

print(f"Timed out waiting for {host}:{port}", file=sys.stderr)
sys.exit(1)
PY
}

link_app() {
  local app="$1"
  local src="${APPS_SRC}/${app}"
  local dst="${BENCH_DIR}/apps/${app}"

  if [ ! -d "$src" ]; then
    echo "Missing source directory: $src" >&2
    exit 1
  fi

  if [ -L "$dst" ]; then
    return
  fi

  if [ -e "$dst" ]; then
    rm -rf "$dst"
  fi

  ln -s "$src" "$dst"
}

install_python_app() {
  local app="$1"
  "${BENCH_DIR}/env/bin/pip" install -e "${BENCH_DIR}/apps/${app}"
}

ensure_workspace_link() {
  local name="$1"
  local target="${BENCH_DIR}/${name}"
  local link="/workspace/${name}"

  mkdir -p "$target"

  if [ -L "$link" ]; then
    ln -sfn "$target" "$link"
    return
  fi

  if [ -d "$link" ] && [ -z "$(find "$link" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    rmdir "$link"
  fi

  if [ ! -e "$link" ]; then
    ln -s "$target" "$link"
  fi
}

ensure_apps_txt() {
  local app="$1"
  local apps_txt="${BENCH_DIR}/sites/apps.txt"
  touch "$apps_txt"
  grep -qxF "$app" "$apps_txt" || echo "$app" >> "$apps_txt"
}

install_site_app() {
  local app="$1"
  if ! bench --site "$SITE_NAME" list-apps | grep -qxF "$app"; then
    bench --site "$SITE_NAME" install-app "$app"
  fi
}

wait_for_tcp mariadb 3306

for app in frappe erpnext crm telephony helpdesk; do
  git config --global --add safe.directory "${APPS_SRC}/${app}" || true
  git config --global --add safe.directory "${APPS_SRC}/${app}/.git" || true
done

if [ -d "$BENCH_DIR" ] && [ ! -d "$BENCH_DIR/env" ]; then
  if [ -z "$(find "$BENCH_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    rmdir "$BENCH_DIR"
  else
    echo "Bench directory exists but is not initialized: $BENCH_DIR" >&2
    echo "Move it away or remove it before running init again." >&2
    exit 1
  fi
fi

if [ ! -d "$BENCH_DIR/env" ]; then
  mkdir -p "$(dirname "$BENCH_DIR")"
  bench init \
    --skip-redis-config-generation \
    --frappe-path "${APPS_SRC}/frappe" \
    --frappe-branch "${FRAPPE_BRANCH:-version-15}" \
    "$BENCH_DIR"
fi

cd "$BENCH_DIR"
mkdir -p apps sites config logs
ensure_workspace_link sites
ensure_workspace_link config
ensure_workspace_link logs

for app in frappe erpnext crm telephony helpdesk; do
  link_app "$app"
  ensure_apps_txt "$app"
done

for app in frappe erpnext crm telephony helpdesk; do
  install_python_app "$app"
done

bench setup requirements --node frappe erpnext crm telephony helpdesk

bench set-config -g db_host mariadb
bench set-config -g redis_cache redis://redis-cache:6379
bench set-config -g redis_queue redis://redis-queue:6379
bench set-config -g redis_socketio redis://redis-socketio:6379
bench set-config -g socketio_port 9000
bench set-config -g developer_mode 1

if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
  bench new-site "$SITE_NAME" \
    --db-host mariadb \
    --db-root-username root \
    --db-root-password "${DB_ROOT_PASSWORD:-admin}" \
    --admin-password "${ADMIN_PASSWORD:-admin}" \
    --no-mariadb-socket
fi

install_site_app erpnext
install_site_app crm
install_site_app telephony
install_site_app helpdesk

bench --site "$SITE_NAME" migrate
bench build

echo
echo "Ready: http://${SITE_NAME}:8000"
echo "Administrator password: ${ADMIN_PASSWORD:-admin}"
