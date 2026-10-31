# Đồ án 6: Phát hiện giao dịch thẻ gian lận. Phần E (Mong): Phân lớp có giám sát, Đối sánh hai họ mô hình và Dashboard

Nhánh: `feature/mong-classification-dashboard`. Cập nhật: 2026-10-31.
Trạng thái chung: **Đã hoàn tất đồng bộ E1 → E9 với Cường (Phần B), Quỳnh (Phần C) và Huy (Phần D); `notebooks/04_supervised_classification.ipynb` đã chạy lại trên `data/processed/transactions_processed.csv` của Cường; đã có bảng đối sánh hai họ mô hình (E7, E8) và xuất `outputs/model_scores_warehouse.csv` theo đúng chuẩn kho PostgreSQL của Quỳnh.**

## 1. Đã làm (E1 → E13)

- **Môi trường:** Python 3.13, `pandas==3.0.2`, `scikit-learn==1.8.0` (đúng phiên bản trong `requirements.txt`), JupyterLab.
- **Dữ liệu gốc & Tiền xử lý dùng chung (E1):**
  - Kiểm tra `data/raw/creditcard.csv` khớp `sha256` của nhóm (`76274b69…98551a89`).
  - Gộp nhánh của Cường (B), Quỳnh (C) và Huy (D); chạy `src/preprocessing.py` tạo `data/processed/transactions_processed.csv` (`284.807` dòng × `47` cột, `sha256 = e8bf7dcd…93628958`).
  - Thống nhất toàn bộ quyết định `D-01` → `D-11` trong `outputs/decision_log.csv`:
    - **Khóa chính (`D-01`):** `txn_id` (`1..284807`, 1-based).
    - **Khử trùng mô hình (`D-02`):** Loại `1.081` bản sao thừa (`is_duplicate = 1`, trong đó có 19 gian lận), giữ `in_model_set == 1` gồm **`283.726` dòng, `473` gian lận** (Ngày 0: `144.236` dòng / `272` gian lận; Ngày 1: `139.490` dòng / `201` gian lận).
    - **Đặc trưng (`D-07`):** `FEATURES = V1..V28 + amount_log1p` (29 cột), bỏ `Time` thô; dùng `make_preprocessor()` của Cường (`StandardScaler` chỉ fit trên `amount_log1p` của tập train; `V1..V28` giữ nguyên).
    - **Hai giao thức chia tập (`D-06`):**
      1. **Giao thức chính theo ngày (`split_temporal`):** `train` = 80% Ngày 0 phân tầng (`115.388` dòng, `218` gian lận), `val` = 20% Ngày 0 phân tầng (`28.848` dòng, `54` gian lận, ngân sách tỉ lệ `K_VAL = 20`), `test` = Ngày 1 sau khử trùng (`139.490` dòng, `201` gian lận, ngân sách `K = 100` giao dịch/ngày, trần lý thuyết `Recall@100 = 100/201 = 49,75%`).
      2. **Giao thức phụ đối sánh 1-1 với Huy (`split_random`):** Chia 60/20/20 phân tầng (`train`: `170.235` / `284` gian lận; `val`: `56.745` / `94` gian lận; `test`: `56.746` dòng / `95` gian lận, `K = 100`) — khớp tuyệt đối từng `txn_id` với `outputs/anomaly_scores_test.csv` của Huy.
- **Notebook `notebooks/04_supervised_classification.ipynb` (E2 → E8):**
  - Baseline: đoán lớp đa số (accuracy `99,86%` nhưng bắt `0` gian lận) và xếp hạng ngẫu nhiên (`100` lần chạy).
  - Ba mô hình có giám sát: `LogisticRegression`, `RandomForestClassifier`, `HistGradientBoostingClassifier`. Xử lý mất cân bằng bằng `class_weight` chỉ trên train; chọn tham số theo `PR-AUC` trên validation, không chọn trên test.
  - Đối sánh hai họ mô hình (Supervised vs. Unsupervised Anomaly Detection của Huy) trên cả `split_random` và `split_temporal`.
