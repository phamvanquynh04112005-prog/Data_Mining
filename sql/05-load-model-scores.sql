-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Script 05: Nạp điểm mô hình vào Staging & Cập nhật Fact_Transaction (sql/05-load-model-scores.sql)
-- Người thực hiện: Quỳnh (Thành viên C — Data Engineer)
-- Phối hợp: Nhận file outputs/model_scores_warehouse.csv từ Huy (D) và Mong (E)
-- Đặc tính: Idempotent (chạy lại nhiều lần không lỗi, khớp 100% schema thật của 01, 02, 03)
-- =============================================================================

SET client_encoding = 'UTF8';
BEGIN;

-- 1. Làm sạch bảng stg_model_scores trước khi nạp lại
TRUNCATE TABLE stg_model_scores;

-- 2. Nạp dữ liệu từ outputs/model_scores_warehouse.csv vào stg_model_scores
-- Định dạng header chuẩn khớp 100% với bảng stg_model_scores trong sql/01-staging.sql:
-- txn_id,split_set,iforest_score,lof_score,sup_prob_score,model_run_note
\echo '[05-load-model-scores] Dang nap outputs/model_scores_warehouse.csv vao stg_model_scores...'
\copy stg_model_scores (txn_id, split_set, iforest_score, lof_score, sup_prob_score, model_run_note) FROM 'outputs/model_scores_warehouse.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 3. Đặt lại các cột điểm mô hình trên Fact_Transaction về NULL trước khi cập nhật
--    (đảm bảo tính idempotent tuyệt đối ngay cả khi file CSV rỗng hoặc chỉ chứa tập TEST)
UPDATE Fact_Transaction
SET
    split_set          = NULL,
    iforest_score      = NULL,
    iforest_daily_rank = NULL,
    lof_score          = NULL,
    lof_daily_rank     = NULL,
    sup_prob_score     = NULL,
    sup_daily_rank     = NULL
WHERE split_set IS NOT NULL
   OR iforest_score IS NOT NULL
   OR lof_score IS NOT NULL
   OR sup_prob_score IS NOT NULL;

-- 4. Tính hạng rà soát trong ngày tương đối (RANK() OVER PARTITION BY date_key)
--    theo đúng công thức của sql/03-transform.sql và cập nhật vào Fact_Transaction
WITH ranked_scores AS (
    SELECT
        f.txn_id,
        m.split_set,
        m.iforest_score,
        CASE WHEN m.iforest_score IS NOT NULL THEN
            RANK() OVER (
                PARTITION BY f.date_key, (m.iforest_score IS NOT NULL)
                ORDER BY m.iforest_score DESC, f.txn_id ASC
            )::INT
        END AS iforest_daily_rank,
        m.lof_score,
        CASE WHEN m.lof_score IS NOT NULL THEN
            RANK() OVER (
                PARTITION BY f.date_key, (m.lof_score IS NOT NULL)
                ORDER BY m.lof_score DESC, f.txn_id ASC
            )::INT
        END AS lof_daily_rank,
        m.sup_prob_score,
        CASE WHEN m.sup_prob_score IS NOT NULL THEN
            RANK() OVER (
                PARTITION BY f.date_key, (m.sup_prob_score IS NOT NULL)
                ORDER BY m.sup_prob_score DESC, f.txn_id ASC
            )::INT
        END AS sup_daily_rank
    FROM Fact_Transaction f
    JOIN stg_model_scores m ON m.txn_id = f.txn_id
)
UPDATE Fact_Transaction f
SET
    split_set          = r.split_set,
    iforest_score      = r.iforest_score,
    iforest_daily_rank = r.iforest_daily_rank,
    lof_score          = r.lof_score,
    lof_daily_rank     = r.lof_daily_rank,
    sup_prob_score     = r.sup_prob_score,
    sup_daily_rank     = r.sup_daily_rank
FROM ranked_scores r
WHERE f.txn_id = r.txn_id;

COMMIT;

ANALYZE stg_model_scores;
ANALYZE Fact_Transaction;

-- 5. Kiểm tra đối soát số dòng điểm mô hình đã nạp (Bước C12)
\echo '=== BAO CAO DOI SOAT DIEM MO HINH (BUOC C12) ==='
SELECT
    (SELECT COUNT(*) FROM stg_model_scores)                           AS stg_score_rows,
    COUNT(*)                                                          AS fact_total_rows,
    COUNT(iforest_score)                                              AS rows_with_iforest,
    COUNT(*) FILTER (WHERE iforest_daily_rank <= 100)                 AS iforest_top100_alerts,
    SUM(is_fraud) FILTER (WHERE iforest_daily_rank <= 100)            AS iforest_caught_fraud,
    COUNT(lof_score)                                                  AS rows_with_lof,
    COUNT(*) FILTER (WHERE lof_daily_rank <= 100)                     AS lof_top100_alerts,
    SUM(is_fraud) FILTER (WHERE lof_daily_rank <= 100)                AS lof_caught_fraud,
    COUNT(sup_prob_score)                                             AS rows_with_sup_prob,
    COUNT(*) FILTER (WHERE sup_daily_rank <= 100)                     AS sup_top100_alerts,
    SUM(is_fraud) FILTER (WHERE sup_daily_rank <= 100)                AS sup_caught_fraud
FROM Fact_Transaction;
