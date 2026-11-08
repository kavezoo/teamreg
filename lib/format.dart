const titledCounts = <String, String>{
  'lunch_title': 'lunch_count',
  'special_lunch_title': 'extra_lunch_count',
  'competition_pipe_title_1': 'competition_pipe_1',
  'competition_pipe_title_2': 'competition_pipe_2',
  'competition_pipe_title_3': 'competition_pipe_3',
  'extra_title_1': 'extra_count_1',
  'extra_title_2': 'extra_count_2',
  'extra_title_3': 'extra_count_3',
};

const titleDefaults = <String, String>{
  'lunch_title': 'Kísérő ebéd igény',
  'special_lunch_title': 'Extra ebéd igény',
  'competition_pipe_title_1': 'Világos versenypipa igény',
  'competition_pipe_title_2': 'Sötét versenypipa igény',
  'extra_title_1': 'Extra ebéd igény (érzékenység)',
};

const deniedNotice =
    'A klubelnök elutasította a jelentkezésedet. Kijelentkeztetünk. '
    'Ha később mégis tag szeretnél lenni, jelentkezz be újra ugyanazzal a Google-fiókkal, '
    'és mentsd el a profilodat. A mentés újra elküldi a jelentkezést a klubelnöknek.';

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value == null) {
    return fallback;
  }
  return int.tryParse(value.toString()) ?? fallback;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final text = value.toLowerCase();
    if (text == '1' || text == 'true') {
      return true;
    }
    if (text == '0' || text == 'false' || text.isEmpty) {
      return false;
    }
  }
  return fallback;
}

String asText(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

List<dynamic> asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

DateTime? asDate(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

String formatDate(DateTime? value) {
  if (value == null) {
    return 'nincs megadva';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}. $month. $day.';
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'nincs megadva';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)} $hour:$minute';
}

String? apiDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String? apiDateTime(DateTime? value) {
  if (value == null) {
    return null;
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${apiDate(local)} $hour:$minute:00';
}

/// A határidő napja még nyitott. Csak a korábbi nap számít lezártnak.
bool registrationClosed(DateTime? deadline, [DateTime? now]) {
  if (deadline == null) {
    return false;
  }
  final clock = (now ?? DateTime.now()).toLocal();
  final today = DateTime(clock.year, clock.month, clock.day);
  final local = deadline.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return day.isBefore(today);
}

/// Besoroltak a csoport sorrendjében, azon belül név szerint. A besorolatlanok a végére kerülnek.
int compareByAssignment({
  required String name,
  required String team,
  int? teamPos,
  required String otherName,
  required String otherTeam,
  int? otherTeamPos,
}) {
  final assigned = team.trim().isNotEmpty;
  final otherAssigned = otherTeam.trim().isNotEmpty;
  if (assigned != otherAssigned) {
    return assigned ? -1 : 1;
  }
  final pos = assigned ? (teamPos ?? 0) : 1 << 30;
  final otherPos = otherAssigned ? (otherTeamPos ?? 0) : 1 << 30;
  final byPos = pos.compareTo(otherPos);
  if (byPos != 0) {
    return byPos;
  }
  final byTeam = team.toLowerCase().compareTo(otherTeam.toLowerCase());
  if (byTeam != 0) {
    return byTeam;
  }
  return name.toLowerCase().compareTo(otherName.toLowerCase());
}

String plainText(String? html) {
  if (html == null || html.trim().isEmpty) {
    return '';
  }
  final withBreaks = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</h[1-6]>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</tr>', caseSensitive: false), '\n');
  final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
  final decoded = stripped
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return decoded.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String? sizedPhoto(String? url, int size) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  final source = url.trim();
  if (RegExp(r'=s\d+').hasMatch(source)) {
    return source.replaceFirst(RegExp(r'=s\d+(-[a-z])?'), '=s$size-c');
  }
  if (!source.contains('?')) {
    return '$source=s$size-c';
  }
  return source;
}

/// A térkép címéből a navigáció célja. A teljes link marad, ha nincs külön hely.
String mapDestination(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    return url.trim();
  }
  final query = uri.queryParameters['destination'] ??
      uri.queryParameters['daddr'] ??
      uri.queryParameters['q'] ??
      uri.queryParameters['query'];
  if (query != null && query.trim().isNotEmpty) {
    return query.trim();
  }
  final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (at != null) {
    return '${at.group(1)},${at.group(2)}';
  }
  final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (pin != null) {
    return '${pin.group(1)},${pin.group(2)}';
  }
  final place = RegExp(r'/place/([^/]+)').firstMatch(uri.path);
  if (place != null) {
    return Uri.decodeComponent(place.group(1)!.replaceAll('+', ' '));
  }
  return url.trim();
}

bool httpUrl(String value) {
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(value.trim());
}
