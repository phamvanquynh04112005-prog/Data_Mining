# Báo Cáo Kết Quả Truy Vấn OLAP & Biên Bản Bàn Giao Kho Dữ Liệu (Phần C — Quỳnh)

- **Dự án:** Đồ án 6 — Ngân hàng: Phát hiện giao dịch thẻ gian lận (*Credit Card Fraud Detection — ULB Dataset*)
- **Câu hỏi kinh doanh trung tâm:** *"Với ngân sách rà soát 100 giao dịch mỗi ngày, ta bắt được bao nhiêu phần trăm gian lận?"*
- **Người thực hiện:** Thành viên C — Quỳnh (Data Engineer: PostgreSQL, Star Schema, ETL, OLAP & Superset Views)
- **Môi trường đã kiểm chứng:** PostgreSQL 16.15-5 (`postgresql://dm:dm@localhost:5432/dm_course`)
- **Trạng thái đối soát:** **ĐẠT 100%** (`284,807` giao dịch, `492` gian lận = `0.1727%`, khớp tuyệt đối với `outputs/audit_metrics.json` của Thành viên A — Khang).

---

## 1. Tóm Tắt Kết Quả Thực Thi 5 Truy Vấn OLAP (`sql/olap_queries.sql`)

Toàn bộ 5 truy vấn OLAP dưới đây đã được thực thi trực tiếp trên kho dữ liệu Star Schema (`Fact_Transaction` kết hợp 4 bảng chiều `Dim_Date`, `Dim_Hour`, `Dim_AmountBand`, `Dim_Channel`).

### OLAP 1: Trần Lý Thuyết (Theoretical Ceiling) Với Ngân Sách 100 Giao Dịch / Ngày Tương Đối
- **Kỹ thuật SQL:** `GROUP BY ROLLUP((d.date_key, d.relative_day_label))`
- **Kết quả thực thi:**

| Ngày tương đối | Tổng giao dịch | Số gian lận (`Class = 1`) | Gian lận sau khử trùng (`DQ-01`) | Tỷ lệ gian lận (%) | Ngân sách rà soát | % Lưu lượng được rà soát | **Trần Recall lý thuyết (%)** | **Trần Recall sau khử trùng (%)** | Tổng tiền gian lận |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Relative Day 0 (`0s – 86,399s`)** | 144,786 | 281 | 272 | 0.1941% | 100 | 0.0691% | **35.59%** | **36.76%** | 32,756.34 |
| **Relative Day 1 (`86,400s – 172,792s`)** | 140,021 | 211 | 201 | 0.1507% | 100 | 0.0714% | **47.39%** | **49.75%** | 27,371.63 |
| **ALL DAYS (Tổng 2 ngày tương đối)** | **284,807** | **492** | **473** | **0.1727%** | **200** | **0.0702%** | **40.65%** | **42.28%** | **60,127.97** |

- **Diễn giải nghiệp vụ (trả lời trực tiếp câu hỏi kinh doanh):**
  1. Ngân sách `100 giao dịch/ngày` chỉ tương đương **0.0702%** tổng lưu lượng giao dịch mỗi ngày (~1,424 giao dịch phải chọn 1).
  2. Do Ngày tương đối 0 có `281` giao dịch gian lận và Ngày tương đối 1 có `211` giao dịch gian lận (vượt quá ngân sách 100 giao dịch/ngày), nên **ngay cả một mô hình tiên tri hoàn hảo 100% (`Precision@100 = 100%`) cũng chỉ có thể bắt tối đa `35.59%` số vụ gian lận ở Ngày 0, `47.39%` ở Ngày 1, và `40.65%` (`200/492` vụ) trên toàn bộ 2 ngày** (hoặc `42.28%` nếu tính trên `473` vụ sau khử trùng `DQ-01`).
  3. Vì vậy, khi Thành viên D (Huy) và E (Mong) đánh giá mô hình ở ngưỡng `k = 100/ngày`, **không bao giờ được kỳ vọng Recall tiến tới 100%**. Mọi mô hình cần được đo song song bằng:
     - `Precision@100/day` (tỷ lệ cảnh báo đúng trong 100 ca rà soát),
     - `Recall@100/day` (tỷ lệ gian lận bắt được trên tổng gian lận thực tế), và
     - **`% of Theoretical Max Recall@100/day`** (đạt bao nhiêu phần trăm so với trần tối đa 200 vụ).

