import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // --- Email/password (kept for RegisterScreen, if still used there) ---

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
    await _auth.signOut();
  }

  // --- Passwordless (magic link) sign-in ---

  /// TODO: Replace this URL with your actual Firebase Hosting domain
  /// (Firebase Console -> Authentication -> Settings -> Authorized domains,
  /// and Authentication -> Templates -> Email link sign-in). It must also
  /// be added as an authorized domain in the Firebase Console, and your
  /// app_links / deep-link setup (Android intent-filter, iOS associated
  /// domain) must point at this same URL scheme, or the magic link won't
  /// open your app.
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

  /// Sends a magic sign-in link to [email]. The caller (LoginScreen)
  /// is responsible for saving the email locally (e.g. SharedPreferences)
  /// so it can be reused when the link is tapped later.
  Future<void> sendPasswordlessLink(String email) async {
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: _actionCodeSettings,
    );
  }

  /// True if [link] is a valid Firebase email sign-in link.
  bool isSignInWithEmailLink(String link) {
    return _auth.isSignInWithEmailLink(link);
  }

  /// Completes sign-in using the emailed magic link.
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    return await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
  }

  // --- Google sign-in ---

  /// Signs in with Google. Returns null if the user cancels the picker.
  /// If this is a brand-new Firebase user, also creates their Firestore
  /// profile doc so CompleteProfileScreen / ProfileGate work correctly.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
      await _firestoreService.createUserProfile(
        uid: user.uid,
        fullname: user.displayName ?? 'New User',
        email: user.email ?? '',
      );
    }

    return userCredential;
  }

  // --- Shared error-message mapping ---

  /// Maps Firebase Auth error codes to clear, user-facing messages.
  /// Shared by LoginScreen, RegisterScreen, and anywhere else that
  /// catches a FirebaseAuthException.
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
