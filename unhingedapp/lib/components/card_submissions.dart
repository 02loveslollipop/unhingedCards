import 'package:flutter/material.dart';
import 'game_card_new.dart';

class CardSubmissions extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> submissions;
  final Map<dynamic, dynamic> players;
  final Function(String, List<Map<String, dynamic>>) on_winner_selected;
  final bool is_interactive;
  final int selection_time_limit;

  const CardSubmissions({
    Key? key,
    required this.submissions,
    required this.players,
    required this.on_winner_selected,
    this.is_interactive = true,
    this.selection_time_limit = 30,
  }) : super(key: key);

  @override
  State<CardSubmissions> createState() => _CardSubmissionsState();
}

class _CardSubmissionsState extends State<CardSubmissions>
    with SingleTickerProviderStateMixin {
  int _time_left = 30;
  bool _timer_started = false;
  String? _focused_submission_id;
  late AnimationController _animation_controller;

  @override
  void initState() {
    super.initState();
    _time_left = widget.selection_time_limit;

    if (widget.is_interactive) {
      _start_selection_timer();
    }

    _animation_controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation_controller.forward();
  }

  void _start_selection_timer() {
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
        _select_random_winner();
      } else {
        _start_selection_timer();
      }
    });
  }

  void _select_random_winner() {
    if (widget.submissions.isEmpty) return;

    // Get a random player ID from the submissions
    final List<String> player_ids = widget.submissions.keys.toList();
    player_ids.shuffle();

    if (player_ids.isNotEmpty) {
      final winner_id = player_ids.first;
      final winning_cards = widget.submissions[winner_id]!;
      widget.on_winner_selected(winner_id, winning_cards);
    }
  }

  void _focus_submission(String player_id) {
    setState(() {
      _focused_submission_id =
          _focused_submission_id == player_id ? null : player_id;
    });
  }

  String _get_anonymous_name(int index) {
    final List<String> names = [
      'Player A',
      'Player B',
      'Player C',
      'Player D',
      'Player E',
      'Player F',
      'Player G',
      'Player H',
    ];
    return index < names.length ? names[index] : 'Player ${index + 1}';
  }

  @override
  void dispose() {
    _animation_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Convert submissions to a list for easy rendering
    final submission_entries = widget.submissions.entries.toList();

    return Column(
      children: [
        // Header with timer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Card Submissions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                  color: Colors.white,
                ),
              ),
              if (widget.is_interactive && _timer_started)
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
        if (widget.is_interactive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Select the funniest submission',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Montserrat',
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),

        // Submissions grid
        Expanded(
          child:
              _focused_submission_id != null
                  ? _build_focused_submission()
                  : _build_submissions_grid(submission_entries),
        ),
      ],
    );
  }

  Widget _build_submissions_grid(
    List<MapEntry<String, List<Map<String, dynamic>>>> submissions,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: submissions.length,
      itemBuilder: (context, index) {
        final entry = submissions[index];
        final String player_id = entry.key;
        final List<Map<String, dynamic>> cards = entry.value;

        // If multiple cards, just show the first one with an indicator
        final Map<String, dynamic> display_card = cards.first;

        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 1.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animation_controller,
              curve: Interval(
                index * 0.05,
                0.6 + index * 0.05,
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              if (widget.is_interactive) {
                if (cards.length > 1) {
                  _focus_submission(player_id);
                } else {
                  widget.on_winner_selected(player_id, cards);
                }
              }
            },
            child: Column(
              children: [
                Stack(
                  children: [
                    // The card
                    GameCard(
                      cardData: display_card,
                      isBlack: false,
                      animate: false,
                    ),

                    // Multiple cards indicator
                    if (cards.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${cards.length} cards',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _get_anonymous_name(index),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Montserrat',
                  ),
                ),
                if (widget.is_interactive)
                  TextButton(
                    onPressed: () {
                      widget.on_winner_selected(player_id, cards);
                    },
                    child: Text(
                      'SELECT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _build_focused_submission() {
    if (_focused_submission_id == null ||
        !widget.submissions.containsKey(_focused_submission_id)) {
      return Center(child: Text('No submission selected'));
    }

    final cards = widget.submissions[_focused_submission_id]!;
    final index = widget.submissions.keys.toList().indexOf(
      _focused_submission_id!,
    );

    return Column(
      children: [
        // Back button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _focused_submission_id = null;
                  });
                },
                icon: Icon(Icons.arrow_back, color: Colors.white),
                label: Text(
                  'Back to all submissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Player name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _get_anonymous_name(index),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              color: Colors.white,
            ),
          ),
        ),

        // Cards display
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            children: [
              ...cards.map(
                (card) => Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GameCard(
                    cardData: card,
                    isBlack: false,
                    animate: false,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Select button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed:
                widget.is_interactive
                    ? () => widget.on_winner_selected(
                      _focused_submission_id!,
                      cards,
                    )
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'SELECT AS WINNER',
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
