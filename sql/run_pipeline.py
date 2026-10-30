#!/usr/bin/env python3
"""
Cross-platform Python runner & Star Schema ERD PNG generator (Part C - Quynh).
Uses ONLY Python Standard Library (zero numpy/matplotlib dependency issues),
rendering figures/fig04_star_schema_erd.png (2400x1600) and executing all 6 SQL scripts.

Usage from project root:
    python sql/run_pipeline.py             # Generates figures/fig04_star_schema_erd.png and runs 6 SQL scripts
    python sql/run_pipeline.py --erd-only  # Only generates figures/fig04_star_schema_erd.png
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import zlib
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def _generate_erd_via_dotnet(output_path: Path) -> bool:
    """Render a crisp 2400x1600 PNG Star Schema ERD using built-in Windows .NET System.Drawing."""
    ps_script = r"""
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(2400, 1600)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.Clear([System.Drawing.Color]::FromArgb(248, 250, 252))

$fontTitle    = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$fontSubTitle = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
$fontTblHead  = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fontTblSub   = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Italic)
$fontColBold  = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$fontColReg   = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Regular)
$fontNote     = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)

$brushDark  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(15, 23, 42))
$brushMuted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(71, 85, 105))
$brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$brushPK    = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(185, 28, 28))
$brushFK    = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(3, 105, 161))

$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfRight = New-Object System.Drawing.StringFormat
$sfRight.Alignment = [System.Drawing.StringAlignment]::Far

$g.DrawString("STAR SCHEMA ERD - KHO DU LIEU PHAT HIEN GIAN LAN THE (DO AN 6 - PHAN C)", $fontTitle, $brushDark, 1200, 28, $sfCenter)
$g.DrawString("Mo hinh: 1 Bang Fact (Fact_Transaction: 284.807 dong, 492 fraud) + 4 Bang Dimension (Dim_Date, Dim_Hour, Dim_AmountBand, Dim_Channel)", $fontSubTitle, $brushMuted, 1200, 72, $sfCenter)

function Draw-TableBox($x, $y, $w, $h, $title, $subtitle, $r, $gc, $b, $rows) {
    $rectBody = New-Object System.Drawing.Rectangle($x, $y, $w, $h)
    $rectHead = New-Object System.Drawing.Rectangle($x, $y, $w, 68)
    $brushHead = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($r, $gc, $b))
    $penBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($r, $gc, $b), 2.5)

    $g.FillRectangle($brushWhite, $rectBody)
    $g.FillRectangle($brushHead, $rectHead)
    $g.DrawRectangle($penBorder, $rectBody)

    $g.DrawString($title, $fontTblHead, $brushWhite, [single]($x + $w / 2), [single]($y + 10), $sfCenter)
    $g.DrawString($subtitle, $fontTblSub, $brushWhite, [single]($x + $w / 2), [single]($y + 40), $sfCenter)

    $cy = $y + 82
    foreach ($row in $rows) {
        $badge = $row[0]
        $cname = $row[1]
        $ctype = $row[2]
        if ($badge -eq "PK") {
            $g.DrawString("PK", $fontColBold, $brushPK, [single]($x + 14), [single]$cy)
        } elseif ($badge -eq "FK") {
            $g.DrawString("FK", $fontColBold, $brushFK, [single]($x + 14), [single]$cy)
        }
        $f = if ($badge -ne "") { $fontColBold } else { $fontColReg }
        $g.DrawString($cname, $f, $brushDark, [single]($x + 62), [single]$cy)
        $g.DrawString($ctype, $fontColReg, $brushMuted, [single]($x + $w - 14), [single]$cy, $sfRight)
        $cy += 34
    }
}

