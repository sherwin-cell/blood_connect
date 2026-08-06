import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Explicitly configure GoogleSignIn with the Web Client ID from google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '394558242984-d2unmof80o47siujfrkimcu6ljrlin5k.apps.googleusercontent.com',
  );

  // --- Email/password ---

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _googleSignIn.signOut(); // Clean up Google session
    await _auth.signOut();
  }

  // --- Passwordless (magic link) sign-in ---

  static const String _magicLinkUrl =
      'https://blood-connect-12ac2.firebaseapp.com/finishSignIn';

  ActionCodeSettings get _actionCodeSettings => ActionCodeSettings(
    url: _magicLinkUrl,
    handleCodeInApp: true,
    androidPackageName: 'com.example.blood_connect',
    androidInstallApp: true,
    androidMinimumVersion: '1',
    iOSBundleId: 'com.example.bloodConnect',
  );

  Future<void> sendPasswordlessLink(String email) async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: _actionCodeSettings,
    );
  }

  bool isSignInWithEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    return await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
  }

  // --- Google sign-in ---

  /// Signs in with Google. Returns null if the user cancels the picker.
  /// Safely verifies Firestore user document existence so CompleteProfileScreen
  /// triggers accurately for new or partially set up users.
  Future<UserCredential?> signInWithGoogle() async {
    // Clear old cached session so account selection prompt always appears
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      // Check if the user document exists in Firestore directly
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _firestoreService.createUserProfile(
          uid: user.uid,
          fullname: user.displayName ?? 'New User',
          email: user.email ?? '',
        );
      }
    }

    return userCredential;
  }

  // --- Shared error-message mapping ---

  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right. Please check and try again.';
      case 'user-not-found':
        return 'No account found with that email. Would you like to register instead?';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Email or password is incorrect. Please check and try again.';
      case 'email-already-in-use':
        return 'An account already exists with that email. Try logging in instead.';
      case 'weak-password':
        return 'That password is too weak. Please choose a stronger one.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'expired-action-code':
        return 'This sign-in link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This sign-in link is invalid or has already been used.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
