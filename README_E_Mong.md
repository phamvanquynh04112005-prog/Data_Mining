# Đồ án 6: Phát hiện giao dịch thẻ gian lận — Phần E (Mong): Phân lớp có giám sát, Đối sánh hai họ mô hình và Dashboard

- **Người thực hiện:** Mong (Thành viên E — GitHub: `HHoaiMong`) & Khang (Thành viên A — Phối hợp hoàn tất E11, E13, E14)
- **Nhánh làm việc:** `feature/mong-classification-dashboard`
- **Ngày cập nhật:** 2026-11-07
- **Trạng thái tổng thể:**
  - **ĐÃ HOÀN THÀNH 100% (E1 → E14 & Đã rà soát/bổ sung toàn bộ 6 mục theo mẫu báo cáo mới `report-template.md`):**
    - **E1 → E10, E12 (Mong):** Đồng bộ giao thức với Cường (B), Quỳnh (C), Huy (D); hoàn thiện và chạy lại sạch từ đầu `notebooks/04_supervised_classification.ipynb` (chọn `top_model` nghiêm ngặt trên tập Validation, bổ sung **5-Fold Stratified CV `mean ± sd`** tại Mục 9B cho Bảng 8 Mục 7.2, xuất biểu đồ phân tích lỗi `figures/fig05_error_analysis_by_amount_band.png` và bảng ví dụ giao dịch FP/FN cụ thể `outputs/error_examples_fp_fn_day1.csv` cho Mục 7.3); xuất file điểm `outputs/model_scores_warehouse.csv` đúng chuẩn kho PostgreSQL của Quỳnh (E9).
    - **E11, E13, E14 & Nâng cấp Dashboard (Mong & Khang):** Đã khởi chạy container PostgreSQL 16 (`superset_db`) và Apache Superset 6.0.0 (`superset_app`), thực thi trọn vẹn 6 script SQL của Quỳnh (`01-staging.sql` → `02-star-schema.sql` → `03-transform.sql` → `05-load-model-scores.sql` → `04-dashboard-views.sql` → `olap_queries.sql`); nâng cấp toàn bộ Dataset ảo của Dashboard (`sql/dashboard_virtual_datasets_mong.sql` và `dashboard/dashboard_export_superset.zip`) đọc trực tiếp 100% từ **Star Schema & Views PostgreSQL** (`Fact_Transaction`, `Dim_AmountBand`, `vw_dash_04_top100_review_queue`, `vw_dash_06_model_vs_baseline_comparison`), đưa cả **2 họ mô hình (`Supervised` + `Isolation Forest` + `LOF`) & Baseline** lên biểu đồ so sánh, hiển thị giờ tương đối (`rel_hour_label`) thay cho giây thô `Time`, thống nhất mẫu số `201` gian lận Ngày 1 đã khử trùng, và lưu trọn bộ đóng gói vào thư mục gốc `dashboard/` theo Phụ lục B của `report-template.md`.

---

## 1. Những gì đã thực hiện (Chi tiết từ E1 đến E14 & Bổ sung theo `report-template.md`)

1. **Dựng môi trường & Kiểm chứng dữ liệu gốc:**
   - Đặt `data/raw/creditcard.csv` (không commit lên Git), kiểm tra `sha256` khớp tuyệt đối với bản audit của Khang (`76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89`): `284.807` dòng × `31` cột, `492` giao dịch gian lận (`0,1727%`).
