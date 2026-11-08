/*
 * Közös felület: állapothozzáférés, címsor, kártya, csíkozott sor, splash.
 *
 * A ClubScaffold a címsor és a csengő. A fiók és a téma az oldalmenüben van. A Band minden második
 * sort eltérő háttérrel és vékony választóvonallal rajzolja.
 */
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../screens/flashes.dart';
import '../screens/settings_page.dart';
import '../state/app_model.dart';

/// Az AppModel elérése a fából: AppScope.of(context).
class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel model, required super.child, super.key}) : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Az AppScope hiányzik.');
    return scope!.notifier!;
  }
}

/// Fehér logo sötét háttérre, fekete logo világos háttérre.
String clubLogoAsset({required bool onDarkBackground}) {
  return onDarkBackground
      ? 'assets/branding/logo_feher_fekete_hatterhez.png'
      : 'assets/branding/logo_fekete_feher_hatterhez.png';
}

/// Egyetlen indítóképernyő: logo és arany pörgettyű, felirat nélkül.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF100E0C) : const Color(0xFFF3EEE4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              clubLogoAsset(onDarkBackground: dark),
              width: 300,
              height: 300,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFE0B56A)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kis logo a címsorban és a belépőn.
class ClubMark extends StatelessWidget {
  const ClubMark({this.size = 36, this.onDarkBackground, super.key});

  final double size;
  final bool? onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final dark = onDarkBackground ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      clubLogoAsset(onDarkBackground: dark),
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Profilkép, vagy a név kezdőbetűje, ha nincs kép.
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.name, this.url, this.radius = 18, super.key});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = sizedPhoto(url, (radius * 4).round());
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: photo == null ? null : NetworkImage(photo),
      onForegroundImageError: photo == null ? null : (_, _) {},
      child: Text(
        letter,
        style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: radius * 0.85),
      ),
    );
  }
}

/// A címsor jobb szélső gombja: világos és sötét téma.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({this.onDarkBar = false, super.key});

  final bool onDarkBar;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = onDarkBar || dark ? const Color(0xFFFFF8EF) : const Color(0xFF3E2618);
    return IconButton(
      tooltip: dark ? 'Világos téma' : 'Sötét téma',
      color: color,
      onPressed: () => AppScope.of(context).toggleTheme(Theme.of(context).brightness),
      icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
    );
  }
}

/// Oldalról becsúszó menü. A címsorral egy sávban a logó van, a sötét sávra a világos változat kerül.
class ClubDrawer extends StatelessWidget {
  const ClubDrawer({required this.children, this.showAccount = false, super.key});

  final List<Widget> children;
  final bool showAccount;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bar = dark ? const Color(0xFF1A1613) : const Color(0xFF3E2618);
    final onBar = dark ? const Color(0xFFF6E7C8) : const Color(0xFFFFF8EF);
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: bar,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const ClubMark(size: 34, onDarkBackground: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ibafai Pipaklub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: onBar, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showAccount) const _DrawerAccount(),
          Expanded(
            child: ListTileTheme(
              data: ListTileThemeData(
                selectedColor: dark ? const Color(0xFFE0B56A) : const Color(0xFF6E3B24),
                selectedTileColor: dark ? const Color(0xFF2A241C) : const Color(0xFFF3E6D4),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A kezdőlap menüje nélkül: profilkép, Profil és Beállítások.
class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubDrawer(
      showAccount: true,
      children: accountDrawerTiles(context),
    );
  }
}

/// Profil, beállítások és kijelentkezés. Az elnöki menü aljára is ez kerül.
List<Widget> accountDrawerTiles(BuildContext context) {
  final model = AppScope.of(context);
  return [
    ListTile(
      title: const Text('Profil'),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).pushNamed('/profile');
      },
    ),
    ListTile(
      title: const Text('Beállítások'),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => const SettingsPage()),
        );
      },
    ),
    ListTile(
      title: const Text('Kijelentkezés'),
      onTap: () {
        Navigator.of(context).pop();
        model.logout();
      },
    ),
  ];
}

