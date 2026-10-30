# Báo Cáo Kết Quả Truy Vấn OLAP & Biên Bản Bàn Giao Kho Dữ Liệu (Phần C — Quỳnh)

- **Dự án:** Đồ án 6 — Ngân hàng: Phát hiện giao dịch thẻ gian lận (*Credit Card Fraud Detection — ULB Dataset*)
- **Câu hỏi kinh doanh trung tâm:** *"Với ngân sách rà soát 100 giao dịch mỗi ngày, ta bắt được bao nhiêu phần trăm gian lận?"*
- **Người thực hiện:** Thành viên C — Quỳnh (Data Engineer: PostgreSQL, Star Schema, ETL, OLAP & Superset Views)
- **Môi trường đã kiểm chứng:** PostgreSQL 16.15-5 (`postgresql://dm:dm@localhost:5432/dm_course`)
- **Log thực thi nguyên bản đính kèm:** `outputs/postgres_execution_log.txt`
- **Trạng thái đối soát:** **ĐẠT 100%** (`284 807` giao dịch, `492` gian lận = `0.1727%`, `sha256: 76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89`, khớp tuyệt đối với `outputs/audit_metrics.json` và `outputs/amount_band_fraud_rate.csv` của Thành viên A — Khang).

---

## 1. Tóm Tắt Kết Quả Thực Thi 5 Truy Vấn OLAP (`sql/olap_queries.sql`)

Toàn bộ 5 truy vấn OLAP dưới đây được trích xuất nguyên bản từ lần chạy thực tế trên PostgreSQL 16.15-5 (`outputs/postgres_execution_log.txt`) dựa trên `Fact_Transaction` kết hợp 4 bảng chiều `Dim_Date`, `Dim_Hour`, `Dim_AmountBand`, `Dim_Channel`.

### OLAP 1: Trần Lý Thuyết (Theoretical Ceiling) Với Ngân Sách 100 Giao Dịch / Ngày Tương Đối
- **Kỹ thuật SQL:** `GROUP BY ROLLUP (d.date_key, d.rel_day_label)`
- **Kết quả thực thi nguyên bản từ PostgreSQL:**

| `pham_vi_ngay` (`rel_day_label`) | `tong_giao_dich` | `tong_gian_lan` | `ty_le_gian_lan_pct` (%) | `ngan_sach_ra_soat` | `ty_le_duoc_ra_soat_pct` (%) | `max_fraud_bat_duoc_raw` | **`tran_recall_raw_pct` (%)** | `gian_lan_sau_khu_trung` (`DQ-01`) | **`tran_recall_dedup_pct` (%)** |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Ngày tương đối 0 (0s – 86.399s)** | 144,786 | 281 | 0.1941% | 100 | 0.0691% | 100 | **35.59%** | 272 | **36.76%** |
| **Ngày tương đối 1 (86.400s – 172.792s)** | 140,021 | 211 | 0.1507% | 100 | 0.0714% | 100 | **47.39%** | 201 | **49.75%** |
| **TỔNG CỘNG TOÀN BỘ (2 NGÀY TƯƠNG ĐỐI)** | **284,807** | **492** | **0.1727%** | **200** | **0.0702%** | **200** | **40.65%** | **473** | **42.28%** |

- **Diễn giải nghiệp vụ (trả lời trực tiếp câu hỏi kinh doanh):**
  1. Ngân sách `100 giao dịch/ngày` chỉ tương đương **0.0702%** tổng lưu lượng giao dịch mỗi ngày (~1,424 giao dịch mới được rà soát 1 giao dịch).
  2. Vì Ngày tương đối 0 có `281` giao dịch gian lận và Ngày tương đối 1 có `211` giao dịch gian lận (đều vượt quá trần 100 giao dịch/ngày), nên **ngay cả một bộ xếp hạng hoàn hảo 100% (`Precision@100 = 100%`) cũng chỉ bắt được tối đa `35.59%` số vụ gian lận ở Ngày 0, `47.39%` ở Ngày 1, và `40.65%` (`200/492` vụ) trên toàn bộ 2 ngày** (hoặc `42.28%` = `200/473` vụ nếu tính trên dữ liệu đã khử trùng `DQ-01`).
  3. Do đó, khi Thành viên D (Huy) và E (Mong) đánh giá mô hình ở ngưỡng `k = 100/ngày`, **không bao giờ được kỳ vọng Recall tiến tới 100%**. Mọi mô hình cần được đo song song bằng `Precision@100`, `Recall@100` và **`% so với Trần lý thuyết (40.65%)`**.

