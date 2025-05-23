import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../components/black_card_deck.dart';
import '../components/black_card_display.dart';
import '../components/player_hand.dart';
import '../components/card_submissions.dart';
import '../components/leaderboard.dart';
import '../components/loading_animation.dart';
import '../components/result_animation.dart';
import '../services/game_service.dart';

class GameScreen extends StatefulWidget {
  final String roomId;
  final String playerId;

  const GameScreen({Key? key, required this.roomId, required this.playerId})
    : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameService _game_service;
  late StreamSubscription<DatabaseEvent> _game_state_subscription;
  late StreamSubscription<DatabaseEvent> _players_subscription;
  late StreamSubscription<DatabaseEvent> _black_card_subscription;
  late StreamSubscription<DatabaseEvent> _player_hand_subscription;
  late StreamSubscription<DatabaseEvent> _submissions_subscription;
  late StreamSubscription<DatabaseEvent> _room_subscription;

  // Game state
  String _game_state = 'checking_game_conditions';
  Map<dynamic, dynamic> _players = {};
  Map<dynamic, dynamic>? _current_black_card;
  List<Map<String, dynamic>> _player_hand = [];
  Map<String, List<Map<String, dynamic>>> _player_submissions = {};
  List<Map<String, dynamic>> _selected_cards = [];
  Map<dynamic, dynamic> _winning_submission = {};
  bool _is_card_czar = false;
  bool _is_host = false;
  bool _has_submitted_cards = false;

  @override
  void initState() {
    super.initState();
    _initialize_game();
  }

