-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Bộ Truy vấn OLAP (sql/olap_queries.sql) — Bước C10 (CLO3 - Tiêu chí 4)
-- Người thực hiện: Quỳnh (Thành viên C — Data Engineer)
-- Kỹ thuật OLAP sử dụng: ROLLUP, CUBE, GROUPING SETS, WINDOW FUNCTIONS
--                       (RANK, DENSE_RANK, ROW_NUMBER, SUM/AVG OVER, LAG)
-- =============================================================================

SET client_encoding = 'UTF8';

-- =============================================================================
-- TRUY VẤN OLAP 1: ROLLUP + WINDOW FUNCTION
-- Câu hỏi nghiệp vụ: "Với ngân sách rà soát 100 giao dịch mỗi ngày, trần lý thuyết
-- tối đa bắt được bao nhiêu % gian lận (trước và sau khi khử trùng DQ-01)?"
-- =============================================================================
\echo ''
\echo '============================================================================='
\echo 'OLAP 1 (ROLLUP): Tran ly thuyet ngan sach ra soat 100 giao dich/ngay tuong doi'
\echo '============================================================================='

WITH daily_summary AS (
    SELECT
        GROUPING(d.date_key) AS is_grand_total,
        COALESCE(d.rel_day_label, 'TỔNG CỘNG TOÀN BỘ (2 NGÀY TƯƠNG ĐỐI)') AS pham_vi_ngay,
        COUNT(*) AS tong_giao_dich,
        SUM(f.is_fraud) AS tong_gian_lan,
        ROUND(AVG(f.is_fraud) * 100, 4) AS ty_le_gian_lan_pct,
        COUNT(*) FILTER (WHERE NOT f.is_duplicate) AS gd_sau_khu_trung,
        SUM(f.is_fraud) FILTER (WHERE NOT f.is_duplicate) AS gian_lan_sau_khu_trung,
        CASE
            WHEN GROUPING(d.date_key) = 0 THEN MAX(d.daily_review_budget)
            ELSE 200
        END AS ngan_sach_ra_soat,
        CASE
            WHEN GROUPING(d.date_key) = 0 THEN LEAST(MAX(d.daily_review_budget), SUM(f.is_fraud)::INT)
            ELSE 200
        END AS max_fraud_bat_duoc_raw,
        CASE
            WHEN GROUPING(d.date_key) = 0 THEN LEAST(MAX(d.daily_review_budget), (SUM(f.is_fraud) FILTER (WHERE NOT f.is_duplicate))::INT)
            ELSE 200
        END AS max_fraud_bat_duoc_dedup
    FROM Fact_Transaction f
    JOIN Dim_Date d ON d.date_key = f.date_key
    GROUP BY ROLLUP (d.date_key, d.rel_day_label)
    HAVING GROUPING(d.date_key) = GROUPING(d.rel_day_label)
)
SELECT
    pham_vi_ngay,
    tong_giao_dich,
    tong_gian_lan,
    ty_le_gian_lan_pct,
    ngan_sach_ra_soat,
    ROUND(ngan_sach_ra_soat::NUMERIC / tong_giao_dich * 100, 4) AS ty_le_duoc_ra_soat_pct,
    max_fraud_bat_duoc_raw,
    ROUND(max_fraud_bat_duoc_raw::NUMERIC / tong_gian_lan * 100, 2) AS tran_recall_raw_pct,
    gian_lan_sau_khu_trung,
    ROUND(max_fraud_bat_duoc_dedup::NUMERIC / gian_lan_sau_khu_trung * 100, 2) AS tran_recall_dedup_pct
FROM daily_summary
ORDER BY is_grand_total, pham_vi_ngay;


-- =============================================================================
-- TRUY VẤN OLAP 2: ROLLUP + WINDOW FUNCTIONS (SUM OVER, RANK OVER)
-- Câu hỏi: "Gian lận phân bổ như thế nào theo Dải số tiền (Dim_AmountBand)
-- và theo từng Ngày tương đối? Dải tiền nào có tỷ lệ gian lận rủi ro cao nhất?"
-- =============================================================================
\echo ''
\echo '============================================================================='
\echo 'OLAP 2 (ROLLUP + WINDOW): Phan tich Gian lan theo Dai Amount & Ngay tuong doi'
\echo '============================================================================='

