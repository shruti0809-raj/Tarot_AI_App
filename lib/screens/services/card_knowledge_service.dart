import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Loads and serves card meanings from assets/card_meanings.json
/// and provides helpers to ground LLM prompts with allowed card names
/// and concise per-card meanings.
class CardKnowledgeService {
  CardKnowledgeService._();
  static final CardKnowledgeService instance = CardKnowledgeService._();

  Map<String, dynamic>? _raw; // full JSON
  bool _loading = false;

  /// Ensure meanings JSON is loaded once.
  Future<void> ensureLoaded() async {
    if (_raw != null || _loading) return;
    _loading = true;
    try {
      final txt = await rootBundle.loadString('assets/card_meanings.json');
      final jsonMap = jsonDecode(txt);
      if (jsonMap is Map<String, dynamic>) {
        _raw = jsonMap;
      } else {
        _raw = <String, dynamic>{};
      }
    } catch (_) {
      _raw = <String, dynamic>{};
    } finally {
      _loading = false;
    }
  }

  /// Convert a filename like "the_high_priestess.png" or raw label into title case display name.
  String beautifyName(String raw) {
    var s = raw;
    // If path-like, keep last segment
    if (s.contains('/')) s = s.split('/').last;
    // Strip extension
    final dot = s.lastIndexOf('.');
    if (dot != -1) s = s.substring(0, dot);
    // Replace separators with space
    s = s.replaceAll(RegExp(r'[_-]+'), ' ');
    // Collapse spaces
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Basic title case
    if (s.isEmpty) return s;
    s = s.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');
    return s;
  }

  /// Normalize a card key for lookups: lowercase alnum only.
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Attempt to fetch a meaning for a given deck & human display name.
  /// Supports both nested maps and flat maps under each deck.
  String _lookupMeaning(String deck, String displayName) {
    final data = _raw?[deck] ?? _raw?[deck.toLowerCase()] ?? _raw?[deck[0].toUpperCase() + deck.substring(1).toLowerCase()];
    if (data == null) return '';

    final normTarget = _norm(displayName);

    if (data is Map) {
      // Try direct, case-insensitive key matches
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final val = entry.value?.toString() ?? '';
        if (_norm(key) == normTarget) return val;
      }
      // Some JSONs store arrays of {name, meaning}
      if (data['cards'] is List) {
        for (final item in (data['cards'] as List)) {
          final name = item['name']?.toString() ?? '';
          final val = item['meaning']?.toString() ?? '';
          if (_norm(name) == normTarget) return val;
        }
      }
    }
    return '';
  }

  /// Clamp meanings to keep prompts concise.
  String _trimMeaning(String text, {int maxChars = 500}) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    // try cut on sentence boundary
    final idx = t.lastIndexOf('.', maxChars);
    return (idx > 120 ? t.substring(0, idx + 1) : t.substring(0, maxChars)).trim();
  }

  /// Build the per-deck grounding payload: { deck: [{name, meaning}] }
  Future<Map<String, List<Map<String, String>>>> getGroundingFor(
    Map<String, List<String>> selectedCardsByDeck,
  ) async {
    await ensureLoaded();
    final out = <String, List<Map<String, String>>>{};

    selectedCardsByDeck.forEach((deck, list) {
      final deckKey = deck.toLowerCase();
      final entries = <Map<String, String>>[];
      for (final raw in list) {
        final display = beautifyName(raw);
        final meaning = _trimMeaning(_lookupMeaning(deckKey, display));
        entries.add({
          'name': display,
          'meaning': meaning,
        });
      }
      out[deckKey] = entries;
    });
    return out;
  }

  /// Return the set of allowed card display names for all selected cards.
  Future<Set<String>> getAllowedNamesFor(
    Map<String, List<String>> selectedCardsByDeck,
  ) async {
    await ensureLoaded();
    final names = <String>{};
    selectedCardsByDeck.forEach((_, list) {
      for (final raw in list) {
        names.add(beautifyName(raw));
      }
    });
    return names;
  }
}