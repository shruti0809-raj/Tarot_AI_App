import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:divine_guidance_app/screens/widgets/animations/twinkling_star.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  String? _completePhoneNumber; // E.164 from IntlPhoneField, e.g. +911234567890
  
  bool _codeSent = false;
  bool _isVerifyingOtp = false;
  bool _isSendingOtp = false;        // used by both Send OTP and Resend OTP buttons
  bool _isDialogRouting = false;     // loader for "Create account" in dialog
  int _resendCooldown = 0;

  Timer? _resendTimer;
  Timer? _sendOtpFailsafeTimer;
  Timer? _verifyFailsafeTimer;

  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();
  }

  @override
  void dispose() {
    _sendOtpFailsafeTimer?.cancel();
    _verifyFailsafeTimer?.cancel();
    _resendTimer?.cancel();
    _iconController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<bool> _showRecaptchaNotice() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Security Check"),
            content: const Text(
              "For your safety, we’ll open a secure verification (reCAPTCHA) page. "
              "You’ll return here automatically to enter your OTP.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Continue"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _promptCreateAccount(String phoneE164) async {
    final create = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (_) {
            bool localLoading = false; // local state for dialog loader
            return StatefulBuilder(
              builder: (context, setSBState) => AlertDialog(
                title: const Text("User not found"),
                content: Text(
                  "No account exists for $phoneE164.\nWould you like to create one?",
                ),
                actions: [
                  TextButton(
                    onPressed: localLoading ? null : () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: localLoading
                        ? null
                        : () async {
                            setSBState(() => localLoading = true);
                            setState(() => _isDialogRouting = true);
                            // Route to onboarding
                            Navigator.pop(context, true);
                          },
                    child: localLoading
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Create account"),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;

    if (create && mounted) {
      // Keep a brief loader state until navigation actually happens
      try {
        await Navigator.pushReplacementNamed(
          context,
          '/onboarding',
          arguments: {
            'signUpMode': 'createFlow',
            'fromLogin': true,
            'phone': phoneE164,
          },
        );
      } finally {
        if (mounted) setState(() => _isDialogRouting = false);
      }
    }
  }

  /// Strict **pre-OTP** existence check against public index
  Future<bool> _checkUserExistsByPhone(String phoneE164) async {
    try {
      final doc = await _firestore
          .collection('userPhoneIndex')
          .doc(phoneE164)
          .get(const GetOptions(source: Source.server));
      return doc.exists;
    } on FirebaseException {
      // If server read fails (network), be conservative: treat as not existing
      return false;
    }
  }

  // ───────────────── SEND / RESEND OTP (guarded by existence) ─────────────────
  Future<void> _sendOtpNow() async {
    if (_isSendingOtp) return; // debounced
    final phone = _completePhoneNumber?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number.")),
      );
      return;
    }

    // 0) Validate format (best-effort; don’t block on plugin errors)
    try {
      // If you want truly global validation, derive region from IntlPhoneField.countryISOCode
      final bool? valid = await PhoneNumberUtil.isValidPhoneNumber(
        phone.replaceFirst('+91', ''), // sample for IN; plugin needs a region
        'IN',
      );
      if (valid != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid phone number.")),
        );
        return;
      }
    } catch (_) {
      // ignore plugin issues
    }

    // 1) STRICT: check phone existence BEFORE OTP
    setState(() => _isSendingOtp = true);
    final exists = await _checkUserExistsByPhone(phone);
    if (!mounted) return;
    if (!exists) {
      setState(() => _isSendingOtp = false);
      await _promptCreateAccount(phone);
      return; // stop here; do NOT start OTP
    }

    // 2) Existing user → proceed with OTP
    if (!_codeSent) {
      final ok = await _showRecaptchaNotice();
      if (!ok) {
        setState(() => _isSendingOtp = false);
        return;
      }
    }

    _sendOtpFailsafeTimer?.cancel();
    _sendOtpFailsafeTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      if (_isSendingOtp) {
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP request is taking too long. Please try again."),
          ),
        );
      }
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (cred) async {
          // Leave final routing to manual verify flow
        },
        verificationFailed: (e) {
          if (!mounted) return;
          _sendOtpFailsafeTimer?.cancel();
          setState(() => _isSendingOtp = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? 'OTP request failed.')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          _sendOtpFailsafeTimer?.cancel();
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isSendingOtp = false;
            _resendCooldown = 30;
          });
          _resendTimer?.cancel();
          _resendTimer =
              Timer.periodic(const Duration(seconds: 1), (Timer timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            if (_resendCooldown == 0) {
              timer.cancel();
            } else {
              setState(() => _resendCooldown--);
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId ??= verificationId;
          if (mounted) setState(() => _isSendingOtp = false);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _sendOtpFailsafeTimer?.cancel();
      setState(() => _isSendingOtp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  // ───────────────── VERIFY OTP → HOME (no extra existence check) ─────────────────
  Future<void> _verifyOtpCode() async {
    if (_isVerifyingOtp) return; // debounced
    final otp = _otpController.text.trim();
    if (otp.length != 6 || (_verificationId?.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 6-digit OTP.")),
      );
      return;
    }

    setState(() => _isVerifyingOtp = true);

    _verifyFailsafeTimer?.cancel();
    _verifyFailsafeTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted) return;
      if (_isVerifyingOtp) {
        setState(() => _isVerifyingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP verification is taking too long. Please retry."),
          ),
        );
      }
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);

      // Per your spec: success -> HOME (we already checked existence earlier)
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP Verification failed: ${e.toString()}")),
      );
    } finally {
      if (!mounted) return;
      _verifyFailsafeTimer?.cancel();
      setState(() => _isVerifyingOtp = false);
    }
  }

  // ───────────────── UI (unchanged visuals; added loaders to all buttons) ─────────────────
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
        left: icon.containsKey('left') ? (icon['left'] as double) + offsetX : null,
        right: icon.containsKey('right') ? (icon['right'] as double) - offsetX : null,
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

  @override
  Widget build(BuildContext context) {
    final sendingOrRouting = _isSendingOtp || _isDialogRouting;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/design/background1.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withAlpha((0.6 * 255).toInt())),
          AnimatedBuilder(
            animation: _iconController,
            builder: (context, child) {
              final w = MediaQuery.of(context).size.width;
              final iconOffset = _iconController.value * w * 1.2;
              return Stack(
                children: [
                  const TwinklingStarField(),
                  ..._buildCelestialIcons(-iconOffset),
                ],
              );
            },
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Welcome to Tarot Reading",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_codeSent) ...[
                            IntlPhoneField(
                              initialCountryCode: 'IN',
                              onChanged: (phone) {
                                _completePhoneNumber = phone.completeNumber; // E.164
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Phone Number",
                                hintStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: (sendingOrRouting || _resendCooldown > 0)
                                  ? null
                                  : _sendOtpNow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 36, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isSendingOtp
                                  ? const Center(
                                      child: SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _resendCooldown > 0
                                          ? 'Resend in $_resendCooldown s'
                                          : 'Send OTP',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "Enter OTP",
                                hintStyle: TextStyle(color: Colors.white54),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _isVerifyingOtp ? null : _verifyOtpCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 36, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isVerifyingOtp
                                  ? const SizedBox(
                                      width: 24, height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text("Verify OTP", style: TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(height: 12),
                            // Resend button now also shows loader while _isSendingOtp
                            TextButton(
                              onPressed: (_resendCooldown > 0 || _isSendingOtp)
                                  ? null
                                  : _sendOtpNow,
                              child: _isSendingOtp
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      _resendCooldown > 0
                                          ? "Resend OTP in $_resendCooldown s"
                                          : "Resend OTP",
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
