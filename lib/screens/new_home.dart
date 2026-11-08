import 'package:flutter/material.dart';

import '../format.dart';
import '../widgets/common.dart';

class NewHome extends StatefulWidget {
  const NewHome({super.key});

  @override
  State<NewHome> createState() => _NewHomeState();
}

class _NewHomeState extends State<NewHome> {
  bool _leaving = false;
  bool _refreshing = false;
  bool _openedForm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFormAtStart());
  }

  Future<void> _openFormAtStart() async {
    if (!mounted || _openedForm) {
      return;
    }
    final user = AppScope.of(context).user;
    if (user == null || user.denied || user.profileSaved || user.membershipRequest == 'pending') {
      return;
    }
    _openedForm = true;
    await _openProfile();
  }

  Future<void> _openProfile() {
    return Navigator.of(context).pushNamed('/profile');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppScope.of(context).user;
    if (user != null && user.denied && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _leaveAfterDenial();
        }
      });
    }
  }

  Future<void> _leaveAfterDenial() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('A jelentkezést elutasították'),
        content: const Text(deniedNotice),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Rendben')),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    await AppScope.of(context).logout();
  }

  Future<void> _refresh() async {
    final model = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _refreshing = true);
    try {
      final next = await model.reloadMe();
      if (next.denied || next.isMember) {
        if (next.isMember) {
          messenger.showSnackBar(
            const SnackBar(content: Text('A jelentkezésedet elfogadtuk. Tag lettél.')),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      showMessage(
        context,
        next.membershipRequest == 'pending'
            ? 'A jelentkezésed még a klubelnöknél van. Új tag vagy.'
            : 'Még nem jelentkeztél. Mentsd el a profilodat, azzal indul a jelentkezés.',
      );
    } catch (error) {
      if (mounted) {
        showMessage(context, friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final pending = user.membershipRequest == 'pending';
    return ClubScaffold(
      title: 'Új tag, elfogadásra vár',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SectionCard(
            title: 'Teendőid',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pending ? _pendingGuide : _startGuide),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _openProfile,
                  child: const Text('Saját adatok'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _refreshing ? null : _refresh,
                  child: Text(_refreshing ? 'Frissítés…' : 'Tagság frissítése'),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _delete(context),
            child: const Text('Az adataim törlése'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final accepted = await confirmAction(
      context,
      title: 'Adatok törlése',
      text: 'Törlöd a fiókodat és a hozzá tartozó adatokat? Ez kijelentkeztet.',
      ok: 'Törlés',
      danger: true,
    );
    if (!accepted || !context.mounted) {
      return;
    }
    try {
      await AppScope.of(context).deleteAccount();
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error));
      }
    }
  }
}

const _startGuide =
    'Ellenőrizd az adataidat, és ha kell, javítsd. A Saját adatok gomb nyitja meg az űrlapot.\n\n'
    'A jelentkezés a Mentés gomb megnyomásával kerül a klubelnökhöz. Mentés után az űrlap bezárul.\n\n'
    'Utána várd meg, amíg a klubelnök elfogadja a jelentkezésedet. A Tagság frissítése megmutatja, ha már tag lettél, és akkor a tagi képernyő nyílik meg.';

const _pendingGuide =
    'A jelentkezésed a klubelnöknél van. Várd meg, amíg elfogadja.\n\n'
    'Addig új tag maradsz. A Saját adatok gombbal megnyithatod az űrlapot, és javíthatod az adataidat.\n\n'
    'A Tagság frissítése lekérdezi a döntést. Ha a klubelnök elfogadott, a tagi képernyő nyílik meg. Ha elutasított, üzenetet kapsz, és kijelentkeztetünk.';
