-- =============================================================================
-- ĐỒ ÁN 6: NGÂN HÀNG — PHÁT HIỆN GIAO DỊCH THẺ GIAN LẬN
-- Script 02: Khởi tạo Kho dữ liệu Star Schema (sql/02-star-schema.sql)
-- Người thực hiện: Quỳnh (Thành viên C — Data Engineer)
-- Mô hình: 1 Bảng Fact (Fact_Transaction) + 4 Bảng Dimension:
--          Dim_Date (tương đối), Dim_Hour (tương đối), Dim_AmountBand, Dim_Channel (mô phỏng)
-- Đặc tính: Idempotent (chạy lại được nhiều lần từ đầu)
-- =============================================================================

SET client_encoding = 'UTF8';
BEGIN;

-- Xóa bảng theo thứ tự phụ thuộc khóa ngoại để chạy lại sạch sẽ
DROP TABLE IF EXISTS Fact_Transaction CASCADE;
DROP TABLE IF EXISTS Dim_Hour CASCADE;
DROP TABLE IF EXISTS Dim_Date CASCADE;
DROP TABLE IF EXISTS Dim_AmountBand CASCADE;
DROP TABLE IF EXISTS Dim_Channel CASCADE;

-- =============================================================================
-- 1. BẢNG CHIỀU NGÀY TƯƠNG ĐỐI: Dim_Date
-- Ghi chú (DQ-05): Time chỉ là số giây kể từ giao dịch đầu tiên (0..172792s).
-- Không có ngày lịch thực tế, do đó Dim_Date lưu Ngày tương đối 0 và 1.
-- =============================================================================
CREATE TABLE Dim_Date (
    date_key            INT          PRIMARY KEY CHECK (date_key IN (0, 1)),
    rel_day_num         INT          NOT NULL CHECK (rel_day_num IN (0, 1)),
    rel_day_label       VARCHAR(60)  NOT NULL,
    start_sec           INT          NOT NULL,
    end_sec             INT          NOT NULL,
    daily_review_budget INT          NOT NULL DEFAULT 100 CHECK (daily_review_budget > 0),
    interpretation_note VARCHAR(255) NOT NULL
);

COMMENT ON TABLE Dim_Date IS
'Dimension Ngày tương đối (0 và 1), cắt theo mỗi 86.400 giây kể từ giao dịch đầu tiên (DQ-05).';

-- =============================================================================
-- 2. BẢNG CHIỀU GIỜ TƯƠNG ĐỐI: Dim_Hour
-- Ghi chú (DQ-05): Giờ tương đối 0..47 kể từ giao dịch đầu tiên.
-- TUYỆT ĐỐI KHÔNG diễn giải thành giờ đồng hồ hay ban ngày / ban đêm.
-- =============================================================================
CREATE TABLE Dim_Hour (
    hour_key            INT          PRIMARY KEY CHECK (hour_key BETWEEN 0 AND 47),
    date_key            INT          NOT NULL REFERENCES Dim_Date(date_key),
    hour_in_rel_day     INT          NOT NULL CHECK (hour_in_rel_day BETWEEN 0 AND 23),
    rel_hour_label      VARCHAR(60)  NOT NULL,
    start_sec           INT          NOT NULL,
    end_sec             INT          NOT NULL,
    interpretation_note VARCHAR(255) NOT NULL
);

COMMENT ON TABLE Dim_Hour IS
'Dimension Giờ tương đối (0..47 kể từ giao dịch đầu tiên). Không phải giờ đồng hồ thực tế (DQ-05).';

-- =============================================================================
-- 3. BẢNG CHIỀU DẢI SỐ TIỀN: Dim_AmountBand
-- Khớp chính xác 7 dải số tiền trong outputs/amount_band_fraud_rate.csv của Khang (A).
-- =============================================================================
CREATE TABLE Dim_AmountBand (
    amount_band_key     INT            PRIMARY KEY CHECK (amount_band_key BETWEEN 1 AND 7),
    band_code           VARCHAR(20)    NOT NULL UNIQUE,
    band_label          VARCHAR(60)    NOT NULL,
    min_amount          NUMERIC(12, 2) NOT NULL,
    max_amount          NUMERIC(12, 2) NOT NULL,
    is_lower_inclusive  BOOLEAN        NOT NULL,
    is_upper_inclusive  BOOLEAN        NOT NULL,
    band_order          INT            NOT NULL UNIQUE CHECK (band_order BETWEEN 1 AND 7)
);

COMMENT ON TABLE Dim_AmountBand IS
'Dimension 7 dải số tiền giao dịch (0, 0–10, 10–50, 50–100, 100–500, 500–1000, >1000) khớp với báo cáo EDA của Khang (A).';

