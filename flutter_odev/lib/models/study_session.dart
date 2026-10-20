enum SessionSource { focus, manual }

/// Tamamlanmış bir çalışma oturumu (odak sayacından ya da elle girilmiş).
class StudySession {
  const StudySession({
    required this.id,
    required this.ownerId,
    required this.start,
    required this.minutes,
    this.courseId,
    this.source = SessionSource.focus,
    this.note = '',
  });

  final String id;
  final String ownerId;
  final String? courseId;
  final DateTime start;
  final int minutes;
  final SessionSource source;
  final String note;

  DateTime get end => start.add(Duration(minutes: minutes));

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'courseId': courseId,
        'start': start.toIso8601String(),
        'minutes': minutes,
        'source': source.name,
        'note': note,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        courseId: json['courseId'] as String?,
        start: DateTime.parse(json['start'] as String),
        minutes: json['minutes'] as int,
        source: json['source'] == 'manual' ? SessionSource.manual : SessionSource.focus,
        note: json['note'] as String? ?? '',
      );
}
