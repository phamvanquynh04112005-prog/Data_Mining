# Đồ án 6: Phát hiện giao dịch thẻ gian lận — Phần E (Mong): Phân lớp có giám sát, Đối sánh hai họ mô hình và Dashboard

- **Người thực hiện:** Mong (Thành viên E — GitHub: `HHoaiMong`)
- **Nhánh làm việc:** `feature/mong-classification-dashboard`
- **Ngày cập nhật:** 2026-10-31
- **Trạng thái tổng thể:**
  - **Đã hoàn thành 100% (E1 → E10, E12):** Đồng bộ giao thức với Cường (B), Quỳnh (C), Huy (D); hoàn thiện và chạy xong `notebooks/04_supervised_classification.ipynb`; lập bảng đối sánh hai họ mô hình (E7, E8); xuất file điểm `outputs/model_scores_warehouse.csv` đúng chuẩn kho PostgreSQL của Quỳnh (E9); dựng và kiểm thử Dashboard Superset 5 biểu đồ + 1 bộ lọc trên dữ liệu CSV từ Notebook (`sql/dashboard_virtual_datasets_mong.sql`).
  - **Phần bàn giao cho Khang (A) làm tiếp (E11, E13, E14):** Nạp kho PostgreSQL `dm_course` của Quỳnh kèm `outputs/model_scores_warehouse.csv`, nối Superset với 6 Views (`sql/04-dashboard-views.sql`), chụp ảnh màn hình Dashboard/SQL Lab lưu vào `figures/` và Export Dashboard (`.zip`). Xem hướng dẫn chi tiết từng bước ở **Mục 6** bên dưới.

---

## 1. Những gì Mong đã làm (Chi tiết từ E1 đến E12)

1. **Dựng môi trường & Kiểm chứng dữ liệu gốc:**
   - Đặt `data/raw/creditcard.csv` (không commit lên Git), kiểm tra `sha256` khớp tuyệt đối với bản audit của Khang (`76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89`): `284.807` dòng × `31` cột, `492` giao dịch gian lận (`0,1727%`).
2. **Thống nhất Schema, Đặc trưng, Khử trùng & Giao thức chia tập (Mục E1):**
   - Đã gộp nhánh của Cường (`origin/feature/cuong-preprocessing`), Quỳnh (`origin/main`) và Huy (`origin/feature/huy-anomaly-detection`) vào nhánh `feature/mong-classification-dashboard`.
   - Chạy `src/preprocessing.py` của Cường để sinh `data/processed/transactions_processed.csv` (`284.807` dòng × `47` cột, `sha256 = e8bf7dcde41cb325482455a040154389dd57d7764fa44d72816dbcbe93628958`).
   - Xác nhận và áp dụng toàn bộ quyết định `D-01` → `D-11` trong `outputs/decision_log.csv`:
     - **Khóa chính (`D-01`):** `txn_id` (`1..284807`, đánh số 1-based theo thứ tự dòng của file gốc).
     - **Khử trùng cho tập mô hình (`D-02`):** Loại `1.081` bản sao thừa hoàn toàn (`is_duplicate = 1`, chứa `19` gian lận), chỉ đưa vào mô hình các dòng `in_model_set == 1` gồm **`283.726` dòng, `473` gian lận** (Ngày 0: `144.236` dòng / `272` gian lận; Ngày 1: `139.490` dòng / `201` gian lận).
     - **Danh sách đặc trưng (`D-07`):** `FEATURES = V1..V28 + amount_log1p` (`29` cột), bỏ `Time` thô. Sử dụng hàm `make_preprocessor(FEATURES)` của Cường (`StandardScaler` chỉ fit trên cột `amount_log1p` của tập train; `V1..V28` giữ nguyên `passthrough`).
     - **Hai giao thức chia tập (`D-06`):**
       1. **Giao thức chính theo ngày (`split_temporal`):** `train` = 80% Ngày 0 phân tầng (`115.388` dòng, `218` gian lận); `val` = 20% Ngày 0 phân tầng (`28.848` dòng, `54` gian lận, ngân sách tỉ lệ `K_VAL = 20`); `test` = Ngày 1 sau khử trùng (`139.490` dòng, `201` gian lận, ngân sách `K = 100` giao dịch/ngày, trần lý thuyết `Recall@100 = 100/201 = 49,75%`).
       2. **Giao thức phụ đối sánh 1-1 với Huy (`split_random`):** Chia `60/20/20` phân tầng (`train`: `170.235` / `284` gian lận; `val`: `56.745` / `94` gian lận; `test`: `56.746` dòng / `95` gian lận, `K = 100`) — khớp tuyệt đối từng dòng `txn_id` với file `outputs/anomaly_scores_test.csv` của Huy.
