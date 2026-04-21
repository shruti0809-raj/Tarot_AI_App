import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailLoginWidget extends StatefulWidget {
  final VoidCallback onSwitchToSignUp;
  final VoidCallback onLoginSuccess;

  const EmailLoginWidget({
    super.key,
    required this.onSwitchToSignUp,
    required this.onLoginSuccess,
  });

  @override
  State<EmailLoginWidget> createState() => _EmailLoginWidgetState();
}

class _EmailLoginWidgetState extends State<EmailLoginWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _error;
  bool _isLoggingIn = false;
  bool _obscurePassword = true;

  Future<void> checkUserStatus(String email) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('checkUserStatus');
      final result = await callable.call({'email': email});

      if (result.data['success'] == true) {
        debugPrint("✅ User status fetched:");
        debugPrint("UID: \${result.data['uid']}");
        debugPrint("Email Verified: \${result.data['emailVerified']}");
        debugPrint("Disabled: \${result.data['disabled']}");
        debugPrint("Created At: \${result.data['createdAt']}");
        debugPrint("Last Sign-in: \${result.data['lastSignIn']}");
      } else {
        debugPrint("❌ Status check failed: \${result.data['message']}");
      }
    } catch (e, st) {
      debugPrint("❌ Callable function error: \$e");
      debugPrint("🔍 Stacktrace:\n$st");
    }
  }

  Future<void> _loginWithEmail() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  if (email.isEmpty || password.isEmpty) {
    if (mounted) setState(() => _error = "Please enter both email and password.");
    return;
  }

  if (mounted) {
    setState(() {
      _isLoggingIn = true;
      _error = null;
    });
  }

  try {
    final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;

    if (user != null) {
      final uid = user.uid;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        debugPrint("✅ Email login successful and Firestore user found.");
        widget.onLoginSuccess();
      } else {
        debugPrint("🆕 Email login successful, but no Firestore doc — redirecting to onboarding.");
        Navigator.pushNamed(context, '/onboarding');
      }
    } else {
      debugPrint("❌ No user returned after login.");
      if (mounted) setState(() => _error = "Login failed. No user found.");
    }
  } on FirebaseAuthException catch (e) {
    debugPrint("❌ FirebaseAuthException: ${e.code} – ${e.message}");
    await checkUserStatus(email); // Optional debugging tool
    if (mounted) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = "No account found for this email.";
            break;
          case 'wrong-password':
            _error = "Incorrect password. Please try again.";
            break;
          case 'invalid-email':
            _error = "Invalid email address.";
            break;
          case 'too-many-requests':
            _error = "Too many login attempts. Please try later.";
            break;
          default:
            _error = e.message ?? "Login failed.";
        }
      });
    }
  } catch (e, st) {
    debugPrint("❌ Unexpected error during email login: $e");
    debugPrint("🔍 Stacktrace:\n$st");
    await checkUserStatus(email);
    if (mounted) setState(() => _error = "Something went wrong. Please try again.");
  } finally {
    if (mounted) setState(() => _isLoggingIn = false);
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
            "Log In with Email",
            style: TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Email",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Password",
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // Add forgot password logic if needed
              },
              child: const Text("Forgot password?", style: TextStyle(color: Colors.white70)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoggingIn ? null : _loginWithEmail,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: _isLoggingIn
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Log In", style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: widget.onSwitchToSignUp,
            child: const Text("New here? Create an account", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
