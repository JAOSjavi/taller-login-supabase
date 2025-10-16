import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

class SessionService {
  static SessionService? _instance;
  static SessionService get instance => _instance ??= SessionService._();

  SessionService._();

  Usuario? _currentUser;
  Usuario? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> saveUser(Usuario usuario) async {
    _currentUser = usuario;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(usuario.toJson()));
  }

  Future<void> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        _currentUser = Usuario.fromJson(userData);
      }
    } catch (e) {
      print('Error al cargar usuario: $e');
    }
  }

  Future<void> clearUser() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }
}
