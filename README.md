# Frappe Local Sources

Entorno Docker local para Frappe Framework, ERPNext, Frappe CRM y Frappe Helpdesk con control directo de los sources.

## Sources

Los repos viven en `apps/` y son la fuente de verdad:

| App | Rama |
| --- | --- |
| `frappe` | `version-15` |
| `erpnext` | `version-15` |
| `crm` | `main` |
| `helpdesk` | `main` |
| `telephony` | `develop` |

Frappe mantiene `version-15` como rama soportada hasta fines de 2027, y CRM/Helpdesk declaran compatibilidad estable de `main` con Frappe/ERPNext v15.

## Primer arranque

```powershell
.\scripts\init.ps1
.\scripts\start.ps1
```

Abrir:

```text
http://frappe.localhost:8000
```

Credenciales por defecto:

```text
Usuario: Administrator
Password: admin
```

Podés cambiar `FRAPPE_SITE_NAME`, `ADMIN_PASSWORD` y `DB_ROOT_PASSWORD` en `.env` antes de inicializar.

## Operación

Arrancar:

```powershell
.\scripts\start.ps1
```

Reconstruir assets:

```powershell
.\scripts\build.ps1
```

Parar contenedores:

```powershell
.\scripts\stop.ps1
```

Entrar al bench:

```powershell
docker compose run --rm bench bash
```

Ejecutar comandos bench:

```powershell
docker compose run --rm bench bench --site frappe.localhost list-apps
docker compose run --rm bench bench --site frappe.localhost migrate
docker compose run --rm bench bench build
```

## Notas

- `frappe-bench/` se genera localmente y queda ignorado por Git.
- `sites` queda como symlink local a `frappe-bench/sites` para que los builds de apps montadas resuelvan los paths esperados.
- MariaDB persiste en el volumen Docker `mariadb-data`.
- Los cambios en `apps/*` son cambios reales sobre los repos clonados.
- `crm` y `helpdesk` incluyen el submódulo `frappe-ui`, ya inicializado.

## Produccion

La variante para VPS esta en `deploy/production/`.

Dominio previsto:

```text
frappe.agentic4biz.com
```

El contenedor `frontend` no publica puertos host. Se conecta a la red externa Docker `reverse-proxy` con el alias `frappe-frontend`, para que el reverse proxy del VPS apunte a:

```text
http://frappe-frontend:8080
```

La imagen de produccion se construye sin metadata `.git` de las apps.
