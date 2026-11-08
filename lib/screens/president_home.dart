import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'editors.dart';
import 'member_home.dart';

class PresidentHome extends StatelessWidget {
  const PresidentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final data = model.data;
    if (model.error != null && data == null) {
      return ClubScaffold(
        title: 'Ibafai Klubelnök',
        body: LoadProblem(message: model.error!, onRetry: model.loadHome),
      );
    }
    final home = data ?? HomeData.empty;
    final pending = home.applicants.length;
    return DefaultTabController(
      length: 6,
      child: ClubScaffold(
        title: model.user?.role == 'admin' ? 'Admin' : 'Ibafai Klubelnök',
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: pending == 0 ? 'Jelentkezők' : 'Jelentkezők ($pending)'),
            const Tab(text: 'Versenyek'),
            const Tab(text: 'Nevezésem'),
            const Tab(text: 'Nevezők'),
            const Tab(text: 'Tagok'),
            const Tab(text: 'Alcsapatok'),
          ],
        ),
        body: TabBarView(
          children: [
            _Applicants(data: home),
            _Competitions(data: home),
            CompetitionBoard(
              competitions: home.competitions,
              registrations: home.registrations.where((row) => row.userId == model.user?.id).toList(),
            ),
            _Groups(data: home),
            _Members(data: home),
            _Teams(data: home),
          ],
        ),
      ),
    );
  }
}

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
        for (final applicant in data.applicants) _ApplicantCard(applicant: applicant),
      ],
    );
  }
}

class _ApplicantCard extends StatefulWidget {
  const _ApplicantCard({required this.applicant});

  final Applicant applicant;

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
          for (final competition in data.competitions)
            _CompetitionRow(competition: competition, data: data),
      ],
    );
  }
}

class _CompetitionRow extends StatelessWidget {
  const _CompetitionRow({required this.competition, required this.data});

  final Competition competition;
  final HomeData data;

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

class _Groups extends StatelessWidget {
  const _Groups({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<Registration>>{};
    for (final row in data.registrations) {
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
          for (final row in sorted) _AssignRow(row: row, teams: data.teams),
        ],
      ),
    );
  }
}

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
          for (final member in members.members)
            _MemberRow(member: member, competitionId: members.competitionId),
      ],
    );
  }
}

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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: member.name, url: member.avatar),
      title: Text(member.role == 'president' ? '${member.name} · Elnök' : member.name),
      subtitle: Text(status.isEmpty ? member.email : '${member.email}\n$status'),
      trailing: action,
    );
  }
}

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
          for (final team in data.teams)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(team.name),
              subtitle: Text('Sorrend: ${team.pos} · ${team.visible ? 'Látható' : 'Rejtett'}'),
              trailing: IconButton(
                tooltip: 'Szerkesztés',
                onPressed: () => editTeam(context, team: team),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
      ],
    );
  }
}
