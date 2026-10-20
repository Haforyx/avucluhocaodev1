import 'package:flutter/material.dart';

import '../models/course.dart';

/// Harf notu ve 4'lük sistemdeki karşılığı (yaygın üniversite tablosu).
enum LetterGrade {
  aa('AA', 90, 4.0, Color(0xFF10B981)),
  ba('BA', 85, 3.5, Color(0xFF22C55E)),
  bb('BB', 80, 3.0, Color(0xFF84CC16)),
  cb('CB', 75, 2.5, Color(0xFF0EA5E9)),
  cc('CC', 70, 2.0, Color(0xFF6366F1)),
  dc('DC', 65, 1.5, Color(0xFFF59E0B)),
  dd('DD', 60, 1.0, Color(0xFFF97316)),
  fd('FD', 50, 0.5, Color(0xFFEF4444)),
  ff('FF', 0, 0.0, Color(0xFFDC2626));

  const LetterGrade(this.label, this.minScore, this.coefficient, this.color);

  final String label;

  /// Bu harfi almak için gereken en düşük ortalama.
  final double minScore;

  /// 4'lük sistemdeki katsayı.
  final double coefficient;
  final Color color;

  /// DD ve üstü geçer not sayılır.
  bool get isPassing => coefficient >= 1.0;

  static LetterGrade fromScore(double score) {
    // Not kırpılır: 89,5 gibi değerler yuvarlanarak AA sayılır.
    final rounded = score.clamp(0, 100).roundToDouble();
    return values.firstWhere((g) => rounded >= g.minScore);
  }
}

/// Ağırlık toplamında kabul edilen yuvarlama payı (ör. 33,333 × 3 = 99,999).
/// Ders formu da aynı payla doğrular.
const weightTolerance = 0.01;

/// Bir ders için hesaplanan özet.
class CourseGradeSummary {
  const CourseGradeSummary({
    required this.average,
    required this.gradedWeight,
    required this.totalWeight,
  });

  /// Notu girilmiş kalemlerin ağırlıklı ortalaması (0-100). Not yoksa null.
  final double? average;

  /// Notu girilmiş kalemlerin toplam ağırlığı (%).
  final double gradedWeight;

  /// Bütün kalemlerin toplam ağırlığı (%). Normalde 100 olmalı.
  final double totalWeight;

  bool get isComplete => gradedWeight >= 100 - weightTolerance && average != null;

  bool get hasWeightProblem => (totalWeight - 100).abs() > weightTolerance;

  double get remainingWeight => (100 - gradedWeight).clamp(0, 100).toDouble();

  LetterGrade? get letter => average == null ? null : LetterGrade.fromScore(average!);
}

/// Bir hedef ortalama için kalan sınavlardan alınması gereken not.
class TargetRequirement {
  const TargetRequirement(this.grade, this.requiredScore);

  final LetterGrade grade;

  /// Kalan her kalemden alınması gereken (eşit) not.
  final double requiredScore;

  /// Kalan sınavlardan 0 alınsa bile bu harf garanti.
  bool get isGuaranteed => requiredScore <= 0;

  /// 100 alınsa bile ulaşılamıyor.
  bool get isImpossible => requiredScore > 100;
}

class GradeCalculator {
  GradeCalculator._();

  static CourseGradeSummary summarize(List<Assessment> assessments) {
    var weighted = 0.0;
    var graded = 0.0;
    var total = 0.0;
    for (final a in assessments) {
      total += a.weight;
      if (a.score != null) {
        weighted += a.score! * a.weight;
        graded += a.weight;
      }
    }
    return CourseGradeSummary(
      average: graded == 0 ? null : weighted / graded,
      gradedWeight: graded,
      totalWeight: total,
    );
  }

  /// Ortalamanın şu anki katkısı: alınan notların 100 üzerinden payı.
  /// Örn. vize %40'tan 70 alındıysa katkı 28 puandır.
  static double earnedPoints(List<Assessment> assessments) {
    var earned = 0.0;
    for (final a in assessments) {
      if (a.score != null) earned += a.score! * a.weight / 100;
    }
    return earned;
  }

  /// [target] ortalamasına ulaşmak için kalan kalemlerden alınması gereken not.
  ///
  /// Kalan ağırlık yoksa null döner. Toplam ağırlık 100 kabul edilir.
  static double? requiredScoreFor(List<Assessment> assessments, double target) {
    final summary = summarize(assessments);
    final remaining = 100 - summary.gradedWeight;
    if (remaining <= weightTolerance) return null;
    return (target - earnedPoints(assessments)) * 100 / remaining;
  }

  /// Her harf notu için gereken not. Kalan sınav yoksa boş liste.
  static List<TargetRequirement> requirements(List<Assessment> assessments) {
    final out = <TargetRequirement>[];
    for (final grade in LetterGrade.values) {
      if (grade == LetterGrade.ff) continue;
      // Harf notları yuvarlanmış ortalamaya göre verildiği için hedef 0,5 aşağıdadır.
      final needed = requiredScoreFor(assessments, grade.minScore - 0.5);
      if (needed == null) return const [];
      out.add(TargetRequirement(grade, needed));
    }
    return out;
  }

  /// Ağırlıklı genel not ortalaması (4'lük sistem). Notu olan dersler dikkate
  /// alınır; kredisi 0 olan dersler ortalamayı etkilemez.
  static double? gpa(Iterable<Course> courses) {
    var points = 0.0;
    var credits = 0;
    for (final course in courses) {
      final letter = summarize(course.assessments).letter;
      if (letter == null || course.credits <= 0) continue;
      points += letter.coefficient * course.credits;
      credits += course.credits;
    }
    return credits == 0 ? null : points / credits;
  }

  /// GANO hesabına giren toplam kredi.
  static int gradedCredits(Iterable<Course> courses) => courses
      .where((c) => c.credits > 0 && summarize(c.assessments).average != null)
      .fold(0, (sum, c) => sum + c.credits);
}
