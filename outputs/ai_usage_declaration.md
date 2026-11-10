# Phụ lục A — Bảng A1: Khai báo sử dụng AI của cả nhóm (Tiêu chí 10)

> Đây là bảng **hợp nhất, có hiệu lực chính thức**. Mục khai báo AI trong `data_audit_summary.md` (A), `cuong_work.md` (B), `olap_and_handover_summary.md` (C), `huy_anomaly_detection_report.md` (D) và `README_E_Mong.md` (E) chỉ là bản chi tiết của từng phần và đều trỏ về bảng này.
>
> **Chính sách của học phần:** AI chỉ được dùng để (1) giải thích khái niệm, (2) hỗ trợ tìm và sửa lỗi, (3) gợi ý cú pháp, (4) chỉnh câu chữ. Mọi quyết định phân tích, thiết kế và diễn giải kết quả phải do nhóm đưa ra, và mỗi thành viên phải giải thích được từng dòng code của phần mình.

## A1. Bảng khai báo

**Công cụ dùng chung:** Claude (Anthropic) và Gemini qua Google Antigravity, GitHub Copilot / ChatGPT (Huy).

| Thành viên | AI đã hỗ trợ việc gì | Nhóm chính sách | Phần nào là của nhóm | Cách kiểm chứng |
|---|---|---|---|---|
| **Khang (A)** — Audit | Giải thích cách đọc phân phối lệch, kiểm định trùng lặp, cách kiểm tra sha256; gợi ý cú pháp pandas cho thống kê mô tả; chỉnh câu chữ `data_audit_summary.md` | (1), (3), (4) | Chọn các phép kiểm tra chất lượng, phát hiện và đặt mã `DQ-01..DQ-07`, đánh giá mức độ trong bảng đạo đức, kết luận về giấy phép và quyền riêng tư | Chạy lại `01_data_audit.ipynb` trên dữ liệu thật; đối chiếu số dòng, tỷ lệ lớp, sha256 với `outputs/audit_metrics.json` |
| **Cường (B)** — Tiền xử lý | Giải thích khái niệm rò rỉ dữ liệu và chia tập phân tầng; gợi ý cú pháp viết hàm kiểm tra rò rỉ; sửa lỗi khi chạy `src/preprocessing.py`; định dạng `decision_log.csv` | (1), (2), (3), (4) | 11 quyết định `D-01..D-11` (giữ outlier, giữ `Amount = 0`, khử trùng, biến đổi `Time` thành giờ tương đối, giao thức `split_temporal` / `split_random` / `cv_fold`, `random_state = 42`); phát hiện 12.446 dòng trùng `V1..V28` | Chạy lại `src/preprocessing.py`; sha256 đầu ra `e8bf7dcd…28958` khớp `outputs/preprocessing_checks.json` (đã tái lập trên máy khác ngày 08/11) |
| **Quỳnh (C)** — Kho dữ liệu / SQL | Giải thích `ROLLUP`, `CUBE`, `GROUPING SETS`, hàm cửa sổ; gợi ý cú pháp PostgreSQL; sửa lỗi tên view/cột khi chạy script; chỉnh câu chữ tài liệu bàn giao | (1), (2), (3), (4) | Thiết kế Star Schema (Fact_Transaction và các Dim), thứ tự nạp 01 → 05, quy tắc lọc `is_duplicate = FALSE` cho mẫu số 201, chọn 3 truy vấn OLAP và cách diễn giải | Chạy 6 script trên PostgreSQL 16; đối chiếu 284.807 dòng, 492 gian lận, 139.490 dòng Ngày 1, đối soát 93 / 31 / 30 |
| **Huy (D)** — Phát hiện bất thường | Giải thích Isolation Forest, LOF (`novelty=True`), PR-AUC, Precision@K; gợi ý cú pháp vòng 5-fold và bố cục biểu đồ 2 panel; sửa lỗi chuẩn hóa trước khi lấy mẫu LOF | (1), (2), (3) | Chọn 2 mô hình và 2 baseline, giao thức chính Ngày 0 → Ngày 1 với K = 100, chọn `n_neighbors = 100` trên Validation, diễn giải chênh lệch giữa hai giao thức, chọn giao dịch điển hình (Phần IV) | Restart & Run All `03_anomaly_detection.ipynb`; đối chiếu IF 31/201, LOF 30/201 và 5-fold với kho PostgreSQL và bảng của Mong |
| **Mong (E)** — Phân lớp & Dashboard | Giải thích chọn mô hình theo Validation, Stratified K-Fold; gợi ý cú pháp truy vấn ảo cho Superset; sửa lỗi kết nối Superset ↔ PostgreSQL; chỉnh câu chữ README | (1), (2), (3), (4) | Chọn họ mô hình và tiêu chí chọn (Random Forest theo Validation), phân tích lỗi theo dải tiền, chọn 7 biểu đồ và nội dung thông điệp dashboard | Chạy lại `04_supervised_classification.ipynb`; RF 93/201 khớp Notebook, `Fact_Transaction` và SQL Lab |

## A2. Phần AI vượt phạm vi và cách nhóm xử lý

Trong quá trình làm, có giai đoạn AI đã **đề xuất cả khối code hoặc đoạn văn** (khung vòng 5-fold, runner `sql/run_pipeline.py`, một số truy vấn ảo của dashboard, các file tổng hợp `.md`). Việc này vượt quá nhóm (3) “gợi ý cú pháp”. Nhóm xử lý như sau:

- Mỗi khối như vậy đã được thành viên phụ trách đọc lại, chạy lại trên dữ liệu thật, và sửa khi sai (ví dụ: tên view, cột `rel_hour`, thứ tự chuẩn hóa trước khi lấy mẫu LOF).
- Mọi **quyết định** (giao thức, tham số, mẫu số, cách diễn giải) nằm ở cột “Phần nào là của nhóm” và do nhóm tự đưa ra.
- Mỗi thành viên cam kết giải thích được từng dòng code của phần mình khi vấn đáp.

> [!IMPORTANT]
> **Từng thành viên cần tự đọc lại dòng của mình và sửa cho đúng thực tế trước khi nộp.** Bảng này được soạn từ các mục khai báo sẵn có trong repo; nếu dòng nào chưa khớp với cách bạn đã dùng AI, hãy sửa trực tiếp — không khai thấp hơn thực tế.

## A3. Cam kết của nhóm

Chúng tôi cam kết: (1) không tải dữ liệu thô `creditcard.csv` hay bảng đặc trưng chứa `Time`, `Amount`, `V1..V28` lên bất kỳ dịch vụ AI nào, chỉ chia sẻ schema hoặc số liệu tổng hợp; (2) mọi con số trong báo cáo đều được sinh ra bằng code trong repo và đã được chạy lại, không có số gõ tay; (3) mọi quyết định phân tích và diễn giải là của nhóm; (4) mỗi thành viên hiểu và giải thích được từng dòng code của phần mình, và cả nhóm chịu trách nhiệm cuối cùng về toàn bộ nội dung nộp.

| Thành viên | Xác nhận đã đọc và đồng ý |
|---|---|
| Khang (A) | ☐ |
| Cường (B) | ☐ |
| Quỳnh (C) | ☐ |
| Huy (D) | ☐ |
| Mong (E) | ☐ |
