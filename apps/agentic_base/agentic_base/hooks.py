app_name = "agentic_base"
app_title = "Agentic Base"
app_publisher = "Agentic4Biz"
app_description = "Capa base comun a todos los clientes"
app_email = "alejandro.sagula@gmail.com"
app_license = "gpl-3.0"

required_apps = ["frappe", "erpnext"]

# Reemplaza los parches que antes vivian en el fork de Frappe (navbar).
# Se ejecuta despues de que el core arma el bootinfo, sin tocar su codigo.
extend_bootinfo = "agentic_base.boot.extend_bootinfo"

after_install = "agentic_base.install.after_install"
after_migrate = "agentic_base.install.after_migrate"

# Regla de la plataforma: nada de monkey patches al core.
# Toda personalizacion entra por hooks, overrides que extienden la clase original, o fixtures.
