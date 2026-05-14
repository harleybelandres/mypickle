import '../models/user_model.dart';
import 'local_auth_service.dart';
import 'local_db_service.dart';

/// Local (non-Firebase) auth replacement for the app.
class AuthService {
  AuthService({LocalAuthService? authService, LocalDbService? db})
      : _auth =
            authService ?? LocalAuthService(db: db ?? LocalDbService.instance);

  final LocalAuthService _auth;

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _auth.signUp(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _auth.login(email: email, password: password);
  }

  UserModel? getCurrentUser() => _auth.getCurrentUser();

  Future<UserModel?> getUserRole({String? userId}) async {
    return _auth.getUserRole(userId: userId);
  }

  Future<void> logout() async {
    await _auth.logout();
  }
}

