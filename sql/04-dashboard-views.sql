-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Script 04: Các View chuẩn hóa cho Dashboard Apache Superset (sql/04-dashboard-views.sql)
-- Người thực hiện: Quỳnh (Thành viên C) · Bàn giao cho: Mong (Thành viên E)
-- Mục đích (Bước C11 – C12): Cung cấp 6 Views có Grain rõ ràng, có trường Filter
-- và tính sẵn Metric nhất quán với Notebook/OLAP để Mong dựng 4–6 biểu đồ Superset.
-- =============================================================================

SET client_encoding = 'UTF8';
BEGIN;

-- =============================================================================
-- VIEW 1: vw_dash_01_daily_budget_kpi
-- Phục vụ Biểu đồ 1: KPI Tổng quan & Trần lý thuyết của Ngân sách 100 GD/ngày
-- Câu hỏi trả lời: "Với ngân sách rà soát 100 giao dịch/ngày, tối đa ta có thể
-- bắt được bao nhiêu % gian lận trên từng ngày tương đối?"
-- Grain: 1 dòng = 1 Ngày tương đối x Chế độ dữ liệu (Gốc / Đã khử trùng DQ-01)
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_01_daily_budget_kpi AS
SELECT
    'Toàn bộ dữ liệu gốc (284.807 GD)' AS che_do_du_lieu,
    d.date_key,
    d.rel_day_label,
    COUNT(*) AS tong_giao_dich,
    SUM(f.is_fraud) AS tong_gian_lan,
    ROUND(AVG(f.is_fraud) * 100, 4) AS ty_le_gian_lan_pct,
    d.daily_review_budget AS ngan_sach_ra_soat_ngay,
    LEAST(d.daily_review_budget, SUM(f.is_fraud)::INT) AS fraud_toi_da_bat_duoc,
    GREATEST(0, SUM(f.is_fraud)::INT - d.daily_review_budget) AS fraud_vuot_ngan_sach_bi_bo_sot,
    ROUND(LEAST(d.daily_review_budget, SUM(f.is_fraud)::INT)::NUMERIC / SUM(f.is_fraud) * 100, 2) AS tran_recall_ly_thuyet_pct
FROM Fact_Transaction f
JOIN Dim_Date d ON d.date_key = f.date_key
GROUP BY d.date_key, d.rel_day_label, d.daily_review_budget

UNION ALL

SELECT
    'Đã khử trùng DQ-01 (283.726 GD)' AS che_do_du_lieu,
    d.date_key,
    d.rel_day_label,
    COUNT(*) AS tong_giao_dich,
    SUM(f.is_fraud) AS tong_gian_lan,
    ROUND(AVG(f.is_fraud) * 100, 4) AS ty_le_gian_lan_pct,
    d.daily_review_budget AS ngan_sach_ra_soat_ngay,
    LEAST(d.daily_review_budget, SUM(f.is_fraud)::INT) AS fraud_toi_da_bat_duoc,
    GREATEST(0, SUM(f.is_fraud)::INT - d.daily_review_budget) AS fraud_vuot_ngan_sach_bi_bo_sot,
    ROUND(LEAST(d.daily_review_budget, SUM(f.is_fraud)::INT)::NUMERIC / SUM(f.is_fraud) * 100, 2) AS tran_recall_ly_thuyet_pct
FROM Fact_Transaction f
JOIN Dim_Date d ON d.date_key = f.date_key
WHERE f.is_duplicate = FALSE
GROUP BY d.date_key, d.rel_day_label, d.daily_review_budget;

COMMENT ON VIEW vw_dash_01_daily_budget_kpi IS
'View Dashboard 1: Tổng quan lưu lượng, số gian lận và trần Recall lý thuyết ứng với ngân sách 100 GD/ngày.';


-- =============================================================================
-- VIEW 2: vw_dash_02_amount_band_risk
-- Phục vụ Biểu đồ 2: Phân bố Gian lận & Tỷ lệ Rủi ro theo 7 Dải Số tiền (Amount Band)
-- Câu hỏi trả lời: "Dải số tiền giao dịch nào có tỷ lệ gian lận bất thường cao nhất?"
-- Grain: 1 dòng = 1 Dải số tiền (band_order 1..7) x 1 Ngày tương đối x Cờ is_duplicate
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_02_amount_band_risk AS
SELECT
    ab.amount_band_key,
    ab.band_order,
    ab.band_code,
    ab.band_label,
    d.date_key,
    d.rel_day_label,
    f.is_duplicate,
    COUNT(*) AS so_giao_dich,
    SUM(f.is_fraud) AS so_gian_lan,
    COUNT(*) - SUM(f.is_fraud) AS so_gd_hop_le,
    ROUND(AVG(f.is_fraud) * 100, 3) AS ty_le_gian_lan_pct,
    ROUND(SUM(f.amount), 2) AS tong_so_tien,
    ROUND(SUM(f.amount) FILTER (WHERE f.is_fraud = 1), 2) AS tong_so_tien_gian_lan