2. **Thống nhất Schema, Đặc trưng, Khử trùng & Ba tầng giao thức đánh giá (Mục E1):**
   - Đã gộp nhánh của Cường (`origin/feature/cuong-preprocessing`), Quỳnh (`origin/main`) và Huy (`origin/feature/huy-anomaly-detection`) vào nhánh `feature/mong-classification-dashboard`.
   - Chạy `src/preprocessing.py` của Cường để sinh `data/processed/transactions_processed.csv` (`284.807` dòng × `47` cột, `sha256 = e8bf7dcde41cb325482455a040154389dd57d7764fa44d72816dbcbe93628958`).
   - Áp dụng toàn bộ quyết định `D-01` → `D-11` trong `outputs/decision_log.csv`:
     - **Khóa chính (`D-01`):** `txn_id` (`1..284807`, đánh số 1-based theo thứ tự dòng của file gốc).
     - **Khử trùng cho tập mô hình (`D-02`):** Loại `1.081` bản sao thừa hoàn toàn (`is_duplicate = 1`, chứa `19` gian lận), chỉ đưa vào mô hình các dòng `in_model_set == 1` gồm **`283.726` dòng, `473` gian lận** (Ngày 0: `144.236` dòng / `272` gian lận; Ngày 1: `139.490` dòng / `201` gian lận).
     - **Danh sách đặc trưng (`D-07`):** `FEATURES = V1..V28 + amount_log1p` (`29` cột), bỏ `Time` thô. Sử dụng hàm `make_preprocessor(FEATURES)` của Cường (`StandardScaler` chỉ fit trên cột `amount_log1p` của tập train; `V1..V28` giữ nguyên `passthrough`).
     - **Ba tầng giao thức đánh giá (`D-06` & Bảng 8 Mục 7.2 `report-template.md`):**
       1. **Giao thức chính theo ngày (`split_temporal`):** `train` = 80% Ngày 0 phân tầng (`115.388` dòng, `218` gian lận); `val` = 20% Ngày 0 phân tầng (`28.848` dòng, `54` gian lận, ngân sách tỉ lệ `K_VAL = 20`); `test` = Ngày 1 sau khử trùng (`139.490` dòng, `201` gian lận, ngân sách `K = 100` giao dịch/ngày, trần lý thuyết `Recall@100 = 100/201 = 49,75%`).
       2. **Giao thức phụ đối sánh 1-1 với Huy (`split_random`):** Chia `60/20/20` phân tầng (`train`: `170.235` / `284` gian lận; `val`: `56.745` / `94` gian lận; `test`: `56.746` dòng / `95` gian lận, `K = 100`) — khớp tuyệt đối từng dòng `txn_id` với file `outputs/anomaly_scores_test.csv` của Huy.
       3. **Đánh giá độ dao động qua 5-Fold Stratified CV (`cv_fold = 0..4`):** Đánh giá `mean ± sd` qua 5 fold phân tầng trên `226.980` giao dịch phát triển mô hình (~`45.396` giao dịch và `75–76` gian lận mỗi fold, ngưỡng `K = 100`) cho cả 3 mô hình có giám sát, 2 mô hình phát hiện bất thường và 3 baseline.
3. **Xây dựng và thực thi `notebooks/04_supervised_classification.ipynb` (Mục E2 → E9B):**
   - **Baseline (E3):** Đoán lớp đa số (`accuracy = 99,86%` trên Ngày 1 nhưng bắt được `0` gian lận) và xếp hạng ngẫu nhiên (`100` lần chạy với `random_state = 42`, lấy trung bình).
   - **Ba mô hình phân lớp có giám sát (E4, E5):** `LogisticRegression`, `RandomForestClassifier`, `HistGradientBoostingClassifier`. Xử lý mất cân bằng bằng `class_weight="balanced"` / `"balanced_subsample"` **chỉ trên tập train**; chọn siêu tham số và chọn `top_model` (`random_forest`, Validation `PR-AUC = 0,8703`) hoàn toàn theo `PR-AUC` trên tập `val`, tuyệt đối không chọn theo `test`.
   - **Phân tích lỗi chuyên sâu trên Test Ngày 1 & Hình 5 (E6 & Mục 7.3):** Xuất biểu đồ 300 DPI `figures/fig05_error_analysis_by_amount_band.png` (gồm phân rã bắt được vs. bỏ sót theo 7 dải tiền và boxplot phân bố xác suất giữa TP `n=93`, FP `n=7`, FN `n=108` tại ngưỡng cắt `p = 0,705`) cùng bảng 6 giao dịch FP/FN cụ thể kèm điểm của cả 2 họ mô hình (`outputs/error_examples_fp_fn_day1.csv`).
   - **Đối sánh hai họ mô hình & 5-Fold Stratified CV (E7, E8 & Mục 9B):** Đối sánh đầy đủ trên `split_random`, `split_temporal` và `cv_fold` (`outputs/cv_5fold_spread_summary.csv`).
