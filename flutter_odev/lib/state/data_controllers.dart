import '../data/app_database.dart';
import '../models/course.dart';
import '../models/study_session.dart';
import '../models/study_task.dart';
import '../services/grade_calculator.dart';
import '../services/study_stats.dart';
import '../utils/ids.dart';
import 'auth_controller.dart';
import 'owned_collection.dart';

class CourseController extends OwnedCollection<Course> {
  CourseController(AppDatabase db, AuthController auth) : super(db.courses, auth);

  @override
  Course fromJson(Map<String, dynamic> json) => Course.fromJson(json);

  @override
  Map<String, dynamic> toJson(Course item) => item.toJson();

  @override
  String idOf(Course item) => item.id;

  @override
  int compare(Course a, Course b) => a.createdAt.compareTo(b.createdAt);

  List<Course> get courses => items;

  double? get gpa => GradeCalculator.gpa(items);

  int get totalCredits => items.fold(0, (sum, c) => sum + c.credits);

  Future<Course> create({
    required String name,
    required String code,
    required String instructor,
    required int credits,
    required int colorIndex,
    required List<Assessment> assessments,
    int weeklyGoalMinutes = 0,
  }) async {
    final course = Course(
      id: newId(),
      ownerId: ownerId!,
      name: name.trim(),
      code: code.trim(),
      instructor: instructor.trim(),
      credits: credits,
      colorIndex: colorIndex,
      assessments: assessments,
      createdAt: DateTime.now(),
      weeklyGoalMinutes: weeklyGoalMinutes,
    );
    await save(course);
    return course;
  }

  Future<void> setScore(Course course, String assessmentId, double? score) => save(
        course.copyWith(
          assessments: [
            for (final a in course.assessments)
              a.id == assessmentId ? a.copyWith(score: score, clearScore: score == null) : a,
          ],
        ),
      );

  /// Sıradaki ders rengi (mevcut derslerde en az kullanılan).
  int suggestColorIndex() {
    final counts = List<int>.filled(coursePalette.length, 0);
    for (final c in items) {
      counts[c.colorIndex % coursePalette.length]++;
    }
    var best = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] < counts[best]) best = i;
    }
    return best;
  }
}

class TaskController extends OwnedCollection<StudyTask> {
  TaskController(AppDatabase db, AuthController auth) : super(db.tasks, auth);

  @override
  StudyTask fromJson(Map<String, dynamic> json) => StudyTask.fromJson(json);

  @override
  Map<String, dynamic> toJson(StudyTask item) => item.toJson();

  @override
  String idOf(StudyTask item) => item.id;

  @override
  int compare(StudyTask a, StudyTask b) => TaskFilter.compareByUrgency(a, b);

  List<StudyTask> get tasks => items;

  List<StudyTask> filtered(TaskFilter filter, {DateTime? now, String? courseId}) => filter.apply(
        courseId == null ? items : items.where((t) => t.courseId == courseId),
        now ?? DateTime.now(),
      );

  int count(TaskFilter filter, {DateTime? now}) {
    final at = now ?? DateTime.now();
    return items.where((t) => filter.matches(t, at)).length;
  }

  Future<StudyTask> create({
    required String title,
    String note = '',
    String? courseId,
    DateTime? dueDate,
    TaskKind kind = TaskKind.homework,
    TaskPriority priority = TaskPriority.normal,
  }) async {
    final task = StudyTask(
      id: newId(),
      ownerId: ownerId!,
      title: title.trim(),
      note: note.trim(),
      courseId: courseId,
      dueDate: dueDate,
      kind: kind,
      priority: priority,
      createdAt: DateTime.now(),
    );
    await save(task);
    return task;
  }

  Future<void> toggleDone(StudyTask task) => save(
        task.isDone ? task.copyWith(clearCompleted: true) : task.copyWith(completedAt: DateTime.now()),
      );

  /// Silinen dersin görevlerini dersten ayırır (görevler kaybolmaz).
  Future<void> detachCourse(String courseId) async {
    for (final t in items.where((t) => t.courseId == courseId).toList()) {
      await save(t.copyWith(clearCourse: true));
    }
  }
}

class SessionController extends OwnedCollection<StudySession> {
  SessionController(AppDatabase db, AuthController auth) : super(db.sessions, auth);

  @override
  StudySession fromJson(Map<String, dynamic> json) => StudySession.fromJson(json);

  @override
  Map<String, dynamic> toJson(StudySession item) => item.toJson();

  @override
  String idOf(StudySession item) => item.id;

  /// En yeni oturum başta.
  @override
  int compare(StudySession a, StudySession b) => b.start.compareTo(a.start);

  List<StudySession> get sessions => items;

  int minutesToday([DateTime? now]) => StudyStats.minutesOn(items, now ?? DateTime.now());

  int streak([DateTime? now]) => StudyStats.currentStreak(items, now ?? DateTime.now());

  List<StudySession> forCourse(String courseId) => items.where((s) => s.courseId == courseId).toList();

  int minutesThisWeekFor(String courseId, [DateTime? now]) {
    final from = startOfWeek(now ?? DateTime.now());
    return StudyStats.totalMinutes(forCourse(courseId), from: from);
  }

  Future<StudySession?> record({
    required int minutes,
    required DateTime start,
    String? courseId,
    SessionSource source = SessionSource.focus,
    String note = '',
  }) async {
    if (minutes <= 0) return null;
    final session = StudySession(
      id: newId(),
      ownerId: ownerId!,
      courseId: courseId,
      start: start,
      minutes: minutes,
      source: source,
      note: note.trim(),
    );
    await save(session);
    return session;
  }
}
