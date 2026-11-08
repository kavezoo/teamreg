/*
 * A szerver JSON-jából készült adatmodellek.
 *
 * A szerepek: new, member, president, admin. A CakeDC „user” szerepe is új tagnak számít.
 * A first_name a vezetéknév, a last_name a keresztnév.
 */
import 'format.dart';

/// Belépett felhasználó. A kezdőképernyőt a [role] választja.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.role,
    required this.membershipRequest,
    required this.profileSaved,
    required this.enabled,
    required this.mail,
    required this.mailChoices,
    required this.flash,
    required this.flashChoices,
    this.avatar,
    this.tosDate,
  });

  final String id;
  final String username;
  final String email;

  /// Vezetéknév. A mező neve a szerveren first_name.
  final String firstName;

  /// Keresztnév. A mező neve a szerveren last_name.
  final String lastName;

  /// Megjelenő név. Ha üres, a vezetéknév és a keresztnév, majd az e-mail.
  final String name;

  /// new, member, president vagy admin. Ismeretlen érték új tagnak számít.
  final String role;

  /// null, pending vagy denied. A pending az elbírálásra váró jelentkezés.
  final String? membershipRequest;

  /// A profil legalább egyszer el lett mentve, azzal indul a jelentkezés.
  final bool profileSaved;

  /// A klubelnök letilthatja a belépést.
  final bool enabled;
  /// Melyik e-mail-fajtát kéri a tag. A kulcs a szerver mail-kódja.
  final Map<String, bool> mail;

  /// A kapcsolók felirata, a szerver szövegével.
  final Map<String, String> mailChoices;

  /// Melyik telefonos üzenetet kéri. A kulcs a szerver flash-kódja.
  final Map<String, bool> flash;

  /// A telefonos kapcsolók felirata.
  final Map<String, String> flashChoices;
  final String? avatar;

  /// Az adatkezelési nyilatkozat elfogadásának ideje. Nullánál még nincs elfogadva.
  final DateTime? tosDate;

  /// Tag, elnök és admin kívül mindenki új jelentkező, a CakeDC „user” szerepe is.
  bool get isNew => role != 'member' && role != 'president' && role != 'admin';
  bool get privacyAccepted => tosDate != null;
  bool get isMember => role == 'member';
  bool get isPresident => role == 'president' || role == 'admin';
  bool get denied => membershipRequest == 'denied';

  String get roleLabel {
    switch (role) {
      case 'member':
        return 'Tag';
      case 'president':
        return 'Klubelnök';
      case 'admin':
        return 'Admin';
      default:
        return 'Új tag';
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final mail = <String, bool>{};
    for (final entry in asMap(json['mail']).entries) {
      mail[entry.key] = asBool(entry.value, fallback: true);
    }
    final choices = <String, String>{};
    for (final entry in asMap(json['mail_choices']).entries) {
      choices[entry.key] = asText(entry.value);
    }
    final flash = <String, bool>{};
    for (final entry in asMap(json['flash']).entries) {
      flash[entry.key] = asBool(entry.value, fallback: true);
    }
    final flashChoices = <String, String>{};
    for (final entry in asMap(json['flash_choices']).entries) {
      flashChoices[entry.key] = asText(entry.value);
    }
    final avatar = asText(json['avatar']);
    return UserProfile(
      id: asText(json['id']),
      username: asText(json['username']),
      email: asText(json['email']),
      firstName: asText(json['first_name']),
      lastName: asText(json['last_name']),
      name: asText(json['name']).isEmpty ? displayName(json) : asText(json['name']),
      role: asText(json['role']),
      membershipRequest: _nullable(json['membership_request']),
      profileSaved: asBool(json['profile_saved']),
      enabled: asBool(json['enabled'], fallback: true),
      mail: mail,
      mailChoices: choices,
      flash: flash,
      flashChoices: flashChoices,
      avatar: avatar.isEmpty ? null : avatar,
      tosDate: asDate(json['tos_date']),
    );
  }
}

/// Kiírt verseny. A leírás HTML helyett a [infoUrl] pipaclub.hu linkje számít.
class Competition {
  const Competition({
    required this.id,
    required this.name,
    required this.comment,
    required this.description,
    this.descriptionHtml = '',
    this.infoUrl,
    required this.mapUrl,
    required this.dateCompetition,
    required this.dateFrom,
    required this.dateDeadline,
    required this.visible,
    required this.pos,
    required this.created,
    required this.titles,
  });

