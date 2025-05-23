import 'package:flutter/material.dart';

class ResultAnimation extends StatefulWidget {
  final bool is_winner;
  final bool is_card_czar;
  final Function()? on_animation_complete;

  const ResultAnimation({
    Key? key,
    required this.is_winner,
    this.is_card_czar = false,
    this.on_animation_complete,
  }) : super(key: key);

  @override
  State<ResultAnimation> createState() => _ResultAnimationState();
}

class _ResultAnimationState extends State<ResultAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (widget.on_animation_complete != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          widget.on_animation_complete!();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color:
                      widget.is_card_czar
                          ? Colors.purple
                          : (widget.is_winner ? Colors.green : Colors.red),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          widget.is_card_czar
                              ? Colors.purple.withOpacity(0.5)
                              : (widget.is_winner ? Colors.green : Colors.red)
                                  .withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.is_card_czar)
                        const Icon(
                          Icons.arrow_forward,
                          size: 70,
                          color: Colors.white,
                        )
                      else
                        Icon(
                          widget.is_winner
                              ? Icons.emoji_events
                              : Icons.sentiment_dissatisfied,
                          size: 70,
                          color: Colors.white,
                        ),
                      const SizedBox(height: 16),
                      if (widget.is_card_czar)
                        const Text(
                          'SHOW SCOREBOARD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        )
                      else
                        Text(
                          widget.is_winner ? 'YOU WIN!' : 'YOU LOSE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      if (widget.is_winner && !widget.is_card_czar)
                        const SizedBox(height: 8),
                      if (widget.is_winner && !widget.is_card_czar)
                        Text(
                          '+1 point',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
