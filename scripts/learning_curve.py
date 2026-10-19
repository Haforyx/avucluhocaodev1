"""En iyi 3 model için öğrenme eğrisi (eğitim boyutu -> F1) çizer.

  python scripts/learning_curve.py
Önce `python spam_classification.py` çalıştırılmış olmalıdır (results/results.csv).
"""
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.model_selection import StratifiedKFold, learning_curve, train_test_split
from sklearn.pipeline import Pipeline

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import spam_classification as sc  # noqa: E402


def main(top_k: int = 3):
    df = sc.load_enron()
    # Test kümesine dokunmamak için yalnızca eğitim kısmı kullanılır (ana deneyle aynı ayrım)
    X, _, y, _ = train_test_split(df["text"], df["label"], test_size=0.2,
                                  stratify=df["label"], random_state=sc.RANDOM_STATE)
    results = pd.read_csv(sc.OUT / "results.csv")
    models = sc.get_models()
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=sc.RANDOM_STATE)
    sizes = np.array([0.02, 0.05, 0.1, 0.2, 0.4, 0.7, 1.0])

    fig, ax = plt.subplots(figsize=(8, 5))
    rows = []
    for _, r in results.head(top_k).iterrows():
        name = r["Model"]
        params = {k: tuple(v) if isinstance(v, list) else v
                  for k, v in json.loads(r["En iyi parametreler"]).items()}
        pipe = Pipeline([("tfidf", sc.make_tfidf()), ("clf", models[name][0])]).set_params(**params)
        n, _, test = learning_curve(pipe, X, y, train_sizes=sizes, cv=cv,
                                    scoring="f1", n_jobs=-1, shuffle=True, random_state=sc.RANDOM_STATE)
        mean, std = test.mean(axis=1), test.std(axis=1)
        ax.plot(n, mean, marker="o", label=name)
        ax.fill_between(n, mean - std, mean + std, alpha=0.15)
        rows += [{"Model": name, "Eğitim örneği": int(a), "CV F1 (ort.)": m, "CV F1 (std)": s}
                 for a, m, s in zip(n, mean, std)]
        print(f"{name}: " + ", ".join(f"{a}->{m:.4f}" for a, m in zip(n, mean)))

    ax.set_xscale("log")
    ax.set_xlabel("Eğitim örneği sayısı (log)")
    ax.set_ylabel("Doğrulama F1")
    ax.set_title("Enron-Spam: öğrenme eğrileri (eğitim kümesinde 5-katlı CV)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(sc.OUT / "learning_curve.png", dpi=150)
    pd.DataFrame(rows).to_csv(sc.OUT / "learning_curve.csv", index=False, float_format="%.4f")


if __name__ == "__main__":
    main()
