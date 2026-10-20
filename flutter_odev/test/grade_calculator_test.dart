import 'package:avuclu_hoca/models/course.dart';
import 'package:avuclu_hoca/services/grade_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Assessment a(String name, double weight, [double? score]) =>
    Assessment(id: name, name: name, weight: weight, score: score);

Course course(int credits, List<Assessment> assessments) => Course(
      id: 'c$credits${assessments.length}',
      ownerId: 'u',
      name: 'Ders',
      code: '',
      instructor: '',
      credits: credits,
      colorIndex: 0,
      assessments: assessments,
      createdAt: DateTime(2026),
    );

void main() {
  group('Harf notu', () {
    test('sınırlar', () {
      expect(LetterGrade.fromScore(100), LetterGrade.aa);
      expect(LetterGrade.fromScore(90), LetterGrade.aa);
      expect(LetterGrade.fromScore(89.4), LetterGrade.ba);
      expect(LetterGrade.fromScore(89.5), LetterGrade.aa); // yuvarlanır
      expect(LetterGrade.fromScore(77), LetterGrade.cb);
      expect(LetterGrade.fromScore(60), LetterGrade.dd);
      expect(LetterGrade.fromScore(59), LetterGrade.fd);
      expect(LetterGrade.fromScore(12), LetterGrade.ff);
      expect(LetterGrade.dd.isPassing, isTrue);
      expect(LetterGrade.fd.isPassing, isFalse);
    });
  });

  group('Ders özeti', () {
    test('ağırlıklı ortalama yalnızca girilmiş notlarla hesaplanır', () {
      final s = GradeCalculator.summarize([a('Vize', 40, 70), a('Final', 60)]);
      expect(s.average, 70);
      expect(s.gradedWeight, 40);
      expect(s.remainingWeight, 60);
      expect(s.isComplete, isFalse);
      expect(s.hasWeightProblem, isFalse);
    });

    test('tamamlanmış ders', () {
      final s = GradeCalculator.summarize([a('Vize', 40, 70), a('Final', 60, 85)]);
      expect(s.average, closeTo(79, 1e-9)); // 0.4*70 + 0.6*85
      expect(s.isComplete, isTrue);
      expect(s.letter, LetterGrade.cb);
    });

    test('not yoksa ortalama null', () {
      final s = GradeCalculator.summarize([a('Vize', 50), a('Final', 50)]);
      expect(s.average, isNull);
      expect(s.letter, isNull);
    });

    test('ağırlık toplamı 100 değilse uyarı', () {
      expect(GradeCalculator.summarize([a('Vize', 40, 50), a('Final', 50)]).hasWeightProblem, isTrue);
    });
  });

  group('Finalden kaç almalıyım?', () {
    test('vize 70 (%40) iken 50 ortalama için finalden 36,67', () {
      final needed = GradeCalculator.requiredScoreFor([a('Vize', 40, 70), a('Final', 60)], 50);
      expect(needed, closeTo(36.67, 0.01));
    });

    test('harf notlarına göre gereksinimler', () {
      final reqs = GradeCalculator.requirements([a('Vize', 40, 70), a('Final', 60)]);
      final aa = reqs.firstWhere((r) => r.grade == LetterGrade.aa);
      // 89,5 ortalama için: (89,5 - 28) / 0,6 = 102,5 -> imkânsız
      expect(aa.isImpossible, isTrue);
      final dd = reqs.firstWhere((r) => r.grade == LetterGrade.dd);
      // 59,5 için: (59,5 - 28) / 0,6 = 52,5
      expect(dd.requiredScore, closeTo(52.5, 1e-9));
      expect(dd.isGuaranteed, isFalse);
    });

    test('yüksek vize ile alt harfler garanti', () {
      final reqs = GradeCalculator.requirements([a('Vize', 80, 100), a('Final', 20)]);
      expect(reqs.firstWhere((r) => r.grade == LetterGrade.dd).isGuaranteed, isTrue);
      expect(reqs.firstWhere((r) => r.grade == LetterGrade.aa).requiredScore, closeTo(47.5, 1e-9));
    });

    test('kalan sınav yoksa hesap yapılmaz', () {
      expect(GradeCalculator.requiredScoreFor([a('Vize', 40, 70), a('Final', 60, 80)], 50), isNull);
      expect(GradeCalculator.requirements([a('Vize', 100, 70)]), isEmpty);
    });
  });

  group('GANO', () {
    test('kredi ağırlıklı ortalama', () {
      final gpa = GradeCalculator.gpa([
        course(6, [a('Final', 100, 92)]), // AA 4.0
        course(4, [a('Final', 100, 72)]), // CC 2.0
        course(3, [a('Final', 100)]), // not yok -> dahil değil
        course(0, [a('Final', 100, 40)]), // kredisiz -> dahil değil
      ]);
      expect(gpa, closeTo((4.0 * 6 + 2.0 * 4) / 10, 1e-9));
    });

    test('hesaplanacak ders yoksa null', () {
      expect(GradeCalculator.gpa([course(5, [a('Final', 100)])]), isNull);
      expect(GradeCalculator.gpa(const []), isNull);
    });

    test('GANO\'ya giren kredi', () {
      expect(
        GradeCalculator.gradedCredits([course(6, [a('F', 100, 50)]), course(4, [a('F', 100)])]),
        6,
      );
    });
  });
}
