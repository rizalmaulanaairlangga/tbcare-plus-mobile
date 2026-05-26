import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/home_header.dart';
import '../../../core/widgets/guest_bottom_nav.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../routes/app_routes.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool _isGuest = true;
  String? _userName;
  List<Map<String, dynamic>> _historyItems = [];
  bool _loading = true;

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
    _loadAuthAndHistory();
  }

  Future<void> _loadAuthAndHistory() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.cover, (route) => false);
      return;
    }
    final user = await StorageService.getUser();
    if (!mounted) return;
    setState(() {
      _isGuest = false;
      _userName = user?.fullName;
    });

    try {
      final history = await AssessmentApiService.fetchHistorySessions();
      if (!mounted) return;
      setState(() {
        _historyItems = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
                HomeHeader(isGuest: _isGuest, userName: _userName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riwayat Pemeriksaan',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.foreground,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const Text(
                          'Hasil skrining terbaru Anda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Timeline List
                        _loading
                            ? const Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : _historyItems.isEmpty
                                ? _buildEmptyState()
                                : _buildTimelineList(),
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
          ? const GuestBottomNav(currentIndex: 1)
          : AppBottomNav(
              currentIndex: 1,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 80, color: AppColors.muted.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No History Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your assessment results will appear here.',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final raw = _historyItems[index];
        
        DateTime createdAt;
        try {
          createdAt = DateTime.parse(raw['createdAt']);
        } catch (_) {
          createdAt = DateTime.now();
        }
        
        final dateStr = DateFormat('MMM dd, yyyy').format(createdAt).toUpperCase();
        
        final riskLevelCode = (raw['riskLevelCode'] ?? 'LOW').toString().toUpperCase();
        Color color = AppColors.primary;
        IconData icon = Icons.check_circle_outline_rounded;
        String riskTitle = raw['riskLevelTitle'] ?? 'Low Risk';

        if (riskLevelCode.contains('HIGH')) {
          color = const Color(0xFFEF4444);
          icon = Icons.error_outline_rounded;
        } else if (riskLevelCode.contains('MEDIUM') || riskLevelCode.contains('MODERATE')) {
          color = const Color(0xFFF59E0B);
          icon = Icons.warning_amber_rounded;
        } else {
          color = const Color(0xFF10B981);
          icon = Icons.check_circle_outline_rounded;
        }

        final item = {
          'sessionKey': raw['sessionKey'],
          'date': dateStr,
          'riskLevel': riskTitle,
          'riskLevelCode': riskLevelCode,
          'percentage': '${(raw['totalScore'] as num).round()}%',
          'tbType': (raw['primaryTbTypeName'] ?? '').toString(),
          'type': (raw['assessmentTypeName'] ?? 'ASSESSMENT').toString().toUpperCase(),
          'color': color,
          'icon': icon,
        };

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline vertical line and dot
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: (item['color'] as Color).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: (item['color'] as Color).withOpacity(0.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.historyDetail,
                        arguments: item,
                      );
                    },
                    child: _buildHistoryCard(item),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final color = item['color'] as Color;
    
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['date'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      item['type'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['riskLevel'] as String,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: color,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '${item['tbType']} • ${item['percentage']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: color.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScatteredAuras(double sw, double sh) {
    return Stack(
      children: [
        Positioned(
          top: -sh * 0.05,
          right: -sw * 0.1,
          child: _buildAura(175, AppColors.primary.withOpacity(0.1)),
        ),
        Positioned(
          top: sh * 0.4,
          left: -sw * 0.2,
          child: _buildAura(150, AppColors.secondary.withOpacity(0.05)),
        ),
        Positioned(
          bottom: sh * 0.1,
          right: -sw * 0.1,
          child: _buildAura(125, AppColors.accent.withOpacity(0.05)),
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
}
