import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unhingedapp/screens/host_lobby_screen.dart';
import 'package:unhingedapp/screens/player_lobby_screen.dart';
import 'firebase_options.dart';
import 'screens/main_menu_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unhinged Cards',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.grey[850], // Darker cards
        textTheme: GoogleFonts.latoTextTheme(
          ThemeData.dark().textTheme, // Use Lato font with dark theme defaults
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent, // Button background
            foregroundColor: Colors.black, // Button text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.lightBlueAccent, // Text button color
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[850], // AppBar background
          elevation: 0, // No shadow
          titleTextStyle: GoogleFonts.lato(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.lightBlueAccent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.white, width: 2.0),
          ),
          labelStyle: const TextStyle(color: Colors.lightBlueAccent),
        ),
      ),
      home: const MainMenuScreen(),
      routes: {
        // Define routes for easier navigation if needed, though direct navigation is also fine
        '/main_menu': (context) => const MainMenuScreen(),
        // '/room_lobby': (context) => RoomLobbyScreen(roomId: '', playerId: '', isHost: false,), // Example, ensure params are passed
        '/qr_scanner':
            (context) =>
                QRScannerScreen(onQRCodeScanned: (scannedId) {}), // Example
        '/game': (context) => GameScreen(roomId: '', playerId: ''), // Example
        // Add routes for HostLobbyScreen and PlayerLobbyScreen if you prefer named routes
        '/host_lobby': (context) => HostLobbyScreen(roomId: '', playerId: ''),
        '/player_lobby':
            (context) => PlayerLobbyScreen(roomId: '', playerId: ''),
      },
    );
  }
}
