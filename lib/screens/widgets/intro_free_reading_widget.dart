import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class IntroFreeReadingWidget extends StatefulWidget {
  final String userName;
  final VoidCallback onGetStarted;

  const IntroFreeReadingWidget({
    super.key,
    required this.userName,
    required this.onGetStarted,
  });

  @override
  State<IntroFreeReadingWidget> createState() => _IntroFreeReadingWidgetState();
}

class _IntroFreeReadingWidgetState extends State<IntroFreeReadingWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _iconController;
  late Animation<double> _fadeIn;

  double? _conversionRate;
  String _targetCurrencySymbol = "₹"; // default

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrencyRate();
    });
  }

  Future<void> _loadCurrencyRate() async {
    final locale = Localizations.localeOf(context).toString();
    _targetCurrencySymbol =
        NumberFormat.simpleCurrency(locale: locale).currencySymbol;

    if (_targetCurrencySymbol == "₹" || _targetCurrencySymbol == "INR") return;

    try {
      const apiKey = "b48fc9d300c617558b89179d";
      final url =
          Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/latest/INR');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rate = data["conversion_rates"][_targetCurrencySymbol];
        if (rate != null) {
          setState(() => _conversionRate = rate.toDouble());
        }
      }
    } catch (e) {
      print("Currency API error: $e");
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  String _formatPrice(num inr) {
    if (_targetCurrencySymbol == "₹" || _targetCurrencySymbol == "INR") {
      return NumberFormat.simpleCurrency(locale: "en_IN").format(inr);
    } else {
      final rate = _conversionRate ?? 0.012;
      final converted = inr * rate;
      return NumberFormat.simpleCurrency(name: _targetCurrencySymbol)
          .format(converted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/design/background2.jpg', fit: BoxFit.cover),
        Container(color: Colors.black.withAlpha((0.4 * 255).toInt())),
        AnimatedBuilder(
          animation: _iconController,
          builder: (context, _) {
            double screenWidth = MediaQuery.of(context).size.width;
            double iconOffset = _iconController.value * screenWidth * 1.2;
            return Stack(children: _buildCelestialIcons(-iconOffset));
          },
        ),
        FadeTransition(
          opacity: _fadeIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("🌙", style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Text(
                  "Welcome, ${widget.userName.trim().split(' ').first} ✨",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cinzel',
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Tarot cards are a mirror to your soul.\nThey help you gain clarity, insight, and direction.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "🔮 With this app, you get:\n"
                  "• 3 free reading to begin\n"
                  "• Deep guidance through love, career, and more\n\n"
                  "💫 After that:\n"
                  "• ${_formatPrice(10)} per reading\n"
                  "• ${_formatPrice(45)} for 5 readings\n"
                  "• ${_formatPrice(90)} for 10 + 1 free\n"
                  "• ${_formatPrice(249)}/month for 1 daily\n"
                  "• ${_formatPrice(399)}/month for unlimited",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Colors.white70,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onGetStarted();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                    elevation: 6,
                  ),
                  child: const Text(
                    "Get My First Reading",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
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
