import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'editors.dart';

class MemberHome extends StatelessWidget {
  const MemberHome({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final data = model.data;
    final Widget body;
    if (model.error != null && data == null) {
      body = LoadProblem(message: model.error!, onRetry: model.loadHome);
    } else {
      body = CompetitionBoard(
        competitions: data?.competitions ?? const [],
        registrations: data?.registrations ?? const [],
        roster: data?.roster ?? const [],
        showRoster: true,
      );
    }
    return ClubScaffold(title: 'Ibafai Klubtag', body: body);
  }
}

class CompetitionBoard extends StatelessWidget {
  const CompetitionBoard({
    required this.competitions,
    required this.registrations,
    this.roster = const [],
    this.showRoster = false,
    super.key,
  });

  final List<Competition> competitions;
  final List<Registration> registrations;
  final List<RosterLine> roster;
  final bool showRoster;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: model.loadHome,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (competitions.isEmpty)
            const EmptyNote('Jelenleg nincs verseny, amire jelentkezni lehet.')
          else
            for (final competition in competitions) ...[
              _CompetitionCard(
                competition: competition,
                registration: _own(competition.id),
              ),
              if (showRoster) _RosterBlock(competition: competition, roster: roster),
            ],
        ],
      ),
    );
  }

  Registration? _own(int competitionId) {
    for (final registration in registrations) {
      if (registration.competitionId == competitionId) {
        return registration;
      }
    }
    return null;
  }
}

class _CompetitionCard extends StatelessWidget {
  const _CompetitionCard({required this.competition, required this.registration});

  final Competition competition;
  final Registration? registration;

  @override
  Widget build(BuildContext context) {
    final description = competition.renderedDescription;
    return SectionCard(
      title: competition.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleBlock(competition: competition),
          if (registration != null) ...[
            const SizedBox(height: 8),
            for (final entry in titledCounts.entries)
              if (competition.title(entry.key).isNotEmpty)
                Text('${competition.title(entry.key)}: ${registration!.count(entry.value)}'),
            if ((registration!.comment ?? '').trim().isNotEmpty)
              Text('Megjegyzés: ${registration!.comment}'),
            Text(
              'Alcsapat: ${registration!.teamName.trim().isEmpty ? 'Nincs besorolva' : registration!.teamName}',
            ),
          ] else if (competition.closed || !competition.visible)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('A jelentkezés lezárult.'),
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            HtmlBlock(html: description),
          ],
          const SizedBox(height: 12),
          if (registration != null)
            OutlinedButton(
              onPressed: () => _open(context),
              child: const Text('Módosítás'),
            )
          else if (competition.canSignUp)
            FilledButton(
              onPressed: () => _open(context),
              child: const Text('Jelentkezés'),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RegistrationEditor(competition: competition, registration: registration),
      ),
    );
  }
}

class _RosterBlock extends StatelessWidget {
  const _RosterBlock({required this.competition, required this.roster});

  final Competition competition;
  final List<RosterLine> roster;

  @override
  Widget build(BuildContext context) {
    final lines = roster.where((line) => line.competition == competition.name).toList()
      ..sort(
        (a, b) => compareByAssignment(
          name: a.name,
          team: a.team,
          teamPos: a.teamPos,
          otherName: b.name,
          otherTeam: b.team,
          otherTeamPos: b.teamPos,
        ),
      );
    return SectionCard(
      title: 'Jelentkezők',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(competition.name, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            const EmptyNote('Még nincs jelentkező.')
          else
            for (final line in lines) _RosterTile(line: line),
        ],
      ),
    );
  }
}

class _RosterTile extends StatelessWidget {
  const _RosterTile({required this.line});

  final RosterLine line;

  @override
  Widget build(BuildContext context) {
    final team = line.team.trim().isEmpty ? 'Nincs besorolva' : line.team;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: line.name, url: line.avatar),
      title: Text(line.name),
      subtitle: Text(team),
    );
  }
}
