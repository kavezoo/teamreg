/*
 * Beállítások. A téma, a levelek és a telefonos üzenetek kapcsolói.
 */
import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Sötét téma és a szerephez tartozó értesítési kapcsolók.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, bool> _mail = {};
  Map<String, bool> _flash = {};
  bool _ready = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) {
      return;
    }
    final user = AppScope.of(context).user;
    if (user == null) {
      return;
    }
    _mail = {for (final entry in user.mailChoices.entries) entry.key: user.mail[entry.key] ?? true};
    _flash = {for (final entry in user.flashChoices.entries) entry.key: user.flash[entry.key] ?? true};
    _ready = true;
  }

  Future<void> _save() async {
    final model = AppScope.of(context);
    final user = model.user;
    if (user == null || _busy) {
      return;
    }
    final needsPrivacy = (user.isNew || user.isMember) && !user.privacyAccepted;
    setState(() => _busy = true);
    try {
      await model.saveProfile({
        'first_name': user.firstName,
        'last_name': user.lastName,
        if (needsPrivacy) 'accept_privacy': true,
        for (final entry in _mail.entries) entry.key: entry.value,
        for (final entry in _flash.entries) entry.key: entry.value,
      });
      if (mounted) {
        showMessage(context, 'A beállítások elmentve.');
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
    final model = AppScope.of(context);
    final user = model.user;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClubScaffold(
      title: 'Beállítások',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sötét téma'),
            subtitle: Text(dark ? 'Sötét felület' : 'Világos felület'),
            value: dark,
            onChanged: (_) => model.toggleTheme(Theme.of(context).brightness),
          ),
          if (user != null && user.mailChoices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('E-mailek', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text('Beállíthatod, milyen levelet kérsz. A jelölés alapból be van kapcsolva.'),
            for (final entry in user.mailChoices.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: _mail[entry.key] ?? true,
                onChanged: _busy ? null : (value) => setState(() => _mail[entry.key] = value),
              ),
          ],
          if (user != null && user.flashChoices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Telefonos üzenetek', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text('Beállíthatod, milyen üzenetet kérsz a telefonra. A jelölés alapból be van kapcsolva.'),
            for (final entry in user.flashChoices.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: _flash[entry.key] ?? true,
                onChanged: _busy ? null : (value) => setState(() => _flash[entry.key] = value),
              ),
          ],
          if (user != null && (user.mailChoices.isNotEmpty || user.flashChoices.isNotEmpty)) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Mentés…' : 'Mentés'),
            ),
          ],
        ],
      ),
    );
  }
}