---

### OLAP 2: Phân Tích Gian Lận Theo 7 Dải Số Tiền (`Dim_AmountBand`) & Ngày Tương Đối
- **Kỹ thuật SQL:** `GROUP BY ROLLUP ((ab.band_order, ab.band_code), d.date_key)` kết hợp `SUM(...) OVER ()` và `RANK() OVER (PARTITION BY grp_band, grp_day ORDER BY ty_le_gian_lan_pct DESC)`
- **Kết quả thực thi nguyên bản từ PostgreSQL (khớp 100% từng con số với `outputs/amount_band_fraud_rate.csv` của Khang A):**

| `band_order` | `dai_so_tien` (`band_code`) | `ngay_tuong_doi` | `so_giao_dich` | `so_gian_lan` | `ty_le_gian_lan_pct` (%) | `ty_trong_tren_tong_492_fraud_pct` (%) | `hang_rui_ro_dai_tien` | `tong_tien_gian_lan` |
| :---: | :--- | :--- | ---: | ---: | ---: | ---: | :---: | ---: |
| 1 | **`0`** (`Amount = 0`) | Cả 2 ngày (Tổng dải) | 1,825 | 27 | **1.479%** | 5.49% | **1** | 0.00 |
| 2 | **`0–10`** (`(0, 10]`) | Cả 2 ngày (Tổng dải) | 98,439 | 222 | 0.226% | **45.12%** | 4 | 458.90 |
| 3 | **`10–50`** (`(10, 50]`) | Cả 2 ngày (Tổng dải) | 90,781 | 57 | 0.063% | 11.59% | 7 | 1,615.03 |
| 4 | **`50–100`** (`(50, 100]`) | Cả 2 ngày (Tổng dải) | 37,254 | 56 | 0.150% | 11.38% | 6 | 4,945.33 |
| 5 | **`100–500`** (`(100, 500]`) | Cả 2 ngày (Tổng dải) | 47,366 | 95 | 0.201% | 19.31% | 5 | 21,913.81 |
| 6 | **`500–1000`** (`(500, 1000]`) | Cả 2 ngày (Tổng dải) | 6,202 | 26 | **0.419%** | 5.28% | **2** | 17,957.57 |
| 7 | **`>1000`** (`Amount > 1000`) | Cả 2 ngày (Tổng dải) | 2,940 | 9 | **0.306%** | 1.83% | **3** | 13,237.33 |
| — | **`ALL_BANDS`** | **Cả 2 ngày (Tổng dải)** | **284,807** | **492** | **0.173%** | **100.00%** | — | **60,127.97** |

- **Điểm phát hiện quan trọng:**
  - Phân bố rủi ro gian lận theo số tiền có **dạng chữ U (bimodal risk)**: tỷ lệ gian lận đạt đỉnh ở **`Amount = 0` (`1.479%`, hạng 1 — cao gấp 8.56 lần mức trung bình)** do hành vi thử thẻ (*zero-amount card probing*), giảm mạnh ở dải giao dịch chi tiêu thường ngày `10–50` (`0.063%`, hạng 7), rồi tăng vọt trở lại ở các dải tiền lớn **`500–1000` (`0.419%`, hạng 2)** và **`>1000` (`0.306%`, hạng 3)**.
  - Về **số lượng vụ việc**, hai dải nhỏ `0` và `0–10` chiếm tới **`50.61%` tổng số vụ gian lận (`249/492` vụ)**. Nhưng về **giá trị thiệt hại tiền tệ**, ba dải từ `100` trở lên (`100–500`, `500–1000`, `>1000`) chiếm tới **`88.33%` tổng số tiền gian lận (`53,108.71 / 60,127.97`)**.

---

