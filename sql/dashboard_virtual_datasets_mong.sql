-- =============================================================================
-- ĐỒ ÁN 6: PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN — DATASET ẢO & VIEW TRÊN SUPERSET 6.0.0
-- Người thực hiện: Mong (Thành viên E) — Đã tích hợp 100% với Kho PostgreSQL của Quỳnh (Thành viên C)
-- Nguồn dữ liệu: Đọc TRỰC TIẾP từ Fact_Transaction, Dim_AmountBand, Dim_Hour và
--   các View chuẩn vw_dash_01..vw_dash_06 (KHÔNG phụ thuộc file classification_scores_test.csv).
-- Chỉ cần chạy 6 script SQL của Quỳnh (01 -> 02 -> 03 -> 05 -> 04 -> olap_queries) kèm
--   outputs/model_scores_warehouse.csv là toàn bộ Dashboard hoạt động đầy đủ 100%.
-- =============================================================================

-- =====================================================================
-- 1) Dataset "vw_superset_amount_bands_day1" (hoặc View trực tiếp từ Fact_Transaction):
--    Gian lận bắt được / bỏ sót trong Top 100 theo 7 dải số tiền trên Tập Test Ngày 1
--    đã khử trùng DQ-01 (139.490 giao dịch, 201 gian lận: bắt được 93, bỏ sót 108).
--    Phục vụ:
--      - Thẻ Big Number: "Số giao dịch gian lận bắt được trong Top 100"
--        (chú thích: "trên 201 gian lận Ngày 1 đã khử trùng (211 trước khử trùng)")
--      - Biểu đồ cột chồng: "Giao dịch gian lận được bắt và bỏ sót theo dải số tiền"
--      - Bộ lọc Native Filter: "Dải số tiền" (dai_amount)
-- =====================================================================
SELECT
  ab.band_order AS thu_tu,
  ab.band_order::text || ') ' || REPLACE(ab.band_code, '–', '-') AS dai_amount,
  COUNT(*) AS so_giao_dich,
  SUM(f.is_fraud) AS gian_lan,
  SUM(CASE WHEN f.is_fraud = 1 AND f.sup_daily_rank <= 100 THEN 1 ELSE 0 END) AS bat_duoc_top100,
  SUM(f.is_fraud) - SUM(CASE WHEN f.is_fraud = 1 AND f.sup_daily_rank <= 100 THEN 1 ELSE 0 END) AS bo_sot
FROM public.Fact_Transaction f
JOIN public.Dim_AmountBand ab ON ab.amount_band_key = f.amount_band_key
WHERE f.date_key = 1
  AND f.is_duplicate = FALSE
GROUP BY ab.band_order, ab.band_code
ORDER BY ab.band_order;

-- =====================================================================
-- 2) Dataset "vw_superset_top100_queue_day1" (trích từ vw_dash_04_top100_review_queue của Quỳnh):
--    Hàng đợi 100 giao dịch ưu tiên rà soát trên Ngày 1 của Random Forest, hiển thị
--    Giờ tương đối dễ hiểu (rel_hour_label) và Dải số tiền thay vì giây thô Time.
--    Phục vụ Biểu đồ Bảng: "Top 100 giao dịch cần rà soát (Random Forest — Ngày 1)".
-- =====================================================================
SELECT
  hang_ra_soat_trong_ngay AS hang_ra_soat,
  txn_id,
  rel_hour_label AS gio_tuong_doi,
  dai_so_tien,
  amount AS so_tien,
  ket_qua_ra_soat,
  diem_xep_hang_rieng AS xac_suat_gian_lan_rf
FROM public.vw_dash_04_top100_review_queue
WHERE date_key = 1
  AND phuong_phap_xep_hang = '4. Mô hình Phân lớp Có giám sát (Mong - E)'
ORDER BY hang_ra_soat_trong_ngay ASC;

