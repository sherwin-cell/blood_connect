import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  /// Web client ID used as [serverClientId] so Google returns an ID token
  /// suitable for Firebase Auth.
  static const String _serverClientId =
      '394558242984-d2unmof80o47siujfrkimcu6ljrlin5k.apps.googleusercontent.com';

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize(serverClientId: _serverClientId);
      _isInitialized = true;
    }
  }

  // --- Email/Password Auth ---

  /// Creates a Firebase Auth account. Call ONLY from the Register flow.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Authenticates an existing Firebase Auth account. Never creates a user.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  Future<void> logout() async {
    await _ensureInitialized();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore if Google session was never established
    }
    await _auth.signOut();
  }

  // --- Google Sign-In (standard Firebase credential flow) ---

  /// Signs in with Google via Firebase Auth.
  ///
  /// Firebase creates the Auth user on first Google sign-in and reuses it
  /// on subsequent sign-ins. A Firestore profile stub is created only when
  /// missing so ProfileGate can route to Complete Profile.
  ///
  /// Returns `null` when the user cancels the Google picker.
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();

    try {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore if no prior Google session
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final String? idToken = googleUser.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Authentication failed. Please try again.',
        );
      }

      String? accessToken;
      try {
        final authorization = await googleUser.authorizationClient
            .authorizationForScopes(const <String>['email', 'profile']);
        accessToken = authorization?.accessToken;
      } catch (_) {
        // ID token alone is sufficient for Firebase Auth
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        await _firestoreService.createUserProfile(
          uid: user.uid,
          fullname: user.displayName,
          email: user.email ?? googleUser.email,
        );
      }

      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted ||
          e.code == GoogleSignInExceptionCode.uiUnavailable) {
        return null;
      }
      throw FirebaseAuthException(
        code: 'network-request-failed',
        message: 'Google Sign-In failed. Please try again.',
      );
    }
  }

  // --- Shared Error Message Mapping ---

  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'weak-password':
        return 'That password is too weak. Please choose a stronger one.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
