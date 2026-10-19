"""
Spam / Normal (Ham) E-posta Sınıflandırma
=========================================
Ana veri seti   : Enron-Spam (Metsis vd., 2006) - 33.716 gerçek e-posta
                  https://github.com/MWiechmann/enron_spam_data
İkincil veri    : SMS Spam Collection (Almeida vd., 2011) - 5.572 SMS
                  (genelleme kontrolü için)

Adımlar:
  1. Veri yükleme ve temizleme (boş/tekrarlı kayıtların atılması)
  2. Stratified %80 eğitim / %20 test ayrımı
  3. TF-IDF ile metinlerin sayısallaştırılması
  4. 6 algoritmanın eğitim kümesinde 5-katlı çapraz doğrulamalı GridSearch
     ile hiperparametre ayarı
  5. Ayrılmış test kümesinde değerlendirme (Accuracy, Precision, Recall,
     F1, ROC-AUC, karmaşıklık matrisi, eğitim/tahmin süresi)
  6. En iyi algoritmanın belirlenmesi (test F1) + McNemar anlamlılık testi

Kullanım:
  python spam_classification.py            # tam deney (Enron + SMS)
  python spam_classification.py --quick    # hızlı deneme (veri alt kümesi)
"""
import argparse
import json
import re
import time
from pathlib import Path

import joblib
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from scipy.stats import binomtest
from sklearn.ensemble import RandomForestClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    ConfusionMatrixDisplay,
    RocCurveDisplay,
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.svm import LinearSVC
from sklearn.tree import DecisionTreeClassifier

RANDOM_STATE = 42
ROOT = Path(__file__).resolve().parent
ENRON_PATH = ROOT / "data" / "enron_spam_data.zip"
SMS_PATH = ROOT / "data" / "sms.tsv"
OUT = ROOT / "results"
LABELS = ["ham", "spam"]


