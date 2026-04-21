import 'dart:math';
import 'package:flutter/material.dart';

class TwinklingStarField extends StatelessWidget {
  final int numberOfStars;

  const TwinklingStarField({super.key, this.numberOfStars = 20});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final random = Random();

    List<Widget> stars = List.generate(numberOfStars, (index) {
      // Random size
      final sizeOptions = [12.0, 16.0, 24.0]; // Small, medium, large
      final imageOptions = ['star_small.png', 'star_medium.png', 'star_large.png'];
      int variantIndex = random.nextInt(sizeOptions.length);

      // Random position
      final dx = random.nextDouble() * screenSize.width;
      final dy = random.nextDouble() * screenSize.height;

      // Random duration
      final duration = Duration(seconds: 2 + random.nextInt(4)); // 2s to 5s

      // Random opacity range
      final beginOpacity = 0.1 + random.nextDouble() * 0.4; // 0.1 to 0.5
      final endOpacity = 0.7 + random.nextDouble() * 0.3;   // 0.7 to 1.0

      return _TwinklingStar(
        imageName: imageOptions[variantIndex],
        position: Offset(dx, dy),
        size: sizeOptions[variantIndex],
        duration: duration,
        beginOpacity: beginOpacity,
        endOpacity: endOpacity,
      );
    });

    return Stack(children: stars);
  }
}

class _TwinklingStar extends StatefulWidget {
  final String imageName;
  final Offset position;
  final double size;
  final Duration duration;
  final double beginOpacity;
  final double endOpacity;

  const _TwinklingStar({
    required this.imageName,
    required this.position,
    required this.size,
    required this.duration,
    required this.beginOpacity,
    required this.endOpacity,
  });

  @override
  State<_TwinklingStar> createState() => _TwinklingStarState();
}

class _TwinklingStarState extends State<_TwinklingStar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(
      begin: widget.beginOpacity,
      end: widget.endOpacity,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.position.dy,
      left: widget.position.dx,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Image.asset(
            'assets/icons/${widget.imageName}',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
