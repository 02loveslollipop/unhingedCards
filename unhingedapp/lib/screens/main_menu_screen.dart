import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart'; // Add this import
import 'dart:math'; // For random player ID
import 'package:qr_flutter/qr_flutter.dart'; // Import for QR code generation

import 'package:unhingedapp/screens/qr_scanner_screen.dart';
import 'package:unhingedapp/screens/room_lobby_screen.dart'; // Import RoomLobbyScreen
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

  // Method to generate a simple random player ID (ephemeral)
  String _generatePlayerId() {
    return 'player_${Random().nextInt(100000)}';
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
            'lobby', // Changed from 'waiting' to 'lobby' to match RoomLobbyScreen
        'currentCardCzar': null,
        'currentQuestionCard': null,
        'submittedAnswers': {},
        'scores': {},
        'createdAt': ServerValue.timestamp,
      };

      await roomRef.set(roomData);
      print('Room created with ID: $roomId');

      if (!mounted) return;

      // Show QR Code Dialog
      showDialog(
        context: context,
        barrierDismissible: false, // User must close dialog manually or join
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Room Created!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Room ID: $roomId'),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: QrImageView(
                    data: roomId,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor:
                        Colors.white, // Ensure QR is scannable in dark mode
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Share this Room ID or QR code with others to join.',
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Go to Lobby'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                  Navigator.push(
                    // Changed from pushReplacement
                    // Use push to keep MainMenuScreen in the stack
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => RoomLobbyScreen(
                            roomId: roomId,
                            playerId: playerId,
                            isHost: true,
                          ),
                    ),
                  );
                },
              ),
            ],
          );
        },
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
          // Changed from pushReplacement
          // Use push to keep MainMenuScreen in the stack
          context,
          MaterialPageRoute(
            builder:
                (context) => RoomLobbyScreen(
                  roomId: roomId,
                  playerId: playerId,
                  isHost: false,
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
To comply with the previous license, the source code and assets of this project are available at: (add repo link here).
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
                  Text(
                    'Unhinged',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      'Cards',
                      style: GoogleFonts.montserrat(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
