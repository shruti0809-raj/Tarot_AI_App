import 'package:flutter/material.dart';
import 'dart:math';
import 'twinkling_star.dart';

class ParallaxBackground extends StatefulWidget {
  final Widget child;
  const ParallaxBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<ParallaxBackground> createState() => _ParallaxBackgroundState();
}

class _ParallaxBackgroundState extends State<ParallaxBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double starOffset = _controller.value * screenWidth;
        double iconOffset = starOffset * 1.2;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Static Background Layers (Layer 1 and 2)
            Image.asset('assets/design/bg_layer1.jpg', fit: BoxFit.cover),
            Image.asset('assets/design/background2.jpg', fit: BoxFit.cover),

            // Layer 3: Stars and Floating Icons move right → left
            Positioned.fill(
              child: Stack(
                children: [
                  Transform.translate(
                    offset: Offset(-starOffset, 0),
                    child: const TwinklingStarField(numberOfStars: 45),
                  ),
                  ..._buildCelestialIcons(-iconOffset),
                ],
              ),
            ),

            // Foreground Content
            widget.child,
          ],
        );
      },
    );
  }

  List<Widget> _buildCelestialIcons(double offsetX) {
    final List<Map<String, dynamic>> iconData = [
      {'path': 'assets/icons/star_small.png', 'top': 100.0, 'left': 30.0, 'size': 12.0},
      {'path': 'assets/icons/star_medium.png', 'top': 250.0, 'right': 40.0, 'size': 16.0},
      {'path': 'assets/icons/star_large.png', 'bottom': 180.0, 'left': 80.0, 'size': 20.0},
      {'path': 'assets/icons/moonstar.png', 'bottom': 60.0, 'right': 60.0, 'size': 18.0},
      {'path': 'assets/icons/constellation.png', 'top': 120.0, 'right': 100.0, 'size': 24.0},
      {'path': 'assets/icons/eye.png', 'bottom': 100.0, 'right': 120.0, 'size': 18.0},
      {'path': 'assets/icons/evileye.png', 'top': 80.0, 'left': 160.0, 'size': 18.0},
      {'path': 'assets/icons/feather.png', 'bottom': 150.0, 'left': 40.0, 'size': 22.0},
      {'path': 'assets/icons/planet.png', 'top': 200.0, 'left': 200.0, 'size': 24.0},
      {'path': 'assets/icons/moon.png', 'bottom': 50.0, 'right': 20.0, 'size': 26.0},
    ];

    return iconData.map((icon) {
      return Positioned(
        top: icon['top'] as double?,
        bottom: icon['bottom'] as double?,
        left: icon.containsKey('left')
            ? (icon['left'] as double?)! + offsetX
            : null,
        right: icon.containsKey('right')
            ? (icon['right'] as double?)! - offsetX
            : null,
        child: _animatedIcon(icon['path'] as String, icon['size'] as double),
      );
    }).toList();
  }

  Widget _animatedIcon(String path, double size) {
    final duration = Duration(seconds: 5 + Random().nextInt(6));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.15),
      duration: duration,
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.85 + Random().nextDouble() * 0.15,
          child: Transform.rotate(
            angle: value / 6,
            child: Transform.scale(
              scale: value,
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        path,
        width: size,
        height: size,
        color: Colors.white.withAlpha((0.8 * 255).toInt()),
      ),
    );
  }
}