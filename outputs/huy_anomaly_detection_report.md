# Báo cáo thí nghiệm — Isolation Forest và Local Outlier Factor (LOF)

**Thành viên phụ trách:** Huy  
**Nhánh Git:** `feature/huy-anomaly-detection`  
**Notebook:** `notebooks/03_anomaly_detection.ipynb`  
**Trạng thái:** Đã chạy lại notebook từ đầu thành công; đã push kết quả lên nhánh làm việc.

## 1. Mục tiêu

Áp dụng hai thuật toán phát hiện bất thường không giám sát (Isolation Forest và LOF) để xếp hạng các giao dịch thẻ tín dụng theo mức độ nghi ngờ gian lận. Đánh giá hiệu quả bằng số giao dịch gian lận trong 100 cảnh báo cao nhất (Fraud Top 100), Precision@100, Recall@100 và Average Precision (AP).

**Phạm vi phép đo:** Top 100 được tính trên **toàn bộ mỗi tập** Validation hoặc Test; chưa phải ngân sách rà soát 100 giao dịch **mỗi ngày**.

## 2. Dữ liệu và quy trình

- Nguồn đầu vào: `data/processed/transactions_processed.csv` do quy trình tiền xử lý của nhóm tạo ra, gồm **284.807 dòng, 47 cột**; kiểm tra cho thấy **0 giá trị thiếu**.
- Sử dụng cột `split_random` đã có sẵn, **không chia lại** dữ liệu.
- **1.081** dòng đánh dấu `excluded_duplicate` không thuộc Train/Validation/Test.
- **Train:** 170.235 dòng; **Validation:** 56.745 dòng, gồm 94 gian lận; **Test:** 56.746 dòng, gồm 95 gian lận.
- Đặc trưng đầu vào của cả hai mô hình: **V1–V28** (28 đặc trưng), dùng làm cấu hình baseline. `is_fraud` chỉ dùng để đánh giá, không làm đầu vào huấn luyện hoặc chọn mẫu Train.
- Chuẩn hóa với `StandardScaler` fit trên dữ liệu Train của từng mô hình, sau đó transform Validation/Test. Không fit scaler trên Test.

## 3. Cấu hình mô hình

| Thuật toán | Cấu hình | Tập huấn luyện |
|---|---|---|
| Isolation Forest | `n_estimators=100`, `contamination='auto'`, `random_state=42`, `n_jobs=-1` | 170.235 giao dịch Train |
| LOF | `novelty=True`, `n_neighbors=100`, `n_jobs=-1` | 20.000 giao dịch chọn ngẫu nhiên từ Train, `random_state/seed=42` |

LOF được thử trên Validation với `n_neighbors` thuộc {20, 50, 100, 150, 200}; **100** là cấu hình có AP và Precision@100 cao nhất trong các giá trị đã thử. Sau khi chọn cấu hình bằng Validation, đánh giá trên Test mà không điều chỉnh theo kết quả Test.

## 4. Kết quả Validation

| Thuật toán | Fraud Top 100 | Precision@100 | Recall@100 | AP |
|---|---:|---:|---:|---:|
| Isolation Forest | 29 | 29,00% | 30,85% | 0,2674 |
| LOF (100) | 49 | 49,00% | 52,13% | 0,4708 |

### Tuning LOF trên Validation

| n_neighbors | Fraud Top 100 | Precision@100 | Recall@100 | AP |
|---:|---:|---:|---:|---:|
| 20 | 2 | 2% | 2,13% | 0,0184 |
| 50 | 45 | 45% | 47,87% | 0,3858 |
| 100 | 49 | 49% | 52,13% | 0,4708 |
| 150 | 46 | 46% | 48,94% | 0,4432 |
| 200 | 43 | 43% | 45,74% | 0,4170 |

## 5. Kết quả Test

Trên **56.746** giao dịch Test, có **95** giao dịch gian lận.

| Thuật toán | Fraud Top 100 | Precision@100 | Recall@100 | AP |
|---|---:|---:|---:|---:|
| Isolation Forest | 27 | 27,00% | 28,42% | 0,1609 |
| LOF (100) | 38 | 38,00% | 40,00% | 0,3125 |

### Phân tích lỗi trong Top 100 cảnh báo Test

| Thuật toán | TP (phát hiện đúng) | FP (cảnh báo nhầm) | FN (gian lận bỏ sót) |
|---|---:|---:|---:|
| Isolation Forest | 27 | 73 | 68 |
| LOF (100) | 38 | 62 | 57 |

Trong thí nghiệm này, LOF phát hiện đúng nhiều hơn Isolation Forest **11** trường hợp gian lận trong Top 100 và giảm **11** cảnh báo nhầm. Hiệu quả của cả hai mô hình trên Test thấp hơn trên Validation.

## 6. Giới hạn và lưu ý khi diễn giải

1. **Không đồng nhất ngân sách nghiệp vụ:** Top 100 toàn bộ Test không đại diện cho 100 giao dịch/ngày; chưa nên báo cáo kết quả là Recall@100/ngày.
2. **Quy mô Train khác nhau:** Isolation Forest dùng toàn bộ Train, còn LOF dùng 20.000 mẫu. Vì vậy, so sánh là so sánh hai **cấu hình thí nghiệm hiện tại**, không khẳng định LOF luôn tốt hơn Isolation Forest.
3. **Đặc trưng:** Mới sử dụng V1–V28; chưa đánh giá các biến thời gian/số tiền bổ sung từ pipeline tiền xử lý.
4. **Giao thức dữ liệu:** Đã dùng `split_random` của nhóm và loại các dòng `excluded_duplicate` theo phân chia được cung cấp. Cần thống nhất với nhóm nếu bản cuối chuyển sang `split_temporal` hoặc quy tắc theo ngày.
5. **Chỉ dùng Test một lần để báo cáo:** Không chọn lại tham số theo Test.

## 7. Đầu ra bàn giao

- `notebooks/03_anomaly_detection.ipynb` — notebook có thể chạy lại từ đầu.
- `outputs/model_comparison_processed_validation.csv` — so sánh trên Validation.
- `outputs/lof_tuning_processed_validation.csv` — kết quả tinh chỉnh LOF.
- `outputs/anomaly_scores_test.csv` — điểm bất thường và thứ hạng của từng giao dịch Test theo hai mô hình.
- `outputs/model_error_analysis_processed_test.csv` — TP/FP/FN trên Test.

**Nhánh bàn giao:** `feature/huy-anomaly-detection`; commit kết quả Error Analysis gần nhất được xác nhận: `7e2597d`.

## 8. Kết luận

Trong cấu hình baseline V1–V28 với dữ liệu `split_random` đã tiền xử lý, **LOF (`n_neighbors=100`) cho kết quả tốt hơn Isolation Forest** trên Validation và Test theo Precision@100, Recall@100 và AP. Kết quả phù hợp làm cơ sở cho bước tích hợp và báo cáo của nhóm, với các giới hạn ở mục 6 cần được trình bày rõ.
