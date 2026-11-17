# Báo cáo thí nghiệm — Phát hiện bất thường không giám sát: Isolation Forest và Local Outlier Factor (LOF)

**Thành viên phụ trách:** Huy (Vai trò D — Kỹ sư Khai thác dữ liệu / Anomaly Detection)  
**Nhánh Git:** `feature/huy-anomaly-detection` (đã hợp nhất vào `main`)  
**Notebook:** `notebooks/03_anomaly_detection.ipynb`  
**Trạng thái:** Đã chạy lại từ đầu thành công (`Run All` toàn bộ `19` ô gồm `16` ô mã nguồn và `3` ô thuyết minh Markdown), đưa giao thức chính (`split_temporal` Ngày 0 $\rightarrow$ Ngày 1 và 5-Fold CV) lên đầu notebook, xuất biểu đồ `figures/fig04c_anomaly_detection_results.png` và dọn sạch các file nháp `*_draft.csv`.

---

## 1. Mục tiêu và Giao thức đánh giá

Áp dụng hai thuật toán phát hiện bất thường không giám sát (**Isolation Forest** và **Local Outlier Factor — LOF**) để xếp hạng các giao dịch thẻ tín dụng theo mức độ nghi ngờ gian lận, trả lời câu hỏi nghiệp vụ cốt lõi của nhóm:
> *"Với ngân sách rà soát $K = 100$ giao dịch đáng ngờ nhất mỗi ngày, hệ thống bắt được bao nhiêu phần trăm số vụ gian lận thực tế?"*

Để đảm bảo tính nhất quán toàn dự án (với Thành viên B — Cường, C — Quỳnh và E — Mong), báo cáo trình bày song song **2 giao thức đánh giá** đã được tiền xử lý sẵn trong `data/processed/transactions_processed.csv`:
1. **Giao thức chính (`split_temporal` — Theo thời gian thực tế, ngân sách $K = 100$ giao dịch/ngày):**
   - **Train Ngày 0 (`split_temporal` thuộc `{'train', 'val'}`):** **`144.236`** giao dịch sạch (gồm `115.388` dòng `train` + `28.848` dòng `val`, tổng cộng `272` gian lận) của Ngày tương đối 0 (`rel_day = 0`).
   - **Test Ngày 1 (`split_temporal == 'test'`):** **`139.490`** giao dịch sạch (trong đó có **`201` gian lận**) của Ngày tương đối 1 (`rel_day = 1`).
   - **Quy tắc đánh giá:** Xếp hạng toàn bộ **`139.490`** giao dịch Ngày 1 theo điểm bất thường giảm dần, chọn **Top-100 giao dịch/ngày** và đo số gian lận bắt được (`TP`), `Precision@100 = TP / 100`, `Recall@100 = TP / 201`, và `PR-AUC` (Average Precision).
2. **Giao thức phụ (`split_random` cố định + 5-Fold Stratified CV `cv_fold = 0..4`):**
   - **Holdout ngẫu nhiên phân tầng (`split_random`):** `train = 170.235` (`284` gian lận), `val = 56.745` (`94` gian lận — dùng để tinh chỉnh siêu tham số `n_neighbors` của LOF), `test = 56.746` (`95` gian lận).
   - **Kiểm định chéo 5-Fold (`cv_fold = 0..4` trên `226.980` dòng `train + val`):** Mỗi fold có tập kiểm tra khoảng `45.396` giao dịch (`75–76` gian lận). Báo cáo **`mean ± sd`** qua 5 fold cho `PR-AUC`, `Precision@100`, `Recall@100`.

---

## 2. Dữ liệu, Đặc trưng và Chống rò rỉ (Anti-Leakage)

- **Nguồn dữ liệu đầu vào:** `data/processed/transactions_processed.csv` (`284.807` dòng × `47` cột, `0` giá trị khuyết).
- **Xử lý bản ghi trùng lặp:** Loại trừ `1.081` dòng trùng lặp (`is_duplicate = True`, `split_temporal = split_random = 'excluded_duplicate'`, gồm `1.062` hợp lệ + `19` gian lận) khỏi cả Train, Validation và Test, giữ đúng `283.726` giao dịch thực tế độc lập (`473` gian lận).
- **Tập đặc trưng đầu vào:** Sử dụng `28` đặc trưng PCA gốc **`V1`–`V28`**. Cột nhãn `is_fraud` tuyệt đối chỉ dùng ở bước tính độ đo đánh giá sau khi mô hình đã chấm điểm xong (thuần không giám sát — *Unsupervised*).
- **Chuẩn hóa chống rò rỉ:** `StandardScaler` chỉ được `fit` trên toàn bộ tập Train của từng giao thức/fold tương ứng, sau đó mới `transform` sang Validation/Test (và lấy mẫu con `20.000` dòng đã chuẩn hóa từ tập Train để huấn luyện LOF).

