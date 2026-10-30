-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Script 03: Biến đổi & Nạp dữ liệu vào Star Schema (sql/03-transform.sql)
-- Người thực hiện: Quỳnh (Thành viên C — Data Engineer)
-- Đặc tính: Idempotent (TRUNCATE + INSERT lại toàn bộ từ stg_raw_transactions)
-- =============================================================================

SET client_encoding = 'UTF8';
BEGIN;

-- Làm sạch dữ liệu trong các bảng Star Schema trước khi nạp lại (đảm bảo idempotent)
TRUNCATE TABLE
    Fact_Transaction,
    Dim_Hour,
    Dim_Date,
    Dim_AmountBand,
    Dim_Channel
RESTART IDENTITY CASCADE;

-- =============================================================================
-- 1. NẠP BẢNG CHIỀU NGÀY TƯƠNG ĐỐI: Dim_Date (2 dòng: Ngày tương đối 0 và 1)
-- =============================================================================
INSERT INTO Dim_Date (
    date_key,
    rel_day_num,
    rel_day_label,
    start_sec,
    end_sec,
    daily_review_budget,
    interpretation_note
)
VALUES
    (0, 0, 'Ngày tương đối 0 (0s – 86.399s)',      0,     86399,  100,
     'Giả định cắt 86.400s đầu tiên kể từ giao dịch đầu (DQ-05). Không phải ngày lịch thực tế.'),
    (1, 1, 'Ngày tương đối 1 (86.400s – 172.792s)', 86400, 172792, 100,
     'Giả định cắt 86.400s tiếp theo kể từ giao dịch đầu (DQ-05). Không phải ngày lịch thực tế.');

-- =============================================================================
-- 2. NẠP BẢNG CHIỀU GIỜ TƯƠNG ĐỐI: Dim_Hour (48 dòng: Giờ tương đối 0..47)
-- =============================================================================
INSERT INTO Dim_Hour (
    hour_key,
    date_key,
    hour_in_rel_day,
    rel_hour_label,
    start_sec,
    end_sec,
    interpretation_note
)
SELECT
    h AS hour_key,
    (h / 24) AS date_key,
    (h % 24) AS hour_in_rel_day,
    FORMAT('Giờ tương đối %s (Ngày %s, giờ chu kỳ %s)', LPAD(h::TEXT, 2, '0'), (h / 24)::TEXT, LPAD((h % 24)::TEXT, 2, '0')) AS rel_hour_label,
    h * 3600 AS start_sec,
    (h + 1) * 3600 - 1 AS end_sec,
    'Giờ thứ k kể từ giao dịch đầu tiên (DQ-05). Tuyệt đối KHÔNG diễn giải thành ban ngày hay ban đêm.' AS interpretation_note
FROM generate_series(0, 47) AS h;

-- =============================================================================
-- 3. NẠP BẢNG CHIỀU DẢI SỐ TIỀN: Dim_AmountBand (7 dòng khớp EDA của Khang A)
-- Khớp chính xác pd.cut(df["Amount"], [-0.01, 0, 10, 50, 100, 500, 1000, 1e9])
-- =============================================================================
INSERT INTO Dim_AmountBand (
    amount_band_key,
    band_code,
    band_label,
    min_amount,
    max_amount,
    is_lower_inclusive,
    is_upper_inclusive,
    band_order
)
VALUES
    (1, '0',        'Dải 1: Amount = 0 (DQ-02)',      0.00,    0.00,      TRUE,  TRUE,  1),
    (2, '0–10',     'Dải 2: (0, 10]',                 0.00,    10.00,     FALSE, TRUE,  2),
    (3, '10–50',    'Dải 3: (10, 50]',                10.00,   50.00,     FALSE, TRUE,  3),
    (4, '50–100',   'Dải 4: (50, 100]',               50.00,   100.00,    FALSE, TRUE,  4),
    (5, '100–500',  'Dải 5: (100, 500]',              100.00,  500.00,    FALSE, TRUE,  5),
    (6, '500–1000', 'Dải 6: (500, 1.000]',            500.00,  1000.00,   FALSE, TRUE,  6),
    (7, '>1000',    'Dải 7: > 1.000 (max 25.691,16)', 1000.00, 25691.16,  FALSE, TRUE,  7);