class _DrawerAccount extends StatelessWidget {
  const _DrawerAccount();

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    final name = user == null || user.name.trim().isEmpty ? (user?.email ?? '') : user.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          UserAvatar(name: name, url: model.ownPhoto, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name.isEmpty ? 'Fiók' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Közös váz. A címsorban a cím van, logó nélkül. A fiók az oldalmenüben van.
class ClubScaffold extends StatelessWidget {
  const ClubScaffold({
    required this.title,
    required this.body,
    this.bottom,
    this.drawer,
    this.showFlash = true,
    this.isHome = false,
    super.key,
  });

  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;
  final Widget? drawer;
  final bool showFlash;

  /// Főképernyő: hamburger menü, visszanyíl nélkül.
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    final navigatorCanPop = Navigator.of(context).canPop();
    final canPop = !isHome && navigatorCanPop;
    final menu = drawer ?? (user == null ? null : const AccountDrawer());
    return PopScope(
      canPop: !isHome || !navigatorCanPop,
      child: Scaffold(
      drawer: menu,
      appBar: AppBar(
        automaticallyImplyLeading: menu != null && !canPop,
        leading: canPop ? const BackButton() : null,
        titleSpacing: canPop ? 0 : 12,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: bottom,
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Üzenetek',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => const FlashesPage()),
                );
              },
              icon: Badge(
                isLabelVisible: model.unreadFlashes > 0,
                label: Text('${model.unreadFlashes}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (showFlash && model.unreadFlashes > 0) const FlashBanner(),
          Expanded(child: body),
        ],
      ),
    ),
    );
  }
}

/// Lista sor: páros és páratlan háttér, alul vékony választóvonal.
class Band extends StatelessWidget {
  const Band({required this.index, required this.child, super.key});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final line = dark ? const Color(0xFF5C4A32) : const Color(0xFFCDB89A);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: index.isOdd ? (dark ? const Color(0xFF322A22) : const Color(0xFFE8D7BE)) : null,
        border: Border(bottom: BorderSide(color: line, width: 0.8)),
      ),
      child: child,
    );
  }
}

/// Külső böngésző. A verseny leírásának pipaclub.hu linkje ide megy.
Future<void> openInBrowser(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    showMessage(context, 'A link nem nyitható meg.');
    return;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showMessage(context, 'A böngésző nem nyitható meg.');
    }
  } catch (error) {
    if (context.mounted) {
      showMessage(context, 'A böngésző nem nyitható meg.');
    }
  }
}

/// Kerek kártya címmel. A [bandIndex] csíkot tesz a kártyák közé.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.title, this.trailing, this.bandIndex, super.key});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final int? bandIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final banded = bandIndex != null && bandIndex!.isOdd;
    final line = dark ? const Color(0xFF5C4A32) : const Color(0xFFCDB89A);
    final card = Card(
      color: banded ? (dark ? const Color(0xFF322A22) : const Color(0xFFE8D7BE)) : null,
      margin: EdgeInsets.only(bottom: bandIndex == null ? 14 : 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Text(title!, style: theme.textTheme.titleMedium)),
                    ?trailing,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
    if (bandIndex == null) {
      return card;
    }
    return Column(
      children: [
        card,
        Divider(height: 14, thickness: 0.8, color: line),
      ],
    );
  }
}

/// Üres lista szövege.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

/// Betöltési hiba és újrapróbálás.
class LoadProblem extends StatelessWidget {
  const LoadProblem({required this.message, required this.onRetry, super.key});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClubMark(size: 72),
            const SizedBox(height: 18),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Újrapróbálom')),
          ],
        ),
      ),
    );
  }
}

/// Megerősítő párbeszéd. Igaz, ha a jobb gombot nyomták.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String text,
  String ok = 'Igen',
  String cancel = 'Mégse',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(ok),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Határidő utáni indok. Üresen nem lehet menteni.
Future<String?> askAbsenceReason(BuildContext context, {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Nem tudok jönni'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Miért nem tudsz jönni?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mégse')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('Mentés'),
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

/// Rövid üzenet a képernyő alján.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Régi HTML megjelenítése. Az új kiírások linket használnak helyette.
class HtmlBlock extends StatelessWidget {
  const HtmlBlock({required this.html, super.key});

  final String html;

  @override
  Widget build(BuildContext context) {
    final data = html.trim();
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    final style = Theme.of(context).textTheme.bodyMedium;
    return HtmlWidget(
      data,
      textStyle: style,
      onTapUrl: (url) async {
        if (!httpUrl(url)) {
          return false;
        }
        final uri = Uri.tryParse(url);
        if (uri == null) {
          return false;
        }
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}

/// ApiException szövege, más hibánál általános mondat.
String friendlyError(Object error) {
  final text = error.toString().replaceFirst('ApiException: ', '').trim();
  if (text.isEmpty) {
    return 'A művelet nem sikerült.';
  }
  return text;
}
