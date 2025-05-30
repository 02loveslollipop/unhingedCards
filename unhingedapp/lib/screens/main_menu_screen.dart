import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart'; // Add this import
import 'dart:math'; // For random player ID
import 'dart:async'; // For Timer

import 'package:unhingedapp/screens/qr_scanner_screen.dart';
import 'package:unhingedapp/screens/host_lobby_screen.dart'; // Import HostLobbyScreen
import 'package:unhingedapp/screens/player_lobby_screen.dart'; // Import PlayerLobbyScreen
import 'package:unhingedapp/screens/badapple_screen.dart'; // Import BadApple screen
import 'package:unhingedapp/utils/name_generator.dart'; // Import the name generator

class MainMenuScreen extends StatefulWidget {
  // Convert to StatefulWidget
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // Create State class
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();

  // Easter egg state tracking
  bool _unhingedPressed = false;
  bool _cardsPressed = false;
  Timer? _easterEggTimer;
  // Method to generate a simple random player ID (ephemeral)
  String _generatePlayerId() {
    return 'player_${Random().nextInt(100000)}';
  }

  @override
  void dispose() {
    _easterEggTimer?.cancel();
    super.dispose();
  }

  void _onUnhingedPressed() {
    setState(() {
      _unhingedPressed = true;
    });

    // Check if both are pressed
    if (_cardsPressed) {
      _triggerEasterEgg();
    } else {
      // Reset after 2 seconds if the other isn't pressed
      _easterEggTimer?.cancel();
      _easterEggTimer = Timer(const Duration(seconds: 2), () {
        setState(() {
          _unhingedPressed = false;
        });
      });
    }
  }

  void _onCardsPressed() {
    setState(() {
      _cardsPressed = true;
    });

    // Check if both are pressed
    if (_unhingedPressed) {
      _triggerEasterEgg();
    } else {
      // Reset after 2 seconds if the other isn't pressed
      _easterEggTimer?.cancel();
      _easterEggTimer = Timer(const Duration(seconds: 2), () {
        setState(() {
          _cardsPressed = false;
        });
      });
    }
  }

  void _triggerEasterEgg() {
    _easterEggTimer?.cancel();

    // Reset state
    setState(() {
      _unhingedPressed = false;
      _cardsPressed = false;
    });

    // Navigate to BadApple screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BadAppleScreen()),
    );
  }

  Future<void> _createRoom() async {
    try {
      String playerId = _generatePlayerId(); // Host player ID
      DatabaseReference roomRef =
          _databaseReference.child('rooms').push(); // Generate unique room ID
      String roomId = roomRef.key!;

      Map<String, dynamic> roomData = {
        'roomId': roomId,
        'hostPlayerId': playerId,
        'players': {
          playerId: {
            'id': playerId,
            'name': NameGenerator.generateRandomName(), // Use generated name
            'isHost': true,
          },
        },
        'gameState':
            'waiting', // Keep as 'waiting' for consistency with lobby screens
        'currentCardCzarId': null,
        'currentBlackCard': null,
        'submittedAnswers': {},
        'scores': {},
        'createdAt': ServerValue.timestamp,
      };

      await roomRef.set(roomData);
      print('Room created with ID: $roomId');

      if (!mounted) return;

      // Navigate directly to HostLobbyScreen without showing a dialog
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => HostLobbyScreen(roomId: roomId, playerId: playerId),
        ),
      );
    } catch (e) {
      print('Error creating room: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating room: $e')));
    }
  }

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => QRScannerScreen(
              onQRCodeScanned: (scannedRoomId) {
                Navigator.pop(context); // Pop QRScannerScreen
                if (scannedRoomId.isNotEmpty) {
                  _joinRoom(scannedRoomId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid QR code or Room ID.'),
                    ),
                  );
                }
              },
            ),
      ),
    );
  }

  Future<void> _joinRoom(String roomId) async {
    try {
      DataSnapshot roomSnapshot =
          await _databaseReference.child('rooms/$roomId').get();
      if (roomSnapshot.exists) {
        String playerId = _generatePlayerId();
        Map<String, dynamic> playerData = {
          'id': playerId,
          'name': NameGenerator.generateRandomName(), // Use generated name
          'isHost': false,
        };
        await _databaseReference
            .child('rooms/$roomId/players/$playerId')
            .set(playerData);
        print('Joined room with ID: $roomId as Player $playerId');

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => PlayerLobbyScreen(
                  // Navigate to PlayerLobbyScreen
                  roomId: roomId,
                  playerId: playerId,
                ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Room not found.')));
        print('Room with ID: $roomId not found.');
      }
    } catch (e) {
      print('Error joining room: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error joining room: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color buttonTextColor = Colors.black;
    const Color buttonBackgroundColor = Colors.white;

    final String disclaimerText = '''
Cards Against Humanity is free to use under the Creative Commons BY-NC-SA 2.0 License (http://creativecommons.org/licenses/by-nc-sa/2.0/).
This project, "Unhinged Cards", is a derivative work offered under the same license. 
It is not for sale, does not generate profit, and is in no way affiliated with Cards Against Humanity LLC.
Please comply with the Laws of Man and Nature. Do not use this game for nefarious purposes such as libel, slander, diarrhea,
copyright infringement, harassment, or death.
To comply with the previous license, the source code and assets of this project are available at: https://github.com/02loveslollipop/unhingedCards
''';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _onUnhingedPressed,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(_unhingedPressed ? 8.0 : 0.0),
                      decoration: BoxDecoration(
                        color:
                            _unhingedPressed
                                ? Colors.white.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        'Unhinged',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _unhingedPressed ? Colors.green : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: _onCardsPressed,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.0 + (_cardsPressed ? 8.0 : 0.0),
                        vertical: 4.0 + (_cardsPressed ? 4.0 : 0.0),
                      ),
                      decoration: BoxDecoration(
                        color: _cardsPressed ? Colors.green : Colors.white,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        'Cards',
                        style: GoogleFonts.montserrat(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _cardsPressed ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _createRoom, // Updated onPressed
                child: const Text(
                  'Create Room',
                  style: TextStyle(color: buttonTextColor),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _navigateToQRScanner, // Updated onPressed
                child: const Text(
                  'Join Room',
                  style: TextStyle(color: buttonTextColor),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                disclaimerText,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
