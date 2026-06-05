#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR=/home/frappe/frappe-bench
APPS_SRC=/home/frappe/src/apps

bench init \
	--skip-redis-config-generation \
	--frappe-branch version-15 \
	"${BENCH_DIR}"

cd "${BENCH_DIR}"
mkdir -p apps sites config logs
ln -sfn "${BENCH_DIR}/sites" /home/frappe/src/sites

copy_app() {
	local app="$1"
	rm -rf "${BENCH_DIR}/apps/${app}"
	mkdir -p "${BENCH_DIR}/apps/${app}"
	cp -a "${APPS_SRC}/${app}/." "${BENCH_DIR}/apps/${app}/"
}

for app in frappe erpnext crm telephony helpdesk; do
	copy_app "$app"
done

cat > sites/apps.txt <<'EOF'
frappe
erpnext
crm
telephony
helpdesk
EOF

for app in frappe erpnext crm telephony helpdesk; do
	"${BENCH_DIR}/env/bin/pip" install -e "${BENCH_DIR}/apps/${app}"
done

bench setup requirements --node frappe erpnext crm telephony helpdesk
bench build

rm -rf /home/frappe/src
