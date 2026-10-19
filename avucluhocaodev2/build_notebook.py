"""avucluhocaodev2/improve_accuracy.ipynb not defterini üretir ve çalıştırır.

Ağır eğitim tekrarlanmaz; `improve_accuracy.py` çıktıları (results/) okunur.
  python avucluhocaodev2/build_notebook.py
"""
from pathlib import Path

import nbformat as nbf
from nbconvert.preprocessors import ExecutePreprocessor

ROOT = Path(__file__).resolve().parent
NB_PATH = ROOT / "improve_accuracy.ipynb"

md = nbf.v4.new_markdown_cell
code = nbf.v4.new_code_cell

cells = [
    md("# Ödev 2 — Doğruluğu artırma yöntemleri ve her algoritmanın ROC eğrileri\n\n"
       "Bu not defteri `improve_accuracy.py` deneyinin sonuçlarını adım adım gösterir. Her algoritmaya "
       "iyileştirme yöntemleri birikimli olarak eklenmiştir:\n\n"
       "| Aşama | Yöntem |\n|---|---|\n"
       "| A0 | Temel: ham metin + CountVectorizer + varsayılan parametreler |\n"
       "| A1 | + Ön işleme & TF-IDF |\n"
       "| A2 | + Kelime 1-2 gram, karakter 3-5 gram, meta özellikler |\n"
       "| A3 | + χ² özellik seçimi & GridSearch hiperparametre optimizasyonu |\n"
       "| A4 | + Karar eşiği optimizasyonu |\n"
       "| Topluluk | Soft Voting, Stacking, XGBoost, LightGBM |"),
    code("import pandas as pd\n"
         "from IPython.display import Image, display\n"
         "from pathlib import Path\n"
         "R = Path('results')\n"
         "pd.set_option('display.float_format', '{:.4f}'.format)"),
    md("## 1. Aşama bazında test doğruluğu (Enron-Spam, 5.800 test e-postası)"),
    code("pd.read_csv(R / 'accuracy_by_stage.csv', index_col=0)"),
    md("## 2. Topluluk (ensemble) yöntemleri"),
    code("pd.read_csv(R / 'ensemble_results.csv')[['Model', 'Accuracy', 'F1', 'ROC-AUC', 'Hata sayısı']]"),
    md("## 3. Her iyileştirme adımının etkisi"),
    code("display(Image(filename=str(R / 'accuracy_ladder.png')))\n"
         "display(Image(filename=str(R / 'errors_heatmap.png')))"),
    md("## 4. Her algoritmanın ROC eğrisi\n\n"
       "Sol: klasik ROC. Sağ: FPR ekseni log ölçekte (sol üst köşe büyütülmüş). "
       "● varsayılan eşik, ★ optimize edilmiş eşik (A4)."),
    code("for f in sorted((R / 'roc').glob('roc_*.png')):\n"
         "    print(f.stem)\n"
         "    display(Image(filename=str(f)))"),
    md("### Tüm algoritmalar tek sayfada"),
    code("display(Image(filename=str(R / 'roc_all_algorithms.png')))"),
    md("### Optimize modeller ve topluluklar"),
    code("display(Image(filename=str(R / 'roc_final_comparison.png')))"),
    md("## 5. İstatistiksel anlamlılık (McNemar testi)\n\n"
       "En doğru model; en iyi tek model, tüm temel (A0) modeller ve diğer topluluklarla aynı test örnekleri "
       "üzerinde karşılaştırılır."),
    code("pd.read_csv(R / 'mcnemar.csv')"),
    md("## 6. Genelleme kontrolü: SMS Spam Collection"),
    code("display(pd.read_csv(R / 'sms' / 'accuracy_by_stage.csv', index_col=0))\n"
         "display(pd.read_csv(R / 'sms' / 'ensemble_results.csv')[['Model', 'Accuracy', 'F1', 'ROC-AUC', 'Hata sayısı']])\n"
         "display(Image(filename=str(R / 'sms' / 'roc_all_algorithms.png')))"),
    md("## 7. Sonuç"),
    code("print(open(R / 'summary.txt', encoding='utf-8').read())"),
]

nb = nbf.v4.new_notebook(cells=cells, metadata={
    "kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"},
    "language_info": {"name": "python"},
})
ExecutePreprocessor(timeout=600, kernel_name="python3").preprocess(nb, {"metadata": {"path": str(ROOT)}})
nbf.write(nb, NB_PATH)
print(f"Yazıldı: {NB_PATH}")
