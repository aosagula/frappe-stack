"""Endpoints de articulos (v1).

GET /api/method/cliente_demo.api.v1.articulos.listar?buscar=&ncm=&limite=20&desde=0
GET /api/method/cliente_demo.api.v1.articulos.obtener?codigo=ART-001

Respuesta de un articulo:
	{"codigo": str, "nombre": str, "ncm": str | null, "unidad": str, "habilitado": bool}
"""

import frappe
from frappe import _

LIMITE_MAXIMO = 100


def _a_contrato(row):
	"""Traduce el registro interno de ERPNext al contrato publico (aisla a la app de cambios internos)."""
	return {
		"codigo": row.name,
		"nombre": row.item_name,
		"ncm": row.posicion_ncm or None,
		"unidad": row.stock_uom,
		"habilitado": not row.disabled,
	}


_CAMPOS = ["name", "item_name", "posicion_ncm", "stock_uom", "disabled"]


@frappe.whitelist(methods=["GET"])
def listar(buscar=None, ncm=None, limite=20, desde=0):
	limite = min(max(int(limite), 1), LIMITE_MAXIMO)
	desde = max(int(desde), 0)

	filtros = {}
	if ncm:
		filtros["posicion_ncm"] = ["like", f"{ncm}%"]
	or_filtros = None
	if buscar:
		or_filtros = {"name": ["like", f"%{buscar}%"], "item_name": ["like", f"%{buscar}%"]}

	# get_list respeta los permisos del usuario que llama
	rows = frappe.get_list(
		"Item",
		fields=_CAMPOS,
		filters=filtros,
		or_filters=or_filtros,
		order_by="name asc",
		limit_start=desde,
		limit_page_length=limite,
	)
	return {"version": "1", "items": [_a_contrato(frappe._dict(r)) for r in rows], "desde": desde, "limite": limite}


@frappe.whitelist(methods=["GET"])
def obtener(codigo):
	if not frappe.db.exists("Item", codigo):
		frappe.throw(_("Articulo {0} no encontrado").format(codigo), frappe.DoesNotExistError)
	doc = frappe.get_doc("Item", codigo)
	doc.check_permission("read")
	return {"version": "1", "item": _a_contrato(frappe._dict({f: doc.get(f) for f in _CAMPOS}))}
