import 'package:flutter/material.dart';

import 'database/database.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.createDatabaseBackup();
  } catch (_) {
    // Une sauvegarde ne doit jamais empêcher l'application de démarrer.
  }

  runApp(const GestionTroupeauApp());
}

class GestionTroupeauApp extends StatelessWidget {
  const GestionTroupeauApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion du troupeau',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