---

### OLAP 2: Phân Tích Đa Chiều Theo Dải Tiền (`Dim_AmountBand`) × Chu Kỳ Ngày (`Dim_Hour.day_cycle_label`)
- **Kỹ thuật SQL:** `GROUP BY CUBE((ab.amount_band_key, ab.amount_band_code, ab.amount_band_label), h.day_cycle_label)`
- **Kết quả tổng hợp theo Dải tiền (`Subtotal by AmountBand` — khớp 100% với `outputs/amount_band_fraud_rate.csv` của Khang A):**

| Thứ tự | Dải tiền (`amount_band_label`) | Tổng giao dịch | Số gian lận | Gian lận (khử trùng) | Tỷ lệ gian lận (%) | Tỷ trọng số vụ gian lận (%) | Tổng tiền gian lận |
| :---: | :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | **`0` (`= 0`)** | 1,825 | 27 | 25 | **1.4795%** | 5.49% | 0.00 |
| 2 | **`(0, 1]`** | 29,215 | 158 | 145 | **0.5408%** | **32.11%** | 152.66 |
| 3 | **`(1, 10]`** | 70,115 | 64 | 64 | 0.0913% | 13.01% | 243.47 |
| 4 | **`(10, 50]`** | 90,781 | 57 | 57 | 0.0628% | 11.59% | 1,561.71 |
| 5 | **`(50, 200]`** | 63,972 | 101 | 97 | 0.1579% | 20.53% | 10,498.68 |
| 6 | **`(200, 1000]`** | 25,959 | 76 | 76 | 0.2928% | 15.45% | 35,342.42 |
| 7 | **`> 1000`** | 2,940 | 9 | 9 | 0.3061% | 1.83% | 12,329.03 |
| **ALL** | **TỔNG TOÀN BỘ (`Grand Total`)** | **284,807** | **492** | **473** | **0.1727%** | **100.00%** | **60,127.97** |

- **Điểm phát hiện quan trọng:**
  - Hai dải tiền nhỏ nhất (`Amount = 0` và `0 < Amount <= 1`) chỉ chiếm `10.90%` tổng số giao dịch nhưng chiếm tới **`37.60%` tổng số vụ gian lận** (`185/492` vụ), với tỷ lệ gian lận ở `Amount = 0` cao gấp **8.56 lần** mức trung bình toàn cục (`1.4795%` so với `0.1727%`). Đây là dấu hiệu điển hình của hành vi *card-probing / zero-amount authorization test* trước khi rút tiền lớn.
  - Tuy nhiên, về mặt **giá trị tiền tệ thất thoát**, hai dải `(50, 200]` và `(200, 1000]` chiếm tới **`76.24%` tổng số tiền gian lận** (`45,841.10 / 60,127.97`).

---

### OLAP 3: Diễn Biến Gian Lận Theo 48 Giờ Tương Đối & Khung Giờ Rủi Ro Cao Nhất
- **Kỹ thuật SQL:** `WINDOW FUNCTIONS` (`AVG(...) OVER (ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`, `SUM(...) OVER (PARTITION BY date_key)`, `DENSE_RANK() OVER (ORDER BY fraud_rate_pct DESC)`)
- **Top 10 giờ tương đối có tỷ lệ gian lận (`fraud_rate_pct`) cao nhất:**

