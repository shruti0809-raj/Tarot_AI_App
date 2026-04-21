import 'package:flutter/material.dart';
import 'package:divine_guidance_app/screens/widgets/intro_free_reading_widget.dart';

class IntroFreeReadingScreen extends StatelessWidget {
  final String userName;

  const IntroFreeReadingScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IntroFreeReadingWidget(
        userName: userName,
        onGetStarted: () => Navigator.pushNamedAndRemoveUntil(
        context,
        "/home",
        (route) => false,
      ),
      ),
    );
  }
}
