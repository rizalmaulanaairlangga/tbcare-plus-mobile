import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/network_exception.dart';
import '../../../core/utils/url_utils.dart';
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
  String? _profilePicture;
  bool _loadingConfig = true;
  Map<String, dynamic>? _storedResult;
  bool get _hasStoredResult => _storedResult != null;

  // For logged-in users: most recent assessment data
  Map<String, dynamic>? _mostRecentAssessment;
  bool _loadingMostRecentAssessment = false;

  // Re-entry guard for the quick-check submit so rapid taps can't fire twice.
  bool _submittingQuick = false;

  // Tracks the device's most recent online/offline state. Used to detect
  // the offline→online transition and auto-refresh when the user returns.
  bool _wasOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  int get _answeredCount => _symptomStates.values.where((v) => v).length;

  double get _combinedCF {
    if (_config == null || _answeredCount == 0) return 0;

    // Mirror the backend's quick-check scoring (AssessmentController.SubmitAssessment):
    // combinedCf = sum(selected question weights) / sum(all question weights).
    // Quick check is single-TB-type (Paru), so each question's `weight` is the
    // Paru weight and no cross-type fan-out is needed.
    double selectedWeight = 0;
    double totalWeight = 0;
    for (final q in _config!.questions) {
      totalWeight += q.weight;
      if (_symptomStates[q.symptomId] == true) selectedWeight += q.weight;
    }

    if (totalWeight <= 0) return 0;
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
    _subscribeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _subscribeConnectivity() {
    // Seed initial state so an early "online" emission doesn't misfire the
    // refresh logic when the app is already online at launch.
    ConnectivityService.isOnline().then((online) {
      if (!mounted) return;
      _wasOnline = online;
    });
    _connectivitySub = ConnectivityService.onChange().listen((online) {
      if (!mounted) return;
      // Only react to the offline→online transition. We don't want to refetch
      // every time the user toggles between WiFi and mobile data while online.
      if (!_wasOnline && online) {
        _refreshAll();
      }
      _wasOnline = online;
    });
  }

  /// Re-fetch all data sources that depend on the network. Called on
  /// pull-to-refresh and after returning online. If we have nothing to fetch
  /// against (offline), the existing cached state is preserved — the user
  /// keeps seeing their last result instead of being kicked back to the
  /// fresh assessment card.
  Future<void> _refreshAll() async {
    final online = await ConnectivityService.isOnline();
    if (!online) {
      _showSnack(
        'Tidak ada koneksi. Menampilkan data terakhir.',
        background: AppColors.warning,
      );
      return;
    }
    await Future.wait<void>([
      _loadConfig(),
      _loadUser(),
    ]);
  }

  /// Cache-then-revalidate for the logged-in user's most-recent assessment:
  /// 1. Hydrate from local cache so the card renders instantly.
  /// 2. Fetch from backend in the background.
  /// 3. On success → update state + overwrite cache.
  /// 4. On failure → keep the cached value visible (do not null it out).
  Future<void> _loadMostRecentAssessment() async {
    if (_isGuest) return;
    final user = await StorageService.getUser();
    final userId = user?.id ?? '';

    // Step 1 — sync render from cache before hitting the network.
    final cached = userId.isEmpty
        ? null
        : await StorageService.getCachedRecentAssessment(userId);
    if (cached != null && mounted) {
      setState(() {
        _mostRecentAssessment = cached;
        _loadingMostRecentAssessment = false;
      });
    } else if (mounted) {
      setState(() => _loadingMostRecentAssessment = true);
    }

    // Step 2 — fetch fresh.
    try {
      final assessment = await AssessmentApiService.fetchMostRecentAssessment();
      if (!mounted) return;
      setState(() {
        if (assessment != null) _mostRecentAssessment = assessment;
        _loadingMostRecentAssessment = false;
      });
      if (assessment != null && userId.isNotEmpty) {
        await StorageService.saveCachedRecentAssessment(userId, assessment);
      }
    } catch (_) {
      // Step 4 — keep whatever (cached or null) is on screen.
      if (!mounted) return;
      setState(() => _loadingMostRecentAssessment = false);
    }
  }

  Future<void> _loadUser() async {
    // Source-of-truth for "is this an authenticated session" is the access
    // token. A cached user without a token (e.g., after token expiry or a
    // partial logout) is NOT logged in — treat as guest.
    final loggedIn = await StorageService.isLoggedIn();
    final user = loggedIn ? await StorageService.getUser() : null;
    if (!mounted) return;
    final wasGuest = _isGuest;
    setState(() {
      _isGuest = !loggedIn;
      _userName = user?.fullName;
      _profilePicture = user?.profilePicture;
    });

    if (_isGuest) {
      // Guest result is session-scoped: kept in memory only for this app run.
      setState(() => _storedResult = StorageService.guestSessionResult);
    } else if (!_isGuest && wasGuest) {
      // Guest→logged-in: hide guest result, load from backend.
      setState(() => _storedResult = null);
      _loadMostRecentAssessment();
    } else if (!_isGuest) {
      // Still logged-in: load most recent assessment
      _loadMostRecentAssessment();
    }

    if (user != null) {
      try {
        final updatedUser = await AuthApiService.fetchCurrentUser();
        if (mounted) {
          setState(() {
            _userName = updatedUser.fullName;
            _profilePicture = updatedUser.profilePicture;
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
      _symptomStates = {for (final q in config.questions) q.symptomId: false};
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
                HomeHeader(
                  isGuest: _isGuest,
                  userName: _userName ?? StorageService.cachedUser?.fullName,
                  profilePicture:
                      _profilePicture ??
                      StorageService.cachedUser?.profilePicture,
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAll,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        children: [
                          if (_loadingConfig ||
                              (_loadingMostRecentAssessment && !_isGuest))
                            _buildLoadingCard()
                          else if (!_isGuest && _mostRecentAssessment != null)
                            _buildLoggedInResultCard()
                          else if (_hasStoredResult)
                            _buildStoredResultCard()
                          else
                            _buildAssessmentCard(),
                        ],
                      ),
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

  Widget _buildLoadingCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildAssessmentCard() {
    final config = _config!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
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
            ...config.questions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSymptomItem(q),
              ),
            ),

            const SizedBox(height: 24),
            _buildCheckButton(),
          ],
        ),
      ),
    );
  }

  final Map<int, IconData> _symptomIcons = {
    1: Icons.air_outlined,
    2: Icons.water_drop_outlined,
    3: Icons.thermostat_outlined,
    4: Icons.waves_outlined,
    5: Icons.no_meals_outlined,
    6: Icons.monitor_weight_outlined,
    7: Icons.battery_alert_outlined,
    8: Icons.nightlight_outlined,
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
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppColors.primary : AppColors.primary)
                  .withValues(alpha: 0.05),
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
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.mutedForeground,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                q.questionText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
            ),
            Switch(
              value: isSelected,
              onChanged: (val) =>
                  setState(() => _symptomStates[q.symptomId] = val),
              activeThumbColor: AppColors.primary,
              activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.withValues(alpha: 0.1),
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
              : [AppColors.muted, AppColors.muted.withValues(alpha: 0.6)],
        ),
        boxShadow: hasSelection
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: (hasSelection && !_submittingQuick) ? _onCheckRisk : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
    if (_submittingQuick) return;
    setState(() => _submittingQuick = true);

    try {
      // Logged-in users must reach the backend to persist. Guests submit
      // entirely locally and don't need the network — the fallback config
      // has real Indonesian copy so an offline submit still produces a
      // proper result page.
      if (!_isGuest) {
        final online = await ConnectivityService.isOnline();
        if (!online) {
          _showSnack(
            'Anda sedang offline. Periksa koneksi internet Anda lalu coba lagi.',
          );
          return;
        }
        // If we just came back online, the cached config may be stale.
        if (!_wasOnline) {
          await _loadConfig();
        }
      }

      if (_config == null || _config!.questions.isEmpty) {
        _showSnack('Gagal memuat data pemeriksaan. Coba lagi sebentar.');
        return;
      }

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
        'riskCode': matchedLevel?.code ?? 'LOW',
        'riskTitle': matchedLevel?.title ?? '',
        'description': matchedLevel?.description ?? '',
        'type': 'QUICK CHECK',
        'symptoms': selectedSymptoms,
      };

      if (!_isGuest) {
        // Logged-in users must persist to backend successfully before the
        // result is shown. Otherwise the user sees a "result" that's not
        // saved anywhere and isn't retrievable later from history.
        final answers = <Map<String, dynamic>>[];
        for (final q in _config!.questions) {
          final selected = _symptomStates[q.symptomId] ?? false;
          if (!selected) continue;
          answers.add({'questionId': q.questionId, 'cfValue': 1.0});
        }

        if (answers.isEmpty) return;

        try {
          await AssessmentApiService.submitAssessment(
            assessmentTypeId: 1,
            answers: answers,
          );
        } catch (e) {
          final msg = NetworkException.from(e).userMessage;
          _showSnack(msg);
          return;
        }
        // Mitigation: seed the recent-assessment cache from the submit
        // payload itself so the home card has data even if the next
        // _loadMostRecentAssessment fetch fails (offline or backend slow).
        final user = await StorageService.getUser();
        if (user?.id != null && user!.id.isNotEmpty) {
          final cacheRecord = {
            'createdAt': DateTime.now().toIso8601String(),
            'assessmentTypeId': 1,
            'assessmentTypeName': 'Quick Check',
            'riskLevelCode': matchedLevel?.code ?? 'LOW',
            'riskLevelTitle': matchedLevel?.title ?? 'Risiko Rendah',
            'totalScore': pct,
            'primaryTbTypeName': '',
          };
          await StorageService.saveCachedRecentAssessment(
            user.id,
            cacheRecord,
          );
          // Reflect immediately in UI; the backend fetch will overwrite later.
          if (mounted) {
            setState(() => _mostRecentAssessment = cacheRecord);
          }
        }
        // Kick a background refresh to pick up the canonical server record.
        if (mounted) _loadMostRecentAssessment();
      } else {
        // Guest path: keep result only for the current app process.
        StorageService.guestSessionResult = assessmentData;
        if (mounted) setState(() => _storedResult = assessmentData);
      }

      if (!mounted) return;
      // Zero-duration transition so the user doesn't see the home page
      // underneath during the standard fade+slide.
      await Navigator.push(
        context,
        PageRouteBuilder(
          settings: RouteSettings(
            name: AppRoutes.result,
            arguments: {
              'riskLevel': risk,
              'isGuest': _isGuest,
              'percentage': pct,
              'assessmentData': assessmentData,
            },
          ),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ResultPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingQuick = false);
    }
  }

  void _showSnack(String message, {Color? background}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background ?? AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
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
    final isFullAssessment = (result['type'] as String?) == 'FULL ASSESSMENT';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.15)),
              ),
              child: Text(
                isFullAssessment ? 'Pemeriksaan Lengkap' : 'Cek Cepat',
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
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.1)),
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

            // Buttons — match logged-in result card logic
            if (!isFullAssessment && riskCode.toUpperCase() != 'LOW') ...[
              _buildResultButton(
                'Lanjutkan Pemeriksaan Lengkap',
                color,
                Colors.white,
                true,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.fullAssessment),
              ),
              const SizedBox(height: 12),
            ],
            if (riskCode.toUpperCase() != 'LOW') ...[
              _buildClinicFinderButton(color),
              const SizedBox(height: 12),
            ],
            _buildResultButton(
              'Lihat Insight Gejala',
              Colors.transparent,
              color,
              false,
              borderColor: color.withValues(alpha: 0.2),
              onPressed: () => _openSymptomInsight(
                color,
                riskCode,
                riskTitle,
                pct,
                isFullAssessment,
                icon,
              ),
            ),
            const SizedBox(height: 12),
            _buildResultButton(
              isFullAssessment
                  ? 'Ulangi Pemeriksaan Lengkap'
                  : 'Ulangi Cek Cepat',
              Colors.white,
              AppColors.mutedForeground,
              false,
              borderColor: AppColors.muted.withValues(alpha: 0.3),
              onPressed: () => _onRetakeAssessment(isFullAssessment),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the symptom-insight detail page. Guests reconstruct the detail purely
  /// from their locally stored result snapshot — never by refetching a config,
  /// whose IDs may differ from the ones used at submit time (that mismatch is
  /// what produced phantom TB-type symptoms). Logged-in users pass a sessionKey
  /// and HistoryDetailPage fetches the canonical detail from the backend.
  Future<void> _openSymptomInsight(
    Color color,
    String riskCode,
    String riskTitle,
    int pct,
    bool isFullAssessment,
    IconData icon, {
    String? sessionKey,
  }) async {
    Map<String, dynamic>? detail;

    if (_isGuest) {
      final stored = _storedResult;
      if (stored != null) {
        detail = isFullAssessment
            ? _buildGuestFullDetail(stored, pct, riskTitle, riskCode)
            : _buildGuestQuickDetail(stored, pct, riskTitle, riskCode);
      }
    }
    // Authenticated insight requires a live backend fetch (architecture:
    // authenticated = online-required). The `requiresOnline` flag makes
    // HistoryDetailPage enforce connectivity, resolve the sessionKey, and show a
    // full-page no-internet handler on failure — never a silent empty page.

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.historyDetail,
      arguments: {
        'sessionKey': sessionKey ?? '',
        'requiresOnline': !_isGuest,
        'date': 'Sekarang',
        'riskLevel': riskTitle,
        'riskLevelCode': riskCode,
        'percentage': '$pct%',
        'tbType': '',
        'type': isFullAssessment ? 'Pemeriksaan Lengkap' : 'Cek Cepat',
        'color': color,
        'icon': icon,
        'detailData': detail,
      },
    );
  }

  /// Builds the insight detail for a guest FULL assessment from the stored
  /// `fullResults` snapshot (saved at submit time). One item per TB type that
  /// received at least one selected symptom. No network/config dependency.
  Map<String, dynamic>? _buildGuestFullDetail(
    Map<String, dynamic> stored,
    int pct,
    String riskTitle,
    String riskCode,
  ) {
    final results = stored['fullResults'] as List<dynamic>?;
    if (results == null) return null;

    final items = <Map<String, dynamic>>[];
    for (final r in results) {
      if (r is! Map) continue;
      final rl = r['riskLevel'] as Map<String, dynamic>?;
      final symptomDetails = (r['symptomDetails'] as List<dynamic>?) ?? [];
      final selected = symptomDetails
          .where(
            (s) => s is Map && ((s['cfValue'] as num?)?.toDouble() ?? 0) > 0,
          )
          .map((s) {
            final m = s as Map;
            return {
              'symptomName': m['symptomName'] ?? '-',
              'symptomCode': m['symptomCode'] ?? '',
              'symptomDescription': m['symptomDescription'],
              'cfValue': 1.0,
              'tbTypeId': (m['originTbTypeId'] as num?)?.toInt() ??
                  (r['tbTypeId'] as num?)?.toInt() ??
                  0,
            };
          })
          .toList();
      if (selected.isEmpty) continue;
      items.add({
        'primaryTbTypeId': (r['tbTypeId'] as num?)?.toInt() ?? 0,
        'primaryTbTypeName': r['tbTypeName'] ?? 'Unknown',
        'totalScore': (r['totalScore'] as num?)?.toDouble() ?? 0,
        'riskLevelTitle': rl?['title'] ?? riskTitle,
        'riskLevelCode': rl?['code'] ?? riskCode,
        'selectedSymptoms': selected,
        'scoreBreakdown': {
          'results': [
            {
              'riskLevel': {'recommendation': rl?['recommendation'] ?? ''},
            },
          ],
        },
      });
    }

    return {
      'items': items,
      'createdAt': DateTime.now().toIso8601String(),
      'assessmentTypeName': 'Full Assessment',
    };
  }

  /// Builds the insight detail for a guest QUICK check from the stored symptom
  /// map. Quick check is single-TB-type (Paru); `_config` (the faithful
  /// bundled/real config) maps the selected symptomIds back to names/codes.
  Map<String, dynamic>? _buildGuestQuickDetail(
    Map<String, dynamic> stored,
    int pct,
    String riskTitle,
    String riskCode,
  ) {
    if (_config == null) return null;
    final symptoms = stored['symptoms'] as Map<String, dynamic>? ?? {};

    final selected = <Map<String, dynamic>>[];
    for (final q in _config!.questions) {
      if (symptoms[q.symptomId.toString()] != true) continue;
      selected.add({
        'symptomName': q.symptomName,
        'symptomCode': q.symptomCode,
        'symptomDescription': q.symptomDescription,
        'cfValue': 1.0,
        'tbTypeId': q.tbTypeId,
      });
    }
    if (selected.isEmpty) return null;

    return {
      'items': [
        {
          'primaryTbTypeId': 1,
          'primaryTbTypeName': _config!.questions.first.tbTypeName ?? 'TBC Paru',
          'totalScore': pct.toDouble(),
          'riskLevelTitle': riskTitle,
          'riskLevelCode': riskCode,
          'selectedSymptoms': selected,
          'scoreBreakdown': {
            'results': [
              {
                'riskLevel': {'recommendation': stored['description'] ?? ''},
              },
            ],
          },
        },
      ],
      'createdAt': DateTime.now().toIso8601String(),
      'assessmentTypeName': 'Quick Assessment',
    };
  }

  Widget _buildClinicFinderButton(Color color) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cari Faskes Terdekat',
              style: TextStyle(
                fontSize: 15,
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
            borderRadius: BorderRadius.circular(18),
          ),
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
    final riskLevelCode = assessment['riskLevelCode'] as String? ?? 'LOW';
    final riskLevelTitle =
        assessment['riskLevelTitle'] as String? ?? 'Low Risk';
    final totalScore = assessment['totalScore'] as num? ?? 0;
    final pct = totalScore.toInt();

    // For full assessment, we might have multiple results - just show the main risk
    String primaryRiskCode = riskLevelCode;
    String primaryRiskTitle = riskLevelTitle;

    final color = _colorForRisk(primaryRiskCode);
    final icon = _iconForRisk(primaryRiskCode);
    final subtitle = _subtitleForRisk(primaryRiskCode);
    final description = _descriptionForRisk(primaryRiskCode);

    final isFullAssessment = assessmentTypeId == 2;
    final assessmentBadge = isFullAssessment
        ? 'Pemeriksaan Lengkap'
        : 'Cek Cepat';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.15)),
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
                color: color.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: color.withValues(alpha: 0.1)),
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
            if (!isFullAssessment &&
                primaryRiskCode.toUpperCase() != 'LOW') ...[
              _buildResultButton(
                'Lanjutkan Pemeriksaan Lengkap',
                color,
                Colors.white,
                true,
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.fullAssessment),
              ),
              const SizedBox(height: 12),
            ],
            if (primaryRiskCode.toUpperCase() != 'LOW') ...[
              _buildClinicFinderButton(color),
              const SizedBox(height: 12),
            ],
            _buildResultButton(
              'Lihat Insight Gejala',
              Colors.transparent,
              color,
              false,
              borderColor: color.withValues(alpha: 0.2),
              onPressed: () => _openSymptomInsight(
                color,
                primaryRiskCode,
                primaryRiskTitle,
                pct,
                isFullAssessment,
                _iconForRisk(primaryRiskCode),
                sessionKey: assessment['sessionKey'] as String?,
              ),
            ),
            const SizedBox(height: 12),
            _buildResultButton(
              isFullAssessment
                  ? 'Ulangi Pemeriksaan Lengkap'
                  : 'Ulangi Cek Cepat',
              Colors.white,
              AppColors.mutedForeground,
              false,
              borderColor: AppColors.muted.withValues(alpha: 0.3),
              onPressed: () => _onRetakeAssessment(isFullAssessment),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRetakeAssessment(bool isFullAssessment) async {
    if (isFullAssessment) {
      Navigator.pushNamed(context, AppRoutes.fullAssessment);
    } else {
      StorageService.guestSessionResult = null;
      setState(() {
        _storedResult = null;
        if (_config != null) {
          _symptomStates = {
            for (final q in _config!.questions) q.symptomId: false,
          };
        }
        _mostRecentAssessment = null;
      });
    }
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
        Positioned(
          top: -50,
          right: -50,
          child: _buildAura(150, AppColors.primary.withValues(alpha: 0.1)),
        ),
        Positioned(
          top: sh * 0.2,
          left: -100,
          child: _buildAura(180, AppColors.secondary.withValues(alpha: 0.05)),
        ),
        Positioned(
          bottom: 100,
          right: 20,
          child: _buildAura(100, AppColors.muted.withValues(alpha: 0.1)),
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
          BoxShadow(color: color, blurRadius: size, spreadRadius: size / 2),
        ],
      ),
    );
  }
}
