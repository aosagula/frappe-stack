#!/usr/bin/env bash
# Prepara el sitio del cliente en cada deploy: crea el sitio si no existe, instala apps faltantes y migra.
# La lista de apps viene horneada en la imagen (/home/frappe/client-apps.txt), no hardcodeada.
set -euo pipefail

BENCH_DIR=/home/frappe/frappe-bench
SITE_NAME="${SITE_NAME:?set SITE_NAME}"

cd "${BENCH_DIR}"
cp /home/frappe/client-apps.txt sites/apps.txt

bench set-config -g db_host "${DB_HOST:-mariadb}"
bench set-config -g db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "${REDIS_CACHE:-redis://redis-cache:6379}"
bench set-config -g redis_queue "${REDIS_QUEUE:-redis://redis-queue:6379}"
bench set-config -g redis_socketio "${REDIS_SOCKETIO:-redis://redis-socketio:6379}"
bench set-config -g socketio_port "${SOCKETIO_PORT:-9000}"
bench set-config -g developer_mode "${DEVELOPER_MODE:-0}"
bench set-config -g serve_default_site true

if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
	bench new-site "${SITE_NAME}" \
		--db-host "${DB_HOST:-mariadb}" \
		--db-port "${DB_PORT:-3306}" \
		--db-root-username "${DB_ROOT_USER:-root}" \
		--db-root-password "${DB_ROOT_PASSWORD:?set DB_ROOT_PASSWORD}" \
		--admin-password "${ADMIN_PASSWORD:?set ADMIN_PASSWORD}" \
		--mariadb-user-host-login-scope='%'
	bench use "${SITE_NAME}"
fi

installed="$(bench --site "${SITE_NAME}" list-apps --format text 2>/dev/null | awk '{print $1}')"
while read -r app; do
	[ -z "$app" ] || [ "$app" = "frappe" ] && continue
	if ! grep -qxF "$app" <<<"$installed"; then
		echo "==> install-app $app"
		bench --site "${SITE_NAME}" install-app "$app"
	fi
done < /home/frappe/client-apps.txt

bench --site "${SITE_NAME}" migrate

# Origenes web autorizados a llamar la API (apps web externas del cliente). Las apps moviles nativas no lo necesitan.
cors="$(python3 -c 'import json; print(json.dumps(json.load(open("/home/frappe/client.json")).get("cors_origins", [])))')"
if [ "$cors" != "[]" ]; then
	bench --site "${SITE_NAME}" set-config allow_cors "$cors" --parse
else
	bench --site "${SITE_NAME}" set-config allow_cors "None" --parse
fi

mkdir -p sites/assets
cp -a /home/frappe/prebuilt-assets/. sites/assets/
bench --site "${SITE_NAME}" clear-cache
bench --site "${SITE_NAME}" clear-website-cache
echo "==> Sitio ${SITE_NAME} listo en release $(cat /home/frappe/release.txt)"
