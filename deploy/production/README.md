# Produccion

Cada cliente tiene **su propio VPS** con su propia base de datos (secret `VPS_HOST_<cliente>`).
En cada servidor queda un solo cliente:

```text
$DEPLOY_ROOT/
  demo/
    .env               # del cliente (a partir de .env.example); FRAPPE_IMAGE lo actualiza el deploy
    compose.yml        # lo copia el workflow en cada deploy
    deploy-client.sh   # idem
```

Requisitos de cada VPS: Docker con compose, la red `reverse-proxy` y un reverse proxy con HTTPS
apuntando `https://<site>` a `http://<FRONTEND_ALIAS>:8080`.

- `Dockerfile`: imagen por cliente (`--build-arg CLIENT=<cliente>`), armada con `scripts/build-bench.sh`.
- `compose.yml`: servicios del cliente. Sin puertos publicados; el frontend se une a la red `reverse-proxy`.
- `scripts/init-site.sh`: crea el sitio si no existe, instala apps faltantes y migra.
- `scripts/deploy-client.sh`: backup → mantenimiento → nueva imagen → migrate → health check, con rollback.

El disparo lo hace `.github/workflows/deploy-window.yml` en la ventana local de cada cliente.

## Migrar la instancia existente (agentic4biz, v15 → v16)

No se hace automatico. Pasos sugeridos:
1. Backup completo del sitio actual y copia anonimizada como `SNAPSHOT_URL_AGENTIC4BIZ` para que el CI pruebe la migracion.
2. Mantener `MARIADB_IMAGE=mariadb:10.6` en su `.env` (el upgrade de MariaDB va aparte).
3. Mover el stack actual a `$DEPLOY_ROOT/agentic4biz` con su volumen de datos.
4. Aprobar el release y habilitar `deploy.enabled` en `clients/agentic4biz/client.json`.
