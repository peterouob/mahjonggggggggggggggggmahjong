import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/router/router.dart';
import '../../../core/storage/session.dart';
import '../../../data/services/broadcast_service.dart';
import '../../../mock/mock_data.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  bool _loading = false;
  bool _isRegister = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  String? _extractUserId(dynamic result) {
    if (result is! Map) return null;
    final user = result['user'];
    if (user is Map) {
      final nested = user['id'] as String? ??
          user['userId'] as String? ??
          user['user_id'] as String?;
      if (nested != null && nested.trim().isNotEmpty) return nested;
    }
    final topLevel = result['user_id'] as String? ??
        result['userId'] as String? ??
        result['id'] as String?;
    if (topLevel != null && topLevel.trim().isNotEmpty) return topLevel;
    return null;
  }

  String _extractUserName(dynamic result, String fallback) {
    if (result is! Map) return fallback;
    final user = result['user'];
    if (user is Map) {
      final nested = user['displayName'] as String? ??
          user['display_name'] as String? ??
          user['username'] as String? ??
          user['user_name'] as String?;
      if (nested != null && nested.trim().isNotEmpty) return nested;
    }
    return result['displayName'] as String? ??
        result['display_name'] as String? ??
        result['username'] as String? ??
        result['user_name'] as String? ??
        fallback;
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password')),
      );
      return;
    }

    if (_isRegister) {
      final email = _emailCtrl.text.trim();
      final displayName = _displayNameCtrl.text.trim();
      if (email.isEmpty || displayName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final path =
          _isRegister ? '/api/v1/auth/register' : '/api/v1/auth/login';

      final body = _isRegister
          ? {
              'username': username,
              'password': password,
              'email': _emailCtrl.text.trim(),
              'displayName': _displayNameCtrl.text.trim(),
            }
          : {
              'username': username,
              'password': password,
            };

      final result = await ApiClient.post(path, body);

      final userId = _extractUserId(result);
      final userName = _extractUserName(result, username);

      if (userId == null) {
        throw const FormatException('Missing user id in auth response');
      }

      Session.instance.userId = userId;
      Session.instance.userName = userName;
      await Session.instance.save();

      // Connect WebSocket and restore any active broadcast.
      WsClient.instance.connect(userId);
      BroadcastService.instance.restore();
      if (mounted) {
        setState(() => _loading = false);
        AppRouter.go(context, AppRoutes.map);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      String message = _isRegister ? 'Registration failed' : 'Login failed';
      if (e.statusCode == 401 || e.statusCode == 404) {
        message = 'Invalid username or password';
      } else if (e.statusCode == 409) {
        message = 'Username already taken';
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _loginAsMock(DevMockUser user) async {
    Session.instance.userId = user.id;
    Session.instance.userName = user.displayName;
    await Session.instance.save();
    WsClient.instance.connect(user.id);
    BroadcastService.instance.restore();
    if (mounted) AppRouter.go(context, AppRoutes.map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.lg,
                ),
                child: const Icon(Icons.grid_view_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Welcome to\nMahJoin', style: AppTypography.displayLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Find Mahjong players around you',
                style: AppTypography.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Username input
              Text('Username', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _usernameCtrl,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter your username',
                  prefixIcon: Icon(Icons.person_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Register-only fields
              if (_isRegister) ...[
                Text('Display Name', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _displayNameCtrl,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Enter your display name',
                    prefixIcon: Icon(Icons.badge_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Email', style: AppTypography.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_rounded,
                        color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Password input
              Text('Password', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_rounded,
                      color: AppColors.textMuted, size: 20),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isRegister ? 'Register' : 'Sign In'),
              ),

              const SizedBox(height: AppSpacing.md),

              // Toggle login / register
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Register",
                    style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy',
                  style: AppTypography.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),

              // ── Dev Quick Login ──────────────────────────────────────────
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('DEV — Quick Login',
                        style: AppTypography.labelSmall
                            .copyWith(color: AppColors.textMuted)),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: devMockUsers
                      .map((u) => ActionChip(
                            avatar: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              radius: 10,
                              child: Text(
                                u.displayName[0],
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white),
                              ),
                            ),
                            label: Text(u.displayName,
                                style: AppTypography.labelLarge),
                            onPressed: () => _loginAsMock(u),
                          ))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
