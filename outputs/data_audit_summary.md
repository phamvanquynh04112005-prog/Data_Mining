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

## 6. Mâu thuẫn / điểm cần nhóm xác nhận (không tự sửa yêu cầu giảng viên)
1. **Giấy phép — đã giải quyết:** trang Kaggle gốc cho thấy ODbL (database) + DbCL (contents), khớp gợi ý của brief; nguồn thứ cấp ghi CC0 không khớp và không được dùng. Chỉ còn nhắc nhóm ghi nguồn đúng cách và không đăng công khai dữ liệu dẫn xuất.
2. **`Time → giờ trong ngày` và `date_key` (brief, mục đồ án 6)** ↔ dữ liệu chỉ có giây tương đối. Đề xuất: `Dim_Hour`/`Dim_Date` dùng *giờ tương đối* và *ngày tương đối*, đặt tên rõ. Cần Cường, Quỳnh đồng ý (mục I.3).
3. **`Dim_Channel` mô phỏng:** dataset không có kênh. Brief cho phép "mô phỏng"; nếu dùng phải ghi rõ synthetic. Nếu nhóm thấy không hợp lý → hỏi giảng viên (mục I.4).
4. **Khử trùng trước khi chia?** (DQ-01) — Cường quyết định, ghi decision log.
5. **Ai phụ trách mục Đạo đức/Riêng tư/Công bằng?** Bản phân công đầu liệt kê nó trong phần việc của Khang; bản "chuẩn hóa" (D1) không còn mục này, trong khi tiêu chí 9 chiếm 0,75 điểm. Dưới đây là bản nháp đầu vào do Khang soạn; nhóm cần chốt người chịu trách nhiệm cuối.

## 7. Đầu vào cho mục Đạo đức, riêng tư & công bằng (bản nháp)
**Ai có thể bị hại, bằng cơ chế nào, giảm thiểu ra sao** (đúng yêu cầu "không viết chung chung"):
- **Chủ thẻ hợp pháp bị đánh dấu nhầm (false positive).** Cơ chế: giao dịch đúng nhưng hiếm (đi xa, mua món đắt bất thường, Amount rất nhỏ/bằng 0) bị xếp vào top bất thường → thẻ bị khoá hoặc giao dịch bị từ chối đúng lúc cần (vd. mua thuốc). *Giảm thiểu:* điểm bất thường chỉ dùng để **ưu tiên hàng đợi rà soát của nhân viên**, không tự động khoá; ưu tiên bước xác minh nhẹ (nhắn tin xác nhận) trước khi từ chối; đo và báo cáo số false positive trong top-100 như chi phí đối với người dùng, không chỉ chi phí của ngân hàng.
- **Chủ thẻ có thói quen "hiếm".** Cơ chế: Isolation Forest/LOF đo mức *hiếm*, không đo mức *gian lận*; người có hành vi khác số đông bị phạt hệ thống. *Giảm thiểu:* so sánh tỷ lệ false positive theo dải Amount (biến duy nhất đo được); nêu rõ không đo được theo nhóm nhân khẩu.
- **Nạn nhân của gian lận không được rà soát.** Cơ chế: trung bình 246 fraud/ngày > ngân sách 100 → trung bình ~146 fraud/ngày nằm ngoài khả năng rà soát (ngày 0: 181, ngày 1: 111). *Giảm thiểu:* báo cáo trung thực trần 40,65%; đề xuất cân nhắc tăng ngân sách hoặc thêm luật chặn tự động cho nhóm rủi ro rất cao.
- **Nhân viên rà soát.** Cơ chế: hàng đợi nhiều false positive gây mệt mỏi cảnh báo. *Giảm thiểu:* theo dõi precision@100 theo thời gian.
- **Quyền riêng tư:** dữ liệu đã ẩn danh bằng PCA và không có định danh trực tiếp; **không** cố gắng khôi phục/ghép với dữ liệu khác; không công bố dòng dữ liệu thô; giữ cục bộ theo quy định học phần.
- **Công bằng theo nhóm:** dataset **không có thuộc tính nhạy cảm**, nên chỉ nói được điều này một cách trung thực và không bịa số liệu theo nhóm.

## 8. Khai báo sử dụng AI (bản nháp cho tiêu chí 10)
AI (Claude) hỗ trợ: viết code notebook audit, soạn bản nháp báo cáo này. Số liệu được tính bằng code chạy trên file `creditcard.csv`; Khang cần chạy lại trên máy mình và đối chiếu. **Lưu ý quy định:** file dữ liệu thô đã được tải lên một dịch vụ AI để chạy audit — tài liệu học phần ghi "không tải dữ liệu lên dịch vụ của bên thứ ba". Dataset là dữ liệu công khai, đã ẩn danh, nhưng Khang cần báo trưởng nhóm/giảng viên và ghi vào khai báo AI (việc còn mở); từ nay các thành viên khác nên chạy notebook cục bộ và chỉ gửi *kết quả tổng hợp* cho AI, không gửi file thô.

## 9. Biên bản bàn giao
| Mục | Nội dung |
|---|---|
| Người bàn giao → nhận | Khang → Cường, Quỳnh, Huy, Mong |
| Phiên bản | Audit v1 (đã kiểm chứng 26/10/2026), sha256 `76274b69…98551a89` |
| Tệp | `notebooks/01_data_audit.ipynb`, `outputs/data_dictionary.csv`, `outputs/quality_issues.csv`, `outputs/audit_metrics.json`, `outputs/amount_band_fraud_rate.csv`, `outputs/relative_hour_fraud_rate.csv`, `figures/fig01–03*.png`, `outputs/license_evidence.md` |
| Cách tái tạo | Xem `README.md` (Restart & Run All) |
| Cần Cường làm | Quyết định DQ-01, DQ-02, DQ-04, DQ-06; công bố schema đầu ra |
| Cần Quỳnh biết | Không có ngày/giờ thật; `Dim_Channel` là mô phỏng; grain = 1 giao dịch |
| Cần Huy + Mong biết | Trần recall 40,65% @100/ngày; dùng split phân tầng; cẩn trọng bản sao |
| Giới hạn đã biết | Mục 5 |
| Việc còn mở | (1) Khang báo trưởng nhóm việc đã đưa CSV thô lên dịch vụ AI và ghi vào khai báo AI; (2) nhóm chốt cách hiểu "100 giao dịch/ngày"; (3) nhóm chốt người phụ trách mục đạo đức |

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
