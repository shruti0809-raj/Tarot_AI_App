import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in helper with "link-if-anonymous" support.
///
/// Usage from UI:
///   final cred = await GoogleLoginHelper.signInWithGoogleAndLinkIfAnon();
///   if (cred?.user != null) { /* route to home/onboarding */ }
class GoogleLoginHelper {
  GoogleLoginHelper._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Signs in with Google and, if there's an anonymous Firebase user,
  /// links the Google credential to that user instead of creating a new one.
  /// Returns null if the user cancels the Google account picker.
  static Future<UserCredential?> signInWithGoogleAndLinkIfAnon({
    bool forceAccountPicker = false,
    String? serverClientId,
  }) async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: serverClientId,
      );

      // Force account chooser if requested
      if (forceAccountPicker) {
        try { await googleSignIn.signOut(); } catch (_) {}
      }

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _signInOrLink(credential);
    } catch (e, st) {
      // Keep prints to help debug SHA issues / OAuth configuration while testing.
      // Consider swapping to a logging package for production.
      // ignore: avoid_print
      print('❌ Google Sign-In failed: $e');
      // ignore: avoid_print
      print('🔍 Stacktrace:\n$st');
      rethrow;
    }
  }

  /// Legacy method kept for backwards-compatibility with old call sites.
  /// It does a plain sign-in (no link-if-anon).
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: const ['email']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e, st) {
      // ignore: avoid_print
      print('❌ Google Sign-In failed: $e');
      // ignore: avoid_print
      print('🔍 Stacktrace:\n$st');
      return null;
    }
  }

  /// Optional: get the Google AuthCredential only (you can handle sign-in/linking yourself).
  static Future<AuthCredential?> getGoogleCredential({
    bool forceAccountPicker = false,
    String? serverClientId,
  }) async {
    final googleSignIn = GoogleSignIn(scopes: const ['email'], serverClientId: serverClientId);
    if (forceAccountPicker) {
      try { await googleSignIn.signOut(); } catch (_) {}
    }
    final GoogleSignInAccount? account = await googleSignIn.signIn();
    if (account == null) return null;
    final GoogleSignInAuthentication tokens = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );
  }

  /// Internal: link to anon user if present; otherwise sign in.
  static Future<UserCredential> _signInOrLink(AuthCredential credential) async {
    final current = _auth.currentUser;
    try {
      if (current != null && current.isAnonymous) {
        return await current.linkWithCredential(credential);
      }
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // If credential already linked elsewhere, fall back to sign-in.
      if (e.code == 'credential-already-in-use' ||
          e.code == 'account-exists-with-different-credential') {
        return await _auth.signInWithCredential(credential);
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
  }
}
