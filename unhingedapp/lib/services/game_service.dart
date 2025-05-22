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
    final players_snapshot = await players_ref.get();
    if (!players_snapshot.exists) return false;

    final players = players_snapshot.value as Map?;
    if (players == null || players.isEmpty) return false;

    // Check if any player has no cards
    for (final player_id in players.keys) {
      // First check the dedicated player hands location
      final player_hand_snapshot =
          await player_hands_ref.child(player_id.toString()).get();

      if (!player_hand_snapshot.exists ||
          (player_hand_snapshot.value is List &&
              (player_hand_snapshot.value as List).isEmpty)) {
        // If no cards in dedicated location, check the player object's cards field
        final player_cards_snapshot =
            await players_ref.child(player_id.toString()).child('cards').get();

        if (!player_cards_snapshot.exists ||
            (player_cards_snapshot.value is List &&
                (player_cards_snapshot.value as List).isEmpty)) {
          // Player has no cards in either location
          return false;
        }

        // If cards were found in player object but not in dedicated location, sync them
        if (player_cards_snapshot.exists &&
            player_cards_snapshot.value is List) {
          await player_hands_ref
              .child(player_id.toString())
              .set(player_cards_snapshot.value);
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
        final new_snapshot = await black_cards_ref.get();
        if (!new_snapshot.exists) {
          print('Failed to initialize black cards');
          return false;
        }

        final cards = List<dynamic>.from(new_snapshot.value as List? ?? []);
        return cards.isNotEmpty;
      }

      final cards = List<dynamic>.from(snapshot.value as List? ?? []);

      if (cards.isEmpty) {
        print('Black cards list is empty, reinitializing decks');
        await _initialize_card_decks();

        // Check again after reinitialization
        final new_snapshot = await black_cards_ref.get();
        final new_cards = List<dynamic>.from(new_snapshot.value as List? ?? []);
        return new_cards.isNotEmpty;
      }

      return cards.isNotEmpty;
    } catch (e) {
      print('Error in check_black_cards_available: $e');
      return false;
    }
  }

  Future<bool> check_white_cards_available_for_players() async {
    try {
      final players_snapshot = await players_ref.get();
      final white_cards_snapshot = await white_cards_ref.get();

      if (!players_snapshot.exists) {
        print('No players found in check_white_cards_available_for_players');
        return false;
      }

      if (!white_cards_snapshot.exists) {
        print('No white cards found, will attempt to initialize deck');
        // Try to initialize the decks if they don't exist
        await _initialize_card_decks();

        // Check again after initialization
        final new_white_cards_snapshot = await white_cards_ref.get();
        if (!new_white_cards_snapshot.exists) {
          print('Still no white cards after initialization');
          return false;
        }

        // Continue with the newly initialized deck
        final white_cards = List<dynamic>.from(
          new_white_cards_snapshot.value as List? ?? [],
        );

        final players_count = (players_snapshot.value as Map?)?.length ?? 0;

        if (players_count == 0) {
          print('No players found after recheck');
          return false;
        }

        // We need at least 1 card per player at minimum to continue
        return white_cards.isNotEmpty;
      }

      // Regular check if both players and white cards exist
      final players_count = (players_snapshot.value as Map?)?.length ?? 0;
      final white_cards = List<dynamic>.from(
        white_cards_snapshot.value as List? ?? [],
      );

      if (players_count == 0) {
        print('No players found in check (players_count = 0)');
        return false;
      }

      // Ideally we want 4 cards per player, but in a pinch we can continue with fewer
      // For now, let's just make sure we have some cards
      print(
        'White cards available: ${white_cards.length}, Players: $players_count',
      );
      return white_cards.isNotEmpty;
    } catch (e) {
      print('Error in check_white_cards_available_for_players: $e');
      return false;
    }
  }

  Future<bool> check_winning_condition() async {
    try {
      final winning_points_snapshot = await winning_points_ref.get();
      final winning_points = (winning_points_snapshot.value as int?) ?? 10;

      print('Checking for winning condition (winning points: $winning_points)');

      final players_snapshot = await players_ref.get();
      if (!players_snapshot.exists) {
        print('No players found in check_winning_condition');
        return false;
      }

      final players = players_snapshot.value as Map?;
      if (players == null || players.isEmpty) {
        print('Players map is null or empty');
        return false;
      }

      // Debug - print all player scores
      print('Current player scores:');
      for (final entry in players.entries) {
        final player_id = entry.key;
        final player = entry.value;
        if (player is Map && player.containsKey('score')) {
          final score = player['score'] as int? ?? 0;
          print('Player $player_id: $score points');
        }
      }

      // Check if any player has reached winning points
      for (final player in players.values) {
        if (player is Map && player.containsKey('score')) {
          final score = player['score'] as int? ?? 0;
          if (score >= winning_points) {
            print('Player has reached winning score: $score');
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
      final players_snapshot = await players_ref.get();
      final white_cards_snapshot = await white_cards_ref.get();

      if (!players_snapshot.exists || !white_cards_snapshot.exists) {
        // No players or no cards
        print('No players or no white cards available');
        return;
      }

      final players = players_snapshot.value as Map?;
      List<dynamic> white_cards = List<dynamic>.from(
        white_cards_snapshot.value as List? ?? [],
      );

      if (players == null || players.isEmpty || white_cards.isEmpty) {
        print('No players, or empty players map, or no white cards');
        return;
      }

      // Calculate how many cards to draw for each player
      final cards_per_player = 4; // Each player gets 4 cards

      // Check if we have enough cards for all players, if not, reinitialize cards
      int total_cards_needed = 0;
      final player_needs = <String, int>{};

      // First calculate how many cards each player needs
      for (final player_id in players.keys) {
        final player_id_str = player_id.toString();
        final player_hand_ref = player_hands_ref.child(player_id_str);

        // Get current hand from dedicated location
        final hand_snapshot = await player_hand_ref.get();
        List<dynamic> current_hand = [];

        if (hand_snapshot.exists && hand_snapshot.value is List) {
          current_hand = List<dynamic>.from(hand_snapshot.value as List);
        } else {
          // Check player object's cards field as fallback
          final player_cards_snapshot =
              await players_ref.child(player_id_str).child('cards').get();

          if (player_cards_snapshot.exists &&
              player_cards_snapshot.value is List) {
            current_hand = List<dynamic>.from(
              player_cards_snapshot.value as List,
            );
            // Sync cards to the dedicated location
            await player_hand_ref.set(current_hand);
          }
        }

        final cards_needed = cards_per_player - current_hand.length;
        if (cards_needed > 0) {
          player_needs[player_id_str] = cards_needed;
          total_cards_needed += cards_needed;
        }
      }

      // If we need more cards than are available, reinitialize the deck
      if (total_cards_needed > 0 && total_cards_needed > white_cards.length) {
        print(
          'Not enough white cards (need $total_cards_needed, have ${white_cards.length}). Reinitializing deck.',
        );
        await _initialize_card_decks();

        // Get the updated deck
        final new_white_cards_snapshot = await white_cards_ref.get();
        if (new_white_cards_snapshot.exists) {
          white_cards = List<dynamic>.from(
            new_white_cards_snapshot.value as List? ?? [],
          );
          // Shuffle the newly initialized deck
          white_cards.shuffle();
          await white_cards_ref.set(white_cards);
        }
      }

      // Now distribute cards to players who need them
      for (final entry in player_needs.entries) {
        final player_id_str = entry.key;
        final cards_needed = entry.value;

        if (cards_needed <= 0 || white_cards.isEmpty) {
          continue; // Skip if player doesn't need cards or no cards left
        }

        final player_hand_ref = player_hands_ref.child(player_id_str);

        // Get current hand again (it might have changed)
        final hand_snapshot = await player_hand_ref.get();
        List<dynamic> current_hand = [];

        if (hand_snapshot.exists && hand_snapshot.value is List) {
          current_hand = List<dynamic>.from(hand_snapshot.value as List);
        }

        // Draw cards for this player (up to cards_needed or what's available)
        final cards_to_draw =
            white_cards.length < cards_needed
                ? white_cards.length
                : cards_needed;

        if (cards_to_draw > 0) {
          final drawn_cards = white_cards.sublist(0, cards_to_draw);
          white_cards = white_cards.sublist(cards_to_draw);

          // Add drawn cards to player's hand
          current_hand.addAll(drawn_cards);
          await player_hand_ref.set(current_hand);

          // Also update the player's cards field directly in the player object for faster access
          await players_ref
              .child(player_id_str)
              .child('cards')
              .set(current_hand);

          print('Drew $cards_to_draw cards for player $player_id_str');
        }
      }

      // Update white cards deck
      await white_cards_ref.set(white_cards);
      print('Updated white card deck, ${white_cards.length} cards remaining');
    } catch (e) {
      print('Error drawing cards for players: $e');
    }
  }

  // Card Czar operations
  Future<void> select_card_czar() async {
    final players_snapshot = await players_ref.get();

    if (players_snapshot.exists) {
      final players = players_snapshot.value as Map?;

      if (players != null && players.isNotEmpty) {
        // Get a random player ID for the Card Czar
        final player_ids = players.keys.toList();
        player_ids.shuffle();
        final card_czar_id = player_ids.first;

        // Update all players to set the Card Czar
        for (final player_id in player_ids) {
          final is_card_czar = player_id == card_czar_id;
          await players_ref.child(player_id.toString()).update({
            'isCardCzar': is_card_czar,
          });
        }
      }
    }
  }

  Future<void> draw_black_card() async {
    final black_cards_snapshot = await black_cards_ref.get();

    if (black_cards_snapshot.exists) {
      final black_cards = List<dynamic>.from(
        black_cards_snapshot.value as List? ?? [],
      );

      if (black_cards.isNotEmpty) {
        // Draw a random black card (or take the first one)
        final card = black_cards.removeAt(0);

        // Set as current black card
        await current_black_card_ref.set(card);

        // Update black cards deck
        await black_cards_ref.set(black_cards);
      }
    }
  }  // Player submissions
  Future<void> submit_white_cards(List<dynamic> card_ids) async {
    print('🎲 Player $player_id submitting cards to the game');
    
    // Submit the selected cards
    await submissions_ref.child(player_id).set(card_ids);
    print('Cards added to submissions database');
    
    // Mark the player as having submitted cards
    await players_ref.child(player_id).update({'hasSubmitted': true});
    print('Player marked as having submitted cards');

    // Remove submitted cards from player's hand
    final hand_snapshot = await player_hand_ref.get();
    if (hand_snapshot.exists) {
      final hand = List<dynamic>.from(hand_snapshot.value as List? ?? []);

      // Remove submitted cards
      hand.removeWhere(
        (card) => card_ids.any(
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
    final players_snapshot = await players_ref.get();
    if (players_snapshot.exists) {
      final players = players_snapshot.value as Map?;
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
    final all_players_submitted = await check_all_players_submitted();
    if (all_players_submitted) {
      print('🏆 ALL PLAYERS HAVE SUBMITTED! This was the last submission needed.');
      
      // Get current game state to see if it needs to be updated
      final game_state_snapshot = await game_state_ref.get();
      final current_game_state = game_state_snapshot.value as String?;
      
      // If we're still in players_selecting_cards or waiting_for_submissions, update the state
      if (current_game_state == 'players_selecting_cards' || current_game_state == 'waiting_for_submissions') {
        print('Game is still in $current_game_state state - updating to czar_selecting_winner');
        await update_game_state('czar_selecting_winner');
        print('Game state updated to czar_selecting_winner');
      } else {
        print('Game is already in $current_game_state state - no update needed');
      }
    } else {
      print('Not all players have submitted yet - waiting for more submissions');
      
      // Log current submissions count
      final submissions_snapshot = await submissions_ref.get();
      if (submissions_snapshot.exists) {
        final submissions = submissions_snapshot.value as Map?;
        if (submissions != null) {
          print('Current submission count: ${submissions.length}');
        }
      }
    }
  }Future<bool> check_all_players_submitted() async {
    print('🔍 In check_all_players_submitted - checking if all players have submitted cards');
    final players_snapshot = await players_ref.get();
    final submissions_snapshot = await submissions_ref.get();

    if (players_snapshot.exists) {
      final players = players_snapshot.value as Map?;
      final submissions = submissions_snapshot.exists ? 
          (submissions_snapshot.value as Map?) : null;

      if (players != null) {
        // Count non-Czar players and check if they've all submitted
        int non_czar_count = 0;
        int submitted_count = 0;
        
        print('Players in the game:');
        for (final entry in players.entries) {
          final player_id = entry.key.toString();
          final player_data = entry.value;
          if (player_data is Map) {
            final isCardCzar = player_data['isCardCzar'] == true;
            final hasSubmitted = player_data['hasSubmitted'] == true;
            final hasSubmissionInDb = submissions != null && submissions.containsKey(player_id);
            
            print('Player $player_id: Card Czar: $isCardCzar, Has submitted flag: $hasSubmitted, Has submission in DB: $hasSubmissionInDb');
            
            // Skip the Card Czar
            if (isCardCzar) {
              print('Player $player_id is Card Czar, skipping from count');
              continue;
            }
            
            non_czar_count++;
            
            // Check both the player's hasSubmitted flag and if they have cards in the submissions
            bool playerHasSubmitted = hasSubmitted;
            bool playerHasSubmissionCards = hasSubmissionInDb;
                
            if (playerHasSubmitted || playerHasSubmissionCards) {
              submitted_count++;
              print('Player $player_id has submitted their cards (flag: $playerHasSubmitted, DB: $playerHasSubmissionCards)');
              
              // If a player has submitted cards but doesn't have the flag set, update it
              if (!playerHasSubmitted && playerHasSubmissionCards) {
                print('Updating hasSubmitted flag for player $player_id');
                players_ref.child(player_id).update({'hasSubmitted': true});
              }
            } else {
              print('Player $player_id has NOT submitted their cards yet');
            }
          }
        }

        // Check if all non-Czar players have submitted
        print('Submitted count: $submitted_count / $non_czar_count non-czar players');
        
        if (submitted_count >= non_czar_count && non_czar_count > 0) {
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
  Future<void> select_winner(String winner_id) async {
    // Update the winner's score
    final winner_ref = players_ref.child(winner_id);
    final winner_snapshot = await winner_ref.get();

    if (winner_snapshot.exists) {
      final winner = winner_snapshot.value as Map?;
      if (winner != null) {
        final current_score = winner['score'] as int? ?? 0;
        await winner_ref.update({'score': current_score + 1});
      }
    }

    // Set winning submission
    await room_ref.child('winningSubmission').set({
      'playerId': winner_id,
      'cards': await submissions_ref
          .child(winner_id)
          .get()
          .then((s) => s.value),
    });

    // Reset the hasSubmitted flags for all players
    final players_snapshot = await players_ref.get();
    if (players_snapshot.exists) {
      final players = players_snapshot.value as Map?;
      if (players != null) {
        for (final player_id in players.keys) {
          await players_ref.child(player_id.toString()).update({'hasSubmitted': false});
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

  Stream<DatabaseEvent> listen_to_room() {
    return room_ref.onValue;
  }  Future<void> initialize_game() async {
    try {
      // Set initial game state (temporary, will update after initialization)
      await update_game_state('initializing');

      // Check if we need to initialize the card decks
      final black_cards_snapshot = await black_cards_ref.get();
      final white_cards_snapshot = await white_cards_ref.get();

      if (!black_cards_snapshot.exists || !white_cards_snapshot.exists) {
        // If card decks don't exist yet, we need to load them from Firestore
        await _initialize_card_decks();
      }

      // Clear any existing submissions
      await submissions_ref.remove();

      // Ensure the white cards are shuffled to have randomized draws
      await shuffle_white_deck();

      // Reset all players' submission status
      final players_snapshot = await players_ref.get();
      if (players_snapshot.exists) {
        final players = players_snapshot.value as Map?;
        if (players != null) {
          for (final player_id in players.keys) {
            await players_ref.child(player_id.toString()).update({'hasSubmitted': false});
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
      final topic_snapshot = await room_ref.child('selectedCardTopic').get();
      final topic_id = topic_snapshot.value as String? ?? 'base_set_en';

      // Get player count to ensure we have enough cards
      final players_snapshot = await players_ref.get();
      int player_count = 0;
      if (players_snapshot.exists) {
        final players = players_snapshot.value as Map?;
        player_count = players?.length ?? 0;
      }

      // We need at least 4 cards per player + some extra for gameplay
      int min_white_cards_needed = max(
        15,
        player_count * 8,
      ); // 4 initial cards + 4 extra per player

      print(
        'Initializing card decks for topic: $topic_id, need at least $min_white_cards_needed white cards',
      );

      // In a real implementation, you would use the topic_id to fetch specific card sets
      // For now, we're using a generous sample set to ensure enough cards
      final black_cards = [
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
      List<Map<String, dynamic>> white_cards = [
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
      if (white_cards.length < min_white_cards_needed) {
        int additional_cards_needed =
            min_white_cards_needed - white_cards.length;
        for (int i = 0; i < additional_cards_needed; i++) {
          final card_num = white_cards.length + 1;
          white_cards.add({
            'text': 'Additional white card #$card_num',
            'type': 'white',
            'id': 'w${card_num}',
          });
        }
      }

      // Save decks to Firebase
      await black_cards_ref.set(black_cards);
      await white_cards_ref.set(white_cards);

      print(
        'Successfully initialized card decks: ${black_cards.length} black cards, ${white_cards.length} white cards',
      );
    } catch (e) {
      print('Error initializing card decks: $e');
    }
  }

  // Helper function to get Card Czar ID
  Future<String?> get_card_czar_id() async {
    final players_snapshot = await players_ref.get();

    if (players_snapshot.exists) {
      final players = players_snapshot.value as Map?;

      if (players != null) {
        for (final entry in players.entries) {
          final player_id = entry.key;
          final player_data = entry.value;

          if (player_data is Map && player_data['isCardCzar'] == true) {
            return player_id.toString();
          }
        }
      }
    }

    return null;
  }

  // Check if current player is Card Czar
  Future<bool> is_current_player_card_czar() async {
    final card_czar_id = await get_card_czar_id();
    return player_id == card_czar_id;
  }

  // Check if current player is host
  Future<bool> is_current_player_host() async {
    final player_snapshot = await player_ref.get();

    if (player_snapshot.exists) {
      final player_data = player_snapshot.value as Map?;
      return player_data?['isHost'] == true;
    }

    return false;
  }
}
