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
  // --- Quick Check mode ---
  RiskLevel _currentRisk = RiskLevel.low;
  int _percentage = 0;
  Map<String, dynamic>? _assessmentData;

  // --- Full Assessment mode ---
  bool _isFullAssessment = false;
  Map<String, dynamic>? _fullResultData;

  // --- Common ---
  bool _isGuest = true;
  String? _userName;
  bool _loaded = false;

  bool _argumentsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsLoaded) {
      _argumentsLoaded = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final raw = ModalRoute.of(context)?.settings.arguments;
      if (raw is Map) {
        _isFullAssessment = (raw['isFullAssessment'] as bool?) ?? false;
        if (_isFullAssessment) {
          _fullResultData = raw['result'] as Map<String, dynamic>?;
          _isGuest = (raw['isGuest'] as bool?) ?? false;
        } else {
          _currentRisk = raw['riskLevel'] as RiskLevel? ?? RiskLevel.low;
          _percentage = (raw['percentage'] as int?) ?? _percentage;
          _isGuest = (raw['isGuest'] as bool?) ?? true;
          _assessmentData = raw['assessmentData'] as Map<String, dynamic>?;
        }
      } else {
        // Fallback: load from local storage (guest quick check)
        final saved = await GuestAssessmentService.get();
        if (saved != null) {
          _currentRisk = _parseRisk(saved['riskLevel'] as String?);
          _percentage = (saved['percentage'] as int?) ?? 0;
          _assessmentData = saved;
        }
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
    // Prefer DB-fetched values from assessmentData, fallback to sensible defaults
    final dbTitle = _assessmentData?['riskTitle'] as String?;
    final dbDescription = _assessmentData?['description'] as String?;

    String title;
    String subtitle;
    String description;
    Color color;
    IconData icon;

    switch (_currentRisk) {
      case RiskLevel.low:
        title = dbTitle ?? 'Low Risk';
        subtitle = 'Anda menunjukkan indikasi rendah TBC';
        description = dbDescription ?? 'Gejala Anda saat ini tidak secara kuat mengindikasikan TBC. Jaga kesehatan dan pantau kondisi Anda.';
        color = AppColors.primary;
        icon = Icons.check_circle_outline;
      case RiskLevel.medium:
        title = dbTitle ?? 'Medium Risk';
        subtitle = 'Beberapa gejala memerlukan perhatian';
        description = dbDescription ?? 'Anda menunjukkan beberapa gejala terkait TBC. Disarankan untuk melanjutkan dengan pemeriksaan yang lebih detail.';
        color = AppColors.warning;
        icon = Icons.info_outline;
      case RiskLevel.high:
        title = dbTitle ?? 'High Risk';
        subtitle = 'Indikasi kuat gejala TBC';
        description = dbDescription ?? 'Gejala Anda sangat mengindikasikan potensi TBC. Silakan lanjutkan dengan pemeriksaan lengkap dan cari bantuan medis.';
        color = AppColors.destructive;
        icon = Icons.report_problem_outlined;
    }

    return {
      'percentage': _percentage,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'color': color,
      'icon': icon,
      'auraColor': color.withOpacity(0.1),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // For full assessment, use a neutral aura
    final auraColor = _isFullAssessment
        ? AppColors.primary.withOpacity(0.08)
        : (_getRiskData()['auraColor'] as Color);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildScatteredAuras(screenWidth, screenHeight, auraColor),
          if (_isFullAssessment)
            // Full assessment: needs Expanded+ListView, so use a bounded Column
            SafeArea(
              child: Column(
                children: [
                  HomeHeader(isGuest: _isGuest, userName: _userName),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          'Hasil Pemeriksaan Lengkap',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Analisis risiko TBC menyeluruh Anda di semua kategori.',
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
                      child: _buildFullResultList(),
                    ),
                  ),
                ],
              ),
            )
          else
            // Quick check: card hugs its content, page scrolls if needed
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeHeader(isGuest: _isGuest, userName: _userName),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const Text(
                            'Hasil Skrining',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.foreground,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Berdasarkan jawaban Anda, berikut adalah penilaian risiko Anda.',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _buildResultCard(_getRiskData()),
                    ),
                  ],
                ),
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

  // ─── FULL ASSESSMENT MULTI-CATEGORY RESULT ────────────────
  Widget _buildFullResultList() {
    if (_fullResultData == null) {
      return const Center(child: Text('Data hasil tidak ditemukan.'));
    }

    final rawResults = _fullResultData!['results'] as List<dynamic>? ?? [];
    final resultsList = rawResults
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();

    int riskRank(String? code) {
      final c = (code ?? '').toUpperCase();
      if (c.contains('HIGH')) return 3;
      if (c.contains('MEDIUM') || c.contains('MODERATE')) return 2;
      return 1;
    }

    resultsList.sort((a, b) {
      final aRisk = a['riskLevel'] as Map<String, dynamic>?;
      final bRisk = b['riskLevel'] as Map<String, dynamic>?;
      final aRank = riskRank(aRisk?['code'] as String?);
      final bRank = riskRank(bRisk?['code'] as String?);
      if (aRank != bRank) return bRank.compareTo(aRank);

      final aScore = (a['totalScore'] as num?)?.toDouble() ?? 0.0;
      final bScore = (b['totalScore'] as num?)?.toDouble() ?? 0.0;
      return bScore.compareTo(aScore);
    });

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: resultsList.length,
            itemBuilder: (context, index) {
              final item = resultsList[index];
              final tbTypeName = item['tbTypeName'] as String? ?? 'Tidak Diketahui';
              final totalScore = (item['totalScore'] as num?)?.toDouble() ?? 0.0;
              final scorePercent = totalScore.round();
              final riskLevelMap = item['riskLevel'] as Map<String, dynamic>?;
              final riskTitle = riskLevelMap?['title'] as String? ?? 'Risiko Rendah';
              final riskCode = (riskLevelMap?['code'] as String? ?? 'LOW').toUpperCase();
              final recommendation = riskLevelMap?['recommendation'] as String? ?? '';
              final symptomDetails = item['symptomDetails'] as List<dynamic>? ?? [];

              // Only show symptoms where the user answered yes (cfValue > 0)
              final positiveSymptoms = symptomDetails
                  .where((s) => ((s['cfValue'] as num?)?.toDouble() ?? 0.0) > 0.0)
                  .toList();

              // Risk-coded colors
              Color themeColor = AppColors.primary;
              IconData riskIcon = Icons.check_circle_outline_rounded;
              if (riskCode == 'HIGH') {
                themeColor = AppColors.destructive;
                riskIcon = Icons.error_outline_rounded;
              } else if (riskCode == 'MEDIUM') {
                themeColor = AppColors.warning;
                riskIcon = Icons.warning_amber_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row: TB Type name + risk badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  tbTypeName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.foreground,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: themeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(riskIcon, color: themeColor, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$scorePercent%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: themeColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            riskTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: themeColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Score progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(
                                  height: 6,
                                  width: double.infinity,
                                  color: AppColors.muted.withOpacity(0.25),
                                ),
                                FractionallySizedBox(
                                  widthFactor: (totalScore / 100).clamp(0.0, 1.0),
                                  child: Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [themeColor.withOpacity(0.7), themeColor],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Detected symptoms chips
                          if (positiveSymptoms.isNotEmpty) ...[
                            const Text(
                              'GEJALA TERDETEKSI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.mutedForeground,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: positiveSymptoms.map((s) {
                                final name = s['symptomName'] as String? ?? '';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: themeColor.withOpacity(0.12)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: themeColor, size: 11),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: themeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                          ] else ...[
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    color: AppColors.primary.withOpacity(0.6), size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  'Tidak ada gejala terdeteksi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Recommendation card
                          if (recommendation.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: themeColor.withOpacity(0.08)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded,
                                      color: themeColor, size: 15),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      recommendation,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.foreground
                                            .withOpacity(0.75),
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.home, (route) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: const Text(
              'Kembali ke Beranda',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ─── QUICK CHECK SINGLE RESULT CARD ──────────────────────
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
                            const SizedBox(height: 14),
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
                const SizedBox(height: 24),
                if (_currentRisk != RiskLevel.low) ...[
                  _buildButton(
                    'Lanjutkan Pemeriksaan Lengkap',
                    mainColor,
                    Colors.white,
                    true,
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.fullAssessment),
                  ),
                  const SizedBox(height: 10),
                  _buildButton(
                    'Cari Klinik Terdekat',
                    Colors.transparent,
                    mainColor,
                    false,
                    borderColor: mainColor.withOpacity(0.2),
                    onPressed: () {},
                  ),
                  const SizedBox(height: 10),
                ],
                _buildButton(
                  'Kembali ke Beranda',
                  _currentRisk == RiskLevel.low ? Colors.white : Colors.transparent,
                  _currentRisk == RiskLevel.low ? mainColor : AppColors.mutedForeground,
                  false,
                  borderColor: _currentRisk == RiskLevel.low
                      ? mainColor.withOpacity(0.2)
                      : AppColors.muted.withOpacity(0.3),
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, AppRoutes.home, (route) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color bgColor, Color textColor, bool hasShadow,
      {Color? borderColor, VoidCallback? onPressed}) {
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        Positioned(
            top: -50,
            right: -50,
            child: _buildAura(150, color.withOpacity(0.2))),
        Positioned(
            top: sh * 0.3,
            left: -100,
            child: _buildAura(180, color.withOpacity(0.1))),
        Positioned(
            bottom: 100,
            right: 20,
            child: _buildAura(100, AppColors.muted.withOpacity(0.2))),
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

// ─── GAUGE PAINTER ─────────────────────────────────────────
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
