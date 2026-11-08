/*
 * Klubelnök és admin kezdőlapja, hamburger menüvel.
 *
 * A menüpontok sorrendje a _section indexe:
 * 0 jelentkezők, 1 versenyek, 2 saját nevezés, 3 nevezők, 4 tagok, 5 alcsapatok.
 * Alapból a nevezők nyílik. Jelentkezőnél a jelentkezők, mert ott kell engedélyezni vagy tiltani.
 */
import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'delete_members.dart';
import 'editors.dart';
import 'member_home.dart';
import 'past_competitions.dart';

/// Elnöki váz. Az admin címe Admin, különben Klubelnök.
class PresidentHome extends StatefulWidget {
  const PresidentHome({super.key});

  @override
  State<PresidentHome> createState() => _PresidentHomeState();
}

class _PresidentHomeState extends State<PresidentHome> {
  static const _sections = ['Jelentkezők', 'Versenyek', 'Nevezésem', 'Nevezők', 'Tagok', 'Alcsapatok'];

  /// 3 = Nevezők, ez a szokásos kezdőlap.
  int _section = 3;

  /// Az első betöltés után dől el, kell-e a jelentkezők lapja.
  bool _pickedStart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final section = AppScope.of(context).requestedSection;
    if (section == null || section == _section) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final next = AppScope.of(context).takeSection();
      if (next != null) {
        setState(() => _section = next);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final data = model.data;
    final title = model.user?.role == 'admin' ? 'Admin' : 'Klubelnök';
    if (model.error != null && data == null) {
      return ClubScaffold(
        title: title,
        body: LoadProblem(message: model.error!, onRetry: model.loadHome),
      );
    }
    final home = data ?? HomeData.empty;
    // Üzenetből kért lapot nem írjuk felül. Várakozó jelentkezőnél a 0-s lap kell.
    if (!_pickedStart && data != null && model.requestedSection == null) {
      _pickedStart = true;
      if (data.applicants.isNotEmpty) {
        _section = 0;
      }
    }
    final pending = home.applicants.length;
    return ClubScaffold(
      title: title,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              for (var index = 0; index < _sections.length; index++)
                ListTile(
                  selected: index == _section,
                  title: Text(
                    index == 0 && pending > 0 ? 'Jelentkezők ($pending)' : _sections[index],
                  ),
                  onTap: () {
                    setState(() => _section = index);
                    Navigator.of(context).pop();
                  },
                ),
              if (model.user?.role == 'admin')
                ListTile(
                  title: const Text('Tagok törlése'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (context) => const DeleteMembersPage()),
                    );
                  },
                ),
              ListTile(
                title: const Text('Korábbi versenyek'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (context) => const PastCompetitionsPage(canEdit: true)),
                  );
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Saját adatok'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/profile');
                },
              ),
              ListTile(
                title: const Text('Kijelentkezés'),
                onTap: () {
                  Navigator.of(context).pop();
                  model.logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: switch (_section) {
        0 => _Applicants(data: home),
        1 => _Competitions(data: home),
        2 => CompetitionBoard(
            competitions: home.competitions,
            registrations: home.registrations.where((row) => row.userId == model.user?.id).toList(),
          ),
        3 => _Groups(data: home),
        4 => _Members(data: home),
        _ => _Teams(data: home),
      },
    );
  }
}

/// Lehúzható lista, ami a kezdőlapot újratölti.
class _Refresh extends StatelessWidget {
  const _Refresh({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: AppScope.of(context).loadHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    );
  }
}

/// Elbírálásra váró jelentkezők. Üresen a nevezők a kezdőlap.
class _Applicants extends StatelessWidget {
  const _Applicants({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    if (data.applicants.isEmpty) {
      return const _Refresh(children: [EmptyNote('Nincs elbírálásra váró jelentkező.')]);
    }
    return _Refresh(
      children: [
        for (var index = 0; index < data.applicants.length; index++)
          _ApplicantCard(applicant: data.applicants[index], bandIndex: index),
      ],
    );
  }
}

/// Egy jelentkező: engedélyezés vagy tiltás.
class _ApplicantCard extends StatefulWidget {
  const _ApplicantCard({required this.applicant, required this.bandIndex});

  final Applicant applicant;
  final int bandIndex;

