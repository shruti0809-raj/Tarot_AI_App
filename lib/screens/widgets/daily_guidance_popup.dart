import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';


class DailyGuidancePopup extends StatefulWidget {
  const DailyGuidancePopup({super.key});

  @override
  State<DailyGuidancePopup> createState() => _DailyGuidancePopupState();
}

class _DailyGuidancePopupState extends State<DailyGuidancePopup>
    with SingleTickerProviderStateMixin {
  List<String> cardPaths = ['', '', ''];
  List<bool> isRevealed = [false, false, false];
  bool isLoaded = false;
  late SharedPreferences prefs;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  late String userId;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.phoneNumber ?? 'guest';
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
    _initializeNotifications();
    _loadOrGenerateCards();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    _scheduleDailyNotification();
  }

  Future<void> _scheduleDailyNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_guidance_channel',
      'Daily Guidance',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Your Daily Guidance is Ready ✨',
      'Tap to see your affirmation, charm & message for today.',
      _nextInstanceOfNineAM(),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfNineAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _loadOrGenerateCards() async {
    prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDate = prefs.getString('${userId}_daily_guidance_date');

    if (savedDate == today) {
      setState(() {
        cardPaths =
            List.generate(3, (index) => prefs.getString('${userId}_card_$index') ?? '');
        isRevealed =
            List.generate(3, (index) => prefs.getBool('${userId}_revealed_$index') ?? false);
        isLoaded = true;
      });
    } else {
      final random = Random();
      final affirm = 'assets/cards/affirmations/card${random.nextInt(40) + 1}.jpg';
      final charm = 'assets/cards/charms/card${random.nextInt(20) + 1}.jpg';
      final message = 'assets/cards/messages/card${random.nextInt(104) + 1}.jpg';

      cardPaths = [affirm, charm, message];
      await prefs.setString('${userId}_daily_guidance_date', today);
      for (int i = 0; i < 3; i++) {
        await prefs.setString('${userId}_card_$i', cardPaths[i]);
        await prefs.setBool('${userId}_revealed_$i', false);
      }

      setState(() {
        isRevealed = [false, false, false];
        isLoaded = true;
      });
    }
  }

  Future<void> _revealCard(int index) async {
    setState(() => isRevealed[index] = true);
    await prefs.setBool('${userId}_revealed_$index', true);
  }

 Future<void> _shareCard(int index) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cardPath = cardPaths[index];
      final cardBytes = await rootBundle.load(cardPath);
      final backgroundBytes = await rootBundle.load('assets/design/background2.jpg');
      final logoBytes = await rootBundle.load('assets/logo/logo.png');
      final watermarkBytes = await rootBundle.load('assets/logo/watermark.png');
      final storeBadgeBytes = await rootBundle.load('assets/badges/google_play_badge.png');

      final cardImage = (await (await ui.instantiateImageCodec(cardBytes.buffer.asUint8List())).getNextFrame()).image;
      final bgImage = (await (await ui.instantiateImageCodec(backgroundBytes.buffer.asUint8List())).getNextFrame()).image;
      final logoImage = (await (await ui.instantiateImageCodec(logoBytes.buffer.asUint8List())).getNextFrame()).image;
      final watermarkImage = (await (await ui.instantiateImageCodec(watermarkBytes.buffer.asUint8List())).getNextFrame()).image;
      final storeBadge = (await (await ui.instantiateImageCodec(storeBadgeBytes.buffer.asUint8List())).getNextFrame()).image;

     final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      final canvasWidth = bgImage.width.toDouble();
      final canvasHeight = bgImage.height.toDouble();
      canvas.drawImage(bgImage, Offset.zero, paint);

      // CARD
      final cardWidth = canvasWidth * 0.7;
      final cardHeight = cardWidth * (cardImage.height / cardImage.width);
      final cardX = (canvasWidth - cardWidth) / 2;
      final cardY = canvasHeight * 0.12;

      canvas.drawImageRect(
        cardImage,
        Rect.fromLTWH(0, 0, cardImage.width.toDouble(), cardImage.height.toDouble()),
        Rect.fromLTWH(cardX, cardY, cardWidth, cardHeight),
        paint,
      );

      // SMALL CENTERED WATERMARK (like before)
      final wmWidth = cardWidth * 0.5;
      final wmHeight = wmWidth * (watermarkImage.height / watermarkImage.width);
      final wmX = cardX + (cardWidth - wmWidth) / 2;
      final wmY = cardY + (cardHeight - wmHeight) / 2;

      canvas.drawImageRect(
        watermarkImage,
        Rect.fromLTWH(0, 0, watermarkImage.width.toDouble(), watermarkImage.height.toDouble()),
        Rect.fromLTWH(wmX, wmY, wmWidth, wmHeight),
        Paint()
          ..color = Colors.white.withOpacity(0.25)
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );

      // BADGE + LOGO aligned properly below the card
          final bottomRowY = cardY + cardHeight + 32;

          final badgeWidth = canvasWidth * 0.35;
          final badgeHeight = badgeWidth * (storeBadge.height / storeBadge.width);

          final logoWidth = canvasWidth * 0.22; // Increased size
          final logoHeight = logoWidth * (logoImage.height / logoImage.width);

          final spacing = 20.0;
          final totalRowWidth = badgeWidth + spacing + logoWidth;
          final startX = (canvasWidth - totalRowWidth) / 2;

          // Draw Google Play badge
          canvas.drawImageRect(
            storeBadge,
            Rect.fromLTWH(0, 0, storeBadge.width.toDouble(), storeBadge.height.toDouble()),
            Rect.fromLTWH(startX, bottomRowY, badgeWidth, badgeHeight),
            paint,
          );

          // Draw App Logo aligned to badge
          canvas.drawImageRect(
            logoImage,
            Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
            Rect.fromLTWH(startX + badgeWidth + spacing, bottomRowY, logoWidth, logoHeight),
            paint,
          );


      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final xfile = XFile.fromData(
        pngBytes,
        name: 'atma_card_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );

      Navigator.of(context).pop();

      await Share.shareXFiles(
        [xfile],
        text: 'Here’s my Daily Guidance ✨ from Atma Tarot by AI 🌌',
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share image: $e')));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isLoaded
        ? Dialog(
            backgroundColor: Colors.black.withAlpha(102),
            insetPadding: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Colors.deepPurpleAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            "Click on the Cards Below to Reveal your Daily Guidance ✨",
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(3, (index) {
                          final folder = index == 0
                              ? 'affirmations'
                              : index == 1
                                  ? 'charms'
                                  : 'messages';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    if (!isRevealed[index]) _revealCard(index);
                                  },
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (child, animation) => ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                    child: isRevealed[index]
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.asset(
                                              cardPaths[index],
                                              width: 250,
                                              key: ValueKey(cardPaths[index]),
                                            ),
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.asset(
                                              'assets/cards/$folder/card_back.jpg',
                                              width: 250,
                                              key: ValueKey('back_$index'),
                                            ),
                                          ),
                                  ),
                                ),
                                if (isRevealed[index])
                                  TextButton.icon(
                                    onPressed: () => _shareCard(index),
                                    icon: const Icon(Icons.share, color: Colors.purple),
                                    label: const Text("Share", style: TextStyle(color: Colors.purple)),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}
