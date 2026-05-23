import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../routes/app_routes.dart';

class CoverPage extends StatefulWidget {
  const CoverPage({super.key});

  @override
  State<CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<CoverPage> with TickerProviderStateMixin {
  late AnimationController _dragController;
  late Animation<double> _dragAnimation;

  late AnimationController _entranceController;
  late Animation<double> _entranceAnimation;

  @override
  void initState() {
    super.initState();

    // Drag Animation (Cover <-> Login)
    _dragController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dragAnimation = CurvedAnimation(
      parent: _dragController,
      curve: Curves.easeOutQuart,
    );

    // Entrance Animation (Center -> Cover)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    // Start entrance animation after a longer delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _entranceController.forward();
      }
    });

    // Auto-redirect to home if already logged in
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    }
  }

  @override
  void dispose() {
    _dragController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_entranceController.isCompleted) return; // Block drag during entrance

    _dragController.value -= details.primaryDelta! / 400;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dragController.value > 0.4) {
      _dragController.forward();
    } else {
      _dragController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Background Auras
          _buildScatteredAuras(screenWidth, screenHeight),

          // Main Animation Builder
          AnimatedBuilder(
            animation: Listenable.merge([_entranceAnimation, _dragAnimation]),
            builder: (context, child) {
              final tE = _entranceAnimation.value;
              final tD = _dragAnimation.value;

              // --- LOGO CALCULATIONS ---
              const logoSize = 180.0;
              final logoStartTop = (screenHeight / 2) - (logoSize / 2);
              final logoCoverTop = screenHeight * 0.12;
              final logoLoginTop = screenHeight * -0.05;

              // First lerp for entrance, second for drag
              final currentLogoTop = Color.lerp(
                Color.fromARGB(
                  lerpDouble(logoStartTop, logoCoverTop, tE)!.toInt(),
                  0,
                  0,
                  0,
                ),
                Color.fromARGB(logoLoginTop.toInt(), 0, 0, 0),
                tD,
              )!.alpha.toDouble();

              // Simplest way to lerp double twice:
              final logoPos = lerpDouble(
                lerpDouble(logoStartTop, logoCoverTop, tE),
                logoLoginTop,
                tD,
              )!;

              final logoOpacity = (1.0 - tD * 2.0).clamp(0.0, 1.0);
              final logoScale = 1.0 - (tD * 0.2);

              // --- SHEET CALCULATIONS ---
              final sheetStartTop = screenHeight;
              final sheetCoverTop = screenHeight * 0.55;
              final sheetLoginTop = screenHeight * 0.35;

              final sheetPos = lerpDouble(
                lerpDouble(sheetStartTop, sheetCoverTop, tE),
                sheetLoginTop,
                tD,
              )!;

              return Stack(
                children: [
                  // The Logo
                  Positioned(
                    top: logoPos,
                    left: (screenWidth / 2) - (90 * logoScale),
                    child: Opacity(
                      opacity: logoOpacity,
                      child: Transform.scale(
                        scale: logoScale,
                        child: _buildLogoWidget(),
                      ),
                    ),
                  ),

                  // Header for Login (Hidden in Cover state)
                  Positioned(
                    top: screenHeight * 0.08,
                    left: 24,
                    child: Opacity(
                      opacity: tD,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _dragController.reverse(),
                            child: _buildBackIcon(),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Welcome Back',
                            style: AppTextStyles.heading1,
                          ),
                          const Text(
                            'Login to your account',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: sheetPos,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onVerticalDragUpdate: _onVerticalDragUpdate,
                      onVerticalDragEnd: _onVerticalDragEnd,
                      child: _buildSheetContent(tD),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(double t) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Cover Content (Fades out)
          Opacity(
            opacity: (1.0 - t * 3.0).clamp(0.0, 1.0),
            child: SingleChildScrollView(child: _buildCoverSheetItems()),
          ),

          // Login Content (Fades in)
          Opacity(
            opacity: (t * 3.0 - 2.0).clamp(0.0, 1.0),
            child: IgnorePointer(
              ignoring: t < 0.8,
              child: _buildLoginSheetItems(),
            ),
          ),

          // Handlebar (Always visible) - Styled like a clipboard clip
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Container(
                width: 55,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSheetItems() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TBCare+', style: AppTextStyles.heading1),
          const SizedBox(height: 12),
          const Text(
            'Early Detection for Better Health. Track your symptoms and get accurate insights instantly.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLoginSheetItems() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      child: Column(
        children: [
          _buildLabel('Email Address'),
          const SizedBox(height: 8),
          _buildTextField(hint: 'Enter your email', icon: Icons.mail_outline),
          const SizedBox(height: 20),
          _buildLabel('Password'),
          const SizedBox(height: 8),
          _buildTextField(
            hint: 'Enter your password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 30),
          _buildLoginButton(),
          const SizedBox(height: 20),
          const Text("Don't have an account?", style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          _buildSecondaryButton('Create Account', () {
            Navigator.pushNamed(context, AppRoutes.register);
          }),
        ],
      ),
    );
  }

  // --- Sub-widgets extracted for cleaner code ---

  Widget _buildBackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.7),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white),
      ),
      child: const Icon(
        Icons.arrow_back,
        color: AppColors.foreground,
        size: 20,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Get Started',
              style: AppTextStyles.buttonPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildSecondaryButton('Continue as Guest', () {
          Navigator.pushNamed(context, AppRoutes.home);
        }),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Login', style: AppTextStyles.buttonPrimary),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: AppColors.primary.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(text, style: AppTextStyles.buttonSecondary),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: TextField(
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: AppColors.primary.withOpacity(0.7),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoWidget() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Green aura effect at the top
        Positioned(
          top: -25,
          child: Container(
            width: 150,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.22),
                  AppColors.white.withOpacity(0),
                ],
              ),
            ),
          ),
        ),

        // Green aura effect at the bottom right - 'Smoke' effect
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(0.2, 0.2),
                radius: 0.7,
                colors: [
                  AppColors.primary.withOpacity(0.35),
                  AppColors.white.withOpacity(0.15),
                  AppColors.white.withOpacity(0),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // Green aura effect at the bottom left
        Positioned(
          bottom: -20,
          left: -20,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.4),
                radius: 0.8,
                colors: [
                  AppColors.primary.withOpacity(0.28),
                  AppColors.white.withOpacity(0.16),
                  AppColors.white.withOpacity(0.0),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Main Container
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(52),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  AppColors.primary.withOpacity(0.22),
                  AppColors.white.withOpacity(0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(46),
            ),
            padding: const EdgeInsets.all(24), // Increased padding to shrink inner box
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/img_logo_app.png',
                  width: 155, // Enlarge logo slightly
                  height: 155,
                  fit: BoxFit.contain,
                ),
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
          left: -50,
          child: _buildAura(400, AppColors.primary.withOpacity(0.15)),
        ),
        Positioned(
          top: sh * 0.2,
          right: -100,
          child: _buildAura(350, AppColors.primary.withOpacity(0.1)),
        ),
        Positioned(
          bottom: sh * 0.2,
          left: -100,
          child: _buildAura(300, AppColors.accent.withOpacity(0.12)),
        ),
        Positioned(
          top: sh * 0.5,
          left: sw * 0.4,
          child: _buildAura(250, AppColors.primary.withOpacity(0.1)),
        ),
      ],
    );
  }

  Widget _buildAura(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}
