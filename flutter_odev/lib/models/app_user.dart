import '../utils/text_utils.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.iterations,
    required this.securityQuestion,
    required this.securityAnswerHash,
    required this.createdAt,
    this.lastLoginAt,
    this.school = '',
    this.department = '',
  });

  final String id;
  final String fullName;
  final String username;
  final String email;
  final String passwordHash;
  final String salt;
  final int iterations;
  final String securityQuestion;
  final String securityAnswerHash;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String school;
  final String department;

  /// Karşılamada kullanılan ad: "hakan yılmaz" -> "Hakan".
  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty || parts.first.isEmpty ? username : parts.first;
    return trCapitalize(first);
  }

  /// Avatar için baş harfler: "Hakan Yılmaz" -> "HY".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return trUpper(username.isEmpty ? '?' : username.substring(0, 1));
    final letters = parts.length == 1
        ? parts.first.substring(0, 1)
        : parts.first.substring(0, 1) + parts.last.substring(0, 1);
    return trUpper(letters);
  }

  AppUser copyWith({
    String? fullName,
    String? email,
    String? passwordHash,
    String? salt,
    int? iterations,
    DateTime? lastLoginAt,
    String? school,
    String? department,
  }) =>
      AppUser(
        id: id,
        fullName: fullName ?? this.fullName,
        username: username,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        salt: salt ?? this.salt,
        iterations: iterations ?? this.iterations,
        securityQuestion: securityQuestion,
        securityAnswerHash: securityAnswerHash,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        school: school ?? this.school,
        department: department ?? this.department,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'iterations': iterations,
        'securityQuestion': securityQuestion,
        'securityAnswerHash': securityAnswerHash,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'school': school,
        'department': department,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        username: json['username'] as String,
        email: json['email'] as String,
        passwordHash: json['passwordHash'] as String,
        salt: json['salt'] as String,
        iterations: json['iterations'] as int,
        securityQuestion: json['securityQuestion'] as String,
        securityAnswerHash: json['securityAnswerHash'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt:
            json['lastLoginAt'] == null ? null : DateTime.parse(json['lastLoginAt'] as String),
        school: json['school'] as String? ?? '',
        department: json['department'] as String? ?? '',
      );
}
