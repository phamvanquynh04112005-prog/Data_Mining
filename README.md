# Đồ án 6 — Phát hiện giao dịch thẻ gian lận (Credit Card Fraud Detection)

> **Câu hỏi kinh doanh trung tâm:** *"Với ngân sách rà soát 100 giao dịch mỗi ngày, ta bắt được bao nhiêu phần trăm gian lận?"*

## Cấu trúc thư mục
```
data/raw/creditcard.csv     <- tự đặt vào (KHÔNG commit; xem outputs/license_evidence.md)
data/processed/transactions_processed.csv <- sinh bởi src/preprocessing.py hoặc 02_preprocessing.ipynb (KHÔNG commit)
src/preprocessing.py        <- Phần B (Cường): Module tiền xử lý & hợp đồng dữ liệu dùng chung
notebooks/
  ├── 01_data_audit.ipynb   <- Phần A (Khang): Audit & chất lượng dữ liệu
  └── 02_preprocessing.ipynb<- Phần B (Cường): Tiền xử lý, biến đổi, kiểm tra rò rỉ & decision log
sql/                        <- Phần C (Quỳnh): PostgreSQL Staging, Star Schema, Transform, OLAP & Superset Views
  ├── setup_local_db.ps1    <- Script khởi tạo DB cục bộ trên Windows (CHỈ DÙNG CHO MÁY CÁ NHÂN)
  ├── 01-staging.sql
  ├── 02-star-schema.sql
  ├── 03-transform.sql
  ├── 04-dashboard-views.sql
  ├── 05-load-model-scores.sql
  ├── olap_queries.sql
  ├── run_warehouse.ps1     <- Runner PowerShell (01 -> 02 -> 03 -> 05)
  ├── run_olap_and_views.ps1<- Runner PowerShell (04 -> olap_queries)
  ├── run_all.sh            <- Runner Bash cho Linux / macOS / WSL
  └── run_pipeline.py       <- Runner Python đa nền tảng + Sinh ảnh ERD PNG 300 DPI
outputs/                    <- data_audit_summary.md, decision_log.csv, processed_data_dictionary.md,
                               star_schema_erd.md, warehouse_validation_report.md,
                               olap_and_handover_summary.md, postgres_execution_log.txt, model_scores_warehouse.csv, ...
figures/                    <- fig01..03 (EDA Phần A), fig04_amount_transform.png (Phần B), fig04_star_schema_erd.png (ERD Phần C)
```

## 1. Chạy lại Phần A (Khang — Dữ liệu & Audit)
```bash
python -m venv .venv && .venv\Scripts\activate      # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
cd notebooks && jupyter lab        # mở 01_data_audit.ipynb → Kernel > Restart & Run All
```
Kết quả đúng khi: `sha256` in ở §1 là `76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89`, shape = `(284807, 31)`, fraud = `492`, và ô cuối in `"OK — checksum raw không đổi"`.

## 1b. Chạy lại Phần B (Cường — Tiền xử lý, Biến đổi, Kiểm tra rò rỉ & Nhật ký quyết định)
```bash
# Cách 1: Sinh nhanh file CSV đã xử lý (data/processed/transactions_processed.csv)
python src/preprocessing.py

# Cách 2: Chạy toàn bộ notebook kèm biểu đồ, kiểm tra rò rỉ và sinh decision_log.csv
cd notebooks && jupyter lab        # mở 02_preprocessing.ipynb → Kernel > Restart & Run All
```
Kết quả đúng khi:
- `data/processed/transactions_processed.csv` có shape = `(284807, 47)`, `sha256 = e8bf7dcde41cb325482455a040154389dd57d7764fa44d72816dbcbe93628958`.
- Tập mô hình sau khi gắn cờ `1,081` bản sao thừa (`in_model_set = 1`) có đúng **`283,726`** dòng, **`473`** gian lận.
- Ô cuối của `02_preprocessing.ipynb` in `"OK — checksum raw không đổi"`, `leakage checks đạt: True` (15/15), `post checks đạt: True`.
- Chi tiết toàn bộ công việc và tiến độ của Phần B xem tại `cuong_work.md`, `outputs/decision_log.csv` và `outputs/processed_data_dictionary.md`.

## 2. Chạy lại Phần C (Quỳnh — Kho dữ liệu PostgreSQL, Star Schema & OLAP)
Yêu cầu: Đã cài đặt **PostgreSQL 16** tại máy local (`localhost:5432`, database `dm_course`, user `dm`) và có file `data/raw/creditcard.csv`.

### Cách 1: Chạy đa nền tảng bằng Python (Windows / macOS / Linux — Tự động sinh ảnh ERD PNG + Chạy 6 file SQL)
```bash
python sql/run_pipeline.py
```

### Cách 2: Chạy trên Windows PowerShell
```powershell
# Bước 1 (tùy chọn - CHỈ DÙNG CHO MÁY CÁ NHÂN CỤC BỘ khi mới cài PostgreSQL lần đầu):
powershell -ExecutionPolicy Bypass -File "sql\setup_local_db.ps1"

# Bước 2: Chạy idempotent 4 script kho dữ liệu (01-staging -> 02-star-schema -> 03-transform -> 05-load-model-scores)
powershell -ExecutionPolicy Bypass -File "sql\run_warehouse.ps1"

# Bước 3: Tạo 6 Dashboard Views cho Apache Superset và thực thi 5 truy vấn OLAP
powershell -ExecutionPolicy Bypass -File "sql\run_olap_and_views.ps1"
```

### Cách 3: Chạy trên Linux / macOS / WSL / Git Bash
```bash
bash sql/run_all.sh
```

Kết quả đúng khi:
- `stg_raw_transactions` và `Fact_Transaction` đều có đúng **`284,807`** dòng, **`492`** gian lận (`0.1727%`).
- Đối soát `DQ-01` (`1,081` bản sao thừa, `283,726` dòng sau khử trùng với `473` gian lận), `DQ-02` (`1,825` dòng `Amount = 0` với `27` gian lận), `DQ-06` (`1,924` dòng có ít nhất 1 cột $V_i$ vượt $|z\text{-score}| > 10$ chứa `231` gian lận) khớp 100% với báo cáo trong `outputs/warehouse_validation_report.md`, `outputs/olap_and_handover_summary.md` và log thực thi `outputs/postgres_execution_log.txt`.
- Chuỗi kết nối cho Apache Superset (Thành viên E — Mong): `postgresql+psycopg2://dm:dm@localhost:5432/dm_course`.
