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
| `V1…V28` | thành phần PCA | Đã ẩn danh bằng PCA (trung bình ≈ 0; tương quan chéo giữa các thành phần khác nhau: $|r|_{max} = 2,3 \times 10^{-14} \approx 0$ với **$n = 284.807$** — nhất quán với mô tả nguồn) | **Không gán ý nghĩa** (vd. V14) |
| `Amount` | đặc trưng gốc | Five-number summary (**$n = 284.807$**): Min = 0,00; Q1 = 5,60; Median = 22,00; Q3 = 77,16; Max = 25.691,16 (Mean = 88,35; SD = 250,12) | Nguồn không nêu đơn vị tiền |
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
2. **`Time → giờ trong ngày` và `date_key` — ĐÃ THỐNG NHẤT (D-05):** dữ liệu chỉ có giây tương đối. Cường (B) tạo `rel_day` (0, 1), `rel_hour` (0..47), `hour_of_cycle` (0..23) trong `transactions_processed.csv`; Quỳnh (C) tạo `Dim_Date` (`date_key` 0..1, `rel_day_label`) và `Dim_Hour` (`hour_key` 0..47, `hour_in_rel_day` 0..23), ghi rõ trong tên cột/view là thời gian tương đối.
3. **`Dim_Channel` mô phỏng — ĐÃ THỐNG NHẤT:** dataset không có kênh giao dịch thực. Quỳnh (C) tạo `Dim_Channel` gồm 3 kênh mô phỏng (`SYNTH_POS`, `SYNTH_ECOM`, `SYNTH_ATM`) có cột `is_synthetic = TRUE` (ràng buộc `CHECK (is_synthetic = TRUE)`) và tuyệt đối không dùng làm feature cho mô hình học máy.
4. **Khử trùng trước khi chia — ĐÃ THỐNG NHẤT (D-02, D-06):** Cường (B) đánh dấu 1 081 bản sao thừa (`is_duplicate = 1`), giữ 283 726 dòng sạch (`in_model_set = 1`) cho toàn bộ thực nghiệm mô hình của Huy (D) và Mong (E), đồng thời giữ đủ 284 807 dòng có cờ `is_duplicate` cho kho dữ liệu của Quỳnh (C) để đối khớp tổng số dòng raw.
5. **Phân công mục Đạo đức/Riêng tư/Công bằng & Ngân sách rà soát (D-10, D-11):** Ngân sách rà soát cố định `k = 100` giao dịch có điểm rủi ro cao nhất trên tập đánh giá (trần lý thuyết trên Ngày 1 sau khử trùng là `100 / 201 = 49,75%`). Khang (A) cung cấp khung phân tích đạo đức/công bằng (§7) kết hợp số đo thực nghiệm FP/FN ở Top-100 từ Huy (D) và Mong (E).

## 7. Phân tích Đạo đức, riêng tư & công bằng (Tiêu chí 9)

| Ai có thể bị tổn hại | Cơ chế gây hại | Mức độ | Biện pháp giảm thiểu |
|---|---|---|---|
| Chủ thẻ hợp pháp bị khóa thẻ nhầm (false positive) | Giao dịch đúng nhưng hiếm bị xếp vào Top-100; Isolation Forest/LOF có **69–70 false positive/100 cảnh báo**, còn Random Forest có **7 false positive/100 cảnh báo** | **Cao** | Chỉ dùng điểm rủi ro để ưu tiên rà soát, không tự động khóa; xác minh nhẹ bằng OTP/tin nhắn trước khi từ chối; công bố số false positive |
| Chủ thẻ có hành vi chi tiêu hiếm | Mô hình bất thường đo mức *hiếm*, không trực tiếp đo gian lận, nên người có hành vi khác số đông có thể chịu nhiều cảnh báo hơn | **Trung bình–Cao** | So sánh tỷ lệ false positive theo `amount_band`; ghi rõ không thể đánh giá theo nhóm nhân khẩu |
| Nạn nhân/ngân hàng chịu thiệt hại do gian lận lọt lưới (false negative) | Ngày 1 có 201 fraud nhưng ngân sách chỉ rà soát 100; Random Forest bắt 93 và bỏ lọt **108 fraud**, trần lý thuyết Recall@100 là **49,75%** | **Cao** | Công bố trần ngân sách; mở rộng ngân sách theo ca; chỉ cân nhắc chặn tự động ở ngưỡng xác suất cực cao kèm cơ chế khiếu nại/xác minh |
| Nhân viên vận hành rà soát | Nhiều cảnh báo giả gây quá tải và mệt mỏi cảnh báo | **Trung bình** | Theo dõi `Precision@100` theo dải tiền và khung giờ tương đối; ưu tiên hàng đợi theo điểm rủi ro |