4. **Danh mục các tệp kết quả chuẩn hóa trong `outputs/`, `figures/` và `dashboard/`:**
   - `outputs/classification_results.csv` & `outputs/classification_validation.csv`: Kết quả Test Ngày 1 và Validation (`split_temporal`).
   - `outputs/model_family_comparison_random_test.csv` & `outputs/model_family_comparison_temporal_test.csv`: Bảng đối sánh hai họ mô hình (E7.1, E7.2).
   - `outputs/cv_5fold_spread_summary.csv` & `outputs/cv_5fold_per_fold_details.csv`: Bảng `mean ± sd` qua 5-fold Stratified CV (Bảng 8 Mục 7.2).
   - `outputs/error_analysis_by_amount_band.csv` & `outputs/error_examples_fp_fn_day1.csv`: Bảng phân rã lỗi theo dải tiền và 6 ca FP/FN cụ thể (Mục 7.3).
   - `figures/fig05_error_analysis_by_amount_band.png`: Hình 5 phân tích lỗi (Mục 7.3).
   - `outputs/model_scores_warehouse.csv`: File điểm `139.490` dòng Test Ngày 1 chuẩn 6 cột cho script `sql/05-load-model-scores.sql` của Quỳnh.
   - `dashboard/dashboard_export_superset.zip`, `dashboard/fig05_dashboard_overview.png`, `dashboard/fig06_dashboard_filtered.png`, `dashboard/fig07_sqllab_reconciliation.png`: Trọn bộ đóng gói Dashboard theo Phụ lục B (đồng thời lưu bản sao tại `outputs/` và `figures/`).

---

## 2. Công cụ & Môi trường đã sử dụng

- **Hệ điều hành & Terminal:** Windows, PowerShell, thư mục làm việc `D:\DA_CK\Data_Mining` và `D:\DA_CK\superset`.
- **Python & Thư viện (trong `.venv`):** Python `3.13.15`, `pandas==3.0.2`, `scikit-learn==1.8.0`, `numpy`, `matplotlib`, `seaborn`, `jupyterlab` (cài từ `requirements.txt`).
- **Quản lý mã nguồn:** Git & GitHub (nhánh `feature/mong-classification-dashboard`).
- **Kho dữ liệu & Công cụ BI:** PostgreSQL `16` (`superset_db`) + Apache Superset `6.0.0` (`superset_app`) chạy trên Docker Compose.
- **Công cụ AI hỗ trợ:** Claude (Anthropic) và Gemini (Google Antigravity) — chi tiết tại Mục 7.

---

## 3. Kết quả thực nghiệm chính (Tóm tắt từ Notebook 04)

### 3.1. Kết quả phân lớp có giám sát trên Test Ngày 1 (`split_temporal`: 139.490 dòng, 201 gian lận)

| Mô hình | Val PR-AUC (`K_VAL=20`) | Test PR-AUC | Precision@100 | Recall@100 | TP (Bắt đúng) | FP (Báo động giả) | FN (Bỏ sót) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Random Forest** (`n_estimators=200, min_samples_leaf=1`) — *Chọn từ Val* | **0,8703** | **0,7843** | 0,9300 | 0,4627 | 93 | 7 | 108 |
| **Logistic Regression** (`C=1.0`) | 0,7627 | 0,7239 | 0,9400 | 0,4677 | 94 | 6 | 107 |
| **HistGradientBoosting** (`max_depth=4, lr=0.1`) | 0,8030 | 0,6727 | 0,9500 | 0,4726 | 95 | 5 | 106 |
| **Xếp hạng ngẫu nhiên (TB 100 lần)** | 0,0023 | 0,0015 | 0,0015 | 0,0007 | 0,15 | 99,85 | 200,85 |

