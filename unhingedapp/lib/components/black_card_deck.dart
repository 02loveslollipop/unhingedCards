import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'game_card.dart';

class BlackCardDeck extends StatefulWidget {
  final Function() on_card_drawn;
  final bool is_interactive;
  final bool has_animation;
  final int timer_duration;

  const BlackCardDeck({
    Key? key,
    required this.on_card_drawn,
    this.is_interactive = true,
    this.has_animation = true,
    this.timer_duration = 5,
  }) : super(key: key);

  @override
  State<BlackCardDeck> createState() => _BlackCardDeckState();
}

class _BlackCardDeckState extends State<BlackCardDeck>
    with TickerProviderStateMixin {
  late AnimationController _animation_controller;
  bool _is_drawing = false;
  int _time_left = 5;

  @override
  void initState() {
    super.initState();
    _animation_controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _time_left = widget.timer_duration;

    if (!widget.is_interactive) {
      _start_auto_draw_timer();
    }
  }

  void _start_auto_draw_timer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _time_left--;
      });

      if (_time_left <= 0) {
        _draw_card();
      } else {
        _start_auto_draw_timer();
      }
    });
  }

  void _draw_card() {
    if (_is_drawing) return;

    setState(() {
      _is_drawing = true;
    });

    if (widget.has_animation) {
      _animation_controller.forward().then((_) {
        widget.on_card_drawn();
      });
    } else {
      widget.on_card_drawn();
    }
  }

  @override
  void dispose() {
    _animation_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main card stack
        GestureDetector(
          onTap: widget.is_interactive ? _draw_card : null,
          child: AnimatedBuilder(
            animation: _animation_controller,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Perspective
                      ..rotateY(_animation_controller.value * math.pi),
                child: Container(
                  width: 200,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'DRAW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Timer overlay
        if (!widget.is_interactive && _time_left > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "$_time_left",
                style: TextStyle(
                  color: Colors.white,
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
