import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initiate session restoration on app start
  AuthManager.instance.restoreSession();
  runApp(const AiNewsApp());
}

class AiNewsApp extends StatelessWidget {
  const AiNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI News Aggregator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: AuthManager.instance,
        builder: (context, child) {
          final auth = AuthManager.instance;
          switch (auth.status) {
            case AuthStatus.initializing:
              return const SplashScreen();
            case AuthStatus.authenticated:
              return DashboardScreen(email: auth.userEmail ?? '');
            case AuthStatus.sessionExpired:
              return AuthScreen(sessionExpiredMessage: auth.errorMessage);
            case AuthStatus.unauthenticated:
            case AuthStatus.refreshing:
            case AuthStatus.loggingOut:
              return const AuthScreen();
          }
        },
      ),
    );
  }
}
