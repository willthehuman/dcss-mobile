import 'package:flutter/material.dart';

import 'ui/game_screen.dart';
import 'ui/login_screen.dart';

class DcssApp extends StatelessWidget {
  const DcssApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7EA0C8),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'DCSS Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: <String, WidgetBuilder>{
        '/login': (BuildContext context) => const LoginScreen(),
        '/game': (BuildContext context) => const GameScreen(),
      },
    );
  }
}