  @override
  State<_ApplicantCard> createState() => _ApplicantCardState();
}

class _ApplicantCardState extends State<_ApplicantCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicant = widget.applicant;
    final model = AppScope.of(context);
    return SectionCard(
      bandIndex: widget.bandIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(name: applicant.name, url: applicant.avatar),
            title: Text(applicant.name),
            subtitle: Text(applicant.email),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _run(() => model.approveApplicant(applicant.id)),
                child: const Text('Elfogad'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final accepted = await confirmAction(
                          context,
                          title: 'Nem tag',
                          text: 'Megjelölöd, hogy nem tag, csak kipróbálta az oldalt?',
                        );
                        if (accepted && context.mounted) {
                          await _run(() => model.denyApplicant(applicant.id));
                        }
                      },
                child: const Text('Nem tag, csak kipróbálta'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aktuális versenyek, szerkesztéssel és új kiírással.
class _Competitions extends StatelessWidget {
  const _Competitions({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    return _Refresh(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const CompetitionEditor()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Új verseny'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.competitions.isEmpty)
          const EmptyNote('Még nincs kiírt verseny.')
        else
          for (var index = 0; index < data.competitions.length; index++)
            _CompetitionRow(competition: data.competitions[index], data: data, bandIndex: index),
      ],
    );
  }
}

/// Verseny sora: időpont, link, szerkesztés.
class _CompetitionRow extends StatelessWidget {
  const _CompetitionRow({required this.competition, required this.data, required this.bandIndex});

  final Competition competition;
  final HomeData data;
  final int bandIndex;

  @override
  Widget build(BuildContext context) {
    final people = data.registrations.where((row) => row.competitionId == competition.id).toList()
      ..sort(
        (a, b) => compareByAssignment(
          name: a.userName,
          team: a.teamName,
          teamPos: a.teamPos,
          otherName: b.userName,
          otherTeam: b.teamName,
          otherTeamPos: b.teamPos,
        ),
      );
    final names = people.map((row) => row.userName).where((name) => name.isNotEmpty).toList();
    return SectionCard(
      bandIndex: bandIndex,
      title: competition.name,
      trailing: IconButton(
        tooltip: 'Szerkesztés',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => CompetitionEditor(competition: competition),
            ),
          );
        },
        icon: const Icon(Icons.edit_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleBlock(competition: competition),
          Text(competition.visible ? 'Látható a tagoknak' : 'A tagoknak rejtett'),
          const SizedBox(height: 6),
          Text(names.isEmpty ? 'Nevezők: 0' : 'Nevezők: ${names.join(', ')}'),
        ],
      ),
    );
  }
}

/// Nevezők versenyenként, csapatba sorolással.
class _Groups extends StatelessWidget {
  const _Groups({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final currentIds = data.competitions.map((item) => item.id).toSet();
    final grouped = <int, List<Registration>>{};
    for (final row in data.registrations) {
      if (!currentIds.contains(row.competitionId)) {
        continue;
      }
      grouped.putIfAbsent(row.competitionId, () => []).add(row);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final left = _name(a);
        final right = _name(b);
        return left.toLowerCase().compareTo(right.toLowerCase());
      });
    return _Refresh(
      children: [
        if (grouped.isEmpty)
          const EmptyNote('Még nincs jelentkező.')
        else ...[
          if (data.teams.isEmpty)
            const EmptyNote('Előbb hozz létre alcsapatot, utána lehet besorolni a jelentkezőket.'),
          for (final id in keys) _Group(competitionId: id, rows: grouped[id]!, data: data),
        ],
      ],
    );
  }

  String _name(int id) {
    for (final competition in data.competitions) {
      if (competition.id == id) {
        return competition.name;
      }
    }
    final rows = data.registrations.where((row) => row.competitionId == id);
    return rows.isEmpty ? 'Verseny' : rows.first.competitionName;
  }
}

/// Egy verseny nevezőlistája.
class _Group extends StatelessWidget {
  const _Group({required this.competitionId, required this.rows, required this.data});

  final int competitionId;
  final List<Registration> rows;
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]..sort(
            (a, b) => compareByAssignment(
              name: a.userName,
              team: a.teamName,
              teamPos: a.teamPos,
              otherName: b.userName,
              otherTeam: b.teamName,
              otherTeamPos: b.teamPos,
            ),
          );
    Competition? competition;
    for (final item in data.competitions) {
      if (item.id == competitionId) {
        competition = item;
        break;
      }
    }
    return SectionCard(
      title: competition?.name ?? (sorted.isEmpty ? 'Verseny' : sorted.first.competitionName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (competition != null) ScheduleBlock(competition: competition),
          for (var index = 0; index < sorted.length; index++)
            Band(index: index, child: _AssignRow(row: sorted[index], teams: data.teams)),
        ],
      ),
    );
  }
}

/// Nevező és a csapat legördülője.
class _AssignRow extends StatefulWidget {
  const _AssignRow({required this.row, required this.teams});

  final Registration row;
  final List<Team> teams;

  @override
  State<_AssignRow> createState() => _AssignRowState();
}

class _AssignRowState extends State<_AssignRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final known = widget.teams.map((team) => team.id).toSet();
    final value = row.teamId != null && known.contains(row.teamId) ? row.teamId : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: row.userName, url: row.avatar),
      title: Text(row.userName.isEmpty ? 'Névtelen' : row.userName),
      subtitle: DropdownButton<int?>(
        isExpanded: true,
        value: value,
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Nincs besorolva')),
          for (final team in widget.teams)
            DropdownMenuItem<int?>(
              value: team.id,
              child: Text(team.visible ? team.name : '${team.name} (rejtett)'),
            ),
        ],
        onChanged: _busy
            ? null
            : (next) async {
                if (next == row.teamId || (next == null && row.teamId == null)) {
                  return;
                }
                final model = AppScope.of(context);
                setState(() => _busy = true);
                try {
                  await model.assignTeam(row, next);
                } catch (error) {
                  if (context.mounted) {
                    showMessage(context, friendlyError(error));
                  }
                } finally {
                  if (mounted) {
                    setState(() => _busy = false);
                  }
                }
              },
      ),
    );
  }
}

