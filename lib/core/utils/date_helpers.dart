/// Date helpers mirroring the reference prototype's real-date behaviour.
library;

const monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const monthFull = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const weekdayShort = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayFull = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

// The prototype's arrays start on Sunday: WD[getDay()], WDF[getDay()].
const weekdayShortSun = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];
const weekdayFullSun = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime today() => dateOnly(DateTime.now());

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int daysLeftInMonth([DateTime? now]) {
  final n = now ?? DateTime.now();
  return daysInMonth(n.year, n.month) - n.day + 1;
}

DateTime monthStart(DateTime date) => DateTime(date.year, date.month, 1);

DateTime addMonths(DateTime anchor, int delta) =>
    DateTime(anchor.year, anchor.month + delta, 1);

DateTime monthAgo(int monthsBack, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month - monthsBack, 1);
}

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

bool isCurrentMonth(DateTime date, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return date.year == n.year && date.month == n.month;
}

String monthYear(DateTime date) => '${monthFull[date.month - 1]} ${date.year}';

String monthShortYear(DateTime date) =>
    '${monthShort[date.month - 1]} ${date.year}';

String dayMonth(DateTime date) => '${date.day} ${monthShort[date.month - 1]}';

String shortDate(DateTime date) =>
    '${date.day} ${monthShort[date.month - 1]} ${date.year}';

String longDate(DateTime date) =>
    '${weekdayFullSun[date.weekday % 7]}, ${date.day} ${monthFull[date.month - 1]}';

/// "3:42 PM" in the device's local time.
String clockTime(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today", "Yesterday", "Mon 9 Nov"
String dayLabel(DateTime date, {DateTime? now}) {
  final n = todayFrom(now);
  final d = dateOnly(date);
  final diff = n.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${weekdayShortSun[date.weekday % 7]} ${date.day} ${monthShort[date.month - 1]}';
}

DateTime todayFrom(DateTime? now) => dateOnly(now ?? DateTime.now());

String relativeDaysLabel(int days) {
  if (days < 0) return '${-days} days late';
  if (days == 0) return 'Due today';
  if (days == 1) return 'In 1 day';
  return 'In $days days';
}

/// Next occurrence of a day-of-month, matching the prototype's `nextDue`.
DateTime nextDue(int day, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = DateTime(n.year, n.month, day);
  if (d.isBefore(dateOnly(n))) return DateTime(n.year, n.month + 1, day);
  return d;
}

int daysUntil(DateTime date, {DateTime? now}) =>
    dateOnly(date).difference(todayFrom(now)).inDays;

String timeGreeting({DateTime? now}) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'morning';
  if (h < 17) return 'afternoon';
  return 'evening';
}

/// Format used inside statement ranges: "23 Sep – 22 Oct".
String rangeLabel(DateTime start, DateTime end) =>
    '${start.day} ${monthShort[start.month - 1]} – ${end.day} ${monthShort[end.month - 1]}';

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? parseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day, 12);
}
