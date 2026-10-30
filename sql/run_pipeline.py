#!/usr/bin/env python3
"""
Cross-platform Python runner & Star Schema ERD PNG generator (Part C - Quynh).
Works on Windows, macOS, and Linux.

Usage from project root:
    python sql/run_pipeline.py             # Generates figures/fig04_star_schema_erd.png and runs SQL pipeline
    python sql/run_pipeline.py --erd-only  # Only generates figures/fig04_star_schema_erd.png
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import matplotlib.patches as mpatches
import matplotlib.pyplot as plt


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def generate_erd_png(output_path: Path) -> None:
    """Render a clean 300-DPI Star Schema ERD diagram to figures/fig04_star_schema_erd.png."""
    output_path.parent.mkdir(parents=True, exist_ok=True)

    fig, ax = plt.subplots(figsize=(15, 10), dpi=300)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis("off")

    fig.patch.set_facecolor("#F8FAFC")
    ax.set_facecolor("#F8FAFC")

    ax.text(
        50,
        96.5,
        "STAR SCHEMA ERD — KHO DỮ LIỆU PHÁT HIỆN GIAN LẬN THẺ (ĐỒ ÁN 6 - PHẦN C)",
        ha="center",
        va="center",
        fontsize=14,
        fontweight="bold",
        color="#0F172A",
    )
    ax.text(
        50,
        93.2,
        "Mô hình: 1 Bảng Fact (Fact_Transaction: 284.807 dòng, 492 gian lận) + 4 Bảng Dimension (Dim_Date, Dim_Hour, Dim_AmountBand, Dim_Channel)",
        ha="center",
        va="center",
        fontsize=9.5,
        color="#334155",
    )

    def draw_table_box(x, y, w, h, title, subtitle, rows, header_color="#1E3A8A", border_color="#1E40AF"):
        rect = mpatches.FancyBboxPatch(
            (x, y),
            w,
            h,
            boxstyle="round,pad=0.4,rounding_size=1.2",
            linewidth=1.6,
            edgecolor=border_color,
            facecolor="#FFFFFF",
            zorder=3,
        )
        ax.add_patch(rect)

        header_h = 5.8
        header_rect = mpatches.FancyBboxPatch(
            (x, y + h - header_h),
            w,
            header_h,
            boxstyle="round,pad=0.4,rounding_size=1.2",
            linewidth=1.2,
            edgecolor=border_color,
            facecolor=header_color,
            zorder=4,
        )
        ax.add_patch(header_rect)

        ax.text(
            x + w / 2,
            y + h - 2.1,
            title,
            ha="center",
            va="center",
            fontsize=10.5,
            fontweight="bold",
            color="#FFFFFF",
            zorder=5,
        )
        ax.text(
            x + w / 2,
            y + h - 4.4,
            subtitle,
            ha="center",
            va="center",
            fontsize=7.8,
            color="#E2E8F0",
            zorder=5,
        )

        body_top = y + h - header_h - 1.5
        line_step = (h - header_h - 2.2) / max(len(rows), 1)
        for idx, (col_key, col_name, col_type) in enumerate(rows):
            cy = body_top - idx * line_step
            badge_color = "#B91C1C" if "PK" in col_key else ("#0369A1" if "FK" in col_key else "#64748B")
            if col_key:
                ax.text(
                    x + 1.2,
                    cy,
                    col_key,
                    ha="left",
                    va="center",
                    fontsize=7.3,
                    fontweight="bold",
                    color=badge_color,
                    family="monospace",
                    zorder=5,
                )
            ax.text(
                x + 5.8,
                cy,
                col_name,
                ha="left",
                va="center",
                fontsize=7.7,
                fontweight="bold" if col_key else "normal",
                color="#0F172A",
                family="monospace",
                zorder=5,
            )
            ax.text(
                x + w - 1.2,
                cy,
                col_type,
                ha="right",
                va="center",
                fontsize=7.1,
                color="#475569",
                zorder=5,
            )

    # Center Fact Table
    fact_rows = [
        ("PK", "txn_id", "INT (1..284807)"),
        ("FK", "date_key", "INT -> Dim_Date(0..1)"),
        ("FK", "hour_key", "INT -> Dim_Hour(0..47)"),
        ("FK", "amount_band_key", "INT -> Dim_AmountBand(1..7)"),
        ("FK", "channel_key", "INT -> Dim_Channel(1..3)"),
        ("", "time_sec", "INT NOT NULL (0..172792)"),
        ("", "amount", "NUMERIC(12,2) NOT NULL"),
        ("", "amount_log1p", "NUMERIC(12,6) NOT NULL"),
        ("", "is_zero_amount", "BOOLEAN (DQ-02: 1.825 GD)"),
        ("", "is_duplicate", "BOOLEAN (DQ-01: 1.081 GD)"),
        ("", "dup_group_rank", "INT NOT NULL (>=1)"),
        ("", "max_abs_v", "NUMERIC(12,6) Max|V1..V28|"),
        ("", "has_extreme_v_z10", "BOOLEAN (DQ-06: 1.924 GD)"),
        ("", "is_fraud", "SMALLINT (492 fraud = 0.1727%)"),
        ("", "split_set", "VARCHAR(10) (TRAIN/VAL/TEST)"),
        ("", "iforest_score / _daily_rank", "NUMERIC / INT (Huy - D)"),
        ("", "lof_score / _daily_rank", "NUMERIC / INT (Huy - D)"),
        ("", "sup_prob_score / _daily_rank", "NUMERIC / INT (Mong - E)"),
    ]
    draw_table_box(
        33,
        14,
        34,
        74,
        "Fact_Transaction",
        "FACT TABLE · Grain: 1 dòng = 1 giao dịch (284.807 dòng)",
        fact_rows,
        header_color="#991B1B",
        border_color="#B91C1C",
    )

    # Top-Left: Dim_Date
    dim_date_rows = [
        ("PK", "date_key", "INT (0, 1)"),
        ("", "rel_day_num", "INT NOT NULL (0, 1)"),
        ("", "rel_day_label", "VARCHAR(60) NOT NULL"),
        ("", "start_sec / end_sec", "INT (0..86399 / 86400..172792)"),
        ("", "daily_review_budget", "INT DEFAULT 100"),
        ("", "interpretation_note", "VARCHAR(255) (DQ-05)"),
    ]
    draw_table_box(
        2,
        55,
        26,
        31,
        "Dim_Date",
        "DIMENSION · 2 dòng (Ngày tương đối 0 & 1)",
        dim_date_rows,
        header_color="#1E3A8A",
        border_color="#1D4ED8",
    )

    # Bottom-Left: Dim_Hour
    dim_hour_rows = [
        ("PK", "hour_key", "INT (0..47)"),
        ("FK", "date_key", "INT -> Dim_Date(0..1)"),
        ("", "hour_in_rel_day", "INT (0..23 chu kỳ 24h)"),
        ("", "rel_hour_label", "VARCHAR(60) NOT NULL"),
        ("", "start_sec / end_sec", "INT NOT NULL"),
        ("", "interpretation_note", "VARCHAR(255) (DQ-05)"),
    ]
    draw_table_box(
        2,
        14,
        26,
        31,
        "Dim_Hour",
        "DIMENSION · 48 dòng (Giờ tương đối 0..47)",
        dim_hour_rows,
        header_color="#0F766E",
        border_color="#0D9488",
    )

    # Top-Right: Dim_AmountBand
    dim_band_rows = [
        ("PK", "amount_band_key", "INT (1..7)"),
        ("", "band_code", "0, 0–10, 10–50, 50–100..."),
        ("", "band_label", "VARCHAR(60) NOT NULL"),
        ("", "min_amount / max_amount", "NUMERIC(12,2)"),
        ("", "is_lower / is_upper_inc", "BOOLEAN NOT NULL"),
        ("", "band_order", "INT UNIQUE (1..7)"),
    ]
    draw_table_box(
        72,
        55,
        26,
        31,
        "Dim_AmountBand",
        "DIMENSION · 7 dòng (Khớp 100% EDA Khang A)",
        dim_band_rows,
        header_color="#1E3A8A",
        border_color="#1D4ED8",
    )

    # Bottom-Right: Dim_Channel
    dim_channel_rows = [
        ("PK", "channel_key", "INT (1..3)"),
        ("", "channel_code", "SYNTH_POS / ECOM / ATM"),
        ("", "channel_name", "VARCHAR(80) (MÔ PHỎNG)"),
        ("", "is_synthetic", "BOOLEAN DEFAULT TRUE"),
        ("", "allocation_rule", "MOD(ABS(HASHTEXT), 3)"),
        ("", "warning_note", "VARCHAR(255) (DQ-07)"),
    ]
    draw_table_box(
        72,
        14,
        26,
        31,
        "Dim_Channel (SYNTHETIC)",
        "DIMENSION · 3 dòng (Dữ liệu mô phỏng DQ-07)",
        dim_channel_rows,
        header_color="#6D28D9",
        border_color="#7C3AED",
    )

    # Draw relationship arrows (1 to N)
    arrow_style = dict(arrowstyle="-|>,head_width=0.35,head_length=0.6", lw=1.8, color="#334155")
    ax.annotate("", xy=(33, 73), xytext=(28, 73), arrowprops=arrow_style)
    ax.text(30.5, 74.5, "1 : N\n(date_key)", ha="center", va="bottom", fontsize=7.5, fontweight="bold", color="#1E3A8A")

    ax.annotate("", xy=(33, 30), xytext=(28, 30), arrowprops=arrow_style)
    ax.text(30.5, 31.5, "1 : N\n(hour_key)", ha="center", va="bottom", fontsize=7.5, fontweight="bold", color="#0F766E")

    ax.annotate("", xy=(67, 73), xytext=(72, 73), arrowprops=arrow_style)
    ax.text(69.5, 74.5, "N : 1\n(amount_band_key)", ha="center", va="bottom", fontsize=7.5, fontweight="bold", color="#1E3A8A")

    ax.annotate("", xy=(67, 30), xytext=(72, 30), arrowprops=arrow_style)
    ax.text(69.5, 31.5, "N : 1\n(channel_key)", ha="center", va="bottom", fontsize=7.5, fontweight="bold", color="#6D28D9")

    #Dim_Date -> Dim_Hour hierarchy arrow
    ax.annotate(
        "",
        xy=(15, 45),
        xytext=(15, 55),
        arrowprops=dict(arrowstyle="-|>,head_width=0.3,head_length=0.5", lw=1.3, ls="--", color="#475569"),
    )
    ax.text(15.8, 50, "Phân cấp\n1 Ngày = 24 Giờ", ha="left", va="center", fontsize=7.2, color="#475569")

    ax.text(
        50,
        5.5,
        "Ghi chú học thuật: (1) Dim_Date & Dim_Hour là thời gian tương đối kể từ giao dịch đầu tiên (Time=0s), KHÔNG gán ngày lịch hay ban ngày/ban đêm (DQ-05).\n"
        "(2) Dim_Channel có is_synthetic = TRUE là chiều mô phỏng theo gợi ý đề bài, KHÔNG dùng để huấn luyện mô hình hay kết luận nghiệp vụ thật (DQ-07).\n"
        "(3) Các cột điểm mô hình (iforest_score, lof_score, sup_prob_score) được tách biệt hoàn toàn để không trộn lẫn các thang đo khác nhau.",
        ha="center",
        va="center",
        fontsize=8,
        color="#334155",
        bbox=dict(boxstyle="round,pad=0.5", facecolor="#EFF6FF", edgecolor="#BFDBFE", lw=1),
    )

    plt.tight_layout()
    fig.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"[OK] Saved Star Schema ERD image to: {output_path}")


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