---

## 3. Cấu hình Mô hình và Đường cơ sở (Baselines)

| Phương pháp / Thuật toán | Loại mô hình | Cấu hình tham số & Quy mô huấn luyện |
|---|---|---|
| **Baseline 1: Xếp hạng ngẫu nhiên** | Đường cơ sở ngẫu nhiên | Chọn ngẫu nhiên `K = 100` giao dịch (lấy trung bình qua 100 lần xáo trộn sinh từ **một** bộ sinh `np.random.default_rng(42)`, thống nhất `random_state = 42` với toàn bộ notebook). |
| **Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$** | Luật ngưỡng không giám sát | Điểm bất thường $s(x) = \max_{j \in \{1..28\}} \|V_j\|$, không cần huấn luyện, chọn Top-100 điểm cao nhất. |
| **Mô hình 1: Isolation Forest** | Cây cô lập không giám sát | `n_estimators=100`, `contamination='auto'`, `random_state=42`, `n_jobs=-1`; huấn luyện trên **toàn bộ tập Train** (`144.236` dòng ở `split_temporal`; `170.235` dòng ở `split_random`). |
| **Mô hình 2: Local Outlier Factor (LOF)** | Mật độ lân cận cục bộ | `novelty=True`, `n_neighbors=100` (chọn qua Validation), `n_jobs=-1`; huấn luyện trên **`20.000` mẫu ngẫu nhiên** từ tập Train đã chuẩn hóa (`seed=42`) để đảm bảo độ phức tạp tính toán bậc hai $O(N^2)$ khả thi. |

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

Trên tập kiểm tra **Ngày 1 (`139.490` giao dịch sạch, `201` giao dịch gian lận)** — trích xuất trực tiếp từ `outputs/anomaly_temporal_day1_results.csv`:

| Phương pháp / Mô hình | Fraud Top-100 (`TP`) | Cảnh báo nhầm (`FP`) | Bỏ sót (`FN`) | `Precision@100` (%) | `Recall@100` (%) (trên 201 fraud) | `PR-AUC` (AP) | Hệ số nâng (Lift so với ngẫu nhiên) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Baseline 1: Xếp hạng ngẫu nhiên (TB 100 lần)** | 0,16 | 99,84 | 200,84 | 0,16% | 0,08% | 0,0015 | 1,0× |
| **Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$** | 10 | 90 | 191 | 10,00% | 4,98% | 0,0571 | ~69,4× |
| **Isolation Forest (`n_estimators=100`)** | **31** | **69** | **170** | **31,00%** | **15,42%** | 0,1582 | **~215,3×** |
| **LOF (`n_neighbors=100`, `novelty=True`)** | **30** | **70** | **171** | **30,00%** | **14,93%** | **0,2478** | **~208,3×** |

> **Nhận xét trên giao thức thời gian (`split_temporal`):**
> - Với ngân sách chỉ rà soát **100 giao dịch/ngày** (tương ứng $0,0717\%$ tổng lưu lượng `139.490` giao dịch Ngày 1), **Isolation Forest bắt được 31/201 vụ gian lận (`Recall@100 = 15,42%`, `Precision@100 = 31,00%`)** và **LOF bắt được 30/201 vụ (`Recall@100 = 14,93%`, `Precision@100 = 30,00%`)** — cao gấp hơn **200 lần** so với rà soát ngẫu nhiên và gấp **3 lần** so với luật ngưỡng đơn giản $\max(\|V_j\|)$ (`10` vụ).
> - Mặc dù Isolation Forest nhỉnh hơn LOF đúng 1 giao dịch trong Top-100 của Ngày 1 (`31` so với `30`), LOF có chất lượng xếp hạng tổng thể trên toàn đường cong Precision-Recall tốt hơn (`PR-AUC = 0,2478` so với `0,1582`).
> - Các con số này khớp 100% với bảng tổng hợp đa mô hình của Thành viên E (Mong) tại `outputs/model_scores_warehouse.csv` và View số 6 `vw_dash_06_model_vs_baseline_comparison` trong Kho dữ liệu PostgreSQL của Thành viên C (Quỳnh).

### 4.2. Độ ổn định qua 5-Fold Stratified Cross-Validation (`mean ± sd`)