-- =============================================================================
-- 4. BẢNG CHIỀU KÊNH GIAO DỊCH (MÔ PHỎNG / SYNTHETIC): Dim_Channel
-- Ghi chú (DQ-07): Dataset gốc không có kênh thanh toán. Bảng này được tạo theo
-- gợi ý thiết kế Star Schema của đề bài và gắn nhãn rõ is_synthetic = TRUE.
-- =============================================================================
CREATE TABLE Dim_Channel (
    channel_key         INT          PRIMARY KEY CHECK (channel_key BETWEEN 1 AND 3),
    channel_code        VARCHAR(30)  NOT NULL UNIQUE,
    channel_name        VARCHAR(80)  NOT NULL,
    is_synthetic        BOOLEAN      NOT NULL DEFAULT TRUE CHECK (is_synthetic = TRUE),
    allocation_rule     VARCHAR(255) NOT NULL,
    warning_note        VARCHAR(255) NOT NULL
);

COMMENT ON TABLE Dim_Channel IS
'Dimension Kênh giao dịch MÔ PHỎNG (SYNTHETIC) theo đề bài. Không dùng để kết luận hành vi kênh thanh toán thật (DQ-07).';

-- =============================================================================
-- 5. BẢNG FACT CHÍNH: Fact_Transaction
-- Grain: 1 dòng = 1 giao dịch thẻ tín dụng trong creditcard.csv (284.807 dòng).
-- =============================================================================
CREATE TABLE Fact_Transaction (
    txn_id              INT            PRIMARY KEY,
    date_key            INT            NOT NULL REFERENCES Dim_Date(date_key),
    hour_key            INT            NOT NULL REFERENCES Dim_Hour(hour_key),
    amount_band_key     INT            NOT NULL REFERENCES Dim_AmountBand(amount_band_key),
    channel_key         INT            NOT NULL REFERENCES Dim_Channel(channel_key),
    time_sec            INT            NOT NULL CHECK (time_sec >= 0),
    amount              NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    amount_log1p        NUMERIC(12, 6) NOT NULL CHECK (amount_log1p >= 0),
    is_zero_amount      BOOLEAN        NOT NULL,
    is_duplicate        BOOLEAN        NOT NULL,
    dup_group_rank      INT            NOT NULL CHECK (dup_group_rank >= 1),
    max_abs_v           NUMERIC(12, 6) NOT NULL CHECK (max_abs_v >= 0),
    has_extreme_v_z10   BOOLEAN        NOT NULL,
    is_fraud            SMALLINT       NOT NULL CHECK (is_fraud IN (0, 1)),
    split_set           VARCHAR(10)    NULL CHECK (split_set IN ('TRAIN', 'VAL', 'TEST')),
    iforest_score       NUMERIC(12, 6) NULL,
    iforest_daily_rank  INT            NULL CHECK (iforest_daily_rank IS NULL OR iforest_daily_rank >= 1),
    lof_score           NUMERIC(12, 6) NULL,
    lof_daily_rank      INT            NULL CHECK (lof_daily_rank IS NULL OR lof_daily_rank >= 1),
    sup_prob_score      NUMERIC(12, 6) NULL,
    sup_daily_rank      INT            NULL CHECK (sup_daily_rank IS NULL OR sup_daily_rank >= 1),
    anomaly_score       NUMERIC(12, 6) NULL
);

COMMENT ON TABLE Fact_Transaction IS
'Bảng Fact chính của Star Schema. Grain: 1 dòng = 1 giao dịch thẻ tín dụng (tổng 284.807 dòng, trong đó 492 gian lận).';

COMMENT ON COLUMN Fact_Transaction.is_duplicate IS
'Cờ đánh dấu 1.081 bản sao thừa trên toàn bộ 31 cột (DQ-01). Giúp lọc linh hoạt giữa toàn bộ dữ liệu (284.807) và dữ liệu khử trùng (283.726).';

COMMENT ON COLUMN Fact_Transaction.is_fraud IS
'Nhãn gian lận (1 = gian lận, 0 = bình thường). Chỉ dùng để đối soát OLAP và đánh giá mô hình.';

-- =============================================================================
-- 6. CHỈ MỤC (INDEXES) TỐI ƯU HÓA TRUY VẤN OLAP & DASHBOARD SUPERSET
-- =============================================================================
CREATE INDEX idx_fact_txn_date_key        ON Fact_Transaction(date_key);
CREATE INDEX idx_fact_txn_hour_key        ON Fact_Transaction(hour_key);
CREATE INDEX idx_fact_txn_amount_band_key ON Fact_Transaction(amount_band_key);
CREATE INDEX idx_fact_txn_channel_key     ON Fact_Transaction(channel_key);
CREATE INDEX idx_fact_txn_is_fraud        ON Fact_Transaction(is_fraud);
CREATE INDEX idx_fact_txn_is_duplicate    ON Fact_Transaction(is_duplicate);
CREATE INDEX idx_fact_txn_iforest_rank    ON Fact_Transaction(date_key, iforest_daily_rank) WHERE iforest_daily_rank IS NOT NULL;
CREATE INDEX idx_fact_txn_lof_rank        ON Fact_Transaction(date_key, lof_daily_rank)     WHERE lof_daily_rank IS NOT NULL;

COMMIT;

