import 'package:flutter/foundation.dart';
import 'preferences.dart';

class Session extends ChangeNotifier {
  static final Session _instance = Session._();
  Session._();
  static Session get instance => _instance;

  String? _userId;
  String? _userName;

  String? get userId => _userId;
  String? get userName => _userName;

  set userId(String? value) {
    _userId = value;
    notifyListeners();
  }

  set userName(String? value) {
    _userName = value;
    notifyListeners();
  }

  bool get isLoggedIn => _userId != null;

  String get avatarInitials {
    if (_userName == null || _userName!.isEmpty) return '?';
    final parts = _userName!.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  /// Load persisted session from SharedPreferences.
  Future<void> restore() async {
    final saved = await Preferences.loadSession();
    _userId = saved.userId;
    _userName = saved.userName;
    notifyListeners();
  }

  /// Persist session after login/register.
  Future<void> save() async {
    if (_userId != null && _userName != null) {
      await Preferences.saveSession(_userId!, _userName!);
    }
  }

  /// Clear in-memory state and persisted storage.
  Future<void> clear() async {
    _userId = null;
    _userName = null;
    notifyListeners();
    await Preferences.clearSession();
  }
}
