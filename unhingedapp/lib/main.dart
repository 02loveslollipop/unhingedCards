import 'package:flutter/material.dart';
import 'package:unhingedapp/screens/main_menu_screen.dart'; // Add this import

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unhinged Cards', // Change title
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          displayLarge: TextStyle(color: Colors.white),
          displayMedium: TextStyle(color: Colors.white),
          displaySmall: TextStyle(color: Colors.white),
          headlineMedium: TextStyle(color: Colors.white),
          headlineSmall: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Remove or comment out the colorScheme if you want a simpler dark theme
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
      ),
      home: const MainMenuScreen(), // Change this to MainMenuScreen
    );
  }
}

// Remove MyHomePage and _MyHomePageState classes as they are no longer needed
// class MyHomePage extends StatefulWidget { ... }
// class _MyHomePageState extends State<MyHomePage> { ... }