- **Diễn giải theo câu hỏi nghiệp vụ:** Với ngân sách rà soát tối đa `100` giao dịch/ngày, trần lý thuyết `Recall@100` ở Ngày 1 (sau khử trùng `DQ-01`) là `100 / 201 = 49,75%` (hoặc `100 / 211 = 47,39%` trước khử trùng). Cả 3 mô hình có giám sát bắt được **`93–95` giao dịch gian lận** trong Top 100 (`Recall@100 = 46,3% – 47,3%`), đạt **~93% – 95% mức trần lý thuyết**. `Random Forest` được chọn làm mô hình chính nhờ `PR-AUC` cao nhất trên Validation (`0,8703`) và tiếp tục dẫn đầu về `PR-AUC` trên Test Ngày 1 (`0,7843`).

### 3.2. Độ dao động (`mean ± sd`) qua 5-Fold Stratified CV (`cv_fold = 0..4`, 226.980 dòng — Phục vụ Bảng 8 Mục 7.2)

| Họ mô hình | Mô hình | PR-AUC (`mean ± sd`) | Precision@100 (`mean ± sd`) | Recall@100 (`mean ± sd`) |
|---|---|---:|---:|---:|
| **Phân lớp có giám sát (Mong - E)** | **Random Forest** | **0,8415 ± 0,0329** | **65,00% ± 2,35%** | **85,97% ± 2,78%** |
| Phân lớp có giám sát (Mong - E) | HistGradientBoosting | 0,7700 ± 0,0361 | 62,80% ± 1,92% | 83,06% ± 2,23% |
| Phân lớp có giám sát (Mong - E) | Logistic Regression | 0,7354 ± 0,0419 | 62,40% ± 3,85% | 82,54% ± 4,97% |
| **Phát hiện bất thường (Huy - D)** | **LOF (`n_neighbors=100`)** | **0,4480 ± 0,0649** | **47,20% ± 2,59%** | **62,44% ± 3,42%** |
| Phát hiện bất thường (Huy - D) | Isolation Forest | 0,1843 ± 0,0409 | 23,60% ± 5,27% | 31,19% ± 6,80% |
| **Baseline** | Heuristic `Max(\|V1..V28\|)` | 0,0920 ± 0,0131 | 16,60% ± 3,21% | 21,94% ± 4,11% |
| Baseline | Luật Top-100 `Amount` lớn nhất | 0,0021 ± 0,0004 | 0,20% ± 0,45% | 0,26% ± 0,59% |
| Baseline | Xếp hạng ngẫu nhiên | 0,0018 ± 0,0001 | 0,14% ± 0,07% | 0,19% ± 0,09% |

*(Lưu ý: Mỗi fold kiểm định chứa ~`45.396` giao dịch với `75–76` gian lận, do đó tại `K = 100` trần lý thuyết của `Precision@100` trên mỗi fold là `~75,6%`; `Random Forest` bắt trung bình `65,0 ± 2,35` trên `75,6` ca gian lận mỗi fold, tức `Recall@100 = 85,97% ± 2,78%` với độ lệch chuẩn thấp).*

### 3.3. Phân tích lỗi theo dải số tiền & Ví dụ giao dịch FP / FN cụ thể trên Ngày 1 (Phục vụ Mục 7.3 & Hình 5)

- **Biểu đồ Hình 5:** `figures/fig05_error_analysis_by_amount_band.png`
- **Phân rã `Random Forest` theo 7 dải số tiền (`outputs/error_analysis_by_amount_band.csv`):**
  - Dải `0`: `864` GD, `16` gian lận -> bắt `6` (`37,5%`), bỏ sót `10`.
  - Dải `0-10`: `49.351` GD, `88` gian lận -> bắt `38` (`43,2%`), bỏ sót `50` *(tập trung nhiều giao dịch thử thẻ "card-testing" nhỏ lẻ)*.
  - Dải `10-50`: `44.807` GD, `28` gian lận -> bắt `13` (`46,4%`), bỏ sót `15`.
  - Dải `50-100`: `17.631` GD, `15` gian lận -> bắt `11` (`73,3%`), bỏ sót `4`.
  - Dải `100-500`: `22.521` GD, `37` gian lận -> bắt `22` (`59,5%`), bỏ sót `15`.
  - Dải `500-1000`: `2.926` GD, `13` gian lận -> bắt `3` (`23,1%`), bỏ sót `10`.
  - Dải `>1000`: `1.390` GD, `4` gian lận -> bắt `0` (`0,0%`), bỏ sót `4` (cỡ mẫu gian lận quá nhỏ).
