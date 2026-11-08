import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/member_home.dart';
import 'screens/new_home.dart';
import 'screens/president_home.dart';
import 'screens/profile_page.dart';
import 'state/app_model.dart';
import 'theme/club_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  await model.loadTheme();
  runApp(TeamRegApp(model: model));
}

class TeamRegApp extends StatefulWidget {
  const TeamRegApp({required this.model, super.key});

  final AppModel model;

  @override
  State<TeamRegApp> createState() => _TeamRegAppState();
}

class _TeamRegAppState extends State<TeamRegApp> with WidgetsBindingObserver {
  late final AppModel _model = widget.model;

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
    if (state == AppLifecycleState.resumed) {
      _model.refreshIdentity();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      model: _model,
      child: ListenableBuilder(
        listenable: _model,
        builder: (context, _) {
          final user = _model.user;
          return MaterialApp(
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
              key: ValueKey(_model.ready ? '${user?.id ?? 'out'}:${user?.role ?? ''}' : 'splash'),
              child: _home(_model),
            ),
          );
        },
      ),
    );
  }
}

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

