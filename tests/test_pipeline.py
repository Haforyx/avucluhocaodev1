import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from sklearn.pipeline import Pipeline

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import spam_classification as sc  # noqa: E402


def test_clean_text_normalizes_tokens():
    out = sc.clean_text("WIN $1000 now!! Visit http://x.com or mail me@a.com")
    assert out == "win numtoken now visit urltoken or mail emailtoken"


def test_clean_text_handles_non_string():
    assert sc.clean_text(None) == "none"
    assert sc.clean_text("   ") == ""


def test_prepare_drops_empty_and_duplicates():
    df = pd.DataFrame({"raw": ["Hello there", "hello THERE!", "!!!", "Buy now"], "label": [0, 0, 1, 1]})
    out = sc.prepare(df, "t", verbose=False)
    assert list(out["text"]) == ["hello there", "buy now"]
    assert list(out["label"]) == [0, 1]


@pytest.mark.skipif(not sc.ENRON_PATH.exists(), reason="Enron veri seti yok")
def test_load_enron_shape_and_labels():
    df = sc.load_enron(verbose=False)
    assert len(df) > 25000
    assert set(df["label"].unique()) == {0, 1}
    assert not df["text"].duplicated().any()


@pytest.mark.skipif(not sc.SMS_PATH.exists(), reason="SMS veri seti yok")
def test_load_sms():
    df = sc.load_sms(verbose=False)
    assert len(df) > 5000
    assert 0.1 < df["label"].mean() < 0.2


def test_all_models_fit_on_toy_data():
    spam = ["win free money now", "free prize claim now", "cheap pills offer free",
            "win cash prize click", "free offer money win"] * 4
    ham = ["meeting at noon tomorrow", "see attached project report", "lunch with team today",
           "project schedule update attached", "call me about the report"] * 4
    X = pd.Series(spam + ham)
    y = np.array([1] * len(spam) + [0] * len(ham))
    models = sc.get_models()
    assert len(models) >= 3
    for name, (clf, _) in models.items():
        tfidf = sc.make_tfidf().set_params(min_df=1)
        pipe = Pipeline([("tfidf", tfidf), ("clf", clf)])
        if name == "KNN":
            pipe.set_params(clf__n_neighbors=3)
        pipe.fit(X, y)
        pred = pipe.predict(pd.Series(["free money prize", "project meeting report"]))
        assert list(pred) == [1, 0], name
        assert sc.score_for_auc(pipe, X).shape == (len(X),)


def test_mcnemar():
    y = np.array([1, 1, 0, 0, 1])
    a = np.array([1, 1, 0, 0, 0])
    b = np.array([1, 0, 0, 1, 0])
    n_b, n_c, p = sc.mcnemar(y, a, b)
    assert (n_b, n_c) == (2, 0)
    assert 0 < p <= 1
    assert sc.mcnemar(y, a, a)[2] == 1.0
