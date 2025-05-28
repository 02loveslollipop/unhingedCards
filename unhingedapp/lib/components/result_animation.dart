import 'package:flutter/material.dart';

class ResultAnimation extends StatefulWidget {
  final bool is_winner;
  final bool is_card_czar;
  final Function()? on_animation_complete;

  const ResultAnimation({
    super.key,
    required this.is_winner,
    this.is_card_czar = false,
    this.on_animation_complete,
  });

  @override
  State<ResultAnimation> createState() => _ResultAnimationState();
}

class _ResultAnimationState extends State<ResultAnimation>
    with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rotating circle animation
                    Transform.rotate(
                      angle: _controller.value * 2 * 3.14159,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.is_winner ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Result text
                    if (widget.is_card_czar)
                      const Text(
                        'ROUND RESULTS',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      )
                    else
                      Text(
                        widget.is_winner ? 'YOU WIN!' : 'YOU LOSE',
                        style: TextStyle(
                          color: widget.is_winner ? Colors.green : Colors.red,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    if (widget.is_winner && !widget.is_card_czar)
                      const Text(
                        '+1 point',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