WITH band_rollup AS (
    SELECT
        GROUPING(ab.band_order) AS grp_band,
        GROUPING(d.date_key)    AS grp_day,
        ab.band_order,
        COALESCE(ab.band_code, 'ALL_BANDS') AS dai_so_tien,
        CASE
            WHEN GROUPING(d.date_key) = 1 THEN 'Cả 2 ngày (Tổng dải)'
            ELSE 'Ngày tương đối ' || d.date_key::TEXT
        END AS ngay_tuong_doi,
        COUNT(*) AS so_giao_dich,
        SUM(f.is_fraud) AS so_gian_lan,
        ROUND(AVG(f.is_fraud) * 100, 3) AS ty_le_gian_lan_pct,
        ROUND(SUM(f.amount), 2) AS tong_gia_tri_gd,
        ROUND(SUM(f.amount) FILTER (WHERE f.is_fraud = 1), 2) AS tong_gia_tri_gian_lan
    FROM Fact_Transaction f
    JOIN Dim_AmountBand ab ON ab.amount_band_key = f.amount_band_key
    JOIN Dim_Date d        ON d.date_key = f.date_key
    GROUP BY ROLLUP ((ab.band_order, ab.band_code), d.date_key)
)
SELECT
    dai_so_tien,
    ngay_tuong_doi,
    so_giao_dich,
    so_gian_lan,
    ty_le_gian_lan_pct,
    ROUND(
        so_gian_lan::NUMERIC / SUM(so_gian_lan) FILTER (WHERE grp_band = 0 AND grp_day = 1) OVER () * 100,
        2
    ) AS ty_trong_tren_tong_492_fraud_pct,
    CASE
        WHEN grp_band = 0 AND grp_day = 1 THEN
            RANK() OVER (PARTITION BY grp_band, grp_day ORDER BY ty_le_gian_lan_pct DESC)
    END AS hang_rui_ro_dai_tien,
    COALESCE(tong_gia_tri_gian_lan, 0.00) AS tong_tien_gian_lan
FROM band_rollup
WHERE grp_day = 1   -- Hiển thị bảng tổng hợp theo 7 dải khớp EDA (bỏ lọc này nếu muốn xem chi tiết 21 dòng ngày x dải)
ORDER BY grp_band, band_order;


-- =============================================================================
-- TRUY VẤN OLAP 3: CUBE (Phân tích đa chiều chéo Ngày x Cờ Amount=0 x Cờ |z|>10)
-- Câu hỏi: "Vì sao tuyệt đối KHÔNG ĐƯỢC xóa các giao dịch cực trị (|z|>10 ở V*)
-- hoặc xóa giao dịch có Amount = 0 theo phản xạ (DQ-02, DQ-04, DQ-06)?"
-- =============================================================================
\echo ''
\echo '============================================================================='
\echo 'OLAP 3 (CUBE): Da chieu Kiem chung Cam bay Xoa Outlier (DQ-02 & DQ-06)'
\echo '============================================================================='

SELECT
    CASE
        WHEN GROUPING(f.has_extreme_v_z10) = 1 THEN 'Tất cả (Mọi mức |z|)'
        WHEN f.has_extreme_v_z10 = TRUE        THEN 'Có ít nhất 1 V* với |z| > 10 (DQ-06)'
        ELSE 'Bình thường (Mọi |z| <= 10)'
    END AS nhom_duoi_nang_pca,
    CASE
        WHEN GROUPING(f.is_zero_amount) = 1 THEN 'Tất cả (Mọi Amount)'
        WHEN f.is_zero_amount = TRUE        THEN 'Amount = 0 (DQ-02)'
        ELSE 'Amount > 0'
    END AS nhom_amount_zero,
    COUNT(*) AS so_giao_dich,
    SUM(f.is_fraud) AS so_gian_lan,
    ROUND(AVG(f.is_fraud) * 100, 3) AS ty_le_gian_lan_pct,
    ROUND(
        SUM(f.is_fraud)::NUMERIC
        / NULLIF(SUM(SUM(f.is_fraud)) FILTER (WHERE GROUPING(f.has_extreme_v_z10) = 1 AND GROUPING(f.is_zero_amount) = 1) OVER (), 0)
        * 100,
        2
    ) AS phan_tram_trong_tong_492_fraud