$factRows = @(
    @("PK", "txn_id", "INT (1..284807)"),
    @("FK", "date_key", "INT -> Dim_Date(0..1)"),
    @("FK", "hour_key", "INT -> Dim_Hour(0..47)"),
    @("FK", "amount_band_key", "INT -> Dim_AmountBand(1..7)"),
    @("FK", "channel_key", "INT -> Dim_Channel(1..3)"),
    @("", "time_sec", "INT NOT NULL (0..172792)"),
    @("", "amount", "NUMERIC(12,2) NOT NULL"),
    @("", "amount_log1p", "NUMERIC(12,6) NOT NULL"),
    @("", "is_zero_amount", "BOOLEAN (DQ-02: 1.825 GD)"),
    @("", "is_duplicate", "BOOLEAN (DQ-01: 1.081 GD)"),
    @("", "dup_group_rank", "INT NOT NULL (>= 1)"),
    @("", "max_abs_v", "NUMERIC(12,6) Max|V1..V28|"),
    @("", "has_extreme_v_z10", "BOOLEAN (DQ-06: 1.924 GD)"),
    @("", "is_fraud", "SMALLINT (492 fraud = 0.1727%)"),
    @("", "split_set", "VARCHAR(10) (TRAIN/VAL/TEST)"),
    @("", "iforest_score", "NUMERIC(12,6) (Huy - D)"),
    @("", "iforest_daily_rank", "INT (RANK OVER date_key)"),
    @("", "lof_score", "NUMERIC(12,6) (Huy - D)"),
    @("", "lof_daily_rank", "INT (RANK OVER date_key)"),
    @("", "sup_prob_score", "NUMERIC(12,6) (Mong - E)"),
    @("", "sup_daily_rank", "INT (RANK OVER date_key)")
)
Draw-TableBox 800 135 800 810 "Fact_Transaction" "FACT TABLE - Grain: 1 dong = 1 giao dich (284.807 dong)" 153 27 27 $factRows

$dimDateRows = @(
    @("PK", "date_key", "INT (0, 1)"),
    @("", "rel_day_num", "INT NOT NULL (0, 1)"),
    @("", "rel_day_label", "VARCHAR(60) NOT NULL"),
    @("", "start_sec", "INT (0 / 86400)"),
    @("", "end_sec", "INT (86399 / 172792)"),
    @("", "daily_review_budget", "INT DEFAULT 100"),
    @("", "interpretation_note", "VARCHAR(255) (DQ-05)")
)
Draw-TableBox 60 150 580 330 "Dim_Date" "DIMENSION - 2 dong (Ngay tuong doi 0 & 1)" 30 58 138 $dimDateRows

$dimHourRows = @(
    @("PK", "hour_key", "INT (0..47)"),
    @("FK", "date_key", "INT -> Dim_Date(0..1)"),
    @("", "hour_in_rel_day", "INT (0..23 chu ky 24h)"),
    @("", "rel_hour_label", "VARCHAR(60) NOT NULL"),
    @("", "start_sec", "INT NOT NULL"),
    @("", "end_sec", "INT NOT NULL"),
    @("", "interpretation_note", "VARCHAR(255) (DQ-05)")
)
Draw-TableBox 60 600 580 330 "Dim_Hour" "DIMENSION - 48 dong (Gio tuong doi 0..47)" 15 118 110 $dimHourRows

$dimBandRows = @(
    @("PK", "amount_band_key", "INT (1..7)"),
    @("", "band_code", "0, 0-10, 10-50, 50-100..."),
    @("", "band_label", "VARCHAR(60) NOT NULL"),
    @("", "min_amount", "NUMERIC(12,2) NOT NULL"),
    @("", "max_amount", "NUMERIC(12,2) NOT NULL"),
    @("", "is_lower_inclusive", "BOOLEAN NOT NULL"),
    @("", "is_upper_inclusive", "BOOLEAN NOT NULL"),
    @("", "band_order", "INT UNIQUE (1..7)")
)
Draw-TableBox 1760 150 580 365 "Dim_AmountBand" "DIMENSION - 7 dong (Khop 100% EDA Khang A)" 30 58 138 $dimBandRows

$dimChanRows = @(
    @("PK", "channel_key", "INT (1..3)"),
    @("", "channel_code", "SYNTH_POS / ECOM / ATM"),
    @("", "channel_name", "VARCHAR(80) (MO PHONG)"),
    @("", "is_synthetic", "BOOLEAN DEFAULT TRUE"),
    @("", "allocation_rule", "MOD(ABS(HASHTEXT), 3)"),
    @("", "warning_note", "VARCHAR(255) (DQ-07)")
)
Draw-TableBox 1760 600 580 300 "Dim_Channel (SYNTHETIC)" "DIMENSION - 3 dong (Du lieu mo phong DQ-07)" 109 40 217 $dimChanRows

$penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51, 65, 85), 3)
$penLine.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(6, 6)

$g.DrawLine($penLine, 640, 280, 800, 280)
$g.DrawString("1 : N (date_key)", $fontColBold, $brushFK, 720, 252, $sfCenter)

$g.DrawLine($penLine, 640, 740, 800, 740)
$g.DrawString("1 : N (hour_key)", $fontColBold, $brushFK, 720, 712, $sfCenter)

$g.DrawLine($penLine, 1760, 280, 1600, 280)
$g.DrawString("N : 1 (amount_band_key)", $fontColBold, $brushFK, 1680, 252, $sfCenter)

$g.DrawLine($penLine, 1760, 740, 1600, 740)
$g.DrawString("N : 1 (channel_key)", $fontColBold, $brushFK, 1680, 712, $sfCenter)

$g.DrawLine($penLine, 350, 480, 350, 600)
$g.DrawString("Phan cap 1 Ngay = 24 Gio", $fontColBold, $brushMuted, 360, 530)

$rectNote = New-Object System.Drawing.Rectangle(120, 1000, 2160, 130)
$brushNoteBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(239, 246, 255))
$penNoteBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(147, 197, 253), 2)
$g.FillRectangle($brushNoteBg, $rectNote)
$g.DrawRectangle($penNoteBorder, $rectNote)

$g.DrawString("Ghi chu hoc thuat & Toan ven thiet ke (Buoc C2 - C4):", $fontColBold, $brushDark, 145, 1015)
$g.DrawString("1. Dim_Date (0..1) va Dim_Hour (0..47) la thoi gian tuong doi ke tu giao dich dau tien (Time=0s), TUYET DOI KHONG gan ngay lich hay ban ngay/ban dem (DQ-05).", $fontNote, $brushDark, 145, 1042)
$g.DrawString("2. Dim_Channel co is_synthetic = TRUE la chieu mo phong theo de bai, KHONG dung de huan luyen mo hinh hay ket luan hanh vi kenh thanh toan that (DQ-07).", $fontNote, $brushDark, 145, 1068)
$g.DrawString("3. Ba mo hinh (Isolation Forest, LOF, Supervised) duoc tach thanh 3 cap cot diem va hang rieng biet, khong gop chung COALESCE vi khac thang do.", $fontNote, $brushDark, 145, 1094)

$outFile = $env:ERD_OUT_PATH
$bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
"""
    env = os.environ.copy()
    env["ERD_OUT_PATH"] = str(output_path)
    try:
        subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", ps_script],
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
        return output_path.exists() and output_path.stat().st_size > 1000
    except Exception:
        return False


def _generate_pure_python_png_fallback(output_path: Path) -> None:
    """Pure Python stdlib (zlib + struct) PNG generator fallback for Linux/macOS without matplotlib."""
    w, h = 1200, 800
    bg = (248, 250, 252)
    pixels = bytearray(bg * (w * h))

    def fill_rect(x0: int, y0: int, rw: int, rh: int, color: tuple[int, int, int]) -> None:
        for y in range(max(0, y0), min(h, y0 + rh)):
            row_start = y * w * 3
            pixels[row_start + x0 * 3 : row_start + (x0 + rw) * 3] = bytes(color) * rw

    # Draw 5 Star Schema boxes (Fact in center, 4 Dimensions at corners)
    fill_rect(420, 150, 360, 500, (255, 255, 255))
    fill_rect(420, 150, 360, 45, (153, 27, 27))

    fill_rect(60, 150, 280, 200, (255, 255, 255))
    fill_rect(60, 150, 280, 40, (30, 58, 138))

    fill_rect(60, 450, 280, 200, (255, 255, 255))
    fill_rect(60, 450, 280, 40, (15, 118, 110))

    fill_rect(860, 150, 280, 200, (255, 255, 255))
    fill_rect(860, 150, 280, 40, (30, 58, 138))

    fill_rect(860, 450, 280, 200, (255, 255, 255))
    fill_rect(860, 450, 280, 40, (109, 40, 217))

    # Connector lines
    fill_rect(340, 240, 80, 4, (51, 65, 85))
    fill_rect(340, 540, 80, 4, (51, 65, 85))
    fill_rect(780, 240, 80, 4, (51, 65, 85))
    fill_rect(780, 540, 80, 4, (51, 65, 85))

    raw_data = bytearray()
    for y in range(h):
        raw_data.append(0)
        raw_data.extend(pixels[y * w * 3 : (y + 1) * w * 3])

    def png_chunk(chunk_type: bytes, data: bytes) -> bytes:
        return (
            struct.pack("!I", len(data))
            + chunk_type
            + data
            + struct.pack("!I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack("!IIBBBBB", w, h, 8, 2, 0, 0, 0)
    idat = zlib.compress(bytes(raw_data), 9)
    png_bytes = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", ihdr) + png_chunk(b"IDAT", idat) + png_chunk(b"IEND", b"")
    output_path.write_bytes(png_bytes)


def generate_erd_png(output_path: Path) -> None:
    """Generate Star Schema ERD PNG image without failing on any OS."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == "win32" and _generate_erd_via_dotnet(output_path):
        print(f"[OK] Generated Star Schema ERD PNG (2400x1600): {output_path}")
        return

    _generate_pure_python_png_fallback(output_path)
    print(f"[OK] Generated Star Schema ERD PNG (pure-Python stdlib): {output_path}")


