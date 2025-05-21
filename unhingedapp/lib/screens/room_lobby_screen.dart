import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import './game_screen.dart'; // Import the new game screen

class RoomLobbyScreen extends StatefulWidget {
  final String roomId;
  final String playerId;
  final bool isHost;

  const RoomLobbyScreen({
    super.key,
    required this.roomId,
    required this.playerId,
    required this.isHost,
  });

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  late DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSubscription;
  Map<dynamic, dynamic> _players = {};
  String _gameState = 'waiting'; // Default to waiting

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}');
    _listenToRoomUpdates();
  }

  void _listenToRoomUpdates() {
    _roomSubscription = _roomRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final roomData = event.snapshot.value as Map<dynamic, dynamic>?;
        if (roomData != null) {
          final newGameState = roomData['gameState'] as String? ?? 'waiting';
          setState(() {
            _players = roomData['players'] as Map<dynamic, dynamic>? ?? {};
            _gameState = newGameState;
          });

          if (newGameState == 'playing' && mounted) {
            // Navigate to GameScreen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (context) => GameScreen(
                      roomId: widget.roomId,
                      playerId: widget.playerId,
                    ),
              ),
            );
          }
        }
      } else {
        // Room deleted or doesn't exist, navigate back
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room not found or has been deleted.'),
            ),
          );
        }
      }
    });
  }

  void _startGame() {
    if (widget.isHost) {
      // TODO: Implement more sophisticated game start logic if needed
      // This should also eventually deal cards, set the first judge, etc.
      // For now, just set gameState to 'playing'
      _roomRef.update({'gameState': 'playing'}).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting game: \$error')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room Lobby: ${widget.roomId}'),
        automaticallyImplyLeading: false, // No back button to main menu
        actions: [
          if (widget.isHost)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: Implement Room Settings (e.g., kick player, change card packs)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Room settings not implemented yet.'),
                  ),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Room ID: ${widget.roomId}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              Text('Players:', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children:
                      _players.entries.map((entry) {
                        final playerId = entry.key as String;
                        final playerData = entry.value as Map<dynamic, dynamic>;
                        final playerName =
                            playerData['name'] as String? ??
                            'Player \\$playerId'; // Display Player ID if name is missing
                        final isHost = playerData['isHost'] as bool? ?? false;
                        return Card(
                          // Wrap ListTile in a Card for better UI
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              // Add a simple avatar
                              child: Text(
                                playerName.isNotEmpty
                                    ? playerName[0].toUpperCase()
                                    : 'P',
                              ),
                            ),
                            title: Text(
                              playerName +
                                  (playerId == widget.playerId ? ' (You)' : ''),
                            ),
                            trailing:
                                isHost
                                    ? const Chip(label: Text('Host'))
                                    : null, // Use a Chip for Host indicator
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              if (_gameState == 'waiting') ...[
                // Show Start Game or Waiting message based on gameState
                if (widget.isHost)
                  ElevatedButton.icon(
                    // Add an icon to the button
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Game'),
                    onPressed:
                        _players.length >= 1
                            ? _startGame
                            : null, // Host can start alone for testing, ideally >= 2
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  )
                else
                  const Column(
                    // Nicer waiting message
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'Waiting for host to start the game...',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
              ] else if (_gameState == 'playing') ...[
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      'Game starting... Loading...',
                      style: TextStyle(fontSize: 16, color: Colors.green),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              TextButton.icon(
                // Add an icon to the leave button
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave Room'),
                onPressed: () async {
                  try {
                    // Remove player from RTDB
                    await _roomRef.child('players/${widget.playerId}').remove();
                    // If host leaves, and there are other players, assign a new host or delete room.
                    // For simplicity now, if host leaves, delete the room if they are the last one or if we don't want to migrate host
                    // More complex: assign a new host from remaining players.
                    // For now, let's try to delete the room if the host is the last one.
                    if (widget.isHost && _players.length > 1) {
                      // Simple: if host leaves, delete the room if they are the last one or if we don't want to migrate host
                      // More complex: assign a new host from remaining players.
                      // Let's try to delete the room if the host is the last one.
                      if (_players.length == 1) {
                        // Only host was in the room
                        await _roomRef.remove();
                      } else {
                        // If host leaves and others are present, ideally, promote a new host.
                        // For now, we'll just let the host leave. The game state won't progress.
                        // Or, we could set gameState to 'aborted' or similar.
                        // Let's keep it simple: host leaves, player entry removed.
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error leaving room: \\$e')),
                      );
                    }
                  }
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ), // Make leave button red
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}