| Hạng rủi ro | Giờ tương đối (`hour_key`) | Ngày tương đối | Offset giờ trong ngày (`0..23`) | Tổng giao dịch | Số gian lận | Tỷ lệ gian lận (%) | Trung bình trượt 3 giờ (%) |
| :---: | :---: | :---: | :---: | ---: | ---: | ---: | ---: |
| **1** | **Hour 02** | Day 0 | `offset +02h` | 1,576 | 21 | **1.3325%** | 0.5060% |
| **2** | **Hour 26** | Day 1 | `offset +02h` | 1,752 | 36 | **2.0548%*** *(xếp theo tổng/tỷ lệ)* | — |
| *(Lưu ý chi tiết từ kết quả SQL)* | **Hour 26** | Day 1 | `offset +02h` | 1,752 | 36 | **2.0548%** (Hạng 1 toàn cục) | 0.8758% |
| | **Hour 02** | Day 0 | `offset +02h` | 1,576 | 21 | **1.3325%** (Hạng 2 toàn cục) | 0.5060% |
| | **Hour 28** | Day 1 | `offset +04h` | 1,126 | 14 | **1.2433%** (Hạng 3 toàn cục) | 1.1997% |
| | **Hour 04** | Day 0 | `offset +04h` | 1,082 | 9 | **0.8318%** (Hạng 4 toàn cục) | 0.8966% |
| | **Hour 27** | Day 1 | `offset +03h` | 1,685 | 13 | **0.7715%** (Hạng 5 toàn cục) | 1.0762% |
| | **Hour 03** | Day 0 | `offset +03h` | 1,807 | 13 | **0.7194%** (Hạng 6 toàn cục) | 0.7204% |
| | **Hour 05** | Day 0 | `offset +05h` | 1,681 | 11 | **0.6544%** (Hạng 7 toàn cục) | 0.6929% |
| | **Hour 07** | Day 0 | `offset +07h` | 3,368 | 21 | **0.6235%** (Hạng 8 toàn cục) | 0.4525% |

- **Điểm phát hiện quan trọng:**
  - Sự lặp lại chu kỳ 24 giờ cực kỳ rõ nét giữa Ngày tương đối 0 và Ngày tương đối 1: các khung giờ tương đối **`offset +02h`, `+03h`, `+04h`** ở cả hai ngày (`Hour 02..04` và `Hour 26..28`) đều là vùng trũng lưu lượng giao dịch hợp lệ nhưng lại là **đỉnh tỷ lệ gian lận** (`0.72% – 2.05%`, gấp **4 đến 12 lần** mức trung bình).
  - Gợi ý trực tiếp cho Thành viên B (Cường — Tiền xử lý) & D (Huy — Mô hình): Đặc trưng `hour_in_day_offset = FLOOR(Time / 3600) % 24` (hoặc mã hóa tuần hoàn `sin/cos` của chu kỳ 24 giờ) mang tín hiệu phân biệt gian lận rất mạnh, trong khi cột `Time` gốc tăng tuyến tính dễ gây lệch giữa tập Train (đầu thời gian) và Test (cuối thời gian).

---

### OLAP 4: Kiểm Định Các Cờ Chất Lượng Dữ Liệu (`DQ-01`, `DQ-02`, `DQ-06`) Bằng `GROUPING SETS`
- **Kỹ thuật SQL:** `GROUP BY GROUPING SETS ((is_duplicate, is_zero_amount, has_extreme_v_z10), (is_duplicate), (is_zero_amount), (has_extreme_v_z10), ())`
- **Kết quả kiểm định các phân nhóm rủi ro:**

| Phân nhóm kiểm định (`grouping_dimension`) | `is_duplicate` (`DQ-01`) | `is_zero_amount` (`DQ-02`) | `has_extreme_v_z10` (`DQ-06`) | Tổng giao dịch | Số gian lận | Tỷ lệ gian lận (%) | % trên tổng 492 gian lận | Hệ số Lift so với TB (`0.1727%`) |
| :--- | :---: | :---: | :---: | ---: | ---: | ---: | ---: | ---: |
| **Tổ hợp 3 cờ: `Amount = 0` & Extreme `|z| > 10` (không trùng)** | `FALSE` | `TRUE` | `TRUE` | 30 | 16 | **53.3333%** | 3.25% | **308.77x** |
| **Tổ hợp 3 cờ: Bản ghi trùng (`DQ-01`) & Extreme `|z| > 10`** | `TRUE` | `FALSE` | `TRUE` | 48 | 10 | **20.8333%** | 2.03% | **120.61x** |
| **Đơn chiều `DQ-06`: Có bất kỳ `|V1..V28| > 10`** | *ALL* | *ALL* | **`TRUE`** | **1,924** | **231** | **12.0062%** | **46.95%** | **69.51x** |
| **Đơn chiều `DQ-06`: Không có `|V1..V28| > 10`** | *ALL* | *ALL* | `FALSE` | 282,883 | 261 | 0.0923% | 53.05% | 0.53x |
| **Đơn chiều `DQ-01`: Bản ghi trùng lặp dư ra** | **`TRUE`** | *ALL* | *ALL* | **1,081** | **19** | **1.7576%** | **3.86%** | **10.18x** |
| **Đơn chiều `DQ-01`: Bản ghi duy nhất / đầu tiên** | `FALSE` | *ALL* | *ALL* | 283,726 | 473 | 0.1667% | 96.14% | 0.97x |
| **Đơn chiều `DQ-02`: Giao dịch `Amount = 0`** | *ALL* | **`TRUE`** | *ALL* | **1,825** | **27** | **1.4795%** | **5.49%** | **8.57x** |

