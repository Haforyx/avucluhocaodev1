import 'package:intl/intl.dart';

import '../services/study_stats.dart';

/// Günün saatine göre selam.
String timeGreeting(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) return 'Günaydın';
  if (h >= 12 && h < 18) return 'İyi günler';
  if (h >= 18 && h < 23) return 'İyi akşamlar';
  return 'İyi geceler';
}

/// 95 -> "1 sa 35 dk", 40 -> "40 dk", 120 -> "2 sa".
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes dk';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h sa' : '$h sa $m dk';
}

/// Grafik eksenleri için kısa biçim: 95 -> "1,6 sa", 40 -> "40 dk".
String formatMinutesShort(num minutes) {
  if (minutes < 60) return '${minutes.round()} dk';
  final hours = minutes / 60;
  if (hours == hours.roundToDouble() || hours >= 10) return '${hours.round()} sa';
  return '${formatNumber(hours, 1)} sa';
}

/// Sayaç gösterimi: 24:59
String formatClock(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Türkçe ondalık: 3.456 -> "3,46"
String formatNumber(num value, [int digits = 2]) =>
    NumberFormat.decimalPatternDigits(locale: 'tr_TR', decimalDigits: digits).format(value);

/// Not gösterimi: 72.0 -> "72", 72.5 -> "72,5", 71.25 -> "71,3"
String formatScore(double value) => NumberFormat('0.#', 'tr_TR').format(value);

String formatDateLong(DateTime d) => DateFormat('d MMMM EEEE', 'tr_TR').format(d);

String formatDate(DateTime d) => DateFormat('d MMMM y', 'tr_TR').format(d);

String formatDateShort(DateTime d) => DateFormat('d MMM', 'tr_TR').format(d);

String formatTime(DateTime d) => DateFormat('HH:mm', 'tr_TR').format(d);

String formatWeekdayShort(DateTime d) => DateFormat('E', 'tr_TR').format(d);

/// Teslim tarihini insan diliyle anlatır: "Bugün 17:00", "Yarın 23:59",
/// "Cuma 12:00", "3 gün gecikti"...
String formatDue(DateTime due, DateTime now) {
  final days = dateOnly(due).difference(dateOnly(now)).inDays;
  final time = formatTime(due);
  final showTime = !(due.hour == 23 && due.minute == 59);
  final suffix = showTime ? ' $time' : '';
  if (days == 0) return 'Bugün$suffix';
  if (days == 1) return 'Yarın$suffix';
  if (days == -1) return 'Dün$suffix';
  if (days < -1) return '${-days} gün gecikti';
  if (days < 7) return '${DateFormat('EEEE', 'tr_TR').format(due)}$suffix';
  return '${formatDateShort(due)}$suffix';
}

/// "3 gün kaldı", "Bugün", "Yarın"
String formatCountdown(DateTime due, DateTime now) {
  final days = dateOnly(due).difference(dateOnly(now)).inDays;
  if (days < 0) return '${-days} gün geçti';
  if (days == 0) return 'Bugün';
  if (days == 1) return 'Yarın';
  return '$days gün kaldı';
}