  final int id;
  final String name;
  final String comment;

  /// Régi HTML-leírás. Megjelenítésre már a [infoLink] szolgál.
  final String description;
  final String descriptionHtml;

  /// A pipaclub.hu-n közzétett versenykiírás címe.
  final String? infoUrl;

  /// Helyszín, Google Maps vagy más http(s) link.
  final String? mapUrl;

  /// A verseny kezdete. Ha ez elmúlt, a kiírás a korábbi versenyek közé kerül.
  final DateTime? dateCompetition;

  /// Megjelenés a listában: a tag ettől a naptól látja a kiírást.
  final DateTime? dateFrom;

  /// Jelentkezési határidő. A határidő napja még nyitott.
  final DateTime? dateDeadline;

  /// Bekapcsolva a tag jelentkezhet. Kikapcsolva csak az elnök látja szerkesztésre.
  final bool visible;
  final int pos;
  final DateTime? created;
  final Map<String, String> titles;

  bool get closed => registrationClosed(dateDeadline);

  bool get canSignUp => visible && !closed;

  String? get openableMap {
    final url = mapUrl?.trim() ?? '';
    if (!httpUrl(url)) {
      return null;
    }
    return url;
  }

  String title(String field) => (titles[field] ?? '').trim();

  /// A pipaclub.hu-n lévő leírás címe. A régi, önmagában álló webcím is megfelel.
  String? get infoLink {
    final saved = (infoUrl ?? '').trim();
    if (httpUrl(saved)) {
      return saved;
    }
    final plain = description.trim();
    if (httpUrl(plain) && !plain.contains(RegExp(r'\s')) && !plain.contains('<')) {
      return plain;
    }
    return null;
  }

  /// A versenyidő elmúlt. Időpont nélkül a kiírás még aktuális.
  bool hasEnded(DateTime now) {
    final when = dateCompetition?.toLocal();
    if (when == null) {
      return false;
    }
    return when.isBefore(now);
  }

  /// A tag a megjelenés napjától látja, amíg a versenyidő el nem múlt.
  bool listedFor(DateTime now) {
    if (hasEnded(now)) {
      return false;
    }
    final from = dateFrom?.toLocal();
    if (from == null) {
      return true;
    }
    final start = DateTime(from.year, from.month, from.day);
    final today = DateTime(now.year, now.month, now.day);
    return !start.isAfter(today);
  }

  /// A webes leírásszűrő eredménye, ha az API küldi. Különben a tárolt HTML.
  String get renderedDescription {
    final safe = descriptionHtml.trim();
    if (safe.isNotEmpty) {
      return safe;
    }
    return description.trim();
  }

  factory Competition.fromJson(Map<String, dynamic> json) {
    final titles = <String, String>{};
    for (final field in titledCounts.keys) {
      titles[field] = asText(json[field]);
    }
    final map = asText(json['map_url']);
    return Competition(
      id: asInt(json['id']),
      name: asText(json['name']),
      comment: asText(json['comment']),
      description: asText(json['description']),
      descriptionHtml: asText(json['description_html']),
      infoUrl: asText(json['info_url']).trim().isEmpty ? null : asText(json['info_url']).trim(),
      mapUrl: map.isEmpty ? null : map,
      dateCompetition: asDate(json['date_competition']),
      dateFrom: asDate(json['date_from']),
      dateDeadline: asDate(json['date_deadline']),
      visible: asBool(json['visible']),
      pos: asInt(json['pos']),
      created: asDate(json['created']),
      titles: titles,
    );
  }

  Competition copyWithTitles(Map<String, String> next) {
    return Competition(
      id: id,
      name: name,
      comment: comment,
      description: description,
      descriptionHtml: descriptionHtml,
      infoUrl: infoUrl,
      mapUrl: mapUrl,
      dateCompetition: dateCompetition,
      dateFrom: dateFrom,
      dateDeadline: dateDeadline,
      visible: visible,
      pos: pos,
      created: created,
      titles: next,
    );
  }
}