- **Điểm phát hiện quan trọng (cực kỳ giá trị cho báo cáo học thuật):**
  1. **Tại sao TUYỆT ĐỐI KHÔNG ĐƯỢC cắt bỏ (clip/drop) ngoại lai trên `V1..V28` (`DQ-06`):** Chỉ riêng `1,924` giao dịch có `|z| > 10` (chiếm `0.675%` dữ liệu) đã chứa tới **`231` vụ gian lận (`46.95%` tổng số gian lận toàn tập)**, với hệ số Lift gấp **69.51 lần** mức nền! Đặc biệt, khi một giao dịch vừa có `Amount = 0` vừa có `|z| > 10`, xác suất gian lận vọt lên **53.33% (`308.77x` Lift)**.
  2. **Tại sao phải khử trùng (`DQ-01`) trước khi đánh giá mô hình:** Trong `1,081` dòng trùng lặp dư ra có `19` dòng gian lận (`1.7576%`). Nếu không khử trùng theo đúng giao thức của nhóm, mô hình có thể "ăn gian" điểm Recall nhờ bắt trúng các bản sao y hệt nhau.

---

### OLAP 5: So Sánh Các Chiến Lược Baseline Với Ngân Sách 100 Giao Dịch / Ngày
- **Kỹ thuật SQL:** `ROW_NUMBER() OVER (PARTITION BY date_key ORDER BY ...)` lấy đúng Top-100 giao dịch mỗi ngày tương đối.
- **Kết quả đối chiếu 3 chiến lược Baseline có sẵn trong kho dữ liệu:**

| Chiến lược rà soát (`100 giao dịch / ngày`) | Phạm vi | Số GD rà soát | Gian lận bắt được (`TP`) | Cảnh báo giả (`FP`) | `Precision@100` (%) | `Recall@100` (%) | **% Đạt được so với Trần Lý Thuyết** | Tiền gian lận thu hồi |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **0. Trần lý thuyết (Oracle Perfect Model)** | 2 ngày | 200 | **200** | 0 | **100.00%** | **40.65%** | **100.00%** | — |
| **1. Baseline Ngẫu nhiên (Random 100/ngày)** | 2 ngày | 200 | **0.34** *(kỳ vọng)* | 199.66 | **0.17%** | **0.07%** | **0.17%** | ~42.22 |
| **2. Baseline Luật thủ công (Top-100 `Amount` lớn nhất/ngày)** | 2 ngày | 200 | **0** | 200 | **0.00%** | **0.00%** | **0.00%** | **0.00** |
| **3. Heuristic Không giám sát (Top-100 `Max(\|V1..V28\|)`/ngày)** | Day 0 | 100 | 23 | 77 | 23.00% | 8.19% | 23.00% | 5,093.86 |
| **3. Heuristic Không giám sát (Top-100 `Max(\|V1..V28\|)`/ngày)** | Day 1 | 100 | 12 | 88 | 12.00% | 5.69% | 12.00% | 1,622.64 |
| **3. Heuristic Không giám sát (Tổng 2 ngày)** | **2 ngày** | **200** | **35** | **165** | **17.50%** | **7.11%** | **17.50%** | **6,716.50** |