3. **Xây dựng và thực thi `notebooks/04_supervised_classification.ipynb` (Mục E2 → E8):**
   - **Baseline (E3):** Đoán lớp đa số (`accuracy = 99,86%` trên Ngày 1 nhưng bắt được `0` gian lận) và xếp hạng ngẫu nhiên (`100` lần chạy với `random_state = 42`, lấy trung bình).
   - **Ba mô hình phân lớp có giám sát (E4, E5):** `LogisticRegression`, `RandomForestClassifier`, `HistGradientBoostingClassifier`. Xử lý mất cân bằng bằng `class_weight="balanced"` / `"balanced_subsample"` **chỉ trên tập train**; chọn siêu tham số theo `PR-AUC` trên tập `val`, tuyệt đối không chọn tham số trên `test`.
   - **Đánh giá một lần trên Test Ngày 1 & Phân tích lỗi theo dải số tiền (E6):** Huấn luyện lại trên toàn bộ Ngày 0 (`train + val`: `144.236` dòng, `272` gian lận) với cấu hình tốt nhất trên Validation, chấm điểm trên Ngày 1 (`139.490` dòng, `201` gian lận), phân tích TP/FP/FN và phân rã số giao dịch gian lận bắt được / bỏ sót theo 7 dải `amount_band`.
   - **Đối sánh hai họ mô hình (E7, E8):** So sánh trực tiếp 3 mô hình có giám sát với `Isolation Forest` và `LOF (n_neighbors=100)` của Huy trên cả `split_random` (`56.746` dòng Test) và `split_temporal` (Ngày 1: `139.490` dòng Test).
4. **Xuất các tệp kết quả chuẩn hóa vào `outputs/` (Mục E6, E7, E9):**
   - `outputs/classification_results.csv`: Bảng kết quả Test Ngày 1 (`split_temporal`).
   - `outputs/classification_validation.csv`: Bảng kết quả chọn tham số trên Validation (`split_temporal`).
   - `outputs/model_family_comparison_random_test.csv`: Bảng đối sánh E7.1 trên `split_random` (khớp 1-1 với `anomaly_scores_test.csv` của Huy).
   - `outputs/model_family_comparison_temporal_test.csv`: Bảng đối sánh E7.2 trên Ngày 1 `split_temporal`.
   - `outputs/model_scores_warehouse.csv`: File điểm gồm `139.490` dòng Test Ngày 1 với đúng 6 cột (`txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note`) khớp 100% với script `sql/05-load-model-scores.sql` của Quỳnh.
   - `outputs/classification_scores_test.csv` (~10,6 MB, lưu local để nạp CSV vào Superset, không commit lên Git).
5. **Dựng và kiểm thử Dashboard Apache Superset 6.0.0 trên dữ liệu CSV (Mục E10, E12):**
   - Chạy Superset 6.0.0 qua Docker Compose (`http://localhost:8088`), nạp CSV vào database `examples` (`schema = public`), viết các truy vấn dataset ảo trong `sql/dashboard_virtual_datasets_mong.sql`, dựng Dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** gồm 5 biểu đồ + 1 bộ lọc `Dải số tiền` và đối soát khớp số liệu với Notebook (`93` ca gian lận trong Top 100).

