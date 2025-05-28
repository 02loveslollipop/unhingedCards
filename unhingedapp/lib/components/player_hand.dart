import 'package:flutter/material.dart';
import 'game_card_new.dart';

class PlayerHand extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final int cards_to_submit;
  final List<Map<String, dynamic>> selected_cards;
  final Function(Map<String, dynamic>) on_card_selected;
  final Function() on_cards_submitted;
  final bool is_submission_enabled;
  final int submission_time_limit;
  final bool auto_submit_on_timeout;

  const PlayerHand({
    super.key,
    required this.cards,
    required this.cards_to_submit,
    required this.selected_cards,
    required this.on_card_selected,
    required this.on_cards_submitted,
    this.is_submission_enabled = true,
    this.submission_time_limit = 20,
    this.auto_submit_on_timeout = true,
  });

  @override
  State<PlayerHand> createState() => _PlayerHandState();
}

class _PlayerHandState extends State<PlayerHand> {
  int _time_left = 20;
  bool _timer_started = false;

  @override
  void initState() {
    super.initState();
    _time_left = widget.submission_time_limit;
    if (widget.is_submission_enabled) {
      _start_submission_timer();
    }
  }

  @override
  void didUpdateWidget(PlayerHand oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start timer if submission was just enabled
    if (widget.is_submission_enabled && !oldWidget.is_submission_enabled) {
      _time_left = widget.submission_time_limit;
      _timer_started = false;
      _start_submission_timer();
    }

    // Reset timer if cards to submit changed
    if (widget.cards_to_submit != oldWidget.cards_to_submit) {
      _time_left = widget.submission_time_limit;
      _timer_started = false;
      if (widget.is_submission_enabled) {
        _start_submission_timer();
      }
    }
  }

  void _start_submission_timer() {
    if (_timer_started) return;

    setState(() {
      _timer_started = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _time_left--;
      });

      if (_time_left <= 0) {
        if (widget.auto_submit_on_timeout) {
          _auto_select_cards();
        }
      } else {
        _start_submission_timer();
      }
    });
  }

  void _auto_select_cards() {
    // If no cards have been selected yet
    if (widget.selected_cards.isEmpty) {
      final cardsToAutoSelect = <Map<String, dynamic>>[];
      final availableCards = List<Map<String, dynamic>>.from(widget.cards);

      // Shuffle cards to randomize selection
      availableCards.shuffle();

      // Select the required number of cards or as many as available
      final count =
          widget.cards_to_submit <= availableCards.length
              ? widget.cards_to_submit
              : availableCards.length;

      for (var i = 0; i < count; i++) {
        final card = availableCards[i];
        widget.on_card_selected(card);
        cardsToAutoSelect.add(card);
      }

      // If we have the right number of cards, submit them
      if (cardsToAutoSelect.length == widget.cards_to_submit) {
        widget.on_cards_submitted();
      }
    }
    // If some cards are selected but not enough
    else if (widget.selected_cards.length < widget.cards_to_submit) {
      final availableCards =
          widget.cards
              .where((card) => !widget.selected_cards.contains(card))
              .toList();

      // Shuffle cards to randomize selection
      availableCards.shuffle();

      // Select the remaining required cards
      final remaining = widget.cards_to_submit - widget.selected_cards.length;
      final count =
          remaining <= availableCards.length
              ? remaining
              : availableCards.length;

      for (var i = 0; i < count; i++) {
        widget.on_card_selected(availableCards[i]);
      }

      // If we now have the right number of cards, submit them
      if (widget.selected_cards.length + count == widget.cards_to_submit) {
        widget.on_cards_submitted();
      }
    }
    // If we already have the right number of cards, just submit them
    else if (widget.selected_cards.length == widget.cards_to_submit) {
      widget.on_cards_submitted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with timer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your cards',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  color: Colors.white,
                ),
              ),
              if (widget.is_submission_enabled && _timer_started)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _time_left <= 5 ? Colors.red : Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _time_left <= 5 ? Colors.red : Colors.white,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$_time_left s',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Instructions
        if (widget.is_submission_enabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Select ${widget.cards_to_submit} card${widget.cards_to_submit > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Montserrat',
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),

        // Cards display
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              ...widget.cards.map((card) {
                final bool isSelected = widget.selected_cards.contains(card);
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Stack(
                    children: [
                      // Card
                      GameCard(
                        cardData: card,
                        isBlack: false,
                        isSelected: isSelected,
                        onTap:
                            widget.is_submission_enabled
                                ? () => widget.on_card_selected(card)
                                : null,
                      ),

                      // Selection indicator
                      if (isSelected && widget.cards_to_submit > 1)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${widget.selected_cards.indexOf(card) + 1}',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // Submit button
        if (widget.is_submission_enabled)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed:
                  widget.selected_cards.length == widget.cards_to_submit
                      ? widget.on_cards_submitted
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                disabledForegroundColor: Colors.black.withOpacity(0.5),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'SUBMIT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