  void _initialize_game() {
    _game_service = GameService(
      room_id: widget.roomId,
      player_id: widget.playerId,
    );

    // Listen to game state changes
    _game_state_subscription = _game_service.listen_to_game_state().listen((
      event,
    ) {
      if (event.snapshot.exists) {
        final state = event.snapshot.value as String?;
        if (state != null) {
          // Don't revert waiting_for_submissions to players_selecting_cards
          if (_game_state == 'waiting_for_submissions' &&
              state == 'players_selecting_cards') {
            return;
          }

          // Always update the local state for any other state changes
          setState(() {
            _game_state = state;
          });
          _handle_game_state_change(state);
        }
      }
    }); // Listen to players changes
    _players_subscription = _game_service.listen_to_players().listen((event) {
      if (event.snapshot.exists) {
        final players = event.snapshot.value as Map?;
        if (players != null) {
          setState(() {
            _players = players;
            // Update Card Czar status
            for (final entry in players.entries) {
              if (entry.key == widget.playerId && entry.value is Map) {
                _is_card_czar = entry.value['isCardCzar'] == true;
                _is_host = entry.value['isHost'] == true;

                // Reset local submitted state if the player's hasSubmitted flag is reset
                if (entry.value['hasSubmitted'] == false &&
                    _has_submitted_cards) {
                  _has_submitted_cards = false;
                }
              }
            }
          });
        }
      }
    });

    // Listen to black card changes
    _black_card_subscription = _game_service
        .listen_to_current_black_card()
        .listen((event) {
          if (event.snapshot.exists) {
            final black_card = event.snapshot.value as Map?;
            if (black_card != null) {
              setState(() {
                _current_black_card = black_card;
              });
            }
          } else {
            setState(() {
              _current_black_card = null;
            });
          }
        }); // Listen to player's hand changes
    _player_hand_subscription = _game_service.listen_to_player_hand().listen((
      event,
    ) {
      if (event.snapshot.exists) {
        final hand = event.snapshot.value as List?;
        if (hand != null) {
          setState(() {
            _player_hand = List<Map<String, dynamic>>.from(
              hand.map((card) => Map<String, dynamic>.from(card as Map)),
            );
          });
        }
      } else {
        // If the player doesn't have cards in the dedicated player hands location,
        // check if they have cards in their player object
        _game_service.players_ref
            .child(widget.playerId)
            .child('cards')
            .get()
            .then((snapshot) {
              if (snapshot.exists) {
                final hand = snapshot.value as List?;
                if (hand != null) {
                  setState(() {
                    _player_hand = List<Map<String, dynamic>>.from(
                      hand.map(
                        (card) => Map<String, dynamic>.from(card as Map),
                      ),
                    );
                  });

                  // Sync these cards to the player_hands location for consistency
                  _game_service.player_hand_ref.set(hand);
                }
              }
            });
      }
    }); // Listen to submissions changes
    _submissions_subscription = _game_service.listen_to_submissions().listen((
      event,
    ) {
      if (event.snapshot.exists) {
        final submissions = event.snapshot.value as Map?;
        if (submissions != null) {
          // Log detailed information about submissions for debugging
          if (_is_card_czar) {
            print('📝 CARD CZAR RECEIVED SUBMISSIONS EVENT:');
            print('Current game state: $_game_state');
            print('Submissions data: ${submissions.toString()}');
            print('Number of submissions: ${submissions.length}');

            // Count non-czar players
            int nonCzarPlayers = 0;
            for (final entry in _players.entries) {
              final playerData = entry.value;
              if (playerData is Map && playerData['isCardCzar'] != true) {
                nonCzarPlayers++;
              }
            }
            print('Number of non-czar players: $nonCzarPlayers');

            // If all non-czar players have submitted and we're in players_selecting_cards or waiting_for_submissions
            if (submissions.length >= nonCzarPlayers &&
                (_game_state == 'players_selecting_cards' ||
                    _game_state == 'waiting_for_submissions') &&
                nonCzarPlayers > 0) {
              print(
                '⚠️ All players have submitted, but game state is still $_game_state',
              );
              print('Checking if the host should update the game state...');

              // Allow the card czar to update the game state if all players have submitted
              _game_service.check_all_players_submitted().then((allSubmitted) {
                if (allSubmitted) {
                  print(
                    'Czar detected all submissions complete - updating game state to czar_selecting_winner',
                  );
                  _game_service.update_game_state('czar_selecting_winner');
                }
              });
            }
          }

          final formattedSubmissions = <String, List<Map<String, dynamic>>>{};

          submissions.forEach((playerId, cards) {
            if (cards is List) {
              formattedSubmissions[playerId
                  .toString()] = List<Map<String, dynamic>>.from(
                cards.map((card) => Map<String, dynamic>.from(card as Map)),
              );
            }
          });

          setState(() {
            _player_submissions = formattedSubmissions;
          });
        }
      } else {
        setState(() {
          _player_submissions = {};
          _has_submitted_cards = false;
        });
      }
    });

    // Listen to room-level changes (winning submission)
    _room_subscription = _game_service.room_ref
        .child('winningSubmission')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final winning_submission = event.snapshot.value as Map?;
            if (winning_submission != null) {
              setState(() {
                _winning_submission = winning_submission;
              });
            }
          } else {
            setState(() {
              _winning_submission = {};
            });
          }
        });

    // Initialize game if host
    _game_service.is_current_player_host().then((is_host) {
      if (is_host) {
        _game_service.initialize_game();
      }
    });
  }

  void _handle_game_state_change(String state) {
    // Skip state change handling if we're in a local waiting_for_submissions state
    // and the global state is still players_selecting_cards
    if (_game_state == 'waiting_for_submissions' &&
        state == 'players_selecting_cards') {
      return;
    }

    switch (state) {
      case 'checking_game_conditions':
        if (_is_host) {
          _check_game_conditions();
        }
        break;

      case 'selecting_card_czar':
        if (_is_host) {
          _select_card_czar();
        }
        break;

      case 'czar_drawing_black_card':
        // No automatic action, waiting for Card Czar to draw
        break;

      case 'czar_viewing_black_card':
        // No automatic action, waiting for timer to complete
        break;

      case 'revealing_black_card':
        // No automatic action, waiting for timer to complete
        break;

      case 'players_selecting_cards':
        // Reset selected cards when entering this state
        setState(() {
          _selected_cards = [];
        });
        break;

      case 'waiting_for_submissions':
        if (_is_host) {
          _check_all_players_submitted();
        }
        break;

      case 'czar_selecting_winner':
        // No automatic action, waiting for Card Czar to select
        break;

      case 'showing_round_result':
        // No automatic action, waiting for timer to complete
        break;

      case 'showing_leaderboard':
        // No automatic action, waiting for timer to complete in the Leaderboard component
        break;

      case 'game_over':
        // No automatic action, game is over
        break;
    }
  }

  // Host functions to manage game flow
  Future<void> _check_game_conditions() async {
    try {
      // Check if a player has enough points to win
      final has_winner = await _game_service.check_winning_condition();
      if (has_winner) {
        print('Game over: A player has reached the winning points');
        await _game_service.update_game_state('game_over');
        return;
      }

      // Check if black deck has cards
      final black_deck_has_cards =
          await _game_service.check_black_cards_available();
      if (!black_deck_has_cards) {
        print('Game over: No black cards available');
        await _game_service.update_game_state('game_over');
        return;
      }

      // Check if white deck has enough cards
      final white_deck_has_enough_cards =
          await _game_service.check_white_cards_available_for_players();
      if (!white_deck_has_enough_cards) {
        print('Game over: Not enough white cards available');
        await _game_service.update_game_state('game_over');
        return;
      }

      // Check if all players have cards
      final all_players_have_cards =
          await _game_service.check_all_players_have_cards();

      // If any player doesn't have cards, shuffle the white deck and draw cards
      if (!all_players_have_cards) {
        print('Some players need cards, shuffling deck and drawing cards');
        await _game_service.shuffle_white_deck();

        // Draw cards for all players
        await _game_service.draw_cards_for_players();

        // Double-check that all players have cards now
        final rechecked_all_players_have_cards =
            await _game_service.check_all_players_have_cards();

        if (!rechecked_all_players_have_cards) {
          // If we still don't have cards for everyone after trying to draw,
          // there's a more serious issue
          print(
            'Game over: Failed to provide cards to all players after draw attempt',
          );
          await _game_service.update_game_state('game_over');
          return;
        }
      }

      // All checks passed, proceed to card czar selection
      print('All game conditions passed, proceeding to card czar selection');
      await _game_service.update_game_state('selecting_card_czar');
    } catch (e) {
      print('Error in checking game conditions: $e');
      // For safety, if something goes wrong with the checks, end the game
      await _game_service.update_game_state('game_over');
    }
  }

  Future<void> _select_card_czar() async {
    await _game_service.select_card_czar();
    await _game_service.update_game_state('czar_drawing_black_card');
  }

  Future<void> _check_all_players_submitted() async {
    print('🔄 Host is checking if all players have submitted their cards...');

    // Debug log current players and their submission status
    final playerSnapshot = await _game_service.players_ref.get();
    if (playerSnapshot.exists) {
      final players = playerSnapshot.value as Map?;
      if (players != null) {
        print('Players in the room:');
        for (final entry in players.entries) {
          final playerId = entry.key;
          final playerData = entry.value as Map?;
          final isCardCzar = playerData?['isCardCzar'] == true;
          final hasSubmitted = playerData?['hasSubmitted'] == true;
          print(
            'Player $playerId: Card Czar: $isCardCzar, Submitted: $hasSubmitted',
          );
        }
      }
    }

    // Debug log current submissions
    final submissionsSnapshot = await _game_service.submissions_ref.get();
    if (submissionsSnapshot.exists) {
      final submissions = submissionsSnapshot.value as Map?;
      print('Current submissions: ${submissions?.length ?? 0}');
      if (submissions != null) {
        for (final entry in submissions.entries) {
          print('Submission from player: ${entry.key}');
        }
      }
    } else {
      print('No submissions found in database');
    }

    // First check immediately if all players have submitted
    bool all_submitted = await _game_service.check_all_players_submitted();
    if (all_submitted) {
      print(
        '✅ All players have already submitted their cards. Moving to czar selection phase immediately.',
      );
      await _game_service.update_game_state('czar_selecting_winner');
      return;
    }

    // Set a maximum wait time (10 seconds) to force state transition
    int maxWaitSeconds = 10;
    int elapsedSeconds = 0;

    // Start a timer to periodically check if all players have submitted
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        print('Timer cancelled - widget no longer mounted');
        return;
      }

      elapsedSeconds++;

      // Check if all non-czar players have submitted
      final all_submitted = await _game_service.check_all_players_submitted();

      // Also check if submissions match the number of non-czar players as a fallback
      final submissionsData = await _game_service.submissions_ref.get();
      int submissionCount = 0;
      if (submissionsData.exists && submissionsData.value is Map) {
        submissionCount = (submissionsData.value as Map).length;
      }

      // Count non-czar players
      final playersData = await _game_service.players_ref.get();
      int nonCzarCount = 0;
      if (playersData.exists && playersData.value is Map) {
        final players = playersData.value as Map;
        for (final entry in players.entries) {
          if (entry.value is Map && entry.value['isCardCzar'] != true) {
            nonCzarCount++;
          }
        }
      }

      bool shouldMoveToNextState =
          all_submitted ||
          (submissionCount >= nonCzarCount && nonCzarCount > 0) ||
          elapsedSeconds >= maxWaitSeconds;

      if (shouldMoveToNextState) {
        String reason =
            all_submitted
                ? 'all players submitted'
                : (submissionCount >= nonCzarCount
                    ? 'submission count matches player count'
                    : 'maximum wait time reached');

        print('✅ Moving to czar selection phase. Reason: $reason');
        timer.cancel();

        // Update the global game state to czar_selecting_winner
        print('Updating game state to czar_selecting_winner');
        await _game_service.update_game_state('czar_selecting_winner');
        print('Game state updated successfully');
      } else {
        print(
          '⏳ Still waiting for some players to submit their cards... ($elapsedSeconds/$maxWaitSeconds seconds elapsed)',
        );
        print(
          'Submission count: $submissionCount, Non-Czar players: $nonCzarCount',
        );
      }
    });
  }

  // Czar actions
  Future<void> _draw_black_card() async {
    await _game_service.draw_black_card();
    await _game_service.update_game_state('czar_viewing_black_card');
  }

  void _complete_czar_viewing() async {
    await _game_service.update_game_state('revealing_black_card');
  }

  void _complete_black_card_reveal() async {
    await _game_service.update_game_state('players_selecting_cards');
  }

  // Player actions
  void _select_white_card(Map<String, dynamic> card) {
    if (_game_state != 'players_selecting_cards' || _has_submitted_cards) {
      return;
    }

    setState(() {
      if (_selected_cards.contains(card)) {
        _selected_cards.remove(card);
      } else {
        final cards_to_submit = _current_black_card?['pick'] as int? ?? 1;

        if (_selected_cards.length < cards_to_submit) {
          _selected_cards.add(card);
        } else if (cards_to_submit == 1) {
          // If only one card required, replace the selected card
          _selected_cards = [card];
        }
      }
    });
  }

  Future<void> _submit_cards() async {
    if (_game_state != 'players_selecting_cards' || _has_submitted_cards) {
      print(
        '⚠️ Cannot submit cards - state: $_game_state, already submitted: $_has_submitted_cards',
      );
      return;
    }

    final cards_to_submit = _current_black_card?['pick'] as int? ?? 1;
    if (_selected_cards.length != cards_to_submit) {
      print(
        '⚠️ Not enough cards selected - have: ${_selected_cards.length}, need: $cards_to_submit',
      );
      return;
    }

    print(
      '🎮 Player ${widget.playerId} submitting ${_selected_cards.length} cards',
    );

    setState(() {
      _has_submitted_cards = true;
      // Only update local state to waiting_for_submissions
      _game_state = 'waiting_for_submissions';
    });

    // Log current players and their submission status before our submission
    final playersBefore = await _game_service.players_ref.get();
    if (playersBefore.exists) {
      final playersMap = playersBefore.value as Map?;
      if (playersMap != null) {
        print('Players before submission:');
        for (final entry in playersMap.entries) {
          final playerId = entry.key;
          final playerData = entry.value as Map?;
          final isCardCzar = playerData?['isCardCzar'] == true;
          final hasSubmitted = playerData?['hasSubmitted'] == true;
          print(
            'Player $playerId: Card Czar: $isCardCzar, Submitted: $hasSubmitted',
          );
        }
      }
    }

    // Submit the cards and mark the player as having submitted
    print('Calling game service to submit cards');
    await _game_service.submit_white_cards(_selected_cards);
    print('Cards submitted successfully');

    // Log current players and their submission status after our submission
    final playersAfter = await _game_service.players_ref.get();
    if (playersAfter.exists) {
      final playersMap = playersAfter.value as Map?;
      if (playersMap != null) {
        print('Players after submission:');
        for (final entry in playersMap.entries) {
          final playerId = entry.key;
          final playerData = entry.value as Map?;
          final isCardCzar = playerData?['isCardCzar'] == true;
          final hasSubmitted = playerData?['hasSubmitted'] == true;
          print(
            'Player $playerId: Card Czar: $isCardCzar, Submitted: $hasSubmitted',
          );
        }
      }
    }

    // Check submissions in the database after our submission
    final submissionsAfter = await _game_service.submissions_ref.get();
    if (submissionsAfter.exists) {
      final submissions = submissionsAfter.value as Map?;
      print(
        'Current submissions after our submit: ${submissions?.length ?? 0}',
      );
      if (submissions != null) {
        for (final entry in submissions.entries) {
          print('Submission from player: ${entry.key}');
        }
      }
    }

    // If the player is also the host, run a check
    if (_is_host) {
      print('This player is the host, checking if all players submitted');
      bool allSubmitted = await _game_service.check_all_players_submitted();
      print('All players submitted according to check: $allSubmitted');
    }

    // If this player was the last to submit, the game service will handle the state transition
    // through the check_all_players_submitted method
  }

  Future<void> _select_winning_submission(
    String player_id,
    List<Map<String, dynamic>> cards,
  ) async {
    if (!_is_card_czar || _game_state != 'czar_selecting_winner') {
      return;
    }

    await _game_service.select_winner(player_id);
    await _game_service.update_game_state('showing_round_result');
  }

  void _on_leaderboard_timeout() async {
    if (_is_host) {
      await _game_service.update_game_state('checking_game_conditions');
    }
  }

  // UI Builders
  Widget _build_checking_conditions() {
    return Center(
      child: LoadingAnimation(message: 'Checking game conditions...'),
    );
  }

  Widget _build_selecting_card_czar() {
    return Center(child: LoadingAnimation(message: 'Selecting Card Czar...'));
  }

  Widget _build_czar_drawing_black_card() {
    if (_is_card_czar) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You are the Card Czar!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Draw a black card',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Montserrat',
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            BlackCardDeck(
              on_card_drawn: _draw_black_card,
              is_interactive: true,
              timer_duration: 5,
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: LoadingAnimation(
          message: 'Waiting for Card Czar to draw a black card...',
        ),
      );
    }
  }
  Widget _build_czar_viewing_black_card() {
    if (_is_card_czar) {
      return BlackCardDisplay(
        card_data: _current_black_card,
        on_reveal_complete: _complete_czar_viewing,
      );
    } else {
      return Center(
        child: LoadingAnimation(
          message: 'Card Czar is viewing the black card...',
        ),
      );
    }
  }
  Widget _build_revealing_black_card() {
    return BlackCardDisplay(
      card_data: _current_black_card,
      on_reveal_complete: _complete_black_card_reveal,
    );
  }
  Widget _build_players_selecting_cards() {
    if (_is_card_czar) {
      return Column(
        children: [
          Expanded(
            flex: 1,
            child: BlackCardDisplay(
              card_data: _current_black_card,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: LoadingAnimation(
                message: 'Waiting for players to select their cards...',
              ),
            ),
          ),
        ],
      );    } else {
      return Column(
        children: [
          Expanded(
            flex: 2,
            child: BlackCardDisplay(
              card_data: _current_black_card,
            ),
          ),
          Expanded(
            flex: 3,
            child: PlayerHand(
              cards: _player_hand,
              cards_to_submit: _current_black_card?['pick'] as int? ?? 1,
              selected_cards: _selected_cards,
              on_card_selected: _select_white_card,
              on_cards_submitted: _submit_cards,
              is_submission_enabled: !_has_submitted_cards,
              submission_time_limit: 20,
              auto_submit_on_timeout: true,
            ),
          ),
        ],
      );
    }
  }

  Widget _build_waiting_for_submissions() {
    return Center(
      child: LoadingAnimation(
        message: 'Waiting for all players to submit their cards...',
      ),
    );
  }

  Widget _build_czar_selecting_winner() {    if (_is_card_czar) {
      return Column(
        children: [
          Expanded(
            flex: 1,
            child: BlackCardDisplay(
              card_data: _current_black_card,
            ),
          ),
          Expanded(
            flex: 2,
            child: CardSubmissions(
              submissions: _player_submissions,
              players: _players,
              on_winner_selected: _select_winning_submission,
              is_interactive: true,
              selection_time_limit: 30,
            ),
          ),
        ],
      );
    } else {
      return Center(
        child: LoadingAnimation(
          message: 'Waiting for Card Czar to select the winner...',
        ),
      );
    }
  }

  Widget _build_showing_round_result() {
    final String? winning_player_id =
        _winning_submission['playerId'] as String?;
    final bool is_winner = winning_player_id == widget.playerId;

    return ResultAnimation(
      is_winner: is_winner,
      is_card_czar: _is_card_czar,
      on_animation_complete: () async {
        if (_is_host) {
          await _game_service.update_game_state('showing_leaderboard');
        }
      },
    );
  }

  Widget _build_showing_leaderboard() {
    return Leaderboard(
      players: _players,
      display_duration: 5,
      on_timeout: _on_leaderboard_timeout,
    );
  }

  Widget _build_game_over() {
    // Check if this player is the winner
    bool isWinner = false;
    String winnerName = "";

    for (final entry in _players.entries) {
      if (entry.value is Map && entry.value['isWinner'] == true) {
        winnerName = entry.value['name'] ?? "Unknown Player";
        isWinner = entry.key == widget.playerId;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Game Over',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Show if player won
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isWinner
                      ? Colors.green.withOpacity(0.3)
                      : Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWinner ? Colors.green : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  isWinner ? 'YOU WON!' : '$winnerName WON!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                    color: isWinner ? Colors.green : Colors.white,
                  ),
                ),
                if (isWinner) const SizedBox(height: 10),
                if (isWinner)
                  Icon(Icons.emoji_events, color: Colors.amber, size: 50),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Display leaderboard using our existing component
          Expanded(
            child: Leaderboard(
              players: _players,
              display_duration: 0, // No auto-continue since it's game over
              on_timeout: () {}, // Empty callback as it won't be called
              is_game_over: true, // Flag to display as game over
            ),
          ),

          const SizedBox(height: 24),

          // Back to lobby button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: Size(200, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Back to Lobby',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _on_will_pop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Game Room: ${widget.roomId}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                _show_game_info();
              },
            ),
          ],
        ),
        body: SafeArea(child: _build_game_ui()),
      ),
    );
  }

  Widget _build_game_ui() {
    switch (_game_state) {
      case 'checking_game_conditions':
        return _build_checking_conditions();

      case 'selecting_card_czar':
        return _build_selecting_card_czar();

      case 'czar_drawing_black_card':
        return _build_czar_drawing_black_card();

      case 'czar_viewing_black_card':
        return _build_czar_viewing_black_card();

      case 'revealing_black_card':
        return _build_revealing_black_card();

      case 'players_selecting_cards':
        return _build_players_selecting_cards();

      case 'waiting_for_submissions':
        return _build_waiting_for_submissions();

      case 'czar_selecting_winner':
        return _build_czar_selecting_winner();

      case 'showing_round_result':
        return _build_showing_round_result();

      case 'showing_leaderboard':
        return _build_showing_leaderboard();

      case 'game_over':
        return _build_game_over();

      default:
        return Center(
          child: Text(
            '$_game_state',
            style: const TextStyle(color: Colors.white),
          ),
        );
    }
  }

  Future<bool> _on_will_pop() async {
    final bool? should_pop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Exit Game?'),
            content: Text(
              _is_host
                  ? 'If you leave, the room will be deleted and other players will be disconnected.'
                  : 'Are you sure you want to leave this game?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Exit'),
              ),
            ],
          ),
    );

    return should_pop ?? false;
  }

  void _show_game_info() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Game Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Game State: $_game_state'),
                const SizedBox(height: 8),
                Text('Room ID: ${widget.roomId}'),
                const SizedBox(height: 8),
                Text('Player ID: ${widget.playerId}'),
                const SizedBox(height: 8),
                Text('Role: ${_is_card_czar ? 'Card Czar' : 'Player'}'),
                const SizedBox(height: 8),
                Text('Host: ${_is_host ? 'Yes' : 'No'}'),
                const SizedBox(height: 8),
                Text('Players: ${_players.length}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _game_state_subscription.cancel();
    _players_subscription.cancel();
    _black_card_subscription.cancel();
    _player_hand_subscription.cancel();
    _submissions_subscription.cancel();
    _room_subscription.cancel();
    super.dispose();
  }
}