---

## 2. Công cụ & Môi trường đã sử dụng

- **Hệ điều hành & Terminal:** Windows, PowerShell, thư mục làm việc `D:\DA_CK\Data_Mining` và `D:\DA_CK\superset`.
- **Python & Thư viện (trong `.venv`):** Python `3.13.15`, `pandas==3.0.2`, `scikit-learn==1.8.0`, `numpy`, `matplotlib`, `seaborn`, `jupyterlab` (cài từ `requirements.txt`).
- **Quản lý mã nguồn:** Git & GitHub (nhánh `feature/mong-classification-dashboard`).
- **Công cụ BI / Dashboard:** Apache Superset `6.0.0` chạy trên Docker Desktop thông qua file `docker-compose-image-tag.yml` trong repo `apache/superset`.
- **Công cụ AI hỗ trợ:** Claude (Anthropic) và Gemini (Google Antigravity) — chi tiết tại Mục 7.

---

## 3. Kết quả thực nghiệm chính (Tóm tắt từ Notebook 04)

### 3.1. Kết quả phân lớp có giám sát trên Test Ngày 1 (`split_temporal`: 139.490 dòng, 201 gian lận)

| Mô hình | PR-AUC | Precision@100 | Recall@100 | TP (Bắt đúng) | FP (Báo động giả) | FN (Bỏ sót) |
|---|---:|---:|---:|---:|---:|---:|
| **Random Forest** (`n_estimators=200, min_samples_leaf=1`) | **0,7843** | 0,9300 | 0,4627 | 93 | 7 | 108 |
| **Logistic Regression** (`C=1.0`) | 0,7239 | 0,9400 | 0,4677 | 94 | 6 | 107 |
| **HistGradientBoosting** (`max_depth=4, lr=0.1`) | 0,6727 | 0,9500 | 0,4726 | 95 | 5 | 106 |
| **Xếp hạng ngẫu nhiên (TB 100 lần)** | 0,0015 | 0,0015 | 0,0007 | 0,15 | 99,85 | 200,85 |

- **Diễn giải theo câu hỏi nghiệp vụ:** Với ngân sách rà soát tối đa `100` giao dịch/ngày, trần lý thuyết `Recall@100` ở Ngày 1 (sau khử trùng `DQ-01`) là `100 / 201 = 49,75%` (hoặc `100 / 211 = 47,39%` trên dữ liệu thô). Cả 3 mô hình có giám sát bắt được `93–95` giao dịch gian lận trong Top 100, đạt **93%–95% mức trần lý thuyết**. `Random Forest` có `PR-AUC` cao nhất (`0,7843`).
- **Phân tích lỗi của `Random Forest` theo 7 dải số tiền (`amount_band`) trên Ngày 1 (`201` gian lận, bắt `93`, bỏ sót `108`):**
  - Dải `0`: `864` giao dịch, `16` gian lận -> bắt được `6`, bỏ sót `10`.
  - Dải `0-10`: `49.351` giao dịch, `88` gian lận -> bắt được `38`, bỏ sót `50`.
  - Dải `10-50`: `44.807` giao dịch, `28` gian lận -> bắt được `13`, bỏ sót `15`.
  - Dải `50-100`: `17.631` giao dịch, `15` gian lận -> bắt được `11`, bỏ sót `4`.
  - Dải `100-500`: `22.521` giao dịch, `37` gian lận -> bắt được `22`, bỏ sót `15`.
  - Dải `500-1000`: `2.926` giao dịch, `13` gian lận -> bắt được `3`, bỏ sót `10`.
  - Dải `>1000`: `1.390` giao dịch, `4` gian lận -> bắt được `0`, bỏ sót `4` (mẫu quá nhỏ, không kết luận).
  - Các giao dịch gian lận bị bỏ sót có số tiền nhỏ (trung vị `Amount = 7,59`).

