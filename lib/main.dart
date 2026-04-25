import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wsa_new/theme/app_theme.dart';
import 'package:wsa_new/screens/auth/login_screen.dart';
import 'package:wsa_new/screens/auth/signup_screen.dart';
import 'package:wsa_new/screens/role_selection_screen.dart';
import 'package:wsa_new/screens/user/user_home.dart';
import 'package:wsa_new/screens/guardian/guardian_home.dart';
import 'package:wsa_new/providers/app_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wsa_new/firebase_options.dart';
import 'package:wsa_new/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FCM background handler BEFORE Firebase.initializeApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  debugPrint("Main: Starting app initialization...");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.init();
  
  debugPrint("Main: Calling runApp...");
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const WomenSafetyApp(),
    ),
  );
}

class WomenSafetyApp extends StatelessWidget {
  const WomenSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Women Safety App',
      theme: AppTheme.darkTheme,
      home: _getInitialScreen(appState),
      routes: {
        '/roles': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/user_home': (context) => const UserHomeWrapper(),
        '/guardian_home': (context) => const GuardianHomeWrapper(),
      },
    );
  }

  Widget _getInitialScreen(AppState appState) {
    if (appState.currentUser == null) {
      return const LoginScreen();
    }
    return appState.currentUser!.role == 'guardian'
        ? const GuardianHomeWrapper()
        : const UserHomeWrapper();
  }
}