- **Bài học kinh doanh đắt giá từ OLAP 5:**
  - **Sự thất bại hoàn toàn của luật thủ công truyền thống ("Rà soát 100 giao dịch có số tiền lớn nhất trong ngày"):** Bắt được **0 vụ gian lận (`0.00%`)** ở cả Ngày 0 lẫn Ngày 1! Toàn bộ 200 giao dịch có giá trị lớn nhất (`Amount > 2,125.87`) đều là giao dịch hợp lệ (`Class = 0`), trong khi giao dịch gian lận lớn nhất trong toàn bộ tập dữ liệu chỉ là `2,125.87`. Điều này chứng minh thuyết phục vì sao ngân hàng bắt buộc phải dùng Khai thác dữ liệu & Học máy thay vì lọc theo ngưỡng tiền thô.

---

## 2. Danh Mục 6 Dashboard Views Phục Vụ Apache Superset (`sql/04-dashboard-views.sql`)

Toàn bộ 6 SQL Views đã được khởi tạo sẵn trong schema `public` của database `dm_course` để Thành viên E (Mong) kết nối trực tiếp vào Apache Superset mà không cần viết lại SQL phức tạp:

| Tên View trong PostgreSQL | Mục đích hiển thị trên Dashboard Superset | Các cột chính |
| :--- | :--- | :--- |
| **`vw_dash_01_daily_budget_kpi`** | **Big Number / KPI Card & Bảng tổng hợp ngân sách 100 GD/ngày:** Hiển thị tổng giao dịch, tổng gian lận, trần lý thuyết (`35.59%` Day 0, `47.39%` Day 1) và kết quả thực tế của mô hình theo từng ngày tương đối. | `date_key`, `relative_day_label`, `total_transactions`, `actual_fraud_count`, `daily_review_budget`, `theoretical_max_recall_pct`, `model_caught_fraud_top100`, `model_recall_at_100_pct`, `pct_of_theoretical_ceiling_achieved` |
| **`vw_dash_02_hourly_fraud_trend`** | **Time-Series Bar + Line Chart (48 giờ tương đối):** Biểu đồ xu hướng lưu lượng giao dịch, số vụ gian lận, tỷ lệ gian lận (`%`) và đường trung bình trượt 3 giờ (`rolling_3h_fraud_rate_pct`) qua 48 giờ tương đối. | `hour_key`, `hour_label`, `hour_in_day_offset`, `day_cycle_label`, `total_transactions`, `fraud_count`, `fraud_rate_pct`, `rolling_3h_fraud_rate_pct` |
| **`vw_dash_03_amount_band_risk`** | **Bar / Dual-Axis Chart theo 7 dải tiền (`Dim_AmountBand`):** So sánh tỷ trọng giao dịch vs. tỷ trọng số vụ gian lận vs. tỷ trọng giá trị tiền gian lận và hệ số Lift. | `amount_band_key`, `amount_band_label`, `total_transactions`, `fraud_count`, `fraud_rate_pct`, `share_of_total_fraud_pct`, `share_of_fraud_value_pct`, `fraud_lift_ratio` |
| **`vw_dash_04_data_quality_impact`** | **Grouped Bar / Table về 3 cờ chất lượng dữ liệu (`DQ-01`, `DQ-02`, `DQ-06`):** Minh họa trực quan tác động của dữ liệu trùng lặp, giao dịch `0 đồng` và ngoại lai `|z| > 10`. | `dq_code`, `segment_name`, `total_transactions`, `fraud_count`, `fraud_rate_pct`, `share_of_all_frauds_pct`, `fraud_lift_vs_overall` |
| **`vw_dash_05_channel_simulation_Notice`** | **Pie / Bar Chart kèm cảnh báo minh bạch về chiều `Dim_Channel` (`SYNTHETIC`):** Luôn đính kèm cột `academic_transparency_note` khẳng định đây là chiều mô phỏng học thuật. | `channel_code`, `channel_name`, `is_synthetic`, `academic_transparency_note`, `total_transactions`, `fraud_count`, `fraud_rate_pct` |
| **`vw_dash_06_model_vs_baseline_comparison`** | **Bảng / Biểu đồ so sánh trực diện các chiến lược @ Ngân sách 100 GD/ngày:** Đặt cạnh nhau Trần lý thuyết (`200` vụ), Random Baseline (`0.34` vụ), Top-100 Amount (`0` vụ), Unsupervised Heuristic (`35` vụ) và Supervised/Anomaly Model từ Thành viên D & E. | `strategy_order`, `strategy_name`, `daily_budget_per_day`, `total_reviewed_2days`, `caught_frauds_2days`, `precision_at_100_pct`, `recall_at_100_pct`, `pct_of_theoretical_ceiling` |

