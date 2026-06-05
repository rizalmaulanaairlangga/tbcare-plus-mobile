import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/models/assessment_config_models.dart';
import '../../../core/utils/network_exception.dart';

class FullAssessmentPage extends StatefulWidget {
  const FullAssessmentPage({super.key});
  @override
  State<FullAssessmentPage> createState() => _FullAssessmentPageState();
}

class _FullAssessmentPageState extends State<FullAssessmentPage> {
  QuickCheckConfig? _config;
  bool _loading = true;
  String? _error;
  bool _isCheckingAuth = true;
  bool _isLoggedIn = false;
  final Map<int, bool> _answerStates = {};
  int _currentStep = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _initSessionAndLoad();
  }

  Future<void> _initSessionAndLoad() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isCheckingAuth = false;
      _isLoggedIn = loggedIn;
    });
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await AssessmentApiService.fetchFullAssessmentConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        for (final q in config.questions) {
          _answerStates[q.questionId] = false;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<int, List<QuickCheckQuestion>> get _questionsByTbType {
    if (_config == null) return {};
    final map = <int, List<QuickCheckQuestion>>{};
    for (final q in _config!.questions) {
      map.putIfAbsent(q.tbTypeId, () => []).add(q);
    }
    return map;
  }

  List<int> get _tbTypeIds => _questionsByTbType.keys.toList();
  int get _totalSteps => _tbTypeIds.length;
  bool get _isFirstStep => _currentStep == 0;
  bool get _isLastStep => _currentStep == _totalSteps - 1;
  int _currentTbTypeId() => _tbTypeIds[_currentStep];
  List<QuickCheckQuestion> _currentQuestions() =>
      _questionsByTbType[_currentTbTypeId()] ?? [];

  String _categoryName(int tbTypeId) {
    if (_config == null) return '';
    final first = _config!.questions.firstWhere(
      (q) => q.tbTypeId == tbTypeId,
      orElse: () => _config!.questions.first,
    );
    return first.tbTypeName ?? 'Kategori $tbTypeId';
  }

  IconData _iconForTbType(int tbTypeId) {
    final name = _categoryName(tbTypeId).toLowerCase();
    if (name.contains('paru') ||
        name.contains('pulmonary') ||
        name.contains('pernapasan') ||
        name.contains('respiratory') ||
        name.contains('lung') ||
        name.contains('dada') ||
        name.contains('thorax')) {
      return Icons.air_outlined;
    }
    if (name.contains('kelenjar') ||
        name.contains('lymph') ||
        name.contains('getah')) {
      return Icons.medication_liquid_outlined;
    }
    if (name.contains('tulang') ||
        name.contains('bone') ||
        name.contains('skeletal') ||
        name.contains('sendi') ||
        name.contains('joint')) {
      return Icons.accessibility_new_rounded;
    }
    if (name.contains('otak') ||
        name.contains('brain') ||
        name.contains('saraf') ||
        name.contains('nerve') ||
        name.contains('neuro')) {
      return Icons.psychology_outlined;
    }
    if (name.contains('usus') ||
        name.contains('intestine') ||
        name.contains('perut') ||
        name.contains('abdomen') ||
        name.contains('pencernaan') ||
        name.contains('gastro')) {
      return Icons.restaurant_outlined;
    }
    if (name.contains('hati') ||
        name.contains('liver') ||
        name.contains('hepar')) {
      return Icons.favorite_border_outlined;
    }
    if (name.contains('ginjal') ||
        name.contains('kidney') ||
        name.contains('renal') ||
        name.contains('urinary')) {
      return Icons.water_drop_outlined;
    }
    if (name.contains('kulit') ||
        name.contains('skin') ||
        name.contains('dermal')) {
      return Icons.waves_outlined;
    }
    if (name.contains('mata') ||
        name.contains('eye') ||
        name.contains('ocular')) {
      return Icons.visibility_outlined;
    }
    if (name.contains('jantung') ||
        name.contains('heart') ||
        name.contains('cardiac')) {
      return Icons.favorite_outlined;
    }
    return Icons.coronavirus_outlined;
  }

  int get _totalAnsweredAll => _answerStates.values.where((v) => v).length;
  int get _totalQuestionsAll => _config?.questions.length ?? 0;

  void _goToNextStep() {
    if (_isLastStep) {
      _onSubmit();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _goToPrevStep() {
    if (!_isFirstStep) setState(() => _currentStep--);
  }

  Future<void> _onSubmit() async {
    if (_totalAnsweredAll == 0 || _config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih minimal satu gejala.'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      // Only logged-in users need the network — they must persist the result
      // to the backend. Guests submit fully locally; the fallback config now
      // carries real Indonesian copy so an offline guest still gets a proper
      // result page.
      if (_isLoggedIn) {
        final online = await ConnectivityService.isOnline();
        if (!online) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Anda sedang offline. Periksa koneksi internet Anda lalu coba lagi.',
                ),
                backgroundColor: AppColors.destructive,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
      // Compute per-TB-type sums using applicableTbTypes for cross-type contribution
      final Map<int, double> sumByTbType = {};
      final Map<int, String> tbTypeNames = {};
      final Map<int, List<Map<String, dynamic>>> symptomsByTbType = {};

      for (final q in _config!.questions) {
        final isSelected = _answerStates[q.questionId] ?? false;
        final cfValue = isSelected ? 1.0 : 0.0;

        // Collect TB type names from applicableTbTypes and primary
        for (final tw in q.applicableTbTypes) {
          tbTypeNames[tw.tbTypeId] = tw.tbTypeName;
        }
        tbTypeNames[q.tbTypeId] = q.tbTypeName ?? 'Kategori ${q.tbTypeId}';

        if (!isSelected) continue;

        final targets = q.applicableTbTypes.isNotEmpty
            ? q.applicableTbTypes
            : [
                TbTypeWeight(
                  tbTypeId: q.tbTypeId,
                  tbTypeName: q.tbTypeName ?? '',
                  weight: q.weight,
                ),
              ];

        for (final tw in targets) {
          sumByTbType[tw.tbTypeId] =
              (sumByTbType[tw.tbTypeId] ?? 0) + tw.weight;
          symptomsByTbType.putIfAbsent(tw.tbTypeId, () => []).add({
            'symptomName': q.symptomName,
            'symptomCode': q.symptomCode,
            'symptomDescription': q.symptomDescription,
            'cfValue': cfValue,
            'originTbTypeId': q.tbTypeId,
          });
        }
      }

      final results = <Map<String, dynamic>>[];
      for (final entry in sumByTbType.entries) {
        final tbTypeId = entry.key;
        final sum = entry.value;
        final combinedCF = 1.0 - exp(-_config!.saturationK * sum);
        final percentage = (combinedCF * 100).round().toDouble();
        final matchedLevel = _config!.findRiskLevel(percentage, tbTypeId);
        results.add({
          'tbTypeId': tbTypeId,
          'tbTypeName': tbTypeNames[tbTypeId] ?? 'Kategori $tbTypeId',
          'tbTypeCode': 'TB$tbTypeId',
          'totalScore': percentage,
          'riskLevel': matchedLevel != null
              ? {
                  'title': matchedLevel.title,
                  'code': matchedLevel.code,
                  'description': matchedLevel.description ?? '',
                  'recommendation': matchedLevel.recommendation ?? '',
                }
              : {
                  'title': 'Risiko Rendah',
                  'code': 'LOW',
                  'description': '',
                  'recommendation': '',
                },
          'symptomDetails': symptomsByTbType[tbTypeId] ?? [],
        });
      }
      final result = {'results': results};
      if (!mounted) return;
      if (!_isLoggedIn) {
        Map<String, dynamic>? highestRiskResult;
        double highestScore = -1;
        for (final r in results) {
          final score = (r['totalScore'] as num).toDouble();
          if (score > highestScore) {
            highestScore = score;
            highestRiskResult = r;
          }
        }
        if (highestRiskResult != null) {
          final riskLevel =
              highestRiskResult['riskLevel'] as Map<String, dynamic>?;
          final symptoms = <String, bool>{};
          _answerStates.forEach((k, v) => symptoms[k.toString()] = v);
          StorageService.guestSessionResult = {
            'riskLevel': riskLevel?['code'] ?? 'LOW',
            'percentage': highestRiskResult['totalScore']?.toInt() ?? 0,
            'riskCode': riskLevel?['code'] ?? 'LOW',
            'riskTitle': riskLevel?['title'] ?? 'Risiko Rendah',
            'description': riskLevel?['description'] ?? '',
            'type': 'FULL ASSESSMENT',
            'symptoms': symptoms,
            'fullResults': results,
          };
        }
      }
      final answers = _config!.questions
          .map(
            (q) => {
              'questionId': q.questionId,
              'cfValue': (_answerStates[q.questionId] ?? false) ? 1.0 : 0.0,
            },
          )
          .toList();

      // Gate 2: logged-in users must persist to backend *before* the result
      // page is shown. Otherwise the user sees a result that's not retrievable
      // from history later.
      if (_isLoggedIn) {
        try {
          await AssessmentApiService.submitAssessment(
            assessmentTypeId: 2,
            answers: answers,
          );
        } catch (e) {
          if (mounted) {
            final msg = NetworkException.from(e).userMessage;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: AppColors.destructive,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        // Mitigation: seed the recent-assessment cache from the submit
        // payload itself, picking the highest-risk per-type result. This way
        // the home card on next open has data even if backend fetch fails.
        Map<String, dynamic>? highest;
        double highestScore = -1;
        for (final r in results) {
          final score = (r['totalScore'] as num).toDouble();
          if (score > highestScore) {
            highestScore = score;
            highest = r;
          }
        }
        final user = await StorageService.getUser();
        if (highest != null && user?.id != null && user!.id.isNotEmpty) {
          final riskLevel = highest['riskLevel'] as Map<String, dynamic>?;
          await StorageService.saveCachedRecentAssessment(user.id, {
            'createdAt': DateTime.now().toIso8601String(),
            'assessmentTypeId': 2,
            'assessmentTypeName': 'Full Assessment',
            'riskLevelCode': riskLevel?['code'] ?? 'LOW',
            'riskLevelTitle': riskLevel?['title'] ?? 'Risiko Rendah',
            'totalScore': (highest['totalScore'] as num).toInt(),
            'primaryTbTypeName': highest['tbTypeName'] ?? '',
          });
        }
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.result,
        arguments: {
          'isFullAssessment': true,
          'isGuest': !_isLoggedIn,
          'result': result,
        },
      );
    } catch (e) {
      if (mounted) {
        final msg = NetworkException.from(e).userMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildScatteredAuras(sw, sh),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                if (!_loading && _error == null) _buildProgressBar(),
                if (!_loading && _error == null) _buildCurrentTbTypeLabel(),
                Expanded(
                  child: _isCheckingAuth
                      ? const Center(child: CircularProgressIndicator())
                      : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? _buildErrorContent()
                      : _buildStepContent(),
                ),
                if (!_loading && _error == null) _buildWizardBottomBar(),
              ],
            ),
          ),
          if (_submitting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.destructive,
          ),
          const SizedBox(height: 16),
          const Text(
            'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Terjadi kesalahan tidak diketahui',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadConfig,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Row(
      children: List.generate(_totalSteps, (i) {
        final isCompleted = i <= _currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i > 0 ? 4 : 0,
              right: i < _totalSteps - 1 ? 4 : 0,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : AppColors.muted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _buildCurrentTbTypeLabel() {
    final tbTypeId = _currentTbTypeId();
    final name = _categoryName(tbTypeId);
    final icon = _iconForTbType(tbTypeId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${_currentStep + 1}/$_totalSteps',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 14,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final tbTypeId = _currentTbTypeId();
    final questions = _currentQuestions();
    final title = _categoryName(tbTypeId);
    final icon = _iconForTbType(tbTypeId);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildWizardSectionCard(tbTypeId, questions, icon, title),
        ],
      ),
    );
  }

  Widget _buildWizardSectionCard(
    int tbTypeId,
    List<QuickCheckQuestion> questions,
    IconData icon,
    String title,
  ) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: questions.map((q) {
          final isSelected = _answerStates[q.questionId] ?? false;
          final sIcon = getSymptomIcon(q.symptomCode);
          return _buildToggleItem(
            q.questionId,
            sIcon,
            q.questionText,
            isSelected,
          );
        }).toList(),
      ),
    ),
  );

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.foreground,
              size: 20,
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'Pemeriksaan Kesehatan Lengkap',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_totalAnsweredAll/$_totalQuestionsAll TERJAWAB',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );

  Widget _buildWizardBottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isFirstStep ? null : _goToPrevStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Kembali'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                  side: BorderSide(
                    color: _isFirstStep
                        ? AppColors.muted.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _goToNextStep,
                icon: Icon(
                  _isLastStep
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _isLastStep ? 'Kirim' : 'Lanjut',
                  style: const TextStyle(
                    fontSize: 15,
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
          ),
        ],
      ),
    ),
  );

  Widget _buildToggleItem(
    int questionId,
    IconData icon,
    String label,
    bool isSelected,
  ) => GestureDetector(
    onTap: () => setState(() {
      _answerStates[questionId] = !isSelected;
    }),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.mutedForeground,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.foreground,
                height: 1.4,
              ),
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: (val) => setState(() {
              _answerStates[questionId] = val;
            }),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.muted,
          ),
        ],
      ),
    ),
  );

  Widget _buildScatteredAuras(double sw, double sh) => Stack(
    children: [
      Positioned(
        top: -sw * 0.05,
        right: -sw * 0.1,
        child: _buildAura(175, AppColors.primary.withValues(alpha: 0.08)),
      ),
      Positioned(
        top: sh * 0.3,
        left: -sw * 0.2,
        child: _buildAura(150, AppColors.secondary.withValues(alpha: 0.04)),
      ),
      Positioned(
        bottom: sh * 0.2,
        right: sw * 0.1,
        child: _buildAura(125, AppColors.muted.withValues(alpha: 0.15)),
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

IconData getSymptomIcon(String code) {
  final c = code.toUpperCase();
  if (c.startsWith('G01')) return Icons.air_outlined;
  if (c.startsWith('G02')) return Icons.water_drop_outlined;
  if (c.startsWith('G03')) return Icons.thermostat_outlined;
  if (c.startsWith('G04')) return Icons.waves_outlined;
  if (c.startsWith('G05')) return Icons.no_food_outlined;
  if (c.startsWith('G06')) return Icons.monitor_weight_outlined;
  if (c.startsWith('G07')) return Icons.battery_alert_outlined;
  if (c.startsWith('G08')) return Icons.nightlight_outlined;
  if (c.startsWith('G09')) return Icons.commit_rounded;
  if (c.startsWith('G10')) return Icons.local_fire_department_outlined;
  if (c.startsWith('G11')) return Icons.open_with_rounded;
  if (c.startsWith('G12')) return Icons.fingerprint_rounded;
  if (c.startsWith('G13')) return Icons.zoom_in_rounded;
  if (c.startsWith('G14')) return Icons.opacity_rounded;
  if (c.startsWith('G15')) return Icons.healing_rounded;
  if (c.startsWith('G16')) return Icons.adjust_rounded;
  if (c.startsWith('G17')) return Icons.sensors_off_rounded;
  if (c.startsWith('G18')) return Icons.local_fire_department_outlined;
  if (c.startsWith('G19')) return Icons.accessibility_new_rounded;
  if (c.startsWith('G20')) return Icons.directions_walk_rounded;
  if (c.startsWith('G21')) return Icons.do_not_disturb_on_rounded;
  if (c.startsWith('G22')) return Icons.bedtime_outlined;
  if (c.startsWith('G23')) return Icons.blur_on_rounded;
  return Icons.help_outline;
}
