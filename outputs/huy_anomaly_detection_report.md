# Báo cáo thí nghiệm — Phát hiện bất thường không giám sát: Isolation Forest và Local Outlier Factor (LOF)

**Thành viên phụ trách:** Huy (Vai trò D — Kỹ sư Khai thác dữ liệu / Anomaly Detection)  
**Nhánh Git:** `feature/huy-anomaly-detection` (đã hợp nhất vào `main`)  
**Notebook:** `notebooks/03_anomaly_detection.ipynb`  
**Trạng thái:** Đã chạy lại từ đầu thành công (`Run All` các cell `1..16`), đồng bộ cả 2 giao thức đánh giá (`split_temporal` chính và `split_random` + `cv_fold` phụ), xuất biểu đồ `figures/fig04c_anomaly_detection_results.png` và dọn sạch các file nháp `*_draft.csv`.

---

## 1. Mục tiêu và Giao thức đánh giá

Áp dụng hai thuật toán phát hiện bất thường không giám sát (**Isolation Forest** và **Local Outlier Factor — LOF**) để xếp hạng các giao dịch thẻ tín dụng theo mức độ nghi ngờ gian lận, trả lời câu hỏi nghiệp vụ cốt lõi của nhóm:
> *"Với ngân sách rà soát $K = 100$ giao dịch đáng ngờ nhất mỗi ngày, hệ thống bắt được bao nhiêu phần trăm số vụ gian lận thực tế?"*

Để đảm bảo tính nhất quán toàn dự án (với Thành viên B — Cường, C — Quỳnh và E — Mong), báo cáo trình bày song song **2 giao thức đánh giá** đã được tiền xử lý sẵn trong `data/processed/transactions_processed.csv`:
1. **Giao thức chính (`split_temporal` — Theo thời gian thực tế, ngân sách $K = 100$ giao dịch/ngày):**
   - **Train (`day_0_train`):** `144.234` giao dịch sạch (trong đó có `272` gian lận) của Ngày 0 (`rel_day = 0`).
   - **Test (`day_1_test`):** `139.492` giao dịch sạch (trong đó có **`201` gian lận**) của Ngày 1 (`rel_day = 1`).
   - **Quy tắc đánh giá:** Xếp hạng toàn bộ `139.492` giao dịch Ngày 1 theo điểm bất thường giảm dần, chọn **Top-100 giao dịch/ngày** và đo số gian lận bắt được (`TP`), `Precision@100 = TP / 100`, `Recall@100 = TP / 201`, và `PR-AUC` (Average Precision).
2. **Giao thức phụ (`split_random` cố định + 5-Fold Stratified CV `cv_fold = 0..4`):**
   - **Holdout ngẫu nhiên phân tầng (`split_random`):** `train = 170.235` (`284` gian lận), `val = 56.745` (`94` gian lận — dùng để tinh chỉnh siêu tham số `n_neighbors` của LOF), `test = 56.746` (`95` gian lận).
   - **Kiểm định chéo 5-Fold (`cv_fold = 0..4` trên `226.980` dòng `train + val`):** Mỗi fold có tập kiểm tra khoảng `45.396` giao dịch (`75–76` gian lận). Báo cáo **`mean ± sd`** qua 5 fold cho `PR-AUC`, `Precision@100`, `Recall@100`.

---

## 2. Dữ liệu, Đặc trưng và Chống rò rỉ (Anti-Leakage)

- **Nguồn dữ liệu đầu vào:** `data/processed/transactions_processed.csv` (`284.807` dòng × `47` cột, `0` giá trị khuyết).
- **Xử lý bản ghi trùng lặp:** Loại trừ `1.081` dòng trùng lặp (`is_duplicate = True`, `split_temporal = split_random = 'excluded_duplicate'`, gồm `1.062` hợp lệ + `19` gian lận) khỏi cả Train, Validation và Test, giữ đúng `283.726` giao dịch thực tế độc lập (`473` gian lận).
- **Tập đặc trưng đầu vào:** Sử dụng `28` đặc trưng PCA gốc **`V1`–`V28`**. Cột nhãn `is_fraud` tuyệt đối chỉ dùng ở bước tính độ đo đánh giá sau khi mô hình đã chấm điểm xong (thuần không giám sát — *Unsupervised*).
- **Chuẩn hóa chống rò rỉ:** `StandardScaler` chỉ được `fit` trên tập Train của từng giao thức/fold tương ứng, sau đó mới `transform` sang Validation và Test.

