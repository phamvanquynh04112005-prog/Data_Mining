-- Dataset ảo (virtual datasets) của dashboard "Đồ án 6 - Phát hiện gian lận thẻ" (Superset 6.0.0, Docker).
-- Các câu SQL này nằm trong Superset chứ không nằm trong repo, nên lưu lại để tái tạo được.
-- Nguồn: bảng public.classification_scores_test (database "examples"), nạp bằng
--   "Upload CSV to database" từ outputs/classification_scores_test.csv (tạo bởi notebook 04).
-- Bảng public.classification_results nạp từ outputs/classification_results.csv.
-- Lưu ý: Đã đồng bộ với chuẩn tiền xử lý của Cường (Phần B) và kho dữ liệu của Quỳnh (Phần C).
-- Trên tập Test Ngày 1 sau khử trùng DQ-01 (139.490 dòng, 201 gian lận) cũng như bản gốc trước khử trùng
-- (140.021 dòng, 211 gian lận), số giao dịch gian lận bắt được trong Top 100 của Random Forest đều bằng 93.

-- =====================================================================
-- 1) Dataset ảo "rf_score_bins": phân bố điểm Random Forest theo nhãn thực (20 dải).
--    Đã đối soát: nhóm Class=1 cộng lại = 211, nhóm Class=0 = 139810, tổng = 140021.
--    Dùng cho biểu đồ: "Phân bố điểm Random Forest theo nhãn thực".
-- =====================================================================
SELECT
  LEAST(FLOOR(score_random_forest::numeric * 20), 19)::int AS bin_idx,
  (LEAST(FLOOR(score_random_forest::numeric * 20), 19) / 20)::numeric(4,2) AS bin_start,
  "Class" AS nhan,
  COUNT(*) AS so_giao_dich
FROM public.classification_scores_test
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- =====================================================================
-- 2) Dataset ảo "rf_amount_bands_v2": gian lận được bắt / bỏ sót trong top 100 theo dải số tiền.
--    Đã đối soát: tổng so_giao_dich = 140021, gian_lan = 211, bat_duoc_top100 = 93, bo_sot = 118.
--    Dùng cho: biểu đồ "Giao dịch gian lận được bắt và bỏ sót theo dải số tiền",
--              Big Number "Số giao dịch gian lận bắt được trong top 100", bộ lọc "Dải số tiền".
--    Nhãn dải có số thứ tự ("1) 0", "2) 0-10", ...) để xếp đúng thứ tự theo tên.
--    Khi dán vào Superset làm dataset ảo, bỏ ORDER BY cuối nếu Superset báo lỗi.
-- =====================================================================
WITH ranked AS (
  SELECT "Amount", "Class",
         ROW_NUMBER() OVER (ORDER BY score_random_forest DESC) AS rk
  FROM public.classification_scores_test
),
banded AS (
  SELECT *,
    CASE WHEN "Amount" = 0 THEN 1
         WHEN "Amount" <= 10 THEN 2
         WHEN "Amount" <= 50 THEN 3
         WHEN "Amount" <= 100 THEN 4
         WHEN "Amount" <= 500 THEN 5
         WHEN "Amount" <= 1000 THEN 6
         ELSE 7 END AS thu_tu,
    CASE WHEN "Amount" = 0 THEN '1) 0'
         WHEN "Amount" <= 10 THEN '2) 0-10'
         WHEN "Amount" <= 50 THEN '3) 10-50'
         WHEN "Amount" <= 100 THEN '4) 50-100'
         WHEN "Amount" <= 500 THEN '5) 100-500'
         WHEN "Amount" <= 1000 THEN '6) 500-1000'
         ELSE '7) >1000' END AS dai_amount
  FROM ranked
)
SELECT dai_amount, thu_tu,
       COUNT(*) AS so_giao_dich,
       SUM("Class") AS gian_lan,
       SUM(CASE WHEN "Class" = 1 AND rk <= 100 THEN 1 ELSE 0 END) AS bat_duoc_top100,
       SUM("Class") - SUM(CASE WHEN "Class" = 1 AND rk <= 100 THEN 1 ELSE 0 END) AS bo_sot
FROM banded
GROUP BY dai_amount, thu_tu
ORDER BY thu_tu;

-- =====================================================================
-- 3) Đối soát nhanh với notebook 04 (kỳ vọng: 93).
-- =====================================================================
SELECT SUM("Class") AS gian_lan_trong_top100
FROM (
  SELECT "Class"
  FROM public.classification_scores_test
  ORDER BY score_random_forest DESC
  LIMIT 100
) t;