- **Tệp kết quả đã xuất vào `outputs/` (E6, E7, E9):**
  - `outputs/classification_results.csv`, `outputs/classification_validation.csv`
  - `outputs/model_family_comparison_random_test.csv`, `outputs/model_family_comparison_temporal_test.csv`
  - `outputs/model_scores_warehouse.csv` (đúng 6 cột `txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note` cho `sql/05-load-model-scores.sql` của Quỳnh)
  - `outputs/classification_scores_test.csv` (lưu local, không commit)
- **Dashboard Apache Superset 6.0.0 (E10 → E13):** Chạy qua Docker Compose tại `http://localhost:8088`, gồm 5 biểu đồ và 1 bộ lọc `Dải số tiền` (chi tiết mục 4).

## 2. Kết quả phân lớp có giám sát trên Test Ngày 1 (`split_temporal`: 139.490 dòng, 201 gian lận)

| Mô hình | PR-AUC | Precision@100 | Recall@100 | TP (Bắt đúng) | FP (Báo động giả) | FN (Bỏ sót) |
|---|---:|---:|---:|---:|---:|---:|
| **Random Forest** | **0,7843** | 0,9300 | 0,4627 | 93 | 7 | 108 |
| **Logistic Regression** | 0,7239 | 0,9400 | 0,4677 | 94 | 6 | 107 |
| **HistGradientBoosting** | 0,6727 | 0,9500 | 0,4726 | 95 | 5 | 106 |
| **Xếp hạng ngẫu nhiên (TB 100 lần)** | 0,0015 | 0,0015 | 0,0007 | 0,15 | 99,85 | 200,85 |

Cách đọc:
- Với quy tắc rà soát tối đa `100` giao dịch/ngày, trần lý thuyết `Recall@100` ở Ngày 1 (sau khử trùng `DQ-01`) là `100 / 201 = 49,75%` (hoặc `100 / 211 = 47,39%` nếu tính cả bản sao gốc). Cả ba mô hình bắt được `93–95` giao dịch gian lận trong Top 100, đạt **93%–95% mức trần lý thuyết**.
- `Precision@100` của ba mô hình chỉ chênh nhau 1–2 giao dịch (`93`, `94`, `95` ca), không đủ lớn để kết luận mô hình nào vượt trội tuyệt đối khi tập test chỉ có `201` giao dịch gian lận. `Random Forest` đạt `PR-AUC` cao nhất (`0,7843`).
- Phân tích lỗi của `Random Forest` theo dải số tiền (`amount_band`) trên Ngày 1 (`201` gian lận, bắt được `93`, bỏ sót `108`):
  - Dải `0`: `16` gian lận (bắt `6`, bỏ sót `10`).
  - Dải `0-10`: `88` gian lận (bắt `38`, bỏ sót `50`).
  - Dải `10-50`: `28` gian lận (bắt `13`, bỏ sót `15`).
  - Dải `50-100`: `15` gian lận (bắt `11`, bỏ sót `4`).
  - Dải `100-500`: `37` gian lận (bắt `22`, bỏ sót `15`).
  - Dải `500-1000`: `13` gian lận (bắt `3`, bỏ sót `10`).
  - Dải `>1000`: `4` gian lận (bắt `0`, bỏ sót `4` — mẫu quá nhỏ, không kết luận).
  - Các giao dịch gian lận bị bỏ sót có số tiền trung vị nhỏ (`7,59`). Đây là mô tả thực nghiệm, không suy diễn nguyên nhân nghiệp vụ.

## 3. So sánh hai họ mô hình: Phân lớp có giám sát (E - Mong) vs. Phát hiện bất thường (D - Huy) (Mục E7 & E8)

### 3.1. Đối sánh 1-1 trên tập Test `split_random` (56.746 dòng, 95 gian lận — khớp `anomaly_scores_test.csv` của Huy)

