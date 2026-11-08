# Hồ sơ nguồn & giấy phép — Credit Card Fraud Detection (ULB)

**Trạng thái: ĐÃ XÁC MINH từ trang Kaggle gốc** (hai ảnh chụp do Khang cung cấp, kiểm tra ngày 26/10/2026).

## 1. Bảng xác minh
| Mục | Giá trị |
|---|---|
| URL trang dataset | https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud |
| Ngày kiểm tra | 26/10/2026 |
| Người kiểm tra | Khang (A) |
| Chủ sở hữu trên Kaggle | Nhóm Học máy – ULB (Machine Learning Group – ULB) |
| Giấy phép hiển thị (nguyên văn, giao diện tiếng Việt) | "Cơ sở dữ liệu: Cơ sở dữ liệu mở, Nội dung: Nội dung cơ sở dữ liệu" (ảnh 1 hiển thị bản tiếng Anh: "Database: Open Database, Contents: Database Contents") |
| Cách hiểu | Cơ sở dữ liệu theo *Open Database License (ODbL)*; nội dung từng bản ghi theo *Database Contents License (DbCL)* — tên theo cách Kaggle đặt |
| Số phiên bản giấy phép | **Kaggle không hiển thị** |
| Điều khoản chi tiết trên trang | **Không có** ngoài tên giấy phép (theo xác nhận của Khang) |
| Tác giả / DOI / Nguồn / Phương pháp thu thập / Trích dẫn (ô metadata) | Đều để trống ("-") |
| Cập nhật gần nhất | "Cách đây 9 năm", tần suất không được chỉ định |
| Bằng chứng | 2 ảnh chụp mục *Giấy phép* và các mục metadata của trang |

Giới hạn của bằng chứng: hai ảnh chụp không bao gồm thanh địa chỉ nên ngày/URL dựa trên xác nhận của người chụp.

## 2. Đối chiếu với các nguồn khác
| Nguồn | Nội dung | Kết luận |
|---|---|---|
| Brief của giảng viên | "thường là ODbL" | Khớp phần *database* |
| Bài báo arXiv 2401.04139 | DbCL v1.0 | Khớp phần *contents* |
| Trang dữ liệu TU Wien (thử nghiệm) | "CC-0" | **Không khớp**; không dùng |

## 3. Cách ghi nguồn trong báo cáo
> Machine Learning Group – ULB. *Credit Card Fraud Detection* [tập dữ liệu]. Kaggle. https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud. Giấy phép: Open Database (ODbL) cho cơ sở dữ liệu, Database Contents (DbCL) cho nội dung — theo trang Kaggle. Truy cập ngày 26/10/2026.

Không ghi DOI hay tên tác giả cá nhân, vì metadata Kaggle để trống. Mô tả dài của dataset nêu bối cảnh hợp tác Worldline – ULB và danh sách tài liệu liên quan; nếu nhóm muốn trích, hãy chép từ phần "Giới thiệu về tập dữ liệu" của trang.

## 4. Lưu ý sử dụng (hiểu biết chung, không phải tư vấn pháp lý)
Trang Kaggle không nêu điều khoản chi tiết, nên phần này không phải điều khoản đọc trên trang. ODbL thường kèm yêu cầu ghi nguồn và chia sẻ lại cùng giấy phép nếu công bố công khai một cơ sở dữ liệu phái sinh. Để tuân thủ chặt chẽ: ghi nguồn đầy đủ theo Mục 3; không đăng công khai dữ liệu giao dịch thô (`data/raw/creditcard.csv`) hay bảng đặc trưng dẫn xuất chứa `Time`, `Amount`, `V1..V28` (`data/processed/transactions_processed.csv`, `outputs/classification_scores_test.csv`). Các tệp điểm mô hình phục vụ đối sánh và chấm tự động Kho dữ liệu PostgreSQL (`outputs/model_scores_warehouse.csv` lưu `txn_id, split_set` và điểm 3 mô hình; `outputs/anomaly_scores_test.csv` lưu `txn_id, is_fraud, split` cùng điểm và thứ hạng 2 mô hình) hoàn toàn không chứa bất kỳ thuộc tính đặc trưng gốc `Time`, `Amount` hay `V1..V28` nào của bộ dữ liệu.

## 5. Quy định vận hành liên quan
- Không commit dữ liệu thô và bảng đặc trưng (`.gitignore` đã chặn `data/raw/*`, `data/processed/*` và `outputs/classification_scores_test.csv`).
- Mỗi thành viên tự tải từ Kaggle và đối chiếu sha256 `76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89`.
