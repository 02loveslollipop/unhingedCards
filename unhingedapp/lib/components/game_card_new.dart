import 'package:flutter/material.dart';
import 'dart:math' as math;

class GameCard extends StatefulWidget {
  final Map<dynamic, dynamic> cardData;
  final bool isBlack;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool animate;
  final bool faceDown;

  const GameCard({
    super.key,
    required this.cardData,
    required this.isBlack,
    this.isSelected = false,
    this.onTap,
    this.animate = false,
    this.faceDown = false,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  late AnimationController _rotateController;
  late Animation<double> _rotateAnimation;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Flip animation (for revealing cards)
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Adjusted duration
    );
    // Animate controller value from 0.0 (front) to 1.0 (back)
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic), // Smoother curve
    );

    // Rotation animation (for card dealing)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _rotateAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeOutCubic),
    );

    // Scale animation (for card selection)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    // Always set rotate controller to end value immediately if not animating
    if (!widget.animate) {
      _rotateController.value = 1.0;
    } else {
      _rotateController.forward();
    }

    // Handle initial card state for faceDown
    if (widget.faceDown) {
      _flipController.value = 1.0; // Start face down (no animation, just set state)
    }

    if (widget.isSelected) {
      _scaleController.forward();
    }
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle selection changes
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _scaleController.forward();
      } else {
        _scaleController.reverse();
      }
    }

    // Handle animation triggers for deal animation
    if (widget.animate && !oldWidget.animate) {
      _rotateController.forward();
      // No automatic flip here, faceDown prop controls flip
    } else if (!widget.animate && oldWidget.animate) {
      _rotateController.value = 1.0;
    }

    // Handle face down changes to trigger flip animation
    if (widget.faceDown != oldWidget.faceDown) {
      if (widget.animate) { // Only animate if widget.animate is true
        if (widget.faceDown) { // Transitioning to face down
          _flipController.forward();
        } else { // Transitioning to face up
          _flipController.reverse();
        }
      } else { // Not animating, set instantly
        _flipController.value = widget.faceDown ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotateController, // For deal rotation
          _scaleController,  // For selection scale
          _flipController    // For flip
        ]),
        builder: (context, child) {
          final double flipValue = _flipAnimation.value; // Use the animation's value
          final double flipAngle = flipValue * math.pi;   // 0 to PI radians for rotation

          // Content should switch halfway through the flip
          final bool showFrontContent = flipValue < 0.5;

          return Transform( // Apply selection scale
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(_scaleAnimation.value),
            child: Transform.rotate( // Apply deal rotation
              angle: _rotateAnimation.value,
              alignment: Alignment.center,
              child: Transform( // Apply flip rotation
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective for Y rotation
                  ..rotateY(flipAngle),   // Rotate the card
                child: showFrontContent
                    ? _CardFront(
                        cardData: widget.cardData,
                        isBlack: widget.isBlack,
                        isSelected: widget.isSelected,
                      )
                    : Transform(
                        // Counter-rotate the back content so it's not mirrored
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(math.pi),
                        child: _CardBack(
                          isSelected: widget.isSelected,
                          isOriginalCardBlack: widget.isBlack, // Pass original card type
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

class _CardFront extends StatelessWidget {
  final Map<dynamic, dynamic> cardData;
  final bool isBlack;
  final bool isSelected;
  // Removed faceDown, animate, animationValue as they are handled by parent

  const _CardFront({
    required this.cardData,
    required this.isBlack,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Removed internal Transform for Y rotation
    return Container(
      width: 160,
      height: 220,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isBlack ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5.0,
            offset: const Offset(2, 2),
          ),
        ],
        border: Border.all(
          color: isSelected ? Colors.yellow : Colors.grey[300]!,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: _buildCardContent(),
    );
  }

  Widget _buildCardContent() {
    // Safely extract text and pick count from card data with proper type handling
    String text;
    int pickCount = 1;

    try {
      // Handle text extraction with different map types
      final textValue = cardData['text'];
      text = textValue?.toString() ?? 'Empty Card';

      // Handle pick count extraction with different map types
      final pickValue = cardData['pick'];
      if (pickValue != null) {
        if (pickValue is int) {
          pickCount = pickValue;
        } else if (pickValue is String) {
          pickCount = int.tryParse(pickValue) ?? 1;
        } else if (pickValue is double) {
          pickCount = pickValue.toInt();
        }
      }
    } catch (e) {
      // Fallback if there's an error
      text = 'Card Error: ${e.toString().substring(0, 20)}...';
      print('Error parsing card data: $e');
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: isBlack ? Colors.white : Colors.black,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (isBlack && pickCount > 1)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Pick $pickCount',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final bool isSelected;
  final bool isOriginalCardBlack; // New property
  // Removed animate, animationValue

  const _CardBack({
    required this.isSelected,
    required this.isOriginalCardBlack, // Added to constructor
  });

  @override
  Widget build(BuildContext context) {
    final bool useBlackText = isOriginalCardBlack; // If original is black, back is white, text is black
    final Color backgroundColor = isOriginalCardBlack ? Colors.white : Colors.black;
    final Color textColor = useBlackText ? Colors.black : Colors.white;
    final Color borderColor = isSelected ? Colors.yellow : Colors.grey[isOriginalCardBlack ? 700 : 300]!;
    final Color dividerColor = useBlackText ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5);


    // Removed internal Transform for Y rotation
    return Container(
      width: 160,
      height: 220,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: backgroundColor, // Dynamic background color
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5.0,
            offset: const Offset(2, 2),
          ),
        ],
        border: Border.all(
          color: borderColor, // Dynamic border color
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: Colors.grey[useBlackText ? 400 : 600]!, width: 0.5), // Adjusted border for visibility
        ),
        margin: const EdgeInsets.all(15),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'UNHINGED',
                style: TextStyle(
                  color: textColor, // Dynamic text color
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 2,
                width: 80,
                color: dividerColor, // Dynamic divider color
              ),
              const SizedBox(height: 10),
              Text(
                'CARDS',
                style: TextStyle(
                  color: textColor, // Dynamic text color
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
