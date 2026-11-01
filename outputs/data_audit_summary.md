# Báo cáo Audit dữ liệu ban đầu — Đề tài 6: Phát hiện giao dịch thẻ gian lận
**Người thực hiện:** Khang (thành viên A) · **Bàn giao cho:** Cường (B), Quỳnh (C), Huy (D), Mong (E)
**Nguồn số liệu:** mọi con số bên dưới do `notebooks/01_data_audit.ipynb` tính từ file `creditcard.csv` thật (chi tiết trong `audit_metrics.json`). Các số trong đề chỉ dùng để đối chiếu.

> **Trạng thái: ĐÃ KIỂM CHỨNG** (26/10/2026). Notebook `01_data_audit.ipynb` được Khang chạy lại từ đầu (Restart & Run All) trên máy của mình (Windows, PowerShell, môi trường `.venv`): không lỗi, sha256 file gốc khớp và không đổi, các số liệu chính trùng khớp với lần chạy ban đầu (xem mục 10). **Giấy phép: ĐÃ XÁC MINH** từ trang Kaggle gốc — xem `license_evidence.md`.
---

## 1. Dataset & số đo thật

| Mục | Số đo thật | Brief ghi | Khớp? |
|---|---|---|---|
| Tên file / kích thước | `creditcard.csv` / 150 828 752 byte (≈150,8 MB) | ~150 MB | ✓ |
| sha256 | `76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89` | — | — |
| Số dòng × cột | **284 807 × 31** | 284 807 × 31 | ✓ |
| Kiểu dữ liệu | 30 cột float64 + `Class` int64 | — | — |
| Giao dịch gian lận (`Class=1`) | **492** | 492 | ✓ |
| Tỷ lệ gian lận | **0,1727%** | 0,172% | ✓ |
| Accuracy nếu đoán "không gian lận" cho tất cả | **99,827%** | 99,8% | ✓ |
| Giá trị thiếu | **0** | — | — |

**Một dòng dữ liệu = một giao dịch thẻ** (grain của `Fact_Transaction`). Dataset không có mã thẻ/khách hàng nên không thể gom nhiều giao dịch về một người.

**Nguồn:** Credit Card Fraud Detection — chủ sở hữu trên Kaggle: Nhóm Học máy – ULB (`https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud`). **Giấy phép (theo trang Kaggle, kiểm tra 26/10/2026):** Cơ sở dữ liệu = Open Database (ODbL), Nội dung = Database Contents (DbCL); trang không hiển thị số phiên bản hay điều khoản chi tiết. Theo mô tả của nguồn: thẻ châu Âu, tháng 9/2013, hai ngày, thu thập trong hợp tác Worldline – ULB.

## 2. Cột dữ liệu (chi tiết: `data_dictionary.csv`)
| Cột | Vai trò | Điều được phép nói | Giới hạn |
|---|---|---|---|
| `Time` | đặc trưng gốc | Số giây kể từ giao dịch đầu tiên (0 → 172 792 s ≈ 47,998 giờ) | **Không phải timestamp**; không biết giờ/ngày thật |
| `V1…V28` | thành phần PCA | Đã ẩn danh bằng PCA (trung bình ≈ 0, không tương quan: hệ số tương quan chéo lớn nhất theo trị tuyệt đối ≈ 2,3×10⁻¹⁴ — nhất quán với mô tả nguồn) | **Không gán ý nghĩa** (vd. V14) |
| `Amount` | đặc trưng gốc | Số tiền giao dịch (0 → 25 691,16) | Nguồn không nêu đơn vị tiền |
| `Class` | nhãn | 1 = gian lận, 0 = còn lại | Chỉ để đánh giá; **không đưa vào feature** của mô hình không giám sát |

Mô tả cột lấy từ mô tả công khai của dataset (qua các trang mirror, trùng với mô tả trên trang Kaggle của nhóm ULB).

