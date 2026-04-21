// lib/screens/user/saved_readings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

class SavedReadingsScreen extends StatefulWidget {
  const SavedReadingsScreen({super.key});

  @override
  State<SavedReadingsScreen> createState() => _SavedReadingsScreenState();
}

class _SavedReadingsScreenState extends State<SavedReadingsScreen> {
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_uid!)
        .collection('savedReadings')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Local file path that matches FinalReadingScreen's `_pdfPathForSession()`
  Future<File> _localFileForDocId(String docId) async {
    final dir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${dir.path}/saved_readings/$_uid');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    // Final screen uses: reading_<sessionId>.pdf
    return File('${userDir.path}/reading_${docId}.pdf');
  }

  /// Display-friendly timestamp. We prefer 'createdAt' if present,
  /// otherwise we try to interpret docId as millisecondsSinceEpoch.
  DateTime _deriveDate(Map<String, dynamic> data, String docId) {
    final ts = data['createdAt'];
    if (ts is Timestamp) return ts.toDate();

    // Fallback: sessionId is used as docId and is a millis timestamp in your flow
    final ms = int.tryParse(docId);
    if (ms != null) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    // Last resort: now
    return DateTime.now();
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy – hh:mm a').format(dt);
  }

  Future<void> _openReading(Map<String, dynamic> data, String docId) async {
    try {
      final f = await _localFileForDocId(docId);
      if (await f.exists()) {
        await OpenFilex.open(f.path);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "PDF not found on this device. "
            "If you saved it on another device, re-save the reading there to view locally.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open PDF: $e')),
      );
    }
  }

  Future<void> _deleteReading(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Reading?"),
        content: const Text("This will remove the saved reading from this device and your account."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Delete local file (if present)
      final f = await _localFileForDocId(docId);
      if (await f.exists()) {
        await f.delete();
      }

      // Delete Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid!)
          .collection('savedReadings')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Saved Readings"),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text("Please sign in to view saved readings."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Readings"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("No saved readings yet."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final when = _deriveDate(data, d.id);
              final pretty = _formatDateTime(when);

              // Show document name as date/time of the session
              final displayName = pretty;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                  title: Text(displayName),
                  subtitle: Text("Saved on $pretty"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteReading(d.id),
                  ),
                  onTap: () => _openReading(data, d.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
