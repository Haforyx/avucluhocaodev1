"""
Ödev 2 - Spam sınıflandırmada doğruluğu artırma yöntemleri ve ROC eğrileri
=========================================================================
Soru: "Elde ettiğimiz doğruluk oranını makine öğrenmesi algoritmalarında hangi
yöntemleri kullanarak arttırabiliriz? Sonuçlarda her bir algoritmanın ROC
eğrilerini oluşturacağız."

Yaklaşım: Her algoritma için iyileştirme yöntemleri ADIM ADIM eklenir ve her
adımın test doğruluğuna katkısı ölçülür (ablation / iyileştirme merdiveni):

  A0  Temel model         : ham metin + CountVectorizer (kelime sayımı) + varsayılan parametreler
  A1  + Ön işleme, TF-IDF  : metin temizleme, stop-word atma, alt-doğrusal TF-IDF ağırlığı
  A2  + Özellik müh.       : kelime 1-2 gram + karakter 3-5 gram + meta özellikler (uzunluk, büyük harf,
                             ünlem, URL, sayı oranı ...)
  A3  + Özellik seçimi ve  : chi-kare ile en bilgilendirici özelliklerin seçimi + 3-katlı CV ile
        hiperparametre opt.  GridSearch
  A4  + Eşik optimizasyonu : karar eşiğinin eğitim kümesindeki çapraz-doğrulama (out-of-fold) skorlarıyla
                             doğruluğu en büyükleyecek şekilde seçilmesi

Ek olarak topluluk (ensemble) yöntemleri denenir: Soft Voting, Stacking,
XGBoost ve LightGBM (gradient boosting).

Test kümesi ödev 1 ile birebir aynıdır (aynı temizleme, aynı random_state).

Kullanım:
  python avucluhocaodev2/improve_accuracy.py                 # Enron-Spam
  python avucluhocaodev2/improve_accuracy.py --dataset sms   # SMS Spam Collection
  python avucluhocaodev2/improve_accuracy.py --quick         # hızlı deneme
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy import sparse
from sklearn.base import clone
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import RandomForestClassifier, StackingClassifier, VotingClassifier
from sklearn.feature_extraction.text import CountVectorizer, TfidfVectorizer
from sklearn.feature_selection import SelectKBest, chi2
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, f1_score, roc_auc_score, roc_curve
from sklearn.model_selection import GridSearchCV, StratifiedKFold, cross_val_predict, train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import MinMaxScaler
from sklearn.svm import LinearSVC
from sklearn.tree import DecisionTreeClassifier

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent))
import spam_classification as sc  # noqa: E402  (ödev 1'in veri yükleme/temizleme kodu)

RS = sc.RANDOM_STATE
STAGES = {
    "A0": "Temel (CountVectorizer, varsayılan)",
    "A1": "+ Ön işleme & TF-IDF",
    "A2": "+ N-gram, karakter & meta özellikler",
    "A3": "+ Özellik seçimi & hiperparametre opt.",
    "A4": "+ Karar eşiği optimizasyonu",
}
CHAR_LIMIT = 3000  # karakter n-gramları için e-postanın ilk N karakteri (bellek/süre sınırı)


# --------------------------------------------------------------------------- #
# Özellik çıkarımı
# --------------------------------------------------------------------------- #
def meta_features(raw: pd.Series) -> np.ndarray:
    """Spam e-postalarda tipik olan biçimsel işaretler."""
    s = raw.fillna("").astype(str)
    n_chars = s.str.len().clip(lower=1)
    words = s.str.split().str.len().fillna(0)
    feats = pd.DataFrame({
        "log_uzunluk": np.log1p(n_chars),
        "log_kelime": np.log1p(words),
        "buyuk_harf_orani": s.str.count(r"[A-Z]") / n_chars,
        "rakam_orani": s.str.count(r"\d") / n_chars,
        "unlem": np.log1p(s.str.count("!")),
        "para_simgesi": np.log1p(s.str.count(r"[$£€]")),
        "url": np.log1p(s.str.count(r"https?://|www\.")),
        "eposta_adresi": np.log1p(s.str.count(r"\S+@\S+")),
        "html": np.log1p(s.str.count(r"<[a-zA-Z/][^>]*>")),
        "ozel_karakter_orani": s.str.count(r"[^\w\s]") / n_chars,
        "ort_kelime_uzunlugu": n_chars / words.clip(lower=1),
    })
    return feats.to_numpy(dtype=float)


class FeatureBuilder:
    """Her aşamanın özellik matrisini yalnızca EĞİTİM verisine fit ederek üretir."""

    def __init__(self, train: pd.DataFrame, test: pd.DataFrame):
        self.train, self.test = train, test

    def a0(self):
        vec = CountVectorizer()
        return vec.fit_transform(self.train["raw"]), vec.transform(self.test["raw"])

    def a1(self):
        vec = sc.make_tfidf()
        return vec.fit_transform(self.train["text"]), vec.transform(self.test["text"])

    def a2(self):
        word = TfidfVectorizer(stop_words="english", sublinear_tf=True, min_df=2, max_df=0.95,
                               ngram_range=(1, 2), max_features=200_000)
        char = TfidfVectorizer(analyzer="char_wb", ngram_range=(3, 5), sublinear_tf=True, min_df=3,
                               max_features=100_000, dtype=np.float32)
        scaler = MinMaxScaler()
        tr_chars = self.train["text"].str.slice(0, CHAR_LIMIT)
        te_chars = self.test["text"].str.slice(0, CHAR_LIMIT)
        X_tr = sparse.hstack([
            word.fit_transform(self.train["text"]),
            char.fit_transform(tr_chars),
            sparse.csr_matrix(scaler.fit_transform(meta_features(self.train["raw"]))),
        ]).tocsr()
        X_te = sparse.hstack([
            word.transform(self.test["text"]),
            char.transform(te_chars),
            # Ölçeklenmiş meta değerlerin [0,1] dışına çıkmaması (MultinomialNB negatif kabul etmez)
            sparse.csr_matrix(np.clip(scaler.transform(meta_features(self.test["raw"])), 0, 1)),
        ]).tocsr()
        return X_tr, X_te


# --------------------------------------------------------------------------- #
# Modeller
# --------------------------------------------------------------------------- #
def default_models():
    """A0-A2 aşamalarında kullanılan varsayılan parametreli modeller."""
    return {
        "Naive Bayes": MultinomialNB(),
        "Logistic Regression": LogisticRegression(max_iter=3000, random_state=RS),
        "Linear SVM": LinearSVC(random_state=RS),
        "KNN": KNeighborsClassifier(),
        "Decision Tree": DecisionTreeClassifier(random_state=RS),
        "Random Forest": RandomForestClassifier(n_jobs=-1, random_state=RS),
    }


def tuned_search_spaces(n_features: int):
    """A3: özellik seçimi (chi2) + hiperparametre ızgaraları."""
    k_all = "all"
    k_small = [k for k in (5_000, 20_000, 50_000) if k < n_features]
    return {
        "Naive Bayes": (MultinomialNB(), {
            "sel__k": [50_000, k_all] if n_features > 50_000 else [k_all],
            "clf__alpha": [0.001, 0.003, 0.01, 0.03]}),
        "Logistic Regression": (LogisticRegression(max_iter=5000, random_state=RS), {
            "sel__k": [k_all], "clf__C": [10, 30, 100, 300]}),
        "Linear SVM": (LinearSVC(random_state=RS, max_iter=5000), {
            "sel__k": [k_all], "clf__C": [0.3, 1, 3, 10]}),
        "KNN": (KNeighborsClassifier(metric="cosine", algorithm="brute", weights="distance"), {
            "sel__k": k_small + [k_all], "clf__n_neighbors": [3, 7, 15]}),
        "Decision Tree": (DecisionTreeClassifier(random_state=RS), {
            "sel__k": k_small[:2] + [k_all], "clf__criterion": ["gini", "entropy"],
            "clf__min_samples_leaf": [1, 3]}),
        "Random Forest": (RandomForestClassifier(n_estimators=400, n_jobs=-1, random_state=RS), {
            "sel__k": k_small[1:] + [k_all], "clf__max_features": ["sqrt", 0.01]}),
    }


def scores(model, X):
    if hasattr(model, "predict_proba"):
        return model.predict_proba(X)[:, 1]
    return model.decision_function(X)


def default_threshold(model):
    return 0.5 if hasattr(model, "predict_proba") else 0.0


def best_threshold(y, s):
    """Doğruluğu en büyükleyen eşik (eşitlikte varsayılana en yakın olan)."""
    order = np.argsort(s)
    s_sorted, y_sorted = s[order], np.asarray(y)[order]
    # eşik = s_sorted[i] -> skoru >= eşik olanlar spam
    n = len(y_sorted)
    pos_total = y_sorted.sum()
    neg_below = np.concatenate([[0], np.cumsum(1 - y_sorted)])[:n]
    pos_below = np.concatenate([[0], np.cumsum(y_sorted)])[:n]
    acc = (neg_below + (pos_total - pos_below)) / n
    # aynı skora sahip örnekler aynı tarafa düşmeli: yalnızca skorun değiştiği noktalar aday
    valid = np.r_[True, s_sorted[1:] != s_sorted[:-1]]
    acc = np.where(valid, acc, -1)
    best = np.flatnonzero(acc == acc.max())
    return float(s_sorted[best[len(best) // 2]]), float(acc.max())


def evaluate(name, stage, y_test, s_test, thr, fit_time, extra=None):
    pred = (s_test >= thr).astype(int)
    row = {
        "Model": name, "Aşama": stage, "Açıklama": STAGES.get(stage, stage),
        "Accuracy": accuracy_score(y_test, pred), "F1": f1_score(y_test, pred),
        "ROC-AUC": roc_auc_score(y_test, s_test), "Hata sayısı": int((pred != y_test).sum()),
        "Eşik": thr, "Süre (s)": fit_time,
    }
    if extra:
        row.update(extra)
    return row


# --------------------------------------------------------------------------- #
# Deney
# --------------------------------------------------------------------------- #
def run(df: pd.DataFrame, out: Path, title: str, cv_splits: int = 3):
    out.mkdir(parents=True, exist_ok=True)
    train, test = train_test_split(df, test_size=0.2, stratify=df["label"], random_state=RS)
    y_tr, y_te = train["label"].to_numpy(), test["label"].to_numpy()
    print(f"\n##### {title} | eğitim: {len(train)} | test: {len(test)} #####")

    fb = FeatureBuilder(train, test)
    feats = {}
    for st in ("A0", "A1", "A2"):
        t0 = time.perf_counter()
        feats[st] = getattr(fb, st.lower())()
        print(f"[{st}] özellik matrisi: {feats[st][0].shape}  ({time.perf_counter() - t0:.1f}s)")

    cv = StratifiedKFold(n_splits=cv_splits, shuffle=True, random_state=RS)
    rows, roc_scores, tuned = [], {}, {}

    def record(name, stage, model, X_tr, X_te, thr=None, extra=None):
        t0 = time.perf_counter()
        model.fit(X_tr, y_tr)
        fit_time = time.perf_counter() - t0
        s = scores(model, X_te)
        thr = default_threshold(model) if thr is None else thr
        rows.append(evaluate(name, stage, y_te, s, thr, fit_time, extra))
        roc_scores[(name, stage)] = s
        r = rows[-1]
        print(f"  {name:20s} {stage}: acc={r['Accuracy']:.4f} f1={r['F1']:.4f} "
              f"auc={r['ROC-AUC']:.5f} hata={r['Hata sayısı']:4d} ({fit_time:.1f}s)")
        return model

    # A0-A2: aynı varsayılan modeller, sadece veri temsili değişiyor
    for st in ("A0", "A1", "A2"):
        print(f"\n--- {st}: {STAGES[st]} ---")
        X_tr, X_te = feats[st]
        for name, model in default_models().items():
            record(name, st, clone(model), X_tr, X_te)

    # A3: özellik seçimi + hiperparametre optimizasyonu (A2 özellikleri üzerinde)
    print(f"\n--- A3: {STAGES['A3']} ---")
    X_tr, X_te = feats["A2"]
    for name, (clf, grid) in tuned_search_spaces(X_tr.shape[1]).items():
        pipe = Pipeline([("sel", SelectKBest(chi2)), ("clf", clf)])
        n_jobs = 1 if name == "Random Forest" else -1
        t0 = time.perf_counter()
        search = GridSearchCV(pipe, grid, scoring="accuracy", cv=cv, n_jobs=n_jobs, refit=False)
        search.fit(X_tr, y_tr)
        tune_time = time.perf_counter() - t0
        best = pipe.set_params(**search.best_params_)
        params = json.dumps(search.best_params_, default=str)
        print(f"  {name}: en iyi {params} (CV acc={search.best_score_:.4f}, {tune_time:.0f}s)")
        tuned[name] = record(name, "A3", best, X_tr, X_te,
                             extra={"Parametreler": params, "CV Accuracy": search.best_score_})

    # A4: karar eşiği optimizasyonu (eğitim kümesinde out-of-fold skorlar)
    print(f"\n--- A4: {STAGES['A4']} ---")
    for name, model in tuned.items():
        method = "predict_proba" if hasattr(model, "predict_proba") else "decision_function"
        oof = cross_val_predict(clone(model), X_tr, y_tr, cv=cv, method=method,
                                n_jobs=1 if name == "Random Forest" else -1)
        oof = oof[:, 1] if oof.ndim == 2 else oof
        thr, oof_acc = best_threshold(y_tr, oof)
        s = roc_scores[(name, "A3")]
        rows.append(evaluate(name, "A4", y_te, s, thr, 0.0, {"CV Accuracy": oof_acc}))
        roc_scores[(name, "A4")] = s
        print(f"  {name:20s} A4: eşik={thr:+.4f} (OOF acc={oof_acc:.4f}) -> "
              f"test acc={rows[-1]['Accuracy']:.4f}")

    # Topluluk (ensemble) yöntemleri
    print("\n--- Topluluk yöntemleri (A2 özellikleri + A3 ayarları) ---")
    ens_rows_start = len(rows)
    for name, model in ensemble_models(tuned).items():
        record(name, "Ensemble", model, X_tr, X_te)
    ens = pd.DataFrame(rows[ens_rows_start:])

    res = pd.DataFrame(rows)
    res.to_csv(out / "stage_results.csv", index=False, float_format="%.5f")
    ens.to_csv(out / "ensemble_results.csv", index=False, float_format="%.5f")
    save_summary(res, out, title)
    # Test skorları: grafiklerin ve istatistiksel testlerin yeniden üretilebilmesi için
    np.savez_compressed(out / "test_scores.npz", y_test=y_te,
                        **{f"{m}|{st}": v for (m, st), v in roc_scores.items()})
    significance_tests(res, roc_scores, y_te, out)
    plot_all(res, roc_scores, y_te, out, title)
    return res


def significance_tests(res, roc_scores, y, out: Path):
    """En doğru model ile (a) her algoritmanın temel hali, (b) en iyi tek model arasında McNemar testi."""
    def pred(model, stage):
        r = res[(res["Model"] == model) & (res["Aşama"] == stage)].iloc[0]
        return (roc_scores[(model, stage)] >= r["Eşik"]).astype(int)

    top = res.sort_values(["Accuracy", "ROC-AUC"], ascending=False).iloc[0]
    singles = res[res["Aşama"].isin(STAGES)].sort_values("Accuracy", ascending=False)
    pairs = [(singles.iloc[0]["Model"], singles.iloc[0]["Aşama"])]
    pairs += [(m, "A0") for m in default_models()]
    pairs += [(m, "Ensemble") for m in res.loc[res["Aşama"] == "Ensemble", "Model"]]
    pairs = [pr for pr in pairs if pr != (top["Model"], top["Aşama"])]
    p_top = pred(top["Model"], top["Aşama"])
    rows = []
    for m, st in pairs:
        b, c, p = sc.mcnemar(y, p_top, pred(m, st))
        rows.append({"Karşılaştırma": f"{top['Model']} [{top['Aşama']}] vs {m} [{st}]",
                     "Yalnız ilki doğru": b, "Yalnız ikincisi doğru": c, "p-değeri": p,
                     "Anlamlı (p<0.05)": p < 0.05})
    mc = pd.DataFrame(rows)
    mc.to_csv(out / "mcnemar.csv", index=False, float_format="%.3g")
    print("\nMcNemar testi:\n" + mc.to_string(index=False))


def ensemble_models(tuned):
    svm_cal = CalibratedClassifierCV(clone(tuned["Linear SVM"]), cv=3)
    members = [("nb", clone(tuned["Naive Bayes"])), ("lr", clone(tuned["Logistic Regression"])),
               ("svm", svm_cal), ("rf", clone(tuned["Random Forest"]))]
    models = {
        "Soft Voting (NB+LR+SVM+RF)": VotingClassifier(members, voting="soft", n_jobs=1),
        "Stacking (meta: LR)": StackingClassifier(
            members[:3], final_estimator=LogisticRegression(max_iter=2000), cv=3, n_jobs=1),
    }
    # Gradient boosting kütüphaneleri opsiyonel
    try:
        from xgboost import XGBClassifier
        models["XGBoost"] = Pipeline([
            ("sel", SelectKBest(chi2, k=20_000)),
            ("clf", XGBClassifier(n_estimators=600, learning_rate=0.1, max_depth=6, subsample=0.8,
                                  colsample_bytree=0.5, tree_method="hist", n_jobs=-1,
                                  random_state=RS, eval_metric="logloss")),
        ])
    except ImportError:
        print("  xgboost kurulu değil, atlandı")
    try:
        from lightgbm import LGBMClassifier
        models["LightGBM"] = Pipeline([
            ("sel", SelectKBest(chi2, k=20_000)),
            ("clf", LGBMClassifier(n_estimators=600, learning_rate=0.05, num_leaves=63,
                                   colsample_bytree=0.5, subsample=0.8, subsample_freq=1,
                                   random_state=RS, n_jobs=-1, verbose=-1)),
        ])
    except ImportError:
        print("  lightgbm kurulu değil, atlandı")
    return models


def save_summary(res: pd.DataFrame, out: Path, title: str):
    base = res[res["Aşama"].isin(STAGES)]
    pivot = base.pivot(index="Model", columns="Aşama", values="Accuracy")[list(STAGES)]
    err = base.pivot(index="Model", columns="Aşama", values="Hata sayısı")[list(STAGES)]
    pivot["Kazanç (A4-A0)"] = pivot["A4"] - pivot["A0"]
    pivot["Hata azalması %"] = 100 * (err["A0"] - err["A4"]) / err["A0"].clip(lower=1)
    pivot = pivot.sort_values("A4", ascending=False)
    pivot.to_csv(out / "accuracy_by_stage.csv", float_format="%.4f")

    best = res.sort_values(["Accuracy", "ROC-AUC"], ascending=False).iloc[0]
    text = (f"{title}\n{'=' * 100}\nTest doğruluğu (aşama bazında):\n"
            f"{pivot.to_string(float_format=lambda v: f'{v:.4f}')}\n\n"
            f"Topluluk yöntemleri:\n"
            f"{res[res['Aşama'] == 'Ensemble'][['Model', 'Accuracy', 'F1', 'ROC-AUC', 'Hata sayısı']].to_string(index=False, float_format=lambda v: f'{v:.4f}')}\n\n"
            f">>> EN YÜKSEK DOĞRULUK: {best['Model']} [{best['Aşama']}] "
            f"Accuracy={best['Accuracy']:.4f}, F1={best['F1']:.4f}, ROC-AUC={best['ROC-AUC']:.5f}\n")
    (out / "summary.txt").write_text(text, encoding="utf-8")
    print("\n" + text)


# --------------------------------------------------------------------------- #
# Grafikler
# --------------------------------------------------------------------------- #
STAGE_COLORS = dict(zip(STAGES, ["#9e9e9e", "#4c78a8", "#f58518", "#54a24b", "#e45756"]))


def slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def plot_roc_for_model(ax_full, ax_zoom, name, roc_scores, y, res):
    """Bir algoritmanın her aşamadaki ROC eğrisi (tam + log ölçekli yakın görünüm)."""
    for st in ("A0", "A1", "A2", "A3"):
        if (name, st) not in roc_scores:
            continue
        fpr, tpr, _ = roc_curve(y, roc_scores[(name, st)])
        auc = roc_auc_score(y, roc_scores[(name, st)])
        lbl = f"{st} {STAGES[st]} (AUC={auc:.4f})"
        for ax in (ax_full, ax_zoom):
            ax.plot(fpr, tpr, color=STAGE_COLORS[st], lw=1.8, label=lbl)
    # A4: seçilen eşiğin ROC üzerindeki çalışma noktası (A3 eğrisi üzerinde)
    for st, marker in (("A3", "o"), ("A4", "*")):
        r = res[(res["Model"] == name) & (res["Aşama"] == st)]
        if len(r) and (name, st) in roc_scores:
            pred = roc_scores[(name, st)] >= r["Eşik"].iloc[0]
            fpr_pt = pred[y == 0].mean()
            tpr_pt = pred[y == 1].mean()
            for ax in (ax_full, ax_zoom):
                ax.scatter(max(fpr_pt, 1e-4), tpr_pt, marker=marker, s=120 if marker == "*" else 50,
                           color=STAGE_COLORS[st], edgecolor="black", zorder=5,
                           label=f"{st} çalışma noktası (acc={r['Accuracy'].iloc[0]:.4f})"
                           if ax is ax_full else None)
    ax_full.plot([0, 1], [0, 1], "k--", lw=0.8)
    ax_full.set(xlabel="Yanlış pozitif oranı (FPR)", ylabel="Doğru pozitif oranı (TPR)",
                title=f"{name}: ROC eğrisi")
    ax_full.legend(fontsize=7, loc="lower right")
    ax_zoom.set_xscale("log")
    ax_zoom.set_xlim(1e-4, 1)
    ax_zoom.set_ylim(0.8, 1.0)
    ax_zoom.set(xlabel="FPR (log ölçek)", ylabel="TPR", title=f"{name}: yakın görünüm")


def plot_all(res, roc_scores, y, out: Path, title: str):
    sns.set_theme(style="whitegrid")
    roc_dir = out / "roc"
    roc_dir.mkdir(exist_ok=True)
    algos = list(default_models())

    # 1) Her algoritma için ayrı ROC figürü
    for name in algos:
        fig, (a, b) = plt.subplots(1, 2, figsize=(13, 5.5))
        plot_roc_for_model(a, b, name, roc_scores, y, res)
        fig.suptitle(f"{title} - {name}")
        fig.tight_layout()
        fig.savefig(roc_dir / f"roc_{slug(name)}.png", dpi=140)
        plt.close(fig)

    # 2) Tüm algoritmaların ROC eğrileri tek sayfada (aşama bazında)
    fig, axes = plt.subplots(2, 3, figsize=(17, 10.5))
    for ax, name in zip(axes.flat, algos):
        for st in ("A0", "A1", "A2", "A3"):
            fpr, tpr, _ = roc_curve(y, roc_scores[(name, st)])
            ax.plot(fpr, tpr, color=STAGE_COLORS[st], lw=1.6,
                    label=f"{st} (AUC={roc_auc_score(y, roc_scores[(name, st)]):.4f})")
        ax.set_xscale("log")
        ax.set_xlim(1e-4, 1)
        ax.set_ylim(0.5, 1.0)
        ax.set_title(name)
        ax.set_xlabel("FPR (log)")
        ax.set_ylabel("TPR")
        ax.legend(fontsize=8, loc="lower right")
    fig.suptitle(f"{title}: algoritma başına ROC eğrileri (A0 temel → A3 optimize)", fontsize=14)
    fig.tight_layout()
    fig.savefig(out / "roc_all_algorithms.png", dpi=140)
    plt.close(fig)

    # 3) En iyi sürümlerin (A3 + ensemble) ROC karşılaştırması
    fig, (a, b) = plt.subplots(1, 2, figsize=(14, 6))
    final = [(n, "A3") for n in algos] + [(n, "Ensemble") for n in res.loc[res["Aşama"] == "Ensemble", "Model"]]
    pal = sns.color_palette("tab10", len(final))
    for (name, st), c in zip(final, pal):
        s = roc_scores[(name, st)]
        fpr, tpr, _ = roc_curve(y, s)
        ls = "--" if st == "Ensemble" else "-"
        for ax in (a, b):
            ax.plot(fpr, tpr, color=c, ls=ls, lw=1.6, label=f"{name} (AUC={roc_auc_score(y, s):.4f})")
    a.plot([0, 1], [0, 1], "k--", lw=0.8)
    a.set(xlabel="FPR", ylabel="TPR", title="Optimize modeller + topluluklar")
    a.legend(fontsize=8, loc="lower right")
    b.set_xscale("log")
    b.set_xlim(1e-4, 1)
    b.set_ylim(0.9, 1.0)
    b.set(xlabel="FPR (log)", ylabel="TPR", title="Yakın görünüm")
    fig.suptitle(f"{title}: final ROC karşılaştırması")
    fig.tight_layout()
    fig.savefig(out / "roc_final_comparison.png", dpi=140)
    plt.close(fig)

    plot_summary(res, out, title)


def plot_summary(res: pd.DataFrame, out: Path, title: str):
    """Yalnızca stage_results.csv ile çizilebilen özet grafikler."""
    from matplotlib.colors import LogNorm

    sns.set_theme(style="whitegrid")
    algos = list(default_models())
    base = res[res["Aşama"].isin(STAGES)]
    ens = res[res["Aşama"] == "Ensemble"].sort_values("Accuracy", ascending=False)

    # 4) Doğruluk merdiveni: hata oranı (%) log ölçekte -> küçük farklar da görünür
    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(15, 6.5), gridspec_kw={"width_ratios": [3, 1.3]})
    pal = dict(zip(algos, sns.color_palette("tab10", len(algos))))
    for name in algos:
        d = base[base["Model"] == name].set_index("Aşama").loc[list(STAGES)]
        err_rate = 100 * (1 - d["Accuracy"])
        ax.plot(range(len(STAGES)), err_rate, marker="o", lw=2.2, color=pal[name], label=name)
    best_ens = ens.iloc[0]
    ax.axhline(100 * (1 - best_ens["Accuracy"]), ls="--", lw=1.2, color="black",
               label=f"{best_ens['Model']} (en iyi topluluk)")
    ax.set_yscale("log")
    ax.set_xticks(range(len(STAGES)), [f"{k}\n{v.replace('& ', '&\n')}" for k, v in STAGES.items()], fontsize=8)
    ax.set_ylabel("Test hata oranı % (log ölçek, aşağısı daha iyi)")
    ax.set_title("Algoritma başına iyileştirme adımları")
    ax.legend(loc="upper right", fontsize=8, ncol=2)
    ax.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:g}"))

    # sağ panel: her algoritmanın en iyi hali + topluluklar
    best = base.sort_values("Accuracy", ascending=False).drop_duplicates("Model")
    final = pd.concat([best.assign(Tür="Tek model"), ens.assign(Tür="Topluluk")])
    final = final.sort_values("Accuracy")
    colors = ["#e45756" if t == "Topluluk" else "#4c78a8" for t in final["Tür"]]
    ax2.barh([f"{m} [{a}]" if a != "Ensemble" else m for m, a in zip(final["Model"], final["Aşama"])],
             100 * final["Accuracy"], color=colors)
    for i, v in enumerate(100 * final["Accuracy"]):
        ax2.text(v, i, f" %{v:.2f}", va="center", fontsize=8)
    ax2.set_xlim(max(90, 100 * final["Accuracy"].min() - 1), 100.4)
    ax2.set_xlabel("Test doğruluğu %")
    ax2.set_title("En iyi sürümler (kırmızı = topluluk)")
    ax2.tick_params(axis="y", labelsize=8)
    fig.suptitle(f"{title}: her iyileştirme yönteminin doğruluğa etkisi", fontsize=13)
    fig.tight_layout()
    fig.savefig(out / "accuracy_ladder.png", dpi=150)
    plt.close(fig)

    # 5) Hata sayısı ısı haritası (log renk ölçeği)
    err = base.pivot(index="Model", columns="Aşama", values="Hata sayısı")[list(STAGES)].loc[algos]
    fig, ax = plt.subplots(figsize=(9, 4.5))
    sns.heatmap(err, annot=True, fmt="d", cmap="Reds", norm=LogNorm(vmin=max(1, err.values.min()),
                vmax=err.values.max()), ax=ax, cbar_kws={"label": "Hatalı tahmin (log)"})
    ax.set_title(f"{title}: test kümesindeki hatalı tahmin sayısı")
    ax.set_xticklabels([f"{k}" for k in STAGES])
    fig.tight_layout()
    fig.savefig(out / "errors_heatmap.png", dpi=150)
    plt.close(fig)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--dataset", choices=["enron", "sms"], default="enron")
    p.add_argument("--quick", action="store_true", help="3000 örneklik alt küme")
    p.add_argument("--replot", action="store_true",
                   help="deneyi çalıştırmadan stage_results.csv'den özet grafikleri yeniden çiz")
    args = p.parse_args()

    if args.replot:
        out = ROOT / "results" if args.dataset == "enron" else ROOT / "results" / "sms"
        title = "Enron-Spam" if args.dataset == "enron" else "SMS Spam"
        res = pd.read_csv(out / "stage_results.csv")
        npz = out / "test_scores.npz"
        if npz.exists():  # skorlar kayıtlıysa ROC grafikleri ve testler de yeniden üretilir
            data = np.load(npz)
            y = data["y_test"]
            roc_scores = {tuple(k.split("|")): data[k] for k in data.files if k != "y_test"}
            significance_tests(res, roc_scores, y, out)
            plot_all(res, roc_scores, y, out, title)
        else:
            plot_summary(res, out, title)
        return

    if args.dataset == "enron":
        df, title, out = sc.load_enron(), "Enron-Spam", ROOT / "results"
    else:
        df, title, out = sc.load_sms(), "SMS Spam", ROOT / "results" / "sms"
    if args.quick:
        df = df.sample(min(3000, len(df)), random_state=RS)
        out = out / "quick"
    run(df, out, title)


if __name__ == "__main__":
    main()