-- =============================================================================
-- 4. NẠP BẢNG CHIỀU KÊNH MÔ PHỎNG (SYNTHETIC): Dim_Channel (3 dòng)
-- Ghi chú (DQ-07): Gắn cờ is_synthetic = TRUE và cảnh báo rõ ràng.
-- =============================================================================
INSERT INTO Dim_Channel (
    channel_key,
    channel_code,
    channel_name,
    is_synthetic,
    allocation_rule,
    warning_note
)
VALUES
    (1, 'SYNTH_POS',  'POS tại quầy (Mô phỏng - Synthetic)',        TRUE,
     'Gán tất định: 1 + MOD(ABS(HASHTEXT(raw_row_id::TEXT)), 3) = 1',
     'Dữ liệu mô phỏng theo đề bài (DQ-07); KHÔNG dùng để rút ra kết luận nghiệp vụ thật.'),
    (2, 'SYNTH_ECOM', 'Online / E-Commerce (Mô phỏng - Synthetic)', TRUE,
     'Gán tất định: 1 + MOD(ABS(HASHTEXT(raw_row_id::TEXT)), 3) = 2',
     'Dữ liệu mô phỏng theo đề bài (DQ-07); KHÔNG dùng để rút ra kết luận nghiệp vụ thật.'),
    (3, 'SYNTH_ATM',  'ATM / Khác (Mô phỏng - Synthetic)',          TRUE,
     'Gán tất định: 1 + MOD(ABS(HASHTEXT(raw_row_id::TEXT)), 3) = 3',
     'Dữ liệu mô phỏng theo đề bài (DQ-07); KHÔNG dùng để rút ra kết luận nghiệp vụ thật.');

