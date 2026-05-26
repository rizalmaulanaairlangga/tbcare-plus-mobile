import 'package:flutter/material.dart';
import '../../../core/services/assessment_api_service.dart';
import '../../../core/theme/app_colors.dart';

class HistoryDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const HistoryDetailPage({super.key, required this.item});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _detail;
  final Map<String, bool> _tbTypeExpanded = {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final sessionKey = (widget.item['sessionKey'] as String?) ?? '';
      final detail = await AssessmentApiService.fetchHistorySessionDetail(sessionKey);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.item['color'] as Color;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final items = (_detail?['items'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    
    // Sort items: High risk first, then by score
    int riskWeight(String? code) {
      final c = (code ?? '').toUpperCase();
      if (c.contains('HIGH')) return 3;
      if (c.contains('MEDIUM') || c.contains('MODERATE')) return 2;
      return 1;
    }

    items.sort((a, b) {
      final r1 = riskWeight(a['riskLevelCode'] as String?);
      final r2 = riskWeight(b['riskLevelCode'] as String?);
      if (r1 != r2) return r2.compareTo(r1);
      final s1 = (a['totalScore'] as num?)?.toDouble() ?? 0.0;
      final s2 = (b['totalScore'] as num?)?.toDouble() ?? 0.0;
      return s2.compareTo(s1);
    });

    String recommendation = 'Silakan kunjungi fasilitas kesehatan terdekat untuk pemeriksaan lebih lanjut.';
    if (items.isNotEmpty) {
      for (final it in items) {
        final breakdown = it['scoreBreakdown'];
        if (breakdown is Map && breakdown['results'] is List && (breakdown['results'] as List).isNotEmpty) {
          final primaryResult = (breakdown['results'] as List).first;
          if (primaryResult is Map && primaryResult['riskLevel'] is Map) {
            final rec = (primaryResult['riskLevel'] as Map)['recommendation'];
            if (rec is String && rec.isNotEmpty) {
              recommendation = rec;
              break;
            }
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Auras
          _buildScatteredAuras(screenWidth, screenHeight, color),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, color),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Result Summary Card
                              _buildSummaryCard(color),
                              const SizedBox(height: 24),

                              // Insight Section
                              if (items.isNotEmpty) ...[
                                const Text(
                                  'Detail Tipe TBC',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.foreground,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...items.map((it) => _buildTbTypeSection(context, it, color)),
                                const SizedBox(height: 32),
                              ],
                              
                              // Recommendation
                              _buildRecommendationCard(color, recommendation),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: color),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Detail Pemeriksaan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.2), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item['date'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item['type'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: color.withOpacity(0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.item['icon'], color: color, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    widget.item['percentage'],
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    (widget.item['tbType'] as String?)?.isNotEmpty == true
                        ? (widget.item['tbType'] as String)
                        : 'Tingkat Risiko',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Container(width: 2, height: 60, color: color.withOpacity(0.1)),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item['riskLevel'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item['riskLevelCode'] == 'HIGH' ? 'Requires immediate attention' : 'Monitor your condition',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTbTypeSection(BuildContext context, Map<String, dynamic> item, Color themeColor) {
    final tbTypeName = (item['primaryTbTypeName'] ?? '').toString();
    final score = (item['totalScore'] is num) ? (item['totalScore'] as num).round() : 0;
    final riskTitle = (item['riskLevelTitle'] ?? 'Low Risk').toString();
    final riskCode = (item['riskLevelCode'] ?? 'LOW').toString().toUpperCase();
    // Ensure card color matches risk level (Low=green, Medium=yellow, High=red)
    Color resolvedColor;
    if (riskCode.contains('HIGH')) {
      resolvedColor = const Color(0xFFEF4444);
    } else if (riskCode.contains('MEDIUM') || riskCode.contains('MODERATE')) {
      resolvedColor = const Color(0xFFF59E0B);
    } else {
      resolvedColor = const Color(0xFF10B981);
    }

    final selectedSymptomsRaw = item['selectedSymptoms'];
    final selectedSymptoms = selectedSymptomsRaw is List ? selectedSymptomsRaw : <dynamic>[];

    // Only include symptoms actually selected by user (cfValue > 0)
    final symptoms = selectedSymptoms
        .where((s) => s is Map && (s['cfValue'] is num) && (s['cfValue'] as num) > 0)
        .map((s) {
          final m = s as Map;
          return {
            'name': m['symptomName'] ?? '-',
            'desc': m['symptomDescription'] ?? 'No description available.',
            'cfValue': m['cfValue'] ?? 0,
          };
        })
        .toList();

    final isExpanded = _tbTypeExpanded[tbTypeName] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: resolvedColor.withOpacity(0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _tbTypeExpanded[tbTypeName] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tbTypeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$score% • $riskTitle ($riskCode)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: resolvedColor.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: resolvedColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$score%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: resolvedColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: resolvedColor,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (symptoms.isNotEmpty) ...[
                    Text(
                      'Gejala dipilih (${symptoms.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mutedForeground.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Use expansion tiles for each symptom instead of a popup
                    ...symptoms.map((s) => _buildSymptomItem(context, s, resolvedColor)),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomItem(BuildContext context, Map<String, dynamic> symptom, Color themeColor) {
    final controller = ExpansionTileController();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.12)),
      ),
      child: ExpansionTile(
        controller: controller,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor.withOpacity(0.15), themeColor.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.check_circle_rounded, color: themeColor, size: 24),
        ),
        title: Text(
          symptom['name'],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.foreground),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symptom['desc'],
                  style: TextStyle(fontSize: 14, color: AppColors.foreground.withOpacity(0.8), height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                controller.collapse();
              },
              style: TextButton.styleFrom(
                backgroundColor: themeColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // symptom details are shown inline using ExpansionTile; no dialog needed.

  Widget _buildRecommendationCard(Color color, String recommendation) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withBlue(100)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recommendation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScatteredAuras(double sw, double sh, Color color) {
    return Stack(
      children: [
        Positioned(
          top: -sh * 0.1,
          right: -sw * 0.2,
          child: _buildAura(200, color.withOpacity(0.1)),
        ),
        Positioned(
          bottom: sh * 0.1,
          left: -sw * 0.3,
          child: _buildAura(250, color.withOpacity(0.05)),
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
