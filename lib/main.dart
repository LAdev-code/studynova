import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/gemini_service.dart';
import 'services/database_service.dart';
import 'services/paywall_manager.dart';
import 'services/theme_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/recording/recording_screen.dart';
import 'features/practice/talkback_screen.dart';
import 'features/canvas/study_canvas.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/space/my_space_screen.dart';
import 'ui/paywall_screen.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Will be available after build

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ThemeService.initialize();

  // Initialize RevenueCat first to get entitlement status
  await PaywallManager.init();

  // Initialize other services
  const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  final geminiService = GeminiService(
    apiKey: geminiApiKey,
  );
  final databaseService = DatabaseService();

  runApp(MyApp(geminiService: geminiService, databaseService: databaseService));
}

class MyApp extends StatelessWidget {
  final GeminiService geminiService;
  final DatabaseService databaseService;

  const MyApp({
    super.key,
    required this.geminiService,
    required this.databaseService,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: ThemeService.primaryColor,
      builder: (context, color, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, mode, child) {
            return ValueListenableBuilder<Locale>(
              valueListenable: ThemeService.locale,
              builder: (context, locale, child) {
                return MaterialApp(
                  title: 'Study Nova',
                  debugShowCheckedModeBanner: false,
                  themeMode: mode,
                  locale: const Locale('en'),
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    final savedLocale = ThemeService.locale.value;
                    if (supportedLocales.any(
                      (supportedLocale) =>
                          supportedLocale.languageCode ==
                          savedLocale.languageCode,
                    )) {
                      return savedLocale;
                    }
                    if (deviceLocale != null) {
                      for (final supportedLocale in supportedLocales) {
                        if (supportedLocale.languageCode ==
                            deviceLocale.languageCode) {
                          return supportedLocale;
                        }
                      }
                    }
                    return const Locale('en');
                  },
                  localizationsDelegates: const [
                    S.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: S.supportedLocales,
                  theme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: color,
                      brightness: Brightness.light,
                    ),
                    appBarTheme: const AppBarTheme(
                      centerTitle: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                  ),
                  darkTheme: ThemeData(
                    useMaterial3: true,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: color,
                      brightness: Brightness.dark,
                    ),
                    appBarTheme: const AppBarTheme(
                      centerTitle: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                  ),
                  home: FutureBuilder<bool>(
                    future: _shouldShowOnboarding(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final showOnboarding = snapshot.data ?? true;
                      if (showOnboarding) {
                        return OnboardingScreen(
                          geminiService: geminiService,
                          databaseService: databaseService,
                        );
                      }

                      return MainNavigation(
                        geminiService: geminiService,
                        databaseService: databaseService,
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

Future<bool> _shouldShowOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('first_launch') ?? true;
}

class MainNavigation extends StatefulWidget {
  final GeminiService geminiService;
  final DatabaseService databaseService;
  static final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  const MainNavigation({
    super.key,
    required this.geminiService,
    required this.databaseService,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    MainNavigation.selectedIndexNotifier.addListener(() {
      setState(() {});
    });
    _screens = [
      InboxScreen(
        geminiService: widget.geminiService,
        databaseService: widget.databaseService,
      ),
      RecordingScreen(
        geminiService: widget.geminiService,
        databaseService: widget.databaseService,
      ),
      TalkBackScreen(
        geminiService: widget.geminiService,
        databaseService: widget.databaseService,
      ),
      StudyCanvas(databaseService: widget.databaseService),
      MySpaceScreen(databaseService: widget.databaseService),
    ];
  }

  @override
  void dispose() {
    MainNavigation.selectedIndexNotifier.removeListener(() {});
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Entitlement Gate: TalkBack AI Tutor (index 2) is a PRO feature
    if (index == 2 && !PaywallManager.isProNotifier.value) {
      PaywallScreen.show(context);
      return;
    }

    MainNavigation.selectedIndexNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.inbox_outlined),
        selectedIcon: const Icon(Icons.inbox),
        label: l10n.smartInbox,
      ),
      NavigationDestination(
        icon: const Icon(Icons.mic_none),
        selectedIcon: const Icon(Icons.mic),
        label: 'Record',
      ),
      NavigationDestination(
        icon: const Icon(Icons.record_voice_over_outlined),
        selectedIcon: const Icon(Icons.record_voice_over),
        label: 'TalkBack',
      ),
      NavigationDestination(
        icon: const Icon(Icons.brush_outlined),
        selectedIcon: const Icon(Icons.brush),
        label: 'Canvas',
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.mySpace,
      ),
    ];

    return Scaffold(
      body: _screens[MainNavigation.selectedIndexNotifier.value],
      bottomNavigationBar: NavigationBar(
        selectedIndex: MainNavigation.selectedIndexNotifier.value,
        onDestinationSelected: _onItemTapped,
        destinations: destinations,
      ),
    );
  }
}
