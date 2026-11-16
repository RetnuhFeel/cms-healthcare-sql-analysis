#!/usr/bin/env bash
# Build the whole database from the sample CSVs and run every analysis query.
# Connection settings come from the usual libpq variables (PGHOST, PGPORT,
# PGUSER, PGPASSWORD, PGDATABASE).
#
#   ./scripts/build.sh            # schema + load + clean + checks + views + analysis
#   ./scripts/build.sh --no-analysis
set -euo pipefail
cd "$(dirname "$0")/.."

export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
PSQL=(psql -X -q -v ON_ERROR_STOP=1)
run() { echo "==> $1"; "${PSQL[@]}" -f "$1"; }

run sql/01_schema/01_staging.sql
"${PSQL[@]}" -f scripts/load_staging.sql
run sql/01_schema/02_core.sql
for f in sql/02_cleaning/*.sql; do run "$f"; done
"${PSQL[@]}" -c "ANALYZE;"
for f in sql/03_quality/*.sql; do run "$f"; done
for f in sql/04_views/*.sql;   do run "$f"; done

if [[ "${1:-}" != "--no-analysis" ]]; then
  python3 scripts/run_analysis.py
fi
echo "Build complete."
