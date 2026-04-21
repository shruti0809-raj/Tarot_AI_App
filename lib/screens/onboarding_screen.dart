import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:divine_guidance_app/screens/intro_free_reading_screen.dart';
import 'package:divine_guidance_app/screens/services/reading_balance_service.dart';
import 'package:divine_guidance_app/screens/legal/privacy_policy_screen.dart';
import 'package:divine_guidance_app/screens/legal/terms_conditions_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _otpController = TextEditingController();

  String _fullPhoneNumber = '';
  bool _agreedToPolicies = false;
  String? _error;

  // OTP state
  bool _otpSent = false;
  bool _otpVerified = false;
  String? _verificationId;
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _verifyingOtp = false;
  bool _sendingOtp = false;

  // Account creation
  bool _creatingAccount = false;

  // Watchdog to avoid endless loader if Play Services / reCAPTCHA hangs
  Timer? _otpWatchdog;

  late AnimationController _iconController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _navigatedAway = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    // Handle entry mode + prefill phone from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    // 1) Prefill phone from arguments when arriving from Login
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final passedPhone = (args['phone'] as String?)?.trim();
      if (passedPhone != null && passedPhone.isNotEmpty) {
        setState(() => _fullPhoneNumber = passedPhone);
      }
    }

    // 2) If already signed in (e.g., hot reload or prior flow), and has no user doc → stay to create it
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _otpVerified = true;   // phone already verified in Auth
        _otpSent = true;
        _fullPhoneNumber = user.phoneNumber ?? _fullPhoneNumber;
      });

      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!mounted) return;
        if (snap.exists) {
          _navigateSafely(() {
            Navigator.pushReplacementNamed(context, '/home');
          });
          return;
        }
      } catch (_) {
        // keep onboarding flow active to create Firestore doc
      }
    }
  }

  @override
  void dispose() {
    _stopAllTimers();
    _iconController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _stopAllTimers() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _otpWatchdog?.cancel();
    _otpWatchdog = null;
  }

  void _navigateSafely(VoidCallback nav) {
    if (_navigatedAway) return;
    _navigatedAway = true;
    _stopAllTimers();
    _iconController.stop();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nav();
    });
  }

  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<bool> _showRecaptchaNotice() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Security Check"),
            content: const Text(
              "We’ll open a secure verification (reCAPTCHA) page. "
              "You’ll return here automatically to enter your OTP.",
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Continue")),
            ],
          ),
        ) ??
        false;
  }

  // ───────────────── OTP: Send / Resend (only if user is NOT already signed in) ─────────────────
  Future<void> _sendOtpNow() async {
    if (_auth.currentUser != null) {
      if (!mounted) return;
      setState(() => _error = "You are already verified.");
      return;
    }

    if (_fullPhoneNumber.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _error = "Enter phone number");
      return;
    }

    if (!_otpSent) {
      final proceed = await _showRecaptchaNotice();
      if (proceed != true) return;
    }

    if (mounted) {
      setState(() {
        _sendingOtp = true;
        _error = null;
      });
    }

    // Watchdog: if callbacks don't arrive (Play Services/reCAPTCHA), allow manual entry
    _otpWatchdog?.cancel();
    _otpWatchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      if (_sendingOtp) {
        setState(() {
          _sendingOtp = false;
          _otpSent = true; // reveal OTP entry so user can type SMS manually
          _error =
              "Couldn’t auto-complete verification on this device. Enter the SMS code manually.";
        });
      }
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCred = await _auth.signInWithCredential(credential);
            _otpWatchdog?.cancel();
            if (!mounted) return;
            if (userCred.user != null) {
              setState(() {
                _otpVerified = true;
                _otpSent = true;
                _sendingOtp = false;
              });
            } else {
              setState(() => _sendingOtp = false);
            }
          } catch (_) {
            _otpWatchdog?.cancel();
            if (mounted) {
              setState(() {
                _error = "Auto-verification failed.";
                _sendingOtp = false;
              });
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _otpWatchdog?.cancel();
          if (!mounted) return;
          setState(() {
            _error = e.message;
            _sendingOtp = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          _otpWatchdog?.cancel();
          if (!mounted) return;
          setState(() {
            _otpSent = true;
            _verificationId = verificationId;
            _sendingOtp = false;
            _resendCountdown = 30;
          });

          _resendTimer?.cancel();
          _resendTimer =
              Timer.periodic(const Duration(seconds: 1), (Timer timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            if (_resendCountdown <= 1) {
              setState(() => _resendCountdown = 0);
              timer.cancel();
            } else {
              setState(() => _resendCountdown--);
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _otpWatchdog?.cancel();
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId; // keep latest ID
            _sendingOtp = false; // ensure button re-enables
          });
        },
      );
    } catch (_) {
      _otpWatchdog?.cancel();
      if (mounted) {
        setState(() {
          _error = "Failed to send OTP. Try again.";
          _sendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_auth.currentUser != null) {
      if (!mounted) return;
      setState(() => _error = "You are already verified.");
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6 || _verificationId == null) {
      if (!mounted) return;
      setState(() => _error = "Enter a valid 6-digit OTP");
      return;
    }

    if (mounted) {
      setState(() {
        _verifyingOtp = true;
        _error = null;
      });
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        if (mounted) {
          setState(() {
            _error = "No internet connection";
            _verifyingOtp = false;
          });
        }
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCred = await _auth.signInWithCredential(credential);
      if (!mounted) return;

      if (userCred.user == null) {
        setState(() => _error = "OTP verification failed.");
      } else {
        setState(() => _otpVerified = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = "OTP verification failed. Try again.");
      }
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  // ───────────────── Create Firestore profile & phone index ─────────────────
  Future<void> _createAccount() async {
    if (!_agreedToPolicies) {
      if (!mounted) return;
      setState(() => _error = "You must agree to the Terms & Privacy Policy.");
      return;
    }

    if (!_otpVerified) {
      if (!mounted) return;
      setState(() => _error = "Please verify your phone number first.");
      return;
    }

    setState(() {
      _creatingAccount = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();

    try {
      final user = _auth.currentUser;
      final uid = user?.uid;
      final phone = user?.phoneNumber ?? _fullPhoneNumber.trim();
      if (uid == null || phone.isEmpty) {
        throw Exception("User not available.");
      }

      // Ensure fresh token before first write
      await user!.getIdToken(true);

      final usersDoc = FirebaseFirestore.instance.collection('users').doc(uid);

      await usersDoc.set({
        'name': name,
        'dob': dob,
        'phone': phone,
        'loginType': 'phone',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔑 Write the phone → uid public index for strict pre-OTP login flow
      await FirebaseFirestore.instance
          .collection('userPhoneIndex')
          .doc(phone) // E.164 string (e.g. +911234567890)
          .set({'uid': uid}, SetOptions(merge: true));

      // Optional: initialize reading balance
      await ReadingBalanceService().resetBalance(3);

      if (!mounted) return;
      _navigateSafely(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) =>
                IntroFreeReadingScreen(userName: name.isEmpty ? 'Friend' : name),
          ),
          (route) => false,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Something went wrong. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _creatingAccount = false);
    }
  }

  // ───────────────── Visual helpers ─────────────────
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
      final double? top = icon['top'] as double?;
      final double? bottom = icon['bottom'] as double?;
      final double? left = icon['left'] as double?;
      final double? right = icon['right'] as double?;
      final double size = icon['size'] as double;
      final String path = icon['path'] as String;

      return Positioned(
        top: top,
        bottom: bottom,
        left: left != null ? left + offsetX : null,
        right: right != null ? right - offsetX : null,
        child: _animatedIcon(path, size),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final alreadySignedIn = _auth.currentUser != null;

    return Scaffold(
      body: Stack(
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
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "Create Account",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),

                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: "Full Name"),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter your name' : null,
                      ),

                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _selectDOB,
                        decoration:
                            const InputDecoration(labelText: "Date of Birth"),
                        validator: (value) =>
                            value!.isEmpty ? 'Enter DOB' : null,
                      ),

                      // Phone input
                      IntlPhoneField(
                        enabled: !alreadySignedIn && !_otpVerified,
                        decoration:
                            const InputDecoration(labelText: 'Phone Number'),
                        initialCountryCode: 'IN',
                        initialValue: alreadySignedIn
                            ? (_auth.currentUser?.phoneNumber ?? '')
                            : (_fullPhoneNumber.isNotEmpty ? _fullPhoneNumber : null),
                        onChanged: (phone) {
                          _fullPhoneNumber = phone.completeNumber;
                        },
                        validator: (value) {
                          if (alreadySignedIn) return null;
                          return value == null ? 'Enter phone number' : null;
                        },
                      ),

                      // OTP section
                      if (!alreadySignedIn) ...[
                        if (!_otpVerified)
                          if (!_otpSent || (_otpSent && _resendCountdown == 0))
                            ElevatedButton(
                              onPressed: _sendingOtp ? null : _sendOtpNow,
                              child: _sendingOtp
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(_otpSent ? "Resend OTP" : "Send OTP"),
                            )
                          else
                            Text("Resend in $_resendCountdown seconds",
                                style: const TextStyle(color: Colors.grey)),

                        if (_otpSent)
                          Column(
                            children: [
                              TextFormField(
                                controller: _otpController,
                                enabled: !_otpVerified,
                                decoration: InputDecoration(
                                  labelText: "Enter 6-digit OTP",
                                  suffixIcon: _otpVerified
                                      ? const Icon(Icons.check_circle,
                                          color: Colors.green)
                                      : null,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              if (!_otpVerified)
                                ElevatedButton(
                                  onPressed: _verifyingOtp ? null : _verifyOtp,
                                  child: _verifyingOtp
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text("Verify OTP"),
                                ),
                            ],
                          ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.verified, color: Colors.green, size: 18),
                            SizedBox(width: 6),
                            Text("Phone verified",
                                style: TextStyle(color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      CheckboxListTile(
                        value: _agreedToPolicies,
                        onChanged: (value) =>
                            setState(() => _agreedToPolicies = value ?? false),
                        title: Wrap(
                          children: [
                            const Text("I agree to the "),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const TermsConditionsScreen())),
                              child: const Text("Terms & Conditions",
                                  style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue)),
                            ),
                            const Text(" and "),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const PrivacyPolicyScreen())),
                              child: const Text("Privacy Policy",
                                  style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue)),
                            ),
                          ],
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),

                      const SizedBox(height: 16),

                      ElevatedButton(
                        onPressed: _creatingAccount
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  _createAccount();
                                }
                              },
                        child: _creatingAccount
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("Create Account"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