# --------------------------------------------------------------------------- #
# 1. Veri yükleme ve ön işleme
# --------------------------------------------------------------------------- #
def clean_text(text: str) -> str:
    """Küçük harfe çevirir, URL/e-posta/sayıları özel kelimeye indirger,
    harf dışı karakterleri siler."""
    text = str(text).lower()
    text = re.sub(r"https?://\S+|www\.\S+", " urltoken ", text)
    text = re.sub(r"\S+@\S+", " emailtoken ", text)
    text = re.sub(r"\d+", " numtoken ", text)
    text = re.sub(r"[^a-z\s]", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def prepare(df: pd.DataFrame, name: str, verbose: bool = True) -> pd.DataFrame:
    """`raw` ve `label` kolonlu tabloyu temizler, boş ve tekrarlı metinleri atar."""
    df = df.copy()
    df["text"] = df["raw"].map(clean_text)
    n_raw = len(df)
    df = df[df["text"].str.len() > 0]
    n_nonempty = len(df)
    # Aynı metnin hem eğitimde hem testte bulunması (veri sızıntısı) engellenir
    df = df.drop_duplicates(subset="text")
    if verbose:
        counts = df["label"].value_counts()
        print(f"[{name}] ham kayıt: {n_raw} | boş atılan: {n_raw - n_nonempty} | "
              f"tekrarlı atılan: {n_nonempty - len(df)} | kalan: {len(df)} "
              f"(ham={counts.get(0, 0)}, spam={counts.get(1, 0)})")
    return df[["raw", "text", "label"]].reset_index(drop=True)


def load_enron(path: Path = ENRON_PATH, verbose: bool = True) -> pd.DataFrame:
    df = pd.read_csv(path)
    raw = df["Subject"].fillna("") + " " + df["Message"].fillna("")
    out = pd.DataFrame({"raw": raw, "label": (df["Spam/Ham"] == "spam").astype(int)})
    return prepare(out, "Enron-Spam", verbose)


def load_sms(path: Path = SMS_PATH, verbose: bool = True) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", header=None, names=["label", "raw"], quoting=3)
    df["label"] = (df["label"] == "spam").astype(int)
    return prepare(df, "SMS Spam", verbose)


# --------------------------------------------------------------------------- #
# 2. Modeller ve hiperparametre ızgaraları
# --------------------------------------------------------------------------- #
def make_tfidf() -> TfidfVectorizer:
    return TfidfVectorizer(stop_words="english", sublinear_tf=True, min_df=2, max_df=0.95)


def get_models():
    """Model adı -> (sınıflandırıcı, GridSearch parametre ızgarası)."""
    return {
        "Naive Bayes": (
            MultinomialNB(),
            {"tfidf__ngram_range": [(1, 1), (1, 2)], "clf__alpha": [0.01, 0.1, 1.0]},
        ),
        "Logistic Regression": (
            LogisticRegression(max_iter=3000, random_state=RANDOM_STATE),
            {"tfidf__ngram_range": [(1, 1), (1, 2)], "clf__C": [1, 10, 100]},
        ),
        "Linear SVM": (
            LinearSVC(random_state=RANDOM_STATE),
            {"tfidf__ngram_range": [(1, 1), (1, 2)], "clf__C": [0.1, 1, 10]},
        ),
        "KNN": (
            KNeighborsClassifier(metric="cosine", algorithm="brute"),
            {"tfidf__max_features": [20000], "clf__n_neighbors": [3, 7, 15], "clf__weights": ["distance"]},
        ),
        "Decision Tree": (
            DecisionTreeClassifier(random_state=RANDOM_STATE),
            {"tfidf__max_features": [20000], "clf__max_depth": [None, 60], "clf__min_samples_leaf": [1, 3]},
        ),
        "Random Forest": (
            RandomForestClassifier(n_estimators=300, n_jobs=-1, random_state=RANDOM_STATE),
            {"tfidf__max_features": [20000], "clf__min_samples_leaf": [1, 2]},
        ),
    }


def score_for_auc(model, X):
    if hasattr(model, "predict_proba"):
        return model.predict_proba(X)[:, 1]
    return model.decision_function(X)


def mcnemar(y_true, pred_a, pred_b):
    """Kesin (binom) McNemar testi. Döner: (b, c, p_değeri)
    b: A doğru / B yanlış, c: A yanlış / B doğru."""
    a_ok = pred_a == y_true
    b_ok = pred_b == y_true
    b = int(np.sum(a_ok & ~b_ok))
    c = int(np.sum(~a_ok & b_ok))
    p = 1.0 if b + c == 0 else binomtest(b, b + c, 0.5).pvalue
    return b, c, p


# --------------------------------------------------------------------------- #
# 3. Eğitim + test
# --------------------------------------------------------------------------- #
def run_experiment(df: pd.DataFrame, out_dir: Path, title: str, cv_splits: int = 5) -> pd.DataFrame:
    out_dir.mkdir(parents=True, exist_ok=True)
    X_train, X_test, y_train, y_test, raw_train, raw_test = train_test_split(
        df["text"], df["label"], df["raw"],
        test_size=0.2, stratify=df["label"], random_state=RANDOM_STATE,
    )
    print(f"\n##### {title} | eğitim: {len(X_train)} | test: {len(X_test)} #####\n")

    cv = StratifiedKFold(n_splits=cv_splits, shuffle=True, random_state=RANDOM_STATE)
    rows, fitted, preds, reports = [], {}, {}, {}

    for name, (clf, grid) in get_models().items():
        print(f"=== {name} ===")
        pipe = Pipeline([("tfidf", make_tfidf()), ("clf", clf)])
        # Random Forest kendi içinde paralel çalıştığı için dış döngü seri tutulur
        n_jobs = 1 if name == "Random Forest" else -1
        search = GridSearchCV(pipe, grid, scoring="f1", cv=cv, n_jobs=n_jobs, refit=False)

        t0 = time.perf_counter()
        search.fit(X_train, y_train)
        tune_time = time.perf_counter() - t0

        best = pipe.set_params(**search.best_params_)
        t0 = time.perf_counter()
        best.fit(X_train, y_train)
        train_time = time.perf_counter() - t0

        t0 = time.perf_counter()
        y_pred = best.predict(X_test)
        pred_time = time.perf_counter() - t0
        y_score = score_for_auc(best, X_test)

        i = search.best_index_
        rows.append({
            "Model": name,
            "CV F1 (ort.)": search.cv_results_["mean_test_score"][i],
            "CV F1 (std)": search.cv_results_["std_test_score"][i],
            "Accuracy": accuracy_score(y_test, y_pred),
            "Precision": precision_score(y_test, y_pred),
            "Recall": recall_score(y_test, y_pred),
            "F1": f1_score(y_test, y_pred),
            "ROC-AUC": roc_auc_score(y_test, y_score),
            "Eğitim süresi (s)": train_time,
            "Tahmin süresi (s)": pred_time,
            "GridSearch süresi (s)": tune_time,
            "En iyi parametreler": json.dumps(search.best_params_, default=str),
        })
        fitted[name], preds[name] = best, y_pred
        reports[name] = classification_report(y_test, y_pred, target_names=LABELS, digits=4)
        print(f"En iyi parametreler: {search.best_params_}  (CV F1={rows[-1]['CV F1 (ort.)']:.4f})")
        print(reports[name])

    results = pd.DataFrame(rows).sort_values(["F1", "Accuracy"], ascending=False).reset_index(drop=True)
    results.to_csv(out_dir / "results.csv", index=False, float_format="%.4f")
    with open(out_dir / "classification_reports.txt", "w", encoding="utf-8") as f:
        for name, rep in reports.items():
            f.write(f"=== {name} ===\n{rep}\n")

    # İstatistiksel karşılaştırma: en iyi model vs diğerleri (McNemar)
    best_name = results.loc[0, "Model"]
    y_true = y_test.to_numpy()
    mc_rows = []
    for other in results["Model"][1:]:
        b, c, p = mcnemar(y_true, preds[best_name], preds[other])
        mc_rows.append({"Karşılaştırma": f"{best_name} vs {other}",
                        f"Yalnız {best_name} doğru": b, "Yalnız diğeri doğru": c,
                        "p-değeri": p, "Anlamlı (p<0.05)": p < 0.05})
    mc = pd.DataFrame(mc_rows)
    mc.to_csv(out_dir / "mcnemar.csv", index=False, float_format="%.3g")

    # Hata analizi: en iyi modelin yanlış sınıfladığı örnekler
    wrong = preds[best_name] != y_true
    mis = pd.DataFrame({
        "gercek": np.array(LABELS)[y_true[wrong]],
        "tahmin": np.array(LABELS)[preds[best_name][wrong]],
        "skor": score_for_auc(fitted[best_name], X_test[wrong]),
        "metin": raw_test[wrong].str.slice(0, 300).str.replace(r"\s+", " ", regex=True),
    })
    mis.to_csv(out_dir / "misclassified_samples.csv", index=False)

    joblib.dump(fitted[best_name], out_dir / "best_model.joblib", compress=3)
    make_plots(results, fitted, X_test, y_test, out_dir, title)
    if "Logistic Regression" in fitted:
        plot_top_words(fitted["Logistic Regression"], out_dir / "top_spam_words.png", title)

    summary = results.drop(columns=["En iyi parametreler"]).to_string(index=False, float_format="%.4f")
    text = (f"{title}\n{'=' * 110}\n{summary}\n\n"
            f"McNemar testi (en iyi model vs diğerleri):\n{mc.to_string(index=False)}\n\n"
            f">>> EN İYİ ALGORİTMA: {best_name}  "
            f"(F1={results.loc[0, 'F1']:.4f}, Accuracy={results.loc[0, 'Accuracy']:.4f}, "
            f"ROC-AUC={results.loc[0, 'ROC-AUC']:.4f})\n")
    (out_dir / "best_model.txt").write_text(text, encoding="utf-8")
    print("\n" + text)
    return results


# --------------------------------------------------------------------------- #
# 4. Görselleştirme
# --------------------------------------------------------------------------- #
def make_plots(results, fitted, X_test, y_test, out_dir: Path, title: str):
    sns.set_theme(style="whitegrid")
    order = list(results["Model"])
    palette = dict(zip(order, sns.color_palette("tab10", len(order))))

    # Metrik karşılaştırma
    metrics = ["Accuracy", "Precision", "Recall", "F1", "ROC-AUC"]
    long = results.melt(id_vars="Model", value_vars=metrics, var_name="Metrik", value_name="Skor")
    fig, ax = plt.subplots(figsize=(13, 6))
    sns.barplot(data=long, x="Metrik", y="Skor", hue="Model", hue_order=order, palette=palette, ax=ax)
    ax.set_ylim(max(0.0, long["Skor"].min() - 0.03), 1.0)
    ax.set_title(f"{title}: algoritmaların test kümesi performansı")
    ax.legend(loc="lower right", ncol=2)
    fig.tight_layout()
    fig.savefig(out_dir / "metric_comparison.png", dpi=150)
    plt.close(fig)

    # Karmaşıklık matrisleri
    n = len(order)
    cols = 3
    rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(4.5 * cols, 4.2 * rows))
    for ax, name in zip(axes.flat, order):
        cm = confusion_matrix(y_test, fitted[name].predict(X_test))
        ConfusionMatrixDisplay(cm, display_labels=LABELS).plot(
            ax=ax, colorbar=False, cmap="Blues", values_format="d")
        ax.set_title(name)
        ax.grid(False)
    for ax in list(axes.flat)[n:]:
        ax.axis("off")
    fig.suptitle(f"{title}: karmaşıklık matrisleri (test)")
    fig.tight_layout()
    fig.savefig(out_dir / "confusion_matrices.png", dpi=150)
    plt.close(fig)

    # ROC eğrileri
    fig, ax = plt.subplots(figsize=(7, 6))
    for name in order:
        RocCurveDisplay.from_predictions(y_test, score_for_auc(fitted[name], X_test),
                                         name=name, ax=ax, curve_kwargs={"color": palette[name]})
    ax.plot([0, 1], [0, 1], "k--", lw=1)
    ax.set_title(f"{title}: ROC eğrileri (test)")
    fig.tight_layout()
    fig.savefig(out_dir / "roc_curves.png", dpi=150)
    plt.close(fig)

    # Eğitim süreleri
    fig, ax = plt.subplots(figsize=(8, 4))
    sns.barplot(data=results, y="Model", x="Eğitim süresi (s)", hue="Model",
                palette=palette, legend=False, ax=ax)
    ax.set_xscale("log")
    ax.set_title(f"{title}: eğitim süresi (saniye, log ölçek)")
    fig.tight_layout()
    fig.savefig(out_dir / "training_time.png", dpi=150)
    plt.close(fig)