---

## 3. Biên Bản Bàn Giao Chính Thức (Chuẩn Mục G — `File_Train.docx`)

```markdown
### BIÊN BẢN BÀN GIAO: THÀNH VIÊN C (QUỲNH) → THÀNH VIÊN E (MONG), B (CƯỜNG) & D (HUY)
- **Người giao:** Thành viên C — Quỳnh (Kỹ sư Dữ liệu / Kho dữ liệu PostgreSQL, Star Schema & OLAP)
- **Người nhận chính:** Thành viên E — Mong (Đánh giá thực nghiệm, Dashboard Apache Superset & Báo cáo tổng hợp)
- **Người nhận phối hợp:** Thành viên B — Cường (Tiền xử lý) & Thành viên D — Huy (Mô hình bất thường & Có giám sát)
- **Ngày giờ bàn giao:** 2026-10-30

#### 1. Danh sách file đầu ra đã tạo và kiểm chứng
1. `outputs/star_schema_erd.md` — Tài liệu thiết kế Grain, sơ đồ ERD Mermaid (1 Fact + 4 Dimensions), đặc tả cột và quy tắc toàn vẹn.
2. `sql/setup_local_db.ps1` — Script PowerShell tự động cấu hình PostgreSQL 16 local, tạo role `dm` và database `dm_course`.
3. `sql/01-staging.sql` — Tạo bảng staging `stg_raw_transactions` và `stg_model_scores`, nạp `284,807` dòng từ `data/raw/creditcard.csv`.
4. `sql/02-star-schema.sql` — Tạo 4 bảng chiều (`Dim_Date`, `Dim_Hour`, `Dim_AmountBand`, `Dim_Channel`) và bảng sự kiện `Fact_Transaction` kèm PK/FK và 8 chỉ mục.
5. `sql/03-transform.sql` — Biến đổi và nạp dữ liệu từ Staging sang Star Schema, gán các cờ chất lượng dữ liệu (`is_duplicate`, `is_zero_amount`, `has_extreme_v_z10`, `max_abs_v_zscore`) và chạy truy vấn đối soát toàn vẹn.
6. `sql/04-dashboard-views.sql` — Khởi tạo 6 SQL Views (`vw_dash_01` đến `vw_dash_06`) phục vụ trực tiếp cho Apache Superset.
7. `sql/05-load-model-scores.sql` — Script nạp điểm mô hình từ file `outputs/model_scores_warehouse.csv` vào kho dữ liệu và cập nhật `Fact_Transaction`.
8. `sql/olap_queries.sql` — Bộ 5 truy vấn OLAP (`ROLLUP`, `CUBE`, `GROUPING SETS`, `WINDOW FUNCTIONS`) trả lời câu hỏi kinh doanh và kiểm định dữ liệu.
9. `sql/run_warehouse.ps1` & `sql/run_olap_and_views.ps1` — Bộ script chạy tự động toàn bộ pipeline SQL với encoding UTF-8 chuẩn trên Windows.
10. `outputs/warehouse_validation_report.md` — Báo cáo đối soát toàn vẹn dữ liệu giữa Staging, Fact và kết quả Audit của Khang (A).
11. `outputs/olap_and_handover_summary.md` — Báo cáo tổng hợp kết quả 5 truy vấn OLAP, từ điển 6 Views Superset và Biên bản bàn giao này.

#### 2. Chuỗi kết nối cơ sở dữ liệu & Lệnh chạy lại từ đầu (Idempotent)
- **SQLALCHEMY URI (dùng cho Apache Superset hoặc Python):**
  `postgresql+psycopg2://dm:dm@localhost:5432/dm_course`
