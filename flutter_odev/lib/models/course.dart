import 'package:flutter/material.dart';

/// Dersin bir değerlendirme kalemi: vize, final, ödev, proje...
class Assessment {
  const Assessment({
    required this.id,
    required this.name,
    required this.weight,
    this.score,
    this.date,
  });

  final String id;
  final String name;

  /// Ortalamaya etkisi, yüzde (0-100).
  final double weight;

  /// Alınan not (0-100). Henüz açıklanmadıysa null.
  final double? score;

  /// Sınav/teslim tarihi (isteğe bağlı).
  final DateTime? date;

  bool get isGraded => score != null;

  Assessment copyWith({String? name, double? weight, double? score, bool clearScore = false, DateTime? date, bool clearDate = false}) =>
      Assessment(
        id: id,
        name: name ?? this.name,
        weight: weight ?? this.weight,
        score: clearScore ? null : (score ?? this.score),
        date: clearDate ? null : (date ?? this.date),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weight': weight,
        'score': score,
        'date': date?.toIso8601String(),
      };

  factory Assessment.fromJson(Map<String, dynamic> json) => Assessment(
        id: json['id'] as String,
        name: json['name'] as String,
        weight: (json['weight'] as num).toDouble(),
        score: (json['score'] as num?)?.toDouble(),
        date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
      );
}

class Course {
  const Course({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.code,
    required this.instructor,
    required this.credits,
    required this.colorIndex,
    required this.assessments,
    required this.createdAt,
    this.weeklyGoalMinutes = 0,
  });

  final String id;
  final String ownerId;
  final String name;
  final String code;
  final String instructor;

  /// Kredi/AKTS. GANO hesabında ağırlık olarak kullanılır.
  final int credits;

  /// [coursePalette] içindeki renk.
  final int colorIndex;
  final List<Assessment> assessments;
  final DateTime createdAt;

  /// Bu ders için haftalık çalışma hedefi (dakika). 0: hedef yok.
  final int weeklyGoalMinutes;

  Color get color => coursePalette[colorIndex % coursePalette.length];

  String get displayName => code.isEmpty ? name : '$code · $name';

  Course copyWith({
    String? name,
    String? code,
    String? instructor,
    int? credits,
    int? colorIndex,
    List<Assessment>? assessments,
    int? weeklyGoalMinutes,
  }) =>
      Course(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        code: code ?? this.code,
        instructor: instructor ?? this.instructor,
        credits: credits ?? this.credits,
        colorIndex: colorIndex ?? this.colorIndex,
        assessments: assessments ?? this.assessments,
        createdAt: createdAt,
        weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'name': name,
        'code': code,
        'instructor': instructor,
        'credits': credits,
        'colorIndex': colorIndex,
        'assessments': [for (final a in assessments) a.toJson()],
        'createdAt': createdAt.toIso8601String(),
        'weeklyGoalMinutes': weeklyGoalMinutes,
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        name: json['name'] as String,
        code: json['code'] as String? ?? '',
        instructor: json['instructor'] as String? ?? '',
        credits: json['credits'] as int? ?? 0,
        colorIndex: json['colorIndex'] as int? ?? 0,
        assessments: [
          for (final a in (json['assessments'] as List? ?? const []))
            Assessment.fromJson(a as Map<String, dynamic>),
        ],
        createdAt: DateTime.parse(json['createdAt'] as String),
        weeklyGoalMinutes: json['weeklyGoalMinutes'] as int? ?? 0,
      );
}

/// Ders renkleri (açık ve koyu temada okunaklı tonlar).
const coursePalette = <Color>[
  Color(0xFF4F46E5), // indigo
  Color(0xFF0EA5E9), // gök mavisi
  Color(0xFF10B981), // zümrüt
  Color(0xFFF59E0B), // kehribar
  Color(0xFFEF4444), // kırmızı
  Color(0xFFEC4899), // pembe
  Color(0xFF8B5CF6), // mor
  Color(0xFF14B8A6), // turkuaz
  Color(0xFFF97316), // turuncu
  Color(0xFF64748B), // arduvaz
];
