# =============================================================================
# Script chay Tao 6 Views cho Dashboard Superset (Buoc C11-C12) & 5 Truy van OLAP (Buoc C10)
# Cach chay:
#   powershell -ExecutionPolicy Bypass -File "sql\run_olap_and_views.ps1"
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

Write-Host "[1/2] Running sql/04-dashboard-views.sql (Create 6 Dashboard Views for Superset)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/04-dashboard-views.sql"

Write-Host "`n=== VIEWS CREATED IN $pgDb ===" -ForegroundColor Yellow
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -c "\dv"

Write-Host "`n[2/2] Running sql/olap_queries.sql (Execute 5 OLAP Queries: ROLLUP, CUBE, GROUPING SETS, WINDOW)..." -ForegroundColor Cyan
& $psql -U $pgUser -h $pgHost -p $pgPort -d $pgDb -v ON_ERROR_STOP=1 -f "sql/olap_queries.sql"

Write-Host "`n[DONE] OLAP Queries and Dashboard Views executed successfully!" -ForegroundColor Green
