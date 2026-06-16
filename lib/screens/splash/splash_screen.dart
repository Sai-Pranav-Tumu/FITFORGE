import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  double _barWidth = 0.0;

  // The splash stays on screen until the app is genuinely ready to show real
  // content (auth + profile + the first workout plan), with a small minimum so
  // it doesn't flash and a maximum so a slow backend can never trap the user.
  static const Duration _minimumSplash = Duration(milliseconds: 800);
  static const Duration _maximumSplash = Duration(seconds: 8);
  final DateTime _start = DateTime.now();
  bool _navigated = false;
  Timer? _minimumTimer;
  Timer? _maximumTimer;
  AuthProvider? _authProvider;
  UserProvider? _userProvider;
  WorkoutProvider? _workoutProvider;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial delay for animation starting
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _barWidth = 0.65; // 65% width
        });
      }
    });

    _authProvider = context.read<AuthProvider>();
    _userProvider = context.read<UserProvider>();
    _workoutProvider = context.read<WorkoutProvider>();
    _authProvider!.addListener(_maybeLeaveSplash);
    _userProvider!.addListener(_maybeLeaveSplash);
    _workoutProvider!.addListener(_maybeLeaveSplash);
    // Safety cap: never trap the user on the splash if something stalls.
    _maximumTimer = Timer(_maximumSplash, _leaveSplash);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLeaveSplash());
  }

  /// Whether the app has loaded enough that the destination screen will show
  /// real content instead of a bare loading spinner.
  bool _isAppReady() {
    final auth = _authProvider!;
    if (auth.isLoading) return false;
    if (auth.user == null) return true; // -> login screen, nothing more to load

    final user = _userProvider!;
    if (user.isLoading) return false; // profile still resolving
    final profile = user.userProfile;
    if (profile == null) return true; // redirect will send to login
    if (profile.onboardingComplete != true) return true; // -> onboarding

    // Authed + onboarded: we'll land on the workout home, so wait until it has
    // an actual plan ready (or a download prompt / error) rather than a spinner.
    final workout = _workoutProvider!;
    return workout.recommendation != null ||
        workout.shouldShowDownloadPrompt ||
        workout.error != null;
  }

  /// Leaves the splash once the app is ready and the minimum brand moment has
  /// elapsed. While the app is still loading, this stays put and animates.
  void _maybeLeaveSplash() {
    if (_navigated || !mounted) return;
    if (!_isAppReady()) return;

    final remaining = _minimumSplash - DateTime.now().difference(_start);
    if (remaining > Duration.zero) {
      _minimumTimer ??= Timer(remaining, _maybeLeaveSplash);
      return;
    }

    _leaveSplash();
  }

  void _leaveSplash() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/home'); // redirect corrects to /login or /onboarding if needed
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    _authProvider?.removeListener(_maybeLeaveSplash);
    _userProvider?.removeListener(_maybeLeaveSplash);
    _workoutProvider?.removeListener(_maybeLeaveSplash);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D13),
      body: Stack(
        children: [
          // Radial Gradient Glow Background
          Center(
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandIndigo.withValues(alpha: 0.22),
                    blurRadius: 120,
                    spreadRadius: 24,
                  ),
                  BoxShadow(
                    color: AppTheme.brandViolet.withValues(alpha: 0.14),
                    blurRadius: 90,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.heroGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandIndigo.withValues(alpha: 0.45),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 62,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFC9D0FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: Text(
                    'FITFORGE',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'YOUR AI FITNESS COACH',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Loading Bar Section
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * 0.15,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  // The Loading Bar
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2533),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeOut,
                            width: constraints.maxWidth * _barWidth,
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: AppTheme.heroGradient,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.brandIndigo.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INITIALIZING BIO-ENGINE',
                        style: TextStyle(
                          color: colorScheme.outline,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Text(
                        '65%',
                        style: TextStyle(
                          color: AppTheme.primaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