/// Egy tag nevezése egy versenyre, a kért darabszámokkal és a csapatával.
class Registration {
  const Registration({
    required this.id,
    required this.userId,
    required this.userName,
    required this.avatar,
    required this.teamId,
    required this.teamName,
    required this.teamPos,
    required this.competitionId,
    required this.competitionName,
    required this.comment,
    required this.counts,
    this.absent = false,
    this.absentReason,
  });

  final int id;
  final String userId;
  final String userName;
  final String? avatar;
  final int? teamId;
  final String teamName;
  final int? teamPos;
  final int competitionId;
  final String competitionName;
  final String? comment;
  final Map<String, int> counts;
  final bool absent;
  final String? absentReason;

  int count(String field) => counts[field] ?? 0;

  factory Registration.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    final team = asMap(json['team']);
    final competition = asMap(json['competition']);
    final counts = <String, int>{};
    for (final field in titledCounts.values) {
      counts[field] = asInt(json[field]);
    }
    final avatar = asText(user['avatar']);
    final teamId = json['team_id'];
    final rawUserId = asText(json['user_id']);
    final teamName = asText(team['name']);
    return Registration(
      id: asInt(json['id']),
      userId: rawUserId.isEmpty || rawUserId == 'null' ? asText(user['id']) : rawUserId,
      userName: displayName(user),
      avatar: avatar.isEmpty ? null : avatar,
      teamId: teamId == null || asText(teamId).isEmpty ? null : asInt(teamId),
      teamName: teamName,
      teamPos: teamName.trim().isEmpty || team['pos'] == null ? null : asInt(team['pos']),
      competitionId: asInt(json['competition_id'] ?? competition['id']),
      competitionName: asText(competition['name']),
      comment: _nullable(json['comment']),
      counts: counts,
      absent: asBool(json['absent']),
      absentReason: _nullable(json['absent_reason']),
    );
  }

  factory Registration.fromMine(Map<String, dynamic> json, String userId) {
    final counts = <String, int>{};
    for (final field in titledCounts.values) {
      counts[field] = asInt(json[field]);
    }
    final teamId = json['team_id'];
    return Registration(
      id: asInt(json['id']),
      userId: userId,
      userName: asText(json['name']),
      avatar: null,
      teamId: teamId == null || asText(teamId).isEmpty ? null : asInt(teamId),
      teamName: asText(json['team']),
      teamPos: json['team_pos'] == null ? null : asInt(json['team_pos']),
      competitionId: asInt(json['competition_id']),
      competitionName: asText(json['competition']),
      comment: _nullable(json['comment']),
      counts: counts,
      absent: asBool(json['absent']),
      absentReason: _nullable(json['absent_reason']),
    );
  }
}

/// A tagoknak szóló névsor egy sora: név, csapat, verseny.
class RosterLine {
  const RosterLine({
    required this.userId,
    required this.name,
    required this.team,
    required this.competition,
    required this.avatar,
    required this.teamPos,
    this.absent = false,
    this.absentReason,
  });

  final String userId;
  final String name;
  final String team;
  final String competition;
  final String? avatar;
  final int? teamPos;
  final bool absent;
  final String? absentReason;

  factory RosterLine.fromJson(Map<String, dynamic> json) {
    final avatar = asText(json['avatar']);
    return RosterLine(
      userId: asText(json['user_id']),
      name: asText(json['name']),
      team: asText(json['team']),
      competition: asText(json['competition']),
      avatar: avatar.isEmpty ? null : avatar,
      teamPos: json['team_pos'] == null ? null : asInt(json['team_pos']),
      absent: asBool(json['absent']),
      absentReason: _nullable(json['absent_reason']),
    );
  }
}

/// Alcsapat. A [pos] a névsor csoportjainak sorrendje.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.visible,
    required this.pos,
  });

  final int id;
  final String name;
  final bool visible;
  final int pos;

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: asInt(json['id']),
      name: asText(json['name']),
      visible: asBool(json['visible']),
      pos: asInt(json['pos']),
    );
  }
}

/// Elbírálásra váró új tag. Az elnök engedélyezi vagy elutasítja.
class Applicant {
  const Applicant({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.membershipRequest,
  });

  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? membershipRequest;