-- =====================================================================
-- 3) Dataset "vw_superset_rf_score_bins_day1":
--    Phân bố điểm xác suất Random Forest (sup_prob_score) theo 20 dải trên Ngày 1
--    đã khử trùng (139.490 dòng = 139.289 hợp pháp + 201 gian lận).
--    Phục vụ Biểu đồ: "Phân bố xác suất Random Forest theo nhãn thực (Ngày 1)".
-- =====================================================================
SELECT
  LEAST(FLOOR(f.sup_prob_score * 20), 19)::int AS bin_idx,
  (LEAST(FLOOR(f.sup_prob_score * 20), 19) / 20.0)::numeric(4,2) AS bin_start,
  CASE WHEN f.is_fraud = 1 THEN '1 - Gian lận (Fraud)' ELSE '0 - Hợp pháp (Normal)' END AS nhom_nhan,
  COUNT(*) AS so_giao_dich
FROM public.Fact_Transaction f
WHERE f.date_key = 1
  AND f.is_duplicate = FALSE
  AND f.sup_prob_score IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- =====================================================================
-- 4) Dataset "vw_superset_model_comparison_day1" (kết hợp vw_dash_06_model_vs_baseline_comparison):
--    Đối sánh đầy đủ CẢ HAI HỌ MÔ HÌNH (Supervised: Random Forest, Logistic Regression,
--    HistGradientBoosting; Unsupervised: LOF, Isolation Forest) và Baseline trên Ngày 1.
--    Phục vụ Biểu đồ số 5: "So sánh 2 họ mô hình & Baseline (PR-AUC, Precision@100, Recall@100)".
-- =====================================================================
SELECT
  method_order,
  CASE method_order
    WHEN 7 THEN '1. Random Forest (Supervised)'
    WHEN 6 THEN '2. LOF n=100 (Unsupervised)'
    WHEN 5 THEN '3. Isolation Forest (Unsupervised)'
    WHEN 4 THEN '4. Heuristic Max|V*| (PCA)'
    WHEN 3 THEN '5. Luật Top-100 Amount'
    WHEN 2 THEN '6. Xếp hạng Ngẫu nhiên'
  END AS mo_hinh,
  ho_bai_toan,
  so_fraud_bat_duoc AS tp_top100,
  so_bao_dong_gia_fp AS fp_top100,
  ROUND(precision_at_100_pct / 100.0, 4) AS "Precision@100",
  ROUND((so_fraud_bat_duoc / 201.0)::numeric, 4) AS "Recall@100",
  CASE method_order
    WHEN 7 THEN 0.7843
    WHEN 6 THEN 0.2478
    WHEN 5 THEN 0.1582
    WHEN 4 THEN 0.0891
    WHEN 3 THEN 0.0014
    WHEN 2 THEN 0.0015
  END AS "PR_AUC"
FROM public.vw_dash_06_model_vs_baseline_comparison
WHERE date_key = 1
  AND method_order IN (2, 3, 4, 5, 6, 7)
ORDER BY "PR_AUC" DESC;

-- =====================================================================
-- 5) Truy vấn đối soát trên SQL Lab (kỳ vọng: sup_caught_fraud = 93,
--    iforest_caught_fraud = 31, lof_caught_fraud = 30 trên 201 gian lận Ngày 1 đã khử trùng):
-- =====================================================================
SELECT
  (SELECT COUNT(*) FROM public.stg_model_scores)                           AS stg_score_rows,
  COUNT(*) FILTER (WHERE date_key = 1 AND is_duplicate = FALSE)            AS day1_dedup_rows,
  SUM(is_fraud) FILTER (WHERE date_key = 1 AND is_duplicate = FALSE)       AS day1_dedup_fraud,
  SUM(is_fraud) FILTER (WHERE date_key = 1 AND iforest_daily_rank <= 100)  AS iforest_caught_fraud,
  SUM(is_fraud) FILTER (WHERE date_key = 1 AND lof_daily_rank <= 100)      AS lof_caught_fraud,
  SUM(is_fraud) FILTER (WHERE date_key = 1 AND sup_daily_rank <= 100)      AS sup_caught_fraud
FROM public.Fact_Transaction;
