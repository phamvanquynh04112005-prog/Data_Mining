# =============================================================================
# Script chay tron bo 4 SQL scripts kho du lieu:
#   01-staging -> 02-star-schema -> 03-transform -> 05-load-model-scores
# Cach chay:
#   powershell -ExecutionPolicy Bypass -File "sql\run_warehouse.ps1"
# =============================================================================

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$cmd = Get-Command psql -ErrorAction SilentlyContinue
if ($cmd) {
    $psql = $cmd.Source
} elseif (Test-Path "C:\Program Files\PostgreSQL\16\bin\psql.exe") {
    $psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
} else {
    Write-Error "Cannot find psql executable. Please add PostgreSQL bin to PATH."
    exit 1
}

$env:PGCLIENTENCODING = "UTF8"
if (-not $env:PGPASSWORD) { $env:PGPASSWORD = "dm" }
$pgHost = if ($env:PGHOST) { $env:PGHOST } else { "localhost" }
$pgPort = if ($env:PGPORT) { $env:PGPORT } else { "5432" }
$pgUser = if ($env:PGUSER) { $env:PGUSER } else { "dm" }
$pgDb   = if ($env:PGDATABASE) { $env:PGDATABASE } else { "dm_course" }

Write-Host "[1/4] Running sql/01-staging.sql (Create Staging & Load creditcard.csv)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/01-staging.sql"

Write-Host "`n[2/4] Running sql/02-star-schema.sql (Create 4 Dimensions & Fact_Transaction)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/02-star-schema.sql"

Write-Host "`n[3/4] Running sql/03-transform.sql (Populate Warehouse & Reconcile Counts)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/03-transform.sql"

Write-Host "`n[4/4] Running sql/05-load-model-scores.sql (Load Model Scores & Update Ranks)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/05-load-model-scores.sql"

Write-Host "`n[DONE] Warehouse pipeline (01 -> 02 -> 03 -> 05) executed successfully!" -ForegroundColor Green
