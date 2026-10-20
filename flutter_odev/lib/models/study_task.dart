import 'package:flutter/material.dart';

enum TaskKind {
  homework('Ödev', Icons.edit_note_rounded),
  exam('Sınav', Icons.quiz_rounded),
  project('Proje', Icons.rocket_launch_rounded),
  reading('Okuma', Icons.menu_book_rounded),
  other('Diğer', Icons.push_pin_rounded);

  const TaskKind(this.label, this.icon);

  final String label;
  final IconData icon;

  static TaskKind byName(String? name) =>
      TaskKind.values.firstWhere((k) => k.name == name, orElse: () => TaskKind.other);
}

enum TaskPriority {
  low('Düşük', Color(0xFF64748B)),
  normal('Normal', Color(0xFF0EA5E9)),
  high('Yüksek', Color(0xFFEF4444));

  const TaskPriority(this.label, this.color);

  final String label;
  final Color color;

  static TaskPriority byName(String? name) =>
      TaskPriority.values.firstWhere((p) => p.name == name, orElse: () => TaskPriority.normal);
}

/// Ödev, sınav, proje gibi yapılacak bir iş.
class StudyTask {
  const StudyTask({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    this.note = '',
    this.courseId,
    this.dueDate,
    this.kind = TaskKind.homework,
    this.priority = TaskPriority.normal,
    this.completedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String note;
  final String? courseId;

  /// Son teslim tarihi/saati. null: tarihsiz görev.
  final DateTime? dueDate;
  final TaskKind kind;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isDone => completedAt != null;

  bool isOverdue(DateTime now) => !isDone && dueDate != null && dueDate!.isBefore(now);

  StudyTask copyWith({
    String? title,
    String? note,
    String? courseId,
    bool clearCourse = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskKind? kind,
    TaskPriority? priority,
    DateTime? completedAt,
    bool clearCompleted = false,
  }) =>
      StudyTask(
        id: id,
        ownerId: ownerId,
        title: title ?? this.title,
        note: note ?? this.note,
        courseId: clearCourse ? null : (courseId ?? this.courseId),
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        kind: kind ?? this.kind,
        priority: priority ?? this.priority,
        createdAt: createdAt,
        completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'note': note,
        'courseId': courseId,
        'dueDate': dueDate?.toIso8601String(),
        'kind': kind.name,
        'priority': priority.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        title: json['title'] as String,
        note: json['note'] as String? ?? '',
        courseId: json['courseId'] as String?,
        dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
        kind: TaskKind.byName(json['kind'] as String?),
        priority: TaskPriority.byName(json['priority'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt:
            json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      );
}