### 3.2. Đối sánh hai họ mô hình: Phân lớp có giám sát (E - Mong) vs. Phát hiện bất thường (D - Huy) (Mục E7 & E8)

#### Bảng E7.1 — Đối sánh 1-1 trên tập Test `split_random` (56.746 dòng, 95 gian lận — khớp `outputs/anomaly_scores_test.csv` của Huy)

| Họ mô hình | Mô hình | PR-AUC (AP) | Precision@100 | Recall@100 | TP | FP | FN |
|---|---|---:|---:|---:|---:|---:|---:|
| **Phân lớp có giám sát (Mong - E)** | **Random Forest** | **0,8097** | **0,7700** | **0,8105** | **77** | 23 | 18 |
| Phân lớp có giám sát (Mong - E) | HistGradientBoosting | 0,7683 | 0,7200 | 0,7579 | 72 | 28 | 23 |
| Phân lớp có giám sát (Mong - E) | Logistic Regression | 0,6773 | 0,7400 | 0,7789 | 74 | 26 | 21 |
| **Phát hiện bất thường (Huy - D)** | **LOF (`n_neighbors=100`)** | **0,3125** | **0,3800** | **0,4000** | **38** | 62 | 57 |
| Phát hiện bất thường (Huy - D) | Isolation Forest | 0,1609 | 0,2700 | 0,2842 | 27 | 73 | 68 |
| **Baseline** | Xếp hạng ngẫu nhiên (TB 100 lần) | 0,0019 | 0,0026 | 0,0027 | 0,26 | 99,74 | 94,74 |

#### Bảng E7.2 — Đối sánh trên Ngày 1 `split_temporal` (139.490 dòng, 201 gian lận — ngân sách 100 giao dịch/ngày)

| Họ mô hình | Mô hình | PR-AUC (AP) | Precision@100 | Recall@100 | TP | FP | FN |
|---|---|---:|---:|---:|---:|---:|---:|
| **Phân lớp có giám sát (Mong - E)** | **Random Forest** | **0,7843** | 0,9300 | 0,4627 | 93 | 7 | 108 |
| Phân lớp có giám sát (Mong - E) | Logistic Regression | 0,7239 | 0,9400 | 0,4677 | 94 | 6 | 107 |
| Phân lớp có giám sát (Mong - E) | HistGradientBoosting | 0,6727 | 0,9500 | 0,4726 | 95 | 5 | 106 |
| **Phát hiện bất thường (Cấu hình Huy)** | **LOF (`n_neighbors=100`)** | 0,2478 | 0,3000 | 0,1493 | 30 | 70 | 171 |
| Phát hiện bất thường (Cấu hình Huy) | Isolation Forest | 0,1582 | 0,3100 | 0,1542 | 31 | 69 | 170 |
| **Baseline** | Xếp hạng ngẫu nhiên (TB 100 lần) | 0,0015 | 0,0015 | 0,0007 | 0,15 | 99,85 | 200,85 |

- **Ghi chú bản chất hai họ mô hình (Mục E8):** Mô hình phân lớp có giám sát học trực tiếp biên quyết định từ nhãn lịch sử `is_fraud` nên đạt `Precision@100` và `PR-AUC` cao hơn nhiều đối với các mẫu gian lận đã biết, nhưng trong thực tế nhãn thường đến trễ và dễ bỏ sót kiểu tấn công mới. Ngược lại, `Isolation Forest` và `LOF` không dùng nhãn mà chỉ đo độ hiếm/cô lập hình học nên có nhiều cảnh báo nhầm hơn (`FP` cao hơn), nhưng triển khai được ngay khi chưa có nhãn và giúp phát hiện các dị biệt mới.

---