FROM Fact_Transaction f
JOIN Dim_AmountBand ab ON ab.amount_band_key = f.amount_band_key
JOIN Dim_Date d        ON d.date_key = f.date_key
GROUP BY
    ab.amount_band_key, ab.band_order, ab.band_code, ab.band_label,
    d.date_key, d.rel_day_label, f.is_duplicate;

COMMENT ON VIEW vw_dash_02_amount_band_risk IS
'View Dashboard 2: Số giao dịch, số gian lận và tỷ lệ % gian lận theo 7 dải Amount (sắp xếp theo band_order 1..7).';


-- =============================================================================
-- VIEW 3: vw_dash_03_relative_hour_trend
-- Phục vụ Biểu đồ 3: Diễn biến Giao dịch & Gian lận theo 48 Giờ tương đối (0..47)
-- Câu hỏi trả lời: "Gian lận biến động như thế nào qua 48 giờ tương đối kể từ giao dịch đầu?"
-- Grain: 1 dòng = 1 Giờ tương đối (hour_key 0..47)
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_03_relative_hour_trend AS
SELECT
    h.hour_key,
    h.rel_hour_label,
    h.date_key,
    d.rel_day_label,
    h.hour_in_rel_day,
    COUNT(*) AS so_giao_dich,
    SUM(f.is_fraud) AS so_gian_lan,
    COUNT(*) FILTER (WHERE NOT f.is_duplicate) AS so_gd_khu_trung,
    SUM(f.is_fraud) FILTER (WHERE NOT f.is_duplicate) AS so_gian_lan_khu_trung,
    ROUND(AVG(f.is_fraud) * 100, 3) AS ty_le_gian_lan_pct,
    ROUND(
        AVG(SUM(f.is_fraud)) OVER (ORDER BY h.hour_key ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING),
        2
    ) AS trung_binh_truot_3h_fraud,
    h.interpretation_note
FROM Fact_Transaction f
JOIN Dim_Hour h ON h.hour_key = f.hour_key
JOIN Dim_Date d ON d.date_key = h.date_key
GROUP BY h.hour_key, h.rel_hour_label, h.date_key, d.rel_day_label, h.hour_in_rel_day, h.interpretation_note;

COMMENT ON VIEW vw_dash_03_relative_hour_trend IS
'View Dashboard 3: Chuỗi thời gian theo 48 giờ tương đối (0..47). Không diễn giải thành giờ đồng hồ thật.';


-- =============================================================================
-- VIEW 4: vw_dash_04_top100_review_queue
-- Phục vụ Biểu đồ 4: Hàng đợi Ưu tiên Rà soát Top-100 Giao dịch Mỗi Ngày tương đối
-- Câu hỏi trả lời: "Danh sách 100 giao dịch ưu tiên cần nhân viên rà soát mỗi ngày
-- gồm những giao dịch nào và bao nhiêu ca là gian lận thật vs. báo động giả (FP)?"
-- Grain: 1 dòng = 1 giao dịch nằm trong Top-100 của Ngày tương đối theo từng phương pháp xếp hạng
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_04_top100_review_queue AS
WITH all_rankings AS (
    SELECT
        f.txn_id,
        f.date_key,
        d.rel_day_label,
        f.hour_key,
        h.rel_hour_label,
        ab.band_order,
        ab.band_code AS dai_so_tien,
        f.time_sec,
        f.amount,
        f.is_zero_amount,
        f.is_duplicate,
        f.max_abs_v,
        f.has_extreme_v_z10,
        f.is_fraud,
        CASE WHEN f.is_fraud = 1 THEN 'Gian lận thật (True Positive)' ELSE 'Khách hợp pháp bị xét (False Positive)' END AS ket_qua_ra_soat,
        COALESCE(f.split_set, 'FULL_WAREHOUSE') AS split_set,
        -- Xếp hạng theo Điểm mô hình chính (nếu đã nạp từ Huy D) hoặc dùng Unsupervised PCA Max(|V*|) làm mặc định
        COALESCE(f.iforest_score, f.anomaly_score, f.max_abs_v) AS diem_bat_thuong_chinh,
        CASE
            WHEN f.iforest_score IS NOT NULL THEN 'Isolation Forest (Huy - D)'
            WHEN f.anomaly_score IS NOT NULL THEN 'Anomaly Score (Tích hợp)'
            ELSE 'Unsupervised PCA Extreme Max(|V1..V28|)'
        END AS nguon_diem_xep_hang,
        ROW_NUMBER() OVER (
            PARTITION BY f.date_key
            ORDER BY COALESCE(f.iforest_score, f.anomaly_score, f.max_abs_v) DESC, f.txn_id ASC
        ) AS hang_ra_soat_trong_ngay
    FROM Fact_Transaction f
    JOIN Dim_Date d        ON d.date_key = f.date_key
    JOIN Dim_Hour h        ON h.hour_key = f.hour_key
    JOIN Dim_AmountBand ab ON ab.amount_band_key = f.amount_band_key
)
SELECT *
FROM all_rankings
WHERE hang_ra_soat_trong_ngay <= 100;