  factory Applicant.fromJson(Map<String, dynamic> json) {
    final avatar = asText(json['avatar']);
    return Applicant(
      id: asText(json['id']),
      name: asText(json['name']),
      email: asText(json['email']),
      avatar: avatar.isEmpty ? null : avatar,
      membershipRequest: _nullable(json['membership_request']),
    );
  }
}

/// Tag vagy elnök a szervezői listán, a legközelebbi verseny nevezésével.
class ClubMember {
  const ClubMember({
    required this.id,
    required this.name,
    required this.email,
    required this.avatar,
    required this.role,
    required this.registered,
    required this.team,
    required this.remindedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String role;
  final bool registered;
  final String? team;
  final String? remindedAt;

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    final avatar = asText(json['avatar']);
    return ClubMember(
      id: asText(json['id']),
      name: asText(json['name']),
      email: asText(json['email']),
      avatar: avatar.isEmpty ? null : avatar,
      role: asText(json['role']),
      registered: asBool(json['registered']),
      team: _nullable(json['team']),
      remindedAt: _nullable(json['reminded_at']),
    );
  }
}

/// A taglista egy versenyhez kötve: ki nevezett, ki hiányzik, kinek ment emlékeztető.
class MembersSnapshot {
  const MembersSnapshot({
    required this.competitionId,
    required this.competitionName,
    required this.missing,
    required this.members,
  });

  final int? competitionId;
  final String? competitionName;
  final int missing;
  final List<ClubMember> members;

  bool get canRemind => competitionId != null;

  factory MembersSnapshot.fromJson(Map<String, dynamic> json) {
    final competition = asMap(json['competition']);
    final id = competition.isEmpty ? null : asInt(competition['id']);
    return MembersSnapshot(
      competitionId: id == null || id == 0 ? null : id,
      competitionName: competition.isEmpty ? null : asText(competition['name']),
      missing: asInt(json['missing']),
      members: asList(json['members'])
          .map((item) => ClubMember.fromJson(asMap(item)))
          .toList(),
    );
  }
}

/// A kezdőképernyő egyben letöltött adatai. Szerepenként más mezők telnek meg.
class HomeData {
  const HomeData({
    required this.competitions,
    required this.registrations,
    required this.roster,
    required this.teams,
    required this.applicants,
    required this.members,
  });

  final List<Competition> competitions;
  final List<Registration> registrations;
  final List<RosterLine> roster;
  final List<Team> teams;
  final List<Applicant> applicants;
  final MembersSnapshot? members;

  static const empty = HomeData(
    competitions: [],
    registrations: [],
    roster: [],
    teams: [],
    applicants: [],
    members: null,
  );
}

/// Vezetéknév és keresztnév. Ha nincs név, az e-mail, végül a felhasználónév.
String displayName(Map<String, dynamic> user) {
  if (user.isEmpty) {
    return '';
  }
  final name = '${asText(user['first_name'])} ${asText(user['last_name'])}'.trim();
  if (name.isNotEmpty) {
    return name;
  }
  final email = asText(user['email']);
  if (email.isNotEmpty) {
    return email;
  }
  return asText(user['username']);
}

String? _nullable(dynamic value) {
  final text = asText(value).trim();
  if (text.isEmpty || text == 'null') {
    return null;
  }
  return text;
}

/*
 * Telefonos üzenet. A [target] mondja meg, hova visz a koppintás:
 * member, registration, roster, competition, applicants, profile, message, home.
 */
class FlashNote {
  const FlashNote({
    required this.id,
    required this.subject,
    required this.body,
    required this.target,
    required this.targetId,
    required this.seen,
    required this.created,
  });

  final String id;
  final String subject;
  final String body;
  final String target;
  final String? targetId;
  final DateTime? seen;
  final DateTime? created;

  bool get unread => seen == null;

  factory FlashNote.fromJson(Map<String, dynamic> json) {
    return FlashNote(
      id: asText(json['id']),
      subject: asText(json['subject']),
      body: asText(json['body']),
      target: asText(json['target']).isEmpty ? 'home' : asText(json['target']),
      targetId: _nullable(json['target_id']),
      seen: asDate(json['seen']),
      created: asDate(json['created']),
    );
  }
}

/// Beszélgetés a listában. Az [id] a szál, erre visz a flash koppintása.
class MessagePreview {
  const MessagePreview({
    required this.id,
    required this.subject,
    required this.peerName,
    required this.lastBody,
    required this.lastAt,
    required this.mineLast,
  });

