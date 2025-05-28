import 'package:flutter/material.dart';
import 'dart:async';

import '../components/black_card_display.dart';
import '../components/game_card.dart';

class AllCardsReveal extends StatefulWidget {
  final Map<dynamic, dynamic>? black_card;
  final Map<String, List<Map<String, dynamic>>> submissions;
  final Map<dynamic, dynamic> players;
  final Map<dynamic, dynamic> winning_submission;
  final Function()? on_reveal_complete;

  const AllCardsReveal({
    super.key,
    required this.black_card,
    required this.submissions,
    required this.players,
    required this.winning_submission,
    this.on_reveal_complete,
  });

  @override
  State<AllCardsReveal> createState() => _AllCardsRevealState();
}

class _AllCardsRevealState extends State<AllCardsReveal>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late List<AnimationController> _cardControllers;
  late Timer _displayTimer;
    List<MapEntry<String, List<Map<String, dynamic>>>> _orderedSubmissions = [];
  int _timeLeft = 10;

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _prepareSubmissions();
    _setupAnimations();
    _startRevealSequence();
    _startDisplayTimer();
  }

  void _prepareSubmissions() {
    // Separate winning and non-winning submissions
    final String? winningPlayerId = widget.winning_submission['playerId'] as String?;
    
    List<MapEntry<String, List<Map<String, dynamic>>>> winningSubmissions = [];
    List<MapEntry<String, List<Map<String, dynamic>>>> otherSubmissions = [];
    
    for (final entry in widget.submissions.entries) {
      if (entry.key == winningPlayerId) {
        winningSubmissions.add(entry);
      } else {
        otherSubmissions.add(entry);
      }
    }
    
    // Show non-winning cards first, then winning cards last
    _orderedSubmissions = [...otherSubmissions, ...winningSubmissions];
  }

  void _setupAnimations() {
    _cardControllers = List.generate(
      _orderedSubmissions.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _startRevealSequence() {
    _mainController.forward();
    
    // Reveal cards one by one with a delay
    for (int i = 0; i < _cardControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 500 + (i * 800)), () {        if (mounted && i < _cardControllers.length) {
          _cardControllers[i].forward();
        }
      });
    }
  }

  void _startDisplayTimer() {
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _timeLeft--;
      });

      if (_timeLeft <= 0) {
        timer.cancel();
        if (widget.on_reveal_complete != null) {
          widget.on_reveal_complete!();
        }
      }
    });
  }

  @override
  void dispose() {
    _displayTimer.cancel();
    _mainController.dispose();
    for (final controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with timer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Round Results',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_timeLeft}s',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Black card display
            Expanded(
              flex: 2,
              child: FadeTransition(
                opacity: _mainController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: BlackCardDisplay(card_data: widget.black_card),
                ),
              ),
            ),
            
            // Submissions grid
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _orderedSubmissions.length,
                  itemBuilder: (context, index) {
                    final submission = _orderedSubmissions[index];                    final playerId = submission.key;
                    final cards = submission.value;
                    final playerName = widget.players[playerId]?['name'] ?? 'Unknown';
                    final isWinning = playerId == widget.winning_submission['playerId'];
                    
                    return AnimatedBuilder(
                      animation: _cardControllers[index],
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _cardControllers[index].value,
                          child: Opacity(
                            opacity: _cardControllers[index].value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isWinning ? Colors.amber : Colors.white.withOpacity(0.3),
                                  width: isWinning ? 3 : 1,
                                ),
                                boxShadow: isWinning ? [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ] : null,
                              ),
                              child: Column(
                                children: [
                                  // Player name
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isWinning ? Colors.amber : Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(11),
                                        topRight: Radius.circular(11),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isWinning)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: Icon(
                                              Icons.emoji_events,
                                              color: Colors.black,
                                              size: 18,
                                            ),
                                          ),
                                        Text(
                                          playerName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isWinning ? FontWeight.bold : FontWeight.w500,
                                            fontFamily: 'Montserrat',
                                            color: isWinning ? Colors.black : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Cards
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center, // Center cards if space allows
                                        children: cards.map((card) {
                                          return Padding( // Removed Expanded from here
                                            padding: const EdgeInsets.only(bottom: 4.0), 
                                            child: GameCard(
                                              cardData: card,
                                              isBlack: false,
                                              isSelected: false,
                                              animate: false,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
