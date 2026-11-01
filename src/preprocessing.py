"""Tiền xử lý dùng chung — Thành viên B (Cường), Đề tài 6: Phát hiện giao dịch thẻ gian lận.

Module này là "hợp đồng dữ liệu" (data contract) cho Quỳnh (C), Huy (D), Mong (E):
- `build_processed()` biến file raw thành bảng đã xử lý (giữ ĐỦ 284 807 dòng, không xoá dòng nào;
  bản sao được GẮN CỜ chứ không xoá) + các cột chia tập cố định với random_state=42.
- Chỉ các biến đổi KHÔNG HỌC TỪ DỮ LIỆU (stateless: log1p, chia giờ, dải tiền) được tính sẵn trong file.
- Các biến đổi CÓ HỌC TỪ DỮ LIỆU (StandardScaler) chỉ nằm trong `make_preprocessor()` và PHẢI được
  fit trên tập train/fold tương ứng → không rò rỉ thông tin từ validation/test.

Mọi quyết định ở đây được ghi trong outputs/decision_log.csv (mã D-xx được nhắc trong comment).
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.preprocessing import StandardScaler

SCHEMA_VERSION = "1.0"
RANDOM_STATE = 42

# Khang đã kiểm chứng checksum này trong 01_data_audit (audit_metrics.json)
EXPECTED_SHA256 = "76274b691b16a6c49d3f159c883398e03ccd6d1ee12d9d8ee38f4b4b98551a89"
EXPECTED_SHAPE = (284807, 31)

V_COLS = [f"V{i}" for i in range(1, 29)]
RAW_COLS = ["Time", *V_COLS, "Amount", "Class"]

LABEL = "is_fraud"
# D-07: bộ đặc trưng mặc định cho mô hình = V1..V28 + log1p(Amount).
# Không đưa time_sec / rel_day / rel_hour vào mặc định (xem decision log).
FEATURES = [*V_COLS, "amount_log1p"]
# Biến thể tuỳ chọn để Huy/Mong thử trên VALIDATION (không phải test): thêm chu kỳ 24h tương đối.
FEATURES_WITH_CYCLE = [*FEATURES, "hour_cycle_sin", "hour_cycle_cos"]

SECONDS_PER_HOUR = 3600
SECONDS_PER_DAY = 86400  # D-05: ranh giới "ngày" = 86 400 s kể từ giao dịch đầu — là GIẢ ĐỊNH
REVIEW_BUDGET_PER_DAY = 100

# D-08: cùng ranh giới dải tiền với Khang (amount_band_fraud_rate.csv) để số liệu khớp nhau.
# Nhãn dùng dấu gạch ASCII cho dễ dùng trong SQL.
AMOUNT_BIN_EDGES = [-np.inf, 0, 10, 50, 100, 500, 1000, np.inf]
AMOUNT_BAND_LABELS = ["0", "0-10", "10-50", "50-100", "100-500", "500-1000", ">1000"]

SPLIT_EXCLUDED = "excluded_duplicate"

# Thứ tự cột của file đã xử lý (KHÔNG đổi tên/thứ tự mà không tăng SCHEMA_VERSION và báo nhóm)
PROCESSED_COLS = [
    "txn_id", "time_sec", "rel_day", "rel_hour", "hour_of_cycle", "hour_cycle_sin", "hour_cycle_cos",
    "amount", "amount_log1p", "amount_band_id", "amount_band", "is_zero_amount",
    *V_COLS,
    LABEL, "is_duplicate", "dup_of_txn_id", "in_model_set",
    "split_temporal", "split_random", "cv_fold",
]


# --------------------------------------------------------------------------------------------
# Nạp dữ liệu
# --------------------------------------------------------------------------------------------
def file_sha256(path: Path | str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_raw(path: Path | str, verify: bool = True) -> pd.DataFrame:
    """Đọc creditcard.csv (chỉ đọc, không ghi đè). Kiểm tra checksum/shape/cột như audit của Khang."""
    path = Path(path)
    if verify:
        got = file_sha256(path)
        if got != EXPECTED_SHA256:
            raise ValueError(f"sha256 khác audit của Khang: {got} — đang dùng phiên bản file khác, báo nhóm trước khi tiếp tục.")
    raw = pd.read_csv(path, float_precision="round_trip")
    if list(raw.columns) != RAW_COLS:
        raise ValueError(f"Cột khác schema đã audit: {list(raw.columns)}")
    if raw.shape != EXPECTED_SHAPE:
        raise ValueError(f"Shape {raw.shape} khác audit {EXPECTED_SHAPE}")
    return raw


# --------------------------------------------------------------------------------------------
# Biến đổi không học từ dữ liệu + gắn cờ + chia tập
# --------------------------------------------------------------------------------------------
def build_processed(raw: pd.DataFrame) -> pd.DataFrame:
    """Trả về bảng đã xử lý theo PROCESSED_COLS. Không xoá dòng nào của raw."""
    df = pd.DataFrame(index=raw.index)

    # D-01: txn_id = số thứ tự dòng trong file raw (1-based). Tái lập được vì file cố định theo sha256.
    df["txn_id"] = np.arange(1, len(raw) + 1, dtype=np.int64)

    # D-05: Time là giây TƯƠNG ĐỐI (audit DQ-05: 0 giá trị không nguyên) → ép int an toàn.
    t = raw["Time"]
    if not (t == t.round()).all():
        raise ValueError("Time có giá trị không nguyên — khác audit, không ép int được.")
    df["time_sec"] = t.astype(np.int64)
    df["rel_day"] = (df["time_sec"] // SECONDS_PER_DAY).astype(np.int64)      # 0/1, giả định
    df["rel_hour"] = (df["time_sec"] // SECONDS_PER_HOUR).astype(np.int64)    # 0..47
    df["hour_of_cycle"] = (df["rel_hour"] % 24).astype(np.int64)              # chu kỳ 24h TƯƠNG ĐỐI, KHÔNG phải giờ đồng hồ
    angle = 2 * np.pi * (df["time_sec"] % SECONDS_PER_DAY) / SECONDS_PER_DAY
    df["hour_cycle_sin"] = np.sin(angle)
    df["hour_cycle_cos"] = np.cos(angle)

    # D-03/D-04: giữ nguyên Amount (kể cả =0 và đuôi dài); log1p xác định tại 0, không cần fit.
    amt = raw["Amount"]
    if (amt < 0).any():
        raise ValueError("Có Amount âm — khác audit.")
    df["amount"] = amt
    df["amount_log1p"] = np.log1p(amt)
    band = pd.cut(amt, AMOUNT_BIN_EDGES, right=True, labels=False)
    df["amount_band_id"] = band.astype(np.int64)
    df["amount_band"] = pd.Series(AMOUNT_BAND_LABELS, dtype=object).iloc[df["amount_band_id"]].to_numpy()
    df["is_zero_amount"] = (amt == 0).astype(np.int64)

    for c in V_COLS:
        df[c] = raw[c]

    df[LABEL] = raw["Class"].astype(np.int64)

    # D-02: bản sao hoàn toàn (cả 31 cột raw giống nhau) → giữ bản đầu tiên cho mô hình,
    # gắn cờ các bản sau; KHÔNG xoá khỏi file (Quỳnh vẫn nạp đủ để đối soát với raw).
    df["is_duplicate"] = raw.duplicated(keep="first").astype(np.int64)
    row_hash = pd.util.hash_pandas_object(raw, index=False)
    df["dup_of_txn_id"] = df.groupby(row_hash.to_numpy())["txn_id"].transform("min").astype(np.int64)
    # dup_of_txn_id = txn_id của bản giữ lại; với dòng không trùng thì bằng chính nó.
    df["in_model_set"] = (1 - df["is_duplicate"]).astype(np.int64)

    _assign_splits(df)
    return df[PROCESSED_COLS]


def _assign_splits(df: pd.DataFrame) -> None:
    """D-06: hai giao thức chia tập cố định (random_state=42), chỉ trên các dòng in_model_set=1.

    split_temporal (giao thức CHÍNH đề xuất cho câu hỏi "100 giao dịch/ngày"):
        rel_day=1 → test (cả một "ngày" tương đối, top-100 có nghĩa đúng như nghiệp vụ);
        rel_day=0 → train/val phân tầng 80/20 theo nhãn.
    split_random (giao thức PHỤ để báo độ dao động): phân tầng 60/20/20 train/val/test.
    cv_fold: StratifiedKFold(5) trên phần train+val của split_random (test giữ nguyên = -1).
    """
    m = df["in_model_set"] == 1
    df["split_temporal"] = SPLIT_EXCLUDED
    df["split_random"] = SPLIT_EXCLUDED
    df["cv_fold"] = -1

    # --- temporal
    day0 = df.index[m & (df["rel_day"] == 0)]
    day1 = df.index[m & (df["rel_day"] == 1)]
    tr0, va0 = train_test_split(day0, test_size=0.2, stratify=df.loc[day0, LABEL], random_state=RANDOM_STATE)
    df.loc[tr0, "split_temporal"] = "train"
    df.loc[va0, "split_temporal"] = "val"
    df.loc[day1, "split_temporal"] = "test"

    # --- random phân tầng 60/20/20
    idx = df.index[m]
    trva, te = train_test_split(idx, test_size=0.2, stratify=df.loc[idx, LABEL], random_state=RANDOM_STATE)
    tr, va = train_test_split(trva, test_size=0.25, stratify=df.loc[trva, LABEL], random_state=RANDOM_STATE)
    df.loc[tr, "split_random"] = "train"
    df.loc[va, "split_random"] = "val"
    df.loc[te, "split_random"] = "test"

    # --- 5-fold phân tầng trên train+val của split_random
    trva = np.sort(np.asarray(trva))
    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    for k, (_, fold_idx) in enumerate(skf.split(trva, df.loc[trva, LABEL])):
        df.loc[trva[fold_idx], "cv_fold"] = k
    df["cv_fold"] = df["cv_fold"].astype(np.int64)


# --------------------------------------------------------------------------------------------
# Biến đổi có học từ dữ liệu — CHỈ fit trên train/fold
# --------------------------------------------------------------------------------------------
def make_preprocessor(features: list[str] | None = None, scale_v: bool = False) -> ColumnTransformer:
    """ColumnTransformer dùng trong sklearn Pipeline.

    D-04: amount_log1p → StandardScaler (fit trên train).
    D-07: V1..V28 mặc định để nguyên (passthrough): đã là thành phần PCA, trung bình ≈ 0, độ lớn
    phương sai giảm dần theo thứ tự PCA — giữ nguyên hình học gốc. `scale_v=True` chuẩn hoá cả V*
    (phương án thay thế; Huy/Mong so sánh trên VALIDATION, không phải test).
    Cột chu kỳ sin/cos (nếu dùng) đã nằm trong [-1, 1] → passthrough.
    """
    features = list(features or FEATURES)
    scaled = ["amount_log1p"] + ([c for c in features if c in V_COLS] if scale_v else [])
    scaled = [c for c in scaled if c in features]
    passthrough = [c for c in features if c not in scaled]
    ct = ColumnTransformer(
        [("scale", StandardScaler(), scaled), ("keep", "passthrough", passthrough)],
        remainder="drop", verbose_feature_names_out=False,
    )
    ct.set_output(transform="pandas")
    return ct


# --------------------------------------------------------------------------------------------
# Tiện ích cho Huy/Mong
# --------------------------------------------------------------------------------------------
PROCESSED_DTYPES = {
    "amount_band": "string", "split_temporal": "string", "split_random": "string",
}


def load_processed(path: Path | str) -> pd.DataFrame:
    """Đọc data/processed/transactions_processed.csv và kiểm tra schema."""
    df = pd.read_csv(path, dtype=PROCESSED_DTYPES, float_precision="round_trip")
    if list(df.columns) != PROCESSED_COLS:
        raise ValueError("Schema file đã xử lý khác PROCESSED_COLS — có thể là phiên bản cũ/mới hơn.")
    return df


def get_split(df: pd.DataFrame, protocol: str = "temporal", part: str = "train",
              features: list[str] | None = None):
    """Trả (X, y, txn_id) cho một phần của giao thức chia tập. Nhãn KHÔNG có trong X.

    protocol: "temporal" | "random";  part: "train" | "val" | "test".
    """
    col = {"temporal": "split_temporal", "random": "split_random"}[protocol]
    features = list(features or FEATURES)
    assert LABEL not in features, "Nhãn không được nằm trong features"
    sub = df[df[col] == part]
    return sub[features].copy(), sub[LABEL].copy(), sub["txn_id"].copy()


def get_cv_folds(df: pd.DataFrame):
    """Sinh (train_idx, valid_idx) theo cột cv_fold (chỉ phần train+val của split_random)."""
    pool = df[df["cv_fold"] >= 0]
    for k in sorted(pool["cv_fold"].unique()):
        yield pool.index[pool["cv_fold"] != k], pool.index[pool["cv_fold"] == k]


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    raw_path = root / "data" / "raw" / "creditcard.csv"
    out_path = root / "data" / "processed" / "transactions_processed.csv"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Loading raw data from {raw_path} ...")
    raw_df = load_raw(raw_path, verify=True)
    proc_df = build_processed(raw_df)
    proc_df.to_csv(out_path, index=False, encoding="utf-8", lineterminator="\n")
    print(f"Saved {out_path} ({proc_df.shape}, sha256={file_sha256(out_path)})")

