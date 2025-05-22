import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../components/game_card.dart';

class GameScreen extends StatefulWidget {
  final String roomId;
  final String playerId;

  const GameScreen({super.key, required this.roomId, required this.playerId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late DatabaseReference _roomRef;
  late StreamSubscription<DatabaseEvent> _gameSubscription;
  // Game state
  String _gameState = 'determining_card_czar';
  Map<dynamic, dynamic> _players = {};
  String? _selectedCardTopic; // Will be used in the main game UI
  String? _currentCardCzarId;
  bool get _isCardCzar =>
      _currentCardCzarId == widget.playerId; // Will be used in the main game UI
  // UI controllers
  final TextEditingController _timeInputController = TextEditingController();
  final FocusNode _timeInputFocusNode = FocusNode();
  bool _hasSubmittedTime = false;
  Map<String, String> _playerTimes = {};

  // Timer variables
  Timer? _playerAnswerTimer;
  Timer? _hostSelectionTimer;
  int _playerTimeLeft = 20; // 20 seconds for players to answer
  int _hostTimeLeft = 20; // 20 seconds for host to select Card Czar
  bool _playerTimerStarted = false;
  bool _hostTimerStarted = false;  // Card game variables
  List<Map<String, dynamic>> _playerHand = []; // Player's white cards
  Map<dynamic, dynamic>? _currentBlackCard; // Current black card
  Map<String, List<Map<String, dynamic>>> _playerSubmissions =
      {}; // Player submissions
  int _cardsToSubmit = 1; // Number of cards to submit (from black card)
  List<Map<String, dynamic>> _selectedWhiteCards =
      []; // Cards selected by player to submit
  bool _hasSubmittedCards = false; // Whether player has submitted cards
  bool _allPlayersSubmitted = false; // Whether all players have submitted
  Map<dynamic, dynamic> _winningSubmission =
      {}; // The winning submission for the round
  String? _winningPlayerId; // The ID of the player who won the round
  bool _isDrawingCards = false; // Whether cards are currently being drawn
  Timer? _cardSubmissionTimer; // Timer for card submission

  @override
  void initState() {
    super.initState();
    _initializeGameState();

    // Start the player answer timer when the screen loads
    _startPlayerAnswerTimer();
  }

  void _startPlayerAnswerTimer() {
    if (_playerTimerStarted) return;

    setState(() {
      _playerTimerStarted = true;
      _playerTimeLeft = 15;
    });

    _playerAnswerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_playerTimeLeft > 0) {
        setState(() {
          _playerTimeLeft--;
        });
      } else {
        _playerAnswerTimer?.cancel();

        // If player didn't submit yet, submit "Didn't answer"
        if (!_hasSubmittedTime && mounted) {
          setState(() {
            _hasSubmittedTime = true;
          });

          // Store "Didn't answer" in Firebase
          _roomRef
              .child('czarDeterminationTimes')
              .child(widget.playerId)
              .set("Didn't answer");

          // Start host selection timer if this is the host
          if (_isHost) {
            _startHostSelectionTimer();
          }
        }
      }
    });
  }

  void _startHostSelectionTimer() {
    if (_hostTimerStarted || !_isHost) return;

    setState(() {
      _hostTimerStarted = true;
      _hostTimeLeft = 10;
    });

    _hostSelectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_hostTimeLeft > 0) {
        setState(() {
          _hostTimeLeft--;
        });
      } else {
        _hostSelectionTimer?.cancel();

        // If time is up, select a random player as Card Czar
        _selectRandomCardCzar();
      }
    });
  }

  void _selectRandomCardCzar() {
    // Get list of players who submitted times
    final submittedPlayerIds = _playerTimes.keys.toList();

    if (submittedPlayerIds.isNotEmpty) {
      // Select a random player from those who submitted times
      final randomIndex =
          DateTime.now().millisecondsSinceEpoch % submittedPlayerIds.length;
      final selectedCzarId = submittedPlayerIds[randomIndex];

      // Update Firebase
      _setCardCzarAndStartGame(selectedCzarId);
    }
  }

  void _initializeGameState() {
    _roomRef = FirebaseDatabase.instance
        .ref()
        .child('rooms')
        .child(widget.roomId);

    // Listen for game updates
    _gameSubscription = _roomRef.onValue.listen(
      (event) {
        if (!mounted) return;

        if (event.snapshot.exists) {
          final roomData = event.snapshot.value as Map<dynamic, dynamic>?;
          if (roomData != null) {
            setState(() {
              _gameState =
                  roomData['gameState'] as String? ?? 'determining_card_czar';
              _players = roomData['players'] as Map<dynamic, dynamic>? ?? {};
              _selectedCardTopic = roomData['selectedCardTopic'] as String?;
              _currentCardCzarId = roomData['currentCardCzarId'] as String?;

              // Get player submission times if they exist
              if (roomData.containsKey('czarDeterminationTimes')) {
                _playerTimes = Map<String, String>.from(
                  (roomData['czarDeterminationTimes']
                              as Map<dynamic, dynamic>? ??
                          {})
                      .map((k, v) => MapEntry(k.toString(), v.toString())),
                );
              }              // Handle current black card if it exists
              if (roomData.containsKey('currentBlackCard')) {
                final blackCardData = roomData['currentBlackCard'];
                if (blackCardData != null) {
                  // Store blackCardData directly without conversion
                  // This avoids type conversion issues
                  _currentBlackCard = blackCardData as Map<dynamic, dynamic>;
                  
                  // Get number of cards to submit from black card
                  final pickValue = _currentBlackCard!['pick'];
                  if (pickValue is int) {
                    _cardsToSubmit = pickValue;
                  } else if (pickValue is String) {
                    _cardsToSubmit = int.tryParse(pickValue) ?? 1;
                  } else {
                    _cardsToSubmit = 1;
                  }
                }
              }

              // Handle player hand if it exists
              if (roomData.containsKey('playerHands') &&
                  roomData['playerHands'] is Map &&
                  (roomData['playerHands'] as Map).containsKey(
                    widget.playerId,
                  )) {
                final handData =
                    (roomData['playerHands'] as Map)[widget.playerId]
                        as List<dynamic>?;
                if (handData != null) {
                  _playerHand =
                      handData
                          .map(
                            (card) => Map<String, dynamic>.from(
                              (card as Map).map(
                                (k, v) => MapEntry(k.toString(), v),
                              ),
                            ),
                          )
                          .toList();
                }
              }

              // Handle player submissions if they exist
              if (roomData.containsKey('submissions')) {
                final submissionsData =
                    roomData['submissions'] as Map<dynamic, dynamic>?;
                if (submissionsData != null) {
                  _playerSubmissions = {};
                  submissionsData.forEach((playerId, submissions) {
                    if (submissions is List) {
                      _playerSubmissions[playerId.toString()] =
                          submissions
                              .map(
                                (card) => Map<String, dynamic>.from(
                                  (card as Map).map(
                                    (k, v) => MapEntry(k.toString(), v),
                                  ),
                                ),
                              )
                              .toList();
                    }
                  });

                  // Check if player has submitted
                  _hasSubmittedCards = _playerSubmissions.containsKey(
                    widget.playerId,
                  );

                  // Check if all non-Czar players have submitted
                  _allPlayersSubmitted = true;
                  _players.keys.forEach((playerId) {
                    if (playerId.toString() != _currentCardCzarId &&
                        !_playerSubmissions.containsKey(playerId.toString())) {
                      _allPlayersSubmitted = false;
                    }
                  });
                }
              }              // Handle winning submission if it exists
              if (roomData.containsKey('winningSubmission')) {
                final winningData = roomData['winningSubmission'];
                if (winningData != null) {
                  // Store the winning submission directly without conversion
                  _winningSubmission = winningData as Map<dynamic, dynamic>;
                  
                  // Extract the winning player ID
                  try {
                    _winningPlayerId = _winningSubmission['playerId']?.toString();
                  } catch (e) {
                    print('Error extracting winning player ID: $e');
                    _winningPlayerId = null;
                  }
                }
              }
            });

            // If the game state just changed to 'playing' and we don't have cards yet, draw cards
            if (_gameState == 'playing' &&
                _playerHand.isEmpty &&
                !_isDrawingCards) {
              _drawInitialCards();
            }
          }
        } else {
          // Room no longer exists, go back to main menu
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('The room has been closed.')),
            );
          }
        }
      },
      onError: (error) {
        print("Error in game subscription: $error");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $error')));
        }
      },
    );
  }

  // Set Card Czar and start the game
  void _setCardCzarAndStartGame(String cardCzarId) async {
    try {
      // Check if we have enough players
      final requiredPlayers =
          kDebugMode ? 2 : 3; // Lower threshold in debug mode
      if (_players.length < requiredPlayers) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Need at least $requiredPlayers players to start the game. Current: ${_players.length}',
              ),
              backgroundColor: Colors.red[900],
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return; // Don't start the game
      }

      // Update gameState to 'playing' and set the Card Czar
      await _roomRef.update({
        'gameState': 'playing',
        'currentCardCzarId': cardCzarId,
      });

      // Cancel any remaining timers
      _playerAnswerTimer?.cancel();
      _hostSelectionTimer?.cancel();

      print('Game started with Card Czar: $cardCzarId');
    } catch (e) {
      print('Error setting Card Czar: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting game: $e')));
      }
    }
  }

  // Draw initial cards for the player
  Future<void> _drawInitialCards() async {
    // Prevent multiple card draws
    if (_isDrawingCards) return;

    setState(() {
      _isDrawingCards = true;
    });

    try {
      // Check if we already have cards in Firebase
      final handRef = _roomRef.child('playerHands').child(widget.playerId);
      final snapshot = await handRef.get();

      if (snapshot.exists) {
        // We already have cards, no need to draw
        print('Player already has cards');
        setState(() {
          _isDrawingCards = false;
        });
        return;
      }

      // Get white cards for the selected topic
      if (_selectedCardTopic == null) {
        print('No card topic selected');
        setState(() {
          _isDrawingCards = false;
        });
        return;
      }

      // Fetch white cards from Firestore
      final cardsSnapshot =
          await FirebaseFirestore.instance
              .collection('cardTopics')
              .doc(_selectedCardTopic)
              .get();

      if (!cardsSnapshot.exists) {
        print('Card topic does not exist');
        setState(() {
          _isDrawingCards = false;
        });
        return;
      }

      final cardsData = cardsSnapshot.data();
      if (cardsData == null || !cardsData.containsKey('cards')) {
        print('No cards found for topic');
        setState(() {
          _isDrawingCards = false;
        });
        return;
      }

      final cards = List<Map<String, dynamic>>.from(cardsData['cards'] as List);

      // Filter out white cards
      final whiteCards =
          cards.where((card) => card['type'] == 'white').toList();

      if (whiteCards.isEmpty) {
        print('No white cards found');
        setState(() {
          _isDrawingCards = false;
        });
        return;
      }

      // Shuffle the cards
      whiteCards.shuffle();

      // Draw 10 cards
      final playerHand = whiteCards.take(10).toList();

      // Save to Firebase
      await handRef.set(playerHand);

      // Update local state
      setState(() {
        _playerHand = playerHand;
        _isDrawingCards = false;
      });

      print('Drew ${playerHand.length} cards for player');

      // If this is the Card Czar, also draw a black card
      if (_isCardCzar && _currentBlackCard == null) {
        _drawBlackCard();
      }
    } catch (e) {
      print('Error drawing cards: $e');
      setState(() {
        _isDrawingCards = false;
      });
    }
  }

  // Draw a black card
  Future<void> _drawBlackCard() async {
    if (!_isCardCzar) return; // Only the Card Czar can draw black cards

    try {
      // Get black cards for the selected topic
      if (_selectedCardTopic == null) return;

      // Fetch black cards from Firestore
      final cardsSnapshot =
          await FirebaseFirestore.instance
              .collection('cardTopics')
              .doc(_selectedCardTopic)
              .get();

      if (!cardsSnapshot.exists) return;

      final cardsData = cardsSnapshot.data();
      if (cardsData == null || !cardsData.containsKey('cards')) return;

      final cards = List<Map<String, dynamic>>.from(cardsData['cards'] as List);

      // Filter out black cards
      final blackCards =
          cards.where((card) => card['type'] == 'black').toList();

      if (blackCards.isEmpty) return;

      // Shuffle the cards
      blackCards.shuffle();

      // Draw 1 card
      final blackCard = blackCards.first;

      // Save to Firebase
      await _roomRef.child('currentBlackCard').set(blackCard);

      // Update local state (will happen via Firebase listener)

      print('Drew black card: ${blackCard['text']}');

      // Start submission timer
      _startCardSubmissionTimer();
    } catch (e) {
      print('Error drawing black card: $e');
    }
  }

  // Start timer for card submission
  void _startCardSubmissionTimer() {
    if (_isCardCzar) return; // Card Czar doesn't submit

    // Cancel existing timer if any
    _cardSubmissionTimer?.cancel();

    // Set 60-second timer for submissions
    _cardSubmissionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Timer logic will be implemented soon
    });
  }

  // Select a white card from hand
  void _selectWhiteCard(Map<String, dynamic> card) {
    if (_isCardCzar || _hasSubmittedCards)
      return; // Card Czar doesn't play or already submitted

    setState(() {
      // Toggle card selection
      final index = _selectedWhiteCards.indexWhere(
        (c) => c['text'] == card['text'],
      );

      if (index >= 0) {
        // Card already selected, deselect it
        _selectedWhiteCards.removeAt(index);
      } else {
        // Card not selected, select it if we haven't reached limit
        if (_selectedWhiteCards.length < _cardsToSubmit) {
          _selectedWhiteCards.add(card);
        }
      }
    });
  }

  // Submit selected white cards
  Future<void> _submitWhiteCards() async {
    if (_isCardCzar || _hasSubmittedCards)
      return; // Card Czar doesn't play or already submitted
    if (_selectedWhiteCards.length != _cardsToSubmit)
      return; // Must select exact number of cards

    try {
      // Save submission to Firebase
      await _roomRef
          .child('submissions')
          .child(widget.playerId)
          .set(_selectedWhiteCards);

      // Remove submitted cards from hand
      final newHand = [..._playerHand];
      for (final card in _selectedWhiteCards) {
        newHand.removeWhere((c) => c['text'] == card['text']);
      }

      // Update hand in Firebase
      await _roomRef.child('playerHands').child(widget.playerId).set(newHand);

      // Update local state (will happen via Firebase listener)
      setState(() {
        _hasSubmittedCards = true;
      });

      print('Submitted ${_selectedWhiteCards.length} cards');
    } catch (e) {
      print('Error submitting cards: $e');
    }
  }

  // Card Czar selects winning submission
  Future<void> _selectWinningSubmission(
    String playerId,
    List<Map<String, dynamic>> submission,
  ) async {
    if (!_isCardCzar) return; // Only Card Czar can select winner

    try {
      // Save winning submission to Firebase
      await _roomRef.child('winningSubmission').set({
        'playerId': playerId,
        'cards': submission,
      });

      // Increment player's score
      await _roomRef
          .child('players')
          .child(playerId)
          .child('score')
          .set(ServerValue.increment(1));

      print('Selected winning submission by $playerId');

      // Start new round after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _startNewRound();
        }
      });
    } catch (e) {
      print('Error selecting winner: $e');
    }
  }

  // Start a new round
  Future<void> _startNewRound() async {
    if (!_isCardCzar) return; // Only Card Czar starts new round

    try {
      // Rotate Card Czar role to next player
      final playerIds = _players.keys.toList();
      final currentIndex = playerIds.indexOf(_currentCardCzarId!);
      final nextIndex = (currentIndex + 1) % playerIds.length;
      final nextCardCzarId = playerIds[nextIndex];

      // Clean up previous round
      await _roomRef.update({
        'currentCardCzarId': nextCardCzarId,
        'currentBlackCard': null,
        'submissions': null,
        'winningSubmission': null,
      });

      print('Started new round with Card Czar: $nextCardCzarId');
    } catch (e) {
      print('Error starting new round: $e');
    }
  }

  // UI for entering "who did X most recently" time
  Widget _buildCardCzarDeterminationUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Determine the first Card Czar',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter when you last pooped (e.g., "20 minutes ago", "this morning")',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Player's time input with timer
            if (!_hasSubmittedTime) ...[
              // Timer display
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color:
                      _playerTimeLeft <= 5 ? Colors.red[900] : Colors.grey[800],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Time remaining: $_playerTimeLeft seconds',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        _playerTimeLeft <= 5 ? Colors.white : Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _timeInputController,
                focusNode: _timeInputFocusNode,
                decoration: InputDecoration(
                  labelText: 'Your answer',
                  hintText: 'e.g., "2 hours ago"',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _submitTime,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (_) => _submitTime(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Your submission:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _playerTimes[widget.playerId] ?? 'No answer submitted',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            // Display all player times that have been submitted
            const Text(
              'Submitted Answers:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (_playerTimes.isEmpty)
              const Text('Waiting for players to submit...'),
            ..._playerTimes.entries.map((entry) {
              final playerId = entry.key;
              final playerName = _getPlayerName(playerId);
              final isCurrentPlayer = playerId == widget.playerId;

              // Determine if this player is the currently selected Card Czar (if any)
              final isSelectedCardCzar = _currentCardCzarId == playerId;

              return GestureDetector(
                onTap: _isHost ? () => _selectPlayerAsCardCzar(playerId) : null,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isSelectedCardCzar ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelectedCardCzar ? Colors.white : Colors.grey[700]!,
                      width: isSelectedCardCzar ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      playerName,
                      style: TextStyle(
                        color: isSelectedCardCzar ? Colors.black : Colors.white,
                        fontWeight:
                            isSelectedCardCzar
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      entry.value,
                      style: TextStyle(
                        color:
                            isSelectedCardCzar ? Colors.black54 : Colors.grey,
                      ),
                    ),
                    leading: Icon(
                      isCurrentPlayer ? Icons.person : Icons.person_outline,
                      color: isSelectedCardCzar ? Colors.black : Colors.white,
                    ),
                    trailing:
                        _isHost
                            ? Icon(
                              Icons.check_circle,
                              color:
                                  isSelectedCardCzar
                                      ? Colors.black
                                      : Colors.transparent,
                            )
                            : null,
                  ),
                ),
              );
            }).toList(),

            const SizedBox(
              height: 30,
            ), // Only the host should see this button to choose the Card Czar
            if (_isHost) ...[
              // Host selection timer if host has submitted their time
              if (_hasSubmittedTime && _hostTimerStarted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color:
                        _hostTimeLeft <= 3 ? Colors.red[900] : Colors.grey[800],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Select a Card Czar: $_hostTimeLeft seconds',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          _hostTimeLeft <= 3 ? Colors.white : Colors.grey[300],
                    ),
                  ),
                ),
              ],
              ElevatedButton(
                onPressed: _playerTimes.length >= 2 ? _selectCardCzar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Select Card Czar'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap a player from the list to make them the Card Czar',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_hostTimerStarted) ...[
                const SizedBox(height: 10),
                Text(
                  'If you don\'t select, a random player will be chosen in $_hostTimeLeft seconds',
                  style: TextStyle(
                    color: _hostTimeLeft <= 3 ? Colors.red[300] : Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              const Text(
                'Waiting for the host to select the Card Czar...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Get player name from player ID
  String _getPlayerName(String playerId) {
    final playerData = _players[playerId];
    if (playerData is Map) {
      return playerData['name'] as String? ?? 'Unknown player';
    }
    return 'Unknown player';
  }

  // Check if current player is the host
  bool get _isHost {
    // The host is the first player in the player list
    if (_players.isNotEmpty) {
      final hostId = _players.keys.first;
      return hostId == widget.playerId;
    }
    return false;
  }

  // Submit player's time for Card Czar determination
  void _submitTime() {
    final time = _timeInputController.text.trim();
    if (time.isNotEmpty) {
      setState(() {
        _hasSubmittedTime = true;
      });

      // Store the time in Firebase
      _roomRef.child('czarDeterminationTimes').child(widget.playerId).set(time);

      // If this is the host, start the host selection timer after submitting
      if (_isHost) {
        _startHostSelectionTimer();
      }
    }
  }

  // Host selects a player as Card Czar
  void _selectCardCzar() {
    // Show dialog with player list to select Card Czar
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Select Card Czar',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children:
                    _playerTimes.entries.map((entry) {
                      final playerId = entry.key;
                      final playerName = _getPlayerName(playerId);
                      final playerAnswer = entry.value;
                      return ListTile(
                        title: Text(
                          playerName,
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          playerAnswer,
                          style: TextStyle(color: Colors.grey),
                        ),
                        onTap: () {
                          // Close dialog
                          Navigator.pop(context);

                          // Set selected player as Card Czar and start game
                          _selectPlayerAsCardCzar(playerId);
                        },
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // Select a specific player as Card Czar
  void _selectPlayerAsCardCzar(String playerId) {
    if (!_isHost) return; // Only host can select

    // Update UI to show selection
    setState(() {
      _currentCardCzarId = playerId;
    });

    // Confirm selection with a brief message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getPlayerName(playerId)} selected as Card Czar'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.grey[800],
      ),
    );

    // Start the game with selected Card Czar
    _setCardCzarAndStartGame(playerId);
  }

  // UI for the main game
  Widget _buildGameUI() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Game status header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Card Topic: ${_selectedCardTopic ?? "Not selected"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        color: _isCardCzar ? Colors.white : Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isCardCzar
                            ? 'You are the Card Czar!'
                            : 'Card Czar: ${_getPlayerName(_currentCardCzarId ?? '')}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isCardCzar ? Colors.white : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Current black card (if available)
            if (_currentBlackCard != null) ...[
              const Text(
                'Black Card:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: GameCard(
                  cardData: _currentBlackCard!,
                  isBlack: true,
                  animate: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cardsToSubmit > 1
                    ? 'Submit $_cardsToSubmit white cards'
                    : 'Submit 1 white card',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ] else if (_isCardCzar) ...[
              // Card Czar can draw a black card if not already drawn
              Center(
                child: ElevatedButton.icon(
                  onPressed: _drawBlackCard,
                  icon: const Icon(Icons.style),
                  label: const Text('Draw a Black Card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Center(
                child: Text(
                  'Waiting for Card Czar to draw a black card...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Player submissions (for Card Czar)
            if (_isCardCzar &&
                _currentBlackCard != null &&
                _allPlayersSubmitted) ...[
              const Text(
                'Player Submissions:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...(_playerSubmissions.entries.map((entry) {
                final playerId = entry.key;
                final cards = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Submission #${_playerSubmissions.keys.toList().indexOf(playerId) + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              cards
                                  .map(
                                    (card) => GameCard(
                                      cardData: card,
                                      isBlack: false,
                                      animate: true,
                                      onTap:
                                          () => _selectWinningSubmission(
                                            playerId,
                                            cards,
                                          ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: ElevatedButton(
                          onPressed:
                              () => _selectWinningSubmission(playerId, cards),
                          child: const Text('Select as Winner'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList()),
            ] else if (_isCardCzar && _currentBlackCard != null) ...[
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Waiting for all players to submit their cards...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_playerSubmissions.length} of ${_players.length - 1} players have submitted',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],

            // Win announcement (if there is a winner)
            if (_winningPlayerId != null &&
                _winningSubmission.containsKey('cards')) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '🏆 ${_getPlayerName(_winningPlayerId!)} WINS! 🏆',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,                      children:
                          (() {
                            // Safely extract cards from winning submission
                            List<Map<dynamic, dynamic>> cards = [];
                            try {
                              final cardsData = _winningSubmission['cards'];
                              if (cardsData is List) {
                                cards = cardsData.cast<Map<dynamic, dynamic>>();
                              }
                            } catch (e) {
                              print('Error extracting winning cards: $e');
                            }
                            return cards.map(
                              (card) => GameCard(
                                cardData: card,
                                isBlack: false,
                                animate: true,
                              ),
                            ).toList();
                          })(),
                      ),
                    ),
                    if (_isCardCzar) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _startNewRound,
                        child: const Text('Start New Round'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Player's hand (if not Card Czar)
            if (!_isCardCzar &&
                _currentBlackCard != null &&
                !_hasSubmittedCards) ...[
              const Text(
                'Your White Cards:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select cards to play:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                height: 250,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      _playerHand.map((card) {
                        final isSelected = _selectedWhiteCards.any(
                          (c) => c['text'] == card['text'],
                        );
                        return GameCard(
                          cardData: card,
                          isBlack: false,
                          isSelected: isSelected,
                          animate: true,
                          onTap: () => _selectWhiteCard(card),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    _selectedWhiteCards.length == _cardsToSubmit
                        ? _submitWhiteCards
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  side: const BorderSide(color: Colors.white),
                ),
                child: Text(
                  _selectedWhiteCards.length == _cardsToSubmit
                      ? 'Submit Cards'
                      : 'Select $_cardsToSubmit Cards First',
                ),
              ),
            ] else if (!_isCardCzar && _hasSubmittedCards) ...[
              const Text(
                'Your Submission:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      (_playerSubmissions[widget.playerId] ?? [])
                          .map(
                            (card) => GameCard(
                              cardData: card,
                              isBlack: false,
                              animate: false,
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Waiting for other players to submit...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ] else if (_isDrawingCards) ...[
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Drawing cards...'),
                  ],
                ),
              ),
            ],

            // Game scores
            const SizedBox(height: 32),
            const Text(
              'Scores:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ..._players.entries.map((entry) {
              final playerId = entry.key;
              final playerName = _getPlayerName(playerId);
              final isCurrentPlayer = playerId == widget.playerId;
              final score =
                  (entry.value is Map)
                      ? (entry.value as Map)['score'] as int? ?? 0
                      : 0;
              final isWinner = playerId == _winningPlayerId;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isWinner ? Colors.white : Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrentPlayer ? Colors.white : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCurrentPlayer ? Icons.person : Icons.person_outline,
                      color: isWinner ? Colors.black : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        playerName,
                        style: TextStyle(
                          fontWeight:
                              isCurrentPlayer
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          color: isWinner ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWinner ? Colors.black : Colors.grey[800],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        score.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isWinner ? Colors.white : null,
                        ),
                      ),
                    ),
                    if (playerId == _currentCardCzarId) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'CZAR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Unhinged Cards'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveGame,
            tooltip: 'Leave Game',
          ),
        ],
      ),
      body:
          _gameState == 'determining_card_czar'
              ? _buildCardCzarDeterminationUI()
              : _buildGameUI(),
    );
  }

  void _leaveGame() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Leave Game?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to leave the game? This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performLeaveGame();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Leave'),
              ),
            ],
          ),
    );
  }

  void _performLeaveGame() async {
    try {
      // If player is host, delete the room, otherwise just remove the player
      if (_isHost) {
        await _roomRef.remove();
      } else {
        await _roomRef.child('players').child(widget.playerId).remove();
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('Error leaving game: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error leaving game: $e')));
      }
    }
  }

  @override
  void dispose() {
    _gameSubscription.cancel();
    _timeInputController.dispose();
    _timeInputFocusNode.dispose();
    _playerAnswerTimer?.cancel();
    _hostSelectionTimer?.cancel();
    super.dispose();
  }
}