### OLAP 3: Đa Chiều Kiểm Chứng Cạm Bẫy Xóa Ngoại Lai (`DQ-02` & `DQ-06`) Bằng `CUBE`
- **Kỹ thuật SQL:** `GROUP BY CUBE (f.has_extreme_v_z10, f.is_zero_amount)`
- **Kết quả thực thi nguyên bản từ PostgreSQL:**

| `nhom_duoi_nang_pca` (`has_extreme_v_z10`) | `nhom_amount_zero` (`is_zero_amount`) | `so_giao_dich` | `so_gian_lan` | `ty_le_gian_lan_pct` (%) | `phan_tram_trong_tong_492_fraud` (%) |
| :--- | :--- | ---: | ---: | ---: | ---: |
| **Có ít nhất 1 V* với \|z\| > 10 (`DQ-06`)** | **`Amount = 0` (`DQ-02`)** | **30** | **16** | **53.333%** | **3.25%** |
| **Có ít nhất 1 V* với \|z\| > 10 (`DQ-06`)** | `Amount > 0` | 1,894 | 215 | 11.352% | 43.70% |
| **Có ít nhất 1 V* với \|z\| > 10 (`DQ-06`)** | **Tất cả (Mọi Amount)** | **1,924** | **231** | **12.006%** | **46.95%** |
| Bình thường (Mọi \|z\| <= 10) | `Amount = 0` (`DQ-02`) | 1,795 | 11 | 0.613% | 2.24% |
| Bình thường (Mọi \|z\| <= 10) | `Amount > 0` | 281,088 | 250 | 0.089% | 50.81% |
| Bình thường (Mọi \|z\| <= 10) | Tất cả (Mọi Amount) | 282,883 | 261 | 0.092% | 53.05% |
| **Tất cả (Mọi mức \|z\|)** | **`Amount = 0` (`DQ-02`)** | **1,825** | **27** | **1.479%** | **5.49%** |
| Tất cả (Mọi mức \|z\|) | `Amount > 0` | 282,982 | 465 | 0.164% | 94.51% |
| **Tất cả (Mọi mức \|z\|)** | **Tất cả (Mọi Amount)** | **284,807** | **492** | **0.173%** | **100.00%** |

- **Điểm phát hiện quan trọng (chứng minh quyết định giữ nguyên ngoại lai của nhóm):**
  1. Chỉ riêng `1,924` giao dịch có ít nhất 1 cột $V_i$ vượt $|z| > 10$ (`0.675%` tổng dữ liệu) đã chứa tới **`231` vụ gian lận (`46.95%` tổng số gian lận toàn tập)**, với tỷ lệ gian lận `12.006%` (cao gấp **69.51 lần** mức nền `0.1727%`).
  2. Đặc biệt, tổ hợp giao dịch vừa có `Amount = 0` vừa có `|z| > 10` có `30` giao dịch thì tới **`16` giao dịch là gian lận (`53.333%`, cao gấp 308.77 lần mức nền)**. Nếu xóa ngoại lai theo phản xạ thông thường, mô hình sẽ mất gần một nửa số ca gian lận!

---

### OLAP 4: Diễn Biến Gian Lận Theo 48 Giờ Tương Đối (`0..47`) & Top 10 Giờ Có Tỷ Lệ Gian Lận Cao Nhất
- **Kỹ thuật SQL:** `WINDOW FUNCTIONS` (`SUM(...) OVER (ROWS UNBOUNDED PRECEDING)`, `AVG(...) OVER (ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING)`, `LAG()`, `DENSE_RANK() OVER (ORDER BY AVG(f.is_fraud) DESC)`)
- **Kết quả thực thi nguyên bản từ PostgreSQL (Top 10 giờ tương đối):**