## 4. Thiết kế Dashboard Apache Superset (5 Biểu đồ & 1 Bộ lọc)

Dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** gồm 5 biểu đồ và 1 bộ lọc:

| # | Tên biểu đồ | Loại biểu đồ | Câu hỏi nghiệp vụ trả lời | Nguồn Dataset CSV (Mong) / View PostgreSQL (Quỳnh) | Số liệu đối soát chuẩn |
|---|---|---|---|---|---|
| **1** | Số giao dịch gian lận bắt được trong top 100 | Big Number | Bắt được bao nhiêu giao dịch gian lận trong ngân sách 100/ngày? | `rf_amount_bands_v2` / `vw_dash_06_model_vs_baseline_comparison` | **93** ca (trên 201 ca sau khử trùng / 211 ca gốc) |
| **2** | Top 100 giao dịch cần rà soát | Table | 100 giao dịch nào cần nhân viên ưu tiên rà soát trong ngày? | `classification_scores_test` / `vw_dash_04_top100_review_queue` | 100 dòng, có **93** dòng `Class = 1` (`is_fraud = 1`) |
| **3** | Phân bố điểm Random Forest theo nhãn thực | Bar Chart (Log scale) | Điểm mô hình có tách biệt được gian lận khỏi hợp lệ không? | `rf_score_bins` / `vw_dash_05_score_distribution` | Tổng số dòng khớp 100% tập Test Ngày 1 |
| **4** | Giao dịch gian lận được bắt và bỏ sót theo dải số tiền | Stacked Bar Chart | Mô hình bắt tốt và bỏ sót nhiều ở dải số tiền nào? | `rf_amount_bands_v2` / `vw_dash_02_amount_band_risk` | Khớp bảng 7 dải tiền ở Notebook 04 §8 (tổng bắt `93`, bỏ sót `108`) |
| **5** | So sánh mô hình: PR-AUC, Precision@100, Recall@100 | Grouped Bar / Table | Mô hình nào xếp hạng tốt hơn baseline và không giám sát? | `classification_results` / `vw_dash_06_model_vs_baseline_comparison` | Khớp bảng kết quả ở Notebook 04 §7 và §9 |

- **Bộ lọc (Filter):** `Dải số tiền` (`dai_amount` / `dai_so_tien`) áp dụng cho biểu đồ 1 và 4.

---

## 5. Cách chạy lại toàn bộ phần Mong đã làm

### 5.1. Chạy lại Tiền xử lý & Notebook 04

Mở PowerShell tại thư mục gốc `Data_Mining` (đảm bảo đã đặt `data/raw/creditcard.csv` đúng `sha256` vào `data/raw/`):

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python src/preprocessing.py
cd notebooks
jupyter lab
```

Trong JupyterLab, mở `notebooks/04_supervised_classification.ipynb`, chọn `Kernel -> Restart Kernel and Run All Cells`. Notebook sẽ tự động kiểm tra checksum, huấn luyện mô hình và sinh lại toàn bộ các file CSV trong `outputs/`.

### 5.2. Chạy lại Apache Superset 6.0.0 bằng Docker Compose

Nếu chưa clone repo Superset, clone về thư mục song song `D:\DA_CK\superset` rồi bật bằng Docker Desktop:

```powershell
cd D:\DA_CK\superset
$env:TAG="6.0.0"
docker compose -f docker-compose-image-tag.yml up -d
```

Truy cập `http://localhost:8088` (tài khoản mặc định: `admin` / `admin`).

---

## 6. BIÊN BẢN BÀN GIAO CHO KHANG (THÀNH VIÊN A) LÀM TIẾP (MỤC E11, E13, E14)

