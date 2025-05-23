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
    Key? key,
    required this.cardData,
    required this.isBlack,
    this.isSelected = false,
    this.onTap,
    this.animate = false,
    this.faceDown = false,
  }) : super(key: key);

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
      duration: const Duration(milliseconds: 800),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeOutCubic),
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

    // Handle initial card state
    if (widget.faceDown && widget.animate) {
      // Only animate flipping if animations are enabled
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          _flipController.forward();
        }
      });
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

    // Handle animation triggers
    if (widget.animate && !oldWidget.animate) {
      _rotateController.forward();
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && widget.faceDown) {
          _flipController.forward();
        }
      });
    } else if (!widget.animate && oldWidget.animate) {
      // If animations are disabled, set to final position immediately
      _rotateController.value = 1.0;
      // Always show the correct side when not animating
      _flipController.value = 0.0;
    }

    // Handle face down changes
    if (widget.faceDown != oldWidget.faceDown) {
      if (widget.faceDown) {
        if (widget.animate) {
          // If changing to face down with animation, reset and trigger flip animation
          _flipController.reset();
          _flipController.forward();
        } else {
          // If animations disabled, just set the value instantly
          _flipController.value = 0.0;
        }
      } else if (_flipController.status == AnimationStatus.completed) {
        if (widget.animate) {
          // If turning face up with animation and animation was complete, reverse it
          _flipController.reverse();
        } else {
          // If animations disabled, just set the value instantly
          _flipController.value = 0.0;
        }
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
          _flipAnimation,
          _rotateAnimation,
          _scaleAnimation,
        ]),
        builder: (context, child) {
          final animationValue = _flipAnimation.value / math.pi;
          final bool showFront = animationValue <= 0.5;

          // For non-animated cards, determine visibility based on faceDown
          final bool displayFront =
              widget.animate ? showFront : !widget.faceDown;
          final bool displayBack =
              widget.animate ? !showFront : widget.faceDown;

          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..scale(_scaleAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              alignment: Alignment.center,
              child: Stack(
                children: [
                  // Card front
                  Visibility(
                    visible: displayFront,
                    child: _CardFront(
                      cardData: widget.cardData,
                      isBlack: widget.isBlack,
                      isSelected: widget.isSelected,
                      faceDown: widget.faceDown,
                      animate: widget.animate,
                      animationValue: animationValue,
                    ),
                  ),

                  // Card back
                  Visibility(
                    visible: displayBack,
                    child: _CardBack(
                      isSelected: widget.isSelected,
                      animate: widget.animate,
                      animationValue: animationValue,
                    ),
                  ),
                ],
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
  final bool faceDown;
  final bool animate;
  final double animationValue;

  const _CardFront({
    required this.cardData,
    required this.isBlack,
    required this.isSelected,
    required this.faceDown,
    required this.animate,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    // Only apply rotation if animating and faceDown
    final rotation =
        (animate && faceDown)
            ? math.min(math.pi / 2, animationValue * math.pi)
            : 0.0;

    return Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(rotation),
      child: Container(
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
      ),
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
  final bool animate;
  final double animationValue;

  const _CardBack({
    required this.isSelected,
    required this.animate,
    required this.animationValue,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate the rotation for back side
    final progress = (animationValue - 0.5) * 2; // 0 to 1 during second half
    final rotation =
        animate
            ?
            // Animated rotation for back side
            math.pi + math.min(math.pi / 2, progress * math.pi)
            :
            // Static rotation for non-animated back
            math.pi;

    return Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(rotation),
      child: Container(
        width: 160,
        height: 220,
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[800],
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
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: Colors.grey[500]!, width: 0.5),
          ),
          margin: const EdgeInsets.all(15),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'UNHINGED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  width: 80,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  'CARDS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
