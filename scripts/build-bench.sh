#!/usr/bin/env bash
# Arma un bench completo para un cliente: core fijado por commit + opcionales + app base + app del cliente.
# Lo usan el CI (tests) y el Dockerfile (imagen de produccion), asi ambos prueban exactamente lo mismo.
#
# Uso: scripts/build-bench.sh CLIENTE BENCH_DIR [--skip-assets]
# Requiere en PATH: git, bench, node 24, yarn. PYTHON apunta a Python 3.14 (default: python3.14).
set -euo pipefail

CLIENT="${1:?cliente}"
BENCH_DIR="$(realpath -m "${2:?directorio del bench}")"
SKIP_ASSETS="${3:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-python3.14}"
SRC_DIR="${SRC_DIR:-$(dirname "$BENCH_DIR")/src}"

STACK="$ROOT/scripts/stack.py"
APPS=($(python3 "$STACK" apps "$CLIENT"))

echo "==> Cliente $CLIENT: ${APPS[*]}"
python3 "$STACK" validate
python3 "$STACK" fetch "$SRC_DIR" "$CLIENT"

if [ ! -d "$BENCH_DIR/env" ]; then
	bench init \
		--frappe-path "$SRC_DIR/frappe" \
		--python "$PYTHON" \
		--skip-redis-config-generation \
		--no-procfile \
		--no-backups \
		--skip-assets \
		"$BENCH_DIR"
fi

cd "$BENCH_DIR"
touch sites/apps.txt
# bench deja apps.txt sin salto de linea final; sin esto el append pega los nombres
sed -i -e '$a\' sites/apps.txt

app_dir() {
	local app="$1"
	if [ -d "$SRC_DIR/$app" ]; then
		echo "$SRC_DIR/$app"
	elif [ "$app" = "agentic_base" ]; then
		echo "$ROOT/apps/agentic_base"
	else
		echo "$ROOT/$(python3 "$STACK" get "$CLIENT" app.path)"
	fi
}

for app in "${APPS[@]}"; do
	[ "$app" = "frappe" ] && continue
	src="$(app_dir "$app")"
	rm -rf "apps/$app"
	cp -a "$src" "apps/$app"
	rm -rf "apps/$app/.git"
	./env/bin/python -m pip install --quiet -e "apps/$app"
	grep -qxF "$app" sites/apps.txt || echo "$app" >> sites/apps.txt
	if [ -f "apps/$app/package.json" ]; then
		bench setup requirements --node "$app"
	fi
	echo "  + $app"
done

printf '%s\n' "${APPS[@]}" > sites/apps.txt

if [ "$SKIP_ASSETS" != "--skip-assets" ]; then
	bench build --production
fi

echo "==> Bench listo en $BENCH_DIR"
