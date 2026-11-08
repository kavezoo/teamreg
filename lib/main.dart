/*
 * Az alkalmazás belépési pontja.
 *
 * A téma a splash előtt betöltődik, utána a szerep választ képernyőt:
 * nincs belépés → login, új tag → NewHome, tag → MemberHome,
 * klubelnök és admin → PresidentHome.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/flashes.dart';
import 'screens/login_screen.dart';
import 'screens/member_home.dart';
import 'screens/messages.dart';
import 'screens/new_home.dart';
import 'screens/president_home.dart';
import 'screens/profile_page.dart';
import 'state/app_model.dart';
import 'theme/club_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  // A mentett világos/sötét mód a splash előtt érvényesül.
  await model.loadTheme();
  runApp(TeamRegApp(model: model));
}

/// A MaterialApp, a téma és a szerep szerinti kezdőképernyő.
class TeamRegApp extends StatefulWidget {
  const TeamRegApp({required this.model, super.key});

  final AppModel model;

  @override
  State<TeamRegApp> createState() => _TeamRegAppState();
}

class _TeamRegAppState extends State<TeamRegApp> with WidgetsBindingObserver {
  late final AppModel _model = widget.model;
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _watchedUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model.bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Előtérbe kerüléskor frissül a szerep, például ha közben elfogadták a jelentkezést.
    if (state == AppLifecycleState.resumed) {
      _model.refreshIdentity();
      _consumeOpen();
    }
  }

  /// Értesítésből a beszélgetésre vagy az üzenetlistára visz.
  Future<void> _consumeOpen() async {
    final open = await _model.takeNotification();
    if (!mounted || open == null) {
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    await _model.markFlashSeen(open.id);
    final threadId = open.targetId;
    if (open.target == 'message' && threadId != null && threadId.isNotEmpty) {
      await navigator.push(
        MaterialPageRoute<void>(builder: (context) => MessageThreadPage(threadId: threadId)),
      );
      return;
    }
    await navigator.push(MaterialPageRoute<void>(builder: (context) => const FlashesPage()));
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: _model,
      child: ListenableBuilder(
        listenable: _model,
        builder: (context, _) {
          final user = _model.user;
          if (_model.ready && user != null && _watchedUser != user.id) {
            _watchedUser = user.id;
            WidgetsBinding.instance.addPostFrameCallback((_) => _consumeOpen());
          }
          if (user == null) {
            _watchedUser = null;
          }
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Ibafai Pipaklub',
            theme: ClubTheme.light(),
            darkTheme: ClubTheme.dark(),
            themeMode: _model.themeMode,
            debugShowCheckedModeBanner: false,
            locale: const Locale('hu'),
            supportedLocales: const [Locale('hu')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final theme = Theme.of(context);
              final light = theme.brightness == Brightness.light;
              final bar = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
              final background = theme.scaffoldBackgroundColor;
              // Világos témán a rendszer sávok feketék, sötét témán a klub sáv színe.
              final systemBar = light ? Colors.black : bar;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: light ? Colors.black : Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                  systemNavigationBarColor: light ? Colors.black : Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.light,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarContrastEnforced: false,
                ),
                child: ColoredBox(
                  color: background,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: media.padding.top,
                        child: ColoredBox(color: systemBar),
                      ),
                      if (light)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: media.padding.bottom,
                          child: const ColoredBox(color: Colors.black),
                        ),
                      Padding(
                        padding: media.padding,
                        child: MediaQuery(
                          data: media.removePadding(
                            removeTop: true,
                            removeBottom: true,
                            removeLeft: true,
                            removeRight: true,
                          ),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            routes: {
              '/profile': (context) => const ProfilePage(),
            },
            home: KeyedSubtree(
              // Szerepváltáskor újraépül a kezdőképernyő, különben a régi home maradna.
              key: ValueKey(_model.ready ? '${user?.id ?? 'out'}:${user?.role ?? ''}' : 'splash'),
              child: _home(_model),
            ),
          );
        },
      ),
    );
  }
}

/// Szerep szerinti kezdőképernyő. Az admin is a klubelnök felületét kapja.
Widget _home(AppModel model) {
  if (!model.ready) {
    return const BrandSplash();
  }
  final user = model.user;
  if (user == null) {
    return const LoginScreen();
  }
  if (user.isPresident) {
    return const PresidentHome();
  }
  if (user.isMember) {
    return const MemberHome();
  }
  return const NewHome();
}

