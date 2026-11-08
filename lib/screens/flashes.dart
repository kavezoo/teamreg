/*
 * Telefonos üzenetek.
 *
 * A sáv a legújabb olvasatlant mutatja. A koppintás a target szerint
 * a nevezésre, a nevezőkre, a versenyre, a jelentkezőkre vagy a profilra visz.
 */
import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import 'editors.dart';
import 'messages.dart';

/// Az összes üzenet. A showFlash hamis, hogy a sáv ne ismétlődjön a lista fölött.
class FlashesPage extends StatelessWidget {
  const FlashesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final flashes = model.flashes;
    final canWrite = model.user != null && model.user!.isNew == false;
    return ClubScaffold(
      title: 'Üzenetek',
      showFlash: false,
      body: Column(
        children: [
          if (canWrite)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (context) => const MessageDeskPage()),
                        );
                      },
                      child: const Text('Beszélgetések'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (context) => const MessageComposePage()),
                        );
                      },
                      child: const Text('Új üzenet'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: flashes.isEmpty
                ? const EmptyNote('Nincs üzenet.')
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
              itemCount: flashes.length,
              itemBuilder: (context, index) {
                final flash = flashes[index];
                return Band(
                  index: index,
                  child: ListTile(
                    title: Text(flash.subject),
                    subtitle: Text(flash.body),
                    trailing: flash.unread ? const Icon(Icons.circle, size: 10, color: Color(0xFFE0B56A)) : null,
                    onTap: () => openFlash(context, flash),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Olvasatlan üzenet sávja a címsor alatt. Többnél a „még N” jelzi a többit.
class FlashBanner extends StatelessWidget {
  const FlashBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = AppScope.of(context).flashes.where((item) => item.unread).toList();
    if (unread.isEmpty) {
      return const SizedBox.shrink();
    }
    final flash = unread.first;
    final more = unread.length - 1;
    return Material(
      color: const Color(0xFF3E2618),
      child: InkWell(
        onTap: () => openFlash(context, flash),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined, color: Color(0xFFE0B56A)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  more > 0 ? '${flash.subject}  ·  még $more' : flash.subject,
                  style: const TextStyle(color: Color(0xFFFFF8EF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Olvasottnak jelöl, majd a céloldalra navigál.
Future<void> openFlash(BuildContext context, FlashNote flash) async {
  final model = AppScope.of(context);
  final navigator = Navigator.of(context);
  await model.markFlashSeen(flash.id);
  if (!context.mounted) {
    return;
  }
  switch (flash.target) {
    case 'member':
      // Elfogadott jelentkezés: a szerep taggá vált, a kezdőlap cserélődik.
      await model.reloadMe();
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    case 'registration':
      await _openRegistration(context, flash.targetId);
      return;
    case 'roster':
      if (model.user?.isPresident == true) {
        model.requestSection(3);
      }
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    case 'competition':
      if (model.user?.isPresident == true) {
        model.requestSection(1);
      }
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    case 'applicants':
      model.requestSection(0);
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    case 'profile':
      await navigator.pushNamed('/profile');
      return;
    case 'message':
      final threadId = flash.targetId;
      if (threadId != null && threadId.isNotEmpty) {
        await navigator.push(
          MaterialPageRoute<void>(builder: (context) => MessageThreadPage(threadId: threadId)),
        );
        return;
      }
      if (context.findAncestorWidgetOfExactType<FlashesPage>() == null) {
        await navigator.push(MaterialPageRoute<void>(builder: (context) => const FlashesPage()));
      }
      return;
    default:
      if (model.user?.isNew == true) {
        await model.reloadMe();
      }
      if (context.mounted) {
        navigator.popUntil((route) => route.isFirst);
      }
  }
}

/// A besorolás üzenete a saját nevezés szerkesztőjét nyitja.
Future<void> _openRegistration(BuildContext context, String? id) async {
  final model = AppScope.of(context);
  await model.loadHome();
  if (!context.mounted) {
    return;
  }
  final data = model.data;
  Registration? registration;
  for (final row in data?.registrations ?? const <Registration>[]) {
    if (row.id.toString() == id) {
      registration = row;
      break;
    }
  }
  Competition? competition;
  for (final item in data?.competitions ?? const <Competition>[]) {
    if (item.id == registration?.competitionId) {
      competition = item;
      break;
    }
  }
  if (registration == null || competition == null) {
    showMessage(context, 'A jelentkezés adatlapja már nem érhető el.');
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => RegistrationEditor(competition: competition!, registration: registration),
    ),
  );
}
