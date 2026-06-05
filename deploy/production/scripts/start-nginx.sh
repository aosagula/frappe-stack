#!/usr/bin/env bash
set -euo pipefail

export SITE_NAME="${SITE_NAME:-frappe.agentic4biz.com}"
export CLIENT_MAX_BODY_SIZE="${CLIENT_MAX_BODY_SIZE:-50m}"

envsubst '${SITE_NAME} ${CLIENT_MAX_BODY_SIZE}' \
	< /etc/nginx/templates/frappe.conf.template \
	> /etc/nginx/conf.d/default.conf

exec nginx -g "daemon off;"