| Họ mô hình | Mô hình | PR-AUC (AP) | Precision@100 | Recall@100 | TP | FP | FN |
|---|---|---:|---:|---:|---:|---:|---:|
| **Phân lớp có giám sát (Mong - E)** | **Random Forest** | **0,8097** | **0,7700** | **0,8105** | **77** | 23 | 18 |
| Phân lớp có giám sát (Mong - E) | HistGradientBoosting | 0,7683 | 0,7200 | 0,7579 | 72 | 28 | 23 |
| Phân lớp có giám sát (Mong - E) | Logistic Regression | 0,6773 | 0,7400 | 0,7789 | 74 | 26 | 21 |
| **Phát hiện bất thường (Huy - D)** | **LOF (`n_neighbors=100`)** | **0,3125** | **0,3800** | **0,4000** | **38** | 62 | 57 |
| Phát hiện bất thường (Huy - D) | Isolation Forest | 0,1609 | 0,2700 | 0,2842 | 27 | 73 | 68 |
| **Baseline** | Xếp hạng ngẫu nhiên (TB 100 lần) | 0,0019 | 0,0026 | 0,0027 | 0,26 | 99,74 | 94,74 |

### 3.2. Đối sánh trên Ngày 1 `split_temporal` (139.490 dòng, 201 gian lận — ngân sách 100 giao dịch/ngày)

| Họ mô hình | Mô hình | PR-AUC (AP) | Precision@100 | Recall@100 | TP | FP | FN |
|---|---|---:|---:|---:|---:|---:|---:|
| **Phân lớp có giám sát (Mong - E)** | **Random Forest** | **0,7843** | 0,9300 | 0,4627 | 93 | 7 | 108 |
| Phân lớp có giám sát (Mong - E) | Logistic Regression | 0,7239 | 0,9400 | 0,4677 | 94 | 6 | 107 |
| Phân lớp có giám sát (Mong - E) | HistGradientBoosting | 0,6727 | 0,9500 | 0,4726 | 95 | 5 | 106 |
| **Phát hiện bất thường (Cấu hình Huy)** | **LOF (`n_neighbors=100`)** | 0,2478 | 0,3000 | 0,1493 | 30 | 70 | 171 |
| Phát hiện bất thường (Cấu hình Huy) | Isolation Forest | 0,1582 | 0,3100 | 0,1542 | 31 | 69 | 170 |
| **Baseline** | Xếp hạng ngẫu nhiên (TB 100 lần) | 0,0015 | 0,0015 | 0,0007 | 0,15 | 99,85 | 200,85 |

### 3.3. Nhận xét bản chất hai họ mô hình (Mục E8)
- **Vì sao mô hình có giám sát đạt điểm cao hơn nhiều?** Các mô hình có giám sát (`Random Forest`, `Logistic Regression`, `HistGB`) học trực tiếp biên phân lớp từ nhãn `is_fraud` trên tập train, trong khi `Isolation Forest` và `LOF` hoàn toàn không nhìn thấy nhãn mà chỉ tìm các điểm thưa/cô lập trong không gian đặc trưng. Các giao dịch hợp pháp nhưng có số tiền lớn hoặc hành vi hiếm cũng bị đánh dấu bất thường, làm tăng dương tính giả (`FP = 62..73` trên 100 cảnh báo so với `FP = 5..7` của mô hình có giám sát trên Ngày 1).
- **Đánh đổi trong thực tế vận hành:** Mô hình có giám sát đòi hỏi nhãn gian lận lịch sử chính xác (thường bị trễ nhiều ngày/tuần sau tra soát và dễ bỏ sót kiểu gian lận mới chưa từng xuất hiện). Ngược lại, phát hiện bất thường không giám sát triển khai được ngay khi chưa có nhãn và hỗ trợ phát hiện các mẫu dị biệt mới. Hai họ mô hình đóng vai trò bổ trợ nhau.

