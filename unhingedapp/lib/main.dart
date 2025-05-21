import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unhingedapp/screens/main_menu_screen.dart';
import 'package:unhingedapp/screens/room_lobby_screen.dart'; // Import RoomLobbyScreen
import 'firebase_options.dart';

Future<void> main() async {
  // Make main async
  WidgetsFlutterBinding.ensureInitialized(); // Add this line
  await Firebase.initializeApp(
    // Add this block
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unhinged Card', // Change title
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const MainMenuScreen(), // Change this to MainMenuScreen
      // Define routes for navigation (optional but good practice)
      routes: {
        '/lobby':
            (context) => const RoomLobbyScreen(
              roomId: '',
              playerId: '',
              isHost: false,
            ), // Placeholder, will be replaced by actual navigation
      },
    );
  }
}

// Remove MyHomePage and _MyHomePageState classes as they are no longer needed
// class MyHomePage extends StatefulWidget { ... }
// class _MyHomePageState extends State<MyHomePage> { ... }
