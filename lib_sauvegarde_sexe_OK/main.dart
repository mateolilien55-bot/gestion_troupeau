import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),

        scaffoldBackgroundColor:
            const Color(0xFFF7F8F7),

        inputDecorationTheme:
            const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}