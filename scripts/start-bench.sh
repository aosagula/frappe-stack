#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="${FRAPPE_BENCH_DIR:-/workspace/frappe-bench}"

if [ ! -d "$BENCH_DIR/env" ]; then
  echo "Bench is not initialized. Run: docker compose --profile setup run --rm init" >&2
  exit 1
fi

cd "$BENCH_DIR"
exec bench start
