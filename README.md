# Đồ án 6 — Phát hiện giao dịch thẻ gian lận (Credit Card Fraud Detection)

> **Câu hỏi kinh doanh trung tâm:** *"Với ngân sách rà soát 100 giao dịch mỗi ngày, ta bắt được bao nhiêu phần trăm gian lận?"*

## Cấu trúc thư mục
```
data/raw/creditcard.csv     <- tự đặt vào (KHÔNG commit; xem outputs/license_evidence.md)
notebooks/01_data_audit.ipynb
sql/                        <- Phần C (Quỳnh): PostgreSQL Staging, Star Schema, Transform, OLAP & Superset Views
  ├── setup_local_db.ps1
  ├── 01-staging.sql
  ├── 02-star-schema.sql
  ├── 03-transform.sql
  ├── 04-dashboard-views.sql
  ├── 05-load-model-scores.sql
  ├── olap_queries.sql
  ├── run_warehouse.ps1
  └── run_olap_and_views.ps1
outputs/                    <- data_audit_summary.md, star_schema_erd.md, warehouse_validation_report.md, olap_and_handover_summary.md, ...
figures/                    <- Biểu đồ EDA & Dashboard
```

## 1. Chạy lại Phần A (Khang — Dữ liệu & Audit)
```bash
python -m venv .venv && .venv\Scripts\activate      # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
cd notebooks && jupyter lab        # mở 01_data_audit.ipynb → Kernel > Restart & Run All
```
Kết quả đúng khi: `sha256` in ở §1 là `76274b69…98551a89`, shape = `(284807, 31)`, fraud = `492`, và ô cuối in `"OK — checksum raw không đổi"`.

## 2. Chạy lại Phần C (Quỳnh — Kho dữ liệu PostgreSQL, Star Schema & OLAP)
Yêu cầu: Đã cài đặt **PostgreSQL 16** tại máy local (`localhost:5432`) và có file `data/raw/creditcard.csv`.

```powershell
# Bước 1 (chỉ cần chạy lần đầu): Khởi tạo role 'dm', database 'dm_course' và cấu hình local auth
powershell -ExecutionPolicy Bypass -File "sql\setup_local_db.ps1"

# Bước 2: Chạy idempotent 3 script kho dữ liệu (01-staging -> 02-star-schema -> 03-transform)
powershell -ExecutionPolicy Bypass -File "sql\run_warehouse.ps1"

# Bước 3: Tạo 6 Dashboard Views cho Apache Superset và thực thi 5 truy vấn OLAP
powershell -ExecutionPolicy Bypass -File "sql\run_olap_and_views.ps1"
```
Kết quả đúng khi:
- `stg_raw_transactions` và `Fact_Transaction` đều có đúng **`284,807`** dòng, **`492`** gian lận (`0.1727%`).
- Đối soát `DQ-01` (`1,081` dòng trùng dư ra, `283,726` dòng sau khử trùng), `DQ-02` (`1,825` dòng `Amount = 0`), `DQ-06` (`1,924` dòng có `|V1..V28| > 10` chứa `231` gian lận) khớp 100% với báo cáo trong `outputs/warehouse_validation_report.md` và `outputs/olap_and_handover_summary.md`.
- Chuỗi kết nối cho Apache Superset (Thành viên E — Mong): `postgresql+psycopg2://dm:dm@localhost:5432/dm_course`.