---

## 3. Cấu hình Mô hình và Đường cơ sở (Baselines)

| Phương pháp / Thuật toán | Loại mô hình | Cấu hình tham số & Quy mô huấn luyện |
|---|---|---|
| **Baseline 1: Xếp hạng ngẫu nhiên** | Đường cơ sở ngẫu nhiên | Chọn ngẫu nhiên `K = 100` giao dịch (trung bình kỳ vọng qua 100 lần chạy với `seed = 0..99`). |
| **Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$** | Luật ngưỡng không giám sát | Điểm bất thường $s(x) = \max_{j \in \{1..28\}} \|V_j\|$, không cần huấn luyện, chọn Top-100 điểm cao nhất. |
| **Mô hình 1: Isolation Forest** | Cây cô lập không giám sát | `n_estimators=100`, `contamination='auto'`, `random_state=42`, `n_jobs=-1`; huấn luyện trên **toàn bộ tập Train** (`144.234` dòng ở `split_temporal`; `170.235` dòng ở `split_random`). |
| **Mô hình 2: Local Outlier Factor (LOF)** | Mật độ lân cận cục bộ | `novelty=True`, `n_neighbors=100` (chọn qua Validation), `n_jobs=-1`; huấn luyện trên **`20.000` mẫu ngẫu nhiên** từ tập Train (`seed=42`) để đảm bảo độ phức tạp tính toán bậc hai $O(N^2)$ khả thi. |

### Tinh chỉnh siêu tham số `n_neighbors` của LOF trên tập Validation (`split_random`, 94 gian lận)

Kết quả xuất tại `outputs/lof_tuning_processed_validation.csv` và biểu diễn tại **Panel A của Hình 4** (`figures/fig04c_anomaly_detection_results.png`):

| `n_neighbors` | Fraud Top 100 (TP) | Precision@100 | Recall@100 (trên 94 fraud) | PR-AUC (AP) |
|---:|---:|---:|---:|---:|
| 20 | 2 | 2,00% | 2,13% | 0,0184 |
| 50 | 45 | 45,00% | 47,87% | 0,3858 |
| **100 (Chọn)** | **49** | **49,00%** | **52,13%** | **0,4708** |
| 150 | 46 | 46,00% | 48,94% | 0,4432 |
| 200 | 43 | 43,00% | 45,74% | 0,4170 |

Cấu hình `n_neighbors = 100` đạt đỉnh cả về `Precision@100` (`49,00%`) lẫn `PR-AUC` (`0,4708`) trên Validation, được cố định để đánh giá trên Test (tuyệt đối không tinh chỉnh lại theo kết quả Test).

---

## 4. Kết quả Thực nghiệm Chính

### 4.1. Giao thức chính: `split_temporal` (Train Ngày 0 $\rightarrow$ Test Ngày 1, Ngân sách $K = 100$ GD/ngày)

Trên tập kiểm tra **Ngày 1 (`139.492` giao dịch sạch, `201` giao dịch gian lận)** — trích xuất trực tiếp từ `outputs/anomaly_temporal_day1_results.csv`:

| Phương pháp / Mô hình | Fraud Top-100 (`TP`) | Cảnh báo nhầm (`FP`) | Bỏ sót (`FN`) | `Precision@100` (%) | `Recall@100` (%) (trên 201 fraud) | `PR-AUC` (AP) | Hệ số nâng (Lift so với ngẫu nhiên) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Baseline 1: Xếp hạng ngẫu nhiên (TB 100 lần)** | 0,16 | 99,84 | 199,84 | 0,16% | 0,08% | 0,0015 | 1,0× |
| **Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$** | 10 | 90 | 191 | 10,00% | 4,98% | 0,0571 | ~69,4× |
| **Isolation Forest (`n_estimators=100`)** | **31** | **69** | **170** | **31,00%** | **15,42%** | 0,1582 | **~215,3×** |
| **LOF (`n_neighbors=100`, `novelty=True`)** | **30** | **70** | **171** | **30,00%** | **14,93%** | **0,2478** | **~208,3×** |