Thực hiện trên `226.980` giao dịch sạch (`cv_fold = 0..4`, mỗi fold kiểm tra `~45.396` giao dịch chứa `75–76` gian lận, chuẩn hóa `StandardScaler` trên toàn tập Train của fold trước khi lấy mẫu `20.000` dòng với `seed = 42 + fold_id`) — trích xuất từ `outputs/anomaly_5fold_cv_summary.csv` và `outputs/anomaly_5fold_cv_per_fold.csv` (khớp 100% với `outputs/cv_5fold_spread_summary.csv` của Thành viên E — Mong):

| Mô hình | `PR-AUC` (`mean ± sd`) | `Precision@100` (%) (`mean ± sd`) | `Recall@100` (%) (`mean ± sd`) |
|---|---|---|---|
| **Isolation Forest (`n_estimators=100`)** | `0,1843 ± 0,0409` | `23,60% ± 5,27%` | `31,19% ± 6,80%` |
| **LOF (`n_neighbors=100`, subsample `20k`)** | **`0,4480 ± 0,0649`** | **`47,20% ± 2,59%`** | **`62,44% ± 3,42%`** |

### 4.3. Giao thức phụ: `split_random` (Validation & Test cố định)

Kết quả trên tập **Validation (`56.745` dòng, `94` gian lận)** và **Test (`56.746` dòng, `95` gian lận)** — trích xuất từ `outputs/model_comparison_processed_validation.csv` và `outputs/model_error_analysis_processed_test.csv`:

| Tập dữ liệu | Thuật toán | Fraud Top-100 (`TP`) | `FP` | `FN` | `Precision@100` (%) | `Recall@100` (%) | `PR-AUC` (AP) |
|---|---|---:|---:|---:|---:|---:|---:|
| **Validation (`94` fraud)** | Isolation Forest | 29 | 71 | 65 | 29,00% | 30,85% | 0,2674 |
| **Validation (`94` fraud)** | LOF (`n_neighbors=100`) | **49** | **51** | **45** | **49,00%** | **52,13%** | **0,4708** |
| **Test (`95` fraud)** | Baseline 1: Ngẫu nhiên (TB 100 lần, `default_rng(42)`) | 0,15 | 99,85 | 94,85 | 0,15% | 0,16% | 0,0017 |
| **Test (`95` fraud)** | Baseline 2: Heuristic $\max(\|V_1..V_{28}\|)$ | 21 | 79 | 74 | 21,00% | 22,11% | 0,1045 |
| **Test (`95` fraud)** | Isolation Forest | 27 | 73 | 68 | 27,00% | 28,42% | 0,1609 |
| **Test (`95` fraud)** | LOF (`n_neighbors=100`) | **38** | **62** | **57** | **38,00%** | **40,00%** | **0,3125** |

> **Giải thích thận trọng về sự khác biệt giữa hai giao thức (`split_random` vs `split_temporal`):**
> - Trên `split_random` và 5-Fold CV (khi dữ liệu Train và Test được lấy mẫu ngẫu nhiên phân tầng trên toàn bộ 2 ngày), LOF vượt trội rõ rệt so với Isolation Forest (`Precision@100 = 47,20% ± 2,59%` so với `23,60% ± 5,27%`), trong khi ở `split_temporal` (huấn luyện Ngày 0, kiểm tra Ngày 1), hai thuật toán cho kết quả xấp xỉ nhau ở Top-100 (`30` so với `31` gian lận).
> - Sự chênh lệch này **gợi ý** hai nguyên nhân có thể đồng thời xảy ra: (1) có thể có sự dịch chuyển nhẹ về phân phối hành vi giao dịch giữa Ngày 0 và Ngày 1 (*covariate/concept shift* trong cửa sổ quan sát ngắn 48 giờ), và (2) trong tập dữ liệu tồn tại `12.446` giao dịch có vector đặc trưng `V1–V28` gần trùng hoặc trùng nhau nhưng khác `Time`/`Amount` (mã `DQ-01b` do Thành viên B — Cường phát hiện). Khi chia ngẫu nhiên (`split_random` / 5-Fold CV), các giao dịch có đặc trưng `V1–V28` gần trùng nhau này có cơ hội phân bổ vào cả Train lẫn Test, tạo lợi thế tự nhiên cho thuật toán dựa trên khoảng cách láng giềng cục bộ như LOF so với khi cắt nghiêm ngặt theo ranh giới ngày (`split_temporal`).

### 4.4. Giao dịch điển hình của Isolation Forest / LOF (mục 5.3 của mẫu báo cáo)

