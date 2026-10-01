import frappe
from frappe.tests import IntegrationTestCase

from agentic_base.install import ensure_desk_defaults


class TestDeskDefaults(IntegrationTestCase):
	def test_habilita_buscador_y_notificaciones(self):
		email = "desk-defaults@example.com"
		if not frappe.db.exists("User", email):
			frappe.get_doc({"doctype": "User", "email": email, "first_name": "Desk"}).insert(
				ignore_permissions=True
			)
		# Sin roles, Frappe lo guarda como Website User; lo forzamos a System User para la prueba
		frappe.db.set_value(
			"User", email, {"user_type": "System User", "search_bar": 0, "notifications": 0}
		)

		ensure_desk_defaults()

		values = frappe.db.get_value("User", email, ["search_bar", "notifications"], as_dict=True)
		self.assertEqual((values.search_bar, values.notifications), (1, 1))

	def test_hook_registrado(self):
		self.assertIn("agentic_base.boot.extend_bootinfo", frappe.get_hooks("extend_bootinfo"))