> **Nhận xét trên giao thức thời gian (`split_temporal`):**
> - Với ngân sách chỉ rà soát **100 giao dịch/ngày** (tương ứng $0,0717\%$ tổng lưu lượng Ngày 1), **Isolation Forest bắt được 31/201 vụ gian lận (`Recall@100 = 15,42%`, `Precision@100 = 31,00%`)** và **LOF bắt được 30/201 vụ (`Recall@100 = 14,93%`, `Precision@100 = 30,00%`)** — cao gấp hơn **200 lần** so với rà soát ngẫu nhiên và gấp **3 lần** so với luật ngưỡng đơn giản $\max(\|V_j\|)$ (`10` vụ).
> - Mặc dù Isolation Forest nhỉnh hơn LOF đúng 1 giao dịch trong Top-100 của Ngày 1 (`31` so với `30`), LOF có chất lượng xếp hạng tổng thể trên toàn đường cong Precision-Recall tốt hơn (`PR-AUC = 0,2478` so với `0,1582`).
> - Các con số này khớp 100% với bảng tổng hợp đa mô hình của Thành viên E (Mong) tại `outputs/model_scores_warehouse.csv` và View số 6 `vw_dash_06_model_vs_baseline_comparison` trong Kho dữ liệu PostgreSQL của Thành viên C (Quỳnh).

### 4.2. Giao thức phụ: `split_random` (Validation & Test cố định)

Kết quả trên tập **Validation (`56.745` dòng, `94` gian lận)** và **Test (`56.746` dòng, `95` gian lận)** — trích xuất từ `outputs/model_comparison_processed_validation.csv` và `outputs/model_error_analysis_processed_test.csv`:

| Tập dữ liệu | Thuật toán | Fraud Top-100 (`TP`) | `FP` | `FN` | `Precision@100` (%) | `Recall@100` (%) | `PR-AUC` (AP) |
|---|---|---:|---:|---:|---:|---:|---:|
| **Validation (`94` fraud)** | Isolation Forest | 29 | 71 | 65 | 29,00% | 30,85% | 0,2674 |
| **Validation (`94` fraud)** | LOF (`n_neighbors=100`) | **49** | **51** | **45** | **49,00%** | **52,13%** | **0,4708** |
| **Test (`95` fraud)** | Baseline 1: Ngẫu nhiên (TB 100 lần) | 0,18 | 99,82 | 94,82 | 0,18% | 0,19% | 0,0017 |
| **Test (`95` fraud)** | Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$ | 21 | 79 | 74 | 21,00% | 22,11% | 0,1045 |
| **Test (`95` fraud)** | Isolation Forest | 27 | 73 | 68 | 27,00% | 28,42% | 0,1609 |
| **Test (`95` fraud)** | LOF (`n_neighbors=100`) | **38** | **62** | **57** | **38,00%** | **40,00%** | **0,3125** |

### 4.3. Độ ổn định qua 5-Fold Stratified Cross-Validation (`mean ± sd`)

Thực hiện trên `226.980` giao dịch sạch (`cv_fold = 0..4`, mỗi fold kiểm tra `~45.396` giao dịch chứa `75–76` gian lận) — trích xuất từ `outputs/anomaly_5fold_cv_summary.csv` và `outputs/anomaly_5fold_cv_per_fold.csv`:

| Mô hình | `PR-AUC` (`mean ± sd`) | `Precision@100` (%) (`mean ± sd`) | `Recall@100` (%) (`mean ± sd`) |
|---|---|---|---|
| **Isolation Forest (`n_estimators=100`)** | `0,1843 ± 0,0409` | `23,60% ± 5,27%` | `31,19% ± 6,80%` |
| **LOF (`n_neighbors=100`, subsample `20k`)** | **`0,4479 ± 0,0690`** | **`46,60% ± 3,05%`** | **`61,64% ± 4,04%`** |

> **Giải thích sự khác biệt giữa hai giao thức (`split_random` vs `split_temporal`):**
> - Trên `split_random` và 5-Fold CV (khi dữ liệu Train và Test cùng phân phối thời gian), LOF vượt trội rõ rệt so với Isolation Forest (`Precision@100 = 46,60% ± 3,05%` so với `23,60% ± 5,27%`), vì cấu trúc mật độ cục bộ của các cụm gian lận trong cùng ngày rất sát nhau.
> - Tuy nhiên, khi chuyển sang `split_temporal` (huấn luyện trên Ngày 0, kiểm tra trên Ngày 1), phân phối giao dịch dịch chuyển theo thời gian (*concept/covariate drift* giữa Ngày 0 và Ngày 1), khiến hiệu năng của LOF giảm về mức tương đương Isolation Forest (`30` vs `31` gian lận trong Top-100/ngày). Điều này chứng minh tầm quan trọng của việc đánh giá theo thời gian (`split_temporal`) trong bài toán phát hiện gian lận ngân hàng thực tế.

