/*
 * Admin: tag vagy elnök törlése külön listából.
 *
 * A menüpont csak adminnál látszik. Saját fiók és másik admin nem szerepel,
 * a szerver ezeket a törléseket amúgy is visszautasítja.
 */
import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';

/// Törölhető tagok. A sor megerősítést kér, mielőtt a fiók megszűnik.
class DeleteMembersPage extends StatelessWidget {
  const DeleteMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final members = model.data?.members?.members ?? const <ClubMember>[];
    final rows = members.where((member) => member.role == 'member' || member.role == 'president').toList();
    return ClubScaffold(
      title: 'Tagok törlése',
      showFlash: false,
      body: RefreshIndicator(
        onRefresh: model.loadHome,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text('Itt törölhető egy tag, ha ezt kéri. A fiókja és minden hozzá tartozó adat törlődik.'),
            ),
            if (rows.isEmpty)
              const EmptyNote('Nincs törölhető tag.')
            else
              for (var index = 0; index < rows.length; index++)
                Band(
                  index: index,
                  child: _DeleteRow(member: rows[index]),
                ),
          ],
        ),
      ),
    );
  }
}

/// Egy tag sora a törlés gombbal.
class _DeleteRow extends StatefulWidget {
  const _DeleteRow({required this.member});

  final ClubMember member;

  @override
  State<_DeleteRow> createState() => _DeleteRowState();
}

class _DeleteRowState extends State<_DeleteRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final role = member.role == 'president' ? 'Klubelnök' : 'Tag';
    return ListTile(
      leading: UserAvatar(name: member.name, url: member.avatar),
      title: Text(member.name),
      subtitle: Text('$role\n${member.email}'),
      isThreeLine: true,
      trailing: TextButton(
        onPressed: _busy ? null : () => _delete(context),
        child: const Text('Törlés'),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final member = widget.member;
    final accepted = await confirmAction(
      context,
      title: 'Tag törlése',
      text: 'Törlöd ${member.name} fiókját és minden hozzá tartozó adatot? Ez nem vonható vissza.',
      ok: 'Törlés',
      danger: true,
    );
    if (!accepted || !context.mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).deleteMember(member.id);
      if (context.mounted) {
        showMessage(context, '${member.name} törölve lett.');
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, friendlyError(error));
        setState(() => _busy = false);
      }
    }
  }
}
