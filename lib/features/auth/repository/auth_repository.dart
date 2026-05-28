import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signInWithGoogle() async {
    // WEB
    if (kIsWeb) {
      GoogleAuthProvider provider = GoogleAuthProvider();

      final credential = await _auth.signInWithPopup(provider);
      await _saveUserProfile(credential.user);

      return credential;
    }

    // ANDROID / IOS
    final GoogleSignIn googleSignIn = GoogleSignIn();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      throw Exception('Google Sign-In cancelled');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await _auth.signInWithCredential(credential);

    await _saveUserProfile(userCredential.user);

    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
  }

  Future<void> _saveUserProfile(User? user) async {
    if (user == null) return;

    final email = user.email?.trim().toLowerCase() ?? '';
    final displayName = user.displayName?.trim() ?? 'User';

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': user.photoURL,
      'searchText': '$displayName $email'.toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}