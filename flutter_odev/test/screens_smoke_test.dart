import 'package:avuclu_hoca/app.dart';
import 'package:avuclu_hoca/data/app_database.dart';
import 'package:avuclu_hoca/services/password_hasher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Demo verisiyle bütün ekranları açıp taşma/hata olmadığını denetler.
/// En üstteki sayfanın dikey kaydırıcısı (metin alanlarının iç kaydırıcıları değil).
Finder _pageScrollable() =>
    find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    Intl.defaultLocale = 'tr_TR';
  });

  Future<void> goTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      // Tembel listede henüz çizilmemiş olabilir: görünene kadar kaydır.
      await tester.scrollUntilVisible(finder, 200, scrollable: _pageScrollable());
    }
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    // pageBack() İngilizce "Back" ipucunu arar; uygulama Türkçe olduğu için düğmeye doğrudan bas.
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
  }

  Future<void> openDemo(WidgetTester tester, {Size size = const Size(1080, 2400)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AvucluHocaApp(db: AppDatabase.inMemory(), hasher: const PasswordHasher(iterations: 10)));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Demo hesabıyla dene'));
  }

  testWidgets('ders detayı: notlar, hedef tablosu, not girişi', (tester) async {
    await openDemo(tester);
    await goTab(tester, 'Dersler');
    expect(find.text('Tahmini dönem ortalaması'), findsOneWidget);

    await tap(tester, find.text('Olasılık ve İstatistik'));
    expect(find.text('Final için hedef'), findsOneWidget);
    expect(find.textContaining('Kalanlardan'), findsOneWidget);

    // Final notunu gir: vize 58 (%40) + final 80 (%60) = 71,2 -> CC
    await tap(tester, find.text('Not gir'));
    await tester.enterText(find.byType(TextFormField).last, '80');
    await tap(tester, find.text('Kaydet'));
    expect(find.text('Ağırlık %60 · katkı 48 puan'), findsOneWidget);
    await tester.drag(_pageScrollable(), const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.text('CC'), findsWidgets);
    expect(find.text('Dersi geçtin'), findsOneWidget);
    expect(find.text('Final için hedef'), findsNothing);

    await tap(tester, find.byTooltip('Düzenle'));
    expect(find.text('Dersi düzenle'), findsOneWidget);
    await back(tester);
    await back(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yeni ders: ağırlık toplamı 100 değilse kaydetmez', (tester) async {
    await openDemo(tester);
    await goTab(tester, 'Dersler');
    await tap(tester, find.text('Ders ekle'));
    await tester.enterText(find.byKey(const Key('course-name')), 'Fizik I');
    await tap(tester, find.text('Değerlendirme ekle'));
    // Vize 40 + Final 60 + yeni (0) -> yeni satırın ağırlığı boş: hata
    await tap(tester, find.byKey(const Key('course-save')));
    expect(find.text('Dersi ekle'), findsOneWidget);

    await tap(tester, find.text('Vize + Final'));
    await tap(tester, find.byKey(const Key('course-save')));
    expect(find.text('Dersi ekle'), findsNothing);
    await tester.scrollUntilVisible(find.text('Fizik I'), 200, scrollable: _pageScrollable());
    expect(find.text('Fizik I'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('odak sayacı başlar, duraklar, sıfırlanır', (tester) async {
    await openDemo(tester);
    await goTab(tester, 'Odak');
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-toggle')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Çalışıyor'), findsOneWidget);
    await tester.tap(find.byKey(const Key('focus-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Duraklatıldı'), findsOneWidget);
    await tap(tester, find.byTooltip('Sıfırla'));
    expect(find.text('25:00'), findsOneWidget);

    await tap(tester, find.byTooltip('Elle çalışma ekle'));
    await tap(tester, find.text('Kaydet'));
    expect(find.textContaining('çalışma eklendi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('istatistik, profil ve ayarlar', (tester) async {
    await openDemo(tester);
    await goTab(tester, 'İstatistik');
    expect(find.text('Bu hafta'), findsOneWidget);
    await tap(tester, find.text('Aylık'));
    await tap(tester, find.byTooltip('Önceki'));
    expect(find.text('Derslere göre'), findsOneWidget);

    await goTab(tester, 'Ana Sayfa');
    await tap(tester, find.byTooltip('Profil ve ayarlar'));
    expect(find.text('Hakan Demir'), findsOneWidget);
    await tap(tester, find.text('Ayarlar'));
    await tap(tester, find.text('Koyu'));
    expect(Theme.of(tester.element(find.text('Görünüm'))).brightness, Brightness.dark);
    await back(tester);
    await tap(tester, find.text('Şifre değiştir'));
    await back(tester);
    await tap(tester, find.text('Profili düzenle'));
    await back(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar ekranda (360 dp) ana sayfa ve görevler taşmaz', (tester) async {
    await openDemo(tester, size: const Size(936, 1800));
    expect(find.text('Merhaba Hakan!'), findsOneWidget);
    await goTab(tester, 'Görevler');
    await tap(tester, find.textContaining('Geciken'));
    await goTab(tester, 'Dersler');
    await goTab(tester, 'İstatistik');
    expect(tester.takeException(), isNull);
  });
}
