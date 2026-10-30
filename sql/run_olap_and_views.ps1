# =============================================================================
# Script chay truy van OLAP (Buoc C10) & Tao 6 Views cho Dashboard Superset (Buoc C11-C12)
# Cach chay:
#   powershell -ExecutionPolicy Bypass -File "D:\Study\KhaiThacDuLieu\BaoCaoCuoiKy\project\sql\run_olap_and_views.ps1"
# =============================================================================

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
$env:PGCLIENTENCODING = "UTF8"
$env:PGPASSWORD = "dm"

Write-Host "[1/2] Running sql/04-dashboard-views.sql (Create 6 Dashboard Views for Superset)..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/04-dashboard-views.sql"

Write-Host "`n=== VIEWS CREATED IN dm_course ===" -ForegroundColor Yellow
& $psql -U dm -h localhost -p 5432 -d dm_course -c "\dv"

Write-Host "`n[2/2] Running sql/olap_queries.sql (Execute 5 OLAP Queries: ROLLUP, CUBE, GROUPING SETS, WINDOW)..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/olap_queries.sql"

Write-Host "`n[DONE] OLAP Queries and Dashboard Views executed successfully!" -ForegroundColor Green

