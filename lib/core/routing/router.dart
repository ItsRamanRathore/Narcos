import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/session_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/lockout_screen.dart';
import '../../features/auth/presentation/registration_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/capture/presentation/screens/camera_screen.dart';
import '../../features/calibration/domain/calibration_result.dart';
import '../../features/analysis/presentation/screens/analysis_screen.dart';
import '../database/database_service.dart';

// Provides the router
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/registration',
        builder: (context, state) => RegistrationScreen(),
      ),
      GoRoute(
        path: '/inactivity_lock',
        builder: (context, state) => PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(title: const Text('Session Locked')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Your session is locked due to inactivity.'),
                  ElevatedButton(
                    onPressed: () {
                      // Implement PIN unlock logic here, which will call
                      // ref.read(sessionProvider.notifier).unlockSession(wrapKey)
                    },
                    child: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/lockout',
        builder: (context, state) => const PopScope(
          canPop: false,
          child: LockoutScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: '/analysis',
        builder: (context, state) {
          final result = state.extra as CalibrationResult;
          return AnalysisScreen(calibrationResult: result);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text('Navigation error: \${state.error}')),
    ),
  );
});

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  String? _previousLocation;

  RouterNotifier(this._ref) {
    _ref.listen(sessionProvider, (_, __) => notifyListeners());
  }

  Future<String?> redirect(BuildContext context, GoRouterState state) async {
    final session = _ref.read(sessionProvider);

    // If first run, go to registration (Check DB directly or via a cached provider, but for async we need to be careful)
    // To prevent async gaps in redirect, let's assume we check it here (GoRouter supports async redirect)
    final db = DatabaseService();
    final isFirstRun = await db.isFirstRun();
    if (isFirstRun && state.matchedLocation != '/registration' && state.matchedLocation != '/login') {
      return '/registration';
    }

    // Now handle session states
    switch (session.lockState) {
      case SessionLockState.active:
        // Check onboarding
        final dbInstance = await db.database;
        final prefs = await dbInstance.query('app_preferences', where: 'key = ?', whereArgs: ['onboarding_complete']);
        final onboardingComplete = prefs.isNotEmpty && prefs.first['value'] == '1';
        
        if (!onboardingComplete && state.matchedLocation != '/onboarding') {
          return '/onboarding';
        }
        
        if (state.matchedLocation == '/login' || state.matchedLocation == '/registration' || state.matchedLocation == '/inactivity_lock') {
          final target = _previousLocation ?? '/home';
          _previousLocation = null;
          return target;
        }
        return null; // allow

      case SessionLockState.inactivityLocked:
        if (state.matchedLocation != '/inactivity_lock') {
          if (state.matchedLocation != '/login' && state.matchedLocation != '/registration') {
            _previousLocation = state.matchedLocation;
          }
          return '/inactivity_lock';
        }
        return null;

      case SessionLockState.expired:
      case SessionLockState.unauthenticated:
        if (state.matchedLocation != '/login' && state.matchedLocation != '/registration') {
          return '/login';
        }
        return null;

      case SessionLockState.lockedOut:
        if (state.matchedLocation != '/lockout') {
          return '/lockout';
        }
        return null;
    }
  }
}
