-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Script 01: Khởi tạo tầng Staging & Nạp dữ liệu gốc (sql/01-staging.sql)
-- Người thực hiện: Quỳnh (Thành viên C — Data Engineer)
-- Đặc tính: Idempotent (chạy lại được nhiều lần từ thư mục gốc của project)
-- =============================================================================

SET client_encoding = 'UTF8';
BEGIN;

-- 1. Tạo bảng Staging lưu nguyên bản 31 cột của file data/raw/creditcard.csv
DROP TABLE IF EXISTS stg_raw_transactions CASCADE;

CREATE TABLE stg_raw_transactions (
    raw_row_id   SERIAL PRIMARY KEY,
    time_sec    DOUBLE PRECISION NOT NULL,
    v1          DOUBLE PRECISION NOT NULL,
    v2          DOUBLE PRECISION NOT NULL,
    v3          DOUBLE PRECISION NOT NULL,
    v4          DOUBLE PRECISION NOT NULL,
    v5          DOUBLE PRECISION NOT NULL,
    v6          DOUBLE PRECISION NOT NULL,
    v7          DOUBLE PRECISION NOT NULL,
    v8          DOUBLE PRECISION NOT NULL,
    v9          DOUBLE PRECISION NOT NULL,
    v10         DOUBLE PRECISION NOT NULL,
    v11         DOUBLE PRECISION NOT NULL,
    v12         DOUBLE PRECISION NOT NULL,
    v13         DOUBLE PRECISION NOT NULL,
    v14         DOUBLE PRECISION NOT NULL,
    v15         DOUBLE PRECISION NOT NULL,
    v16         DOUBLE PRECISION NOT NULL,
    v17         DOUBLE PRECISION NOT NULL,
    v18         DOUBLE PRECISION NOT NULL,
    v19         DOUBLE PRECISION NOT NULL,
    v20         DOUBLE PRECISION NOT NULL,
    v21         DOUBLE PRECISION NOT NULL,
    v22         DOUBLE PRECISION NOT NULL,
    v23         DOUBLE PRECISION NOT NULL,
    v24         DOUBLE PRECISION NOT NULL,
    v25         DOUBLE PRECISION NOT NULL,
    v26         DOUBLE PRECISION NOT NULL,
    v27         DOUBLE PRECISION NOT NULL,
    v28         DOUBLE PRECISION NOT NULL,
    amount      NUMERIC(12, 2)   NOT NULL,
    class       SMALLINT         NOT NULL CHECK (class IN (0, 1))
);

COMMENT ON TABLE stg_raw_transactions IS
'Bảng Staging chứa nguyên bản 284.807 dòng x 31 cột từ data/raw/creditcard.csv (sha256: 76274b69...98551a89).';

COMMENT ON COLUMN stg_raw_transactions.raw_row_id IS
'Số thứ tự dòng tự tăng (1..284807) theo đúng thứ tự xuất hiện trong file CSV gốc, dùng làm khóa tất định txn_id.';

COMMENT ON COLUMN stg_raw_transactions.time_sec IS
'Số giây tương đối kể từ giao dịch đầu tiên trong dataset (0..172792). Không phải timestamp thực.';

COMMENT ON COLUMN stg_raw_transactions.class IS
'Nhãn gian lận gốc (1 = fraud: 492 dòng, 0 = non-fraud: 284.315 dòng). Chỉ dùng để đối soát và đánh giá.';

-- 2. Nạp trực tiếp dữ liệu từ file data/raw/creditcard.csv vào stg_raw_transactions
\echo '[01-staging] Dang nap 284.807 dong tu data/raw/creditcard.csv vao stg_raw_transactions...'
\copy stg_raw_transactions (time_sec, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16, v17, v18, v19, v20, v21, v22, v23, v24, v25, v26, v27, v28, amount, class) FROM 'data/raw/creditcard.csv' WITH (FORMAT csv, HEADER true);

-- 3. Tạo bảng Staging phụ để nhận điểm mô hình từ Huy (D) và Mong (E) khi chạy xong
DROP TABLE IF EXISTS stg_model_scores CASCADE;

CREATE TABLE stg_model_scores (
    txn_id          INT            PRIMARY KEY,
    split_set       VARCHAR(10)    NULL CHECK (split_set IN ('TRAIN', 'VAL', 'TEST')),
    iforest_score   NUMERIC(12, 6) NULL,
    lof_score       NUMERIC(12, 6) NULL,
    sup_prob_score  NUMERIC(12, 6) NULL,
    model_run_note  VARCHAR(100)   NULL
);

COMMENT ON TABLE stg_model_scores IS
'Bảng Staging chờ nạp điểm bất thường (Isolation Forest, LOF từ Huy - D) và xác suất phân lớp (từ Mong - E).';

COMMIT;

-- Kiểm tra nhanh số dòng vừa nạp vào Staging
SELECT COUNT(*) AS stg_total_rows, SUM(class) AS stg_total_fraud FROM stg_raw_transactions;
