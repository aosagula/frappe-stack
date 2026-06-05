# Produccion Frappe

Stack Docker de produccion para `frappe.agentic4biz.com`.

## Red del reverse proxy

Crear una red Docker compartida entre este stack y el reverse proxy:

```bash
docker network create reverse-proxy
```

El reverse proxy debe estar conectado a esa red y enviar trafico HTTPS de:

```text
frappe.agentic4biz.com -> http://frappe-frontend:8080
```

Este stack no publica puertos host. Solo expone `frontend:8080` dentro de la red externa `reverse-proxy`.

## Variables

```bash
cp deploy/production/.env.example deploy/production/.env
```

Editar passwords antes de levantar.

## Primer deploy manual

```bash
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml build
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml up -d mariadb redis-cache redis-queue redis-socketio
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml run --rm init
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml up -d
```

## Deploy posterior

```bash
git pull --ff-only origin main
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml build
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml run --rm init
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml up -d
```

## Reverse proxy ejemplo nginx

```nginx
server {
    listen 443 ssl http2;
    server_name frappe.agentic4biz.com;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_pass http://frappe-frontend:8080;
    }
}
```

## Nota sobre sources

El build copia `apps/` dentro de la imagen y `.dockerignore` excluye `**/.git/`, asi que la imagen final no contiene historial Git.

Para que el VPS reproduzca exactamente tus cambios al hacer deploy desde `main`, `apps/` debe estar versionado de una de estas dos formas:

- Submodulos Git apuntando a tus forks o a commits especificos.
- Codigo vendorizado directamente en este repo, sin los `.git` internos.

La opcion recomendada es submodulos contra forks propios si vas a modificar Frappe, ERPNext, CRM o Helpdesk.

## GitHub Actions

El workflow `.github/workflows/deploy-production.yml` despliega automaticamente cuando se actualiza `main`.

Secrets requeridos:

```text
VPS_HOST
VPS_USER
VPS_SSH_KEY
VPS_DEPLOY_PATH
REPO_SSH_URL
```

`REPO_SSH_URL` debe ser la URL SSH del repo principal, por ejemplo:

```text
git@github.com:aosagula/frappe-stack.git
```

En el VPS, `VPS_DEPLOY_PATH` puede estar vacio. El workflow lo clona automaticamente si no tiene `.git`.

El archivo de entorno de produccion debe existir en:

```text
deploy/production/.env
```

Si el workflow clona el repo por primera vez, crear ese archivo luego en el VPS y relanzar el job.
