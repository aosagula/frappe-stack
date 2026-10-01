from frappe.tests import UnitTestCase

from agentic_base.boot import DESK_PROPERTIES, extend_bootinfo, normalize_desk_settings


class TestBootDefaults(UnitTestCase):
	def test_desk_settings_vacio_se_completa(self):
		result = normalize_desk_settings(None)
		self.assertEqual(set(result), set(DESK_PROPERTIES))
		self.assertTrue(all(result[p] == 1 for p in DESK_PROPERTIES))

	def test_respeta_valores_explicitos(self):
		result = normalize_desk_settings({"search_bar": 0, "notifications": 1})
		self.assertEqual(result["search_bar"], 0)
		self.assertEqual(result["notifications"], 1)

	def test_navbar_sin_dropdowns(self):
		boot = {"desk_settings": None, "navbar_settings": {"announcement_widget": ""}}
		extend_bootinfo(boot)
		self.assertEqual(boot["navbar_settings"]["settings_dropdown"], [])
		self.assertEqual(boot["navbar_settings"]["help_dropdown"], [])
		self.assertEqual(boot["desk_settings"]["notifications"], 1)
