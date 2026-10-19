import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import improve_accuracy as ia  # noqa: E402


def test_best_threshold_finds_perfect_split():
    y = np.array([0, 0, 0, 1, 1, 1])
    s = np.array([0.1, 0.2, 0.6, 0.7, 0.8, 0.9])
    thr, acc = ia.best_threshold(y, s)
    assert acc == 1.0
    assert 0.6 < thr <= 0.7
    assert ((s >= thr).astype(int) == y).all()


def test_best_threshold_respects_ties():
    # Aynı skora sahip örnekler eşik ile ayrılamaz
    y = np.array([0, 1, 1, 0])
    s = np.array([0.5, 0.5, 0.9, 0.1])
    thr, acc = ia.best_threshold(y, s)
    assert np.isclose(acc, ((s >= thr).astype(int) == y).mean())


def test_meta_features_shape_and_range():
    raw = pd.Series(["FREE MONEY!!! http://x.com $$$", "hello team, see you at 3pm", None])
    m = ia.meta_features(raw)
    assert m.shape == (3, 11)
    assert np.isfinite(m).all()
    assert m[0, 2] > m[1, 2]  # büyük harf oranı spam'de daha yüksek
    assert m[0, 4] > 0 and m[1, 4] == 0  # ünlem


def test_feature_builder_fits_only_on_train():
    train = pd.DataFrame({"raw": ["Buy cheap pills now", "Team meeting at noon", "Win free cash now",
                                  "Project report attached"] * 3,
                          "label": [1, 0, 1, 0] * 3})
    train["text"] = train["raw"].map(ia.sc.clean_text)
    test = pd.DataFrame({"raw": ["unseenword cheap pills"], "label": [1]})
    test["text"] = test["raw"].map(ia.sc.clean_text)
    fb = ia.FeatureBuilder(train, test)
    for stage in ("a0", "a1", "a2"):
        X_tr, X_te = getattr(fb, stage)()
        assert X_tr.shape[1] == X_te.shape[1]
        assert X_te.min() >= 0  # MultinomialNB negatif değer kabul etmez


def test_search_spaces_cover_all_algorithms():
    spaces = ia.tuned_search_spaces(300_000)
    assert set(spaces) == set(ia.default_models())
    for clf, grid in spaces.values():
        assert "sel__k" in grid and len(grid["sel__k"]) >= 1


def test_slug():
    assert ia.slug("Soft Voting (NB+LR+SVM+RF)") == "soft_voting_nb_lr_svm_rf"
