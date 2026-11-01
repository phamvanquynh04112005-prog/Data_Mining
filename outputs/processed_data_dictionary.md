# Data dictionary — dữ liệu đã xử lý (schema v1.0)
File: `data/processed/transactions_processed.csv` · 284,807 dòng × 47 cột · sha256 `e8bf7dcde41cb325482455a040154389dd57d7764fa44d72816dbcbe93628958`  
Sinh tự động bởi `notebooks/02_preprocessing.ipynb` ngày 2026-10-30. Logic: `src/preprocessing.py`. Grain: **1 dòng = 1 giao dịch** (giống raw).

| Cột | Kiểu | Định nghĩa | Quyết định | Giới hạn / lưu ý |
|---|---|---|---|---|
| `txn_id` | int64 | Khoá giao dịch = số thứ tự dòng trong creditcard.csv (1-based) | D-01 | Ổn định khi raw có sha256 đã audit |
| `time_sec` | int64 | Time gốc (giây kể từ giao dịch đầu tiên), ép int | D-05 | KHÔNG phải timestamp |
| `rel_day` | int64 | time_sec // 86400 → 0/1 | D-05 | Ranh giới 86 400 s là giả định |
| `rel_hour` | int64 | time_sec // 3600 → 0..47 | D-05 | Giờ kể từ giao dịch đầu, không phải giờ đồng hồ |
| `hour_of_cycle` | int64 | rel_hour % 24 → 0..23 | D-05 | Chu kỳ 24h tương đối; KHÔNG gọi là giờ trong ngày |
| `hour_cycle_sin` | float64 | sin(2π·(time_sec mod 86400)/86400) | D-07 | Chỉ dùng nếu thử biến thể FEATURES_WITH_CYCLE trên val |
| `hour_cycle_cos` | float64 | cos(2π·(time_sec mod 86400)/86400) | D-07 | như trên |
| `amount` | float64 | Amount gốc, không sửa | D-03/D-04 | Không rõ đơn vị tiền |
| `amount_log1p` | float64 | log(1 + amount); không cần fit | D-04 | Chuẩn hoá thêm trong pipeline (fit trên train) |
| `amount_band_id` | int64 | 0..6 theo ranh giới (−∞,0],(0,10],(10,50],(50,100],(100,500],(500,1000],(1000,∞) | D-08 | Cùng ranh giới với audit của Khang |
| `amount_band` | string | Nhãn dải: 0, 0-10, 10-50, 50-100, 100-500, 500-1000, >1000 | D-08 | Dùng cho Dim_AmountBand/dashboard |
| `is_zero_amount` | int64 | 1 nếu amount = 0 | D-03 | Ý nghĩa Amount=0 không được nguồn giải thích |
| `V1…V28` | float64 | Thành phần PCA gốc, không sửa | D-07 | Không gán ý nghĩa nghiệp vụ |
| `is_fraud` | int64 | Nhãn = Class gốc (1 gian lận, 0 còn lại) | — | CHỈ để đánh giá/học có giám sát; không bao giờ là feature |
| `is_duplicate` | int64 | 1 nếu là bản sao thừa (trùng cả 31 cột với một dòng trước) | D-02 | Bị loại khỏi tập mô hình |
| `dup_of_txn_id` | int64 | txn_id của bản được giữ trong nhóm trùng (dòng không trùng = chính nó) | D-02 | Để kho dữ liệu truy vết |
| `in_model_set` | int64 | 1 − is_duplicate | D-02 | Lọc tập dùng cho mô hình |
| `split_temporal` | string | train / val / test / excluded_duplicate (test = rel_day 1; train/val = rel_day 0 phân tầng 80/20) | D-06 | Giao thức CHÍNH đề xuất |
| `split_random` | string | train / val / test / excluded_duplicate (phân tầng 60/20/20) | D-06 | Giao thức PHỤ |
| `cv_fold` | int64 | 0..4 = fold phân tầng trên train+val của split_random; −1 = không thuộc | D-06 | Báo độ dao động |

**Bộ đặc trưng mặc định (`P.FEATURES`, 29 cột):** `V1…V28`, `amount_log1p`. Nhãn: `is_fraud`.
**Biến đổi có học (chỉ fit trên train/fold):** `P.make_preprocessor()` = StandardScaler cho `amount_log1p`, V* passthrough (tuỳ chọn `scale_v=True`).

---

## Hướng dẫn sử dụng cho các thành viên nhận bàn giao

