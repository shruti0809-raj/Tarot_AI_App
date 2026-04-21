import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OtpVerificationWidget extends StatefulWidget {
  final String verificationId;
  final Function(bool isNewUser) onVerified;

  const OtpVerificationWidget({
    super.key,
    required this.verificationId,
    required this.onVerified,
  });

  @override
  State<OtpVerificationWidget> createState() => _OtpVerificationWidgetState();
}

class _OtpVerificationWidgetState extends State<OtpVerificationWidget> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  String? _error;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = "Enter 6-digit OTP");
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        setState(() {
          _isVerifying = false;
          _error = "No internet connection";
        });
        return;
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;

      if (user == null) {
        throw Exception("FirebaseAuth returned null user");
      }

      final phoneNumber = user.phoneNumber ?? 'N/A';
      final uid = user.uid;
      final usersRef = FirebaseFirestore.instance.collection('users');

      // 🔍 Check Firestore for this phone number
      final snapshot = await usersRef.where('phone', isEqualTo: phoneNumber).limit(1).get();
      final isNewUser = snapshot.docs.isEmpty;

      // ✅ If user is new, create a minimal placeholder Firestore doc
      if (isNewUser) {
        await usersRef.doc(uid).set({
          'phone': phoneNumber,
          'loginType': 'phone',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      widget.onVerified(isNewUser); // isNewUser = true → go to onboarding

    } on FirebaseAuthException catch (e) {
      setState(() {
        _isVerifying = false;
        _error = e.message ?? "Invalid OTP";
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _error = "Something went wrong. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Enter OTP",
            style: TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '6-digit OTP',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _error,
            ),
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isVerifying
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _verifyOtp();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isVerifying
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Verify", style: TextStyle(fontSize: 16)),
          )
        ],
      ),
    );
  }
}
