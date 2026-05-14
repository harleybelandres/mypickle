import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_model.dart';
import 'local_db_service.dart';

/// Local auth replacement for FirebaseAuth.
///
/// - Stores users in Hive
/// - Stores password hashes in Hive (separate box)
/// - Stores current session userId in Hive
class LocalAuthService {
  LocalAuthService({required this.db});

  final LocalDbService db;

  static const _authBox = 'auth';
  static const _passwordHashKey = 'passwordHash';
  static const _saltKey = 'salt';

  Future<void> _ensureBoxes() async {
    await Hive.openBox<Map>(_authBox);
  }

  Box<Map> get _auth => Hive.box<Map>(_authBox);

  String _hashPassword({required String password, required String salt}) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> _newSalt() async {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _ensureBoxes();

    final existing = await db.getUserByEmail(email);
    if (existing != null) {
      throw Exception('Email already in use');
    }

    // Use email hash as uid for determinism.
    final uid = sha256.convert(utf8.encode(email)).toString();

    final salt = await _newSalt();
    final passwordHash = _hashPassword(password: password, salt: salt);

    final user = UserModel(
      id: uid,
      name: name,
      email: email,
      role: role,
    );

    await db.upsertUser(user: user);
    await _auth.put(uid, {_saltKey: salt, _passwordHashKey: passwordHash});
    await db.setCurrentUserId(uid);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _ensureBoxes();

    final user = await db.getUserByEmail(email);
    if (user == null) throw Exception('No account found for that email');

    final authData = _auth.get(user.id);
    if (authData == null) throw Exception('Account has no auth data');

    final map = Map<String, dynamic>.from(authData);
    final salt = map[_saltKey] as String?;
    final expectedHash = map[_passwordHashKey] as String?;

    if (salt == null || expectedHash == null) {
      throw Exception('Account has invalid auth data');
    }

    final actual = _hashPassword(password: password, salt: salt);
    if (actual != expectedHash) {
      throw Exception('Invalid password');
    }

    await db.setCurrentUserId(user.id);
  }

  UserModel? getCurrentUser() {
    final uid = db.getCurrentUserId();
    if (uid == null) return null;
    return db.getUserById(uid);
  }

  Future<UserModel?> getUserRole({String? userId}) async {
    final uid = userId ?? db.getCurrentUserId();
    if (uid == null) return null;
    return db.getUserById(uid);
  }

  Future<void> logout() async {
    await db.setCurrentUserId(null);
  }
}

