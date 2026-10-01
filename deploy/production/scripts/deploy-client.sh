#!/usr/bin/env bash
# Despliega un release en UN cliente, en el VPS. Lo invoca el workflow deploy-window.yml
# solo cuando la ventana de mantenimiento del cliente esta abierta (hora local del cliente).
#
# Uso: deploy-client.sh CLIENTE IMAGEN
#   CLIENTE  nombre (clients/<CLIENTE>/client.json)
#   IMAGEN   ghcr.io/aosagula/frappe-<cliente>:<release>
#
# Espera en $DEPLOY_ROOT/<CLIENTE>/: .env (del cliente) y compose.yml (lo copia el workflow).
# Pasos: backup -> modo mantenimiento -> nueva imagen -> migrate -> health check.
# Si algo falla: vuelve a la imagen anterior y restaura la base del backup recien tomado.
set -euo pipefail

CLIENT="${1:?cliente}"
IMAGE="${2:?imagen}"
DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/frappe-clients}"
DIR="$DEPLOY_ROOT/$CLIENT"
cd "$DIR"

[ -f .env ] || { echo "Falta $DIR/.env" >&2; exit 1; }
set -a; . ./.env; set +a

dc() { docker compose --env-file .env -f compose.yml "$@"; }
log() { echo "[$(date -u +%FT%TZ)] [$CLIENT] $*"; }

PREVIOUS="${FRAPPE_IMAGE:-}"
if [ "$PREVIOUS" = "$IMAGE" ]; then
	log "Ya esta en $IMAGE, nada que hacer"
	exit 0
fi

docker network inspect "${PROXY_NETWORK:-reverse-proxy}" >/dev/null 2>&1 \
	|| docker network create "${PROXY_NETWORK:-reverse-proxy}"

log "Descargando $IMAGE"
docker pull "$IMAGE"

FIRST_DEPLOY=0
if [ -z "$PREVIOUS" ] || ! dc ps --status running backend -q | grep -q .; then
	FIRST_DEPLOY=1
fi

BACKUP_DIR=""
if [ "$FIRST_DEPLOY" = 0 ]; then
	log "Backup previo"
	dc exec -T backend bench --site "$SITE_NAME" backup --with-files
	BACKUP_DIR="$(dc exec -T backend sh -c "ls -td /home/frappe/frappe-bench/sites/$SITE_NAME/private/backups/*-database.sql.gz | head -1")"
	log "Backup: $BACKUP_DIR"
	dc exec -T backend bench --site "$SITE_NAME" set-maintenance-mode on
fi

set_image() {
	sed -i "s#^FRAPPE_IMAGE=.*#FRAPPE_IMAGE=$1#" .env
	export FRAPPE_IMAGE="$1"
}

rollback() {
	log "FALLO: volviendo a $PREVIOUS"
	if [ -z "$PREVIOUS" ]; then
		exit 1
	fi
	set_image "$PREVIOUS"
	dc up -d --remove-orphans
	if [ -n "$BACKUP_DIR" ]; then
		log "Restaurando base desde $BACKUP_DIR"
		dc exec -T backend bench --site "$SITE_NAME" restore "$BACKUP_DIR" \
			--db-root-password "$DB_ROOT_PASSWORD" --force
	fi
	dc exec -T backend bench --site "$SITE_NAME" set-maintenance-mode off || true
	dc exec -T backend bench --site "$SITE_NAME" clear-cache || true
	exit 1
}
trap rollback ERR

set_image "$IMAGE"
dc up -d mariadb redis-cache redis-queue redis-socketio
log "Migrando"
dc run --rm init
dc up -d --remove-orphans
dc exec -T backend bench --site "$SITE_NAME" set-maintenance-mode off

log "Health check"
for i in $(seq 1 40); do
	if dc exec -T frontend curl -fsS -H "Host: $SITE_NAME" http://127.0.0.1:8080/api/method/ping >/dev/null 2>&1; then
		trap - ERR
		log "OK: $CLIENT en $IMAGE (antes: ${PREVIOUS:-ninguna})"
		exit 0
	fi
	sleep 5
done
false