COMMENT ON VIEW vw_dash_04_top100_review_queue IS
'View Dashboard 4: Hàng đợi Top-100 giao dịch rủi ro cao nhất mỗi ngày tương đối (tổng 200 giao dịch cho 2 ngày).';


-- =============================================================================
-- VIEW 5: vw_dash_05_score_distribution
-- Phục vụ Biểu đồ 5: Phân phối Mức độ Bất thường giữa Giao dịch Thường vs. Gian lận
-- Câu hỏi trả lời: "Điểm bất thường tách biệt nhóm gian lận khỏi nhóm hợp pháp ở ngưỡng nào?"
-- Grain: 1 dòng = 1 Dải mức độ lệch (Score Bucket) x Nhãn (is_fraud) x Ngày tương đối
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_05_score_distribution AS
WITH bucketed AS (
    SELECT
        f.date_key,
        d.rel_day_label,
        f.is_fraud,
        CASE WHEN f.is_fraud = 1 THEN '1 - Gian lận (Fraud)' ELSE '0 - Hợp pháp (Normal)' END AS nhom_nhan,
        f.is_duplicate,
        CASE
            WHEN f.max_abs_v < 2  THEN 1
            WHEN f.max_abs_v < 4  THEN 2
            WHEN f.max_abs_v < 6  THEN 3
            WHEN f.max_abs_v < 10 THEN 4
            WHEN f.max_abs_v < 15 THEN 5
            WHEN f.max_abs_v < 25 THEN 6
            ELSE 7
        END AS bucket_order,
        CASE
            WHEN f.max_abs_v < 2  THEN '1. Rất thấp (< 2)'
            WHEN f.max_abs_v < 4  THEN '2. Thấp [2, 4)'
            WHEN f.max_abs_v < 6  THEN '3. Trung bình [4, 6)'
            WHEN f.max_abs_v < 10 THEN '4. Cao [6, 10)'
            WHEN f.max_abs_v < 15 THEN '5. Rất cao [10, 15) (|z|>10)'
            WHEN f.max_abs_v < 25 THEN '6. Cực đoan [15, 25)'
            ELSE                       '7. Đặc biệt cực đoan (>= 25)'
        END AS dai_muc_bat_thuong
    FROM Fact_Transaction f
    JOIN Dim_Date d ON d.date_key = f.date_key
)
SELECT
    date_key,
    rel_day_label,
    bucket_order,
    dai_muc_bat_thuong,
    is_fraud,
    nhom_nhan,
    is_duplicate,
    COUNT(*) AS so_giao_dich
FROM bucketed
GROUP BY date_key, rel_day_label, bucket_order, dai_muc_bat_thuong, is_fraud, nhom_nhan, is_duplicate;

COMMENT ON VIEW vw_dash_05_score_distribution IS
'View Dashboard 5: Phân phối điểm bất thường theo dải để vẽ biểu đồ Histogram/Bar so sánh lớp 0 và lớp 1.';


-- =============================================================================
-- VIEW 6: vw_dash_06_model_vs_baseline_comparison
-- Phục vụ Biểu đồ 6: So sánh Hiệu năng Mô hình vs. Baseline dưới Ngân sách 100 GD/ngày
-- Câu hỏi trả lời: "Các phương pháp phát hiện bất thường và phân lớp cải thiện
-- Precision@100 và Recall gấp bao nhiêu lần so với Baseline ngẫu nhiên / luật thủ công?"
-- Grain: 1 dòng = 1 Phương pháp x 1 Ngày tương đối
-- =============================================================================
CREATE OR REPLACE VIEW vw_dash_06_model_vs_baseline_comparison AS
WITH ranked AS (
    SELECT
        f.txn_id,
        f.date_key,
        d.rel_day_label,
        d.daily_review_budget,
        f.is_fraud,
        ROW_NUMBER() OVER (PARTITION BY f.date_key ORDER BY f.amount DESC, f.txn_id ASC)    AS rnk_amount,
        ROW_NUMBER() OVER (PARTITION BY f.date_key ORDER BY f.max_abs_v DESC, f.txn_id ASC) AS rnk_max_v,
        f.iforest_daily_rank,
        f.lof_daily_rank,
        f.sup_daily_rank
    FROM Fact_Transaction f
    JOIN Dim_Date d ON d.date_key = f.date_key
)
SELECT
    1 AS method_order,
    'Baseline 0: Đoán toàn bộ Không gian lận (Bẫy Accuracy 99.83%)' AS ten_mo_hinh,
    'Baseline' AS ho_bai_toan,
    date_key,
    rel_day_label,
    0 AS so_gd_ra_soat,
    0::NUMERIC AS so_fraud_bat_duoc,
    0::NUMERIC AS so_bao_dong_gia_fp,
    SUM(is_fraud) AS tong_fraud_ngay,
    0.00 AS precision_at_100_pct,
    0.00 AS recall_pct
