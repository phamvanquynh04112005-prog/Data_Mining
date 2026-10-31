# =============================================================================
# Script setup PostgreSQL Local on Windows for Data Mining Project
# WARNING / CANH BAO BAO MAT:
#   CHỈ DÙNG CHO MÁY CÁ NHÂN CỤC BỘ (FOR LOCAL PERSONAL DEV ENVIRONMENT ONLY).
#   Script nay cau hinh pg_hba.conf o che do 'trust' tren 127.0.0.1/::1 va tao
#   role 'dm' (NOSUPERUSER, CREATEDB) voi mat khau thu nghiem 'dm'.
#   TUYET DOI KHONG chay script nay tren may chu Production!
# Run in PowerShell (Run as Administrator):
#   powershell -ExecutionPolicy Bypass -File sql\setup_local_db.ps1
# =============================================================================

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$pgBin  = "C:\Program Files\PostgreSQL\16\bin"
$pgData = "C:\Program Files\PostgreSQL\16\data"
$pgHba  = Join-Path $pgData "pg_hba.conf"
$psql   = Join-Path $pgBin  "psql.exe"
$pgCtl  = Join-Path $pgBin  "pg_ctl.exe"

if (-not (Test-Path $psql)) {
    $cmd = Get-Command psql -ErrorAction SilentlyContinue
    if ($cmd) {
        $psql = $cmd.Source
        $pgBin = Split-Path -Parent $psql
        $pgCtl = Join-Path $pgBin "pg_ctl.exe"
    } else {
        Write-Error "Cannot find psql.exe. Please install PostgreSQL or add bin directory to PATH."
        exit 1
    }
}

# 1. Add PostgreSQL bin to User PATH if not present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$pgBin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$pgBin", "User")
    Write-Host "[OK] Added $pgBin to User PATH." -ForegroundColor Green
}
$env:Path += ";$pgBin"

# 2. Configure pg_hba.conf for local trust authentication (LOCAL DEV MACHINE ONLY)
if (Test-Path $pgHba) {
    $backupHba = "$pgHba.bak"
    if (-not (Test-Path $backupHba)) {
        Copy-Item $pgHba $backupHba -Force
    }
    $content = Get-Content $pgHba -Raw
    $newContent = $content -replace "scram-sha-256", "trust" -replace "md5", "trust"
    Set-Content -Path $pgHba -Value $newContent -Encoding ASCII
    & $pgCtl reload -D $pgData | Out-Null
    Start-Sleep -Seconds 1
    Write-Host "[OK] Reloaded local authentication config (pg_hba.conf - LOCAL DEV ONLY)." -ForegroundColor Green
} else {
    Write-Warning "Cannot find $pgHba (skipping pg_hba.conf edit)."
}

# 3. Set standard local dev passwords for 'postgres' and 'dm' (NOSUPERUSER, CREATEDB)
Write-Host "[INFO] Setting up role 'dm' (NOSUPERUSER, CREATEDB) for local dev..." -ForegroundColor Cyan
& $psql -U postgres -h localhost -p 5432 -c "ALTER USER postgres WITH PASSWORD 'postgres';"
& $psql -U postgres -h localhost -p 5432 -c "DO `$`$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dm') THEN CREATE ROLE dm WITH LOGIN PASSWORD 'dm' NOSUPERUSER CREATEDB; ELSE ALTER ROLE dm WITH LOGIN PASSWORD 'dm' NOSUPERUSER CREATEDB; END IF; END `$`$;"

# 4. Create database 'dm_course' if not exists
$dbExists = & $psql -U postgres -h localhost -p 5432 -tAc "SELECT 1 FROM pg_database WHERE datname = 'dm_course';"
if ($dbExists -ne "1") {
    & $psql -U postgres -h localhost -p 5432 -c "CREATE DATABASE dm_course OWNER dm ENCODING 'UTF8';"
    Write-Host "[OK] Created database 'dm_course' (Owner: dm)." -ForegroundColor Green
} else {
    Write-Host "[OK] Database 'dm_course' already exists." -ForegroundColor Green
}

& $psql -U postgres -h localhost -p 5432 -d dm_course -c "GRANT ALL PRIVILEGES ON SCHEMA public TO dm;"

# 5. Run 01-staging.sql and 02-star-schema.sql
$env:PGCLIENTENCODING = "UTF8"
Write-Host "[INFO] Running sql/01-staging.sql and sql/02-star-schema.sql..." -ForegroundColor Cyan
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/01-staging.sql"
& $psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/02-star-schema.sql"

Write-Host "`n=== TABLES IN DATABASE dm_course ===" -ForegroundColor Yellow
& $psql -U dm -h localhost -p 5432 -d dm_course -c "\dt"

Write-Host "[DONE] PostgreSQL and Star Schema are ready!" -ForegroundColor Green
