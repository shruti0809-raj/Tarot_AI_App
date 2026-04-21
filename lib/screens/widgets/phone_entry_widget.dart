import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class PhoneEntryWidget extends StatefulWidget {
  final Function(String verificationId) onCodeSent;

  const PhoneEntryWidget({super.key, required this.onCodeSent});

  @override
  State<PhoneEntryWidget> createState() => _PhoneEntryWidgetState();
}

class _PhoneEntryWidgetState extends State<PhoneEntryWidget> {
  String fullPhoneNumber = '';
  bool _isSending = false;
  String? _error;

  Future<void> _sendOTP() async {
    if (fullPhoneNumber.isEmpty || !fullPhoneNumber.startsWith('+')) {
      setState(() => _error = 'Please enter a valid phone number');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Optional: Auto-sign-in
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isSending = false;
            _error = e.message ?? 'Failed to send OTP';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          widget.onCodeSent(verificationId);
          setState(() => _isSending = false);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _isSending = false);
        },
      );
    } catch (e) {
      setState(() {
        _isSending = false;
        _error = 'Something went wrong. Please try again.';
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
            "Enter your phone number",
            style: TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          IntlPhoneField(
            initialCountryCode: 'IN',
            style: const TextStyle(color: Colors.white),
            dropdownTextStyle: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Phone Number',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _error,
            ),
            onChanged: (phone) {
              fullPhoneNumber = phone.completeNumber;
              setState(() {
                _error = null;
              });
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSending
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _sendOTP();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isSending
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Send OTP", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
