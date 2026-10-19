"""
Kaydedilmiş en iyi modelle yeni e-postaları sınıflandırır.

Kullanım:
  python predict.py "Congratulations! You won a free iPhone, click here"
  python predict.py --file email.txt
  echo "metin" | python predict.py
"""
import argparse
import sys
from pathlib import Path

import joblib

from spam_classification import LABELS, OUT, clean_text, score_for_auc

MODEL_PATH = OUT / "best_model.joblib"


def load_model(path: Path = MODEL_PATH):
    if not path.exists():
        sys.exit(f"Model bulunamadı: {path}\nÖnce `python spam_classification.py` çalıştırın.")
    return joblib.load(path)


def classify(model, texts):
    cleaned = [clean_text(t) for t in texts]
    preds = model.predict(cleaned)
    scores = score_for_auc(model, cleaned)
    return [(LABELS[p], float(s)) for p, s in zip(preds, scores)]


def main():
    parser = argparse.ArgumentParser(description="Spam / ham e-posta tahmini")
    parser.add_argument("texts", nargs="*", help="Sınıflandırılacak metin(ler)")
    parser.add_argument("--file", type=Path, help="Tek bir e-posta içeren metin dosyası")
    parser.add_argument("--model", type=Path, default=MODEL_PATH, help="Model dosyası (.joblib)")
    args = parser.parse_args()

    texts = list(args.texts)
    if args.file:
        texts.append(args.file.read_text(encoding="utf-8", errors="ignore"))
    if not texts and not sys.stdin.isatty():
        texts.append(sys.stdin.read())
    if not texts:
        parser.error("Metin, --file veya stdin girişi gerekli")

    model = load_model(args.model)
    clf_name = type(model.named_steps["clf"]).__name__
    for text, (label, score) in zip(texts, classify(model, texts)):
        kind = "olasılık(spam)" if hasattr(model, "predict_proba") else "karar skoru"
        preview = " ".join(text.split())[:70]
        print(f"[{label.upper():4}] {kind}={score:+.3f}  ({clf_name})  {preview}")


if __name__ == "__main__":
    main()
