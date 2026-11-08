/*
 * Belépés Google-fiókkal.
 *
 * Nincs külön adatkezelési jelölőnégyzet: a gomb fölötti szöveg mondja,
 * hogy a belépéssel a nyilatkozat elfogadott. A splash felirata itt sem jelenik meg.
 */
import 'package:flutter/material.dart';

import '../privacy.dart';
import '../widgets/common.dart';

/// Google-gomb, hibaüzenet és a nyilatkozat megnyitása.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final message = await AppScope.of(context).signInWithGoogle();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = AppScope.of(context);
    final notice = model.notice;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          const ThemeToggleButton(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            const Center(child: ClubMark(size: 148)),
            const SizedBox(height: 22),
            Text(
              'Ibafai Pipaklub',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Jelentkezés Hagyományőrző Lassúsági Pipaszívó Versenyre',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            if (notice != null) ...[
              MaterialBanner(
                content: Text(notice),
                actions: [
                  TextButton(
                    onPressed: model.clearNotice,
                    child: const Text('Rendben'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'A belépés a telefon Google-fiókjával történik. A jelszót az alkalmazás nem kéri és nem tárolja.',
                    ),
                    const SizedBox(height: 12),
                    const Text('A belépéssel elfogadod az adatkezelési feltételeket.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _signIn,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.account_circle),
                      label: const Text('Belépés Google-fiókkal'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => showPrivacy(context),
              child: const Text('Adatkezelési nyilatkozat'),
            ),
          ],
        ),
      ),
    );
  }
}