| `gio_tuong_doi` (`hour_key`) | `ngay_tuong_doi` (`date_key`) | `gio_chu_ky_24h` (`hour_in_rel_day`) | `so_giao_dich` | `so_gian_lan` | **`ty_le_gian_lan_pct` (%)** | `trung_binh_truot_3h_fraud` | `thay_doi_so_voi_gio_truoc` (`LAG`) | `gian_lan_tich_luy` | `hang_ty_le_gian_lan` |
| :---: | :---: | :---: | ---: | ---: | ---: | ---: | ---: | ---: | :---: |
| **26** | 1 | **2** | 1,752 | 36 | **2.055%** | 16.00 | +28 | 329 | **1** |
| **28** | 1 | **4** | 1,127 | 17 | **1.508%** | 7.00 | +13 | 350 | **2** |
| **2** | 0 | **2** | 1,576 | 21 | **1.332%** | 12.00 | +19 | 25 | **3** |
| **3** | 0 | **3** | 1,821 | 13 | **0.714%** | 13.33 | -8 | 38 | **4** |
| **7** | 0 | 7 | 3,368 | 23 | **0.683%** | 10.33 | +20 | 81 | **5** |
| **5** | 0 | 5 | 1,681 | 11 | **0.654%** | 6.67 | +5 | 55 | **6** |
| **4** | 0 | **4** | 1,082 | 6 | **0.555%** | 10.00 | -7 | 44 | **7** |
| **11** | 0 | 11 | 8,517 | 43 | **0.505%** | 18.00 | +41 | 146 | **8** |
| **25** | 1 | 1 | 2,003 | 8 | **0.399%** | 16.00 | +4 | 293 | **9** |
| **23** | 0 | 23 | 6,082 | 17 | **0.280%** | 8.00 | +14 | 281 | **10** |

- **Điểm phát hiện quan trọng:**
  - Sự lặp lại chu kỳ 24 giờ cực kỳ rõ nét giữa Ngày tương đối 0 và Ngày tương đối 1: các vị trí giờ chu kỳ **`hour_in_rel_day = 2, 3, 4`** ở cả hai ngày (`hour_key = 2, 3, 4` và `hour_key = 26, 28`) đều là vùng lưu lượng giao dịch thấp (`1,082 – 1,821` GD/giờ) nhưng lại chiếm trọn **Top 4 khung giờ có tỷ lệ gian lận cao nhất (`0.714% – 2.055%`, gấp 4 đến 12 lần mức trung bình)**!
  - Gợi ý cho Thành viên B (Cường) & D (Huy): Đặc trưng chu kỳ `hour_in_rel_day = FLOOR(Time / 3600) % 24` mang tín hiệu phân biệt rất mạnh, trong khi cột `Time` gốc tăng đơn điệu dễ gây lệch phân phối giữa tập Train và Test.

---

### OLAP 5: Đánh Giá Các Chiến Lược Baseline Trên Ngân Sách 100 Giao Dịch / Ngày
- **Kỹ thuật SQL:** `ROW_NUMBER() OVER (PARTITION BY f.date_key ORDER BY ...)` kết hợp `GROUP BY GROUPING SETS ((phuong_phap, date_key), (phuong_phap))`
- **Kết quả thực thi nguyên bản từ PostgreSQL:**

| `phuong_phap` | `pham_vi` | `ngan_sach_ra_soat` | `fraud_bat_duoc` (`TP`) | `duong_tinh_gia_fp` (`FP`) | `precision_at_k_pct` (%) | `recall_pct` (%) | **`hieu_suat_so_voi_tran_pct` (%)** |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| **1. Baseline: Đoán ngẫu nhiên 100 GD/ngày** | Ngày tương đối 0 | 100 | 0.19 | 99.81 | 0.19% | 0.07% | 0.19% |
| **1. Baseline: Đoán ngẫu nhiên 100 GD/ngày** | Ngày tương đối 1 | 100 | 0.15 | 99.85 | 0.15% | 0.07% | 0.15% |
| **1. Baseline: Đoán ngẫu nhiên 100 GD/ngày** | **TỔNG 2 NGÀY (200 GD)** | **200** | **0.34** | **199.66** | **0.17%** | **0.07%** | **0.17%** |
| **2. Baseline Rule: Top-100 Amount cao nhất/ngày** | Ngày tương đối 0 | 100 | **0** | 100 | **0.00%** | **0.00%** | **0.00%** |
| **2. Baseline Rule: Top-100 Amount cao nhất/ngày** | Ngày tương đối 1 | 100 | **0** | 100 | **0.00%** | **0.00%** | **0.00%** |
| **2. Baseline Rule: Top-100 Amount cao nhất/ngày** | **TỔNG 2 NGÀY (200 GD)** | **200** | **0** | **200** | **0.00%** | **0.00%** | **0.00%** |
| **3. Unsupervised Heuristic: Top-100 Max(\|V1..V28\|)/ngày** | Ngày tương đối 0 | 100 | **23** | 77 | **23.00%** | **8.19%** | **23.00%** |
| **3. Unsupervised Heuristic: Top-100 Max(\|V1..V28\|)/ngày** | Ngày tương đối 1 | 100 | **12** | 88 | **12.00%** | **5.69%** | **12.00%** |
| **3. Unsupervised Heuristic: Top-100 Max(\|V1..V28\|)/ngày** | **TỔNG 2 NGÀY (200 GD)** | **200** | **35** | **165** | **17.50%** | **7.11%** | **17.50%** |

