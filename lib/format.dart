/*
 * JSON-olvasók, dátumformák és a névsor rendezése.
 *
 * A verseny űrlapján a címmező (lunch_title) és a darabszám (lunch_count)
 * párosban jár. A megjelenített dátum magyar (2026. 11. 08.),
 * az API felé küldött pedig 2026-11-08.
 */

/// Kiírás címe → a nevezésben tárolt darabszám mezője.
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

/// Új verseny alap címei, ha az elnök nem ír mást.
const titleDefaults = <String, String>{
  'lunch_title': 'Kísérő ebéd igény',
  'special_lunch_title': 'Extra ebéd igény',
  'competition_pipe_title_1': 'Világos versenypipa igény',
  'competition_pipe_title_2': 'Sötét versenypipa igény',
  'extra_title_1': 'Extra ebéd igény (érzékenység)',
};

/// Elutasított új tag kijelentkeztető szövege.
const deniedNotice =
    'A klubelnök elutasította a jelentkezésedet. Kijelentkeztetünk. '
    'Ha később mégis tag szeretnél lenni, jelentkezz be újra ugyanazzal a Google-fiókkal, '
    'és mentsd el a profilodat. A mentés újra elküldi a jelentkezést a klubelnöknek.';

/// API-szám: int, num vagy szám-szöveg. Hibás értéknél [fallback].
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

/// API-logikai: true/false, 1/0, illetve a „true” és „false” szöveg.
String absenceLabel(String prefix, String? reason) {
  final text = (reason ?? '').trim();
  return text.isEmpty ? prefix : '$prefix: $text';
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

/// Nullából üres szöveg, minden másból a toString értéke.
String asText(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

/// Beágyazott JSON-objektum. Más típusnál üres map.
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return {};
}

/// JSON-tömb. Ha nem lista jött, üres lista.
List<dynamic> asList(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

/// „2026-11-08” és „2026-11-08 18:00:00” is DateTime lesz. Üresnél null.
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

/// Képernyőre: 2026. 11. 08. Üresnél „nincs megadva”.
String formatDate(DateTime? value) {
  if (value == null) {
    return 'nincs megadva';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}. $month. $day.';
}

/// Képernyőre, órával: 2026. 11. 08. 18:00
String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'nincs megadva';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${formatDate(local)} $hour:$minute';
}

/// Csevegő napelválasztó: ma csak idő, másnap dátummal.
String formatChatDay(DateTime value, [DateTime? now]) {
  final local = value.toLocal();
  final clock = (now ?? DateTime.now()).toLocal();
  final today = DateTime(clock.year, clock.month, clock.day);
  final day = DateTime(local.year, local.month, local.day);
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final time = '$hour:$minute';
  if (day == today) {
    return time;
  }
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Tegnap $time';
  }
  return '${formatDate(local)} $time';
}

/// API-nak küldött nap: 2026-11-08
String? apiDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

/// API-nak küldött időpont, másodperccel: 2026-11-08 18:00:00
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
  // Besorolatlan a lista végére kerül, a csoportok a pos szerint állnak.
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

/// Régi HTML-leírásból olvasható szöveg. A sortörő címkéket megtartja.
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

/// Google-profilkép kért méretben. A =s96 végét =s128-c-re cseréli.
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
  // Google Maps @lat,lng vagy a !3dlat!4dlng pin.
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

/// Csak http és https cím nyitható böngészőben vagy térképen.
bool httpUrl(String value) {
  return RegExp(r'^https?://', caseSensitive: false).hasMatch(value.trim());
}
