/*
 * Az alkalmazás állapota: belépés, téma, kezdőadatok, üzenetek.
 *
 * A képernyők az AppScope-on keresztül érik el. A Google azonosító tokent
 * nem menti és nem írja ki nyersen, csak a szervernek küldi el egyszer.
 */
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';

/// Android natív csatorna: a splash a mentett témával induljon.
const _themeChannel = MethodChannel('hu.vzsfoto.teamreg/theme');

/// Háttérfigyelés: ugyanaz az alkalmazás nézi az új flash üzeneteket.
const _watchChannel = MethodChannel('hu.vzsfoto.teamreg/messages');

/// Közös állapot. A notifyListeners rajzolja újra a feliratkozott képernyőket.
class AppModel extends ChangeNotifier {
  AppModel({ApiClient? api, FlutterSecureStorage? storage})
    : _api = api ?? ApiClient(),
      _storage = storage ?? const FlutterSecureStorage() {
    _api.refresh = _refresh;
  }

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  ThemeMode themeMode = ThemeMode.system;

  /// Hamis, amíg a mentett belépés és a téma nincs kész. Addig a splash látszik.
  bool ready = false;

  /// Null, ha nincs belépve.
  UserProfile? user;

  /// A Google-fiók profilképe, ha a szerver nem küld avatárt.
  String? photoUrl;

  /// A szerephez tartozó kezdőlap adatai.
  HomeData? data;
  String? error;
  bool loading = false;

  /// Egyszeri üzenet, például az elutasított jelentkezés szövege.
  String? notice;

  /// A telefonra küldött üzenetek, a legújabb elöl.
  List<FlashNote> flashes = const [];

  /// Üzenetből kért elnöki menüpont. A PresidentHome egyszer elolvassa, aztán törli.
  int? requestedSection;

  int get unreadFlashes => flashes.where((item) => item.unread).length;

  String? _refreshToken;
  DateTime? _accessExpires;
  Future<bool>? _refreshing;

  String? photoFor(String? apiAvatar) {
    return sizedPhoto(apiAvatar ?? photoUrl, 128);
  }

  String? get ownPhoto => sizedPhoto(photoUrl ?? user?.avatar, 256);

  /// Indulás: téma, Google, mentett belépés, majd a kezdőlap.
  Future<void> bootstrap() async {
    await loadTheme();
    await _ensureGoogle();
    final restored = await _restore();
    if (restored && user != null) {
      await loadHome(initial: true);
    }
    ready = true;
    notifyListeners();
  }