## 4. Dashboard Apache Superset (E10 → E13)

Dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** (chạy trên Superset 6.0.0 qua Docker tại `http://localhost:8088`, đã Published):

| # | Biểu đồ | Câu hỏi trả lời | Dataset / View | Đối soát với Notebook & SQL |
|---|---|---|---|---|
| 1 | Số giao dịch gian lận bắt được trong top 100 | Bắt được bao nhiêu giao dịch gian lận trong ngân sách 100/ngày? | `rf_amount_bands_v2` / `vw_dash_06_model_vs_baseline_comparison` | Notebook §7 & §8 và SQL Lab: **93** ca |
| 2 | Top 100 giao dịch cần rà soát | 100 giao dịch nào cần ưu tiên rà soát trong ngày? | `classification_scores_test` / `vw_dash_04_top100_review_queue` | SQL Lab: **93** giao dịch có `Class = 1` (`is_fraud = 1`) |
| 3 | Phân bố điểm Random Forest theo nhãn thực | Điểm mô hình có tách được gian lận khỏi hợp lệ không? | `rf_score_bins` / `vw_dash_05_score_distribution` | Tổng khớp 100% số dòng Test Ngày 1 |
| 4 | Giao dịch gian lận được bắt và bỏ sót theo dải số tiền | Bỏ sót nhiều ở dải số tiền nào? | `rf_amount_bands_v2` / `vw_dash_02_amount_band_risk` | Khớp bảng phân rã 7 dải `amount_band` ở Notebook §8 |
| 5 | So sánh mô hình: PR-AUC, Precision@100, Recall@100 | Mô hình nào xếp hạng tốt hơn baseline và không giám sát? | `classification_results` / `vw_dash_06_model_vs_baseline_comparison` | Khớp Notebook §7 và §9 |

- **Bộ lọc (Filter):** `Dải số tiền` (`dai_amount` / `band_code`) áp dụng cho biểu đồ 1 và 4.
- **Tích hợp Kho PostgreSQL của Quỳnh (E9, E11):** File `outputs/model_scores_warehouse.csv` do Notebook 04 sinh ra tuân thủ đúng schema `stg_model_scores` trong `sql/05-load-model-scores.sql` của Quỳnh (`txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note`), sẵn sàng nạp vào bảng `Fact_Transaction` để cập nhật trực tiếp các View `vw_dash_04_top100_review_queue` và `vw_dash_06_model_vs_baseline_comparison`.

## 5. Cách chạy lại từ đầu

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python src/preprocessing.py
cd notebooks
jupyter lab
```

Mở `04_supervised_classification.ipynb`, chọn `Kernel -> Restart Kernel and Run All Cells`.

## 6. Khai báo sử dụng AI (Tiêu chí 10)

- **Công cụ sử dụng:** Claude (Anthropic) và Gemini (Google Antigravity).
- **Mục đích sử dụng:** Hỗ trợ rà soát sự đồng bộ giao thức giữa các nhánh (`feature/cuong-preprocessing`, `feature/huy-anomaly-detection`, `main`), cấu trúc hóa mã nguồn `notebooks/04_supervised_classification.ipynb`, viết truy vấn SQL đối soát cho Superset và trình bày bảng báo cáo.
- **Phần do sinh viên kiểm tra và chịu trách nhiệm:** Toàn bộ mã nguồn được chạy thực tế trên tập dữ liệu `creditcard.csv` (`sha256: 76274b69…98551a89`) và `transactions_processed.csv` (`sha256: e8bf7dcd…93628958`) tại máy cá nhân; mọi con số (`PR-AUC`, `Precision@100`, `Recall@100`, số giao dịch bắt được/bỏ sót theo dải tiền) trên báo cáo và Dashboard đều được đối soát khớp với kết quả chạy thật của Notebook và SQL Lab; không gửi dữ liệu thô lên dịch vụ bên thứ ba.