> **Gửi Khang (A):** Toàn bộ phần code, mô hình, bảng đối sánh E7 với Huy và file điểm `outputs/model_scores_warehouse.csv` cho kho của Quỳnh đã được Mong chạy xong và push lên nhánh `feature/mong-classification-dashboard`. Nhờ Khang thực hiện nốt **5 bước ngắn** dưới đây trên máy của Khang để nối Superset với kho PostgreSQL của Quỳnh, chụp ảnh màn hình Dashboard đưa vào `figures/` và tạo Pull Request nhé!

### Bước 1: Lấy nhánh `feature/mong-classification-dashboard` về máy Khang

Đảm bảo trong thư mục `data/raw/` trên máy Khang đã có file `creditcard.csv` (`sha256: 76274b69…98551a89`), sau đó chạy:

```powershell
git fetch origin
git checkout feature/mong-classification-dashboard
git pull origin feature/mong-classification-dashboard
```

### Bước 2: Khởi tạo kho PostgreSQL `dm_course` của Quỳnh và nạp điểm mô hình (`outputs/model_scores_warehouse.csv`)

Mong đã xuất sẵn điểm của cả 3 mô hình (`Isolation Forest`, `LOF`, `Supervised Random Forest`) trên Ngày 1 vào file `outputs/model_scores_warehouse.csv` đúng 6 cột của Quỳnh.

- **Cách A (Nếu máy Khang đã cài PostgreSQL ở cổng `5432`):** Chạy 2 lệnh sau từ thư mục gốc `Data_Mining`:

```powershell
powershell -ExecutionPolicy Bypass -File "sql\setup_local_db.ps1"
python sql/run_pipeline.py
```

- **Cách B (Nếu máy Khang không cài PostgreSQL ngoài Windows mà dùng luôn container `superset_db` của Docker Superset):** Sau khi bật Docker Superset (`docker compose -f docker-compose-image-tag.yml up -d`), chạy khối lệnh sau từ thư mục gốc `Data_Mining` để nạp toàn bộ kho dữ liệu và 6 Views của Quỳnh vào thẳng PostgreSQL trong Docker:

```powershell
docker exec superset_db mkdir -p /tmp/dm_warehouse/data/raw /tmp/dm_warehouse/outputs /tmp/dm_warehouse/sql
docker cp data/raw/creditcard.csv superset_db:/tmp/dm_warehouse/data/raw/creditcard.csv
docker cp outputs/model_scores_warehouse.csv superset_db:/tmp/dm_warehouse/outputs/model_scores_warehouse.csv
docker cp sql/. superset_db:/tmp/dm_warehouse/sql/
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/01-staging.sql
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/02-star-schema.sql
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/03-transform.sql
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/05-load-model-scores.sql
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/04-dashboard-views.sql
docker exec -w /tmp/dm_warehouse superset_db psql -U examples -d examples -v ON_ERROR_STOP=1 -f sql/olap_queries.sql
```

*(Khi chạy xong Bước 2, bảng kiểm tra cuối của `05-load-model-scores.sql` sẽ in ra đúng: `sup_top100_alerts = 100`, `sup_caught_fraud = 93`, `iforest_caught_fraud = 31`, `lof_caught_fraud = 30`).*

### Bước 3: Kết nối Apache Superset với các View trong `sql/04-dashboard-views.sql` (Mục E11, E12)

1. Mở Superset tại `http://localhost:8088` (đăng nhập `admin` / `admin`).
2. Kết nối Database:
   - Nếu dùng **Cách B** ở Bước 2: các bảng và 6 Views (`vw_dash_01` → `vw_dash_06`) đã nằm sẵn ngay trong database **`examples`** (`schema = public`) của Superset, không cần tạo kết nối mới!
   - Nếu dùng **Cách A** (PostgreSQL cài trên Windows): vào **Settings -> Database Connections -> + Database -> PostgreSQL**, nhập SQLAlchemy URI:
     - `postgresql+psycopg2://dm:dm@host.docker.internal:5432/dm_course` (nếu Superset chạy trong Docker)
     - hoặc `postgresql+psycopg2://dm:dm@localhost:5432/dm_course` (nếu Superset chạy trực tiếp trên máy).