-- =============================================================================
-- 5. BIẾN ĐỔI & NẠP BẢNG FACT: Fact_Transaction (284.807 dòng)
-- - Tính toán dup_group_rank & is_duplicate trên toàn bộ 31 cột gốc (DQ-01)
-- - Tính toán has_extreme_v_z10 (|z| > 10 ở ít nhất một cột V1..V28) (DQ-06)
-- - Ánh xạ khóa ngoại sang 4 bảng Dimension
-- - Left join với stg_model_scores (nếu đã có điểm từ Huy D / Mong E)
-- =============================================================================
WITH v_stats AS (
    SELECT
        AVG(v1)  AS m1,  STDDEV_SAMP(v1)  AS s1,
        AVG(v2)  AS m2,  STDDEV_SAMP(v2)  AS s2,
        AVG(v3)  AS m3,  STDDEV_SAMP(v3)  AS s3,
        AVG(v4)  AS m4,  STDDEV_SAMP(v4)  AS s4,
        AVG(v5)  AS m5,  STDDEV_SAMP(v5)  AS s5,
        AVG(v6)  AS m6,  STDDEV_SAMP(v6)  AS s6,
        AVG(v7)  AS m7,  STDDEV_SAMP(v7)  AS s7,
        AVG(v8)  AS m8,  STDDEV_SAMP(v8)  AS s8,
        AVG(v9)  AS m9,  STDDEV_SAMP(v9)  AS s9,
        AVG(v10) AS m10, STDDEV_SAMP(v10) AS s10,
        AVG(v11) AS m11, STDDEV_SAMP(v11) AS s11,
        AVG(v12) AS m12, STDDEV_SAMP(v12) AS s12,
        AVG(v13) AS m13, STDDEV_SAMP(v13) AS s13,
        AVG(v14) AS m14, STDDEV_SAMP(v14) AS s14,
        AVG(v15) AS m15, STDDEV_SAMP(v15) AS s15,
        AVG(v16) AS m16, STDDEV_SAMP(v16) AS s16,
        AVG(v17) AS m17, STDDEV_SAMP(v17) AS s17,
        AVG(v18) AS m18, STDDEV_SAMP(v18) AS s18,
        AVG(v19) AS m19, STDDEV_SAMP(v19) AS s19,
        AVG(v20) AS m20, STDDEV_SAMP(v20) AS s20,
        AVG(v21) AS m21, STDDEV_SAMP(v21) AS s21,
        AVG(v22) AS m22, STDDEV_SAMP(v22) AS s22,
        AVG(v23) AS m23, STDDEV_SAMP(v23) AS s23,
        AVG(v24) AS m24, STDDEV_SAMP(v24) AS s24,
        AVG(v25) AS m25, STDDEV_SAMP(v25) AS s25,
        AVG(v26) AS m26, STDDEV_SAMP(v26) AS s26,
        AVG(v27) AS m27, STDDEV_SAMP(v27) AS s27,
        AVG(v28) AS m28, STDDEV_SAMP(v28) AS s28
    FROM stg_raw_transactions
),
dedup_flagged AS (
    SELECT
        r.raw_row_id AS txn_id,
        (FLOOR(r.time_sec / 86400.0))::INT AS date_key,
        (FLOOR(r.time_sec / 3600.0))::INT  AS hour_key,
        CASE
            WHEN r.amount = 0     THEN 1
            WHEN r.amount <= 10   THEN 2
            WHEN r.amount <= 50   THEN 3
            WHEN r.amount <= 100  THEN 4
            WHEN r.amount <= 500  THEN 5
            WHEN r.amount <= 1000 THEN 6
            ELSE 7
        END AS amount_band_key,
        (1 + MOD(ABS(HASHTEXT(r.raw_row_id::TEXT)), 3))::INT AS channel_key,
        r.time_sec::INT AS time_sec,
        r.amount,
        ROUND(LN(r.amount + 1.0)::NUMERIC, 6) AS amount_log1p,
        (r.amount = 0) AS is_zero_amount,
        ROW_NUMBER() OVER (
            PARTITION BY
                r.time_sec,
                r.v1,  r.v2,  r.v3,  r.v4,  r.v5,  r.v6,  r.v7,
                r.v8,  r.v9,  r.v10, r.v11, r.v12, r.v13, r.v14,
                r.v15, r.v16, r.v17, r.v18, r.v19, r.v20, r.v21,
                r.v22, r.v23, r.v24, r.v25, r.v26, r.v27, r.v28,
                r.amount, r.class
            ORDER BY r.raw_row_id
        )::INT AS dup_group_rank,
        ROUND(
            GREATEST(
                ABS(r.v1),  ABS(r.v2),  ABS(r.v3),  ABS(r.v4),  ABS(r.v5),  ABS(r.v6),  ABS(r.v7),
                ABS(r.v8),  ABS(r.v9),  ABS(r.v10), ABS(r.v11), ABS(r.v12), ABS(r.v13), ABS(r.v14),
                ABS(r.v15), ABS(r.v16), ABS(r.v17), ABS(r.v18), ABS(r.v19), ABS(r.v20), ABS(r.v21),
                ABS(r.v22), ABS(r.v23), ABS(r.v24), ABS(r.v25), ABS(r.v26), ABS(r.v27), ABS(r.v28)
            )::NUMERIC, 6
        ) AS max_abs_v,
        (
            ABS(r.v1  - s.m1)  > 10 * s.s1  OR ABS(r.v2  - s.m2)  > 10 * s.s2  OR
            ABS(r.v3  - s.m3)  > 10 * s.s3  OR ABS(r.v4  - s.m4)  > 10 * s.s4  OR
            ABS(r.v5  - s.m5)  > 10 * s.s5  OR ABS(r.v6  - s.m6)  > 10 * s.s6  OR
            ABS(r.v7  - s.m7)  > 10 * s.s7  OR ABS(r.v8  - s.m8)  > 10 * s.s8  OR
            ABS(r.v9  - s.m9)  > 10 * s.s9  OR ABS(r.v10 - s.m10) > 10 * s.s10 OR
            ABS(r.v11 - s.m11) > 10 * s.s11 OR ABS(r.v12 - s.m12) > 10 * s.s12 OR
            ABS(r.v13 - s.m13) > 10 * s.s13 OR ABS(r.v14 - s.m14) > 10 * s.s14 OR
            ABS(r.v15 - s.m15) > 10 * s.s15 OR ABS(r.v16 - s.m16) > 10 * s.s16 OR
            ABS(r.v17 - s.m17) > 10 * s.s17 OR ABS(r.v18 - s.m18) > 10 * s.s18 OR
            ABS(r.v19 - s.m19) > 10 * s.s19 OR ABS(r.v20 - s.m20) > 10 * s.s20 OR
            ABS(r.v21 - s.m21) > 10 * s.s21 OR ABS(r.v22 - s.m22) > 10 * s.s22 OR
            ABS(r.v23 - s.m23) > 10 * s.s23 OR ABS(r.v24 - s.m24) > 10 * s.s24 OR
            ABS(r.v25 - s.m25) > 10 * s.s25 OR ABS(r.v26 - s.m26) > 10 * s.s26 OR
            ABS(r.v27 - s.m27) > 10 * s.s27 OR ABS(r.v28 - s.m28) > 10 * s.s28
        ) AS has_extreme_v_z10,
        r.class AS is_fraud
    FROM stg_raw_transactions r
    CROSS JOIN v_stats s
)
INSERT INTO Fact_Transaction (
    txn_id,
    date_key,
    hour_key,
    amount_band_key,
    channel_key,
    time_sec,
    amount,
    amount_log1p,
    is_zero_amount,
    is_duplicate,
    dup_group_rank,
    max_abs_v,
    has_extreme_v_z10,
    is_fraud,
    split_set,
    iforest_score,
    iforest_daily_rank,
    lof_score,
    lof_daily_rank,
    sup_prob_score,
    sup_daily_rank
)
SELECT
    d.txn_id,
    d.date_key,
    d.hour_key,
    d.amount_band_key,
    d.channel_key,
    d.time_sec,
    d.amount,
    d.amount_log1p,
    d.is_zero_amount,
    (d.dup_group_rank > 1) AS is_duplicate,
    d.dup_group_rank,
    d.max_abs_v,
    d.has_extreme_v_z10,
    d.is_fraud,
    m.split_set,
    m.iforest_score,
    CASE WHEN m.iforest_score IS NOT NULL THEN
        RANK() OVER (PARTITION BY d.date_key, (m.iforest_score IS NOT NULL) ORDER BY m.iforest_score DESC, d.txn_id ASC)::INT
    END AS iforest_daily_rank,
    m.lof_score,
    CASE WHEN m.lof_score IS NOT NULL THEN
        RANK() OVER (PARTITION BY d.date_key, (m.lof_score IS NOT NULL) ORDER BY m.lof_score DESC, d.txn_id ASC)::INT
    END AS lof_daily_rank,
    m.sup_prob_score,
    CASE WHEN m.sup_prob_score IS NOT NULL THEN
        RANK() OVER (PARTITION BY d.date_key, (m.sup_prob_score IS NOT NULL) ORDER BY m.sup_prob_score DESC, d.txn_id ASC)::INT
    END AS sup_daily_rank
