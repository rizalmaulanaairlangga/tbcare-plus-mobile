import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/services/guest_assessment_service.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/models/assessment_config_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/guest_bottom_nav.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../result/pages/result_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  QuickCheckConfig? _config;
  Map<int, bool> _symptomStates = {};
  bool _isGuest = true;
  String? _userName;
  bool _loadingConfig = true;

  int get _answeredCount => _symptomStates.values.where((v) => v).length;

  double get _combinedCF {
    if (_config == null || _answeredCount == 0) return 0;
    double sum = 0;
    _symptomStates.forEach((symptomId, selected) {
      if (selected) {
        final q = _config!.questions.firstWhere(
          (q) => q.symptomId == symptomId,
          orElse: () => _config!.questions.first,
        );
        sum += q.weight;
      }
    });
    return 1 - exp(-_config!.saturationK * sum);
  }

  int get _percentage => (_combinedCF * 100).round();

  RiskLevelConfig? get _matchedRiskLevel {
    if (_config == null) return null;
    return _config!.findRiskLevel(_percentage.toDouble(), 1);
  }

  RiskLevel get _risk {
    final rl = _matchedRiskLevel;
    if (rl == null) return RiskLevel.low;
    switch (rl.code.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }

  Color get _riskColor {
    switch (_risk) {
      case RiskLevel.low:
        return AppColors.primary;
      case RiskLevel.medium:
        return AppColors.warning;
      case RiskLevel.high:
        return AppColors.destructive;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadConfig();
  }

  Future<void> _loadUser() async {
    final user = await StorageService.getUser();
    if (!mounted) return;
    setState(() {
      _isGuest = user == null;
      _userName = user?.fullName;
    });

    if (user != null) {
      try {
        final updatedUser = await AuthApiService.fetchCurrentUser();
        if (mounted && updatedUser.fullName != _userName) {
          setState(() {
            _userName = updatedUser.fullName;
          });
        }
      } catch (e) {
        // Silently fail background sync (e.g. if offline)
      }
    }
  }

  Future<void> _loadConfig() async {
    final config = await AssessmentApiService.fetchQuickCheckConfig();
    if (!mounted) return;
    setState(() {
      _config = config;
      _symptomStates = {
        for (final q in config.questions) q.symptomId: false,
      };
      _loadingConfig = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildScatteredAuras(screenWidth, screenHeight),
          SafeArea(
            child: Column(
              children: [
                HomeHeader(isGuest: _isGuest, userName: _userName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        if (_loadingConfig)
                          _buildLoadingCard()
                        else
                          _buildAssessmentCard(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Symptom Insights'),
                        const SizedBox(height: 16),
                        _buildInsightItem(
                          Icons.lightbulb_outline,
                          'Early detection saves lives',
                          'TBC symptoms often start subtle. Regular checks are vital.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isGuest
          ? const GuestBottomNav(currentIndex: 0)
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

  Widget _buildLoadingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    final config = _config!;
    final pct = _percentage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick TBC Check',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        '${config.questions.length} symptoms to review',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (pct > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _riskColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pct% · ${_matchedRiskLevel?.code.toUpperCase() ?? ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _riskColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 8,
                    width: (MediaQuery.of(context).size.width - 96) * (_percentage / 100).clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Dynamic symptom items from backend
              ...config.questions.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSymptomItem(q),
                  )),

              const SizedBox(height: 24),
              _buildCheckButton(),
            ],
          ),
        ),
      ),
    );
  }

  final Map<int, IconData> _symptomIcons = {
    1: Icons.air_outlined,
    2: Icons.water_drop_outlined,
    3: Icons.accessibility_new_rounded,
    4: Icons.waves_outlined,
    5: Icons.monitor_weight_outlined,
    6: Icons.thermostat_outlined,
    7: Icons.nightlight_outlined,
    8: Icons.battery_alert_outlined,
  };

  Widget _buildSymptomItem(QuickCheckQuestion q) {
    final isSelected = _symptomStates[q.symptomId] ?? false;
    final icon = _symptomIcons[q.symptomId] ?? Icons.help_outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.12) : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? AppColors.primary : AppColors.primary).withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.mutedForeground, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              q.questionText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.foreground : AppColors.mutedForeground,
              ),
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: (val) => setState(() => _symptomStates[q.symptomId] = val),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.2),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    final hasSelection = _answeredCount > 0;

    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: hasSelection
              ? const [AppColors.primary, AppColors.secondary]
              : [AppColors.muted, AppColors.muted.withOpacity(0.6)],
        ),
        boxShadow: hasSelection
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: hasSelection ? _onCheckRisk : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text(
          'Check My Risk',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _onCheckRisk() async {
    if (_answeredCount == 0 || _config == null) return;

    final cf = _combinedCF;
    final pct = _percentage;
    final risk = _risk;
    final matchedLevel = _matchedRiskLevel;

    final selectedSymptoms = <String, bool>{};
    _symptomStates.forEach((k, v) => selectedSymptoms[k.toString()] = v);

    final assessmentData = {
      'riskLevel': risk.name,
      'combinedCF': cf,
      'percentage': pct,
      'riskCode': matchedLevel?.code ?? '',
      'riskTitle': matchedLevel?.title ?? '',
      'type': 'QUICK CHECK',
      'symptoms': selectedSymptoms,
    };

    try {
      await GuestAssessmentService.save(assessmentData);
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.result,
      arguments: {
        'riskLevel': risk,
        'isGuest': _isGuest,
        'percentage': pct,
        'assessmentData': assessmentData,
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScatteredAuras(double sw, double sh) {
    return Stack(
      children: [
        Positioned(top: -50, right: -50, child: _buildAura(150, AppColors.primary.withOpacity(0.1))),
        Positioned(top: sh * 0.2, left: -100, child: _buildAura(180, AppColors.secondary.withOpacity(0.05))),
        Positioned(bottom: 100, right: 20, child: _buildAura(100, AppColors.muted.withOpacity(0.1))),
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
