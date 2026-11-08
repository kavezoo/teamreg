/*
 * Saját adatok.
 *
 * A név és az e-mail a Google-ból jön, itt nem szerkeszthető.
 * A mentés a megnyitó lapra visz vissza. Új tagnál ez a kezdőképernyő,
 * nem marad a profilon. A törlés minden szerepnél elérhető.
 */
import 'package:flutter/material.dart';

import '../models.dart';
import '../privacy.dart';
import '../widgets/common.dart';

/// Nem szerkeszthető mező: a Google-ból kapott név és e-mail.
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

/// A /profile útvonal. Mentés után bezárja magát.
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
          const SizedBox(height: 24),
          const _DeleteAccountButton(),
        ],
      ),
    );
  }
}

/// A fiók és minden kapcsolt adat törlése, megerősítés után.
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _delete(context),
      child: const Text('Az adataim törlése'),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final accepted = await confirmAction(
      context,
      title: 'Adatok törlése',
      text: 'Törlöd a fiókodat és minden hozzá tartozó adatot? Ez kijelentkeztet, és nem vonható vissza.',
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

/// Név, levél- és telefonos kapcsolók, mentés. A [closeOnSave] a megnyitó lapra visz vissza.
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
  late Map<String, bool> _flash;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _family = TextEditingController(text: widget.user.firstName);
    _given = TextEditingController(text: widget.user.lastName);
    _mail = Map<String, bool>.from(widget.user.mail);
    _flash = Map<String, bool>.from(widget.user.flash);
  }

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id || oldWidget.user.role != widget.user.role) {
      _family.text = widget.user.firstName;
      _given.text = widget.user.lastName;
      _mail = Map<String, bool>.from(widget.user.mail);
      _flash = Map<String, bool>.from(widget.user.flash);
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
        // first_name a vezetéknév, last_name a keresztnév.
        'first_name': family,
        'last_name': given,
        if (needsPrivacy) 'accept_privacy': true,
        for (final entry in _mail.entries) entry.key: entry.value,
        for (final entry in _flash.entries) entry.key: entry.value,
      };
      // A mentés szerepet válthat, és a kezdőlap újraépül. A navigátort előtte kell elkapni.
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context, rootNavigator: true);
      await AppScope.of(context).saveProfile(body);
      final message = user.isNew && explains ? 'A jelentkezésed elment.' : 'A profil mentve.';
      if (widget.closeOnSave) {
        navigator.popUntil((route) => route.isFirst);
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      if (!mounted) {
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
        if (user.flashChoices.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Telefonos üzenetek', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          const Text('Beállíthatod, milyen üzenetet kérsz a telefonra. A jelölés alapból be van kapcsolva.'),
          for (final entry in user.flashChoices.entries)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value),
              value: _flash[entry.key] ?? true,
              onChanged: (value) => setState(() => _flash[entry.key] = value),
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