def plot_top_words(lr_pipe: Pipeline, path: Path, title: str, k: int = 20):
    """Logistic Regression katsayılarına göre spam/ham'ı en çok belirleyen terimler."""
    vocab = np.array(lr_pipe.named_steps["tfidf"].get_feature_names_out())
    coef = lr_pipe.named_steps["clf"].coef_[0]
    idx = np.r_[np.argsort(coef)[:k], np.argsort(coef)[-k:]]
    fig, ax = plt.subplots(figsize=(8, 10))
    colors = ["#2a9d8f" if c < 0 else "#e76f51" for c in coef[idx]]
    ax.barh(vocab[idx], coef[idx], color=colors)
    ax.set_title(f"{title}: en ayırt edici terimler\n(LR katsayısı; kırmızı=spam, yeşil=ham)")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--quick", action="store_true", help="3000 örneklik alt küme, 3-katlı CV")
    parser.add_argument("--skip-sms", action="store_true", help="SMS genelleme deneyini atla")
    args = parser.parse_args()

    np.random.seed(RANDOM_STATE)
    enron = load_enron()
    sms = None if args.skip_sms else load_sms()
    cv_splits = 5
    if args.quick:
        enron = enron.sample(3000, random_state=RANDOM_STATE)
        cv_splits = 3

    enron_res = run_experiment(enron, OUT, "Enron-Spam (e-posta)", cv_splits)
    if sms is not None:
        sms_res = run_experiment(sms, OUT / "sms", "SMS Spam Collection", cv_splits)
        comp = pd.DataFrame({
            "Model": enron_res["Model"],
            "Enron F1": enron_res["F1"],
        }).merge(sms_res[["Model", "F1"]].rename(columns={"F1": "SMS F1"}), on="Model")
        comp.to_csv(OUT / "dataset_comparison.csv", index=False, float_format="%.4f")
        print("\nVeri setleri arası F1 karşılaştırması:\n" + comp.to_string(index=False, float_format="%.4f"))


if __name__ == "__main__":
    main()
