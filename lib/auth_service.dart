// auth_service.dart
// all the firebase auth calls live here: register, sign in, sign out, the
// auth state stream, and the error codes turned into readable text

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';

// all the firebase auth calls live in here
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser {
    return _auth.currentUser;
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges();
  }

  // register and save the user document at the same time
  Future<void> register(String email, String password, String firstName,
      String lastName) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    User? user = result.user;
    if (user == null) {
      throw Exception('registration did not return a user');
    }

    // so the board can show a name without another read
    await user.updateDisplayName('$firstName $lastName'.trim());

    // the user document, one per uid
    UserRecord record = UserRecord(
      uid: user.uid,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      role: 'student',
    );
    await _db.collection('users').doc(user.uid).set(record.toMap());
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// turn the firebase error codes into something readable
String friendlyAuthError(FirebaseAuthException e) {
  if (e.code == 'invalid-email') {
    return 'That email address does not look right.';
  } else if (e.code == 'user-not-found') {
    return 'No account with that email. Register first.';
  } else if (e.code == 'wrong-password' ||
      e.code == 'invalid-credential') {
    return 'Wrong email or password.';
  } else if (e.code == 'email-already-in-use') {
    return 'That email is already registered.';
  } else if (e.code == 'weak-password') {
    return 'Password needs at least 6 characters.';
  } else if (e.code == 'network-request-failed') {
    return 'No connection. Check your network and try again.';
  } else if (e.code == 'too-many-requests') {
    return 'Too many tries. Wait a minute and try again.';
  }
  return 'Sign in failed: ${e.message}';
}