  /// Google-belépés. Null a siker és a megszakítás. Szöveg a hiba.
  Future<String?> signInWithGoogle() async {
    if (!await _ensureGoogle()) {
      return 'A telefon Google-belépése ezen a készüléken nem elérhető.';
    }
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      return 'A telefon Google-belépése ezen a készüléken nem elérhető.';
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return 'A Google nem adott azonosító tokent. Ellenőrizd a Google Cloud Android-kliensét.';
      }
      // Csak a token eleje és hossza kerül a naplóba, a nyers token nem.
      debugPrint('Google token: ${_tokenTrace(idToken)}');
      final json = await _api.post('/auth/google.json', {
        'id_token': idToken,
        'device_name': await _deviceName(),
        'platform': _platform(),
      }, false);
      final payload = asMap(json['data']);
      if (payload.isEmpty) {
        debugPrint('Üres belépési válasz: ${json.keys.join(',')}');
        return 'A belépés nem sikerült.';
      }
      await _storeSession(payload, photo: account.photoUrl);
      ready = false;
      notifyListeners();
      await loadHome(initial: true);
      ready = true;
      notifyListeners();
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      debugPrint('Google belépés: ${error.code} ${error.description}');
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        return 'A Google-belépés nincs engedélyezve ezen az alkalmazáson. '
            'A Google Cloudban Android-kliens kell a hu.vzsfoto.teamreg csomaghoz és az aláírás ujjlenyomatához.';
      }
      final description = error.description?.trim();
      if (description != null && description.isNotEmpty) {
        return description;
      }
      return 'A Google-belépés nem sikerült.';
    } on ApiException catch (error) {
      debugPrint('API belépés: ${error.statusCode} ${error.message}');
      return error.message;
    } catch (error) {
      debugPrint('Belépés: $error');
      return 'A belépés nem sikerült. Ellenőrizd a hálózatot.';
    }
  }

  /// Kijelentkezés a szerveren és a telefonon. A téma megmarad.
  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.post('/auth/logout.json', {'refresh_token': refresh}, false);
      }
    } catch (error) {
      debugPrint('Kijelentkezés a szerveren: $error');
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (error) {
      debugPrint('Google kijelentkezés: $error');
    }
    await _clearSession();
    data = null;
    error = null;
    notifyListeners();
  }

  /// A saját fiók és a kapcsolt adatok törlése, utána kijelentkezés.
  Future<void> deleteAccount() async {
    await _api.delete('/users/delete-account.json');
    await logout();
    notice = 'Az adataid törölve lettek.';
    notifyListeners();
  }

  /// Profil mentése. Új tagnál ez küldi el a jelentkezést, és szerepet is válthat.
  Future<UserProfile> saveProfile(Map<String, dynamic> body) async {
    final json = await _api.post('/users/profile.json', body);
    final profile = UserProfile.fromJson(asMap(json['user']));
    user = profile;
    notifyListeners();
    return profile;
  }

  /// Kezdőlap újratöltése. Az [initial] hiba esetén kiüríti a régi adatot.
  Future<void> loadHome({bool initial = false}) async {
    final current = user;
    if (current == null) {
      return;
    }
    loading = true;
    if (initial) {
      error = null;
    }
    notifyListeners();
    try {
      if (current.isNew) {
        final me = await _api.get('/auth/me.json');
        user = UserProfile.fromJson(asMap(me['user']));
        if (user!.isMember) {
          data = await _loadMember();
        } else if (user!.isPresident) {
          data = await _loadPresident();
        } else {
          data = HomeData.empty;
        }
      } else if (current.isMember) {
        data = await _loadMember();
      } else if (current.isPresident) {
        data = await _loadPresident();
      } else {
        data = HomeData.empty;
      }
      error = null;
      _applyOwnAvatar();
    } on ApiException catch (caught) {
      debugPrint(caught.message);
      error = caught.message;
      if (initial) {
        data = null;
      }
      if (caught.statusCode == 401) {
        await _clearSession();
      }
    } catch (caught) {
      debugPrint('$caught');
      error = 'Az adatok nem tölthetők be. Ellenőrizd a hálózatot.';
      if (initial) {
        data = null;
      }
    } finally {
      await _fetchFlashes();
      loading = false;
      notifyListeners();
    }
  }

  /// Üzenetek. A hiba nem töri el a kezdőlap többi adatát.
  Future<void> _fetchFlashes() async {
    if (user == null) {
      flashes = const [];
      return;
    }
    try {
      final json = await _api.get('/flashes.json');
      flashes = asList(json['flashes']).map((item) => FlashNote.fromJson(asMap(item))).toList();
    } catch (error) {
      debugPrint('Flash üzenetek: $error');
    }
  }

  /// Elnöki menüpont kérése üzenetből. 0 jelentkezők, 1 versenyek, 3 nevezők.
  void requestSection(int section) {
    requestedSection = section;
    notifyListeners();
  }

  /// A kért menüpont egyszer olvasható, utána törlődik.
  int? takeSection() {
    final section = requestedSection;
    requestedSection = null;
    return section;
  }

  /// Előtérbe kerüléskor megnézi, változott-e a szerep vagy a tagság.
  Future<void> refreshIdentity() async {
    if (user == null || _refreshToken == null) {
      return;
    }
    try {
      await reloadMe();
    } catch (error) {
      debugPrint('Profil frissítés: $error');
    }
  }

  /// A /auth/me.json frissíti a profilt. Szerepváltáskor a kezdőlapot is újratölti.
  Future<UserProfile> reloadMe() async {
    final me = await _api.get('/auth/me.json');
    final next = UserProfile.fromJson(asMap(me['user']));
    final changed = next.role != user?.role;
    user = next;
    notifyListeners();
    if (changed) {
      await loadHome(initial: true);
    } else {
      await _fetchFlashes();
      notifyListeners();
    }
    return next;
  }

  /// A jobb szélső gomb: a mostani fényerő ellentéte, és el is menti.
  Future<void> toggleTheme(Brightness brightness) async {
    themeMode = brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', themeMode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
    await _publishTheme();
  }

  /// Az egyszeri figyelmeztetés bezárása.
  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  /// Tag kezdőlapja: látható, még nem lezárt versenyek, saját nevezések, névsor.
  Future<HomeData> _loadMember() async {
    final competitionsFuture = _api.pages('/competitions.json', 'competitions');
    final mineFuture = _api.get('/registrations/mine.json');
    final rosterFuture = _api.get('/registrations/roster.json');
    final meFuture = _api.get('/auth/me.json');
    final now = DateTime.now();
    // A lezárt és a még meg nem jelent kiírás itt is kiesik, a szerver frissítése előtt is.
    final competitions = (await competitionsFuture)
        .map(Competition.fromJson)
        .where((row) => row.listedFor(now))
        .toList();
    final mineJson = await mineFuture;
    final rosterJson = await rosterFuture;
    user = UserProfile.fromJson(asMap((await meFuture)['user']));
    final mine = asList(mineJson['registrations'])
        .map((item) => Registration.fromMine(asMap(item), user?.id ?? ''))
        .toList();
    final roster = asList(rosterJson['registrations'])
        .map((item) => RosterLine.fromJson(asMap(item)))
        .toList();
    return HomeData(
      competitions: competitions,
      registrations: mine,
      roster: roster,
      teams: const [],
      applicants: const [],
      members: null,
    );
  }

  /// Elnök és admin: jelentkezők, versenyek, nevezések, csapatok, taglista.
  Future<HomeData> _loadPresident() async {
    final competitionsFuture = _api.pages('/competitions.json', 'competitions');
    final registrationsFuture = _api.pages('/registrations.json', 'registrations');
    final teamsFuture = _api.pages('/teams.json', 'teams');
    final applicantsFuture = _api.get('/applicants.json');
    final membersFuture = _members();
    final mineFuture = _api.get('/registrations/mine.json');
    final meFuture = _api.get('/auth/me.json');
    final now = DateTime.now();
    final competitions = (await competitionsFuture)
        .map(Competition.fromJson)
        .where((row) => !row.hasEnded(now)) // az elnök a jövőbeli megjelenésű kiírást is szerkeszti
        .toList();
    final registrations = (await registrationsFuture).map(Registration.fromJson).toList();
    final teamRows = await teamsFuture;
    final applicantsJson = await applicantsFuture;
    final members = await membersFuture;
    final mineJson = await mineFuture;
    user = UserProfile.fromJson(asMap((await meFuture)['user']));
    final mine = asList(mineJson['registrations'])
        .map((item) => Registration.fromMine(asMap(item), user?.id ?? ''))
        .toList();
    final byId = {for (final row in registrations) row.id: row};
    for (final row in mine) {
      final existing = byId[row.id];
      byId[row.id] = Registration(
        id: row.id,
        userId: user?.id ?? existing?.userId ?? '',
        userName: row.userName.isNotEmpty ? row.userName : (existing?.userName ?? ''),
        avatar: existing?.avatar,
        teamId: row.teamId ?? existing?.teamId,
        teamName: row.teamName.isNotEmpty ? row.teamName : (existing?.teamName ?? ''),
        teamPos: row.teamPos ?? existing?.teamPos,
        competitionId: row.competitionId,
        competitionName: row.competitionName,
        comment: row.comment ?? existing?.comment,
        counts: row.counts,
      );
    }
    final teams = teamRows.map(Team.fromJson).toList()
      ..sort((a, b) {
        final byPos = a.pos.compareTo(b.pos);
        if (byPos != 0) {
          return byPos;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final applicants = asList(applicantsJson['pending'])
        .map((item) => Applicant.fromJson(asMap(item)))
        .toList();
    final avatars = {for (final member in members.members) member.id: member.avatar};
    final withAvatars = byId.values.map((row) {
      final avatar = row.avatar ?? avatars[row.userId];
      if (avatar == row.avatar) {
        return row;
      }
      return Registration(
        id: row.id,
        userId: row.userId,
        userName: row.userName,
        avatar: avatar,
        teamId: row.teamId,
        teamName: row.teamName,
        teamPos: row.teamPos,
        competitionId: row.competitionId,
        competitionName: row.competitionName,
        comment: row.comment,
        counts: row.counts,
      );
    }).toList();
    return HomeData(
      competitions: competitions,
      registrations: withAvatars,
      roster: const [],
      teams: teams,
      applicants: applicants,
      members: members,
    );
  }

  Future<MembersSnapshot> _members() async {
    final first = await _api.get('/members.json?limit=100');
    final snapshot = MembersSnapshot.fromJson(first);
    final pageCount = asInt(asMap(first['paging'])['pageCount'], fallback: 1);
    if (pageCount <= 1) {
      return snapshot;
    }
    final all = [...snapshot.members];
    for (var page = 2; page <= pageCount && page < 20; page++) {
      final json = await _api.get('/members.json?limit=100&page=$page');
      all.addAll(asList(json['members']).map((item) => ClubMember.fromJson(asMap(item))));
    }
    return MembersSnapshot(
      competitionId: snapshot.competitionId,
      competitionName: snapshot.competitionName,
      missing: snapshot.missing,
      members: all,
    );
  }

  void _applyOwnAvatar() {
    final id = user?.id;
    final members = data?.members?.members ?? const <ClubMember>[];
    for (final member in members) {
      if (member.id == id && (photoUrl == null || photoUrl!.isEmpty)) {
        photoUrl = member.avatar;
      }
    }
  }

  /// Mentett téma. Üres értéknél a telefon rendszertémája.
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = switch (prefs.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
    await _publishTheme();
  }

  Future<void> _publishTheme() async {
    final value = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    if (value == null) {
      return;
    }
    try {
      await _themeChannel.invokeMethod<void>('setNightMode', value);
    } catch (error) {
      debugPrint('Téma szinkron: $error');
    }
  }

  Future<bool> _restore() async {
    _refreshToken = await _storage.read(key: 'refresh_token');
    photoUrl = await _storage.read(key: 'photo_url');
    final rawExpiry = await _storage.read(key: 'access_expires');
    final expiry = int.tryParse(rawExpiry ?? '');
    _accessExpires = expiry == null ? null : DateTime.fromMillisecondsSinceEpoch(expiry);
    _api.accessToken = await _storage.read(key: 'access_token');
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      await _syncWatch();
      return false;
    }
    final renewed = await _refresh();
    if (!renewed) {
      await _syncWatch();
      return false;
    }
    if (user == null && !await _loadMe()) {
      await _syncWatch();
      return false;
    }
    await _syncWatch();
    return true;
  }

  Future<bool> _refresh() {
    final pending = _refreshing;
    if (pending != null) {
      return pending;
    }
    final future = _refreshNow();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<bool> _refreshNow() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) {
      return false;
    }
    if (_api.accessToken != null &&
        _accessExpires != null &&
        _accessExpires!.isAfter(DateTime.now().add(const Duration(seconds: 20)))) {
      return true;
    }
    try {
      final json = await _api.post('/auth/refresh.json', {'refresh_token': token}, false);
      final payload = asMap(json['data']);
      if (payload.isEmpty) {
        await _clearSession();
        return false;
      }
      await _storeSession(payload, photo: photoUrl);
      return true;
    } on ApiException catch (error) {
      debugPrint('Token megújítás: ${error.message}');
      await _clearSession();
      return false;
    } catch (error) {
      debugPrint('Token megújítás: $error');
      return _api.accessToken != null && user != null;
    }
  }

  Future<bool> _loadMe() async {
    try {
      final me = await _api.get('/auth/me.json');
      user = UserProfile.fromJson(asMap(me['user']));
      return true;
    } catch (error) {
      debugPrint('Saját profil: $error');
      return false;
    }
  }

  Future<void> _storeSession(Map<String, dynamic> payload, {String? photo}) async {
    final access = asText(payload['access_token']);
    final refresh = asText(payload['refresh_token']);
    final expiresIn = asInt(payload['expires_in'], fallback: 600);
    _api.accessToken = access;
    _refreshToken = refresh;
    _accessExpires = DateTime.now().add(Duration(seconds: expiresIn));
    user = UserProfile.fromJson(asMap(payload['user']));
    if (photo != null && photo.isNotEmpty) {
      photoUrl = photo;
    }
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    await _storage.write(
      key: 'access_expires',
      value: _accessExpires!.millisecondsSinceEpoch.toString(),
    );
    if (photoUrl != null) {
      await _storage.write(key: 'photo_url', value: photoUrl);
    }
    await _syncWatch();
  }

  Future<void> _clearSession() async {
    _api.accessToken = null;
    _refreshToken = null;
    _accessExpires = null;
    user = null;
    photoUrl = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'access_expires');
    await _storage.delete(key: 'photo_url');
    await _syncWatch();
  }

  /// Belépve elindítja a telefonos figyelést, kijelentkezéskor leállítja.
  Future<void> _syncWatch() async {
    try {
      final access = _api.accessToken;
      final refresh = _refreshToken;
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty || user == null) {
        await _watchChannel.invokeMethod<void>('stopWatch');
        return;
      }
      await _watchChannel.invokeMethod<void>('startWatch', {
        'accessToken': access,
        'refreshToken': refresh,
        'baseUrl': ApiConfig.baseUrl,
      });
    } catch (error) {
      debugPrint('Üzenetfigyelés: $error');
    }
  }

  /// Az értesítésből nyitandó flash. Egyszer olvasható.
  Future<FlashNote?> takeNotification() async {
    try {
      final raw = await _watchChannel.invokeMethod<dynamic>('takeOpen');
      if (raw is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(raw);
      final id = asText(map['id']);
      if (id.isEmpty) {
        return null;
      }
      final targetId = asText(map['targetId']);
      return FlashNote(
        id: id,
        subject: asText(map['subject']),
        body: asText(map['body']),
        target: asText(map['target']).isEmpty ? 'message' : asText(map['target']),
        targetId: targetId.isEmpty ? null : targetId,
        seen: null,
        created: null,
      );
    } catch (error) {
      debugPrint('Üzenetnyitás: $error');
      return null;
    }
  }

  /// Új vagy meglévő nevezés. A csapatot csak az elnök küldi, [includeTeam] mellett.
  Future<void> saveRegistration({
    int? id,
    required int competitionId,
    required Map<String, int> counts,
    String? comment,
    int? teamId,
    bool includeTeam = false,
  }) async {
    final body = <String, dynamic>{
      'competition_id': competitionId,
      'comment': (comment == null || comment.trim().isEmpty) ? null : comment.trim(),
      ...counts,
    };
    if (includeTeam) {
      body['team_id'] = teamId;
    }
    if (id == null) {
      await _api.post('/registrations.json', body);
    } else {
      await _api.patch('/registrations/$id.json', body);
    }
    await loadHome();
  }

  /// Nevezés visszavonása a határidő előtt.
  Future<void> withdrawRegistration(int id) async {
    await _api.delete('/registrations/$id.json');
    await loadHome();
  }

  /// Csapatba sorolás. Saját nevezésnél a darabszámok is mennek, hogy ne vesszenek el.
  Future<void> assignTeam(Registration row, int? teamId) async {
    final body = <String, dynamic>{'team_id': teamId};
    if (row.userId == user?.id) {
      body.addAll(row.counts);
      body['comment'] = row.comment;
    }
    await _api.patch('/registrations/${row.id}.json', body);
    await loadHome();
  }

  /// Lezárt versenyek, a legutóbbi versenyidő elöl. 404, amíg a szerver nincs frissítve.
  Future<List<Competition>> loadPastCompetitions() async {
    try {
      final rows = await _api.pages('/competitions/past.json', 'competitions');
      final list = rows.map(Competition.fromJson).toList();
      list.sort((a, b) {
        final left = a.dateCompetition;
        final right = b.dateCompetition;
        if (left == null && right == null) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (left == null) {
          return 1;
        }
        if (right == null) {
          return -1;
        }
        final byDate = right.compareTo(left);
        if (byDate != 0) {
          return byDate;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw ApiException(
          'A korábbi versenyek listája a szerver frissítése után érhető el.',
          statusCode: 404,
        );
      }
      rethrow;
    }
  }

  /// Verseny létrehozása vagy mentése. A leírás helyett az info_url link megy.
  Future<void> saveCompetition(Map<String, dynamic> body, {int? id}) async {
    if (id == null) {
      await _api.post('/competitions.json', body);
    } else {
      await _api.patch('/competitions/$id.json', body);
    }
    await loadHome();
  }

  /// Alcsapat létrehozása vagy átnevezése.
  Future<void> saveTeam({
    int? id,
    required String name,
    required bool visible,
    required int pos,
  }) async {
    final body = {'name': name, 'visible': visible, 'pos': pos};
    if (id == null) {
      await _api.post('/teams.json', body);
    } else {
      await _api.patch('/teams/$id.json', body);
    }
    await loadHome();
  }

  /// Üzenet olvasottnak jelölése. A helyi lista akkor is frissül, ha a szerver még nem tudja.
  Future<void> markFlashSeen(String id) async {
    try {
      await _api.post('/flashes/$id/seen.json');
    } catch (error) {
      debugPrint('Flash olvasott: $error');
    }
    flashes = [
      for (final item in flashes)
        if (item.id == id)
          FlashNote(
            id: item.id,
            subject: item.subject,
            body: item.body,
            target: item.target,
            targetId: item.targetId,
            seen: DateTime.now(),
            created: item.created,
          )
        else
          item,
    ];
    notifyListeners();
  }

  /// Beszélgetések és a választható címzettek.
  Future<MessageDesk> messageDesk() async {
    final json = await _api.get('/messages.json');
    return MessageDesk.fromJson(json);
  }

  /// Egy beszélgetés megnyitása. A [id] a flash target_id értéke.
  Future<MessageThread> messageThread(String id) async {
    final json = await _api.get('/messages/$id.json');
    return MessageThread.fromJson(asMap(json['thread']));
  }

  /// Új üzenet egy tagnak vagy elnöknek. A címzett telefonján flashként jelenik meg.
  Future<void> sendClubMessage({
    required String recipientId,
    required String subject,
    required String body,
  }) async {
    await _api.post('/messages.json', {
      'recipient_id': recipientId,
      'subject': subject,
      'body': body,
    });
  }

  /// Válasz a beszélgetésre. A másik fél telefonjára flashként megy ki.
  Future<void> replyClubMessage(String threadId, String body) async {
    await _api.post('/messages/$threadId/reply.json', {'body': body});
  }

  /// Admin törli egy másik tag fiókját. Saját magát és másik admint a szerver utasítja el.
  Future<void> deleteMember(String id) async {
    await _api.delete('/users/$id.json');
    await loadHome();
  }

  /// Tagból elnök, vagy elnökből tag. Admin és saját fiók nem váltható.
  Future<void> setMemberRole(String id, String role) async {
    await _api.post('/users/$id/role.json', {'role': role});
    await loadHome();
  }

  /// Jelentkező elfogadása. A telefonján member célú üzenet nyitja a tagfelületet.
  Future<void> approveApplicant(String id) async {
    await _api.post('/applicants/$id/approve.json');
    await loadHome();
  }

  /// Jelentkező elutasítása. A telefonján a kezdőlapra vivő üzenet jelenik meg.
  Future<void> denyApplicant(String id) async {
    await _api.post('/applicants/$id/deny.json');
    await loadHome();
  }

  /// Egy tagnak emlékeztető a megadott versenyre. A szöveg a szerver válasza.
  Future<String> remindMember(String id, int competitionId) async {
    final json = await _api.post('/members/$id/remind.json', {'competition_id': competitionId});
    await loadHome();
    final message = asText(json['message']);
    return message.isEmpty ? 'Emlékeztető e-mail kiküldve.' : message;
  }

  /// Emlékeztető mindenkinek, aki a versenyre még nem nevezett.
  Future<String> remindMissing(int competitionId) async {
    final json = await _api.post('/members/remind-missing.json', {
      'competition_id': competitionId,
    });
    await loadHome();
    final message = asText(json['message']);
    return message.isEmpty ? 'Kész.' : message;
  }

  Future<String> _deviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await plugin.androidInfo;
          return '${info.brand} ${info.model}'.trim();
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          return info.name;
        default:
          return defaultTargetPlatform.name;
      }
    } catch (_) {
      return defaultTargetPlatform.name;
    }
  }

  String _platform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return defaultTargetPlatform.name;
    }
  }
}

/// Naplóhoz a token közönsége és kiállítója, a token és az e-mail nélkül.
String _tokenTrace(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length < 2) {
      return 'hibás formátum';
    }
    final map = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (map is! Map) {
      return 'nem objektum';
    }
    return 'aud=${map['aud']} azp=${map['azp']} iss=${map['iss']} '
        'email_verified=${map['email_verified']} has_email=${map['email'] != null} exp=${map['exp']}';
  } catch (error) {
    return 'nem olvasható: $error';
  }
}

bool _googleReady = false;

/// A Google belépés egyszer áll be, a webes kliens azonosítójával.
Future<bool> _ensureGoogle() async {
  if (_googleReady) {
    return true;
  }
  try {
    await GoogleSignIn.instance.initialize(serverClientId: ApiConfig.googleServerClientId);
    _googleReady = true;
    return true;
  } catch (error) {
    debugPrint('Google inicializálás: $error');
    return false;
  }
}