Lấy từ điểm Ngày 1 (`split_temporal`) đã tính ở Phần I, không huấn luyện lại — sinh bởi **Phần IV** của `notebooks/03_anomaly_detection.ipynb`, lưu tại `outputs/anomaly_typical_examples_day1.csv` (16 dòng). Cột “Lệch chuẩn lớn nhất” là 3 trục `V` có `|z|` lớn nhất (z tính theo trung bình và độ lệch chuẩn của Ngày 0).

| Mô hình | Loại | `txn_id` | Hạng Ngày 1 | Giờ tương đối | Amount | Lệch chuẩn lớn nhất |
|---|---|---:|---:|---:|---:|---|
| Isolation Forest | Bắt đúng (TP) | 151007 | 2 | 26 | 1,00 | V7 = −26,8; V3 = −24,4; V10 = −21,2 |
| Isolation Forest | Bắt đúng (TP) | 154372 | 4 | 28 | 2,28 | V7 = −31,9; V21 = −24,0; V8 = −23,8 |
| LOF | Bắt đúng (TP) | 150655 | 4 | 26 | 0,01 | V17 = −22,9; V12 = −18,2; V14 = −16,5 |
| LOF | Bắt đúng (TP) | 150666 | 6 | 26 | 209,65 | V17 = −25,7; V12 = −16,9; V16 = −14,2 |
| Cả hai | Báo nhầm (FP) | 274772 | 1 / 1 | 46 | 25.691,16 | V7 = +104,1; V5 = −86,9; V27 = +83,1 |
| Cả hai | Báo nhầm (FP) | 151297 | 12 / 2 | 26 | 18.910,00 | V20 = +53,1; V2 = −37,6; V23 = −28,1 |
| Isolation Forest | Bỏ sót (FN) | 204080 | 109.996 | 37 | 108,51 | V3 = −2,1; V14 = −2,1; V13 = +1,4 |
| LOF | Bỏ sót (FN) | 251882 | 115.190 | 43 | 3,14 | V14 = −3,3; V4 = +3,1; V16 = +2,2 |

> **Nhận xét:**
> - **Bắt đúng:** các ca gian lận đứng đầu đều lệch rất mạnh (|z| > 15) trên một nhóm nhỏ trục PCA, và thường có số tiền rất nhỏ (0,01 – 2,28). Hai mô hình dựa vào các trục khác nhau: IF chủ yếu ở `V7`, `V3`, `V10`; LOF ở `V17`, `V12`, `V14`.
> - **Báo nhầm:** cả hai mô hình cùng xếp các giao dịch hợp lệ **số tiền rất lớn** (> 18.000) với độ lệch cực đoan (|z| tới 104) lên hạng 1–12. Đây là điểm yếu cố hữu của phương pháp không giám sát: “hiếm” không đồng nghĩa với “gian lận” (xem Mục 5, ý 1).
> - **Bỏ sót:** các ca gian lận bị xếp cuối có |z| < 3,5 trên mọi trục, tức là trông giống hệt giao dịch bình thường trong không gian `V1–V28`. Không mô hình dựa trên mật độ hay cô lập nào bắt được những ca này nếu không có nhãn — lý do bổ sung nhánh có giám sát của Thành viên E (Mong).
> - Không gán ý nghĩa nghiệp vụ cho từng trục `V*` (đã ẩn danh bằng PCA, quyết định `D-07`).

---

## 5. Giới hạn và Lưu ý khi Diễn giải

1. **Giới hạn của phương pháp không giám sát (Unsupervised):** Vì hoàn toàn không sử dụng nhãn `is_fraud` trong quá trình học, cả Isolation Forest và LOF đều gán điểm bất thường cao cho các giao dịch hợp lệ nhưng có hành vi cực đoan (ví dụ: giao dịch số tiền rất lớn hoặc lệch mạnh trên một vài trục PCA nhưng không phải gian lận), dẫn đến `69–70` cảnh báo nhầm (`FP`) trong Top-100/ngày. Đây là động lực trực tiếp để nhóm bổ sung nhánh **Phân lớp có giám sát (Supervised Classification)** của Thành viên E (Mong).
2. **Quy mô mẫu huấn luyện của LOF:** Do độ phức tạp khoảng cách cặp $O(N^2)$, LOF (`novelty=True`) được huấn luyện trên `20.000` mẫu ngẫu nhiên (`seed=42`) từ tập Train đã chuẩn hóa, trong khi Isolation Forest huấn luyện trên toàn bộ tập Train (`O(N \log N)`).
3. **Không gian đặc trưng:** Nhánh phát hiện bất thường cố định không gian đặc trưng ở `V1–V28` để giữ chuẩn so sánh thuần túy về hình học/mật độ trong không gian PCA.

---

## 6. Danh mục Đầu ra Bàn giao của Thành viên D (Huy)

