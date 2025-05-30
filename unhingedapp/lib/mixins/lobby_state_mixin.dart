import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../screens/game_screen.dart';

mixin LobbyStateMixin<T extends StatefulWidget> on State<T> {
  late DatabaseReference roomRef;
  StreamSubscription<DatabaseEvent>? roomSubscription;
  Map<dynamic, dynamic> players = {};
  String gameState = 'waiting';
  String? selectedCardTopic; // Add tracking for selectedCardTopic
  void initializeLobbyState({
    required String currentRoomId,
    required String currentPlayerId,
    required VoidCallback
    onStateShouldUpdate, // Typically () => setState(() {})
    required Function(String, String)
    navigateToGameScreenCallback, // (roomId, playerId)
    required VoidCallback
    onRoomLeftOrDeletedCallback, // To pop and show snackbar
    required Function(String)
    showErrorSnackBar, // To show general error messages
  }) {
    roomRef = FirebaseDatabase.instance
        .ref()
        .child('rooms')
        .child(currentRoomId);
    roomSubscription = roomRef.onValue.listen(
      (event) {
        if (!mounted) return;

        if (event.snapshot.exists) {
          final roomData = event.snapshot.value as Map<dynamic, dynamic>?;
          if (roomData != null) {
            final newGameState = roomData['gameState'] as String? ?? 'waiting';
            final newPlayers =
                roomData['players'] as Map<dynamic, dynamic>? ?? {};
            final newSelectedCardTopic =
                roomData['selectedCardTopic'] as String?;

            bool needsUpdate = false;
            if (newGameState != gameState) {
              gameState = newGameState;
              needsUpdate = true;
            }
            if (players.toString() != newPlayers.toString()) {
              players = newPlayers;
              needsUpdate = true;
            }
            if (selectedCardTopic != newSelectedCardTopic) {
              selectedCardTopic = newSelectedCardTopic;
              needsUpdate = true;
            }
            if (needsUpdate) {
              onStateShouldUpdate();
            }

            // Navigate to GameScreen for both determining_card_czar and playing states
            if (newGameState == 'playing' ||
                newGameState == 'determining_card_czar') {
              navigateToGameScreenCallback(currentRoomId, currentPlayerId);
            }
          }
        } else {
          onRoomLeftOrDeletedCallback();
        }
      },
      onError: (error) {
        if (mounted) {
          print("Error in room subscription: $error");
          showErrorSnackBar("Error listening to room updates: $error");
          onRoomLeftOrDeletedCallback();
        }
      },
    );
  }

  Future<void> handleLeaveRoomAction({
    required Future<void> Function()
    leaveAction, // The specific Firebase action
    required VoidCallback onSuccessfullyLeft, // e.g., popUntil
    required Function(String) onError, // e.g., showSnackBar
  }) async {
    try {
      await leaveAction();
      // Explicitly call the callback on success
      if (mounted) {
        onSuccessfullyLeft();
      }
    } catch (e) {
      if (mounted) {
        print('Error performing leave action: $e');
        onError('Error leaving room: ${e.toString()}');
      }
    }
  }

  void disposeLobbySubscription() {
    roomSubscription?.cancel();
  }
  Widget buildRoomIdWidget(BuildContext context, String currentRoomId) {
    return Positioned(
      bottom: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Room ID',
              style: TextStyle(color: Colors.grey, fontSize: 8),
            ),
            const SizedBox(height: 1),
            Text(
              currentRoomId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to navigate to GameScreen
  void defaultNavigateToGameScreen(
    BuildContext context,
    String roomId,
    String playerId,
  ) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GameScreen(roomId: roomId, playerId: playerId),
        ),
      );
    }
  }

  // Helper for room left/deleted
  void defaultOnRoomLeftOrDeleted(BuildContext context, String message) {
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Helper for showing error snackbar
  void defaultShowErrorSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
