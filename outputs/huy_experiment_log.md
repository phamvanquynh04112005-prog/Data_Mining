
# Anomaly Detection — Experiment Log

## 1. Mục tiêu
Phát hiện và xếp hạng các giao dịch thẻ bất thường
bằng Isolation Forest và Local Outlier Factor (LOF).

## 2. Dữ liệu
- Tổng số dòng: 284807
- Tổng số cột: 31
- Số giao dịch gian lận: 492
- Tỷ lệ gian lận: 0.1727%
- Số dòng trùng dư thừa: 1081
- Số giá trị thiếu: 0

## 3. Giao thức thử nghiệm
- Train: 70%
- Validation: 15%
- Test: 15% (chưa đánh giá)
- random_state: 42
- Đặc trưng thử nghiệm: V1-V28
- Lưu ý: Có dòng trùng giữa Train và Validation.
- Trạng thái: Preliminary / Not Final

## 4. Isolation Forest
- n_estimators: 100
- contamination: auto
- Số mẫu train: 199364
- Precision@100: 24%
- Recall@100: 32.43%
- Average Precision: 0.1832

## 5. LOF không giám sát
- Số mẫu train: 20000
- novelty: True
- Các giá trị n_neighbors: 10, 20, 50, 100
- Cấu hình tốt nhất trong các giá trị đã thử: 100
- Precision@100: 39%
- Recall@100: 52.70%
- Average Precision: 0.3266

## 6. Random Baseline
- 100 lần chạy
- Fraud Top 100 trung bình: 0.15
- Precision@100 trung bình: 0.15%
- Recall@100 trung bình: 0.2027%
- AP trung bình: 0.001959

## 7. Các hạn chế
- Chưa xử lý nguy cơ trùng lặp giữa các tập.
- Chưa thống nhất pipeline tiền xử lý với nhóm.
- Chưa đánh giá theo Top 100 giao dịch mỗi ngày.
- Chưa so sánh các mô hình với cùng quy mô train.
- Chưa đánh giá chính thức trên tập Test.

## 8. Quyết định tiếp theo
- Thống nhất xử lý trùng lặp với Cường.
- Thống nhất giao thức đánh giá với Mong.
- Chạy lại mô hình trên dữ liệu chính thức.
- Xuất anomaly_scores_test.csv.
