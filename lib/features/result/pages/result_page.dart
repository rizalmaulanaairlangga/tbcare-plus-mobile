import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/models/assessment_config_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_utils.dart';
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
  Map<String, dynamic>? _assessmentData;
  bool _isFullAssessment = false;
  Map<String, dynamic>? _fullResultData;
  bool _isGuest = true;
  String? _userName;
  String? _profilePicture;
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
          StorageService.lastAssessmentResult = _fullResultData;
        } else {
          _currentRisk = raw['riskLevel'] as RiskLevel? ?? RiskLevel.low;
          _percentage = (raw['percentage'] as int?) ?? _percentage;
          _isGuest = (raw['isGuest'] as bool?) ?? true;
          _assessmentData = raw['assessmentData'] as Map<String, dynamic>?;
        }
      } else if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.home,
          arguments: {'isGuest': true},
        );
        return;
      }
      final loggedIn = await StorageService.isLoggedIn();
      final user = loggedIn ? await StorageService.getUser() : null;
      if (!mounted) return;
      setState(() {
        _isGuest = !loggedIn;
        _userName = user?.fullName;
        _profilePicture = user?.profilePicture;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _openSymptomInsight(Color mainColor, IconData riskIcon) async {
    if (_assessmentData == null) return;

    // Authenticated: hand off to HistoryDetailPage with `requiresOnline`, which
    // fetches the canonical session online and shows a full-page handler if
    // offline. No local loading dialog here (avoids a spinner that could hang on
    // an offline fetch — the original infinite-loading bug).
    if (!_isGuest) {
      Navigator.pushNamed(
        context,
        AppRoutes.historyDetail,
        arguments: {
          'sessionKey': '',
          'requiresOnline': true,
          'date': 'Sekarang',
          'riskLevel': _assessmentData!['riskTitle'] ?? 'Risiko Rendah',
          'riskLevelCode': _assessmentData!['riskCode'] ?? 'LOW',
          'percentage': '$_percentage%',
          'tbType': '',
          'type': 'Cek Cepat',
          'color': mainColor,
          'icon': riskIcon,
          'detailData': null,
        },
      );
      return;
    }

    // Guest: reconstruct locally (no network needed — the config falls back to
    // the bundled offline asset).
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Map<String, dynamic>? detail;
    try {
      final config = await AssessmentApiService.fetchQuickCheckConfig();
      final symptoms =
          _assessmentData!['symptoms'] as Map<String, dynamic>? ?? {};
      final Map<int, List<Map<String, dynamic>>> byTbType = {};
      final Map<int, String> tbTypeNames = {};

      for (final q in config.questions) {
        final selected = symptoms[q.symptomId.toString()] == true;
        if (!selected) continue;

        // Mimic backend logic: distribute to all applicable TB types
        final targets = q.applicableTbTypes.isNotEmpty
            ? q.applicableTbTypes
            : [
                TbTypeWeight(
                  tbTypeId: q.tbTypeId,
                  tbTypeName: q.tbTypeName ?? '',
                  weight: q.weight,
                ),
              ];

        for (final t in targets) {
          tbTypeNames[t.tbTypeId] = t.tbTypeName;
          byTbType.putIfAbsent(t.tbTypeId, () => []).add({
            'symptomName': q.symptomName,
            'symptomCode': q.symptomCode,
            'symptomDescription': q.symptomDescription,
            'cfValue': 1.0,
            'tbTypeId': q.tbTypeId,
          });
        }
      }

      if (byTbType.isNotEmpty) {
        final items = <Map<String, dynamic>>[];
        for (final entry in byTbType.entries) {
          final typeId = entry.key;
          items.add({
            'primaryTbTypeId': typeId,
            'primaryTbTypeName': tbTypeNames[typeId] ?? 'Unknown',
            'totalScore': _percentage,
            'riskLevelTitle': _assessmentData!['riskTitle'] ?? 'Risiko Rendah',
            'riskLevelCode': _assessmentData!['riskCode'] ?? 'LOW',
            'selectedSymptoms': entry.value,
            'scoreBreakdown': {
              'results': [
                {
                  'riskLevel': {
                    'recommendation': _assessmentData!['description'] ?? '',
                  },
                },
              ],
            },
          });
        }
        detail = {
          'items': items,
          'createdAt': DateTime.now().toIso8601String(),
          'assessmentTypeName': 'Quick Assessment',
        };
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.historyDetail,
      arguments: {
        'sessionKey': '',
        'requiresOnline': false,
        'date': 'Sekarang',
        'riskLevel': _assessmentData!['riskTitle'] ?? 'Risiko Rendah',
        'riskLevelCode': _assessmentData!['riskCode'] ?? 'LOW',
        'percentage': '$_percentage%',
        'tbType': '',
        'type': 'Cek Cepat',
        'color': mainColor,
        'icon': riskIcon,
        'detailData': detail,
      },
    );
  }

  Map<String, dynamic> _getRiskData() {
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
        description =
            dbDescription ??
            'Gejala Anda saat ini tidak secara kuat mengindikasikan TBC. Jaga kesehatan dan pantau kondisi Anda.';
        color = AppColors.primary;
        icon = Icons.check_circle_outline;
        break;
      case RiskLevel.medium:
        title = dbTitle ?? 'Medium Risk';
        subtitle = 'Beberapa gejala memerlukan perhatian';
        description =
            dbDescription ??
            'Anda menunjukkan beberapa gejala terkait TBC. Disarankan untuk melanjutkan dengan pemeriksaan yang lebih detail.';
        color = AppColors.warning;
        icon = Icons.info_outline;
        break;
      case RiskLevel.high:
        title = dbTitle ?? 'High Risk';
        subtitle = 'Indikasi kuat gejala TBC';
        description =
            dbDescription ??
            'Gejala Anda sangat mengindikasikan potensi TBC. Silakan lanjutkan dengan pemeriksaan lengkap dan cari bantuan medis.';
        color = AppColors.destructive;
        icon = Icons.report_problem_outlined;
        break;
    }
    return {
      'percentage': _percentage,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'color': color,
      'icon': icon,
      'auraColor': color.withValues(alpha: 0.1),
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
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildScatteredAuras(sw, sh),
          _isFullAssessment && _fullResultData != null
              ? _buildFullResultView()
              : _buildQuickResultView(),
        ],
      ),
      bottomNavigationBar: _isGuest
          ? const GuestBottomNav(currentIndex: -1)
          : AppBottomNav(
              currentIndex: 0,
              onTap: (i) {
                final routes = [
                  AppRoutes.home,
                  AppRoutes.history,
                  AppRoutes.profile,
                ];
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

  Widget _buildQuickResultView() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            HomeHeader(
              isGuest: _isGuest,
              userName: _userName ?? StorageService.cachedUser?.fullName,
              profilePicture:
                  _profilePicture ?? StorageService.cachedUser?.profilePicture,
            ),
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
    );
  }

  Widget _buildFullResultView() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              isGuest: _isGuest,
              userName: _userName ?? StorageService.cachedUser?.fullName,
              profilePicture:
                  _profilePicture ?? StorageService.cachedUser?.profilePicture,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hasil Pemeriksaan Lengkap',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.foreground,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hasil pemeriksaan mendetail berdasarkan gejala yang Anda pilih.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final sortedResults = List<Map<String, dynamic>>.from(
                (_fullResultData!['results'] as List)
                    .cast<Map<String, dynamic>>(),
              );
              sortedResults.sort((a, b) {
                String? codeOf(Map<String, dynamic> m) {
                  final rl = m['riskLevel'] as Map<String, dynamic>?;
                  return rl?['code'] as String?;
                }

                final ra = _riskRank(codeOf(a));
                final rb = _riskRank(codeOf(b));
                if (ra != rb) return rb.compareTo(ra);
                final sa = (a['totalScore'] as num?)?.toDouble() ?? 0;
                final sb = (b['totalScore'] as num?)?.toDouble() ?? 0;
                return sb.compareTo(sa);
              });
              final result = sortedResults[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _buildCategoryResultCard(result),
              );
            }, childCount: (_fullResultData!['results'] as List).length),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _goHome,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Kembali ke Beranda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: {'isGuest': _isGuest},
    );
  }

  int _riskRank(String? code) {
    final c = (code ?? '').toUpperCase();
    if (c.contains('HIGH')) return 3;
    if (c.contains('MEDIUM') || c.contains('MODERATE')) return 2;
    return 1;
  }

  Widget _buildCategoryResultCard(Map<String, dynamic> result) {
    final title = result['tbTypeName'] ?? 'Unknown';
    final score = (result['totalScore'] as num?)?.toInt() ?? 0;
    final riskLevel = result['riskLevel'] as Map<String, dynamic>?;
    final riskTitle = riskLevel?['title'] ?? 'Risiko Rendah';
    final riskCode = (riskLevel?['code'] ?? 'LOW').toString().toUpperCase();
    Color color;
    IconData riskIcon;
    if (riskCode.contains('HIGH')) {
      color = AppColors.destructive;
      riskIcon = Icons.error_outline_rounded;
    } else if (riskCode.contains('MEDIUM') || riskCode.contains('MODERATE')) {
      color = AppColors.warning;
      riskIcon = Icons.warning_amber_rounded;
    } else {
      color = AppColors.primary;
      riskIcon = Icons.check_circle_outline_rounded;
    }
    final symptoms =
        (result['symptomDetails'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final selectedSymptoms = symptoms
        .where((s) => (s['cfValue'] as num?)?.toDouble() == 1.0)
        .toList();
    final containerColor = color.withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$riskTitle',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(riskIcon, color: color, size: 28),
                ],
              ),
            ],
          ),
          if (selectedSymptoms.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSymptomGroups(
              selectedSymptoms,
              color,
              result['tbTypeId'] as int? ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSymptomGroups(
    List<Map<String, dynamic>> symptoms,
    Color color,
    int currentTbTypeId,
  ) {
    final umum = symptoms.where((s) {
      final code = (s['symptomCode'] as String?) ?? '';
      if (!code.startsWith('G')) return false;
      final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
      final numPart = int.tryParse(digits);
      return numPart != null &&
          numPart >= 1 &&
          numPart <= 8 &&
          !code.contains(RegExp(r'[a-z]'));
    }).toList();
    final khusus = symptoms.where((s) {
      final code = (s['symptomCode'] as String?) ?? '';
      if (!code.startsWith('G')) return true;
      final digits = code.replaceAll(RegExp(r'[^0-9]'), '');
      final numPart = int.tryParse(digits);
      return numPart == null ||
          numPart > 8 ||
          code.contains(RegExp(r'[a-z]'));
    }).toList();
    final isTbType1 = currentTbTypeId == 1;

    if (isTbType1) {
      // No separation for tb_type=1, show all selected symptoms
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gejala dipilih (${symptoms.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedForeground.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          ...symptoms.map((s) => _buildSymptomChip(s, color)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (umum.isNotEmpty) ...[
          Text(
            'Gejala Umum (${umum.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedForeground.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          ...umum.map((s) => _buildSymptomChip(s, color)),
          if (khusus.isNotEmpty) const SizedBox(height: 16),
        ],
        if (khusus.isNotEmpty) ...[
          Text(
            'Gejala Khusus (${khusus.length})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedForeground.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          ...khusus.map((s) => _buildSymptomChip(s, color)),
        ],
      ],
    );
  }

  Widget _buildSymptomChip(Map<String, dynamic> s, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            s['symptomName'] ?? '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildResultCard(Map<String, dynamic> data) {
    Color mainColor = data['color'];
    final pct = data['percentage'] as int;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: mainColor.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              width: 250,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CustomPaint(
                    size: const Size(250, 125),
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
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: AppColors.foreground,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(data['icon'] as IconData, color: mainColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  data['title'] as String,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data['subtitle'] as String,
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
                color: mainColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: mainColor.withValues(alpha: 0.1)),
              ),
              child: Text(
                data['description'] as String,
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
              _buildClinicFinderButton(mainColor),
              const SizedBox(height: 10),
            ],
            _buildButton(
              'Lihat Insight Gejala',
              Colors.transparent,
              mainColor,
              false,
              borderColor: mainColor.withValues(alpha: 0.2),
              onPressed: () =>
                  _openSymptomInsight(mainColor, data['icon'] as IconData),
            ),
            const SizedBox(height: 10),
            _buildButton(
              'Kembali ke Beranda',
              _currentRisk == RiskLevel.low ? Colors.white : Colors.transparent,
              _currentRisk == RiskLevel.low
                  ? mainColor
                  : AppColors.mutedForeground,
              false,
              borderColor: _currentRisk == RiskLevel.low
                  ? mainColor.withValues(alpha: 0.2)
                  : AppColors.muted.withValues(alpha: 0.3),
              onPressed: _goHome,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicFinderButton(Color color) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.15),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: ElevatedButton(
        onPressed: () => UrlUtils.launchNearestClinicMap(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              'Cari Faskes Terdekat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.open_in_new_rounded,
              color: color.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
    String text,
    Color bgColor,
    Color textColor,
    bool hasShadow, {
    Color? borderColor,
    VoidCallback? onPressed,
  }) {
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
                  color: bgColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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

  Widget _buildScatteredAuras(double sw, double sh) => Stack(
    children: [
      Positioned(
        top: -sw * 0.05,
        right: -sw * 0.2,
        child: _buildAura(200, AppColors.primary.withValues(alpha: 0.08)),
      ),
      Positioned(
        top: sh * 0.25,
        left: -sw * 0.15,
        child: _buildAura(175, AppColors.secondary.withValues(alpha: 0.05)),
      ),
    ],
  );

  Widget _buildAura(double size, Color color) => Container(
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

class GaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  GaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    paint.color = color.withValues(alpha: 0.15);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      paint,
    );
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * percentage.clamp(0.0, 1.0),
      false,
      paint,
    );
    final angle = math.pi + math.pi * percentage.clamp(0.0, 1.0);
    final dot = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(dot, 7, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
