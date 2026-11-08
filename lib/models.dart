import 'format.dart';

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
    this.avatar,
    this.tosDate,
  });

  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String name;
  final String role;
  final String? membershipRequest;
  final bool profileSaved;
  final bool enabled;
  final Map<String, bool> mail;
  final Map<String, String> mailChoices;
  final String? avatar;
  final DateTime? tosDate;

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
      avatar: avatar.isEmpty ? null : avatar,
      tosDate: asDate(json['tos_date']),
    );
  }
}

class Competition {
  const Competition({
    required this.id,
    required this.name,
    required this.comment,
    required this.description,
    this.descriptionHtml = '',
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
  final String description;
  final String descriptionHtml;
  final String? mapUrl;
  final DateTime? dateCompetition;
  final DateTime? dateFrom;
  final DateTime? dateDeadline;
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
    );
  }
}

class RosterLine {
  const RosterLine({
    required this.name,
    required this.team,
    required this.competition,
    required this.avatar,
    required this.teamPos,
  });

  final String name;
  final String team;
  final String competition;
  final String? avatar;
  final int? teamPos;

  factory RosterLine.fromJson(Map<String, dynamic> json) {
    final avatar = asText(json['avatar']);
    return RosterLine(
      name: asText(json['name']),
      team: asText(json['team']),
      competition: asText(json['competition']),
      avatar: avatar.isEmpty ? null : avatar,
      teamPos: json['team_pos'] == null ? null : asInt(json['team_pos']),
    );
  }
}

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
