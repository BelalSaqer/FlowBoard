import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Streams the signed-in Firebase user, or null when signed out. This is
/// the source of truth [AuthGate] watches to decide between the sign-in
/// screen and the app.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// `signInWithPopup` is the web implementation for provider sign-in;
/// `signInWithProvider` (native flow) is the mobile equivalent but isn't
/// wired here since this app has only been built/run for web so far.
Future<void> signInWithGoogle(FirebaseAuth auth) async {
  await auth.signInWithPopup(GoogleAuthProvider());
}

Future<void> signInAsGuest(FirebaseAuth auth) async {
  await auth.signInAnonymously();
}

Future<void> signInWithEmail(FirebaseAuth auth, String email, String password) async {
  await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
}

Future<void> createAccountWithEmail(FirebaseAuth auth, String email, String password) async {
  await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
}

Future<void> sendPasswordReset(FirebaseAuth auth, String email) async {
  await auth.sendPasswordResetEmail(email: email.trim());
}

/// Maps Firebase Auth exceptions to short, user-facing copy instead of
/// showing raw exception text.
String friendlyAuthErrorMessage(Object error) {
  if (error is! FirebaseAuthException) return "Something went wrong. Please try again.";
  switch (error.code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'user-not-found':
      return 'No account found for that email.';
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists for that email.';
    case 'weak-password':
      return 'Choose a password with at least 6 characters.';
    case 'network-request-failed':
      return 'No network connection. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'popup-closed-by-user':
    case 'cancelled-popup-request':
      return 'Sign-in was cancelled.';
    case 'operation-not-allowed':
      return 'Email sign-in isn\'t enabled for this app yet.';
    default:
      return error.message ?? 'Something went wrong. Please try again.';
  }
}