  final String id;
  final String subject;
  final String peerName;
  final String lastBody;
  final String lastAt;
  final bool mineLast;

  factory MessagePreview.fromJson(Map<String, dynamic> json) {
    return MessagePreview(
      id: asText(json['id']),
      subject: asText(json['subject']),
      peerName: asText(json['peer_name']),
      lastBody: asText(json['last_body']),
      lastAt: asText(json['last_at']),
      mineLast: asBool(json['mine_last']),
    );
  }
}

/// Akinek üzenetet lehet küldeni.
class MessagePeer {
  const MessagePeer({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  String get label {
    switch (role) {
      case 'president':
        return '$name (elnök)';
      case 'admin':
        return '$name (admin)';
      default:
        return name;
    }
  }

  factory MessagePeer.fromJson(Map<String, dynamic> json) {
    return MessagePeer(
      id: asText(json['id']),
      name: asText(json['name']),
      role: asText(json['role']),
    );
  }
}

/// A beszélgetések és a választható címzettek.
class MessageDesk {
  const MessageDesk({required this.threads, required this.recipients, this.notice});

  final List<MessagePreview> threads;
  final List<MessagePeer> recipients;

  /// A beszélgetéslista hibája. A címzettek ettől még megérkezhetnek.
  final String? notice;

  factory MessageDesk.fromJson(Map<String, dynamic> json) {
    final notice = asText(json['notice']);
    return MessageDesk(
      threads: [
        for (final item in asList(json['threads']))
          if (item is Map) MessagePreview.fromJson(asMap(item)),
      ],
      recipients: [
        for (final item in asList(json['recipients']))
          if (item is Map) MessagePeer.fromJson(asMap(item)),
      ],
      notice: notice.isEmpty ? null : notice,
    );
  }
}

/// Egy sor a beszélgetésben.
class MessagePost {
  const MessagePost({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.body,
    required this.mine,
    required this.created,
    required this.when,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String body;
  final bool mine;
  final String created;
  final DateTime? when;

  factory MessagePost.fromJson(Map<String, dynamic> json) {
    final created = asText(json['created']);
    return MessagePost(
      id: asText(json['id']),
      senderId: asText(json['sender_id']),
      senderName: asText(json['sender_name']),
      senderAvatar: _nullable(json['sender_avatar']),
      body: asText(json['body']),
      mine: asBool(json['mine']),
      created: created,
      when: asDate(created),
    );
  }
}

/// A megnyitott beszélgetés, a válaszokkal.
class MessageThread {
  const MessageThread({
    required this.id,
    required this.subject,
    required this.peerName,
    required this.peerAvatar,
    required this.posts,
  });

  final String id;
  final String subject;
  final String peerName;
  final String? peerAvatar;
  final List<MessagePost> posts;

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      id: asText(json['id']),
      subject: asText(json['subject']),
      peerName: asText(json['peer_name']),
      peerAvatar: _nullable(json['peer_avatar']),
      posts: [
        for (final item in asList(json['posts']))
          if (item is Map) MessagePost.fromJson(asMap(item)),
      ],
    );
  }
}

/// A legközelebbi látható, még el nem múlt verseny. A tesztek ezt használják.
Competition? currentRosterCompetition(List<Competition> competitions, [DateTime? now]) {
  final clock = now ?? DateTime.now();
  Competition? current;
  for (final candidate in competitions) {
    if (!candidate.visible) {
      continue;
    }
    final when = candidate.dateCompetition;
    if (when != null && when.isBefore(clock)) {
      continue;
    }
    current = _sooner(current, candidate);
  }
  return current;
}

Competition _sooner(Competition? current, Competition candidate) {
  if (current == null) {
    return candidate;
  }
  final currentWhen = current.dateCompetition;
  final candidateWhen = candidate.dateCompetition;
  if (candidateWhen != null && (currentWhen == null || candidateWhen.isBefore(currentWhen))) {
    return candidate;
  }
  if (candidateWhen == null && currentWhen == null) {
    final currentCreated = current.created;
    final candidateCreated = candidate.created;
    if (candidateCreated != null &&
        (currentCreated == null || candidateCreated.isAfter(currentCreated))) {
      return candidate;
    }
  }
  return current;
}
