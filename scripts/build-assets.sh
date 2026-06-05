#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${FRAPPE_BENCH_DIR:-/workspace/frappe-bench}"

for app in frappe erpnext crm telephony helpdesk; do
  git config --global --add safe.directory "/workspace/apps/${app}" || true
  git config --global --add safe.directory "/workspace/apps/${app}/.git" || true
done

if [ -d /workspace/sites ] && [ -z "$(find /workspace/sites -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  rmdir /workspace/sites
fi

ln -sfn "${BENCH_DIR}/sites" /workspace/sites

cd "$BENCH_DIR"
bench build
