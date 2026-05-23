import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/guest_assessment_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/guest_bottom_nav.dart';
import '../../../core/widgets/app_bottom_nav.dart';

enum RiskLevel { low, medium, high }

class ResultPage extends StatefulWidget {
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  RiskLevel _currentRisk = RiskLevel.low;
  int _percentage = 0;
  bool _isGuest = true;
  String? _userName;
  Map<String, dynamic>? _assessmentData;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Primary: load from local storage (saved right before navigation)
      final saved = await GuestAssessmentService.get();
      if (saved != null) {
        _currentRisk = _parseRisk(saved['riskLevel'] as String?);
        _percentage = (saved['percentage'] as int?) ?? 0;
        _assessmentData = saved;
      }

      // Secondary: override with route arguments if present
      final raw = ModalRoute.of(context)?.settings.arguments;
      if (raw is Map) {
        _currentRisk = raw['riskLevel'] as RiskLevel;
        _percentage = (raw['percentage'] as int?) ?? _percentage;
        _isGuest = (raw['isGuest'] as bool?) ?? true;
      }

      final user = await StorageService.getUser();
      if (!mounted) return;
      setState(() {
        _isGuest = user == null;
        _userName = user?.fullName;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  RiskLevel _parseRisk(String? name) {
    switch (name) {
      case 'high':
        return RiskLevel.high;
      case 'medium':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }

  Map<String, dynamic> _getRiskData() {
    switch (_currentRisk) {
      case RiskLevel.low:
        return {
          'percentage': _percentage,
          'title': 'Low Risk',
          'subtitle': 'You show low indications of TBC',
          'description': 'Your current symptoms do not strongly indicate TBC. Stay healthy and monitor your condition.',
          'color': AppColors.primary,
          'icon': Icons.check_circle_outline,
          'auraColor': AppColors.primary.withOpacity(0.1),
        };
      case RiskLevel.medium:
        return {
          'percentage': _percentage,
          'title': 'Medium Risk',
          'subtitle': 'Some symptoms require attention',
          'description': 'You show some symptoms related to TBC. It is recommended to continue with a more detailed assessment.',
          'color': AppColors.warning,
          'icon': Icons.info_outline,
          'auraColor': AppColors.warning.withOpacity(0.1),
        };
      case RiskLevel.high:
        return {
          'percentage': _percentage,
          'title': 'High Risk',
          'subtitle': 'Strong indication of TBC symptoms',
          'description': 'Your symptoms strongly indicate potential TBC. Please proceed with a full assessment and seek medical attention.',
          'color': AppColors.destructive,
          'icon': Icons.report_problem_outlined,
          'auraColor': AppColors.destructive.withOpacity(0.1),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = _getRiskData();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildScatteredAuras(screenWidth, screenHeight, data['auraColor']),
          SafeArea(
            child: Column(
              children: [
                HomeHeader(isGuest: _isGuest, userName: _userName),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Text(
                        'Screening Result',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Based on your answers, here is your risk assessment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildResultCard(data),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isGuest
          ? const GuestBottomNav(currentIndex: -1)
          : AppBottomNav(
              currentIndex: 0,
              onTap: (i) {
                final routes = [AppRoutes.home, AppRoutes.history, AppRoutes.profile];
                if (i < routes.length) {
                  Navigator.pushNamedAndRemoveUntil(context, routes[i], (route) => false);
                }
              },
            ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    Color mainColor = data['color'];
    final pct = data['percentage'] as int;

    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: mainColor.withOpacity(0.2)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  width: 240,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      CustomPaint(
                        size: const Size(240, 120),
                        painter: GaugePainter(
                          percentage: pct / 100,
                          color: mainColor,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: AppColors.foreground,
                                height: 1,
                              ),
                            ),
                            Text(
                              '${data['title'].split(' ')[0].toUpperCase()} RISK',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: mainColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(data['icon'], color: mainColor, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      data['title'],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data['subtitle'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: mainColor.withOpacity(0.1)),
                  ),
                  child: Text(
                    data['description'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_currentRisk != RiskLevel.low) ...[
                  _buildButton(
                    'Continue Full Assessment',
                    mainColor,
                    Colors.white,
                    true,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.fullAssessment),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildButton(
                  _currentRisk == RiskLevel.low ? 'Back to Home' : 'Find Nearby Clinic',
                  _currentRisk == RiskLevel.low ? Colors.white : Colors.transparent,
                  mainColor,
                  false,
                  borderColor: _currentRisk == RiskLevel.low ? mainColor.withOpacity(0.2) : Colors.transparent,
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color bgColor, Color textColor, bool hasShadow, {Color? borderColor, VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: bgColor,
        border: borderColor != null ? Border.all(color: borderColor) : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: bgColor.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildScatteredAuras(double sw, double sh, Color color) {
    return Stack(
      children: [
        Positioned(top: -50, right: -50, child: _buildAura(150, color.withOpacity(0.2))),
        Positioned(top: sh * 0.3, left: -100, child: _buildAura(180, color.withOpacity(0.1))),
        Positioned(bottom: 100, right: 20, child: _buildAura(100, AppColors.muted.withOpacity(0.2))),
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
          BoxShadow(
            color: color,
            blurRadius: size,
            spreadRadius: size / 2,
          ),
        ],
      ),
    );
  }
}

class GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;

  GaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 10;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final bgPaint = Paint()
      ..color = AppColors.muted.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
