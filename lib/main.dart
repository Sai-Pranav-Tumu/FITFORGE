import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/nutrition_provider.dart';
import 'providers/water_provider.dart';
import 'providers/diet_plan_provider.dart';
import 'services/nutrition_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the generated options from `flutterfire configure`
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, authProvider, userProvider) {
            final provider = userProvider ?? UserProvider();
            provider.syncAuthUser(authProvider.user);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          UserProvider,
          NutritionProvider
        >(
          create: (_) => NutritionProvider(),
          update: (_, authProvider, userProvider, nutritionProvider) {
            final provider = nutritionProvider ?? NutritionProvider();
            provider.sync(authProvider.user, userProvider.userProfile);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<AuthProvider, UserProvider, WaterProvider>(
          create: (_) => WaterProvider(),
          update: (_, authProvider, userProvider, waterProvider) {
            final provider = waterProvider ?? WaterProvider();
            provider.sync(authProvider.user, userProvider.userProfile);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, DietPlanProvider>(
          create: (_) => DietPlanProvider(),
          update: (_, authProvider, dietPlanProvider) {
            final provider = dietPlanProvider ?? DietPlanProvider();
            provider.sync(authProvider.user?.uid);
            return provider;
          },
        ),
      ],
      child: const FitForgeApp(),
    ),
  );

  // Keep startup fast: initialize nutrition DB/import in background.
  NutritionService.instance.initialize().catchError((error, stack) {
    debugPrint('Nutrition init failed: $error');
  });

  NotificationService.instance.initialize().catchError((error, stack) {
    debugPrint('Notification init failed: $error');
  });
}
