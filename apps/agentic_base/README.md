# Agentic Base

App comun a todos los clientes. Va instalada en cada sitio, entre el core (Frappe + ERPNext oficiales) y la app propia del cliente.

Que va aca:
- Correcciones al core hechas por hooks (nunca editando Frappe/ERPNext).
- Localizacion y logica que comparte mas de un cliente. Si dos clientes piden lo mismo, sube a esta capa.

Contenido actual:
- `boot.py`: completa `desk_settings` y `navbar_settings` para que el navbar no se rompa (reemplaza los parches que estaban en el fork de Frappe).
- `install.py` + patch `v1_0.set_default_desk_settings`: habilita buscador y notificaciones a usuarios de sistema.

Tests: `bench --site <sitio> run-tests --app agentic_base`
