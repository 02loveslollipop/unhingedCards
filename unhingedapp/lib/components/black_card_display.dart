import 'package:flutter/material.dart';
import 'game_card.dart';

class BlackCardDisplay extends StatefulWidget {
  final Map<dynamic, dynamic>? card_data;
  final bool has_reveal_animation;
  final int reveal_duration;
  final Function()? on_reveal_complete;

  const BlackCardDisplay({
    Key? key,
    required this.card_data,
    this.has_reveal_animation = true,
    this.reveal_duration = 2,
    this.on_reveal_complete,
  }) : super(key: key);

  @override
  State<BlackCardDisplay> createState() => _BlackCardDisplayState();
}

class _BlackCardDisplayState extends State<BlackCardDisplay> {
  bool _is_revealed = false;
  int _time_left = 2;

  @override
  void initState() {
    super.initState();
    _time_left = widget.reveal_duration;

    if (widget.has_reveal_animation) {
      _start_reveal_timer();
    } else {
      setState(() {
        _is_revealed = true;
      });

      if (widget.on_reveal_complete != null) {
        widget.on_reveal_complete!();
      }
    }
  }

  void _start_reveal_timer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        _time_left--;
      });

      if (_time_left <= 0) {
        setState(() {
          _is_revealed = true;
        });

        if (widget.on_reveal_complete != null) {
          widget.on_reveal_complete!();
        }
      } else {
        _start_reveal_timer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card_data == null) {
      return Center(
        child: Text(
          'No black card available',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Montserrat',
            color: Colors.white,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Black Card',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GameCard(
            cardData: widget.card_data!,
            isBlack: true,
            animate: true,
            faceDown: !_is_revealed,
          ),
          if (widget.has_reveal_animation && !_is_revealed)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Revealing in $_time_left...',
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'Montserrat',
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