- **Ví dụ giao dịch cụ thể bị cảnh báo nhầm (FP) và bị bỏ sót (FN) (`outputs/error_examples_fp_fn_day1.csv`):**
  - **Ca FP điển hình:** `txn_id = 149865` (Giờ tương đối `25`, `Amount = 1,00`, dải `0-10`, hạng `#28`, `sup_prob_score = 0,9250`, `lof_score = 2,0768`) và `txn_id = 163770` (Giờ tương đối `32`, `Amount = 19,99`, dải `10-50`, hạng `#58`, `sup_prob_score = 0,8600`, `lof_score = 3,9965`) — giao dịch hợp pháp nhưng mang tổ hợp PCA giống mẫu thử thẻ nên cả hai họ mô hình đều chấm điểm rủi ro cao.
  - **Ca FN điển hình:** `txn_id = 237108` (Giờ tương đối `41`, `Amount = 0,00`, gian lận xác thực thẻ `0` đồng, đạt `sup_prob_score = 0,7050` ở hạng `#101` — bị loại sát nút ngay dưới ngưỡng cắt ngân sách `K = 100`) và `txn_id = 176050` (Giờ tương đối `34`, `Amount = 2.125,87`, dải `>1000`, `sup_prob_score = 0,0000`, `lof_score = -0,2423` — gian lận giá trị lớn nhưng nằm sâu trong vùng mật độ giao dịch bình thường trên không gian `V1..V28`).

### 3.4. Đối sánh hai họ mô hình trên `split_random` & `split_temporal` (Mục E7 & E8)

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

---

## 4. Thiết kế Dashboard Apache Superset (Đọc trực tiếp từ Kho dữ liệu PostgreSQL Star Schema)

Dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** gồm 5 biểu đồ và 1 bộ lọc, toàn bộ truy vấn định nghĩa tại `sql/dashboard_virtual_datasets_mong.sql` và đóng gói tại `dashboard/dashboard_export_superset.zip`:

| # | Tên biểu đồ | Loại biểu đồ | Câu hỏi nghiệp vụ trả lời | Bảng / View Kho PostgreSQL (Quỳnh - C) | Số liệu đối soát chuẩn |
|---|---|---|---|---|---|
| **1** | Số giao dịch gian lận bắt được trong Top 100 | Big Number | Bắt được bao nhiêu giao dịch gian lận trong ngân sách 100/ngày? | `Fact_Transaction` JOIN `Dim_AmountBand` | **93** ca trên **201** gian lận Ngày 1 đã khử trùng (`38` ca khi lọc dải `2) 0-10`) |
| **2** | Top 100 giao dịch cần rà soát (Random Forest — Ngày 1) | Table | 100 giao dịch nào cần ưu tiên rà soát, thuộc khung giờ tương đối nào? | `vw_dash_04_top100_review_queue` | 100 dòng hiển thị `rel_hour_label` (`Dim_Hour`), có **93** dòng `Gian lận (TP)` |
| **3** | Phân bố xác suất Random Forest theo nhãn thực | Bar Chart (Log scale) | Điểm mô hình có tách biệt được gian lận khỏi hợp pháp không? | `Fact_Transaction` (`vw_dash_05_score_distribution`) | Tổng số dòng khớp `139.490` giao dịch Test Ngày 1 |
| **4** | Giao dịch gian lận được bắt và bỏ sót theo dải số tiền | Stacked Bar Chart | Mô hình bắt tốt và bỏ sót nhiều ở dải số tiền nào? | `Fact_Transaction` JOIN `Dim_AmountBand` (`vw_dash_02`) | Khớp 100% bảng 7 dải tiền ở Notebook 04 §8 (tổng bắt `93`, bỏ sót `108`) |
| **5** | So sánh 2 họ mô hình & Baseline: PR-AUC, Precision@100, Recall@100 | Grouped Bar | Họ có giám sát vượt trội ra sao so với phát hiện bất thường và baseline? | `vw_dash_06_model_vs_baseline_comparison` | Gồm đủ `RF`, `LogReg`, `HistGB`, `LOF`, `Isolation Forest`, `Max\|V*\|` và `Random` |