- **Bài học kinh doanh đắt giá từ OLAP 5:**
  - **Luật thủ công truyền thống ("Rà soát 100 giao dịch có số tiền `Amount` lớn nhất trong ngày") thất bại hoàn toàn:** Bắt được **`0` vụ gian lận (`0.00%`)** ở cả Ngày 0 lẫn Ngày 1! Toàn bộ 200 giao dịch có giá trị lớn nhất đều là giao dịch hợp lệ (`is_fraud = 0`), trong khi giao dịch gian lận lớn nhất trong toàn tập dữ liệu chỉ là `2,125.87`.
  - Chỉ riêng một phép xếp hạng không giám sát đơn giản trên không gian PCA (`Top-100 Max(|V1..V28|)/ngày`) đã bắt được **`35` vụ gian lận / 200 ca rà soát (`Precision@100 = 17.50%`, đạt `17.50%` so với trần lý thuyết 200 vụ — cao gấp >100 lần so với rà soát ngẫu nhiên)**. Đây là mốc Baseline thực tế để các mô hình Isolation Forest, LOF (Huy — D) và Supervised (Mong — E) vượt qua.

---

## 2. Danh Mục 6 Dashboard Views Phục Vụ Apache Superset (`sql/04-dashboard-views.sql`)

Toàn bộ 6 SQL Views đã được khởi tạo trong schema `public` của database `dm_course` (khớp 100% với tên bảng và tên cột trong code SQL):

