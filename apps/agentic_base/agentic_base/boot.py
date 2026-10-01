"""Defensas sobre el bootinfo del desk.

En v15 (y el mismo codigo sigue en v16) el navbar se rompe si `desk_settings`
llega vacio o si `navbar_settings` no trae los dropdowns. Antes lo arreglabamos
modificando toolbar.js en un fork de Frappe; aca lo resolvemos del lado del
servidor, completando los valores faltantes antes de que lleguen al navegador.
"""

DESK_PROPERTIES = (
	"search_bar",
	"notifications",
	"list_sidebar",
	"bulk_actions",
	"view_switcher",
	"form_sidebar",
	"form_navigation_buttons",
	"timeline",
	"dashboard",
)

NAVBAR_LIST_KEYS = ("settings_dropdown", "help_dropdown")


def normalize_desk_settings(desk_settings):
	"""Devuelve un dict con todas las propiedades del desk; las faltantes quedan habilitadas."""
	normalized = dict(desk_settings or {})
	for prop in DESK_PROPERTIES:
		if normalized.get(prop) is None:
			normalized[prop] = 1
	return normalized


def normalize_navbar_settings(navbar_settings):
	"""Garantiza que los dropdowns del navbar sean listas (el template itera sobre ellos)."""
	if navbar_settings is None:
		navbar_settings = {}
	for key in NAVBAR_LIST_KEYS:
		if not _get(navbar_settings, key):
			_set(navbar_settings, key, [])
	return navbar_settings


def extend_bootinfo(bootinfo):
	bootinfo["desk_settings"] = normalize_desk_settings(bootinfo.get("desk_settings"))
	bootinfo["navbar_settings"] = normalize_navbar_settings(bootinfo.get("navbar_settings"))


def _get(obj, key):
	return obj.get(key) if isinstance(obj, dict) else getattr(obj, key, None)


def _set(obj, key, value):
	if isinstance(obj, dict):
		obj[key] = value
	else:
		setattr(obj, key, value)
