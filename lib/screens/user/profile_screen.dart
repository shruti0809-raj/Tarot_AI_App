// screens/profile/profile_screen.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();

  DateTime? _dob;
  File? _selectedImage;

  bool _loading = true;
  String? _error;
  bool _deleting = false;

  // NEW: guard to avoid double-routing
  bool _routingOut = false;

  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    // If auth becomes null (after delete/sign-out), always go to Welcome
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (!mounted || _routingOut) return;
      if (u == null) {
        _goWelcome();
      }
    });

    _loadProfile();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // Centralized, safe routing to the Welcome screen with stack reset
  void _goWelcome() {
    if (!mounted) return;
    _routingOut = true;

    // Close any dialogs that might still be open
    Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

    // Try '/welcome' first; if it doesn't exist, fall back to '/'
    bool pushed = false;
    try {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/welcome', (route) => false);
      pushed = true;
    } catch (_) {}

    if (!pushed) {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = "Not signed in.";
      });
      return;
    }

    try {
      // Firestore profile (name/dob)
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data();
      if (data != null) {
        _nameController.text = (data['name'] ?? '').toString();
        final dobStr = (data['dob'] ?? '').toString();
        if (dobStr.isNotEmpty) _dob = DateTime.tryParse(dobStr);
      }

      // Local profile image
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('profile_image_path_${user.uid}');
      if (path != null && File(path).existsSync()) {
        _selectedImage = File(path);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_${user.uid}.jpg');
      await file.writeAsBytes(bytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path_${user.uid}', file.path);
      await prefs.setBool('profile_image_updated_${user.uid}', true);

      setState(() => _selectedImage = file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _updateProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = "Not signed in.");
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty || _dob == null) {
      setState(() => _error = "Please enter name and date of birth.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'dob': _dob!.toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );
      setState(() => _error = null);
    } on FirebaseException catch (e) {
      setState(() => _error = e.message ?? "Failed to update profile.");
    } catch (e) {
      setState(() => _error = "Unexpected error: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete account: call ONLY the Cloud Function (server does all deletions)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _confirmAndDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently delete your account, profile, and phone index. "
          "This action cannot be undone. Do you want to continue?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _deleting = true);

    // Blocking loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('deleteAccount');
      await callable.call().timeout(const Duration(seconds: 60));
    } catch (e) {
      // If CF fails, we still sign out and route to welcome (server should handle deletion best-effort)
      debugPrint('deleteAccount call failed: $e');
    }

    // Best-effort local cleanup (avatar cache)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        final path = prefs.getString('profile_image_path_${user.uid}');
        if (path != null) {
          await prefs.remove('profile_image_path_${user.uid}');
          await prefs.remove('profile_image_updated_${user.uid}');
          final f = File(path);
          if (await f.exists()) {
            await f.delete();
          }
        }
      }
    } catch (_) {}

    // Sign out to clear session
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (!mounted) return;

    // Close loader
    Navigator.of(context, rootNavigator: true).maybePop();
    setState(() => _deleting = false);

    // Route out immediately (auth listener will also route if signOut triggers later)
    _goWelcome();

    // Optional toast (after we’ve routed)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your account is being deleted.")),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : const AssetImage('assets/profile_placeholder.png')
                                  as ImageProvider,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: const CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 18,
                              child: Icon(Icons.edit, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Name"),
                  ),
                  const SizedBox(height: 16),

                  // DOB
                  GestureDetector(
                    onTap: _pickDob,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "Date of Birth"),
                      child: Text(_dob != null
                          ? DateFormat('dd MMM yyyy').format(_dob!)
                          : 'Select DOB'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text("Save Changes"),
                  ),
                  const SizedBox(height: 16),

                  // Delete account
                  TextButton(
                    onPressed: _deleting ? null : _confirmAndDeleteAccount,
                    child: _deleting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
