/*
 * Űrlapok: nevezés, verseny, alcsapat.
 *
 * A verseny leírása nem HTML, hanem a pipaclub.hu linkje.
 * A date_from a listában megjelenés napja, a tag ettől látja a kiírást.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../models.dart';
import '../services/maps.dart';
import '../widgets/common.dart';

/// Nevezés darabszámai és megjegyzése. A határidő után csak olvasható.
class RegistrationEditor extends StatefulWidget {
  const RegistrationEditor({required this.competition, this.registration, super.key});

  final Competition competition;
  final Registration? registration;

  @override
  State<RegistrationEditor> createState() => _RegistrationEditorState();
}

class _RegistrationEditorState extends State<RegistrationEditor> {
  late final Map<String, int> _counts;
  late final TextEditingController _comment;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _counts = {
      for (final field in titledCounts.values) field: widget.registration?.count(field) ?? 0,
    };
    _comment = TextEditingController(text: widget.registration?.comment ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await AppScope.of(context).saveRegistration(
        id: widget.registration?.id,
        competitionId: widget.competition.id,
        counts: _counts,
        comment: _comment.text,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
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

  Future<void> _withdraw() async {
    final registration = widget.registration;
    if (registration == null) {
      return;
    }
    final accepted = await confirmAction(
      context,
      title: 'Biztosan?',
      text: 'Biztosan törlöd a jelentkezést? Ezt nem lehet visszavonni.',
      ok: 'Igen, törlöm',
      danger: true,
    );
    if (!accepted || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).withdrawRegistration(registration.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final competition = widget.competition;
    return Scaffold(
      appBar: AppBar(title: Text(competition.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ScheduleBlock(competition: competition),
          const SizedBox(height: 8),
          for (final entry in titledCounts.entries)
            if (competition.title(entry.key).isNotEmpty)
              CountStepper(
                label: competition.title(entry.key),
                value: _counts[entry.value] ?? 0,
                onChanged: (value) => setState(() => _counts[entry.value] = value),
              ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Megjegyzés',
              hintText: 'Például speciális ebédigény',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Mentés')),
          if (widget.registration != null && !competition.closed) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _withdraw,
              child: const Text('Nem tudok a versenyen részt venni'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Egy igény léptetője, nullától felfelé.
class CountStepper extends StatelessWidget {
  const CountStepper({required this.label, required this.value, required this.onChanged, super.key});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            tooltip: 'Kevesebb',
            onPressed: value <= 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.center)),
          IconButton(
            tooltip: 'Több',
            onPressed: value >= 1000 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

/// Verseny ideje, határidő, leírás linkje és a térkép gombja.
class ScheduleBlock extends StatelessWidget {
  const ScheduleBlock({required this.competition, super.key});

  final Competition competition;

  @override
  Widget build(BuildContext context) {
    final map = competition.openableMap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verseny ideje: ${formatDateTime(competition.dateCompetition)}'),
        Text('Jelentkezési határidő: ${formatDate(competition.dateDeadline)}'),
        if (competition.infoLink != null)
          TextButton.icon(
            onPressed: () => openInBrowser(context, competition.infoLink!),
            icon: const Icon(Icons.open_in_browser),
            label: const Text('A verseny leírása'),
          ),
        if (map != null)
          TextButton.icon(
            onPressed: () async {
              final opened = await openDirections(map);
              if (!opened && context.mounted) {
                showMessage(context, 'A térképprogram nem nyitható meg.');
              }
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Útvonal a helyszínre'),
          ),
      ],
    );
  }
}

/// Verseny létrehozása és szerkesztése. A leírás mezője a link.
class CompetitionEditor extends StatefulWidget {
  const CompetitionEditor({this.competition, super.key});

  final Competition? competition;

  @override
  State<CompetitionEditor> createState() => _CompetitionEditorState();
}

class _CompetitionEditorState extends State<CompetitionEditor> {
  late final TextEditingController _name;
  late final TextEditingController _comment;
  late final TextEditingController _map;
  late final TextEditingController _link;
  late final TextEditingController _pos;
  late final Map<String, TextEditingController> _titles;
  DateTime? _from;
  DateTime? _deadline;
  DateTime? _when;
  late bool _visible;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final competition = widget.competition;
    _name = TextEditingController(text: competition?.name ?? '');
    _comment = TextEditingController(text: competition?.comment ?? '');
    _map = TextEditingController(text: competition?.mapUrl ?? '');
    _link = TextEditingController(text: competition?.infoLink ?? '');
    _pos = TextEditingController(text: '${competition?.pos ?? 0}');
    _from = competition?.dateFrom;
    _deadline = competition?.dateDeadline;
    _when = competition?.dateCompetition;
    _visible = competition?.visible ?? false;
    _titles = {
      for (final field in titledCounts.keys)
        field: TextEditingController(
          text: competition == null ? (titleDefaults[field] ?? '') : competition.title(field),
        ),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _comment.dispose();
    _map.dispose();
    _link.dispose();
    _pos.dispose();
    for (final controller in _titles.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool deadline}) async {
    final initial = (deadline ? _deadline : _from) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2040),
      locale: const Locale('hu'),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (deadline) {
        _deadline = picked;
      } else {
        _from = picked;
      }
    });
  }

  Future<void> _pickWhen() async {
    final initial = _when ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2040),
      locale: const Locale('hu'),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final comment = _comment.text.trim();
    final map = _map.text.trim();
    if (name.isEmpty) {
      showMessage(context, 'A név kötelező.');
      return;
    }
    if (comment.isEmpty) {
      showMessage(context, 'A megjegyzés kötelező.');
      return;
    }
    final link = _link.text.trim();
    if (_from == null || _deadline == null) {
      showMessage(context, 'A megjelenés napja és a határidő is kell.');
      return;
    }
    if (map.isNotEmpty && !httpUrl(map)) {
      showMessage(context, 'A térkép címe http vagy https legyen.');
      return;
    }
    if (link.isNotEmpty && !httpUrl(link)) {
      showMessage(context, 'A leírás linkje http vagy https legyen.');
      return;
    }
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'comment': comment,
        'date_from': apiDate(_from),
        'date_deadline': apiDate(_deadline),
        'date_competition': apiDateTime(_when),
        'map_url': map,
        'info_url': link,
        'visible': _visible,
        'pos': int.tryParse(_pos.text.trim()) ?? 0,
        for (final entry in _titles.entries) entry.key: entry.value.text.trim(),
      };
      await AppScope.of(context).saveCompetition(body, id: widget.competition?.id);
      if (mounted) {
        Navigator.pop(context, true);
      }
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
    final editing = widget.competition != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Verseny szerkesztése' : 'Új verseny')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Név'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            // date_from: nem a jelentkezés kezdete, hanem a tagok listáján a megjelenés napja.
            title: const Text('Megjelenés a listában'),
            subtitle: Text(
              _from == null
                  ? 'nincs megadva\nEttől a naptól látják a tagok.'
                  : '${formatDate(_from)}\nEttől a naptól látják a tagok.',
            ),
            trailing: const Icon(Icons.event),
            onTap: () => _pickDate(deadline: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Jelentkezési határidő'),
            subtitle: Text(formatDate(_deadline)),
            trailing: const Icon(Icons.event),
            onTap: () => _pickDate(deadline: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verseny ideje'),
            subtitle: Text(_when == null ? 'nincs megadva' : formatDateTime(_when)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_when != null)
                  IconButton(
                    tooltip: 'Időpont törlése',
                    onPressed: () => setState(() => _when = null),
                    icon: const Icon(Icons.clear),
                  ),
                const Icon(Icons.schedule),
              ],
            ),
            onTap: _pickWhen,
          ),
          TextField(
            controller: _map,
            decoration: const InputDecoration(
              labelText: 'Helyszín',
              hintText: 'https://maps.google.com/...',
            ),
          ),
          const SizedBox(height: 12),
          for (final field in titledCounts.keys) ...[
            TextField(
              controller: _titles[field],
              decoration: InputDecoration(labelText: _titleLabel(field)),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _comment,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Megjegyzés'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              // info_url. A HTML-leírást a lap nem menti, a régi szöveg a szerveren megmarad.
              labelText: 'Leírás linkje',
              hintText: 'https://pipaclub.hu/...',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Látható a tagoknak'),
            subtitle: const Text('Bekapcsolva jelentkezhetnek rá.'),
            value: _visible,
            onChanged: (value) => setState(() => _visible = value),
          ),
          TextField(
            controller: _pos,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Sorrend'),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Mentés')),
        ],
      ),
    );
  }

  String _titleLabel(String field) {
    switch (field) {
      case 'lunch_title':
        return 'Ebéd címe';
      case 'special_lunch_title':
        return 'Különleges ebéd címe';
      case 'competition_pipe_title_1':
        return 'Versenypipa 1 címe';
      case 'competition_pipe_title_2':
        return 'Versenypipa 2 címe';
      case 'competition_pipe_title_3':
        return 'Versenypipa 3 címe';
      case 'extra_title_1':
        return 'Extra 1 címe';
      case 'extra_title_2':
        return 'Extra 2 címe';
      case 'extra_title_3':
        return 'Extra 3 címe';
      default:
        return field;
    }
  }
}

/// Alcsapat párbeszéd. Team nélkül új csapatot hoz létre.
Future<void> editTeam(BuildContext context, {Team? team}) async {
  final name = TextEditingController(text: team?.name ?? '');
  final pos = TextEditingController(text: '${team?.pos ?? 0}');
  var visible = team?.visible ?? false;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(team == null ? 'Új alcsapat' : 'Alcsapat'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Név'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pos,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Sorrend'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Látható'),
                    value: visible,
                    onChanged: (value) => setState(() => visible = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse')),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty) {
                          showMessage(context, 'A név kötelező.');
                          return;
                        }
                        setState(() => busy = true);
                        try {
                          await AppScope.of(context).saveTeam(
                            id: team?.id,
                            name: name.text.trim(),
                            visible: visible,
                            pos: int.tryParse(pos.text.trim()) ?? 0,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            showMessage(context, friendlyError(error));
                            setState(() => busy = false);
                          }
                        }
                      },
                child: const Text('Mentés'),
              ),
            ],
          );
        },
      );
    },
  );
  name.dispose();
  pos.dispose();
}
