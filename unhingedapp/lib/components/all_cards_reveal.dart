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
    final String? winningPlayerId =
        widget.winning_submission['playerId'] as String?;

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
      Future.delayed(Duration(milliseconds: 500 + (i * 800)), () {
        if (mounted && i < _cardControllers.length) {
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
    final screenSize = MediaQuery.of(context).size;
    final safeAreaPadding = MediaQuery.of(context).padding;
    final availableHeight =
        screenSize.height - safeAreaPadding.top - safeAreaPadding.bottom;

    // Determine if device is small (phone) - hide black card on small screens
    final isSmallDevice = screenSize.width < 600 || availableHeight < 700;

    // More conservative fixed dimensions for layout calculation
    const headerHeight = 80.0;
    final blackCardHeight =
        isSmallDevice ? 0.0 : 100.0; // Hide black card on small devices
    const gridPadding = 12.0; // Reduced from 16
    const gridSpacing = 8.0; // Reduced from 12
    const bottomSafetyMargin = 20.0; // Add safety margin

    // Calculate grid dimensions with safety margin
    final gridAreaHeight =
        availableHeight -
        headerHeight -
        blackCardHeight -
        (gridPadding * 2) -
        bottomSafetyMargin;
    final gridCrossAxisCount = 2;
    final gridRowCount =
        (_orderedSubmissions.length / gridCrossAxisCount).ceil();
    final gridItemHeight =
        (gridAreaHeight - (gridSpacing * (gridRowCount - 1))) /
        gridRowCount; // Calculate card display area dimensions within each grid item
    const playerNameHeight = 35.0; // Reduced from 40

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          height: availableHeight,
          child: Stack(
            children: [
              // Header section
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isSmallDevice
                              ? 'Results'
                              : 'Round Results', // Shorter title on small devices
                          style: TextStyle(
                            fontSize:
                                isSmallDevice
                                    ? 20
                                    : 24, // Smaller font on small devices
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
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
              ), // Black card section - Only show on larger devices
              if (!isSmallDevice)
                Positioned(
                  top: headerHeight,
                  left: 0,
                  right: 0,
                  height: blackCardHeight,
                  child: Container(
                    child: FadeTransition(
                      opacity: _mainController,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: BlackCardDisplay(card_data: widget.black_card),
                      ),
                    ),
                  ),
                ),

              // Grid section
              Positioned(
                top: headerHeight + blackCardHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(gridPadding),
                  child: GridView.builder(
                    physics:
                        gridRowCount * gridItemHeight <= gridAreaHeight
                            ? NeverScrollableScrollPhysics()
                            : ClampingScrollPhysics(), // Changed to ClampingScrollPhysics for better behavior
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      mainAxisExtent: gridItemHeight.clamp(
                        80.0,
                        200.0,
                      ), // Clamp grid item height
                      crossAxisSpacing: gridSpacing,
                      mainAxisSpacing: gridSpacing,
                    ),
                    itemCount: _orderedSubmissions.length,
                    itemBuilder: (context, index) {
                      final submission = _orderedSubmissions[index];
                      final playerId = submission.key;
                      final cards = submission.value;
                      final playerName =
                          widget.players[playerId]?['name'] ?? 'Unknown';
                      final isWinning =
                          playerId == widget.winning_submission['playerId'];

                      return AnimatedBuilder(
                        animation: _cardControllers[index],
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _cardControllers[index].value,
                            child: Opacity(
                              opacity: _cardControllers[index].value,
                              child: Container(
                                height: gridItemHeight.clamp(
                                  80.0,
                                  200.0,
                                ), // Match the clamped height
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isWinning
                                            ? Colors.amber
                                            : Colors.white.withOpacity(0.3),
                                    width: isWinning ? 3 : 1,
                                  ),
                                  boxShadow:
                                      isWinning
                                          ? [
                                            BoxShadow(
                                              color: Colors.amber.withOpacity(
                                                0.5,
                                              ),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Column(
                                  children: [
                                    // Player name header
                                    Container(
                                      height: playerNameHeight,
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ), // Reduced padding
                                      decoration: BoxDecoration(
                                        color:
                                            isWinning
                                                ? Colors.amber
                                                : Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(11),
                                          topRight: Radius.circular(11),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isWinning)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ), // Reduced padding
                                              child: Icon(
                                                Icons.emoji_events,
                                                color: Colors.black,
                                                size: 14, // Reduced icon size
                                              ),
                                            ),
                                          Text(
                                            playerName,
                                            style: TextStyle(
                                              fontSize: 11, // Reduced font size
                                              fontWeight:
                                                  isWinning
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                              fontFamily: 'Montserrat',
                                              color:
                                                  isWinning
                                                      ? Colors.black
                                                      : Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Cards display area - Expanded to fill remaining space
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          2.0,
                                        ), // Minimal padding
                                        child: Column(
                                          children:
                                              cards.asMap().entries.map((
                                                entry,
                                              ) {
                                                final cardIndex = entry.key;
                                                final card = entry.value;

                                                return Expanded(
                                                  child: Container(
                                                    width:
                                                        double
                                                            .infinity, // Fill width
                                                    margin: EdgeInsets.only(
                                                      bottom:
                                                          cardIndex <
                                                                  cards.length -
                                                                      1
                                                              ? 1.0
                                                              : 0.0, // No margin on last card
                                                    ),
                                                    child: GameCard(
                                                      cardData: card,
                                                      isBlack: false,
                                                      isSelected: false,
                                                      animate: false,
                                                    ),
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
      ),
    );
  }
}