| STT | Tên View trong PostgreSQL | Grain & Mục đích hiển thị trên Apache Superset | Các cột chính trong View |
| :---: | :--- | :--- | :--- |
| **1** | **`vw_dash_01_daily_budget_kpi`** | **KPI Card & Bảng Trần lý thuyết ngân sách 100 GD/ngày:** So sánh song song cả 2 chế độ dữ liệu (`Toàn bộ dữ liệu gốc 284.807 GD` và `Đã khử trùng DQ-01 283.726 GD`) trên từng ngày tương đối. | `che_do_du_lieu`, `date_key`, `rel_day_label`, `tong_giao_dich`, `tong_gian_lan`, `ty_le_gian_lan_pct`, `ngan_sach_ra_soat_ngay`, `fraud_toi_da_bat_duoc`, `fraud_vuot_ngan_sach_bi_bo_sot`, `tran_recall_ly_thuyet_pct` |
| **2** | **`vw_dash_02_amount_band_risk`** | **Bar / Dual-Axis Chart theo 7 dải số tiền (`Dim_AmountBand`):** Phân tích số giao dịch, số gian lận, tỷ lệ gian lận (%) và tổng tiền gian lận theo 7 dải (`0`, `0–10`, `10–50`, `50–100`, `100–500`, `500–1000`, `>1000`), có bộ lọc `date_key` và `is_duplicate`. | `amount_band_key`, `band_order`, `band_code`, `band_label`, `date_key`, `rel_day_label`, `is_duplicate`, `so_giao_dich`, `so_gian_lan`, `so_gd_hop_le`, `ty_le_gian_lan_pct`, `tong_so_tien`, `tong_so_tien_gian_lan` |
| **3** | **`vw_dash_03_relative_hour_trend`** | **Time-Series Bar + Line Chart qua 48 giờ tương đối (`0..47`):** Xu hướng lưu lượng giao dịch, số gian lận (gốc & khử trùng), tỷ lệ gian lận (%) và trung bình trượt 3 giờ (`trung_binh_truot_3h_fraud`). | `hour_key`, `rel_hour_label`, `date_key`, `rel_day_label`, `hour_in_rel_day`, `so_giao_dich`, `so_gian_lan`, `so_gd_khu_trung`, `so_gian_lan_khu_trung`, `ty_le_gian_lan_pct`, `trung_binh_truot_3h_fraud`, `interpretation_note` |
| **4** | **`vw_dash_04_top100_review_queue`** | **Bảng Hàng đợi Ưu tiên Rà soát Top-100 GD/ngày:** Tách biệt rõ từng phương pháp xếp hạng (`phuong_phap_xep_hang`: Baseline PCA `Max(\|V\|)`, `Isolation Forest`, `LOF`, `Supervised`) — **không trộn thang đo** — kèm cột `trang_thai_diem_mo_hinh` cảnh báo rõ khi chưa nạp điểm ML. | `txn_id`, `date_key`, `rel_day_label`, `hour_key`, `band_order`, `dai_so_tien`, `amount`, `is_fraud`, `ket_qua_ra_soat`, `phuong_phap_xep_hang`, `trang_thai_diem_mo_hinh`, `diem_xep_hang_rieng`, `hang_ra_soat_trong_ngay` |
| **5** | **`vw_dash_05_score_distribution`** | **Histogram / Bar Chart phân phối độ lệch cực đại:** So sánh phân phối biên độ `Max(\|V1..V28\|)` theo 7 mức (`bucket_order 1..7`) giữa lớp Hợp pháp (`0`) và Gian lận (`1`), có cột `loai_thang_do` và `trang_thai_diem_mo_hinh` ghi rõ đây là thang đo PCA gốc. | `loai_thang_do`, `trang_thai_diem_mo_hinh`, `date_key`, `rel_day_label`, `bucket_order`, `dai_muc_bat_thuong`, `is_fraud`, `nhom_nhan`, `is_duplicate`, `so_giao_dich` |
| **6** | **`vw_dash_06_model_vs_baseline_comparison`** | **Biểu đồ Tổng kết So sánh Mô hình vs. Baseline @ 100 GD/ngày:** Đặt cạnh nhau 4 Baseline, 3 Mô hình ML (`Isolation Forest`, `LOF`, `Supervised`) và `Trần lý thuyết` kèm cột `trang_thai_du_lieu`. | `method_order`, `ten_mo_hinh`, `ho_bai_toan`, `trang_thai_du_lieu`, `date_key`, `rel_day_label`, `so_gd_ra_soat`, `so_fraud_bat_duoc`, `so_bao_dong_gia_fp`, `tong_fraud_ngay`, `precision_at_100_pct`, `recall_pct` |

---

## 3. Biên Bản Bàn Giao Chính Thức (Chuẩn Mục G — `File_Train.docx`)

