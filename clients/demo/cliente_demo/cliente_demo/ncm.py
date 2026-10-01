"""Validacion de posicion arancelaria NCM para articulos del cliente demo."""

import re

import frappe
from frappe import _

# 8 digitos (0000.00.00) con sufijo SIM opcional de 3 digitos + letra (.000A)
NCM_PATTERN = re.compile(r"^\d{4}\.\d{2}\.\d{2}(\.\d{3}[A-Z])?$")


def normalize_ncm(value):
	"""Acepta la posicion con o sin puntos y la devuelve con el formato canonico."""
	if not value:
		return value
	raw = re.sub(r"[\s.]", "", value).upper()
	if re.fullmatch(r"\d{8}", raw):
		return f"{raw[:4]}.{raw[4:6]}.{raw[6:8]}"
	if re.fullmatch(r"\d{11}[A-Z]", raw):
		return f"{raw[:4]}.{raw[4:6]}.{raw[6:8]}.{raw[8:12]}"
	return value.strip().upper()


def is_valid_ncm(value):
	return bool(value) and bool(NCM_PATTERN.match(value))


def validate_item(doc, method=None):
	value = doc.get("posicion_ncm")
	if not value:
		return
	normalized = normalize_ncm(value)
	if not is_valid_ncm(normalized):
		frappe.throw(_("Posicion NCM invalida: {0}. Formato esperado 0000.00.00 o 0000.00.00.000A").format(value))
	doc.posicion_ncm = normalized
