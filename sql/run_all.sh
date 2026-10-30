#!/usr/bin/env bash
# =============================================================================
# Cross-platform Bash runner for Linux / macOS / WSL / Git Bash
# Usage from project root:
#   bash sql/run_all.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

export PGCLIENTENCODING="UTF8"
export PGPASSWORD="${PGPASSWORD:-dm}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-dm}"
PGDATABASE="${PGDATABASE:-dm_course}"

echo "[1/6] Running sql/01-staging.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/01-staging.sql"

echo "[2/6] Running sql/02-star-schema.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/02-star-schema.sql"

echo "[3/6] Running sql/03-transform.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/03-transform.sql"

echo "[4/6] Running sql/05-load-model-scores.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/05-load-model-scores.sql"

echo "[5/6] Running sql/04-dashboard-views.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/04-dashboard-views.sql"

echo "[6/6] Running sql/olap_queries.sql..."
psql -U "${PGUSER}" -h "${PGHOST}" -p "${PGPORT}" -d "${PGDATABASE}" -v ON_ERROR_STOP=1 -f "sql/olap_queries.sql"

echo "[DONE] All 6 SQL scripts executed successfully!"