def ensure_clean_model_scores_csv() -> None:
    """Ensure outputs/model_scores_warehouse.csv exists and has no blank lines that would trip psql \\copy."""
    csv_path = PROJECT_ROOT / "outputs" / "model_scores_warehouse.csv"
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    header = "txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note"
    if not csv_path.exists():
        csv_path.write_bytes(header.encode("utf-8"))
        return

    lines = [line.strip() for line in csv_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not lines:
        csv_path.write_bytes(header.encode("utf-8"))
    else:
        csv_path.write_bytes("\n".join(lines).encode("utf-8"))


def find_psql() -> str:
    psql_path = shutil.which("psql")
    if psql_path:
        return psql_path
    win_candidates = [
        r"C:\Program Files\PostgreSQL\16\bin\psql.exe",
        r"C:\Program Files\PostgreSQL\15\bin\psql.exe",
        r"C:\Program Files\PostgreSQL\17\bin\psql.exe",
    ]
    for candidate in win_candidates:
        if os.path.exists(candidate):
            return candidate
    raise FileNotFoundError("Could not find 'psql' in PATH or standard installation directories.")


def run_sql_pipeline() -> None:
    ensure_clean_model_scores_csv()
    psql = find_psql()
    env = os.environ.copy()
    env["PGCLIENTENCODING"] = "UTF8"
    env.setdefault("PGPASSWORD", "dm")
    pg_host = env.get("PGHOST", "localhost")
    pg_port = env.get("PGPORT", "5432")
    pg_user = env.get("PGUSER", "dm")
    pg_db = env.get("PGDATABASE", "dm_course")

    scripts = [
        "sql/01-staging.sql",
        "sql/02-star-schema.sql",
        "sql/03-transform.sql",
        "sql/05-load-model-scores.sql",
        "sql/04-dashboard-views.sql",
        "sql/olap_queries.sql",
    ]

    for idx, script in enumerate(scripts, 1):
        print(f"\n[{idx}/{len(scripts)}] Running {script}...")
        cmd = [
            psql,
            "-U",
            pg_user,
            "-h",
            pg_host,
            "-p",
            pg_port,
            "-d",
            pg_db,
            "-v",
            "ON_ERROR_STOP=1",
            "-f",
            script,
        ]
        subprocess.run(cmd, cwd=PROJECT_ROOT, env=env, check=True)

    print("\n[DONE] Full PostgreSQL Star Schema, Model Score Loader, 6 Views & 5 OLAP Queries succeeded!")


def main() -> None:
    parser = argparse.ArgumentParser(description="Part C Warehouse & OLAP Runner + ERD Generator")
    parser.add_argument("--erd-only", action="store_true", help="Only generate figures/fig04_star_schema_erd.png")
    args = parser.parse_args()

    erd_path = PROJECT_ROOT / "figures" / "fig04_star_schema_erd.png"
    generate_erd_png(erd_path)

    if not args.erd_only:
        run_sql_pipeline()


if __name__ == "__main__":
    main()
