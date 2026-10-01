#!/usr/bin/env bash
# Regla de la plataforma: las apps propias no pisan codigo del core en runtime.
# Detecta asignaciones del estilo `frappe.algo = ...` o `erpnext.modulo.funcion = ...` (monkey patching).
# Se permiten frappe.local / frappe.flags / frappe.response, que son estado de request, no codigo.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

hits="$(grep -rnE '^\s*(frappe|erpnext|hrms|crm|helpdesk)(\.[A-Za-z_][A-Za-z0-9_]*)+\s*=[^=]' \
	--include='*.py' "$ROOT/apps" "$ROOT/clients" \
	| grep -vE '(frappe\.(local|flags|response|form_dict|request)\b)' || true)"

if [ -n "$hits" ]; then
	echo "Monkey patching detectado (usar hooks u override_doctype_class):" >&2
	echo "$hits" >&2
	exit 1
fi
echo "OK: sin monkey patches"