FROM Fact_Transaction f
GROUP BY CUBE (f.has_extreme_v_z10, f.is_zero_amount)
ORDER BY GROUPING(f.has_extreme_v_z10), f.has_extreme_v_z10 DESC,
         GROUPING(f.is_zero_amount), f.is_zero_amount DESC;


-- =============================================================================
-- TRUY VẤN OLAP 4: WINDOW FUNCTIONS (Moving Average, Cumulative Sum, LAG, DENSE_RANK)
-- Câu hỏi: "Diễn biến lưu lượng giao dịch và gian lận theo 48 Giờ tương đối (0..47)
-- như thế nào? Top 10 giờ tương đối có tỷ lệ gian lận cao nhất?"
-- (Lưu ý: Giờ tương đối kể từ giao dịch đầu tiên, KHÔNG phải giờ đồng hồ thực tế)
-- =============================================================================
\echo ''
\echo '============================================================================='
\echo 'OLAP 4 (WINDOW FUNCTIONS): Top 10 Gio tuong doi co ty le gian lan cao nhat'
\echo '============================================================================='

WITH hourly_olap AS (
    SELECT
        h.hour_key,
        h.date_key AS rel_day,
        h.hour_in_rel_day,
        COUNT(*) AS so_giao_dich,
        SUM(f.is_fraud) AS so_gian_lan,
        ROUND(AVG(f.is_fraud) * 100, 3) AS ty_le_gian_lan_pct,
        -- Tổng gian lận tích lũy từ giờ 0 đến giờ hiện tại
        SUM(SUM(f.is_fraud)) OVER (ORDER BY h.hour_key ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS gian_lan_tich_luy,
        -- Trung bình trượt 3 giờ tương đối (giờ trước, giờ hiện tại, giờ sau)
        ROUND(
            AVG(SUM(f.is_fraud)) OVER (ORDER BY h.hour_key ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING),
            2
        ) AS trung_binh_truot_3h_fraud,
        -- Độ lệch số vụ gian lận so với giờ liền trước (LAG)
        SUM(f.is_fraud) - LAG(SUM(f.is_fraud), 1, 0::BIGINT) OVER (ORDER BY h.hour_key) AS thay_doi_so_voi_gio_truoc,
        -- Xếp hạng giờ có tỷ lệ gian lận cao nhất
        DENSE_RANK() OVER (ORDER BY AVG(f.is_fraud) DESC) AS hang_ty_le_gian_lan
    FROM Fact_Transaction f
    JOIN Dim_Hour h ON h.hour_key = f.hour_key
    GROUP BY h.hour_key, h.date_key, h.hour_in_rel_day
)
SELECT
    hour_key AS gio_tuong_doi,
    rel_day AS ngay_tuong_doi,
    hour_in_rel_day AS gio_chu_ky_24h,
    so_giao_dich,
    so_gian_lan,
    ty_le_gian_lan_pct,
    trung_binh_truot_3h_fraud,
    thay_doi_so_voi_gio_truoc,
    gian_lan_tich_luy,
    hang_ty_le_gian_lan
FROM hourly_olap
ORDER BY hang_ty_le_gian_lan, hour_key
LIMIT 10;


-- =============================================================================
-- TRUY VẤN OLAP 5: GROUPING SETS + ROW_NUMBER() OVER (MÔ PHỎNG HÀNG ĐỢI TOP-100/NGÀY)
-- Câu hỏi nghiệp vụ cốt lõi: "Với ngân sách rà soát 100 giao dịch mỗi ngày,
-- các luật cơ sở (Baseline: Top-100 Amount lớn nhất vs. Top-100 |V*| cực đại)
-- bắt được bao nhiêu gian lận (Precision@100, Recall, % so với trần 40.65%)?"
-- =============================================================================
\echo ''
\echo '============================================================================='
\echo 'OLAP 5 (WINDOW RANKING @100/NGAY): Danh gia Baseline tren Ngan sach 100/ngay'
\echo '============================================================================='

WITH ranked_txns AS (
    SELECT
        f.txn_id,
        f.date_key,
        f.is_fraud,
        f.is_duplicate,
        -- Quy tắc Baseline 1: Ưu tiên rà soát 100 giao dịch có số tiền (Amount) lớn nhất mỗi ngày
        ROW_NUMBER() OVER (PARTITION BY f.date_key ORDER BY f.amount DESC, f.txn_id ASC) AS rank_by_amount_desc,
        -- Quy tắc Baseline 2 (Heuristic không giám sát trên PCA): Ưu tiên 100 giao dịch có max(|V1..V28|) lớn nhất mỗi ngày
        ROW_NUMBER() OVER (PARTITION BY f.date_key ORDER BY f.max_abs_v DESC, f.txn_id ASC) AS rank_by_max_abs_v_desc
    FROM Fact_Transaction f
),
strategy_eval AS (
    SELECT
        '1. Baseline: Đoán ngẫu nhiên 100 GD/ngày (Kỳ vọng lý thuyết)' AS phuong_phap,
        d.date_key,
        100 AS so_gd_ra_soat,
        ROUND(100.0 * SUM(r.is_fraud) / COUNT(*), 2) AS so_fraud_bat_duoc,
        SUM(r.is_fraud) AS tong_fraud_trong_ngay
    FROM ranked_txns r
    JOIN Dim_Date d ON d.date_key = r.date_key
    GROUP BY d.date_key

    UNION ALL

    SELECT
        '2. Baseline Rule: Rà soát Top-100 Amount cao nhất/ngày' AS phuong_phap,
        r.date_key,
        COUNT(*) FILTER (WHERE r.rank_by_amount_desc <= 100) AS so_gd_ra_soat,
        SUM(r.is_fraud) FILTER (WHERE r.rank_by_amount_desc <= 100)::NUMERIC AS so_fraud_bat_duoc,
        SUM(r.is_fraud) AS tong_fraud_trong_ngay
    FROM ranked_txns r
    GROUP BY r.date_key

    UNION ALL

    SELECT
        '3. Unsupervised Heuristic: Top-100 Max(|V1..V28|) cao nhất/ngày' AS phuong_phap,
        r.date_key,
        COUNT(*) FILTER (WHERE r.rank_by_max_abs_v_desc <= 100) AS so_gd_ra_soat,
        SUM(r.is_fraud) FILTER (WHERE r.rank_by_max_abs_v_desc <= 100)::NUMERIC AS so_fraud_bat_duoc,
        SUM(r.is_fraud) AS tong_fraud_trong_ngay
    FROM ranked_txns r
    GROUP BY r.date_key
)
SELECT
    phuong_phap,
    COALESCE('Ngày tương đối ' || date_key::TEXT, 'TỔNG 2 NGÀY (Ngân sách 200 GD)') AS pham_vi,
    SUM(so_gd_ra_soat) AS ngan_sach_ra_soat,
    SUM(so_fraud_bat_duoc) AS fraud_bat_duoc,
    SUM(so_gd_ra_soat) - SUM(so_fraud_bat_duoc) AS duong_tinh_gia_fp,
    ROUND(SUM(so_fraud_bat_duoc) / SUM(so_gd_ra_soat) * 100, 2) AS precision_at_k_pct,
    ROUND(SUM(so_fraud_bat_duoc) / SUM(tong_fraud_trong_ngay) * 100, 2) AS recall_pct,
    ROUND(SUM(so_fraud_bat_duoc) / LEAST(SUM(so_gd_ra_soat), SUM(tong_fraud_trong_ngay)) * 100, 2) AS hieu_suat_so_voi_tran_pct
FROM strategy_eval
GROUP BY GROUPING SETS ((phuong_phap, date_key), (phuong_phap))
ORDER BY phuong_phap, date_key NULLS LAST;