- **Bộ lọc (Filter):** `Dải số tiền` (`dai_amount` từ `Dim_AmountBand`) áp dụng tương tác cho Biểu đồ 1 và Biểu đồ 4.

---

## 5. Cách chạy lại toàn bộ Phần E

### 5.1. Chạy lại Tiền xử lý & Notebook 04
```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python src/preprocessing.py
cd notebooks
jupyter lab
```
Mở `notebooks/04_supervised_classification.ipynb`, chọn `Kernel -> Restart Kernel and Run All Cells`.

### 5.2. Chạy Kho PostgreSQL & Apache Superset 6.0.0
```powershell
cd D:\DA_CK\superset
$env:TAG="6.0.0"
docker compose -f docker-compose-image-tag.yml up -d
```
Truy cập `http://localhost:8088` (`admin` / `admin`) và import gói `dashboard/dashboard_export_superset.zip` qua giao diện **Dashboards -> Import Dashboard**.

---

## 6. Biên bản đối soát Kho PostgreSQL & Tệp bàn giao trong `dashboard/` (Mục E11, E13, E14)

Kết quả đối soát Bước C12 / E11 trên PostgreSQL 16 (`outputs/postgres_execution_log.txt` & `outputs/warehouse_validation_report.md`):

```text
=== BAO CAO DOI SOAT DIEM MO HINH (BUOC C12) ===
 stg_score_rows | fact_total_rows | rows_with_iforest | iforest_top100_alerts | iforest_caught_fraud | rows_with_lof | lof_top100_alerts | lof_caught_fraud | rows_with_sup_prob | sup_top100_alerts | sup_caught_fraud 
----------------+-----------------+-------------------+-----------------------+----------------------+---------------+-------------------+------------------+--------------------+-------------------+------------------
         139490 |          284807 |            139490 |                   100 |                   31 |        139490 |               100 |               30 |             139490 |               100 |               93
(1 row)
```

Danh sách tệp bàn giao tại thư mục `dashboard/` (theo đúng cấu trúc Phụ lục B `report-template.md`):
1. `dashboard/dashboard_export_superset.zip` (và bản sao `outputs/dashboard_export_superset.zip`)
2. `dashboard/fig05_dashboard_overview.png` (và bản sao `figures/fig05_dashboard_overview.png`)
3. `dashboard/fig06_dashboard_filtered.png` (và bản sao `figures/fig06_dashboard_filtered.png`)
4. `dashboard/fig07_sqllab_reconciliation.png` (và bản sao `figures/fig07_sqllab_reconciliation.png`)

---

## 7. Khai báo sử dụng AI (Tiêu chí 10)

- **Công cụ sử dụng:** Claude (Anthropic) và Gemini (Google Antigravity).
- **Mục đích sử dụng:** Hỗ trợ rà soát sự đồng bộ giao thức giữa các nhánh (`feature/cuong-preprocessing`, `feature/huy-anomaly-detection`, `main`), cấu trúc hóa mã nguồn `notebooks/04_supervised_classification.ipynb` (bao gồm 5-Fold Stratified CV và phân tích lỗi FP/FN), viết truy vấn SQL kết nối Star Schema cho Apache Superset và biên tập tài liệu bàn giao `README_E_Mong.md`.
- **Phần do sinh viên kiểm tra và chịu trách nhiệm:** Toàn bộ mã nguồn được thực thi trực tiếp trên dữ liệu thật `creditcard.csv` (`sha256: 76274b69…98551a89`) và `transactions_processed.csv` (`sha256: e8bf7dcd…93628958`) tại máy cá nhân; toàn bộ chỉ số (`PR-AUC`, `Precision@100`, `Recall@100`, `mean ± sd` qua 5 fold, phân tích lỗi theo dải tiền) được đối soát khớp 100% giữa Notebook, PostgreSQL `Fact_Transaction` và SQL Lab; không tải dữ liệu giao dịch thô lên dịch vụ bên thứ ba.
