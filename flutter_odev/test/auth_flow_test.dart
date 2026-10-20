import 'package:avuclu_hoca/app.dart';
import 'package:avuclu_hoca/data/app_database.dart';
import 'package:avuclu_hoca/services/password_hasher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Ödevin istediği akış: kayıt ol -> giriş yap -> "Merhaba Hakan" yazsın.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    Intl.defaultLocale = 'tr_TR';
  });

  late AppDatabase db;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AvucluHocaApp(db: db, hasher: const PasswordHasher(iterations: 10)));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() => db = AppDatabase.inMemory());

  testWidgets('kayıt ol, çıkış yap, giriş yap: her seferinde "Merhaba Hakan!"', (tester) async {
    await pumpApp(tester);
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);

    // --- Kayıt ---
    await tap(tester, find.byKey(const Key('go-register')));
    expect(find.text('Hesap oluştur'), findsOneWidget);

    // Boş formu gönderince hatalar görünür.
    await tap(tester, find.byKey(const Key('register-submit')));
    expect(find.text('Adını ve soyadını gir.'), findsOneWidget);
    expect(find.text('Devam etmek için onaylaman gerekiyor.'), findsOneWidget);

    await enter(tester, 'register-fullname', 'hakan yılmaz');
    await enter(tester, 'register-username', 'hakan');
    await enter(tester, 'register-email', 'hakan@mail.com');
    await enter(tester, 'register-password', 'Gizli.Sifre1');
    await enter(tester, 'register-confirm', 'Baska1234');
    await enter(tester, 'register-answer', 'istanbul');
    await tap(tester, find.byKey(const Key('register-terms')));
    await tap(tester, find.byKey(const Key('register-submit')));
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);

    await enter(tester, 'register-confirm', 'Gizli.Sifre1');
    await tap(tester, find.byKey(const Key('register-submit')));

    expect(find.text('Merhaba Hakan!'), findsOneWidget);
    expect(find.byKey(const Key('register-submit')), findsNothing);

    // --- Çıkış ---
    await tap(tester, find.byTooltip('Profil ve ayarlar'));
    await tap(tester, find.byKey(const Key('logout')));
    await tap(tester, find.text('Çıkış yap').last);
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);

    // --- Hatalı giriş ---
    await enter(tester, 'login-identifier', 'hakan');
    await enter(tester, 'login-password', 'yanlis');
    await tap(tester, find.byKey(const Key('login-submit')));
    expect(find.textContaining('şifre hatalı'), findsOneWidget);

    // --- Doğru giriş (e-posta ile) ---
    await enter(tester, 'login-identifier', 'hakan@mail.com');
    await enter(tester, 'login-password', 'Gizli.Sifre1');
    await tap(tester, find.byKey(const Key('login-submit')));
    expect(find.text('Merhaba Hakan!'), findsOneWidget);
  });

  testWidgets('demo hesabıyla giriş ana sayfayı örnek verilerle açar', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.text('Demo hesabıyla dene'));
    expect(find.text('Merhaba Hakan!'), findsOneWidget);
    expect(find.text('GANO'), findsOneWidget);

    // Sekmeler açılabiliyor.
    for (final tab in ['Görevler', 'Odak', 'Dersler', 'İstatistik', 'Ana Sayfa']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('görev ekleme ve tamamlama', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.text('Demo hesabıyla dene'));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Görevler')));
    await tester.pumpAndSettle();

    await tap(tester, find.text('Yeni görev'));
    await tester.enterText(find.byKey(const Key('task-title')), 'Fizik laboratuvar raporu');
    await tap(tester, find.widgetWithText(ActionChip, 'Yarın'));
    await tap(tester, find.byKey(const Key('task-save')));
    expect(find.text('Fizik laboratuvar raporu'), findsOneWidget);

    final tile = find.ancestor(of: find.text('Fizik laboratuvar raporu'), matching: find.byType(ListTile));
    await tap(tester, find.descendant(of: tile, matching: find.byTooltip('Tamamlandı olarak işaretle')));
    expect(find.textContaining('tamamlandı.'), findsOneWidget);
    // Aktif listeden çıktı.
    expect(find.text('Fizik laboratuvar raporu'), findsNothing);
  });
}
