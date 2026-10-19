"""spam_classification.ipynb not defterini üretir ve çalıştırır.

  python scripts/build_notebook.py
"""
from pathlib import Path

import nbformat as nbf
from nbconvert.preprocessors import ExecutePreprocessor

ROOT = Path(__file__).resolve().parents[1]
NB_PATH = ROOT / "spam_classification.ipynb"

md = nbf.v4.new_markdown_cell
code = nbf.v4.new_code_cell

cells = [
    md("# Spam / Normal E-posta Sınıflandırma\n\n"
       "Bu not defteri ödevin adımlarını sırayla gösterir: veri seti incelemesi, ön işleme, "
       "6 makine öğrenmesi algoritmasının eğitimi, test kümesinde karşılaştırma ve en iyi algoritmanın seçimi.\n\n"
       "Hiperparametre araması (5-katlı GridSearchCV) uzun sürdüğü için `spam_classification.py` betiğinde "
       "yapılır; burada betiğin bulduğu en iyi parametrelerle modeller yeniden eğitilir ve test edilir."),
    code("import json\n"
         "import numpy as np\n"
         "import pandas as pd\n"
         "import matplotlib.pyplot as plt\n"
         "import seaborn as sns\n"
         "from IPython.display import Image, display\n"
         "from sklearn.model_selection import train_test_split\n"
         "from sklearn.pipeline import Pipeline\n"
         "from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score\n"
         "import spam_classification as sc\n"
         "sns.set_theme(style='whitegrid')\n"
         "pd.set_option('display.float_format', '{:.4f}'.format)"),
    md("## 1. Veri seti: Enron-Spam\n\n"
       "Enron şirketinin 6 çalışanının gerçek posta kutularından alınan normal (ham) e-postalar ile "
       "farklı spam tuzaklarından toplanan spam e-postaların birleşimidir (Metsis vd., 2006)."),
    code("raw = pd.read_csv(sc.ENRON_PATH)\n"
         "print(raw.shape)\n"
         "raw.head()"),
    code("raw['Spam/Ham'].value_counts().plot.bar(color=['#e76f51', '#2a9d8f'], title='Sınıf dağılımı (ham veri)')\n"
         "plt.show()"),
    md("## 2. Ön işleme\n\n"
       "* Konu + gövde birleştirilir, küçük harfe çevrilir.\n"
       "* URL → `urltoken`, e-posta adresi → `emailtoken`, sayı → `numtoken`.\n"
       "* Harf dışı karakterler silinir.\n"
       "* Boş ve **tekrarlı** metinler atılır (aynı e-postanın hem eğitimde hem testte olması sonucu şişirir)."),
    code("df = sc.load_enron()\n"
         "df['kelime_sayisi'] = df['text'].str.split().str.len()\n"
         "df.head()"),
    code("fig, ax = plt.subplots(figsize=(9, 4))\n"
         "sns.histplot(data=df.assign(sinif=df['label'].map({0: 'ham', 1: 'spam'})), x='kelime_sayisi',\n"
         "             hue='sinif', bins=80, log_scale=True, element='step', ax=ax)\n"
         "ax.set_title('E-posta uzunluğu dağılımı (kelime, log ölçek)')\n"
         "plt.show()\n"
         "df.groupby('label')['kelime_sayisi'].describe()"),
    md("## 3. Eğitim / test ayrımı\n\nStratified %80 eğitim, %20 test (`random_state=42`)."),
    code("X_train, X_test, y_train, y_test = train_test_split(\n"
         "    df['text'], df['label'], test_size=0.2, stratify=df['label'], random_state=sc.RANDOM_STATE)\n"
         "len(X_train), len(X_test)"),
    md("## 4. Modellerin eğitimi ve testi\n\n"
       "Her model `TF-IDF → sınıflandırıcı` boru hattıdır. Parametreler `results/results.csv` dosyasındaki "
       "GridSearch sonuçlarından alınır."),
    code("best_params = pd.read_csv(sc.OUT / 'results.csv').set_index('Model')['En iyi parametreler']\n"
         "rows, fitted = [], {}\n"
         "for name, (clf, _) in sc.get_models().items():\n"
         "    pipe = Pipeline([('tfidf', sc.make_tfidf()), ('clf', clf)])\n"
         "    params = json.loads(best_params[name])\n"
         "    params = {k: tuple(v) if isinstance(v, list) else v for k, v in params.items()}\n"
         "    pipe.set_params(**params).fit(X_train, y_train)\n"
         "    pred = pipe.predict(X_test)\n"
         "    rows.append({'Model': name, 'Accuracy': accuracy_score(y_test, pred),\n"
         "                 'Precision': precision_score(y_test, pred), 'Recall': recall_score(y_test, pred),\n"
         "                 'F1': f1_score(y_test, pred), 'ROC-AUC': roc_auc_score(y_test, sc.score_for_auc(pipe, X_test))})\n"
         "    fitted[name] = pipe\n"
         "res = pd.DataFrame(rows).sort_values('F1', ascending=False).reset_index(drop=True)\n"
         "res"),
    md("## 5. Karşılaştırma grafikleri"),
    code("for f in ['metric_comparison.png', 'confusion_matrices.png', 'roc_curves.png', 'training_time.png']:\n"
         "    display(Image(filename=str(sc.OUT / f)))"),
    md("## 6. İstatistiksel anlamlılık (McNemar testi)\n\n"
       "En iyi model ile diğerleri aynı test örneklerinde karşılaştırılır. p < 0.05 ise fark tesadüfi değildir."),
    code("pd.read_csv(sc.OUT / 'mcnemar.csv')"),
    md("## 7. Hangi kelimeler spam'i belirliyor?"),
    code("display(Image(filename=str(sc.OUT / 'top_spam_words.png')))"),
    md("## 8. Hata analizi: en iyi modelin yanlış sınıfladığı örnekler"),
    code("pd.read_csv(sc.OUT / 'misclassified_samples.csv').head(10)"),
    md("## 9. Genelleme kontrolü: SMS Spam Collection\n\n"
       "Aynı yöntem farklı ve daha dengesiz (%13 spam) bir veri setinde de denenmiştir."),
    code("pd.read_csv(sc.OUT / 'dataset_comparison.csv')"),
    md("## 10. Sonuç"),
    code("best = res.loc[0]\n"
         "print(f\"En iyi algoritma: {best['Model']}  (F1={best['F1']:.4f}, Accuracy={best['Accuracy']:.4f}, ROC-AUC={best['ROC-AUC']:.4f})\")\n"
         "print(open(sc.OUT / 'best_model.txt', encoding='utf-8').read())"),
    md("## 11. Yeni e-postaları sınıflandırma"),
    code("from predict import classify\n"
         "model = fitted[res.loc[0, 'Model']]\n"
         "ornekler = ['Congratulations! You have won a $1000 gift card. Click here to claim your prize now',\n"
         "            'Hi team, the meeting is moved to 3pm tomorrow. Please review the attached agenda.',\n"
         "            'Cheap meds online, no prescription needed, best prices viagra',\n"
         "            'Can you send me the updated gas nomination spreadsheet for next month?']\n"
         "pd.DataFrame(classify(model, ornekler), columns=['tahmin', 'skor']).assign(metin=ornekler)"),
]

nb = nbf.v4.new_notebook(cells=cells, metadata={
    "kernelspec": {"name": "python3", "display_name": "Python 3", "language": "python"},
    "language_info": {"name": "python"},
})
ExecutePreprocessor(timeout=3600, kernel_name="python3").preprocess(nb, {"metadata": {"path": str(ROOT)}})
nbf.write(nb, NB_PATH)
print(f"Yazıldı: {NB_PATH}")
