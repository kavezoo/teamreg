import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../state/app_model.dart';

class AppScope extends InheritedNotifier<AppModel> {
  const AppScope({required AppModel model, required super.child, super.key}) : super(notifier: model);

  static AppModel of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Az AppScope hiányzik.');
    return scope!.notifier!;
  }
}

String clubLogoAsset({required bool onDarkBackground}) {
  return onDarkBackground
      ? 'assets/branding/logo_feher_fekete_hatterhez.png'
      : 'assets/branding/logo_fekete_feher_hatterhez.png';
}

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
            const SizedBox(height: 20),
            Text(
              'Betöltés...',
              style: TextStyle(
                color: dark ? const Color(0xFFD9CBB2) : const Color(0xFF3E2618),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 18),
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

class ClubScaffold extends StatelessWidget {
  const ClubScaffold({required this.title, required this.body, this.bottom, super.key});

  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final user = model.user;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            const ClubMark(size: 34, onDarkBackground: true),
            const SizedBox(width: 10),
            Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        bottom: bottom,
        actions: [
          if (user != null && !user.isNew)
            PopupMenuButton<String>(
              tooltip: 'Fiók',
              onSelected: (value) async {
                if (value == 'profile') {
                  await Navigator.of(context).pushNamed('/profile');
                } else if (value == 'logout') {
                  await model.logout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(user.name.isEmpty ? user.email : user.name),
                ),
                const PopupMenuItem(value: 'profile', child: Text('Saját adatok')),
                const PopupMenuItem(value: 'logout', child: Text('Kijelentkezés')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: UserAvatar(name: user.name, url: model.ownPhoto, radius: 16),
              ),
            ),
          if (user != null && user.isNew)
            IconButton(
              tooltip: 'Kijelentkezés',
              onPressed: model.logout,
              icon: const Icon(Icons.logout),
            ),
          const ThemeToggleButton(onDarkBar: true),
        ],
      ),
      body: body,
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, this.title, this.trailing, super.key});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
  }
}

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

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

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

String friendlyError(Object error) {
  final text = error.toString().replaceFirst('ApiException: ', '').trim();
  if (text.isEmpty) {
    return 'A művelet nem sikerült.';
  }
  return text;
}