FROM ranked
GROUP BY date_key, rel_day_label

UNION ALL

SELECT
    2 AS method_order,
    'Baseline 1: Rà soát ngẫu nhiên 100 GD/ngày (Kỳ vọng)' AS ten_mo_hinh,
    'Baseline' AS ho_bai_toan,
    date_key,
    rel_day_label,
    100 AS so_gd_ra_soat,
    ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS so_fraud_bat_duoc,
    ROUND(100.0 - (100.0 * SUM(is_fraud) / COUNT(*)), 2) AS so_bao_dong_gia_fp,
    SUM(is_fraud) AS tong_fraud_ngay,
    ROUND(100.0 * SUM(is_fraud) / COUNT(*), 2) AS precision_at_100_pct,
    ROUND((100.0 * SUM(is_fraud) / COUNT(*)) / SUM(is_fraud) * 100, 2) AS recall_pct
FROM ranked
GROUP BY date_key, rel_day_label

UNION ALL

SELECT
    3 AS method_order,
    'Baseline 2: Luật thủ công Top-100 Amount cao nhất/ngày' AS ten_mo_hinh,
    'Baseline (Heuristic)' AS ho_bai_toan,
    date_key,
    rel_day_label,
    100 AS so_gd_ra_soat,
    SUM(is_fraud) FILTER (WHERE rnk_amount <= 100)::NUMERIC AS so_fraud_bat_duoc,
    (100 - SUM(is_fraud) FILTER (WHERE rnk_amount <= 100))::NUMERIC AS so_bao_dong_gia_fp,
    SUM(is_fraud) AS tong_fraud_ngay,
    ROUND(SUM(is_fraud) FILTER (WHERE rnk_amount <= 100)::NUMERIC, 2) AS precision_at_100_pct,
    ROUND(SUM(is_fraud) FILTER (WHERE rnk_amount <= 100)::NUMERIC / SUM(is_fraud) * 100, 2) AS recall_pct
FROM ranked
GROUP BY date_key, rel_day_label

UNION ALL

SELECT
    4 AS method_order,
    'Unsupervised Heuristic: Top-100 Max(|V1..V28|) cao nhất/ngày' AS ten_mo_hinh,
    'Phát hiện bất thường (Không giám sát)' AS ho_bai_toan,
    date_key,
    rel_day_label,
    100 AS so_gd_ra_soat,
    SUM(is_fraud) FILTER (WHERE rnk_max_v <= 100)::NUMERIC AS so_fraud_bat_duoc,
    (100 - SUM(is_fraud) FILTER (WHERE rnk_max_v <= 100))::NUMERIC AS so_bao_dong_gia_fp,
    SUM(is_fraud) AS tong_fraud_ngay,
    ROUND(SUM(is_fraud) FILTER (WHERE rnk_max_v <= 100)::NUMERIC, 2) AS precision_at_100_pct,
    ROUND(SUM(is_fraud) FILTER (WHERE rnk_max_v <= 100)::NUMERIC / SUM(is_fraud) * 100, 2) AS recall_pct
FROM ranked
GROUP BY date_key, rel_day_label

UNION ALL

SELECT
    9 AS method_order,
    'Trần lý thuyết: Bộ xếp hạng hoàn hảo (Giới hạn ngân sách 100/ngày)' AS ten_mo_hinh,
    'Giới hạn lý thuyết (Ceiling)' AS ho_bai_toan,
    date_key,
    rel_day_label,
    100 AS so_gd_ra_soat,
    LEAST(100, SUM(is_fraud)::INT)::NUMERIC AS so_fraud_bat_duoc,
    0::NUMERIC AS so_bao_dong_gia_fp,
    SUM(is_fraud) AS tong_fraud_ngay,
    100.00 AS precision_at_100_pct,
    ROUND(LEAST(100, SUM(is_fraud)::INT)::NUMERIC / SUM(is_fraud) * 100, 2) AS recall_pct
FROM ranked
GROUP BY date_key, rel_day_label;

COMMENT ON VIEW vw_dash_06_model_vs_baseline_comparison IS
'View Dashboard 6: So sánh trực tiếp Precision@100, Recall và số dương tính giả (FP) giữa các phương pháp và trần lý thuyết.';

COMMIT;