- **Lệnh chạy lại toàn bộ kho dữ liệu (từ thư mục gốc `project/`):**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "sql\run_warehouse.ps1"
  powershell -ExecutionPolicy Bypass -File "sql\run_olap_and_views.ps1"
  ```

#### 3. Các con số kiểm chứng cốt lõi (Không được lệch trong Báo cáo & Slide)
- Tổng số giao dịch trong `Fact_Transaction`: **`284,807`** (`492` gian lận = **`0.1727%`**, `284,315` hợp lệ).
- Bản ghi trùng lặp dư ra (`DQ-01`, `is_duplicate = TRUE`): **`1,081`** dòng (`19` gian lận); sau khử trùng còn **`283,726`** dòng (`473` gian lận).
- Giao dịch `Amount = 0` (`DQ-02`, `is_zero_amount = TRUE`): **`1,825`** dòng (`27` gian lận = **`1.4795%`**).
- Giao dịch có ngoại lai `|V1..V28| > 10` (`DQ-06`, `has_extreme_v_z10 = TRUE`): **`1,924`** dòng chứa **`231` gian lận** (**`12.0062%`**, chiếm **`46.95%`** tổng số gian lận toàn tập).
- **Trần lý thuyết với ngân sách 100 giao dịch/ngày:**
  - Ngày tương đối 0 (`144,786` GD, `281` gian lận): Bắt tối đa **`100/281 = 35.59%`** (`36.76%` sau khử trùng).
  - Ngày tương đối 1 (`140,021` GD, `211` gian lận): Bắt tối đa **`100/211 = 47.39%`** (`49.75%` sau khử trùng).
  - Toàn bộ 2 ngày (`284,807` GD, `492` gian lận, ngân sách 200 GD): Bắt tối đa **`200/492 = 40.65%`** (`42.28%` sau khử trùng).
- **Kết quả Baseline trên kho dữ liệu (@ 100 giao dịch/ngày):**
  - Random 100/ngày: Kỳ vọng **`0.34`** vụ gian lận / 2 ngày (`Precision@100 = 0.17%`, `Recall = 0.07%`).
  - Luật thủ công Top-100 `Amount` lớn nhất/ngày: **`0`** vụ gian lận / 2 ngày (`Precision@100 = 0.00%`, `Recall = 0.00%`).
  - Heuristic không giám sát Top-100 `Max(|V1..V28|)`/ngày: **`35`** vụ gian lận / 2 ngày (`23` vụ Ngày 0 + `12` vụ Ngày 1; `Precision@100 = 17.50%`, `Recall = 7.11%`).

#### 4. Hướng dẫn tích hợp điểm mô hình cho Thành viên D (Huy) & E (Mong)
Khi chạy xong thực nghiệm mô hình, Huy (D) hoặc Mong (E) chỉ cần xuất file `outputs/model_scores_warehouse.csv` gồm đúng 10 cột sau:
`transaction_seq_id,split_role,iforest_score,lof_score,ae_recon_error,logreg_prob,lgbm_prob,daily_alert_rank,is_top100_daily_alert,selected_model_name`
Sau đó chạy:
```powershell
psql -U dm -h localhost -p 5432 -d dm_course -f "sql/05-load-model-scores.sql"
```
View `vw_dash_01_daily_budget_kpi` và `vw_dash_06_model_vs_baseline_comparison` sẽ tự động cập nhật kết quả của mô hình để hiển thị lên Apache Superset.

#### 5. Các giả định và giới hạn cần lưu ý
1. **Không gán giờ đồng hồ thực tế cho `Time`:** Mọi phân tích theo ngày (`Dim_Date`) và giờ (`Dim_Hour`) đều là **ngày tương đối (`0..1`)** và **giờ tương đối (`0..47`)** tính từ giao dịch đầu tiên (`Time = 0`).
2. **Không bịa tên nghiệp vụ cho `V1..V28`:** Các cột `V1..V28` được giữ nguyên là thành phần chính ẩn danh sau PCA.
3. **Tính minh bạch của `Dim_Channel`:** Bảng `Dim_Channel` là chiều mô phỏng (`is_synthetic = TRUE`) để đáp ứng yêu cầu kỹ thuật tối thiểu 3–4 bảng chiều của Star Schema; tuyệt đối không dùng `channel_key` làm đặc trưng huấn luyện mô hình hay rút ra kết luận nghiệp vụ thật.
```

