import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/common.dart';
import 'editors.dart';

class FlashesPage extends StatelessWidget {
  const FlashesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flashes = AppScope.of(context).flashes;
    return ClubScaffold(
      title: 'Üzenetek',
      showFlash: false,
      body: flashes.isEmpty
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
    );
  }
}

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

Future<void> openFlash(BuildContext context, FlashNote flash) async {
  final model = AppScope.of(context);
  final navigator = Navigator.of(context);
  await model.markFlashSeen(flash.id);
  if (!context.mounted) {
    return;
  }
  switch (flash.target) {
    case 'member':
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
