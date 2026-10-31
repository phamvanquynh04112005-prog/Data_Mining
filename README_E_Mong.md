# Đồ án 6: Phát hiện giao dịch thẻ gian lận. Phần E (Mong): Phân lớp có giám sát và Dashboard

Nhánh: `feature/mong-classification-dashboard`. Cập nhật: 2026-10-31.
Trạng thái chung: **mô hình phân lớp đã chạy trên dữ liệu thật; dashboard Superset đã dựng từ file CSV của notebook (5 biểu đồ, 1 bộ lọc, đã đối soát với notebook); giao thức đánh giá vẫn là ĐỀ XUẤT chưa chốt; chưa nối kho PostgreSQL của Quỳnh.**

## 1. Đã làm

- Dựng môi trường: Python 3.13, `pandas==3.0.2`, `scikit-learn==1.8.0` (đúng phiên bản trong `requirements.txt`), JupyterLab.
- Đặt `data/raw/creditcard.csv`, kiểm tra sha256 khớp bản của nhóm (`76274b69…98551a89`).
- Kiểm tra lại số liệu của Khang trên file thật: 284.807 dòng, 31 cột, nhãn là cột `Class`; ngày 0 có 144.786 dòng (281 gian lận), ngày 1 có 140.021 dòng (211 gian lận); không dòng nào ở ngày 1 trùng với ngày 0.
- Đọc `audit_metrics.json` (Khang) và `huy_experiment_log.md` (Huy), nhận ra giao thức của Huy chưa so sánh được với phần này (xem mục 4).
- Viết và chạy `notebooks/04_supervised_classification.ipynb`:
  - Chia theo thời gian: test = ngày 1; train và validation = ngày 0 (validation là 30% cuối theo thời gian). Bỏ `Time` thô; `Amount` dùng log1p.
  - Baseline: đoán lớp đa số và xếp hạng ngẫu nhiên (100 lần chạy).
  - Ba mô hình: Logistic Regression, Random Forest, HistGradientBoosting. Xử lý mất cân bằng bằng trọng số lớp, chỉ trên train; preprocessing nằm trong pipeline; tham số chọn trên validation, không chọn trên test.
  - Chỉ số: Precision@100, Recall@100, PR-AUC. Không dùng accuracy làm chỉ số chính.
- Xuất kết quả vào `outputs/`: `classification_results.csv`, `classification_validation.csv`; `classification_scores_test.csv` (khoảng 10,6 MB) chỉ lưu local, không commit.
- Dựng dashboard Superset 6.0.0 (Docker Compose, chạy local tại `http://localhost:8088`), nạp hai file CSV vào database `examples` (schema `public`), tạo dashboard **"Đồ án 6 - Phát hiện gian lận thẻ"** (đã Published) gồm 5 biểu đồ và 1 bộ lọc (mục 3). Các câu SQL của dataset ảo lưu tại `sql/dashboard_virtual_datasets_mong.sql`.

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
- Với Random Forest, trong top 100 có 93 giao dịch gian lận. Theo dải số tiền (Amount): dải 0-10 có 92 giao dịch gian lận, bắt được 37 và bỏ sót 55; dải >1000 có 4 giao dịch gian lận, bắt được 0 (mẫu quá nhỏ, không kết luận). Các giao dịch bị bỏ sót có Amount nhỏ (trung vị 7,12). Đây mới là quan sát, chưa kiểm chứng nguyên nhân.

## 3. Dashboard (Superset)

Nguồn dữ liệu hiện tại là **file CSV từ notebook 04 nạp vào database `examples`**, chưa phải kho PostgreSQL của Quỳnh.

| # | Biểu đồ | Câu hỏi trả lời | Dataset | Đối soát |
|---|---|---|---|---|
| 1 | Số giao dịch gian lận bắt được trong top 100 (trên tổng 211) | Bắt được bao nhiêu giao dịch gian lận trong ngân sách 100? | `rf_amount_bands_v2` (SQL ảo) | Notebook §8 và SQL Lab: 93 |
| 2 | Top 100 giao dịch cần rà soát | 100 giao dịch nào cần rà soát? | `classification_scores_test` | SQL Lab: 93 giao dịch có `Class = 1` |
| 3 | Phân bố điểm Random Forest theo nhãn thực | Điểm có tách được gian lận khỏi hợp lệ không? | `rf_score_bins` (SQL ảo) | Tổng 211 gian lận, 139.810 hợp lệ |
| 4 | Giao dịch gian lận được bắt và bỏ sót theo dải số tiền | Bỏ sót nhiều ở dải số tiền nào? | `rf_amount_bands_v2` | Tổng 140.021, 211, 93, 118 |
| 5 | So sánh mô hình: PR-AUC, Precision@100, Recall@100 | Mô hình nào xếp hạng tốt hơn baseline? | `classification_results` | Notebook §7 |