## 3. Vấn đề chất lượng có bằng chứng (≥3 theo yêu cầu: có 7) — chi tiết: `quality_issues.csv`
| ID | Vấn đề | Bằng chứng đo được | Hệ quả chính | Người duyệt |
|---|---|---|---|---|
| DQ-01 | Dòng trùng lặp hoàn toàn | **1 081** bản sao thừa (1 854 dòng/773 nhóm); trong đó **19 fraud**. Split 70/30 stratify seed 42: **456/85 443** dòng test có bản sao trong train (fraud 7/148) | Rò rỉ nhẹ qua bản sao, nhất là với LOF/k-NN; lệch số đếm giữa notebook/SQL | Cường |
| DQ-02 | `Amount = 0` | **1 825** dòng, **27 fraud** → 1,48% fraud (≈8,6 lần mức trung bình) | Ý nghĩa không rõ; log/chuẩn hoá có thể lỗi | Cường |
| DQ-03 | Mất cân bằng cực đoan | 492/284 807 = 0,1727% | Accuracy vô nghĩa | Huy, Mong |
| DQ-04 | `Amount` lệch phải nặng | skew 17,0; kurtosis 845; 31 904 dòng vượt hàng rào IQR (184,5), có 91 fraud | Cần biến đổi, **không xoá outlier** | Cường |
| DQ-05 | `Time` tương đối, float cho giá trị nguyên | 0 giá trị không nguyên; 160 215 dòng trùng Time với dòng trước; không có ngày/giờ/đơn vị tiền | "Giờ trong ngày", `date_key` thật **không có căn cứ** | Cả nhóm, Quỳnh |
| DQ-06 | Khác thang đo & đuôi nặng | std V* từ 1,96 → 0,33; Amount ≈ 250; Time ≈ 47 488. **1 924** dòng có độ lệch > 10 độ lệch chuẩn (theo trị tuyệt đối) ở ít nhất một V*, chứa **231/492 fraud (47,0%)** | Khoảng cách bị Time/Amount lấn át nếu không chuẩn hoá; xoá "outlier" = mất gần nửa fraud | Cường, Huy |
| DQ-07 | Thiếu siêu dữ liệu | Chỉ 31 cột; không có thẻ/khách/cửa hàng/kênh/quốc gia/đơn vị tiền | `Dim_Channel` chỉ có thể là dữ liệu mô phỏng; không đo công bằng theo nhóm người | Quỳnh, Khang |

Đã kiểm tra nhưng **không phát hiện**: giá trị thiếu (0), `Amount` âm (0), `Amount` có >2 chữ số thập phân (0). Không tính vào số vấn đề.

