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
    } // Handle animation triggers
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
      // Always show the front when not animating
      _flipController.value = 0.0;
    } // Handle face down changes
    if (widget.faceDown != oldWidget.faceDown) {
      if (widget.faceDown) {
        if (widget.animate) {
          // If changing to face down with animation, reset and trigger flip animation
          _flipController.reset();
          _flipController.forward();
        } else {
          // If animations disabled, just set the value to show the back of the card
          _flipController.value = 0.0;
        }
      } else if (_flipController.status == AnimationStatus.completed) {
        if (widget.animate) {
          // If turning face up with animation and animation was complete, reverse it
          _flipController.reverse();
        } else {
          // If animations disabled, just set the value to show the front of the card
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
          // Calculate flip progress from 0 to 1
          final animationValue = _flipAnimation.value / math.pi;

          // Determine which side to show
          bool showFront;

          if (!widget.animate) {
            // When not animating, just show front or back based on faceDown
            showFront = !widget.faceDown;
          } else {
            // When animating, use animation value to determine which side to show
            showFront = animationValue <= 0.5;
          }

          return Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective for 3D effect
                  ..scale(_scaleAnimation.value),
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              alignment: Alignment.center,
              child:
                  widget.animate
                      ?
                      // When animating, use flippy effect
                      _buildAnimatedCard(animationValue, showFront)
                      :
                      // When not animating, just show the right side directly
                      _buildStaticCard(showFront),
            ),
          );
        },
      ),
    );
  }

  // Build a simple static card without animations
  Widget _buildStaticCard(bool showFront) {
    return showFront
        ? _buildCard(isFront: true)
        : Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..rotateY(math.pi),
          child: _buildCard(isFront: false),
        );
  }

  // Build a card with flip animation
  Widget _buildAnimatedCard(double animationValue, bool showFront) {
    return Stack(
      children: [
        // Back side
        Opacity(
          opacity: showFront ? 0.0 : 1.0,
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(
                    math.pi +
                        math.min(
                          math.pi / 2,
                          ((animationValue - 0.5) * 2) * math.pi,
                        ),
                  ),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _buildCard(isFront: false),
            ),
          ),
        ),
        // Front side
        Opacity(
          opacity: showFront ? 1.0 : 0.0,
          child: Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(
                    widget.faceDown
                        ? math.min(math.pi / 2, animationValue * math.pi)
                        : 0.0,
                  ),
            child: _buildCard(isFront: true),
          ),
        ),
      ],
    );
  }

  Widget _buildFrontSide(double animationValue) {
    // Front card rotates from 0 to 90 degrees on Y axis only when animating
    final rotation =
        widget.animate && widget.faceDown
            ? math.min(math.pi / 2, animationValue * math.pi)
            : 0.0;

    // Use a simple opacity for front side
    final frontOpacity = 1.0;

    return Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspective for 3D effect
            ..rotateY(rotation), // Y-axis rotation only for flipping
      child: Opacity(opacity: frontOpacity, child: _buildCard(isFront: true)),
    );
  }

  Widget _buildBackSide(double animationValue) {
    // Back card rotates only when animating
    final progress = (animationValue - 0.5) * 2; // 0 to 1 during second half
    final rotation =
        widget.animate
            ? math.pi + math.min(math.pi / 2, progress * math.pi)
            : math.pi;

    // Use a simple opacity for back side
    final backOpacity = 1.0;

    return Transform(
      alignment: Alignment.center,
      transform:
          Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspective for 3D effect
            ..rotateY(rotation), // Y-axis rotation only for flipping
      child: Opacity(
        opacity: backOpacity,
        child: Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..rotateY(math.pi), // Flip back to correct text orientation
          child: _buildCard(isFront: false),
        ),
      ),
    );
  }

  Widget _buildCard({required bool isFront}) {
    // When not animating, use simple logic for determining which side to show
    final showFront =
        widget.animate
            ? (isFront || !widget.faceDown)
            : (isFront == !widget.faceDown);

    final cardColor = widget.isBlack ? Colors.black : Colors.white;
    final backColor = Colors.grey[800];

    return Container(
      width: 160,
      height: 220,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: showFront ? cardColor : backColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5.0,
            offset: const Offset(2, 2),
          ),
        ],
        border: Border.all(
          color: widget.isSelected ? Colors.yellow : Colors.grey[300]!,
          width: widget.isSelected ? 2.0 : 1.0,
        ),
      ),
      child: showFront ? _buildCardContent() : _buildCardBack(),
    );
  }

  Widget _buildCardContent() {
    // Safely extract text and pick count from card data with proper type handling
    String text;
    int pickCount = 1;

    try {
      // Handle text extraction with different map types
      final textValue = widget.cardData['text'];
      text = textValue?.toString() ?? 'Empty Card';

      // Handle pick count extraction with different map types
      final pickValue = widget.cardData['pick'];
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
                  color: widget.isBlack ? Colors.white : Colors.black,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (widget.isBlack && pickCount > 1)
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

  Widget _buildCardBack() {
    return Container(
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
    );
  }
}