- `notebooks/03_anomaly_detection.ipynb` — Notebook hoàn chỉnh (`21` ô gồm `17` ô code và `4` ô thuyết minh Markdown; Phần IV xuất giao dịch điển hình), trình bày giao thức chính (`split_temporal` & 5-Fold CV) trước giao thức phụ (`split_random`), chạy tuần tự từ đầu không lỗi, không có số gõ tay (hardcode).
- `outputs/anomaly_temporal_day1_results.csv` — Kết quả giao thức chính `split_temporal` (Ngày 0 $\rightarrow$ Ngày 1, ngân sách `K = 100/ngày`) cho 2 Baselines, Isolation Forest và LOF.
- `outputs/anomaly_5fold_cv_summary.csv` & `outputs/anomaly_5fold_cv_per_fold.csv` — Kết quả kiểm định chéo 5-Fold (`mean ± sd` và chi tiết từng fold `0..4`, đồng nhất 100% với bảng tổng hợp của Thành viên E — Mong).
- `outputs/lof_tuning_processed_validation.csv` — Bảng tinh chỉnh `n_neighbors` của LOF trên Validation.
- `outputs/model_comparison_processed_validation.csv` & `outputs/model_error_analysis_processed_test.csv` — Kết quả Validation và phân tích lỗi `TP/FP/FN` trên Test (`split_random`).
- `outputs/anomaly_scores_test.csv` — Điểm bất thường và thứ hạng của từng giao dịch Test (`split_random`).
- `outputs/anomaly_typical_examples_day1.csv` — 16 giao dịch điển hình Ngày 1 (mỗi mô hình 3 TP, 3 FP, 2 FN) cho Mục 4.4 / mục 5.3 của mẫu báo cáo.
- `figures/fig04c_anomaly_detection_results.png` — **Hình 4** của báo cáo (Panel A: Đường cong chọn `n_neighbors` của LOF trên Validation; Panel B: So sánh số gian lận bắt được ở Top-100 giữa `split_temporal` Ngày 1 và `split_random` Test).

---

## 7. Kê khai Sử dụng AI (Phụ lục A — Bảng A1, Phần của Thành viên D — Huy)

> **Bảng khai báo AI hợp nhất (chính thức) của cả nhóm:** `outputs/ai_usage_declaration.md` (có cột “Phần nào là của nhóm” và cam kết). Mục dưới đây là bản chi tiết của phần này.

| Thành viên | Công cụ AI đã sử dụng | Mục đích & Phạm vi sử dụng | Phần nào là của nhóm | Cách kiểm chứng & Xác nhận của thành viên |
|---|---|---|---|---|
| **Huy (Thành viên D — Kỹ sư Khai thác dữ liệu / Anomaly Detection)** | GitHub Copilot / ChatGPT | Giải thích cơ chế Isolation Forest, LOF (`novelty=True`), `PR-AUC` và `Precision@K`; gợi ý cú pháp vòng lặp 5-Fold CV (`cv_fold = 0..4`) và bố cục biểu đồ Matplotlib 2 panel; hỗ trợ sửa lỗi thứ tự chuẩn hóa `StandardScaler` trước khi lấy mẫu LOF | Huy tự lựa chọn 2 mô hình không giám sát và 2 đường cơ sở (baselines), thiết lập giao thức đánh giá chính Ngày 0 $\rightarrow$ Ngày 1 với ngân sách `K = 100`/ngày, chọn siêu tham số `n_neighbors = 100` trên tập Validation, phân tích nguyên nhân chênh lệch giữa hai giao thức và trích xuất 16 giao dịch điển hình (`TP`/`FP`/`FN`) | Tự chạy lại toàn bộ `notebooks/03_anomaly_detection.ipynb` từ đầu (`Kernel -> Restart & Run All`), đối chiếu từng con số xuất ra ở `outputs/anomaly_temporal_day1_results.csv` (`TP = 31` cho Isolation Forest, `TP = 30` cho LOF trên `201` gian lận Ngày 1) và `outputs/anomaly_5fold_cv_summary.csv` (`LOF Precision@100 = 47,20% ± 2,59%`) khớp chính xác với kho dữ liệu PostgreSQL và bảng tổng hợp của nhóm. |

**Cam kết bảo mật và trách nhiệm:** Thành viên D (Huy) và cả nhóm cam kết không tải dữ liệu giao dịch thô (`data/raw/creditcard.csv`) lên bất kỳ dịch vụ AI bên thứ ba nào; toàn bộ quyết định lựa chọn mô hình, siêu tham số và diễn giải kết quả là của nhóm; tự hiểu và giải thích được từng dòng code của phần mình.
