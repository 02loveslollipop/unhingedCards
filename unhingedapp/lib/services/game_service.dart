import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

class GameService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String room_id;
  final String player_id;

  GameService({required this.room_id, required this.player_id});

  DatabaseReference get room_ref => _db.child('rooms').child(room_id);
  DatabaseReference get game_state_ref => room_ref.child('gameState');
  DatabaseReference get players_ref => room_ref.child('players');
  DatabaseReference get player_ref => players_ref.child(player_id);
  DatabaseReference get black_cards_ref => room_ref.child('blackCards');
  DatabaseReference get white_cards_ref => room_ref.child('whiteCards');
  DatabaseReference get current_black_card_ref =>
      room_ref.child('currentBlackCard');
  DatabaseReference get player_hands_ref => room_ref.child('playerHands');
  DatabaseReference get player_hand_ref => player_hands_ref.child(player_id);
  DatabaseReference get submissions_ref => room_ref.child('submissions');
  DatabaseReference get round_submissions_for_reveal_ref => room_ref.child('roundSubmissionsForReveal'); // New Ref
  DatabaseReference get winning_points_ref => room_ref.child('winningPoints');
  // Game state checks
  Future<bool> check_player_has_cards() async {
    final snapshot = await player_hand_ref.get();
    if (snapshot.exists) {
      final cards = List<dynamic>.from(snapshot.value as List? ?? []);
      return cards.isNotEmpty;
    }
    return false;
  }

  Future<bool> check_all_players_have_cards() async {
    final playersSnapshot = await players_ref.get();
    if (!playersSnapshot.exists) return false;

    final players = playersSnapshot.value as Map?;
    if (players == null || players.isEmpty) return false;

    // Check if any player has no cards
    for (final player_id in players.keys) {
      // First check the dedicated player hands location
      final playerHandSnapshot =
          await player_hands_ref.child(player_id.toString()).get();

      if (!playerHandSnapshot.exists ||
          (playerHandSnapshot.value is List &&
              (playerHandSnapshot.value as List).isEmpty)) {
        // If no cards in dedicated location, check the player object's cards field
        final playerCardsSnapshot =
            await players_ref.child(player_id.toString()).child('cards').get();

        if (!playerCardsSnapshot.exists ||
            (playerCardsSnapshot.value is List &&
                (playerCardsSnapshot.value as List).isEmpty)) {
          // Player has no cards in either location
          return false;
        }

        // If cards were found in player object but not in dedicated location, sync them
        if (playerCardsSnapshot.exists &&
            playerCardsSnapshot.value is List) {
          await player_hands_ref
              .child(player_id.toString())
              .set(playerCardsSnapshot.value);
        }
      }
    }

    return true;
  }

  Future<bool> check_black_cards_available() async {
    try {
      final snapshot = await black_cards_ref.get();

      if (!snapshot.exists) {
        print('No black cards found, initializing decks');
        await _initialize_card_decks();

        // Check again after initialization
        final newSnapshot = await black_cards_ref.get();
        if (!newSnapshot.exists) {
          print('Failed to initialize black cards');
          return false;
        }

        final cards = List<dynamic>.from(newSnapshot.value as List? ?? []);
        return cards.isNotEmpty;
      }

      final cards = List<dynamic>.from(snapshot.value as List? ?? []);

      if (cards.isEmpty) {
        print('Black cards list is empty, reinitializing decks');
        await _initialize_card_decks();

        // Check again after reinitialization
        final newSnapshot = await black_cards_ref.get();
        final newCards = List<dynamic>.from(newSnapshot.value as List? ?? []);
        return newCards.isNotEmpty;
      }

      return cards.isNotEmpty;
    } catch (e) {
      print('Error in check_black_cards_available: $e');
      return false;
    }
  }

  Future<bool> check_white_cards_available_for_players() async {
    try {
      final playersSnapshot = await players_ref.get();
      final whiteCardsSnapshot = await white_cards_ref.get();

      if (!playersSnapshot.exists) {
        print('No players found in check_white_cards_available_for_players');
        return false;
      }

      if (!whiteCardsSnapshot.exists) {
        print('No white cards found, will attempt to initialize deck');
        // Try to initialize the decks if they don't exist
        await _initialize_card_decks();

        // Check again after initialization
        final newWhiteCardsSnapshot = await white_cards_ref.get();
        if (!newWhiteCardsSnapshot.exists) {
          print('Still no white cards after initialization');
          return false;
        }

        // Continue with the newly initialized deck
        final whiteCards = List<dynamic>.from(
          newWhiteCardsSnapshot.value as List? ?? [],
        );

        final playersCount = (playersSnapshot.value as Map?)?.length ?? 0;

        if (playersCount == 0) {
          print('No players found after recheck');
          return false;
        }

        // We need at least 1 card per player at minimum to continue
        return whiteCards.isNotEmpty;
      }

      // Regular check if both players and white cards exist
      final playersCount = (playersSnapshot.value as Map?)?.length ?? 0;
      final whiteCards = List<dynamic>.from(
        whiteCardsSnapshot.value as List? ?? [],
      );

      if (playersCount == 0) {
        print('No players found in check (players_count = 0)');
        return false;
      }

      // Ideally we want 4 cards per player, but in a pinch we can continue with fewer
      // For now, let's just make sure we have some cards
      print(
        'White cards available: ${whiteCards.length}, Players: $playersCount',
      );
      return whiteCards.isNotEmpty;
    } catch (e) {
      print('Error in check_white_cards_available_for_players: $e');
      return false;
    }
  }

  Future<bool> check_winning_condition() async {
    try {
      final winningPointsSnapshot = await winning_points_ref.get();
      final winningPoints = (winningPointsSnapshot.value as int?) ?? 10;

      print('Checking for winning condition (winning points: $winningPoints)');

      final playersSnapshot = await players_ref.get();
      if (!playersSnapshot.exists) {
        print('No players found in check_winning_condition');
        return false;
      }

      final players = playersSnapshot.value as Map?;
      if (players == null || players.isEmpty) {
        print('Players map is null or empty');
        return false;
      }

      // Debug - print all player scores
      print('Current player scores:');
      for (final entry in players.entries) {
        final playerId = entry.key;
        final player = entry.value;
        if (player is Map && player.containsKey('score')) {
          final score = player['score'] as int? ?? 0;
          print('Player $playerId: $score points');
        }
      }

      // Check if any player has reached winning points
      for (final entry in players.entries) {
        final playerId = entry.key.toString();
        final player = entry.value;
        if (player is Map && player.containsKey('score')) {
          final score = player['score'] as int? ?? 0;
          if (score >= winningPoints) {
            print('Player $playerId has reached winning score: $score');

            // Reset any previous winner flags
            for (final p in players.entries) {
              await players_ref.child(p.key.toString()).update({
                'isWinner': false,
              });
            }

            // Mark this player as the winner
            await players_ref.child(playerId).update({'isWinner': true});

            // Also store the winner ID at the room level for easy access
            await room_ref.child('winnerId').set(playerId);

            return true;
          }
        }
      }
      // No winner yet
      return false;
    } catch (e) {
      print('Error in check_winning_condition: $e');
      return false;
    }
  }

  // Game setup
  Future<void> shuffle_white_deck() async {
    final snapshot = await white_cards_ref.get();
    if (snapshot.exists) {
      final cards = List<dynamic>.from(snapshot.value as List? ?? []);
      cards.shuffle();
      await white_cards_ref.set(cards);
    }
  }

  Future<void> draw_cards_for_players() async {
    try {
      final playersSnapshot = await players_ref.get();
      final whiteCardsSnapshot = await white_cards_ref.get();

      if (!playersSnapshot.exists || !whiteCardsSnapshot.exists) {
        // No players or no cards
        print('No players or no white cards available');
        return;
      }

      final players = playersSnapshot.value as Map?;
      List<dynamic> whiteCards = List<dynamic>.from(
        whiteCardsSnapshot.value as List? ?? [],
      );

      if (players == null || players.isEmpty || whiteCards.isEmpty) {
        print('No players, or empty players map, or no white cards');
        return;
      }

      // Calculate how many cards to draw for each player
      final cardsPerPlayer = 4; // Each player gets 4 cards

      // Check if we have enough cards for all players, if not, reinitialize cards
      int totalCardsNeeded = 0;
      final playerNeeds = <String, int>{};

      // First calculate how many cards each player needs
      for (final player_id in players.keys) {
        final playerIdStr = player_id.toString();
        final playerHandRef = player_hands_ref.child(playerIdStr);

        // Get current hand from dedicated location
        final handSnapshot = await playerHandRef.get();
        List<dynamic> currentHand = [];

        if (handSnapshot.exists && handSnapshot.value is List) {
          currentHand = List<dynamic>.from(handSnapshot.value as List);
        } else {
          // Check player object's cards field as fallback
          final playerCardsSnapshot =
              await players_ref.child(playerIdStr).child('cards').get();

          if (playerCardsSnapshot.exists &&
              playerCardsSnapshot.value is List) {
            currentHand = List<dynamic>.from(
              playerCardsSnapshot.value as List,
            );
            // Sync cards to the dedicated location
            await playerHandRef.set(currentHand);
          }
        }

        final cardsNeeded = cardsPerPlayer - currentHand.length;
        if (cardsNeeded > 0) {
          playerNeeds[playerIdStr] = cardsNeeded;
          totalCardsNeeded += cardsNeeded;
        }
      }

      // If we need more cards than are available, reinitialize the deck
      if (totalCardsNeeded > 0 && totalCardsNeeded > whiteCards.length) {
        print(
          'Not enough white cards (need $totalCardsNeeded, have ${whiteCards.length}). Reinitializing deck.',
        );
        await _initialize_card_decks();

        // Get the updated deck
        final newWhiteCardsSnapshot = await white_cards_ref.get();
        if (newWhiteCardsSnapshot.exists) {
          whiteCards = List<dynamic>.from(
            newWhiteCardsSnapshot.value as List? ?? [],
          );
          // Shuffle the newly initialized deck
          whiteCards.shuffle();
          await white_cards_ref.set(whiteCards);
        }
      }

      // Now distribute cards to players who need them
      for (final entry in playerNeeds.entries) {
        final playerIdStr = entry.key;
        final cardsNeeded = entry.value;

        if (cardsNeeded <= 0 || whiteCards.isEmpty) {
          continue; // Skip if player doesn't need cards or no cards left
        }

        final playerHandRef = player_hands_ref.child(playerIdStr);

        // Get current hand again (it might have changed)
        final handSnapshot = await playerHandRef.get();
        List<dynamic> currentHand = [];

        if (handSnapshot.exists && handSnapshot.value is List) {
          currentHand = List<dynamic>.from(handSnapshot.value as List);
        }

        // Draw cards for this player (up to cards_needed or what's available)
        final cardsToDraw =
            whiteCards.length < cardsNeeded
                ? whiteCards.length
                : cardsNeeded;

        if (cardsToDraw > 0) {
          final drawnCards = whiteCards.sublist(0, cardsToDraw);
          whiteCards = whiteCards.sublist(cardsToDraw);

          // Add drawn cards to player's hand
          currentHand.addAll(drawnCards);
          await playerHandRef.set(currentHand);

          // Also update the player's cards field directly in the player object for faster access
          await players_ref
              .child(playerIdStr)
              .child('cards')
              .set(currentHand);

          print('Drew $cardsToDraw cards for player $playerIdStr');
        }
      }

      // Update white cards deck
      await white_cards_ref.set(whiteCards);
      print('Updated white card deck, ${whiteCards.length} cards remaining');
    } catch (e) {
      print('Error drawing cards for players: $e');
    }
  }

  // Card Czar operations
  Future<void> select_card_czar() async {
    final playersSnapshot = await players_ref.get();

    if (playersSnapshot.exists) {
      final players = playersSnapshot.value as Map?;

      if (players != null && players.isNotEmpty) {
        // Get a random player ID for the Card Czar
        final playerIds = players.keys.toList();
        playerIds.shuffle();
        final cardCzarId = playerIds.first;

        // Update all players to set the Card Czar
        for (final player_id in playerIds) {
          final isCardCzar = player_id == cardCzarId;
          await players_ref.child(player_id.toString()).update({
            'isCardCzar': isCardCzar,
          });
        }
      }
    }
  }

  Future<void> draw_black_card() async {
    final blackCardsSnapshot = await black_cards_ref.get();

    if (blackCardsSnapshot.exists) {
      final blackCards = List<dynamic>.from(
        blackCardsSnapshot.value as List? ?? [],
      );

      if (blackCards.isNotEmpty) {
        // Draw a random black card (or take the first one)
        final card = blackCards.removeAt(0);

        // Set as current black card
        await current_black_card_ref.set(card);

        // Update black cards deck
        await black_cards_ref.set(blackCards);
      }
    }
  } // Player submissions

  Future<void> submit_white_cards(List<dynamic> cardIds) async {
    print('🎲 Player $player_id submitting cards to the game');

    // Submit the selected cards
    await submissions_ref.child(player_id).set(cardIds);
    print('Cards added to submissions database');

    // Mark the player as having submitted cards
    await players_ref.child(player_id).update({'hasSubmitted': true});
    print('Player marked as having submitted cards');

    // Remove submitted cards from player's hand
    final handSnapshot = await player_hand_ref.get();
    if (handSnapshot.exists) {
      final hand = List<dynamic>.from(handSnapshot.value as List? ?? []);

      // Remove submitted cards
      hand.removeWhere(
        (card) => cardIds.any(
          (id) => card is Map && id is Map && card['id'] == id['id'],
        ),
      );

      // Update player's hand
      await player_hand_ref.set(hand);
      print('Updated player hand - removed submitted cards');

      // Also update the player's cards field directly in the player object for faster access
      await players_ref.child(player_id).child('cards').set(hand);
    }

    // Get the card czar ID for comparison
    String? cardCzarId;
    final playersSnapshot = await players_ref.get();
    if (playersSnapshot.exists) {
      final players = playersSnapshot.value as Map?;
      if (players != null) {
        for (final entry in players.entries) {
          if (entry.value is Map && entry.value['isCardCzar'] == true) {
            cardCzarId = entry.key.toString();
            break;
          }
        }
      }
    }
    print('Current Card Czar: $cardCzarId');

    // Check if this was the last submission needed
    print('Checking if all players have submitted cards...');
    final allPlayersSubmitted = await check_all_players_submitted();
    if (allPlayersSubmitted) {
      print(
        '🏆 ALL PLAYERS HAVE SUBMITTED! This was the last submission needed.',
      );

      // Get current game state to see if it needs to be updated
      final gameStateSnapshot = await game_state_ref.get();
      final currentGameState = gameStateSnapshot.value as String?;

      // If we're still in players_selecting_cards or waiting_for_submissions, update the state
      if (currentGameState == 'players_selecting_cards' ||
          currentGameState == 'waiting_for_submissions') {
        print(
          'Game is still in $currentGameState state - updating to czar_selecting_winner',
        );
        await update_game_state('czar_selecting_winner');
        print('Game state updated to czar_selecting_winner');
      } else {
        print(
          'Game is already in $currentGameState state - no update needed',
        );
      }
    } else {
      print(
        'Not all players have submitted yet - waiting for more submissions',
      );

      // Log current submissions count
      final submissionsSnapshot = await submissions_ref.get();
      if (submissionsSnapshot.exists) {
        final submissions = submissionsSnapshot.value as Map?;
        if (submissions != null) {
          print('Current submission count: ${submissions.length}');
        }
      }
    }
  }

  Future<bool> check_all_players_submitted() async {
    print(
      '🔍 In check_all_players_submitted - checking if all players have submitted cards',
    );
    final playersSnapshot = await players_ref.get();
    final submissionsSnapshot = await submissions_ref.get();

    if (playersSnapshot.exists) {
      final players = playersSnapshot.value as Map?;
      final submissions =
          submissionsSnapshot.exists
              ? (submissionsSnapshot.value as Map?)
              : null;

      if (players != null) {
        // Count non-Czar players and check if they've all submitted
        int nonCzarCount = 0;
        int submittedCount = 0;

        print('Players in the game:');
        for (final entry in players.entries) {
          final playerId = entry.key.toString();
          final playerData = entry.value;
          if (playerData is Map) {
            final isCardCzar = playerData['isCardCzar'] == true;
            final hasSubmitted = playerData['hasSubmitted'] == true;
            final hasSubmissionInDb =
                submissions != null && submissions.containsKey(playerId);

            print(
              'Player $playerId: Card Czar: $isCardCzar, Has submitted flag: $hasSubmitted, Has submission in DB: $hasSubmissionInDb',
            );

            // Skip the Card Czar
            if (isCardCzar) {
              print('Player $playerId is Card Czar, skipping from count');
              continue;
            }

            nonCzarCount++;

            // Check both the player's hasSubmitted flag and if they have cards in the submissions
            bool playerHasSubmitted = hasSubmitted;
            bool playerHasSubmissionCards = hasSubmissionInDb;

            if (playerHasSubmitted || playerHasSubmissionCards) {
              submittedCount++;
              print(
                'Player $playerId has submitted their cards (flag: $playerHasSubmitted, DB: $playerHasSubmissionCards)',
              );

              // If a player has submitted cards but doesn't have the flag set, update it
              if (!playerHasSubmitted && playerHasSubmissionCards) {
                print('Updating hasSubmitted flag for player $playerId');
                players_ref.child(playerId).update({'hasSubmitted': true});
              }
            } else {
              print('Player $playerId has NOT submitted their cards yet');
            }
          }
        }

        // Check if all non-Czar players have submitted
        print(
          'Submitted count: $submittedCount / $nonCzarCount non-czar players',
        );

        if (submittedCount >= nonCzarCount && nonCzarCount > 0) {
          print('✅ ALL PLAYERS HAVE SUBMITTED THEIR CARDS - returning true');
          return true;
        } else {
          print('❌ Still waiting for some players to submit - returning false');
          return false;
        }
      } else {
        print('No players found in the game data');
      }
    } else {
      print('Players snapshot does not exist');
    }
    print('Defaulting to false - not all players have submitted');
    return false;
  }

  // Winner selection
  Future<void> select_winner(String winnerId) async {
    // Get current submissions BEFORE they are cleared to store them for reveal
    final currentSubmissionsSnapshot = await submissions_ref.get();
    final currentSubmissions = currentSubmissionsSnapshot.value;

    // Update the winner's score
    final winnerRef = players_ref.child(winnerId);
    final winnerSnapshot = await winnerRef.get();

    if (winnerSnapshot.exists) {
      final winner = winnerSnapshot.value as Map?;
      if (winner != null) {
        final currentScore = winner['score'] as int? ?? 0;
        await winnerRef.update({'score': currentScore + 1});
      }
    }

    // Set winning submission (points to the winner's cards within the main submissions)
    await room_ref.child('winningSubmission').set({
      'playerId': winnerId,
      'cards': await submissions_ref
          .child(winnerId)
          .get()
          .then((s) => s.value),
    });

    // Store all submissions for this round in a separate node for all players to see
    if (currentSubmissions != null) {
      print('[GameService] Storing current submissions to roundSubmissionsForReveal: $currentSubmissions');
      await round_submissions_for_reveal_ref.set(currentSubmissions);
    } else {
      print('[GameService] No current submissions to store for reveal.');
      // Ensure the node is empty if there were no submissions
      await round_submissions_for_reveal_ref.set(null);
    }

    // Reset the hasSubmitted flags for all players
    final playersSnapshot = await players_ref.get();
    if (playersSnapshot.exists) {
      final players = playersSnapshot.value as Map?;
      if (players != null) {
        for (final player_id in players.keys) {
          await players_ref.child(player_id.toString()).update({
            'hasSubmitted': false,
          });
        }
      }
    }

    // Clear submissions for next round
    await submissions_ref.remove();
  }

  // Game state management
  Future<void> update_game_state(String state) async {
    await game_state_ref.set(state);
  }

  Stream<DatabaseEvent> listen_to_game_state() {
    return game_state_ref.onValue;
  }

  Stream<DatabaseEvent> listen_to_players() {
    return players_ref.onValue;
  }

  Stream<DatabaseEvent> listen_to_submissions() {
    return submissions_ref.onValue;
  }

  Stream<DatabaseEvent> listen_to_current_black_card() {
    return current_black_card_ref.onValue;
  }

  Stream<DatabaseEvent> listen_to_player_hand() {
    // First check if the player has cards in their player object
    return player_hand_ref.onValue;
  }

  // New Listener for round submissions to be revealed
  Stream<DatabaseEvent> listen_to_round_submissions_for_reveal() {
    return round_submissions_for_reveal_ref.onValue;
  }

  Stream<DatabaseEvent> listen_to_room() {
    return room_ref.onValue;
  }

  Future<void> initialize_game() async {
    try {
      // Set initial game state (temporary, will update after initialization)
      await update_game_state('initializing');

      // Clear round submissions for reveal from previous round
      print('[GameService] Clearing roundSubmissionsForReveal during game initialization.');
      await round_submissions_for_reveal_ref.remove();

      // Check if we need to initialize the card decks
      final blackCardsSnapshot = await black_cards_ref.get();
      final whiteCardsSnapshot = await white_cards_ref.get();

      if (!blackCardsSnapshot.exists || !whiteCardsSnapshot.exists) {
        // If card decks don't exist yet, we need to load them from Firestore
        await _initialize_card_decks();
      }

      // Clear any existing submissions
      await submissions_ref.remove();

      // Clear any previous winning submissions
      await room_ref.child('winningSubmission').remove();
      await room_ref.child('winnerId').remove();

      // Ensure the white cards are shuffled to have randomized draws
      await shuffle_white_deck();

      // Reset all players' submission status and winner status
      final playersSnapshot = await players_ref.get();
      if (playersSnapshot.exists) {
        final players = playersSnapshot.value as Map?;
        if (players != null) {
          for (final player_id in players.keys) {
            await players_ref.child(player_id.toString()).update({
              'hasSubmitted': false,
              'isWinner': false,
            });
          }
        }
      }

      // Make sure all players have cards before starting the game
      await draw_cards_for_players();

      // Now that initialization is complete, update the game state to begin checks
      await update_game_state('checking_game_conditions');
    } catch (error) {
      print('Error initializing game: $error');
      // Handle initialization error - keep game in a safe state
      await update_game_state('initialization_error');
    }
  }

  Future<void> _initialize_card_decks() async {
    try {
      // Get card topic from the room
      final topicSnapshot = await room_ref.child('selectedCardTopic').get();
      final topicId = topicSnapshot.value as String? ?? 'base_set_en';

      // Get player count to ensure we have enough cards
      final playersSnapshot = await players_ref.get();
      int playerCount = 0;
      if (playersSnapshot.exists) {
        final players = playersSnapshot.value as Map?;
        playerCount = players?.length ?? 0;
      }

      // We need at least 4 cards per player + some extra for gameplay
      int minWhiteCardsNeeded = max(
        15,
        playerCount * 8,
      ); // 4 initial cards + 4 extra per player

      print(
        'Initializing card decks for topic: $topicId, need at least $minWhiteCardsNeeded white cards',
      );

      // In a real implementation, you would use the topic_id to fetch specific card sets
      // For now, we're using a generous sample set to ensure enough cards
      final blackCards = [
        {'text': 'Why am I sticky?', 'type': 'black', 'pick': 1},
        {'text': 'What\'s my secret power?', 'type': 'black', 'pick': 1},
        {
          'text': 'What never fails to liven up the party?',
          'type': 'black',
          'pick': 1,
        },
        {
          'text': 'I got 99 problems but _____ ain\'t one.',
          'type': 'black',
          'pick': 1,
        },
        {
          'text':
              'It\'s a pity that kids these days are all getting involved with _____.',
          'type': 'black',
          'pick': 1,
        },
        {
          'text': 'What is Batman\'s guilty pleasure?',
          'type': 'black',
          'pick': 1,
        },
        {
          'text': 'TSA guidelines now prohibit _____ on airplanes.',
          'type': 'black',
          'pick': 1,
        },
        {
          'text': 'What ended my last relationship?',
          'type': 'black',
          'pick': 1,
        },
        {
          'text':
              'MTV\'s new reality show features eight washed-up celebrities living with _____.',
          'type': 'black',
          'pick': 1,
        },
        {'text': 'I drink to forget _____.', 'type': 'black', 'pick': 1},
      ];

      // Generate plenty of white cards to ensure we don't run out
      List<Map<String, dynamic>> whiteCards = [
        {'text': 'An unholy amount of glitter.', 'type': 'white', 'id': 'w1'},
        {'text': 'Crying into a bowl of cereal.', 'type': 'white', 'id': 'w2'},
        {'text': 'A 50-foot-tall robot.', 'type': 'white', 'id': 'w3'},
        {
          'text': 'The crushing weight of existential dread.',
          'type': 'white',
          'id': 'w4',
        },
        {
          'text': 'An alarming amount of mayonnaise.',
          'type': 'white',
          'id': 'w5',
        },
        {'text': 'Avocado toast.', 'type': 'white', 'id': 'w6'},
        {'text': 'Doing the right thing.', 'type': 'white', 'id': 'w7'},
        {
          'text':
              'The tiny calloused hands of the Chinese children that made this card.',
          'type': 'white',
          'id': 'w8',
        },
        {'text': 'A disappointing salad.', 'type': 'white', 'id': 'w9'},
        {'text': 'Silence.', 'type': 'white', 'id': 'w10'},
        {'text': 'A lifetime of sadness.', 'type': 'white', 'id': 'w11'},
        {'text': 'Tasteful sideboob.', 'type': 'white', 'id': 'w12'},
        {'text': 'A sassy black woman.', 'type': 'white', 'id': 'w13'},
        {'text': 'Catapults.', 'type': 'white', 'id': 'w14'},
        {'text': 'Homeless people.', 'type': 'white', 'id': 'w15'},
        {
          'text': 'A micropig wearing a tiny raincoat and booties.',
          'type': 'white',
          'id': 'w16',
        },
        {
          'text': 'Sudden Poop Explosion Disease.',
          'type': 'white',
          'id': 'w17',
        },
        {'text': 'A moment of silence.', 'type': 'white', 'id': 'w18'},
        {'text': 'A really cool hat.', 'type': 'white', 'id': 'w19'},
        {
          'text': 'The inescapable death march of time.',
          'type': 'white',
          'id': 'w20',
        },
        {'text': 'Puppies!', 'type': 'white', 'id': 'w21'},
        {'text': 'Hormone injections.', 'type': 'white', 'id': 'w22'},
        {'text': 'Emotions.', 'type': 'white', 'id': 'w23'},
        {'text': 'The miracle of childbirth.', 'type': 'white', 'id': 'w24'},
        {'text': 'Explosive decompression.', 'type': 'white', 'id': 'w25'},
      ];

      // Add more generated white cards if needed to meet minimum
      if (whiteCards.length < minWhiteCardsNeeded) {
        int additionalCardsNeeded =
            minWhiteCardsNeeded - whiteCards.length;
        for (int i = 0; i < additionalCardsNeeded; i++) {
          final cardNum = whiteCards.length + 1;
          whiteCards.add({
            'text': 'Additional white card #$cardNum',
            'type': 'white',
            'id': 'w$cardNum',
          });
        }
      }

      // Save decks to Firebase
      await black_cards_ref.set(blackCards);
      await white_cards_ref.set(whiteCards);

      print(
        'Successfully initialized card decks: ${blackCards.length} black cards, ${whiteCards.length} white cards',
      );
    } catch (e) {
      print('Error initializing card decks: $e');
    }
  }

  // Helper function to get Card Czar ID
  Future<String?> get_card_czar_id() async {
    final playersSnapshot = await players_ref.get();

    if (playersSnapshot.exists) {
      final players = playersSnapshot.value as Map?;

      if (players != null) {
        for (final entry in players.entries) {
          final playerId = entry.key;
          final playerData = entry.value;

          if (playerData is Map && playerData['isCardCzar'] == true) {
            return playerId.toString();
          }
        }
      }
    }

    return null;
  }

  // Check if current player is Card Czar
  Future<bool> is_current_player_card_czar() async {
    final cardCzarId = await get_card_czar_id();
    return player_id == cardCzarId;
  }

  // Check if current player is host
  Future<bool> is_current_player_host() async {
    final playerSnapshot = await player_ref.get();

    if (playerSnapshot.exists) {
      final playerData = playerSnapshot.value as Map?;
      return playerData?['isHost'] == true;
    }

    return false;
  }
}