FROM dedup_flagged d
LEFT JOIN stg_model_scores m ON m.txn_id = d.txn_id
ORDER BY d.txn_id;

COMMIT;

-- Cập nhật thống kê cho bộ tối ưu hóa truy vấn của PostgreSQL
ANALYZE Dim_Date;
ANALYZE Dim_Hour;
ANALYZE Dim_AmountBand;
ANALYZE Dim_Channel;
ANALYZE Fact_Transaction;

-- =============================================================================
-- 6. TRUY VẤN ĐỐI SOÁT TOÀN VẸN DỮ LIỆU TỰ ĐỘNG (BƯỚC C9)
-- =============================================================================
\echo '=== BAO CAO DOI SOAT TOAN VEN KHO DU LIEU (BUOC C9) ==='
SELECT
    (SELECT COUNT(*) FROM stg_raw_transactions)                                    AS stg_rows,
    COUNT(*)                                                                       AS fact_rows,
    SUM(is_fraud)                                                                  AS total_fraud,
    COUNT(*) FILTER (WHERE is_fraud = 0)                                           AS total_non_fraud,
    COUNT(*) FILTER (WHERE is_duplicate = TRUE)                                    AS dup_extra_rows_dq01,
    SUM(is_fraud) FILTER (WHERE is_duplicate = TRUE)                               AS dup_extra_fraud_dq01,
    COUNT(*) FILTER (WHERE is_duplicate = FALSE)                                   AS dedup_rows,
    SUM(is_fraud) FILTER (WHERE is_duplicate = FALSE)                              AS dedup_fraud,
    COUNT(*) FILTER (WHERE is_zero_amount = TRUE)                                  AS amount_zero_rows_dq02,
    SUM(is_fraud) FILTER (WHERE is_zero_amount = TRUE)                             AS amount_zero_fraud_dq02,
    COUNT(*) FILTER (WHERE has_extreme_v_z10 = TRUE)                               AS extreme_v_z10_rows_dq06,
    SUM(is_fraud) FILTER (WHERE has_extreme_v_z10 = TRUE)                          AS extreme_v_z10_fraud_dq06,
    COUNT(*) FILTER (WHERE date_key = 0)                                           AS day0_rows,
    SUM(is_fraud) FILTER (WHERE date_key = 0)                                      AS day0_fraud,
    COUNT(*) FILTER (WHERE date_key = 1)                                           AS day1_rows,
    SUM(is_fraud) FILTER (WHERE date_key = 1)                                      AS day1_fraud
FROM Fact_Transaction;

