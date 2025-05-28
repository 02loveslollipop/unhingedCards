import 'package:flutter/material.dart';
import 'dart:async';

class Leaderboard extends StatefulWidget {
  final Map<dynamic, dynamic> players;
  final int display_duration;
  final Function() on_timeout;
  final bool is_game_over;

  const Leaderboard({
    super.key,
    required this.players,
    this.display_duration = 5,
    required this.on_timeout,
    this.is_game_over = false,
  });

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard>
    with SingleTickerProviderStateMixin {
  late List<MapEntry<dynamic, dynamic>> _sorted_players;
  late Timer _display_timer;
  int _time_left = 5;
  late AnimationController _animation_controller;
  @override
  void initState() {
    super.initState();

    _time_left = widget.display_duration;

    // Only start the timer if it's not the game over screen
    if (!widget.is_game_over) {
      _start_display_timer();
    }

    // Sort players by score
    _sorted_players =
        widget.players.entries.toList()..sort(
          (a, b) => (b.value['score'] ?? 0).compareTo(a.value['score'] ?? 0),
        );

    _animation_controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation_controller.forward();
  }

  void _start_display_timer() {
    _display_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _time_left--;
      });

      if (_time_left <= 0) {
        timer.cancel();
        widget.on_timeout();
      }
    });
  }

  @override
  void dispose() {
    _display_timer.cancel();
    _animation_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.is_game_over ? 'Final Scores' : 'Leaderboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: 'Montserrat',
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Rank',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Player',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Score',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(color: Colors.white, height: 1),

              // Player rows
              ...List.generate(_sorted_players.length, (index) {
                final player = _sorted_players[index];
                final bool isCardCzar = player.value['isCardCzar'] == true;
                final bool isHost = player.value['isHost'] == true;

                return SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animation_controller,
                      curve: Interval(
                        index * 0.1,
                        0.1 + index * 0.1,
                        curve: Curves.easeOut,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(
                                player.value['name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                  color: Colors.white,
                                  fontWeight:
                                      index == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              if (isCardCzar)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                ),
                              if (isHost)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.admin_panel_settings,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${player.value['score'] ?? 0}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                              fontWeight:
                                  index == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (!widget.is_game_over)
          Column(
            children: [
              const SizedBox(height: 10),
              Text(
                'Next round in $_time_left seconds...',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
