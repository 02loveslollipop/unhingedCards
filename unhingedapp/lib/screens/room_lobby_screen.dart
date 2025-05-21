import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import './game_screen.dart'; // Import the new game screen
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'dart:math'; // For shuffling cards

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
  List<String> _availableCardTopics = [];
  String? _selectedCardTopic; // To store the host's selection

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}');
    _listenToRoomUpdates();
    _fetchCardTopics(); // Fetch card topics when the lobby screen initializes
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
            _selectedCardTopic = topics.first; // Default to the first topic
          }
        });
      }
    } catch (e) {
      print("Error fetching card topics: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching card topics: $e')),
        );
      }
    }
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
              content: Text('Room has been deleted.'),
            ),
          );
        }
      }
    });
  }

  Future<void> _startGame() async {
    if (widget.isHost && _selectedCardTopic != null && _players.isNotEmpty) {
      try {
        // 1. Fetch cards from the selected topic in Firestore
        DocumentSnapshot topicDoc =
            await FirebaseFirestore.instance
                .collection('cardTopics')
                .doc(_selectedCardTopic)
                .get();

        if (!topicDoc.exists || topicDoc.data() == null) {
          throw Exception("Selected card topic not found or is empty.");
        }

        final cardData = topicDoc.data() as Map<String, dynamic>;
        final List<dynamic> allCards =
            cardData['cards'] as List<dynamic>? ?? [];

        List<Map<String, dynamic>> whiteCards =
            allCards
                .where((card) => card['type'] == 'white')
                .map((card) => Map<String, dynamic>.from(card))
                .toList();
        List<Map<String, dynamic>> blackCards =
            allCards
                .where((card) => card['type'] == 'black')
                .map((card) => Map<String, dynamic>.from(card))
                .toList();

        if (whiteCards.isEmpty || blackCards.isEmpty) {
          throw Exception(
            "Not enough white or black cards in the selected topic.",
          );
        }

        // Shuffle cards
        whiteCards.shuffle(Random());
        blackCards.shuffle(Random());

        // 2. Deal cards to players
        Map<String, dynamic> playerHands = {};
        Map<String, dynamic> playerScores = {}; // Initialize scores
        List<String> playerIds = _players.keys.cast<String>().toList();

        const int cardsPerPlayer = 7; // Standard hand size

        for (String playerId in playerIds) {
          List<Map<String, dynamic>> hand = [];
          for (int i = 0; i < cardsPerPlayer; i++) {
            if (whiteCards.isNotEmpty) {
              hand.add(whiteCards.removeAt(0)); // Deal from the top
            }
          }
          playerHands[playerId] = hand;
          playerScores[playerId] = 0; // Initialize score for each player
        }

        // 3. Select the first black card
        Map<String, dynamic> currentBlackCard = blackCards.removeAt(0);

        // 4. Select the first Card Czar (e.g., the host or a random player)
        String firstCardCzarId = playerIds.first; // Host can be the first czar

        // 5. Prepare initial game state for RTDB
        Map<String, dynamic> gameUpdates = {
          'gameState': 'playing',
          'currentBlackCard': currentBlackCard,
          'playerHands': playerHands,
          'scores': playerScores,
          'currentCardCzarId': firstCardCzarId,
          'playedWhiteCards': whiteCards, // Remaining white cards in the deck
          'playedBlackCards': blackCards, // Remaining black cards in the deck
          'submittedAnswers': {}, // Clear any previous submissions
          'selectedCardTopic': _selectedCardTopic, // Store the selected topic
          'roundWinner': null,
          'lastWinningCard': null,
        };

        await _roomRef.update(gameUpdates);
      } catch (e) {
        print('Error starting game: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error starting game: $e')));
        }
      }
    } else if (_selectedCardTopic == null && widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a card topic to start the game.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Lobby'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
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
                      offset: const Offset(0, 2), // changes position of shadow
                    ),
                  ],
                ),
                child: Text(
                  'Room ID: ${widget.roomId}',
                  style: TextStyle(
                    fontSize:
                        Theme.of(context).textTheme.headlineSmall?.fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
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
                if (widget.isHost && _availableCardTopics.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Card Topic',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      value: _selectedCardTopic,
                      items:
                          _availableCardTopics.map((String topicId) {
                            // Attempt to get a more descriptive name if available, otherwise use topicId
                            // This assumes your topic documents in Firestore might have a 'topicName' field.
                            // For now, we'll just use the ID.
                            return DropdownMenuItem<String>(
                              value: topicId,
                              child: Text(
                                topicId,
                              ), // Replace with a more descriptive name if available
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCardTopic = newValue;
                        });
                      },
                    ),
                  ),
                if (widget.isHost &&
                    _availableCardTopics.isEmpty &&
                    _selectedCardTopic == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 10),
                        Text("Loading card topics..."),
                      ],
                    ),
                  ),
                if (widget.isHost)
                  ElevatedButton.icon(
                    // Add an icon to the button
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Game'),
                    onPressed:
                        _players.length >= 1 &&
                                _selectedCardTopic !=
                                    null // Enable button only if a topic is selected
                            ? _startGame
                            : null,
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
                    if (widget.isHost) {
                      // Host is leaving, delete the entire room.
                      // Other players' _listenToRoomUpdates will detect the deletion
                      // and they will be popped from the lobby with a message.
                      await _roomRef.remove();
                    } else {
                      // Non-host player is leaving. Just remove their data from the room.
                      await _roomRef
                          .child('players/${widget.playerId}')
                          .remove();
                    }
                  } catch (e) {
                    print(
                      'Error leaving room: $e',
                    ); // Log the error for debugging
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error leaving room: ${e.toString()}'),
                        ),
                      );
                    }
                  } finally {
                    // Regardless of success or failure of Firebase operation,
                    // navigate the current user back to the main menu.
                    if (mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
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