```markdown
### BIÊN BẢN BÀN GIAO: THÀNH VIÊN C (QUỲNH) → THÀNH VIÊN E (MONG), B (CƯỜNG) & D (HUY)
- **Người giao:** Thành viên C — Quỳnh (Kỹ sư Dữ liệu / Kho dữ liệu PostgreSQL, Star Schema & OLAP)
- **Người nhận chính:** Thành viên E — Mong (Đánh giá thực nghiệm, Dashboard Apache Superset & Báo cáo tổng hợp)
- **Người nhận phối hợp:** Thành viên B — Cường (Tiền xử lý) & Thành viên D — Huy (Mô hình bất thường & Có giám sát)
- **Ngày giờ bàn giao:** 2026-10-30

#### 1. Danh sách file đầu ra đã tạo và kiểm chứng
1. `outputs/star_schema_erd.md` & `figures/fig04_star_schema_erd.png` — Tài liệu thiết kế Grain, sơ đồ ERD (Mermaid + Ảnh PNG 300 DPI), đặc tả cột và quy tắc toàn vẹn.
2. `sql/01-staging.sql` — Tạo bảng staging `stg_raw_transactions` và `stg_model_scores`, nạp `284,807` dòng từ `data/raw/creditcard.csv`.
3. `sql/02-star-schema.sql` — Tạo 4 bảng chiều (`Dim_Date`, `Dim_Hour`, `Dim_AmountBand`, `Dim_Channel`) và bảng sự kiện `Fact_Transaction` kèm PK/FK và 9 chỉ mục.
4. `sql/03-transform.sql` — Biến đổi và nạp dữ liệu từ Staging sang Star Schema, gán các cờ chất lượng dữ liệu (`is_duplicate`, `is_zero_amount`, `has_extreme_v_z10`, `max_abs_v`) và chạy truy vấn đối soát toàn vẹn.
5. `sql/04-dashboard-views.sql` — Khởi tạo 6 SQL Views (`vw_dash_01` đến `vw_dash_06`) phục vụ trực tiếp cho Apache Superset.
6. `sql/05-load-model-scores.sql` & `outputs/model_scores_warehouse.csv` — Script nạp điểm mô hình từ CSV vào `stg_model_scores`, tự động tính hạng `iforest_daily_rank`, `lof_daily_rank`, `sup_daily_rank` bằng `RANK() OVER (PARTITION BY date_key ...)` và cập nhật `Fact_Transaction`.
7. `sql/olap_queries.sql` — Bộ 5 truy vấn OLAP (`ROLLUP`, `CUBE`, `GROUPING SETS`, `WINDOW FUNCTIONS`) trả lời câu hỏi kinh doanh.
8. `sql/run_warehouse.ps1`, `sql/run_olap_and_views.ps1`, `sql/run_all.sh`, `sql/run_pipeline.py` — Bộ script chạy tự động đa nền tảng (Windows PowerShell, Linux/macOS Bash và Python).
9. `outputs/warehouse_validation_report.md` & `outputs/postgres_execution_log.txt` — Báo cáo đối soát toàn vẹn dữ liệu và log chạy thật trên PostgreSQL 16.15-5.
10. `outputs/olap_and_handover_summary.md` — Báo cáo tổng hợp kết quả 5 truy vấn OLAP, từ điển 6 Views Superset và Biên bản bàn giao này.

#### 2. Chuỗi kết nối cơ sở dữ liệu & Lệnh chạy lại từ đầu (Đa nền tảng & Idempotent)
- **SQLALCHEMY URI (dùng cho Apache Superset hoặc Python):**
  `postgresql+psycopg2://dm:dm@localhost:5432/dm_course`
- **Cách 1 — Chạy bằng Python (Đa nền tảng Windows / macOS / Linux):**
  ```bash
  python sql/run_pipeline.py
  ```
- **Cách 2 — Chạy trên Windows PowerShell:**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "sql\run_warehouse.ps1"
  powershell -ExecutionPolicy Bypass -File "sql\run_olap_and_views.ps1"
  ```
- **Cách 3 — Chạy trên Linux / macOS / WSL / Git Bash:**
  ```bash
  bash sql/run_all.sh
  ```

#### 3. Hướng dẫn tích hợp điểm mô hình cho Thành viên D (Huy) & E (Mong) (Bước C12)
Khi chạy xong thực nghiệm mô hình, Huy (D) và Mong (E) ghi đè file `outputs/model_scores_warehouse.csv` theo đúng 6 cột:
`txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note`
(trong đó `txn_id` là số thứ tự dòng `1..284807` trong `creditcard.csv`, `split_set` nhận `'TRAIN'`, `'VAL'`, hoặc `'TEST'`).
Sau đó chạy:
```bash
psql -U dm -h localhost -p 5432 -d dm_course -v ON_ERROR_STOP=1 -f "sql/05-load-model-scores.sql"
```
Script `05-load-model-scores.sql` sẽ tự động nạp vào `stg_model_scores`, tính `iforest_daily_rank`, `lof_daily_rank`, `sup_daily_rank` trong từng ngày tương đối và cập nhật `Fact_Transaction`. Các View `vw_dash_04_top100_review_queue` và `vw_dash_06_model_vs_baseline_comparison` sẽ tự động hiển thị kết quả của cả 3 mô hình!
```
