#!/usr/bin/env bash
# Prueba completa de un cliente contra la version del core fijada en stack.json:
#   1. arma el bench (sin assets)
#   2. crea un sitio limpio e instala las apps en orden
#   3. corre los tests de la app base y de la app del cliente
#   4. corre migrate dos veces (los patches tienen que ser idempotentes)
#   5. si hay SNAPSHOT_SQL (backup anonimizado del cliente), lo restaura y migra encima
#
# Uso: scripts/ci-test-client.sh CLIENTE [BENCH_DIR]
# Variables: DB_HOST, DB_PORT, DB_ROOT_PASSWORD, REDIS_URL, SNAPSHOT_SQL (opcional)
set -euo pipefail

CLIENT="${1:?cliente}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH_DIR="${2:-$ROOT/.work/$CLIENT/frappe-bench}"
SITE="test-$CLIENT.localhost"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"
REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
RESULTS="$ROOT/.work/$CLIENT/results"
mkdir -p "$RESULTS"

APPS=($(python3 "$ROOT/scripts/stack.py" apps "$CLIENT"))
CLIENT_APP="$(python3 "$ROOT/scripts/stack.py" get "$CLIENT" app.name)"

bash "$ROOT/scripts/build-bench.sh" "$CLIENT" "$BENCH_DIR" --skip-assets
cd "$BENCH_DIR"

bench set-config -g db_host "$DB_HOST"
bench set-config -g db_port "$DB_PORT"
bench set-config -g redis_cache "$REDIS_URL/0"
bench set-config -g redis_queue "$REDIS_URL/1"
bench set-config -g redis_socketio "$REDIS_URL/2"

if [ -d "sites/$SITE" ]; then
	bench drop-site "$SITE" --force --db-root-password "$DB_ROOT_PASSWORD" --no-backup
fi

echo "==> Sitio limpio $SITE"
bench new-site "$SITE" \
	--db-root-password "$DB_ROOT_PASSWORD" \
	--admin-password admin \
	--mariadb-user-host-login-scope='%'
bench --site "$SITE" set-config allow_tests true

for app in "${APPS[@]}"; do
	[ "$app" = "frappe" ] && continue
	echo "==> install-app $app"
	bench --site "$SITE" install-app "$app"
done

echo "==> Tests agentic_base"
bench --site "$SITE" run-tests --app agentic_base --junit-xml-output "$RESULTS/agentic_base.xml"

if [ -n "$CLIENT_APP" ] && [ "$CLIENT_APP" != "None" ]; then
	echo "==> Tests $CLIENT_APP"
	bench --site "$SITE" run-tests --app "$CLIENT_APP" --junit-xml-output "$RESULTS/$CLIENT_APP.xml"
fi

echo "==> Migrate x2 (idempotencia)"
bench --site "$SITE" migrate
bench --site "$SITE" migrate

if [ -n "${SNAPSHOT_SQL:-}" ] && [ -f "$SNAPSHOT_SQL" ]; then
	echo "==> Restaurando snapshot del cliente y migrando a la version candidata"
	bench --site "$SITE" restore "$SNAPSHOT_SQL" --db-root-password "$DB_ROOT_PASSWORD" --force
	bench --site "$SITE" migrate
fi

echo "==> OK: $CLIENT paso todas las pruebas"
