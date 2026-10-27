# Đồ án 6 — Phát hiện giao dịch thẻ gian lận · Phần A (Khang): Dữ liệu & Audit

## Cấu trúc
```
data/raw/creditcard.csv     <- tự đặt vào (KHÔNG commit; xem license_evidence.md)
notebooks/01_data_audit.ipynb
outputs/                    <- data_audit_summary.md, data_dictionary.csv, quality_issues.csv, audit_metrics.json, ...
figures/
```
## Chạy lại
```
python -m venv .venv && .venv\Scripts\activate      # Windows  (macOS/Linux: source .venv/bin/activate)
pip install -r requirements.txt
cd notebooks && jupyter lab        # mở 01_data_audit.ipynb → Kernel > Restart & Run All
```
Kết quả đúng khi: `sha256` in ở §1 là `76274b69…98551a89`, shape = (284807, 31), fraud = 492, và ô cuối in "OK — checksum raw không đổi".
Nếu sha256 khác → bạn đang dùng một phiên bản file khác; báo cả nhóm trước khi tiếp tục.