## 4. Quan sát có ích cho các thành viên khác (mô tả, KHÔNG suy ra nguyên nhân)
- **Trần của câu hỏi nghiệp vụ.** Nếu "ngày" = mỗi 86 400 s: ngày 0 có 144 786 giao dịch/**281** fraud; ngày 1 có 140 021/**211**. Với ngân sách 100/ngày, **một bộ xếp hạng hoàn hảo cũng chỉ bắt tối đa 200/492 = 40,65%** fraud. 100 giao dịch chỉ bằng 0,07% lượng giao dịch trung bình mỗi ngày. → Cần chốt cách hiểu "100 giao dịch/ngày" (mục I.5 của tài liệu nhóm) *trước* khi Huy và Mong chấm điểm; ranh giới ngày 86 400 s là **giả định**. Nên báo cả Recall và "Recall / trần 40,65%" để người đọc không hiểu nhầm.
- **Fraud tập trung ở vài mức Amount.** Trong 492 fraud, 113 giao dịch (23,0%) có Amount đúng 1,00; 27 có 0; 27 có 99,99. Mức 1,00 cũng rất phổ biến trong lớp thường (13 575 dòng), nên tỷ lệ fraud tại Amount=1,00 là ≈0,83% (≈4,8 lần trung bình), chứ không phải 100%. Đây là mô tả, không giải thích được vì sao.
- **Tỷ lệ fraud theo dải Amount** (`amount_band_fraud_rate.csv`): 0 → 1,48%; 0–10 → 0,23%; 10–50 → 0,06%; 50–100 → 0,15%; 100–500 → 0,20%; 500–1000 → 0,42%; >1000 → 0,31%. Chênh nhau nhưng số fraud mỗi dải nhỏ (9–222), nên đừng kết luận mạnh.
- **Giờ tương đối** (`relative_hour_fraud_rate.csv`): số fraud mỗi giờ chỉ 0–57 và nhận gốc thời gian chưa biết, nên **không được viết "ban đêm rủi ro hơn"** (đúng cạm bẫy đã nêu trong brief). Chỉ có thể nói "giờ thứ k kể từ giao dịch đầu".

## 5. Giới hạn dữ liệu
1. Hẹp và cũ: ~2 ngày, tháng 9/2013, thẻ châu Âu → không suy rộng; thử thách "suy giảm theo thời gian" chỉ có hai điểm (ngày 0, ngày 1).
2. Mất cân bằng cực đoan và trần recall 100/ngày (§4).
3. V1–V28 ẩn danh → feature importance của V* không nói được gì về hành vi thật.
4. Không có cột nhân khẩu/nhóm/kênh/mã khách → không đo công bằng theo nhóm người được; chỉ có thể chia theo dải Amount và thời gian tương đối.
5. Nguồn không nêu quy trình gán nhãn → nhãn 0 không bảo đảm "chắc chắn sạch".

## 6. Điểm thống nhất của nhóm (đã chốt trong `outputs/decision_log.csv` D-01 → D-11)
1. **Giấy phép — ĐÃ GIẢI QUYẾT (D-01):** trang Kaggle gốc cho thấy ODbL (database) + DbCL (contents), khớp gợi ý của brief; nguồn thứ cấp ghi CC0 không khớp và không được dùng. Nhóm ghi nguồn đầy đủ theo `outputs/license_evidence.md` và không đăng công khai dữ liệu dẫn xuất.
2. **`Time → giờ trong ngày` và `date_key` — ĐÃ THỐNG NHẤT (D-05, D-08):** dữ liệu chỉ có giây tương đối. Cường (B) và Quỳnh (C) dùng `relative_day` (0, 1) và `relative_hour` (`hour_of_day` 0..23 tương đối, `elapsed_hour` 0..47) cho `dim_date` và `dim_hour`, ghi rõ trong tên cột/view là thời gian tương đối.
3. **`Dim_Channel` mô phỏng — ĐÃ THỐNG NHẤT (D-09):** dataset không có kênh giao dịch thực. Quỳnh (C) tạo `dim_channel` gồm 3 kênh mô phỏng (`POS_SIM`, `ECOM_SIM`, `ATM_SIM`) có cột `is_simulated = TRUE` và không dùng làm feature cho mô hình học máy.
4. **Khử trùng trước khi chia — ĐÃ THỐNG NHẤT (D-02, D-06):** Cường (B) đánh dấu 1 081 bản sao thừa (`is_duplicate = 1`), giữ 283 726 dòng sạch (`in_model_set = 1`) cho toàn bộ thực nghiệm mô hình của Huy (D) và Mong (E), đồng thời giữ đủ 284 807 dòng có cờ `is_duplicate` cho kho dữ liệu của Quỳnh (C) để đối khớp tổng số dòng raw.
5. **Phân công mục Đạo đức/Riêng tư/Công bằng & Ngân sách rà soát (D-10, D-11):** Ngân sách rà soát cố định `k = 100` giao dịch có điểm rủi ro cao nhất trên tập đánh giá (trần lý thuyết trên Ngày 1 sau khử trùng là `100 / 201 = 49,75%`). Khang (A) cung cấp khung phân tích đạo đức/công bằng (§7) kết hợp số đo thực nghiệm FP/FN ở Top-100 từ Huy (D) và Mong (E).

## 7. Phân tích Đạo đức, riêng tư & công bằng (Tiêu chí 9)
**Ai có thể bị hại, bằng cơ chế nào, giảm thiểu ra sao** (đúng yêu cầu "không viết chung chung"):
- **Chủ thẻ hợp pháp bị đánh dấu nhầm (false positive).** Cơ chế: giao dịch đúng nhưng hiếm (đi xa, mua món đắt bất thường, Amount rất nhỏ/bằng 0) bị xếp vào top bất thường → thẻ bị khoá hoặc giao dịch bị từ chối đúng lúc cần (vd. mua thuốc). *Số liệu thực nghiệm tại ngân sách Top-100 (Ngày 1 Test):* mô hình không giám sát (Isolation Forest / LOF) có tới **69–70 false positive / 100 cảnh báo**, trong khi mô hình giám sát (Random Forest) giảm xuống còn **7 false positive / 100 cảnh báo** (`Precision@100 = 93%`). *Giảm thiểu:* điểm rủi ro chỉ dùng để **ưu tiên hàng đợi rà soát của nhân viên**, không tự động khoá thẻ; ưu tiên bước xác minh nhẹ (OTP/tin nhắn xác nhận) trước khi từ chối; báo cáo số false positive trong Top-100 như chi phí trực tiếp đối với khách hàng.
- **Chủ thẻ có thói quen "hiếm".** Cơ chế: Isolation Forest/LOF đo mức *hiếm*, không đo mức *gian lận*; người có hành vi khác số đông bị phạt hệ thống. *Giảm thiểu:* so sánh tỷ lệ false positive theo dải Amount (`amount_band` — biến phân tầng duy nhất đo được trên dashboard Superset); nêu rõ không đo được theo nhóm nhân khẩu.
- **Nạn nhân của gian lận không được rà soát (false negative).** Cơ chế: số lượng gian lận thực tế mỗi ngày vượt ngân sách rà soát 100 giao dịch/ngày (trên toàn bộ dataset: trung bình 246 fraud/ngày, trần 40,65%; trên Ngày 1 sau khử trùng: 201 fraud, trần lý thuyết `100 / 201 = 49,75%`, thực tế Random Forest bắt được **93/201 fraud**, bỏ lọt **108 fraud**). *Giảm thiểu:* báo cáo trung thực trần ngân sách; đề xuất kết hợp chặn tự động cho phân khúc điểm xác suất cực cao (`sup_prob_score >= 0.90`) và mở rộng ngân sách rà soát theo ca.
- **Nhân viên rà soát.** Cơ chế: hàng đợi nhiều false positive gây mệt mỏi cảnh báo (alert fatigue). *Giảm thiểu:* theo dõi `Precision@100` theo từng khung giờ tương đối và dải số tiền trên Dashboard Superset.
- **Quyền riêng tư:** dữ liệu đã ẩn danh bằng PCA và không có định danh trực tiếp; **không** cố gắng khôi phục/ghép với dữ liệu khác; không công bố dòng dữ liệu thô; giữ cục bộ theo quy định học phần (`.gitignore` chặn `data/raw/*` và `data/processed/*`).
- **Công bằng theo nhóm:** dataset **không có thuộc tính nhạy cảm** (giới tính, độ tuổi, thu nhập, khu vực), nên nhóm báo cáo trung thực giới hạn này và không suy diễn theo nhóm nhân khẩu.

## 8. Khai báo sử dụng AI (Tiêu chí 10)
AI hỗ trợ: gợi ý khung code kiểm toán dữ liệu (`notebooks/01_data_audit.ipynb`), đối chiếu quy trình tiền xử lý (`src/preprocessing.py`), viết truy vấn kiểm chứng đối khớp SQL và cấu trúc báo cáo. Toàn bộ số liệu trong báo cáo được tính toán trực tiếp bằng code chạy cục bộ trên file `creditcard.csv` (`sha256 = 76274b69...98551a89`) và đối chiếu chéo giữa Python — PostgreSQL — Apache Superset. Nhóm tuân thủ nguyên tắc chỉ chia sẻ số liệu tổng hợp (summary metrics) và schema trong quá trình hoàn thiện báo cáo, không commit dữ liệu thô hoặc file điểm dòng chi tiết dung lượng lớn lên kho mã nguồn công khai.

## 9. Biên bản bàn giao
| Mục | Nội dung |
|---|---|
| Người bàn giao → nhận | Khang (A) → Cường (B), Quỳnh (C), Huy (D), Mong (E) |
| Phiên bản | Audit v1.1 (đã kiểm chứng & chốt toàn nhóm), sha256 `76274b69…98551a89` |
| Tệp | `notebooks/01_data_audit.ipynb`, `outputs/data_dictionary.csv`, `outputs/quality_issues.csv`, `outputs/audit_metrics.json`, `outputs/amount_band_fraud_rate.csv`, `outputs/relative_hour_fraud_rate.csv`, `figures/fig01–03*.png`, `outputs/license_evidence.md`, `outputs/decision_log.csv` |
| Cách tái tạo | Xem `README.md` (Restart & Run All) |
| Trạng thái Cường (B) | **Đã hoàn thành:** Quyết định DQ-01, DQ-02, DQ-04, DQ-06 trong `decision_log.csv`; xuất `src/preprocessing.py` và `preprocessing_metadata.json` |
| Trạng thái Quỳnh (C) | **Đã hoàn thành:** Thiết kế Star Schema (`dim_date`, `dim_hour`, `dim_amount_band`, `dim_channel` mô phỏng, `fact_transaction`) và 6 script SQL nạp kho + đối khớp |
| Trạng thái Huy (D) + Mong (E) | **Đã hoàn thành:** Đánh giá công bằng trên `split_random` và `split_temporal` (Day 0 → Day 1) tại `k = 100`, báo cáo kèm trần lý thuyết và tích hợp điểm vào kho PostgreSQL / Superset |
| Giới hạn đã biết | Mục 5 |
| Việc còn mở | **Không còn (Đã đóng toàn bộ quyết định D-01 → D-11 trong `outputs/decision_log.csv`)** |

## 10. Kết quả kiểm thử tái lập (Khang chạy trên máy, 26/10/2026)
| Mục | Kết quả trên máy Khang | Kết quả lần chạy đầu | Khớp |
|---|---|---|---|
| sha256 file gốc (trước và sau khi chạy) | `76274b69…98551a89`, không đổi | `76274b69…98551a89` | ✓ |
| Số dòng × cột | 284 807 × 31 | 284 807 × 31 | ✓ |
| Fraud / ô thiếu | 492 / 0 | 492 / 0 | ✓ |
| Bản sao thừa (trong đó fraud) | 1 081 (19) | 1 081 (19) | ✓ |
| `Amount = 0` (trong đó fraud) | 1 825 (27) | 1 825 (27) | ✓ |
| Trần: fraud bắt được tối đa @100/ngày | 200 → 40,65% | 200 → 40,65% | ✓ |
| Dòng test có bản sao trong train (split 70/30, seed 42) | 456 | 456 | ✓ |
| Chạy notebook | Run All không lỗi; ô cuối in `OK — checksum raw không đổi` | không lỗi | ✓ |

Phạm vi kiểm thử: các chỉ số chính trong bảng được đối chiếu bằng cách đọc `audit_metrics.json` do máy Khang tạo ra. Các số còn lại (skew, IQR, số dòng |z|>10, tỷ lệ theo dải Amount...) do cùng notebook tính, nhưng chưa được đối chiếu từng số thủ công.
