import 'package:flutter/material.dart';

class GameScreen extends StatelessWidget {
  final String roomId;
  final String playerId;

  const GameScreen({super.key, required this.roomId, required this.playerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Game Screen - Room: \$roomId')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to the game, Player \$playerId!'),
            Text('Room ID: \$roomId'),
            // Game content will go here
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Placeholder for leaving game, navigate back to main menu for now
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Leave Game (Placeholder)'),
            ),
          ],
        ),
      ),
    );
  }
}
