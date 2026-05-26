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
  Map<String, dynamic>? _storedResult;
  bool get _hasStoredResult => _storedResult != null;
  
  // For logged-in users: most recent assessment data
  Map<String, dynamic>? _mostRecentAssessment;
  bool _loadingMostRecentAssessment = false;
  bool _hasCompletedFullAssessment = false;
  bool _isMostRecentQuickAssessment = false;

  int get _answeredCount => _symptomStates.values.where((v) => v).length;

  double get _combinedCF {
    if (_config == null || _answeredCount == 0) return 0;

    // Quick check score is based on total questions and their weights:
    // percentage = (sum(selected weights) / sum(all weights)) * 100
    final totalWeight = _config!.questions.fold<double>(0, (acc, q) => acc + q.weight);
    if (totalWeight <= 0) return 0;

    double selectedWeight = 0;
    _symptomStates.forEach((symptomId, selected) {
      if (!selected) return;
      final q = _config!.questions.firstWhere(
        (q) => q.symptomId == symptomId,
        orElse: () => _config!.questions.first,
      );
      selectedWeight += q.weight;
    });

    return selectedWeight / totalWeight;
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

  bool _argumentsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsLoaded) {
      _argumentsLoaded = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        if (args.containsKey('isGuest')) {
          _isGuest = args['isGuest'] as bool;
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadConfig();
    _loadStoredResult();
  }

  Future<void> _loadMostRecentAssessment() async {
    if (_isGuest) return;
    
    setState(() => _loadingMostRecentAssessment = true);
    
    try {
      final assessment = await AssessmentApiService.fetchMostRecentAssessment();
      final hasFullAssessment = await AssessmentApiService.hasCompletedFullAssessment();
      final isMostRecentQuick = await AssessmentApiService.isMostRecentQuickAssessment();
      
      if (!mounted) return;
      setState(() {
        _mostRecentAssessment = assessment;
        _hasCompletedFullAssessment = hasFullAssessment;
        _isMostRecentQuickAssessment = isMostRecentQuick;
        _loadingMostRecentAssessment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMostRecentAssessment = false);
    }
  }

  Future<void> _loadStoredResult() async {
    if (!_isGuest) return;
    final saved = await GuestAssessmentService.get();
    if (!mounted) return;
    if (saved != null && saved['type'] == 'QUICK CHECK') {
      setState(() => _storedResult = saved);
    }
  }

  Future<void> _loadUser() async {
    final user = await StorageService.getUser();
    if (!mounted) return;
    final wasGuest = _isGuest;
    setState(() {
      _isGuest = user == null;
      _userName = user?.fullName;
    });

    // Guest→guest: try loading stored result
    if (_isGuest && wasGuest && _storedResult == null) {
      _loadStoredResult();
    } else if (!_isGuest && wasGuest) {
      // Guest→logged-in: load most recent assessment from backend
      _loadMostRecentAssessment();
    } else if (!_isGuest) {
      // Still logged-in: load most recent assessment
      _loadMostRecentAssessment();
    }

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
                        if (_loadingConfig || (_loadingMostRecentAssessment && !_isGuest))
                          _buildLoadingCard()
                        else if (!_isGuest && _mostRecentAssessment != null)
                          _buildLoggedInResultCard()
                        else if (_hasStoredResult && _isGuest)
                          _buildStoredResultCard()
                        else
                          _buildAssessmentCard(),
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
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    routes[i],
                    (route) => false,
                    arguments: {'isGuest': _isGuest},
                  );
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
                        'Cek TBC Cepat',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.foreground,
                        ),
                      ),
                      Text(
                        '${config.questions.length} gejala untuk ditinjau',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

    return GestureDetector(
      onTap: () => setState(() => _symptomStates[q.symptomId] = !isSelected),
      behavior: HitTestBehavior.opaque,
      child: Container(
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
          'Periksa Risiko Saya',
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
      'description': matchedLevel?.description ?? '',
      'type': 'QUICK CHECK',
      'symptoms': selectedSymptoms,
    };

    try {
      await GuestAssessmentService.save(assessmentData);
      if (!mounted) return;
      setState(() => _storedResult = assessmentData);
    } catch (_) {}

    // If user is logged in, persist quick assessment to backend history as well.
    if (!_isGuest) {
      final answers = <Map<String, dynamic>>[];
      for (final q in _config!.questions) {
        final selected = _symptomStates[q.symptomId] ?? false;
        if (!selected) continue;
        answers.add({
          'questionId': q.questionId,
          'cfValue': 1.0,
        });
      }

      if (answers.isNotEmpty) {
        try {
          await AssessmentApiService.submitAssessment(
            assessmentTypeId: 1,
            answers: answers,
          );
          
          // Reload the most recent assessment to show on dashboard
          if (mounted) {
            await _loadMostRecentAssessment();
          }
        } catch (e) {
          // Don't block navigation if saving history fails, but log for debugging.
          // ignore: avoid_print
          print('submitAssessment(quick) failed: $e');
        }
      }
      return; // For logged-in users, stay on dashboard and show result
    }

    // For guests, navigate to result page
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

  // ─── STORED RESULT CARD ────────────────────────────────────
  Widget _buildStoredResultCard() {
    final result = _storedResult!;
    final pct = (result['percentage'] as int?) ?? 0;
    final riskCode = (result['riskCode'] as String?) ?? 'LOW';
    final riskTitle = (result['riskTitle'] as String?) ?? 'Risiko Rendah';
    final color = _colorForRisk(riskCode);
    final icon = _iconForRisk(riskCode);
    final subtitle = _subtitleForRisk(riskCode);
    final description = _descriptionForRisk(riskCode);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
            children: [
              // Title
              const Text(
                'Hasil Skrining Terakhir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 10),

              // Pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Text(
                  'Cek Cepat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Gauge
              SizedBox(
                height: 140,
                width: 240,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CustomPaint(
                      size: const Size(240, 120),
                      painter: GaugePainter(percentage: pct / 100, color: color),
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
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Risk icon + title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    riskTitle,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.1)),
                ),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Buttons
              if (riskCode.toUpperCase() != 'LOW') ...[
                _buildResultButton(
                  'Lanjutkan Pemeriksaan Lengkap',
                  color,
                  Colors.white,
                  true,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.fullAssessment),
                ),
                const SizedBox(height: 12),
              ],
              _buildResultButton(
                'Cari Klinik Terdekat',
                Colors.transparent,
                color,
                false,
                borderColor: color.withOpacity(0.2),
                onPressed: () {}, // Placeholder
              ),
              const SizedBox(height: 12),
              _buildResultButton(
                'Ulangi Cek Cepat',
                Colors.white,
                AppColors.mutedForeground,
                false,
                borderColor: AppColors.muted.withOpacity(0.3),
                onPressed: _retakeQuickCheck,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultButton(
    String text,
    Color bgColor,
    Color textColor,
    bool hasShadow, {
    Color? borderColor,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ─── LOGGED-IN USER RESULT CARD ────────────────────────────────────
  Widget _buildLoggedInResultCard() {
    if (_mostRecentAssessment == null) {
      return _buildAssessmentCard();
    }

    final assessment = _mostRecentAssessment!;
    
    // Extract the most recent result info
    final assessmentTypeId = assessment['assessmentTypeId'] as int? ?? 1;
    final assessmentTypeName = assessment['assessmentTypeName'] as String? ?? 'Assessment';
    final riskLevelCode = assessment['riskLevelCode'] as String? ?? 'LOW';
    final riskLevelTitle = assessment['riskLevelTitle'] as String? ?? 'Low Risk';
    final totalScore = assessment['totalScore'] as num? ?? 0;
    final pct = totalScore.toInt();
    
    // For full assessment, we might have multiple results - just show the main risk
    String primaryRiskCode = riskLevelCode;
    String primaryRiskTitle = riskLevelTitle;
    double primaryScore = pct.toDouble();
    
    final color = _colorForRisk(primaryRiskCode);
    final icon = _iconForRisk(primaryRiskCode);
    final subtitle = _subtitleForRisk(primaryRiskCode);
    final description = _descriptionForRisk(primaryRiskCode);
    
    final isFullAssessment = assessmentTypeId == 2;
    final assessmentBadge = isFullAssessment ? 'Pemeriksaan Lengkap' : 'Cek Cepat';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
            children: [
              // Title
              const Text(
                'Hasil Skrining Terakhir',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 10),

              // Pill badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.15)),
                ),
                child: Text(
                  assessmentBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Gauge
              SizedBox(
                height: 140,
                width: 240,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    CustomPaint(
                      size: const Size(240, 120),
                      painter: GaugePainter(percentage: pct / 100, color: color),
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
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Risk icon + title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    primaryRiskTitle,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 24),

              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.withOpacity(0.1)),
                ),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Buttons - different based on assessment type
              if (!isFullAssessment && primaryRiskCode.toUpperCase() != 'LOW') ...[
                _buildResultButton(
                  'Lanjutkan Pemeriksaan Lengkap',
                  color,
                  Colors.white,
                  true,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.fullAssessment),
                ),
                const SizedBox(height: 12),
              ],
              _buildResultButton(
                isFullAssessment ? 'Ulangi Pemeriksaan Lengkap' : 'Ulangi Cek Cepat',
                color,
                Colors.white,
                true,
                onPressed: () => _onRetakeAssessment(isFullAssessment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRetakeAssessment(bool isFullAssessment) async {
    if (isFullAssessment) {
      // Clear selected symptoms and go to full assessment
      Navigator.pushNamed(context, AppRoutes.fullAssessment);
    } else {
      // Reset quick assessment form
      setState(() {
        if (_config != null) {
          _symptomStates = {
            for (final q in _config!.questions) q.symptomId: false,
          };
        }
        _mostRecentAssessment = null;
      });
    }
  }

  void _retakeQuickCheck() {
    GuestAssessmentService.clear();
    setState(() {
      _storedResult = null;
      if (_config != null) {
        _symptomStates = {
          for (final q in _config!.questions) q.symptomId: false,
        };
      }
    });
  }

  Color _colorForRisk(String code) {
    switch (code.toUpperCase()) {
      case 'HIGH':
        return AppColors.destructive;
      case 'MEDIUM':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _iconForRisk(String code) {
    switch (code.toUpperCase()) {
      case 'HIGH':
        return Icons.report_problem_outlined;
      case 'MEDIUM':
        return Icons.info_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _subtitleForRisk(String code) {
    switch (code.toUpperCase()) {
      case 'HIGH':
        return 'Indikasi kuat gejala TBC';
      case 'MEDIUM':
        return 'Beberapa gejala memerlukan perhatian';
      default:
        return 'Anda menunjukkan indikasi rendah TBC';
    }
  }

  String _descriptionForRisk(String code) {
    switch (code.toUpperCase()) {
      case 'HIGH':
        return 'Gejala Anda sangat mengindikasikan potensi TBC. Silakan lanjutkan dengan pemeriksaan lengkap dan cari bantuan medis.';
      case 'MEDIUM':
        return 'Anda menunjukkan beberapa gejala terkait TBC. Disarankan untuk melanjutkan dengan pemeriksaan yang lebih detail.';
      default:
        return 'Gejala Anda saat ini tidak secara kuat mengindikasikan TBC. Jaga kesehatan dan pantau kondisi Anda.';
    }
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
