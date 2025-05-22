import 'package:flutter/material.dart';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../components/player_list.dart';
import '../mixins/lobby_state_mixin.dart'; // Import the mixin

class HostLobbyScreen extends StatefulWidget {
  final String roomId;
  final String playerId;

  const HostLobbyScreen({
    super.key,
    required this.roomId,
    required this.playerId,
  });

  @override
  State<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends State<HostLobbyScreen>
    with LobbyStateMixin<HostLobbyScreen> {
  // Use the mixin
  // _roomRef, _roomSubscription, _players, _gameState are now managed by LobbyStateMixin
  List<String> _availableCardTopics = [];
  String? _selectedCardTopic;
  bool _neverShowQrShareDialog =
      false; // Flag to track user preference for QR code instructions

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
          () =>
              defaultOnRoomLeftOrDeleted(context, 'The room has been deleted.'),
      showErrorSnackBar:
          (message) => defaultShowErrorSnackBar(context, message),
    );
    _fetchCardTopics();

    // Check if we should show the QR code sharing dialog
    _checkAndShowQrSharingDialog();
  }

  // Method to check if we should show the QR sharing dialog and display it if needed
  Future<void> _checkAndShowQrSharingDialog() async {
    final prefs = await SharedPreferences.getInstance();
    _neverShowQrShareDialog = prefs.getBool('neverShowQrShareDialog') ?? false;

    // Show dialog if user hasn't chosen "Don't show again"
    if (!_neverShowQrShareDialog) {
      // Use Future.delayed to avoid showing dialog during build
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showQrSharingInstructionsDialog();
        }
      });
    }
  }

  // Show a dialog with instructions on how to share the QR code
  void _showQrSharingInstructionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          title: const Text(
            'Share Room with Others',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'To invite players to join your room:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '• Show them the QR code to scan',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Or share the Room ID with them',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Players need to use the "Join Room" option from the main menu to connect.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                "Don't show again",
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () async {
                // Save preference
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('neverShowQrShareDialog', true);
                _neverShowQrShareDialog = true;
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchCardTopics() async {
    try {
      QuerySnapshot topicSnapshot =
          await FirebaseFirestore.instance.collection('cardTopics').get();
      List<String> topics = topicSnapshot.docs.map((doc) => doc.id).toList();
      if (mounted) {
        setState(() {
          _availableCardTopics = topics;
          if (topics.isNotEmpty) {
            _selectedCardTopic = topics.first;
            // Update the room with the default selected topic
            roomRef.child('selectedCardTopic').set(topics.first);
          }
        });
      }
    } catch (e) {
      print("Error fetching card topics: $e");
      if (mounted) {
        defaultShowErrorSnackBar(context, 'Error fetching card topics: $e');
      }
    }
  }

  // _listenToRoomUpdates is now handled by LobbyStateMixin
  Future<void> _startGame() async {
    if (_selectedCardTopic != null && players.isNotEmpty) {
      // Check if we have enough players
      final requiredPlayers = kDebugMode ? 2 : 3; // Lower threshold in debug mode
      
      try {
        // Update game state to indicate Card Czar determination phase
        await roomRef.child('gameState').set('determining_card_czar');

        // TODO: Navigate to Card Czar determination screen or show a dialog
        // For now, the existing listener in LobbyStateMixin will handle
        // navigation to GameScreen when gameState changes, which is not ideal yet.
        // We will refine this in the next steps.
        if (mounted) {
          // Optionally, show a temporary message or disable button further
          print("Game state set to determining_card_czar");
        }
      } catch (e) {
        print('Error setting game state for Card Czar determination: $e');
        if (mounted) {
          defaultShowErrorSnackBar(
            context,
            'Error starting game: ${e.toString()}',
          );
        }
      }
    } else if (_selectedCardTopic == null) {
      defaultShowErrorSnackBar(
        context,
        'Please select a card topic to start the game.',
      );
    } else if (players.isEmpty) {
      defaultShowErrorSnackBar(context, 'Cannot start game with no players.');
    }
  }

  Future<void> _leaveRoom() async {
    await handleLeaveRoomAction(
      leaveAction: () => roomRef.remove(), // Host deletes the entire room
      onSuccessfullyLeft: () {
        // This is now handled by the onRoomLeftOrDeletedCallback in initializeLobbyState
        // if (mounted) {
        //   Navigator.of(context).popUntil((route) => route.isFirst);
        // }
      },
      onError: (message) => defaultShowErrorSnackBar(context, message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Lobby'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Room ID & QR Code:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.help_outline, size: 18),
                        tooltip: 'How to share',
                        onPressed: _showQrSharingInstructionsDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.roomId,
                      style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.headlineSmall?.fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 15),
                  QrImageView(
                    data: widget.roomId,
                    version: QrVersions.auto,
                    size: 150.0,
                    backgroundColor:
                        Colors.white, // Ensure QR is visible in dark mode
                  ),
                  const SizedBox(height: 20),                  Text(
                    'Players:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Need at least ${kDebugMode ? 2 : 3} players to start',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Player list with fixed height instead of Expanded
                  SizedBox(
                    height: 200, // Fixed height for player list
                    child: PlayerList(
                      players: players,
                      currentPlayerId: widget.playerId,
                    ),
                  ),
                  
                  // Player count indicator
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: players.length >= (kDebugMode ? 2 : 3) 
                          ? Colors.green[900] 
                          : Colors.red[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          players.length >= (kDebugMode ? 2 : 3)
                              ? Icons.check_circle
                              : Icons.warning,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Players: ${players.length}/${kDebugMode ? 2 : 3}+',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (gameState == 'waiting') ...[
                    // Use gameState from mixin
                    if (_availableCardTopics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Card Topic',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            // Ensure label and border colors fit the dark theme
                            labelStyle: TextStyle(color: Colors.grey[400]),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: BorderSide(color: Colors.grey[600]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                              borderSide: const BorderSide(
                                color: Colors.white,
                                width: 2.0,
                              ),
                            ),
                          ),
                          value: _selectedCardTopic,
                          dropdownColor:
                              Colors.grey[850], // Dark dropdown background
                          style: const TextStyle(
                            color: Colors.white,
                          ), // Text color for items
                          iconEnabledColor:
                              Colors.white, // Color for the dropdown icon
                          items:
                              _availableCardTopics.map((String topicId) {
                                return DropdownMenuItem<String>(
                                  value: topicId,
                                  child: Text(
                                    topicId,
                                    style: TextStyle(
                                      color:
                                          _selectedCardTopic == topicId
                                              ? Colors.white
                                              : Colors.grey[400],
                                      fontWeight:
                                          _selectedCardTopic == topicId
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCardTopic = newValue;
                            });
                            // Update selectedCardTopic in Firebase for all users to see
                            if (newValue != null) {
                              roomRef.child('selectedCardTopic').set(newValue);
                            }
                          },
                          selectedItemBuilder: (BuildContext context) {
                            // Custom builder for selected item
                            return _availableCardTopics.map<Widget>((
                              String item,
                            ) {
                              return Text(
                                item,
                                style: const TextStyle(
                                  color:
                                      Colors.white, // Selected item text color
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      )
                    else if (_availableCardTopics.isEmpty &&
                        _selectedCardTopic == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('Loading card topics...'),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                  const SizedBox(height: 20),                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                    onPressed:
                        players.length >= (kDebugMode ? 2 : 3)
                            ? _startGame
                            : null, // Require minimum players
                    child: const Text('Start Game'),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    icon: const Icon(
                      Icons.delete_forever,
                      color: Colors.redAccent,
                    ),
                    label: const Text('Leave Room & Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    onPressed: _leaveRoom,
                  ),
                  // Add some bottom padding for the Room ID overlay
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          buildRoomIdWidget(context, widget.roomId),
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
