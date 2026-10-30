# =============================================================================
# Script chay tron bo 3 SQL scripts: 01-staging -> 02-star-schema -> 03-transform
# Cach chay:
#   powershell -ExecutionPolicy Bypass -File "D:\Study\KhaiThacDuLieu\BaoCaoCuoiKy\project\sql\run_warehouse.ps1"
# =============================================================================

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$psql = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
$env:PGCLIENTENCODING = "UTF8"
$env:PGPASSWORD = "dm"

Write-Host "[1/3] Running sql/01-staging.sql (Create Staging & Load creditcard.csv)..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/01-staging.sql"

Write-Host "`n[2/3] Running sql/02-star-schema.sql (Create 4 Dimensions & Fact_Transaction)..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/02-star-schema.sql"

Write-Host "`n[3/3] Running sql/03-transform.sql (Populate Warehouse & Reconcile Counts)..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/03-transform.sql"

Write-Host "`n[DONE] 3 SQL scripts executed successfully from scratch!" -ForegroundColor Green

