import frappe


def after_install():
	ensure_desk_defaults()


def after_migrate():
	ensure_desk_defaults()


def ensure_desk_defaults():
	"""Habilita buscador y notificaciones a los usuarios de sistema que los tengan apagados.

	Reemplaza el patch `set_default_desk_settings` que estaba en el fork de Frappe.
	Es idempotente: se puede correr en cada migrate.
	"""
	columns = set(frappe.db.get_table_columns("User"))
	if not {"search_bar", "notifications"} <= columns:
		return

	frappe.db.sql(
		"""UPDATE `tabUser`
		SET search_bar = 1, notifications = 1
		WHERE user_type = 'System User'
		AND (search_bar IS NULL OR search_bar = 0 OR notifications IS NULL OR notifications = 0)"""
	)
