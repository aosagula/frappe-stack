"""Tests de contrato de la API v1.

Fijan lo que las apps externas dan por sentado: nombres de campos, tipos, paginacion,
permisos y que los metodos sigan expuestos. Si alguno falla, una app movil en produccion
se romperia: el cambio va a v2 o se corrige, pero no se mergea asi.
"""

import frappe
from frappe.tests import IntegrationTestCase

from cliente_demo.api.v1 import articulos

CONTRATO_ITEM = {"codigo": str, "nombre": str, "ncm": (str, type(None)), "unidad": str, "habilitado": bool}


def _preparar_maestros():
	if not frappe.db.exists("UOM", "Unidad"):
		frappe.get_doc({"doctype": "UOM", "uom_name": "Unidad"}).insert(ignore_permissions=True)
	if not frappe.db.exists("Item Group", "Todos los articulos"):
		frappe.get_doc(
			{"doctype": "Item Group", "item_group_name": "Todos los articulos", "is_group": 1}
		).insert(ignore_permissions=True)
	if not frappe.db.exists("Item Group", "API Test"):
		frappe.get_doc(
			{
				"doctype": "Item Group",
				"item_group_name": "API Test",
				"parent_item_group": "Todos los articulos",
			}
		).insert(ignore_permissions=True)
	for codigo, nombre, ncm in (
		("API-001", "Notebook 14", "84713012"),
		("API-002", "Monitor 24", "8528.52.20"),
		("API-003", "Cable sin NCM", None),
	):
		if not frappe.db.exists("Item", codigo):
			frappe.get_doc(
				{
					"doctype": "Item",
					"item_code": codigo,
					"item_name": nombre,
					"item_group": "API Test",
					"stock_uom": "Unidad",
					"is_stock_item": 0,
					"posicion_ncm": ncm,
				}
			).insert(ignore_permissions=True)


class TestApiV1Articulos(IntegrationTestCase):
	@classmethod
	def setUpClass(cls):
		super().setUpClass()
		_preparar_maestros()

	def assertContratoItem(self, item):
		self.assertEqual(set(item), set(CONTRATO_ITEM), "Cambiaron los campos del contrato v1")
		for campo, tipo in CONTRATO_ITEM.items():
			self.assertIsInstance(item[campo], tipo, f"Tipo de '{campo}' fuera de contrato")

	def test_metodos_expuestos_solo_por_get(self):
		for metodo in (articulos.listar, articulos.obtener):
			self.assertIn(metodo, frappe.whitelisted)
			self.assertNotIn(metodo, frappe.guest_methods, "La API v1 no debe ser publica")
			self.assertEqual(frappe.allowed_http_methods_for_whitelisted_func.get(metodo), ["GET"])

	def test_listar_forma_de_respuesta(self):
		res = articulos.listar(buscar="API-")
		self.assertEqual(set(res), {"version", "items", "desde", "limite"})
		self.assertEqual(res["version"], "1")
		self.assertGreaterEqual(len(res["items"]), 3)
		for item in res["items"]:
			self.assertContratoItem(item)

	def test_ncm_normalizado_y_nulo(self):
		por_codigo = {i["codigo"]: i for i in articulos.listar(buscar="API-")["items"]}
		self.assertEqual(por_codigo["API-001"]["ncm"], "8471.30.12")
		self.assertIsNone(por_codigo["API-003"]["ncm"])

	def test_filtro_por_ncm(self):
		codigos = [i["codigo"] for i in articulos.listar(ncm="8528")["items"]]
		self.assertEqual(codigos, ["API-002"])

	def test_paginacion_y_limite_maximo(self):
		pagina = articulos.listar(buscar="API-", limite=1, desde=1)
		self.assertEqual([i["codigo"] for i in pagina["items"]], ["API-002"])
		self.assertEqual(articulos.listar(limite=10_000)["limite"], articulos.LIMITE_MAXIMO)

	def test_obtener(self):
		res = articulos.obtener("API-002")
		self.assertEqual(set(res), {"version", "item"})
		self.assertContratoItem(res["item"])
		self.assertEqual(res["item"]["nombre"], "Monitor 24")

	def test_obtener_inexistente(self):
		with self.assertRaises(frappe.DoesNotExistError):
			articulos.obtener("NO-EXISTE")

	def test_respeta_permisos(self):
		frappe.set_user("Guest")
		try:
			with self.assertRaises(frappe.PermissionError):
				articulos.obtener("API-001")
			with self.assertRaises(frappe.PermissionError):
				articulos.listar(buscar="API-")
		finally:
			frappe.set_user("Administrator")
