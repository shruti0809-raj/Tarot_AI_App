import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/welcome_intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_selection_screen.dart';
import 'screens/deck_spread/deck_spread_love.dart';
import 'screens/deck_spread/deck_spread_career.dart';
import 'screens/deck_spread/deck_spread_sunsign.dart';
import 'screens/deck_spread/deck_spread_fullmoon.dart';
import 'screens/deck_spread/deck_spread_personal.dart';
import 'screens/deck_spread/deck_spread_angel.dart';
import 'screens/deck_reveal/deck_reveal_love.dart';
import 'screens/deck_reveal/deck_reveal_career.dart';
import 'screens/deck_reveal/deck_reveal_sunsign.dart';
import 'screens/deck_reveal/deck_reveal_fullmoon.dart';
import 'screens/deck_reveal/deck_reveal_personal.dart';
import 'screens/deck_reveal/deck_reveal_angel.dart';
import 'screens/final_reading/final_reading_screen.dart';
import 'screens/legal/privacy_policy_screen.dart';
import 'screens/legal/terms_conditions_screen.dart';
import 'screens/legal/refund_policy_screen.dart';
import 'screens/legal/data_deletion_screen.dart';
import 'screens/user/billing_history_screen.dart';
import 'screens/user/help_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/saved_readings_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/report_content_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();
  await _initializeNotifications();
  runApp(const DivineGuidanceApp());
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class DivineGuidanceApp extends StatelessWidget {
  const DivineGuidanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Divine Guidance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
      ),
      // initialRoute removed; AuthGate decides start screen
      home: const AuthGate(),

      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/':
            return MaterialPageRoute(builder: (_) => const WelcomeIntroScreen());
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => const HomeSelectionScreen());
          case '/privacy':
            return MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen());
          case '/terms':
            return MaterialPageRoute(builder: (_) => const TermsConditionsScreen());
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case '/report':
            return MaterialPageRoute(builder: (_) => const ReportContentScreen());
          case '/saved':
            return MaterialPageRoute(builder: (_) => const SavedReadingsScreen());
          case '/billing':
            return MaterialPageRoute(builder: (_) => const BillingHistoryScreen());
          case '/help':
            return MaterialPageRoute(builder: (_) => const HelpScreen());
          case '/refund-policy':
            return MaterialPageRoute(builder: (_) => const RefundPolicyScreen());
          case '/data-deletion':
            return MaterialPageRoute(builder: (_) => const DataDeletionPolicyScreen());
          case '/love-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadLoveScreen());
          case '/career-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadCareerScreen());
          case '/sunsign-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadSunSignScreen());
          case '/fullmoon-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadFullMoonScreen());
          case '/personal-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadPersonalScreen());
          case '/angel-spread':
            return MaterialPageRoute(builder: (_) => const DeckSpreadAngelScreen());
          case '/deck-reveal-love': {
            final args = settings.arguments as Map<String, List<String>>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealLove(selectedCardsByDeck: args),
            );
          }
          case '/deck-reveal-career': {
            final args = settings.arguments as Map<String, List<String>>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealCareer(selectedCardsByDeck: args),
            );
          }
          case '/deck-reveal-angel': {
            final args = settings.arguments as Map<String, List<String>>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealAngel(selectedCardsByDeck: args),
            );
          }
          case '/deck-reveal-fullmoon': {
            final args = settings.arguments as Map<String, List<String>>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealFullMoon(selectedCardsByDeck: args),
            );
          }
          case '/deck-reveal-personal': {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealPersonal(
                question: args['question'],
                selectedCardsByDeck: args['selectedCardsByDeck'],
              ),
            );
          }
          case '/deck-reveal-sunsign': {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => DeckRevealSunSign(
                sunSign: args['sunSign'],
                selectedCardsByDeck: args['selectedCardsByDeck'],
              ),
            );
          }
          case '/final-reading': {
            final args = (settings.arguments ?? {}) as Map;

            Map<String, List<String>> cardsFromRoute = {};
            if (args.containsKey('cards') && args['cards'] is Map) {
              final raw = args['cards'] as Map;
              raw.forEach((k, v) {
                if (v is List) {
                  cardsFromRoute[k.toString()] =
                      v.map((e) => e.toString()).toList();
                }
              });
            } else {
              args.forEach((k, v) {
                if (v is List) {
                  cardsFromRoute[k.toString()] =
                      v.map((e) => e.toString()).toList();
                }
              });
            }

            return MaterialPageRoute(
              builder: (_) => FinalReadingScreen(
                selectedCardsByDeck: cardsFromRoute,
              ),
              settings: settings,
            );
          }

          // /checkout route removed (paywall now purchases directly)

          default:
            return null;
        }
      },
    );
  }
}

/// Routes based on current Firebase Auth state (keeps user signed in on device).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While Firebase restores the session, show a lightweight splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }

        final user = snapshot.data;

        if (user != null) {
          // Already signed in on this device → straight to Home
          return const HomeSelectionScreen();
        }

        // Not signed in yet → your intro/onboarding/login flow
        return const WelcomeIntroScreen();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
    }
}