- **Quyền riêng tư:** dữ liệu đã ẩn danh bằng PCA và không có định danh trực tiếp; **không** cố gắng khôi phục/ghép với dữ liệu khác; không công bố dòng dữ liệu thô; giữ cục bộ theo quy định học phần (`.gitignore` chặn `data/raw/*` và `data/processed/*`).
- **Phân tích biến đại diện gián tiếp (proxy attributes):** Bộ dữ liệu ULB không chứa thuộc tính nhạy cảm trực tiếp như giới tính, độ tuổi, chủng tộc, thu nhập hay khu vực địa lý. Tuy nhiên, **giá trị giao dịch (`Amount` / `amount_band`)** và **khung giờ tương đối (`rel_hour` / `hour_of_cycle`)** có thể là proxy cho nhóm thu nhập hoặc người lao động làm ca đêm. Ví dụ, một số nhóm có thể phát sinh nhiều giao dịch giá trị nhỏ `0–10`, hoặc giao dịch trong `hour_in_rel_day = 2..4`. Vì không biết mốc giờ lịch thực, đây chỉ là rủi ro proxy cần kiểm tra, không phải kết luận nhân khẩu học. Nhóm đo và công bố tỷ lệ bắt đúng/bỏ sót theo từng `amount_band` (Mục 7.3) để phát hiện mô hình gây bất lợi tập trung lên một phân khúc giao dịch hợp pháp.

## 8. Khai báo sử dụng AI (Tiêu chí 10)

| Công cụ / dịch vụ | Mục đích sử dụng | Phần áp dụng (tệp / mục) | Cách nhóm kiểm chứng kết quả |
|---|---|---|---|
| **Claude (Anthropic) và Gemini / Google Antigravity** | Gợi ý khung code kiểm toán, rà soát logic EDA, định dạng bảng và cấu trúc báo cáo | `notebooks/01_data_audit.ipynb`, `outputs/data_dictionary.csv`, `outputs/data_audit_summary.md`, `outputs/quality_issues.csv` | Khang chạy lại toàn bộ notebook trên dữ liệu thật cục bộ; đối chiếu số dòng, tỷ lệ lớp, thống kê mô tả, checksum và các tệp đầu ra với `outputs/audit_metrics.json` |
| **AI hỗ trợ rà soát liên phần** | Đối chiếu quy trình tiền xử lý, Star Schema, truy vấn SQL và số liệu bàn giao giữa các thành viên | `src/preprocessing.py`, `sql/02-star-schema.sql`, `sql/03-transform.sql`, Mục 6–9 của báo cáo audit | Đối chiếu chéo Python – PostgreSQL – Apache Superset; kiểm tra tên trường/mã kênh trực tiếp từ mã nguồn và chỉ dùng số liệu đã được code tái lập |

**Cam kết bảo mật và trách nhiệm:** Không tải dữ liệu thô `creditcard.csv` lên dịch vụ AI bên thứ ba; chỉ chia sẻ schema hoặc số liệu tổng hợp. Không commit dữ liệu thô hay tệp điểm theo từng dòng lên kho công khai. Khang và cả nhóm chịu trách nhiệm cuối cùng đối với mã nguồn, diễn giải và mọi số liệu được nộp.

## 9. Biên bản bàn giao
| Mục | Nội dung |
|---|---|
| Người bàn giao → nhận | Khang (A) → Cường (B), Quỳnh (C), Huy (D), Mong (E) |
| Phiên bản | Audit v1.1 (đã kiểm chứng & chốt toàn nhóm), sha256 `76274b69…98551a89` |
| Tệp | `notebooks/01_data_audit.ipynb`, `outputs/data_dictionary.csv`, `outputs/quality_issues.csv`, `outputs/audit_metrics.json`, `outputs/amount_band_fraud_rate.csv`, `outputs/relative_hour_fraud_rate.csv`, `figures/fig01–03*.png`, `outputs/license_evidence.md`, `outputs/decision_log.csv` |
| Cách tái tạo | Xem `README.md` (Restart & Run All) |
| Trạng thái Cường (B) | **Đã hoàn thành:** Quyết định `D-01` → `D-11` trong `decision_log.csv`; xuất `src/preprocessing.py`, `outputs/preprocessing_checks.json` và `outputs/processed_schema.json` |
| Trạng thái Quỳnh (C) | **Đã hoàn thành:** Thiết kế Star Schema (`Dim_Date`, `Dim_Hour`, `Dim_AmountBand`, `Dim_Channel` mô phỏng, `Fact_Transaction`) và 6 script SQL nạp kho + đối khớp |
| Trạng thái Huy (D) + Mong (E) | **Đã hoàn thành:** Đánh giá công bằng trên `split_random` và `split_temporal` (Day 0 → Day 1) tại `k = 100`, báo cáo kèm trần lý thuyết và tích hợp điểm vào kho PostgreSQL / Superset |
| Giới hạn đã biết | Mục 5 |
| Việc còn mở | **Về mặt kỹ thuật và quyết định dữ liệu (`D-01` → `D-11`): Đã đóng. Việc chung còn lại của nhóm: Hoàn thiện Báo cáo Word theo `report-template.md` và Slide thuyết trình tuần 15.** |

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
