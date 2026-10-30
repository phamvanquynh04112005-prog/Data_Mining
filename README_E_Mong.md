# Đồ án 6: Phát hiện giao dịch thẻ gian lận. Phần E (Mong): Phân lớp có giám sát và Dashboard

Nhánh: `feature/mong-classification-dashboard`. Cập nhật: 2026-10-30.
Trạng thái chung: **phần mô hình đã chạy trên dữ liệu thật, giao thức đánh giá còn là ĐỀ XUẤT chưa chốt, dashboard chưa làm.**

## 1. Đã làm

- Dựng môi trường: Python 3.13, `pandas==3.0.2`, `scikit-learn==1.8.0` (đúng phiên bản trong `requirements.txt`), JupyterLab.
- Đặt `data/raw/creditcard.csv`, kiểm tra sha256 khớp bản của nhóm (`76274b69…98551a89`).
- Kiểm tra lại số liệu của Khang trên file thật: 284.807 dòng, 31 cột, nhãn là cột `Class`; ngày 0 có 144.786 dòng (281 gian lận), ngày 1 có 140.021 dòng (211 gian lận); không dòng nào ở ngày 1 trùng với ngày 0.
- Đọc `audit_metrics.json` (Khang) và `huy_experiment_log.md` (Huy), nhận ra giao thức của Huy chưa so sánh được với phần này (xem mục 3).
- Viết và chạy `notebooks/04_supervised_classification.ipynb`:
  - Chia theo thời gian: test = ngày 1; train và validation = ngày 0 (validation là 30% cuối theo thời gian). Bỏ `Time` thô; `Amount` dùng log1p.
  - Baseline: đoán lớp đa số và xếp hạng ngẫu nhiên (100 lần chạy).
  - Ba mô hình: Logistic Regression, Random Forest, HistGradientBoosting. Xử lý mất cân bằng bằng trọng số lớp, chỉ trên train; preprocessing nằm trong pipeline; tham số chọn trên validation, không chọn trên test.
  - Chỉ số: Precision@100, Recall@100, PR-AUC. Không dùng accuracy làm chỉ số chính.
- Xuất kết quả vào `outputs/`: `classification_results.csv`, `classification_validation.csv`; `classification_scores_test.csv` (khoảng 10,6 MB) chỉ lưu local, không commit.

## 2. Kết quả sơ bộ trên test (ngày 1, 211 giao dịch gian lận)

**Chưa dùng làm kết quả chính thức** vì giao thức chưa được Huy và Cường xác nhận.

| Mô hình | PR-AUC | Precision@100 | Recall@100 |
|---|---|---|---|
| Random Forest | 0,798 | 0,93 | 0,441 |
| Logistic Regression | 0,754 | 0,96 | 0,455 |
| HistGradientBoosting | 0,701 | 0,95 | 0,450 |
| Xếp hạng ngẫu nhiên (trung bình) | 0,0016 | 0,0015 | 0,0007 |

Cách đọc:
- Với quy tắc rà soát tối đa 100 giao dịch mỗi ngày, trần Recall@100 ở ngày 1 là 100/211 = 47,4%. Cả ba mô hình gần chạm trần.
- Precision@100 và Recall@100 chênh nhau chỉ vài giao dịch, không đủ để kết luận mô hình nào hơn. PR-AUC phân biệt tốt hơn, nhưng chỉ có một ngày test và 211 giao dịch gian lận nên vẫn cần thận trọng.
- Các giao dịch gian lận bị bỏ sót có `Amount` nhỏ (trung vị 7,12). Đây mới là quan sát, chưa kiểm chứng nguyên nhân.

## 3. Chưa làm và đang thiếu gì

| Việc (theo E1 đến E14) | Thiếu gì | Từ ai |
|---|---|---|
| E1: thống nhất schema, feature list, split protocol | Danh sách đặc trưng chính thức, cách xử lý dòng trùng, quyết định tiền xử lý | Cường (B) |
| E1, E7: giao thức đánh giá chung và so sánh với anomaly detection | Huy cần chuyển sang cùng cách chia (ngày 0 train, ngày 1 test) và xếp hạng top 100 theo ngày. Log hiện tại dùng chia ngẫu nhiên 70/15/15, top 100 trên cả validation, đánh dấu Preliminary | Huy (D), cùng Mong |
| E7: bảng so sánh hai họ mô hình | `anomaly_scores_test.csv` có `row_id`, tính theo giao thức chung | Huy (D) |
| E9, E11: nối dashboard với dữ liệu thật | Bảng hoặc view PostgreSQL (star schema) | Quỳnh (C) |
| E10 đến E13: dashboard Superset (≥ 4 biểu đồ, có filter) | Chưa cài Superset; cần dữ liệu từ Quỳnh để đối soát với notebook | Mong |
| E14: bàn giao đầy đủ | Dashboard, nguồn dữ liệu từng biểu đồ, hướng dẫn tái tạo | Mong |

## 4. Công cụ đã sử dụng

- Python 3.13, pandas 3.0.2, scikit-learn 1.8.0, numpy, JupyterLab (cài từ `requirements.txt`).
- Git và GitHub (nhánh riêng, push lên `origin`).
- Dự kiến cho dashboard: Apache Superset (Docker) và PostgreSQL local.
- Claude (Anthropic): hỗ trợ hướng dẫn quy trình, soạn notebook 04 và các lệnh Git. Mã đã được chạy lại trên dữ liệu thật của nhóm.

## 5. Cách chạy lại

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
cd notebooks
jupyter lab
```

Mở `04_supervised_classification.ipynb`, chọn Kernel, Restart Kernel and Run All Cells. Cần `data/raw/creditcard.csv` đúng sha256 của nhóm.

## 6. Giới hạn và cách tránh diễn giải sai

- Giao thức là đề xuất. Nếu đổi cách chia, chỉ cần sửa ô cấu hình (§1) và ô chia dữ liệu (§2) của notebook.
- Test chỉ có 211 giao dịch gian lận: chênh lệch nhỏ giữa các mô hình không có ý nghĩa kết luận.
- Validation chỉ là 30% của ngày 0 nên dùng ngân sách tỉ lệ (30 giao dịch), và chỉ chọn cấu hình bằng PR-AUC.
- V1 đến V28 là thành phần PCA ẩn danh, không diễn giải ý nghĩa nghiệp vụ.
- Mô hình này học từ nhãn, còn anomaly detection thì không. Trong thực tế không phải lúc nào cũng có nhãn.

## 7. Khai báo sử dụng AI

Ghi chi tiết (công cụ, mục đích, phần được chỉnh sửa) theo mẫu của nhóm khi nộp báo cáo.
