#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR=/home/frappe/frappe-bench
SITE_NAME="${SITE_NAME:-frappe.agentic4biz.com}"

cd "${BENCH_DIR}"

cat > sites/apps.txt <<'EOF'
frappe
erpnext
crm
telephony
helpdesk
EOF

bench set-config -g db_host "${DB_HOST:-mariadb}"
bench set-config -g db_port "${DB_PORT:-3306}"
bench set-config -g redis_cache "${REDIS_CACHE:-redis://redis-cache:6379}"
bench set-config -g redis_queue "${REDIS_QUEUE:-redis://redis-queue:6379}"
bench set-config -g redis_socketio "${REDIS_SOCKETIO:-redis://redis-socketio:6379}"
bench set-config -g socketio_port "${SOCKETIO_PORT:-9000}"
bench set-config -g developer_mode "${DEVELOPER_MODE:-0}"
bench set-config -g serve_default_site true

install_site_app() {
	local app="$1"
	if ! bench --site "${SITE_NAME}" list-apps | grep -qxF "$app"; then
		bench --site "${SITE_NAME}" install-app "$app"
	fi
}

if [ ! -f "sites/${SITE_NAME}/site_config.json" ]; then
	bench new-site "${SITE_NAME}" \
		--db-host "${DB_HOST:-mariadb}" \
		--db-port "${DB_PORT:-3306}" \
		--db-root-username "${DB_ROOT_USER:-root}" \
		--db-root-password "${DB_ROOT_PASSWORD:?set DB_ROOT_PASSWORD}" \
		--admin-password "${ADMIN_PASSWORD:?set ADMIN_PASSWORD}" \
		--no-mariadb-socket
fi

install_site_app erpnext
install_site_app crm
install_site_app telephony
install_site_app helpdesk

bench --site "${SITE_NAME}" migrate

# Mark setup wizard complete so the desk renders the navbar correctly.
# ERPNext sets desktop:home_page=setup-wizard and is_setup_complete=0
# in tabInstalled Application; fix both so the desk loads normally.
echo "UPDATE \`tabInstalled Application\` SET is_setup_complete=1 WHERE app_name IN ('frappe','erpnext');
UPDATE \`tabDefaultValue\` SET defvalue='home' WHERE defkey='desktop:home_page' AND defvalue='setup-wizard';" \
	| bench --site "${SITE_NAME}" mariadb

mkdir -p sites/assets
cp -a /home/frappe/prebuilt-assets/. sites/assets/
bench --site "${SITE_NAME}" clear-cache
bench --site "${SITE_NAME}" clear-website-cache
