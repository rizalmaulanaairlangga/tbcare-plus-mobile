import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../routes/app_routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey             = GlobalKey<FormState>();
  final _fullNameCtrl        = TextEditingController();
  final _emailCtrl           = TextEditingController();
  final _passwordCtrl        = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading              = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      await AuthApiService.register(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nickname: _fullNameCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
        arguments: 'Akun berhasil dibuat! Silakan login.',
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth  = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          _buildScatteredAuras(screenWidth, screenHeight),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildBackButton(context),
                    const SizedBox(height: 32),

                    const Text('Create Account', style: AppTextStyles.heading1),
                    const Text('Start your health journey',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 32),

                    _buildRegisterCard(),

                    const SizedBox(height: 40),
                    _buildFooter(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.white.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back, color: AppColors.foreground, size: 20),
      ),
    );
  }

  Widget _buildRegisterCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Banner
              if (_errorMessage != null) ...[
                _buildErrorBanner(_errorMessage!),
                const SizedBox(height: 20),
              ],

              _buildLabel('Nickname'),
              const SizedBox(height: 8),
              _buildTextFormField(
                controller: _fullNameCtrl,
                hint: 'Enter your nickname',
                icon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Nickname tidak boleh kosong';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Email Address'),
              const SizedBox(height: 8),
              _buildTextFormField(
                controller: _emailCtrl,
                hint: 'Enter your email address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                  if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid (harus mengandung @ dan .)';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildPasswordFormField(
                controller: _passwordCtrl,
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscure: _obscurePassword,
                onToggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
                  if (v.length < 6) return 'Password minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _buildLabel('Confirm Password'),
              const SizedBox(height: 8),
              _buildPasswordFormField(
                controller: _confirmPasswordCtrl,
                hint: 'Repeat your password',
                icon: Icons.shield_outlined,
                obscure: _obscureConfirmPassword,
                onToggle: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _onRegister(),
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Konfirmasi password tidak boleh kosong';
                  if (v != _passwordCtrl.text)
                    return 'Password tidak cocok';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Create Account',
                                style: AppTextStyles.buttonPrimary),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Field Builders ────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.foreground,
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        validator: validator,
        decoration: _inputDecoration(hint: hint, icon: icon),
      ),
    );
  }

  Widget _buildPasswordFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: _fieldDecoration(),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        decoration: _inputDecoration(
          hint: hint,
          icon: icon,
          suffixIcon: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.mutedForeground,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: AppColors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: AppColors.mutedForeground.withOpacity(0.5), fontSize: 15),
      prefixIcon:
          Icon(icon, color: AppColors.primary.withOpacity(0.7), size: 20),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Text('Already have an account?', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text(
              'Login to Account',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScatteredAuras(double sw, double sh) {
    return Stack(
      children: [
        Positioned(
            top: -50,
            right: -50,
            child: _buildAura(150, AppColors.primary.withOpacity(0.1))),
        Positioned(
            top: sh * 0.3,
            left: -100,
            child: _buildAura(150, AppColors.secondary.withOpacity(0.05))),
        Positioned(
            bottom: 100,
            right: 20,
            child: _buildAura(100, AppColors.accent.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildAura(double size, Color color) {
    return Container(
      width: size * 2,
      height: size * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size, spreadRadius: size / 2),
        ],
      ),
    );
  }
}
