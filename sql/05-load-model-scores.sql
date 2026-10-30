-- =============================================================================
-- ĐỒ ÁN 6: PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN (CREDIT CARD FRAUD DETECTION)
-- Thành viên C (Quỳnh) — Data Engineer: Kho dữ liệu PostgreSQL, Star Schema & OLAP
-- File: sql/05-load-model-scores.sql
-- Mục tiêu (Bước C12): Nạp điểm mô hình từ Thành viên D (Huy) & E (Mong) vào
--                      stg_model_scores và cập nhật Fact_Transaction để
--                      6 Dashboard Views trên Apache Superset tự động hiển thị
--                      kết quả so sánh Baseline vs. Mô hình.
-- Tính chất: Idempotent (chạy lại nhiều lần không lỗi, không nhân bản dữ liệu)
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- 1. Làm sạch bảng staging điểm mô hình trước khi nạp mới
TRUNCATE TABLE stg_model_scores;

-- 2. Nạp file CSV điểm mô hình từ thư mục outputs/
-- Định dạng CSV kỳ vọng (có header):
-- transaction_seq_id,split_role,iforest_score,lof_score,ae_recon_error,logreg_prob,lgbm_prob,daily_alert_rank,is_top100_daily_alert,selected_model_name
\echo '[05-load-model-scores] Dang nap outputs/model_scores_warehouse.csv vao stg_model_scores...'
\copy stg_model_scores (transaction_seq_id, split_role, iforest_score, lof_score, ae_recon_error, logreg_prob, lgbm_prob, daily_alert_rank, is_top100_daily_alert, selected_model_name) FROM 'outputs/model_scores_warehouse.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- 3. Cập nhật ngược vào bảng Fact_Transaction theo khóa chính transaction_seq_id
UPDATE Fact_Transaction f
SET
    split_role            = s.split_role,
    iforest_score         = s.iforest_score,
    lof_score             = s.lof_score,
    ae_recon_error        = s.ae_recon_error,
    logreg_prob           = s.logreg_prob,
    lgbm_prob             = s.lgbm_prob,
    daily_alert_rank      = s.daily_alert_rank,
    is_top100_daily_alert = COALESCE(s.is_top100_daily_alert, FALSE),
    selected_model_name   = s.selected_model_name
FROM stg_model_scores s
WHERE f.transaction_seq_id = s.transaction_seq_id;

COMMIT;

ANALYZE Fact_Transaction;

-- 4. Kiểm tra nhanh kết quả cập nhật trên View so sánh mô hình vs. baseline
SELECT * FROM vw_dash_06_model_vs_baseline_comparison;

