// screens/final_reading/final_reading_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:divine_guidance_app/screens/services/reading_balance_service.dart';

class FinalReadingScreen extends StatefulWidget {
  final Map<String, List<String>> selectedCardsByDeck;
  const FinalReadingScreen({Key? key, required this.selectedCardsByDeck}) : super(key: key);

  @override
  State<FinalReadingScreen> createState() => _FinalReadingScreenState();
}

class _FinalReadingScreenState extends State<FinalReadingScreen> {
  static const String kFunctionUrl = 'https://generatetarotreading-gaxikumrxa-uc.a.run.app';
  static const List<String> _deckOrder = ['tarot', 'oracle', 'messages', 'affirmations', 'charms'];

  String? _sessionId;
  Map<String, List<String>> _cards = {};
  bool _argsLoaded = false;
  bool _started = false;
  bool _creditDeducted = false;

  Map<String, String> deckReadings = {};
  String? heading;
  String? intro;
  String? summary;

  String _readingType = 'general';
  String? _userQuestion;
  String? _zodiacSign;
  String _screenTitle = 'Your Final Reading';

  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
  }

  // ---- helpers: normalization ----
  String _normalizeDeckKey(String k) {
    final rk = k.toLowerCase();
    if (rk == 'affirmaations' || rk == 'affirmation') return 'affirmations';
    return rk;
  }

  String _fixExt(String f) {
    var s = f.split('/').last;
    s = s.replaceAll('.ppng', '.png');
    s = s.replaceAll('.png.png', '.png');
    return s;
  }

  Map<String, String> _normalizeReadingTypeAndZodiac(String raw) {
    final s = (raw).toLowerCase();
    const signs = [
      'aries','taurus','gemini','cancer','leo','virgo','libra','scorpio','sagittarius','capricorn','aquarius','pisces'
    ];
    String type = 'general';
    String zodiac = '';
    if (s.contains('love')) type = 'love';
    else if (s.contains('career')) type = 'career';
    else if (s.contains('angel')) type = 'angel';
    else if (s.contains('full moon') || s.contains('fullmoon')) type = 'fullmoon';
    else if (s.contains('personal')) type = 'personal';
    if (s.contains('sun') || s.contains('sunsign') || s.contains('zodiac')) {
      type = 'sunsign';
      for (final z in signs) { if (s.contains(z)) { zodiac = z; break; } }
    }
    return {'type': type, 'zodiac': zodiac};
  }

  void _loadArgsOnce(BuildContext context) {
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _sessionId = args['sessionId']?.toString();

      final fromTitle = args['title']?.toString();
      final fromType  = args['readingType']?.toString(); // canonical if present
      _screenTitle = fromTitle ?? _screenTitle;

      // --- Prefer canonical readingType when provided ---
      if (fromType != null && fromType.isNotEmpty) {
        _readingType = fromType.toLowerCase();
      } else {
        final norm = _normalizeReadingTypeAndZodiac(fromTitle ?? _readingType);
        _readingType = norm['type']!;
      }

      // zodiac: explicit arg wins; else try to infer from title if sunsign
      final zArg = args['zodiacSign']?.toString();
      if (zArg != null && zArg.isNotEmpty) {
        _zodiacSign = zArg;
      } else {
        final zNorm = _normalizeReadingTypeAndZodiac(fromTitle ?? '');
        _zodiacSign = zNorm['zodiac'];
      }

      // normalize cards
      final passedCards = args['cards'];
      if (passedCards is Map) {
        final normalized = <String, List<String>>{};
        passedCards.forEach((k, v) {
          if (v is List) {
            final dk = _normalizeDeckKey(k.toString());
            normalized[dk] = v.map((e) => _fixExt(e.toString())).toList();
          }
        });
        _cards = normalized;
      }

      // accept both keys; prefer 'userQuestion'
      _userQuestion = (args['userQuestion'] ?? args['personalQuestion'])?.toString();
    }

    if (_cards.isEmpty) {
      _cards = widget.selectedCardsByDeck.map((k, v) =>
        MapEntry(_normalizeDeckKey(k), v.map(_fixExt).toList()));
    }

    _sessionId ??= '${DateTime.now().millisecondsSinceEpoch}';
    _argsLoaded = true;
  }

  // ---- subject + fallbacks ----
  String _detectSubjectAlias() {
    final q = (_userQuestion ?? '').toLowerCase();
    if (q.contains('my daughter')) return 'your daughter';
    if (q.contains('my son')) return 'your son';
    if (q.contains('my marriage')) return 'your marriage';
    if (q.contains('marriage')) return 'your marriage';
    if (q.contains('relationship')) return 'your relationship';
    return 'your situation';
  }

  String _fallbackForDeck(String deck) {
    final subject = _detectSubjectAlias();
    switch (deck) {
      case 'messages':
        return [
          'You are not alone in this.',
          'Trust small steady moves; they compound quietly.',
          'Remember: clarity grows when you speak simply and listen fully.',
          'Set one gentle boundary and keep it.',
          'Notice one sign of progress today, however small.',
          'If anxiety spikes, pause, breathe, and return to your next small step.',
        ].join(' ');
      case 'affirmations':
        if (subject == 'your marriage') {
          return [
            'I speak gently and honestly.',
            'I listen without defensiveness.',
            'I show love through steady daily actions.',
            'I keep promises I can keep.',
            'I release worst-case stories.',
            'I trust our marriage to strengthen with steady effort.',
          ].join('\n');
        } else if (subject == 'your daughter') {
          return [
            'I trust my daughter’s path.',
            'I offer support without control.',
            'I speak hope when fear rises.',
            'I notice small wins and name them.',
            'I ask for help when needed.',
            'I believe in her resilience.',
          ].join('\n');
        } else {
          return [
            'I choose calm over panic.',
            'I take one small step today.',
            'I communicate clearly and kindly.',
            'I honor my needs and boundaries.',
            'I release what I cannot control.',
            'I trust steady effort to create change.',
          ].join('\n');
        }
      default:
        return 'This section supports the main answer with a simple next step.';
    }
  }

  // ---- HTTP ----
  Future<void> _generateReadings() async {
    setState(() {
      loading = true;
      failed = false;
      deckReadings.clear();
      heading = null;
      intro = null;
      summary = null;
    });

    final filenamesOnly = <String, List<String>>{
      for (final e in _cards.entries)
        _normalizeDeckKey(e.key): e.value
            .map((c) => _fixExt(c))
            .map((c) => c.split('/').last)
            .toList(),
    };

    final nonEmptySelected = <String, List<String>>{
      for (final e in filenamesOnly.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };

    final hasAny = nonEmptySelected.values.any((lst) => lst.isNotEmpty);
    if (!hasAny) {
      setState(() { loading = false; failed = true; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cards to read for this type.')),
      );
      return;
    }

    final uri = Uri.parse(kFunctionUrl);

    final payload = <String, dynamic>{
      'readingType': _readingType,
      'selectedCards': nonEmptySelected,
      if (_readingType == 'personal' && (_userQuestion?.trim().isNotEmpty ?? false))
        'userQuestion': _userQuestion!.trim(),
      if (_readingType == 'sunsign' && (_zodiacSign?.trim().isNotEmpty ?? false))
        'zodiacSign': _zodiacSign!.trim(),
    };

    try {
      debugPrint('⤴️ POST $kFunctionUrl');
      debugPrint('⤴️ payload: ${jsonEncode(payload)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      debugPrint('⬇️ status: ${response.statusCode}');
      debugPrint('⬇️ body: ${response.body}');

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final byDeck = (body['by_deck'] as Map?)?.cast<String, dynamic>();
        if (byDeck != null && byDeck.isNotEmpty) {
          final m = <String, String>{};
          byDeck.forEach((k, v) => m[_normalizeDeckKey(k.toString())] = _sanitizeText((v ?? '').toString()));

          if (_readingType.toLowerCase() == 'personal') {
            for (final d in _presentDecksInOrder()) {
              final missingOrEmpty = !(m.containsKey(d)) || (m[d]?.trim().isEmpty ?? true);
              if (missingOrEmpty && (d == 'messages' || d == 'affirmations')) {
                m[d] = _fallbackForDeck(d);
              }
            }
          }

          setState(() {
            deckReadings = m;
            heading = _sanitizeText((body['heading'] ?? '').toString());
            intro   = _sanitizeText((body['intro']   ?? '').toString());
            summary = _sanitizeText((body['summary'] ?? '').toString());
            loading = false;
            failed  = false;
          });
          await _onSuccessfulReading();
          return;
        }

        final reply = _sanitizeText((body['reply'] ?? '').toString());
        setState(() {
          summary = reply.isNotEmpty ? reply : null;
          heading = _sanitizeText((body['heading'] ?? '').toString());
          intro   = _sanitizeText((body['intro']   ?? '').toString());
          loading = false;
          failed = reply.isEmpty;
        });
        if (!failed) await _onSuccessfulReading();
      } else {
        setState(() { loading = false; failed = true; });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reading failed (${response.statusCode}). ${response.body}')),
        );
      }
    } catch (e) {
      setState(() { loading = false; failed = true; });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _onSuccessfulReading() async {
    if (!_creditDeducted) {
      try {
        await ReadingBalanceService().deductReading();
        _creditDeducted = true;
      } catch (e) {
        debugPrint('Deduct failed: $e');
      }
    }
    // NOTE: Do NOT auto-save here. Only mark session; saving happens when user taps "Save Reading".
    await _markSessionCompleted();
  }

  String _sanitizeText(String s) {
    if (s.isEmpty) return s;
    s = s.replaceAll('**', '').replaceAll('*', '');
    s = s.replaceAll(RegExp(r'^[#>\-]+\s*', multiLine: true), '');
    s = s.replaceAll('\r', '');
    s = s.replaceAll(RegExp(' +'), ' ');
    s = s.replaceAll(RegExp('\n{3,}'), '\n\n');
    return s.trim();
  }

  Future<void> _markSessionCompleted() async {
    if (_sessionId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final sessionRef = userRef.collection('readingSessions').doc(_sessionId);

    try {
      await sessionRef.set({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'readingType': _readingType,
        if (_userQuestion != null) 'userQuestion': _userQuestion,
        if (_zodiacSign != null) 'zodiacSign': _zodiacSign,
      }, SetOptions(merge: true));

      await userRef.update({
        'lastReadings': FieldValue.arrayUnion([DateTime.now().toIso8601String()]),
      });
    } catch (e) {
      debugPrint('Failed to mark session completed: $e');
    }
  }

  // ---- Firestore save (used ONLY when user taps Save Reading) ----
  Future<void> _saveReadingToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docId = _sessionId ?? FirebaseFirestore.instance.collection('_').doc().id;
    final readingRef = userRef.collection('savedReadings').doc(docId);

    try {
      await readingRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'readingType': _readingType,
        'cards': _cards,
        'byDeck': deckReadings,
        'heading': heading,
        'intro': intro,
        'summary': summary,
        'question': _userQuestion,
        'zodiacSign': _zodiacSign,
        'sessionId': _sessionId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save reading: $e');
    }
  }

  // ---- Paths / PDF helpers ----
  Future<Directory> _getUserPdfDir() async {
    final base = await getApplicationDocumentsDirectory();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '_anonymous';
    final dir = Directory('${base.path}/saved_readings/$uid');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // deterministic local PDF path for this session (prevents duplicates)
  Future<String> _pdfPathForSession() async {
    final dir = await _getUserPdfDir();
    final id = _sessionId ?? 'session';
    return '${dir.path}/reading_${id}.pdf';
  }

  String _fileSafeType() {
    final z = (_readingType == 'sunsign' && (_zodiacSign?.isNotEmpty ?? false)) ? '_${_zodiacSign!}' : '';
    return '${_readingType.toLowerCase()}$z';
  }

  // Build the PDF and write to disk. If forcePath is provided, write exactly there (idempotent save).
  Future<File?> _buildPdfFile({String? forcePath}) async {
    final pdf = pw.Document();
    final readableDate = DateFormat('dd MMM yyyy – hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        maxPages: 10,
        build: (context) => [
          pw.Text('Tarot Reading – $readableDate', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if ((heading ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(heading!, style: pw.TextStyle(fontSize: 14)),
          ],
          if ((intro ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(intro!, style: const pw.TextStyle(fontSize: 12)),
          ],
          for (final deck in _deckOrder)
            if ((_cards[deck]?.isNotEmpty ?? false) && (deckReadings[deck]?.isNotEmpty ?? false)) ...[
              pw.SizedBox(height: 12),
              pw.Text('${deck[0].toUpperCase()}${deck.substring(1)}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(deckReadings[deck]!, style: const pw.TextStyle(fontSize: 12)),
            ],
          if ((summary ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(summary!, style: const pw.TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );

    try {
      final bytes = await pdf.save();
      if (forcePath != null) {
        final file = File(forcePath);
        await file.writeAsBytes(bytes, flush: true);
        return file;
      }

      // default: timestamped name (useful for share flow)
      final userDir = await _getUserPdfDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safeType = _fileSafeType();
      final file = File('${userDir.path}/reading_${safeType}_$ts.pdf');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('PDF write error: $e');
      return null;
    }
  }

  // ---- SAVE READING (idempotent) ----
  Future<void> _saveReading() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // deterministic docId == sessionId, deterministic local file path
    final docId = _sessionId ?? FirebaseFirestore.instance.collection('_').doc().id;

    // 1) Check Firestore duplicate
    final readingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedReadings')
        .doc(docId);

    final already = await readingRef.get();
    if (already.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This reading has already been saved.')),
      );
      return;
    }

    // 2) Check local duplicate
    final targetPath = await _pdfPathForSession();
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      if (!mounted) return;
      // To keep FS and local consistent, also ensure Firestore doc exists (in case user deleted cloud copy)
      try {
        await _saveReadingToFirestore();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This reading has already been saved.')),
      );
      return;
    }

    // 3) Build/write PDF to deterministic path
    final pdf = await _buildPdfFile(forcePath: targetPath);
    if (!mounted) return;
    if (pdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save reading')),
      );
      return;
    }

    // 4) Save Firestore doc
    try {
      await _saveReadingToFirestore();
    } catch (e) {
      debugPrint('Failed to write Firestore doc for saved reading: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading saved to account and device')),
    );
  }

  // ---- SHARE READING (fresh timestamped PDF) ----
  Future<void> _sharePdf() async {
    final file = await _buildPdfFile(); // timestamped (not the idempotent one)
    if (file == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create PDF')));
      return;
    }
    await Share.shareXFiles([XFile(file.path)], text: 'My tarot reading');
  }

  // ---- UI helpers ----
  Widget _deckCardsScroller(String deck) {
    final cards = _cards[deck] ?? [];
    if (cards.isEmpty) return const SizedBox();
    return SizedBox(
      height: 135,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/cards/${deck.toLowerCase()}/${cards[i].split('/').last}',
            width: 76, height: 115, fit: BoxFit.cover,
          ),
        ),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: cards.length,
      ),
    );
  }

  Widget _deckSection(String deck) {
    final hasCards = (_cards[deck]?.isNotEmpty ?? false);
    final text = deckReadings[deck] ?? '';
    if (!hasCards || text.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('${deck[0].toUpperCase()}${deck.substring(1)}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _deckCardsScroller(deck),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
    );
  }

  List<String> _presentDecksInOrder() {
    return _deckOrder.where((d) => (_cards[d]?.isNotEmpty ?? false)).toList();
  }

  @override
  Widget build(BuildContext context) {
    _loadArgsOnce(context);
    if (!_started && _argsLoaded) {
      _started = true;
      Future.microtask(() => _generateReadings());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Save Reading',
            onPressed: loading || failed ? null : _saveReading,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share Reading',
            onPressed: loading || failed ? null : _sharePdf,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((heading ?? '').isNotEmpty)
                      Text(heading!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    if ((intro ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(intro!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Reading Date: ${DateFormat('dd MMM yyyy – hh:mm a').format(DateTime.now())}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    for (final deck in _presentDecksInOrder()) _deckSection(deck),
                    if ((summary ?? '').isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      const Text('Summary', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(summary!, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    ],
                    if (failed) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: _generateReadings,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],

                    // Bottom Buttons (match top icons)
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: loading || failed ? null : _saveReading,
                      icon: const Icon(Icons.save_alt),
                      label: const Text("Save Reading"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: loading || failed ? null : _sharePdf,
                      icon: const Icon(Icons.ios_share),
                      label: const Text("Share Reading"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
