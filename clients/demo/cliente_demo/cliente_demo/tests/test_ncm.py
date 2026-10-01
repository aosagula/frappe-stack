import frappe
from frappe.tests import IntegrationTestCase, UnitTestCase

from cliente_demo.ncm import is_valid_ncm, normalize_ncm, validate_item


class TestNcmUnit(UnitTestCase):
	def test_normaliza_sin_puntos(self):
		self.assertEqual(normalize_ncm("84713012"), "8471.30.12")
		self.assertEqual(normalize_ncm("8471.30.12.100z"), "8471.30.12.100Z")

	def test_formatos(self):
		self.assertTrue(is_valid_ncm("8471.30.12"))
		self.assertTrue(is_valid_ncm("8471.30.12.100Z"))
		self.assertFalse(is_valid_ncm("8471.30"))
		self.assertFalse(is_valid_ncm("ABCD.30.12"))

	def test_validate_normaliza_en_el_doc(self):
		doc = frappe._dict(posicion_ncm="84713012")
		validate_item(doc)
		self.assertEqual(doc.posicion_ncm, "8471.30.12")

	def test_validate_rechaza_invalida(self):
		with self.assertRaises(frappe.ValidationError):
			validate_item(frappe._dict(posicion_ncm="12.34"))


class TestNcmInstalacion(IntegrationTestCase):
	def test_campo_instalado_por_fixture(self):
		self.assertTrue(frappe.db.exists("Custom Field", "Item-posicion_ncm"))

	def test_hook_registrado_en_item(self):
		hooks = frappe.get_hooks("doc_events").get("Item", {}).get("validate", [])
		self.assertIn("cliente_demo.ncm.validate_item", hooks)
