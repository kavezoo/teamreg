import 'package:flutter/material.dart';

import '../models.dart';
import '../privacy.dart';
import '../widgets/common.dart';

class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(value.isEmpty ? '—' : value),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    if (user == null) {
      return const SizedBox.shrink();
    }
    return ClubScaffold(
      title: 'Saját adatok',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ProfileForm(user: user, closeOnSave: true),
        ],
      ),
    );
  }
}

class ProfileForm extends StatefulWidget {
  const ProfileForm({required this.user, this.closeOnSave = false, super.key});

  final UserProfile user;
  final bool closeOnSave;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController _family;
  late final TextEditingController _given;
  late Map<String, bool> _mail;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _family = TextEditingController(text: widget.user.firstName);
    _given = TextEditingController(text: widget.user.lastName);
    _mail = Map<String, bool>.from(widget.user.mail);
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.role != widget.user.role) {
      _family.text = widget.user.firstName;
      _given.text = widget.user.lastName;
      _mail = Map<String, bool>.from(widget.user.mail);
    }
  }

  @override
  void dispose() {
    _family.dispose();
    _given.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = widget.user;
    final family = _family.text.trim();
    final given = _given.text.trim();
    if (family.isEmpty || given.isEmpty) {
      showMessage(context, 'A vezetéknév és a keresztnév is kell.');
      return;
    }
    final needsPrivacy = (user.isNew || user.isMember) && !user.privacyAccepted;
    final explains = user.isNew && user.membershipRequest != 'pending';
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'first_name': family,
        'last_name': given,
        if (needsPrivacy) 'accept_privacy': true,
        for (final entry in _mail.entries) entry.key: entry.value,
      };
      await AppScope.of(context).saveProfile(body);
      if (!mounted) {
        return;
      }
      final message = user.isNew && explains ? 'A jelentkezésed elment.' : 'A profil mentve.';
      if (widget.closeOnSave && Navigator.of(context).canPop()) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      showMessage(context, message);
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
    final user = widget.user;
    final model = AppScope.of(context);
    final needsPrivacy = (user.isNew || user.isMember) && !user.privacyAccepted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: UserAvatar(name: user.name, url: model.ownPhoto, radius: 42)),
        const SizedBox(height: 8),
        Text(user.roleLabel, textAlign: TextAlign.center),
        if (user.isNew) ...[
          const SizedBox(height: 16),
          Text(
            user.membershipRequest == 'pending'
                ? 'Az adataidat itt javíthatod. A jelentkezésed már a klubelnöknél van. A Mentés elmenti a javítást, és bezárja az űrlapot.'
                : 'Ellenőrizd az adataidat, és ha kell, javítsd. A jelentkezés a Mentés gomb megnyomásával történik, utána ez az űrlap bezárul.',
          ),
        ],
        const SizedBox(height: 16),
        _LockedField(label: 'Felhasználónév', value: user.username),
        const SizedBox(height: 12),
        _LockedField(label: 'E-mail', value: user.email),
        const SizedBox(height: 12),
        TextField(
          controller: _family,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Vezetéknév'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _given,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Keresztnév'),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              final family = _family.text;
              _family.text = _given.text;
              _given.text = family;
            },
            child: const Text('Nevek cseréje'),
          ),
        ),
        if (user.mailChoices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('E-mailek', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text('Beállíthatod, milyen levelet kérsz. A jelölés alapból be van kapcsolva.'),
          for (final entry in user.mailChoices.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _mail[entry.key] ?? true,
              onChanged: (value) => setState(() => _mail[entry.key] = value),
            ),
        ],
        if (needsPrivacy) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showPrivacy(context),
              child: const Text('Adatkezelési nyilatkozat'),
            ),
          ),
        ],
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Mentés…' : 'Mentés'),
        ),
      ],
    );
  }
}
