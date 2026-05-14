import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/tournament_provider.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final authService = AuthService();

  await authService.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),

        ChangeNotifierProvider<TournamentProvider>(
          create: (_) => TournamentProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}