---

## 5. Giới hạn và Lưu ý khi Diễn giải

1. **Giới hạn của phương pháp không giám sát (Unsupervised):** Vì hoàn toàn không sử dụng nhãn `is_fraud` trong quá trình học, cả Isolation Forest và LOF đều gán điểm bất thường cao cho các giao dịch hợp lệ nhưng có hành vi cực đoan (ví dụ: giao dịch số tiền rất lớn hoặc lệch mạnh trên một vài trục PCA nhưng không phải gian lận), dẫn đến `69–70` cảnh báo nhầm (`FP`) trong Top-100/ngày. Đây là động lực trực tiếp để nhóm bổ sung nhánh **Phân lớp có giám sát (Supervised Classification)** của Thành viên E (Mong).
2. **Quy mô mẫu huấn luyện của LOF:** Do độ phức tạp khoảng cách cặp $O(N^2)$, LOF (`novelty=True`) được huấn luyện trên `20.000` mẫu ngẫu nhiên (`seed=42`) từ tập Train, trong khi Isolation Forest huấn luyện trên toàn bộ tập Train (`O(N \log N)`).
3. **Không gian đặc trưng:** Nhánh phát hiện bất thường cố định không gian đặc trưng ở `V1–V28` để giữ chuẩn so sánh thuần túy về hình học/mật độ trong không gian PCA.

---

## 6. Danh mục Đầu ra Bàn giao của Thành viên D (Huy)

- `notebooks/03_anomaly_detection.ipynb` — Notebook hoàn chỉnh (`16` cells), chạy tuần tự từ đầu không lỗi, không có số gõ tay (hardcode).
- `outputs/anomaly_temporal_day1_results.csv` — Kết quả giao thức chính `split_temporal` (Ngày 0 $\rightarrow$ Ngày 1, ngân sách `K = 100/ngày`) cho 2 Baselines, Isolation Forest và LOF.
- `outputs/anomaly_5fold_cv_summary.csv` & `outputs/anomaly_5fold_cv_per_fold.csv` — Kết quả kiểm định chéo 5-Fold (`mean ± sd` và chi tiết từng fold `0..4`).
- `outputs/lof_tuning_processed_validation.csv` — Bảng tinh chỉnh `n_neighbors` của LOF trên Validation.
- `outputs/model_comparison_processed_validation.csv` & `outputs/model_error_analysis_processed_test.csv` — Kết quả Validation và phân tích lỗi `TP/FP/FN` trên Test (`split_random`).
- `outputs/anomaly_scores_test.csv` — Điểm bất thường và thứ hạng của từng giao dịch Test (`split_random`).
- `figures/fig04c_anomaly_detection_results.png` — **Hình 4** của báo cáo (Panel A: Đường cong chọn `n_neighbors` của LOF trên Validation; Panel B: So sánh số gian lận bắt được ở Top-100 giữa `split_temporal` Ngày 1 và `split_random` Test).

---

## 7. Kê khai Sử dụng AI (Phụ lục A — Bảng A1, Phần của Thành viên D — Huy)

| Thành viên | Công cụ AI đã sử dụng | Mục đích & Phạm vi sử dụng | Cách kiểm chứng & Xác nhận của thành viên |
|---|---|---|---|
| **Huy (Thành viên D — Kỹ sư Khai thác dữ liệu / Anomaly Detection)** | GitHub Copilot / ChatGPT | Hỗ trợ viết khung mã nguồn kiểm định chéo 5-Fold (`cv_fold = 0..4`), định dạng bảng tổng hợp kết quả giao thức `split_temporal` (Ngày 0 $\rightarrow$ Ngày 1) và căn chỉnh bố cục biểu đồ 2 panel `figures/fig04c_anomaly_detection_results.png`. | Tự chạy lại toàn bộ `notebooks/03_anomaly_detection.ipynb` từ đầu (`Kernel -> Restart & Run All`), đối chiếu từng con số xuất ra ở `outputs/anomaly_temporal_day1_results.csv` (`TP = 31` cho Isolation Forest, `TP = 30` cho LOF trên `201` gian lận Ngày 1) và `outputs/anomaly_5fold_cv_summary.csv` khớp chính xác với kho dữ liệu PostgreSQL và bảng tổng hợp của nhóm. |
