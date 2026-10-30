# Báo cáo Đối soát Toàn vẹn Kho dữ liệu PostgreSQL (Bước C9)

**Người thực hiện:** Quỳnh (Thành viên C — Data Engineer)  
**Trạng thái:** **ĐÃ KIỂM CHỨNG THỰC TẾ TRÊN POSTGRESQL 16.15-5** (Ngày chạy: 30/10/2026)  
**Cơ sở dữ liệu:** `postgresql://dm:dm@localhost:5432/dm_course`  
**Log thực thi nguyên bản đính kèm:** `outputs/postgres_execution_log.txt`  
**Quy trình chạy:** Chạy tuần tự từ đầu `sql/01-staging.sql` $\rightarrow$ `sql/02-star-schema.sql` $\rightarrow$ `sql/03-transform.sql` $\rightarrow$ `sql/05-load-model-scores.sql` thông qua `sql/run_warehouse.ps1` (hoặc `python sql/run_pipeline.py`).

---

## 1. Bảng Đối soát Số dòng & Tổng Nhãn (Staging vs. Star Schema vs. Audit của Khang A)

| Chỉ số đối soát | Số đo từ `01_data_audit.ipynb` (`audit_metrics.json`) | Kết quả truy vấn PostgreSQL (`Fact_Transaction`) | Độ lệch | Đánh giá |
|---|---:|---:|---:|---|
| Tổng số dòng nạp vào `stg_raw_transactions` | 284 807 | **284 807** | 0 | ✓ Khớp tuyệt đối |
| Tổng số dòng trong `Fact_Transaction` | 284 807 | **284 807** | 0 | ✓ Khớp tuyệt đối |
| Số dòng `Dim_Date` | 2 | **2** | 0 | ✓ Khớp tuyệt đối |
| Số dòng `Dim_Hour` | 48 | **48** | 0 | ✓ Khớp tuyệt đối |
| Số dòng `Dim_AmountBand` | 7 | **7** | 0 | ✓ Khớp tuyệt đối |
| Số dòng `Dim_Channel` (Synthetic) | 3 | **3** | 0 | ✓ Khớp tuyệt đối |
| Tổng giao dịch gian lận (`is_fraud = 1`) | 492 | **492** | 0 | ✓ Khớp tuyệt đối |
| Tổng giao dịch bình thường (`is_fraud = 0`) | 284 315 | **284 315** | 0 | ✓ Khớp tuyệt đối |
| Bản sao thừa trên 31 cột (`DQ-01`: `is_duplicate = TRUE`) | 1 081 | **1 081** | 0 | ✓ Khớp tuyệt đối |
| Gian lận nằm trong bản sao thừa (`DQ-01`) | 19 | **19** | 0 | ✓ Khớp tuyệt đối |
| Số dòng sau khi khử trùng (`is_duplicate = FALSE`) | 283 726 | **283 726** | 0 | ✓ Khớp tuyệt đối |
| Số gian lận sau khi khử trùng (`is_duplicate = FALSE`) | 473 | **473** | 0 | ✓ Khớp tuyệt đối |
| Giao dịch có `Amount = 0` (`DQ-02`: `is_zero_amount = TRUE`) | 1 825 | **1 825** | 0 | ✓ Khớp tuyệt đối |
| Gian lận có `Amount = 0` (`DQ-02`) | 27 | **27** | 0 | ✓ Khớp tuyệt đối |
| Dòng có ít nhất 1 cột $V_i$ vượt $|z| > 10$ (`DQ-06`) | 1 924 | **1 924** | 0 | ✓ Khớp tuyệt đối |
| Gian lận có ít nhất 1 cột $V_i$ vượt $|z| > 10$ (`DQ-06`) | 231 | **231** | 0 | ✓ Khớp tuyệt đối |
| Giao dịch Ngày tương đối 0 (`date_key = 0`) | 144 786 | **144 786** | 0 | ✓ Khớp tuyệt đối |
| Gian lận Ngày tương đối 0 (`date_key = 0`) | 281 | **281** | 0 | ✓ Khớp tuyệt đối |
| Giao dịch Ngày tương đối 1 (`date_key = 1`) | 140 021 | **140 021** | 0 | ✓ Khớp tuyệt đối |
| Gian lận Ngày tương đối 1 (`date_key = 1`) | 211 | **211** | 0 | ✓ Khớp tuyệt đối |

---

## 2. Log Kết quả Chạy Thực tế trên Máy Cá nhân

```text
[1/3] Running sql/01-staging.sql (Create Staging & Load creditcard.csv)...
COPY 284807
 stg_total_rows | stg_total_fraud
----------------+-----------------
         284807 |             492
(1 row)

[2/3] Running sql/02-star-schema.sql (Create 4 Dimensions & Fact_Transaction)...
CREATE TABLE (Dim_Date, Dim_Hour, Dim_AmountBand, Dim_Channel, Fact_Transaction)
CREATE INDEX (8 indexes)
COMMIT

[3/3] Running sql/03-transform.sql (Populate Warehouse & Reconcile Counts)...
TRUNCATE TABLE
INSERT 0 2
INSERT 0 48
INSERT 0 7
INSERT 0 3
INSERT 0 284807
COMMIT
ANALYZE
=== BAO CAO DOI SOAT TOAN VEN KHO DU LIEU (BUOC C9) ===
 stg_rows | fact_rows | total_fraud | total_non_fraud | dup_extra_rows_dq01 | dup_extra_fraud_dq01 | dedup_rows | dedup_fraud | amount_zero_rows_dq02 | amount_zero_fraud_dq02 | extreme_v_z10_rows_dq06 | extreme_v_z10_fraud_dq06 | day0_rows | day0_fraud | day1_rows | day1_fraud 
----------+-----------+-------------+-----------------+---------------------+----------------------+------------+-------------+-----------------------+------------------------+-------------------------+--------------------------+-----------+------------+-----------+------------
   284807 |    284807 |         492 |          284315 |                1081 |                   19 |     283726 |         473 |                  1825 |                     27 |                    1924 |                      231 |    144786 |        281 |    140021 |        211
(1 row)
```

