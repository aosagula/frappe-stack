# frappe-stack — plataforma multicliente sobre Frappe/ERPNext v16

Un solo repo para operar varios clientes con el mismo core, cada uno con sus personalizaciones,
su propia instancia y su propia ventana de mantenimiento en su hora local.

> El estado anterior (v15 con forks y submodulos, deploy automatico a `frappe.agentic4biz.com`)
> quedo respaldado en la rama `backup/v15-baseline`.

## Capas

| Capa | Donde | Quien la cambia | Regla |
| --- | --- | --- | --- |
| Core | `stack.json` (Frappe, ERPNext, CRM, Helpdesk, Telephony oficiales) | Nadie lo edita: solo se sube de version | Fijado por **commit**. Nunca se modifica el codigo. |
| Base | `apps/agentic_base` | Vos, para todos | Lo que comparten 2+ clientes. Correcciones al core por hooks. |
| Cliente | `clients/<cliente>/` (`client.json` + su app) | Vos, por cliente | Lo minimo propio del cliente. |

Nada de monkey patches: el CI rechaza asignaciones del tipo `frappe.algo = ...` en apps propias
(`scripts/check-no-monkeypatch.sh`). Se personaliza con hooks, `override_doctype_class` y fixtures.

## Cliente: `clients/<cliente>/client.json`

```json
{
  "name": "demo",
  "site": "demo.agentic4biz.com",
  "timezone": "America/Argentina/Buenos_Aires",
  "maintenance_window": { "days": ["sun"], "start": "02:00", "duration_minutes": 120 },
  "optional_apps": [],
  "app": { "name": "cliente_demo", "path": "clients/demo/cliente_demo" },
  "release": "",
  "deploy": { "enabled": false, "canary": true }
}
```

- `app` puede ser una carpeta de este repo (`path`) o un repo propio del cliente (`repo` + `commit`).
- `release` es el tag de imagen aprobado para ese cliente (el SHA corto que publica el workflow Images).

Clientes incluidos:
- `demo`: ficticio. App `cliente_demo` con campo NCM en Articulo, validacion y tests.
- `agentic4biz`: la instancia que antes desplegaba `main`. Deploy **deshabilitado** hasta planificar la migracion v15 → v16.

## Apps externas (movil, web, integraciones)

Las apps externas viven en su propio repo y hablan con ERPNext solo por una **API propia versionada**
dentro de la app del cliente (o de `agentic_base` si la comparten varios clientes), nunca por `/api/resource/<Doctype>`.

- Endpoints en `<app>/api/v1/…` (ejemplo: `cliente_demo.api.v1.articulos.listar`).
- Dentro de una version solo se agregan campos o endpoints. Un cambio incompatible va a `v2` y `v1` sigue viva mientras haya apps viejas instaladas.
- Cada endpoint tiene **tests de contrato** (`tests/test_api_v1.py`): campos, tipos, paginacion, permisos y metodo HTTP. Si un cambio del core o propio los rompe, el CI queda en rojo.
- En `client.json`:
  - `external_apps`: que apps usa el cliente y que version de la API consumen (se valida que exista).
  - `cors_origins`: dominios de apps web autorizados (se aplican en cada deploy y el smoke test verifica el header). Las apps moviles nativas no lo necesitan.
- Autenticacion: usuarios de la app con OAuth2 de Frappe o token por usuario; integraciones con API key de un usuario tecnico con permisos acotados. Nunca credenciales de Administrator en una app.

## Flujo de un cambio

1. **PR** (cambio en core, base o cliente) → workflow **CI**: valida configs, lint, y por cada cliente arma el bench, instala en un sitio limpio, corre los tests de la base y del cliente, y migra dos veces. Si hay snapshot del cliente (`SNAPSHOT_URL_<CLIENTE>`), lo restaura y migra encima.
2. Mismo PR → workflow **Images**: construye la imagen de cada cliente y la levanta con el compose de produccion (smoke test).
3. **Merge a main** → Images publica `ghcr.io/aosagula/frappe-<cliente>:<sha>`. **No despliega nada.**
4. **Aprobar**: PR que pone ese `<sha>` en `release` del cliente canario. Luego, los demas.
5. **Deploy en ventana** (cada hora): si la ventana del cliente esta abierta en su hora local y el release cambio, backup → mantenimiento → migrate → health check. Si falla, vuelve a la imagen anterior y restaura el backup.

Emergencias: `Deploy en ventana` → *Run workflow* con `client` y `force` para saltear la ventana.

## Actualizar el core

Editar en `stack.json` el `tag` y el `commit` de la app. El CI corre contra todos los clientes.
Para conseguir el commit de un tag: `git ls-remote https://github.com/frappe/erpnext refs/tags/v16.38.0`.

## Comandos

```bash
python3 scripts/stack.py validate          # valida stack.json y clientes
python3 scripts/stack.py apps demo         # apps del cliente en orden
python3 scripts/stack.py due               # clientes en ventana ahora

# Prueba completa de un cliente (requiere Python 3.14, Node 24, bench, MariaDB y Redis)
DB_ROOT_PASSWORD=root bash scripts/ci-test-client.sh demo

# Imagen y entorno local de un cliente con Docker
docker build -f deploy/production/Dockerfile --build-arg CLIENT=demo -t frappe-demo:local .
cp deploy/production/.env.example deploy/production/.env   # FRAPPE_IMAGE=frappe-demo:local, SITE_NAME=demo.localhost
docker network create reverse-proxy
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml up -d mariadb redis-cache redis-queue redis-socketio
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml run --rm init
docker compose --env-file deploy/production/.env -f deploy/production/compose.yml up -d
```

## Nuevo cliente

1. Copiar `clients/demo` a `clients/<nuevo>` y renombrar la app (`cliente_demo` → `cliente_<nuevo>`).
2. Ajustar `client.json`: sitio, zona horaria, ventana, apps opcionales.
3. Escribir los tests de sus flujos criticos en la app del cliente.
4. Preparar su VPS (Docker + reverse proxy con HTTPS), cargar el secret `VPS_HOST_<nuevo>` y crear `$DEPLOY_ROOT/<nuevo>/.env` a partir de `deploy/production/.env.example`.
5. Cuando haya release aprobado: `"deploy": {"enabled": true}` y `"release": "<sha>"`.

## Configuracion en GitHub

- Environment `production` (opcional: con aprobacion manual). **Cada cliente tiene su propio VPS**:
  - `VPS_HOST_<cliente>` (obligatorio, sin default: un cliente sin servidor propio no se despliega).
  - `VPS_USER_<cliente>` y `VPS_SSH_KEY_<cliente>`, o `VPS_USER` / `VPS_SSH_KEY` sin sufijo como default para todos.
- Variable `DEPLOY_ROOT` (default `/opt/frappe-clients`).
- Opcional: `SNAPSHOT_URL_<CLIENTE>` con un backup anonimizado para probar migraciones sobre datos reales.

## Reverse proxy

Cada cliente expone `frontend:8080` en la red Docker `reverse-proxy` con el alias de `FRONTEND_ALIAS`.
El proxy del VPS apunta `https://<site>` → `http://<FRONTEND_ALIAS>:8080`.
`nginx.conf.template` completa el header `Origin` de socket.io (antes era un parche al core).