3. Vào **Datasets -> + Dataset**, chọn các View `vw_dash_01` đến `vw_dash_06` (và/hoặc chạy các câu SQL trong `sql/dashboard_virtual_datasets_mong.sql` trên SQL Lab rồi bấm **Save dataset**) để hiển thị 5 biểu đồ trên Dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** theo đúng bảng ở **Mục 4** phía trên, kèm 1 bộ lọc (`Dải số tiền` hoặc `Ngày tương đối`).

### Bước 4: Chụp ảnh màn hình và Export Dashboard lưu vào repo (Mục E13, E14)

1. Chụp 3 ảnh màn hình và lưu vào thư mục `figures/`:
   - `figures/fig05_dashboard_overview.png`: Ảnh toàn bộ Dashboard ở trạng thái mặc định (hiển thị rõ 5 biểu đồ và con số `93` giao dịch gian lận bắt được trong Top 100).
   - `figures/fig06_dashboard_filtered.png`: Ảnh toàn bộ Dashboard sau khi chọn bộ lọc (ví dụ lọc dải số tiền `0-10`, số liệu trên biểu đồ tự động thay đổi theo bộ lọc).
   - `figures/fig07_sqllab_reconciliation.png`: Ảnh chạy câu lệnh đối soát trong **SQL Lab** ra đúng `93` giao dịch gian lận trong Top 100 của Random Forest:
     ```sql
     SELECT so_gd_ra_soat, so_fraud_bat_duoc, so_bao_dong_gia_fp, precision_at_100_pct, recall_pct
     FROM vw_dash_06_model_vs_baseline_comparison
     WHERE date_key = 1 AND method_order = 7;
     ```
2. Ở trang danh sách **Dashboards** của Superset, bấm biểu tượng **Export** ở dòng *"Đồ án 6 - Phát hiện gian lận thẻ"* để tải file `.zip` về và lưu tại `outputs/dashboard_export_superset.zip` (kiểm tra file export không chứa mật khẩu).

### Bước 5: Commit, Push lên GitHub và Tạo Pull Request vào `main`

Sau khi đã có ảnh trong `figures/` và file export, chạy lệnh:

```powershell
git add figures/ outputs/ README_E_Mong.md
git commit -m "docs(part-e): add Superset dashboard screenshots and export"
git push origin feature/mong-classification-dashboard
```

Cuối cùng, lên GitHub tạo **Pull Request** từ nhánh `feature/mong-classification-dashboard` vào nhánh `main`. *(Lưu ý: không `git add outputs/classification_scores_test.csv` vì file này nặng 10,6 MB).*

---

## 7. Khai báo sử dụng AI (Tiêu chí 10)

- **Công cụ sử dụng:** Claude (Anthropic) và Gemini (Google Antigravity).
- **Mục đích sử dụng:** Hỗ trợ rà soát sự đồng bộ giao thức giữa các nhánh (`feature/cuong-preprocessing`, `feature/huy-anomaly-detection`, `main`), cấu trúc hóa mã nguồn `notebooks/04_supervised_classification.ipynb`, viết truy vấn SQL cho dataset ảo / đối soát trên Superset và biên tập tài liệu bàn giao `README_E_Mong.md`.
- **Phần do sinh viên kiểm tra và chịu trách nhiệm:** Toàn bộ mã nguồn được thực thi trực tiếp trên dữ liệu thật `creditcard.csv` (`sha256: 76274b69…98551a89`) và `transactions_processed.csv` (`sha256: e8bf7dcd…93628958`) tại máy cá nhân; toàn bộ chỉ số (`PR-AUC`, `Precision@100`, `Recall@100`, phân tích lỗi theo dải tiền) được đối soát khớp giữa Notebook, file CSV và SQL Lab; không tải dữ liệu giao dịch thô lên dịch vụ bên thứ ba.