### 1. Cho Quỳnh (C — PostgreSQL, Star Schema, OLAP)
- Tạo file CSV đã xử lý (nếu chưa có trên máy): `python src/preprocessing.py` → sinh `data/processed/transactions_processed.csv` (284,807 dòng × 47 cột).
- File giữ **đủ 284,807 dòng** (không xoá bản sao) để đối soát 1–1 với `creditcard.csv` (tổng `is_fraud = 492`, tổng `amount = 25,162,590.01`).
- Khoá chính của `Fact_Transaction`: `txn_id` (1..284,807).
- Các trường dimension có sẵn trong file:
  - `Dim_Date` (ngày tương đối): `rel_day` (0 hoặc 1, giả định 86,400 giây/ngày). **Không** tạo ngày lịch thật.
  - `Dim_Hour` (giờ tương đối): `rel_hour` (0..47) và `hour_of_cycle` (0..23 — chu kỳ 24h tương đối, không phải giờ đồng hồ).
  - `Dim_AmountBand`: `amount_band_id` (0..6) và `amount_band` (`0`, `0-10`, `10-50`, `50-100`, `100-500`, `500-1000`, `>1000`).
- Khi viết truy vấn OLAP, ghi rõ truy vấn đang đếm trên toàn bộ 284,807 dòng hay tập mô hình đã khử trùng (`WHERE in_model_set = 1`, 283,726 dòng, 473 fraud).

### 2. Cho Huy (D — Anomaly Detection) và Mong (E — Supervised Classification)
```python
import sys
sys.path.insert(0, "../src")
import preprocessing as P

df = P.load_processed("../data/processed/transactions_processed.csv")

# Giao thức CHÍNH (temporal: train/val ở rel_day=0, test ở rel_day=1)
X_train, y_train, id_train = P.get_split(df, protocol="temporal", part="train")
X_val,   y_val,   id_val   = P.get_split(df, protocol="temporal", part="val")
X_test,  y_test,  id_test  = P.get_split(df, protocol="temporal", part="test")

# Chuẩn hoá: CHỈ fit trên X_train
pre = P.make_preprocessor()          # StandardScaler cho amount_log1p, giữ nguyên V1..V28
Z_train = pre.fit_transform(X_train)
Z_val   = pre.transform(X_val)
Z_test  = pre.transform(X_test)
```
- **Lưu ý cho Huy (Isolation Forest & LOF):**
  - Không truyền `y_train` vào `.fit()` của mô hình không giám sát; chỉ dùng `y_val` để chọn tham số và `y_test` ở bước đánh giá cuối.
  - Theo quyết định `D-11`, trong tập mô hình có các nhóm giao dịch trùng `V1..V28 + Amount` nhưng khác `Time` (nhóm lớn nhất 77 dòng, đều là non-fraud). Khi chạy LOF, nên thử `n_neighbors > 77` (ví dụ 80 hoặc 100) trên tập validation để tránh khoảng cách k-láng giềng bằng 0, hoặc ghi nhận hiện tượng này trong báo cáo.
  - Khi xuất `outputs/anomaly_scores_test.csv`, giữ cột `txn_id` để Quỳnh/Mong join vào PostgreSQL và Superset.

---

## Biên bản bàn giao (theo mẫu G — `File_Train.docx`)
- **Người bàn giao:** Cường (Thành viên B)
- **Người nhận:** Khang (A), Quỳnh (C), Huy (D), Mong (E)
- **Ngày/phiên bản:** 2026-10-30 / Schema v1.0
- **Tên file/đường dẫn:**
  - `src/preprocessing.py`
  - `notebooks/02_preprocessing.ipynb`
  - `data/processed/transactions_processed.csv` (sha256: `e8bf7dcde41cb325482455a040154389dd57d7764fa44d72816dbcbe93628958`)
  - `outputs/decision_log.csv` (11 quyết định `D-01` → `D-11`)
  - `outputs/processed_data_dictionary.md`, `outputs/processed_schema.json`, `outputs/preprocessing_checks.json`
  - `figures/fig04_amount_transform.png`
- **Mục đích của đầu ra:** Cung cấp dữ liệu đã làm sạch/biến đổi, quy tắc chia tập cố định (`random_state=42`), pipeline chuẩn hoá chống rò rỉ dữ liệu và nhật ký quyết định có bằng chứng.
- **Đầu vào được dùng:** `data/raw/creditcard.csv` (sha256 `76274b69…98551a89`) và bộ kết quả audit của Khang (`outputs/audit_metrics.json`, `outputs/quality_issues.csv`, `outputs/data_dictionary.csv`).
- **Cách tái tạo:** Chạy `python src/preprocessing.py` hoặc mở `notebooks/02_preprocessing.ipynb` → Restart & Run All.
- **Các kiểm tra đã chạy và kết quả:** 15/15 kiểm tra chống rò rỉ (`leakage_checks`) = `True`; toàn bộ kiểm tra hậu xử lý (`post_checks_all_ok`) = `True`; round-trip đọc/ghi CSV khớp tuyệt đối (`roundtrip_equal = True`); sha256 file raw trước và sau khi chạy không đổi.
- **Trạng thái:** Đã kiểm chứng.
