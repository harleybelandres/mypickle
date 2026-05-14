import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/tournament_provider.dart';
import 'services/local_db_service.dart';
import 'services/seed_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDbService.instance.init();

  // Seed local dev data (admin/user accounts + approved tournaments).
  await SeedService().seedIfNeeded();

  runApp(
    ChangeNotifierProvider<TournamentProvider>(
      create: (_) => TournamentProvider(),
      child: const MyApp(),
    ),
  );
}











