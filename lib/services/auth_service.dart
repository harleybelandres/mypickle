import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import '../models/user_model.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // In-memory cache so getCurrentUser() stays synchronous
  UserModel? _cachedUser;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final user = UserModel(id: uid, name: name, email: email, role: role);
    await _db.collection('users').doc(uid).set(user.toMap());
    _cachedUser = user;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    _cachedUser = doc.exists ? UserModel.fromMap(doc.data()!) : null;

    if (_cachedUser != null) {
      await FirebaseAnalytics.instance.setUserProperty(
        name: 'user_role',
        value: _cachedUser!.role,
      );

      await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
    }
  }

  Future<void> logout() async {
    _cachedUser = null;
    await _auth.signOut();
  }

  /// Synchronous — returns cached UserModel (populated after login/signUp).
  UserModel? getCurrentUser() => _cachedUser;

  Future<UserModel?> getUserRole({String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }

  /// Call on app start to restore session if user was previously logged in.
  Future<void> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      _cachedUser = null;
      return;
    }
    final doc = await _db.collection('users').doc(user.uid).get();
    _cachedUser = doc.exists ? UserModel.fromMap(doc.data()!) : null;
  }
}