- Bộ lọc `Dải số tiền` (cột `dai_amount`, dataset `rf_amount_bands_v2`) áp dụng cho biểu đồ 1 và 4. Đã kiểm thử: chọn `2) 0-10` thì Big Number đổi từ 93 thành 37 và biểu đồ 4 chỉ còn một cột (37 bắt được, 55 bỏ sót).
- Cảnh báo giới hạn dòng ở biểu đồ 2 (⚠) là chủ ý: ngân sách rà soát là 100 giao dịch mỗi ngày.
- Biểu đồ 3 dùng thang logarit nên cột có giá trị 1 không hiển thị.
- Cách chạy lại dashboard: xem mục 5.

## 4. Chưa làm và đang thiếu gì

| Việc (theo E1 đến E14) | Thiếu gì | Từ ai |
|---|---|---|
| E1: thống nhất schema, feature list, split protocol | Danh sách đặc trưng chính thức, cách xử lý dòng trùng, quyết định tiền xử lý | Cường (B) |
| E1, E7: giao thức đánh giá chung và so sánh với anomaly detection | Huy cần chuyển sang cùng cách chia (ngày 0 train, ngày 1 test) và xếp hạng top 100 theo ngày. Log hiện tại dùng chia ngẫu nhiên 70/15/15, top 100 trên cả validation, đánh dấu Preliminary | Huy (D), cùng Mong |
| E7: bảng so sánh hai họ mô hình | `anomaly_scores_test.csv` có `row_id`, tính theo giao thức chung | Huy (D) |
| E9, E11: nối dashboard với dữ liệu thật của kho | Đọc tài liệu bàn giao và nối các view trong `sql/04-dashboard-views.sql` của Quỳnh (cần PostgreSQL local); sau đó đổi nguồn dataset và đối soát lại số liệu | Quỳnh (C), Mong |
| E14: bàn giao đầy đủ | Ảnh chụp dashboard và export dashboard lưu vào `figures/` | Mong |

## 5. Công cụ đã sử dụng và cách chạy lại

- Python 3.13, pandas 3.0.2, scikit-learn 1.8.0, numpy, JupyterLab (cài từ `requirements.txt`).
- Git và GitHub (nhánh riêng, push lên `origin`).
- Apache Superset 6.0.0 chạy bằng Docker Desktop (Docker Compose `docker-compose-image-tag.yml`), tài liệu Superset ghi rõ không hỗ trợ chính thức cho Windows nhưng chạy được qua Docker.
- Claude (Anthropic): hỗ trợ hướng dẫn quy trình, soạn notebook 04, các câu SQL và lệnh Git. Mã đã được chạy lại trên dữ liệu thật của nhóm.

Chạy lại notebook:

```
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
cd notebooks
jupyter lab
```

Mở `04_supervised_classification.ipynb`, chọn Kernel, Restart Kernel and Run All Cells. Cần `data/raw/creditcard.csv` đúng sha256 của nhóm.

Chạy lại dashboard: dựng Superset 6.0.0 bằng Docker, bật "Allow file uploads to database" cho database `examples`, nạp hai file CSV, tạo các dataset ảo bằng `sql/dashboard_virtual_datasets_mong.sql`, rồi dựng lại 5 biểu đồ theo bảng ở mục 3.

## 6. Giới hạn và cách tránh diễn giải sai

- Giao thức là đề xuất. Nếu đổi cách chia, chỉ cần sửa ô cấu hình (§1) và ô chia dữ liệu (§2) của notebook, rồi nạp lại CSV vào Superset.
- Test chỉ có 211 giao dịch gian lận: chênh lệch nhỏ giữa các mô hình và giữa các dải số tiền không có ý nghĩa kết luận.
- Validation chỉ là 30% của ngày 0 nên dùng ngân sách tỉ lệ (30 giao dịch), và chỉ chọn cấu hình bằng PR-AUC.
- V1 đến V28 là thành phần PCA ẩn danh, không diễn giải ý nghĩa nghiệp vụ.
- Mô hình này học từ nhãn, còn anomaly detection thì không. Trong thực tế không phải lúc nào cũng có nhãn.
- Dashboard hiện đọc file CSV nạp tay, không tự cập nhật khi mô hình thay đổi.

## 7. Khai báo sử dụng AI

Ghi chi tiết (công cụ, mục đích, phần được chỉnh sửa) theo mẫu của nhóm khi nộp báo cáo.
