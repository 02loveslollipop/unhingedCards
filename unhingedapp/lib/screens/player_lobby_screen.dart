import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Re-add for DatabaseReference type
import 'dart:async'; // Still needed for StreamSubscription type in mixin if not directly used here
import '../components/player_list.dart';
import '../mixins/lobby_state_mixin.dart'; // Import the mixin

class PlayerLobbyScreen extends StatefulWidget {
  final String roomId;
  final String playerId;

  const PlayerLobbyScreen({
    super.key,
    required this.roomId,
    required this.playerId,
  });

  @override
  State<PlayerLobbyScreen> createState() => _PlayerLobbyScreenState();
}

class _PlayerLobbyScreenState extends State<PlayerLobbyScreen>
    with LobbyStateMixin<PlayerLobbyScreen> {
  // Use the mixin

  @override
  void initState() {
    super.initState();
    initializeLobbyState(
      currentRoomId: widget.roomId,
      currentPlayerId: widget.playerId,
      onStateShouldUpdate: () => setState(() {}),
      navigateToGameScreenCallback:
          (roomId, playerId) =>
              defaultNavigateToGameScreen(context, roomId, playerId),
      onRoomLeftOrDeletedCallback:
          () => defaultOnRoomLeftOrDeleted(
            context,
            'You have left the room or the room was closed.',
          ),
      showErrorSnackBar:
          (message) => defaultShowErrorSnackBar(context, message),
    );
  }

  Future<void> _leaveRoom() async {
    // Use roomRef from mixin
    DatabaseReference playerRef = roomRef.child('players/${widget.playerId}');
    await handleLeaveRoomAction(
      leaveAction: () => playerRef.remove(),
      onSuccessfullyLeft: () {
        // Explicitly navigate back to the main menu
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      onError: (message) => defaultShowErrorSnackBar(context, message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Lobby'),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // No back button to main menu
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            // Replace Center with SingleChildScrollView
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Players in Room:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  // Player list with fixed height instead of Expanded
                  SizedBox(
                    height: 200, // Fixed height for player list
                    child: PlayerList(
                      players: players, // Use players from mixin
                      currentPlayerId: widget.playerId,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (gameState == 'waiting') ...[
                    // Use gameState from mixin
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        const Text(
                          'Waiting for host to start the game...',
                          style: TextStyle(fontSize: 16),
                        ),
                        if (selectedCardTopic != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[600]!),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Selected Card Topic:',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  selectedCardTopic!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ] else if (gameState == 'determining_card_czar') ...[
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Determining first Card Czar...',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ] else if (gameState == 'playing') ...[
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Game starting... Loading...',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  TextButton.icon(
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Leave Room'),
                    onPressed: _leaveRoom,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  // Add some bottom padding for the Room ID overlay
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          buildRoomIdWidget(context, widget.roomId), // Use mixin method
        ],
      ),
    );
  }

  @override
  void dispose() {
    disposeLobbySubscription(); // Call mixin's dispose method
    super.dispose();
  }
}