/// Tagok, emlékeztetővel és elnökké nevezéssel.
class _Members extends StatelessWidget {
  const _Members({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final members = data.members;
    final model = AppScope.of(context);
    return _Refresh(
      children: [
        if (members == null || !members.canRemind)
          const EmptyNote('Nincs nyitott verseny, ezért emlékeztetőt nem lehet küldeni.')
        else
          Text('A jelentkezés és az emlékeztető ehhez a versenyhez tartozik: ${members.competitionName}'),
        if (members != null && members.canRemind && members.missing > 0) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              final accepted = await confirmAction(
                context,
                title: 'E-mail küldése',
                text: 'Elküldöd az emlékeztetőt mindenkinek, aki még nem jelentkezett?',
              );
              if (!accepted || !context.mounted) {
                return;
              }
              try {
                final message = await model.remindMissing(members.competitionId!);
                if (context.mounted) {
                  showMessage(context, message);
                }
              } catch (error) {
                if (context.mounted) {
                  showMessage(context, friendlyError(error));
                }
              }
            },
            child: Text('Emlékeztető mindenkinek, aki még nem jelentkezett (${members.missing})'),
          ),
        ],
        const SizedBox(height: 12),
        if (members == null || members.members.isEmpty)
          const EmptyNote('Nincs aktív tag.')
        else
          for (var index = 0; index < members.members.length; index++)
            Band(
              index: index,
              child: _MemberRow(member: members.members[index], competitionId: members.competitionId),
            ),
      ],
    );
  }
}

/// Tag sora: szerepváltás és emlékeztető.
class _MemberRow extends StatefulWidget {
  const _MemberRow({required this.member, required this.competitionId});

  final ClubMember member;
  final int? competitionId;

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final String status;
    Widget? action;
    if (member.registered) {
      final team = member.team?.trim() ?? '';
      status = team.isEmpty ? 'Jelentkezett a versenyre és besorolásra vár' : team;
    } else if (member.remindedAt != null) {
      status = member.remindedAt!;
    } else if (widget.competitionId != null && member.email.trim().isNotEmpty) {
      status = 'Még nem jelentkezett';
      action = OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  final message = await AppScope.of(context).remindMember(member.id, widget.competitionId!);
                  if (context.mounted) {
                    showMessage(context, message);
                  }
                } catch (error) {
                  if (context.mounted) {
                    showMessage(context, friendlyError(error));
                  }
                } finally {
                  if (mounted) {
                    setState(() => _busy = false);
                  }
                }
              },
        child: const Text('Emlékeztető'),
      );
    } else if (widget.competitionId != null) {
      status = 'Nincs e-mail címe';
    } else {
      status = '';
    }
    final mine = member.id == AppScope.of(context).user?.id;
    final canAppoint = !mine && (member.role == 'member' || member.role == 'president');
    final appoint = member.role == 'president';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: UserAvatar(name: member.name, url: member.avatar),
          title: Text(member.role == 'president' ? '${member.name} · Elnök' : member.name),
          subtitle: Text(status.isEmpty ? member.email : '${member.email}\n$status'),
          trailing: action,
        ),
        if (canAppoint)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final accepted = await confirmAction(
                        context,
                        title: appoint ? 'Taggá tétel' : 'Elnökké nevezés',
                        text: appoint
                            ? '${member.name} újra tag legyen?'
                            : '${member.name} klubelnök legyen?',
                      );
                      if (!accepted || !context.mounted) {
                        return;
                      }
                      setState(() => _busy = true);
                      try {
                        await AppScope.of(context).setMemberRole(
                          member.id,
                          appoint ? 'member' : 'president',
                        );
                      } catch (error) {
                        if (context.mounted) {
                          showMessage(context, friendlyError(error));
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _busy = false);
                        }
                      }
                    },
              child: Text(appoint ? 'Legyen tag' : 'Legyen elnök'),
            ),
          ),
      ],
    );
  }
}

/// Alcsapatok sorrendje és láthatósága.
class _Teams extends StatelessWidget {
  const _Teams({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    return _Refresh(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => editTeam(context),
            icon: const Icon(Icons.add),
            label: const Text('Új alcsapat'),
          ),
        ),
        const SizedBox(height: 12),
        if (data.teams.isEmpty)
          const EmptyNote('Még nincs alcsapat.')
        else
          for (var index = 0; index < data.teams.length; index++)
            Band(
              index: index,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(data.teams[index].name),
                subtitle: Text(
                  'Sorrend: ${data.teams[index].pos} · ${data.teams[index].visible ? 'Látható' : 'Rejtett'}',
                ),
                trailing: IconButton(
                  tooltip: 'Szerkesztés',
                  onPressed: () => editTeam(context, team: data.teams[index]),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
      ],
    );
  }
}
