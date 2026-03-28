import 'package:fitforge/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';

// Import screens (to be created)
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/generating/generating_screen.dart';
import 'screens/main_shell/main_shell.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';

class FitForgeApp extends StatelessWidget {
  const FitForgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();

    final GoRouter router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: Listenable.merge([authProvider, userProvider]),
      redirect: (context, state) {
        if (authProvider.isLoading ||
            (authProvider.user != null && userProvider.isLoading)) {
          return null;
        }

        final isAuth = authProvider.user != null;
        final isAuthPage =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        final isSplash = state.matchedLocation == '/splash';
        final isOnboarding = state.matchedLocation == '/onboarding';
        final needsOnboarding =
            isAuth && (userProvider.userProfile?.onboardingComplete != true);

        if (!isAuth && !isAuthPage && !isSplash) {
          return '/login';
        }

        if (needsOnboarding && !isOnboarding) {
          return '/onboarding';
        }

        if (isAuth && isOnboarding && !needsOnboarding) {
          return '/home';
        }

        if (isAuth && isOnboarding && needsOnboarding) {
          return null;
        }

        if (isAuth && (isAuthPage || isSplash)) {
          return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/generating',
          builder: (context, state) => const GeneratingScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const MainShell()),
      ],
    );

    return MaterialApp.router(
      title: 'FitForge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: router,
    );
  }
}
