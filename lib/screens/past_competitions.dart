import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'editors.dart';

class PastCompetitionsPage extends StatefulWidget {
  const PastCompetitionsPage({this.canEdit = false, super.key});

  final bool canEdit;

  @override
  State<PastCompetitionsPage> createState() => _PastCompetitionsPageState();
}

class _PastCompetitionsPageState extends State<PastCompetitionsPage> {
  List<Competition>? _rows;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppScope.of(context).loadPastCompetitions();
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? const <Competition>[];
    final Widget body;
    if (_loading && _rows == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _rows == null) {
      body = LoadProblem(message: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (rows.isEmpty)
              const EmptyNote('Nincs korábbi verseny.')
            else
              for (var index = 0; index < rows.length; index++)
                Band(
                  index: index,
                  child: _PastRow(competition: rows[index], canEdit: widget.canEdit),
                ),
          ],
        ),
      );
    }
    return ClubScaffold(title: 'Korábbi versenyek', body: body);
  }
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.competition, required this.canEdit});

  final Competition competition;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final link = competition.infoLink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(competition.name, style: Theme.of(context).textTheme.titleMedium)),
              if (canEdit)
                IconButton(
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
            ],
          ),
          Text(formatDateTime(competition.dateCompetition)),
          if (link != null)
            TextButton.icon(
              onPressed: () => openInBrowser(context, link),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('A verseny leírása'),
            ),
        ],
      ),
    );
  }
}
