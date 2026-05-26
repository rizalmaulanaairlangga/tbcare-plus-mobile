import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/guest_bottom_nav.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/models/assessment_config_models.dart';

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

  // Track checked state by questionId
  final Map<int, bool> _answerStates = {};

  // Section expansion states
  final Map<int, bool> _sectionExpanded = {};

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

    // Guest users are allowed to run full assessment; only saving to history requires login.
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
        final categories = _questionsByTbType.keys.toList();
        for (int i = 0; i < categories.length; i++) {
          _sectionExpanded[i] = true;
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

  // Group questions by tbTypeId
  Map<int, List<QuickCheckQuestion>> get _questionsByTbType {
    if (_config == null) return {};
    final map = <int, List<QuickCheckQuestion>>{};
    for (final q in _config!.questions) {
      map.putIfAbsent(q.tbTypeId, () => []).add(q);
    }
    return map;
  }

  String _categoryName(int tbTypeId) {
    if (_config == null) return '';
    final first = _config!.questions.firstWhere(
      (q) => q.tbTypeId == tbTypeId,
      orElse: () => _config!.questions.first,
    );
    return first.tbTypeName ?? 'Kategori $tbTypeId';
  }

  int get _answeredCount {
    return _answerStates.values.where((v) => v).length;
  }

  int get _totalQuestions {
    return _config?.questions.length ?? 0;
  }

  Future<void> _onSubmit() async {
    if (_answeredCount == 0 || _config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih minimal satu gejala.'),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final grouped = _questionsByTbType;
      final results = <Map<String, dynamic>>[];

      grouped.forEach((tbTypeId, questions) {
        double sum = 0.0;
        final symptomDetails = <Map<String, dynamic>>[];

        for (final q in questions) {
          final isSelected = _answerStates[q.questionId] ?? false;
          final cfValue = isSelected ? 1.0 : 0.0;
          if (isSelected) {
            sum += q.weight;
          }
          symptomDetails.add({
            'symptomName': q.symptomName,
            'cfValue': cfValue,
          });
        }

        final combinedCF = 1.0 - exp(-_config!.saturationK * sum);
        final percentage = (combinedCF * 100).round().toDouble();
        final matchedLevel = _config!.findRiskLevel(percentage, tbTypeId);

        results.add({
          'tbTypeName': questions.first.tbTypeName ?? 'Kategori $tbTypeId',
          'tbTypeCode': questions.first.symptomCode.split('_').first,
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
          'symptomDetails': symptomDetails,
        });
      });

      final result = {
        'results': results,
      };

      if (!mounted) return;

      // Persist assessment answers to backend history.
      final answers = _config!.questions
          .map((q) => {
                'questionId': q.questionId,
                'cfValue': (_answerStates[q.questionId] ?? false) ? 1.0 : 0.0,
              })
          .toList();

      if (_isLoggedIn) {
        try {
          await AssessmentApiService.submitAssessment(
            assessmentTypeId: 2,
            answers: answers,
          );
        } catch (e) {
          // Don't block user flow if history save fails, but log for debugging.
          // ignore: avoid_print
          print('submitAssessment(full) failed: $e');
        }
      }
      
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: AppColors.destructive,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Auras
          _buildScatteredAuras(screenWidth, screenHeight),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header with back button + title
                _buildHeader(context),

                // Scrollable Content
                Expanded(
                  child: _isCheckingAuth
                      ? const Center(child: CircularProgressIndicator())
                      : _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? _buildErrorContent()
                              : _buildAssessmentContent(),
                ),
              ],
            ),
          ),
          if (_submitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isLoggedIn
          ? AppBottomNav(
              currentIndex: -1,
              onTap: (i) {
                final routes = [AppRoutes.home, AppRoutes.history, AppRoutes.profile];
                if (i < routes.length) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    routes[i],
                    (route) => false,
                    arguments: {'isGuest': false},
                  );
                }
              },
            )
          : const GuestBottomNav(currentIndex: -1),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.destructive),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.foreground),
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
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentContent() {
    final grouped = _questionsByTbType;
    final tbTypeIdsList = grouped.keys.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          // Info Banner
          _buildInfoBanner(),
          const SizedBox(height: 20),

          // Render categories dynamically
          ...tbTypeIdsList.asMap().entries.map((entry) {
            final idx = entry.key;
            final tbTypeId = entry.value;
            final questions = grouped[tbTypeId] ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCategorySection(idx, tbTypeId, questions),
            );
          }),

          const SizedBox(height: 8),

          // Submit Button
          _buildSubmitSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCategorySection(int index, int tbTypeId, List<QuickCheckQuestion> questions) {
    final title = _categoryName(tbTypeId);
    final subtitle = 'Gejala dan indikasi $title';

    // All forms now consistently use Toggle switches (_buildToggleItem)
    Widget content = Column(
      children: questions.map((q) {
        final isSelected = _answerStates[q.questionId] ?? false;
        final icon = getSymptomIcon(q.symptomCode);
        return _buildToggleItem(q.questionId, icon, q.questionText, isSelected);
      }).toList(),
    );

    final categoryIcons = [
      Icons.air_outlined,
      Icons.commit_rounded,
      Icons.radio_button_unchecked,
      Icons.accessibility_new_rounded,
    ];
    final sectionIcon = categoryIcons[index % categoryIcons.length];

    return _buildSectionCard(
      sectionIndex: index,
      icon: sectionIcon,
      title: title,
      subtitle: subtitle,
      content: content,
    );
  }

  // ─── HEADER ───────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: AppColors.foreground, size: 20),
            ),
          ),

          // Title + Badge (Centered)
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '$_answeredCount/$_totalQuestions TERJAWAB',
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

          // Spacer to balance back button
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ─── INFO BANNER ──────────────────────────────────────────
  Widget _buildInfoBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Silakan jawab setiap gejala berdasarkan kondisi Anda saat ini untuk hasil pemeriksaan yang paling akurat.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SECTION WRAPPER ──────────────────────────────────────
  Widget _buildSectionCard({
    required int sectionIndex,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    bool isExpanded = _sectionExpanded[sectionIndex] ?? true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Section Header
              GestureDetector(
                onTap: () {
                  setState(() {
                    _sectionExpanded[sectionIndex] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content (animated)
              AnimatedCrossFade(
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: content,
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 300),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Style 1: Toggle switches
  Widget _buildToggleItem(int questionId, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answerStates[questionId] = !isSelected;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
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
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.muted.withOpacity(0.4),
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
              onChanged: (val) {
                setState(() {
                  _answerStates[questionId] = val;
                });
              },
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withOpacity(0.3),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  // Style 2: Checkboxes
  Widget _buildCheckboxItem(int questionId, String label, bool isChecked, {bool showDivider = true}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answerStates[questionId] = !isChecked;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5)))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isChecked ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? AppColors.primary : AppColors.mutedForeground.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: isChecked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isChecked ? AppColors.primary : AppColors.foreground,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Style 3: Grid card items
  Widget _buildGridCard(int questionId, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answerStates[questionId] = !isSelected;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.2)
                      : AppColors.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.mutedForeground,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Style 4: Chips
  Widget _buildChip(int questionId, IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _answerStates[questionId] = !isSelected;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.mutedForeground,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SUBMIT BUTTON ────────────────────────────────────────
  Widget _buildSubmitSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Kirim Pemeriksaan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── BACKGROUND AURAS ─────────────────────────────────────
  Widget _buildScatteredAuras(double sw, double sh) {
    return Stack(
      children: [
        Positioned(
          top: -sw * 0.05,
          right: -sw * 0.1,
          child: _buildAura(175, AppColors.primary.withOpacity(0.08)),
        ),
        Positioned(
          top: sh * 0.3,
          left: -sw * 0.2,
          child: _buildAura(150, AppColors.secondary.withOpacity(0.04)),
        ),
        Positioned(
          bottom: sh * 0.2,
          right: sw * 0.1,
          child: _buildAura(125, AppColors.muted.withOpacity(0.15)),
        ),
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

  // Guest users are allowed to access full assessment; login is only required to save history.
  void _showLoginRequiredDialog() {}
}

IconData getSymptomIcon(String code) {
  final cleanCode = code.toUpperCase();
  if (cleanCode.startsWith('G01')) return Icons.air_outlined;
  if (cleanCode.startsWith('G02')) return Icons.water_drop_outlined;
  if (cleanCode.startsWith('G03')) return Icons.thermostat_outlined;
  if (cleanCode.startsWith('G04')) return Icons.waves_outlined;
  if (cleanCode.startsWith('G05')) return Icons.no_food_outlined;
  if (cleanCode.startsWith('G06')) return Icons.monitor_weight_outlined;
  if (cleanCode.startsWith('G07')) return Icons.battery_alert_outlined;
  if (cleanCode.startsWith('G08')) return Icons.nightlight_outlined;
  if (cleanCode.startsWith('G09')) return Icons.commit_rounded;
  if (cleanCode.startsWith('G10')) return Icons.local_fire_department_outlined;
  if (cleanCode.startsWith('G11')) return Icons.open_with_rounded;
  if (cleanCode.startsWith('G12')) return Icons.fingerprint_rounded;
  if (cleanCode.startsWith('G13')) return Icons.zoom_in_rounded;
  if (cleanCode.startsWith('G14')) return Icons.opacity_rounded;
  if (cleanCode.startsWith('G15')) return Icons.healing_rounded;
  if (cleanCode.startsWith('G16')) return Icons.adjust_rounded;
  if (cleanCode.startsWith('G17')) return Icons.sensors_off_rounded;
  if (cleanCode.startsWith('G18')) return Icons.local_fire_department_outlined;
  if (cleanCode.startsWith('G19')) return Icons.accessibility_new_rounded;
  if (cleanCode.startsWith('G20')) return Icons.directions_walk_rounded;
  if (cleanCode.startsWith('G21')) return Icons.do_not_disturb_on_rounded;
  if (cleanCode.startsWith('G22')) return Icons.bedtime_outlined;
  if (cleanCode.startsWith('G23')) return Icons.blur_on_rounded;
  return Icons.help_outline;
}
