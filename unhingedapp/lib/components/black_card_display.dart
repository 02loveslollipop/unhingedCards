import 'package:flutter/material.dart';
import 'game_card_new.dart';

class BlackCardDisplay extends StatelessWidget {
  final Map<dynamic, dynamic>? card_data;
  final Function()? on_reveal_complete;

  const BlackCardDisplay({
    Key? key,
    required this.card_data,
    this.on_reveal_complete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (card_data == null) {
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

    // Call on_reveal_complete with a small delay if provided
    if (on_reveal_complete != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        on_reveal_complete!();
      });
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
          Container(
            width: 176, // Card width + margin (160 + 16)
            height: 236, // Card height + margin (220 + 16)
            child: GameCard(
              cardData: card_data!,
              isBlack: true,
              animate: false,
              faceDown: false,
            ),
          ),
        ],
      ),
    );
  }
}
