import 'dart:convert';

class QuickCheckConfig {
  final List<QuickCheckQuestion> questions;
  final List<RiskLevelConfig> riskLevels;
  final String scoringMethod;
  final double saturationK;

  const QuickCheckConfig({
    required this.questions,
    required this.riskLevels,
    this.scoringMethod = 'soft_saturation_cf',
    this.saturationK = 0.35,
  });

  factory QuickCheckConfig.fromJson(Map<String, dynamic> json) {
    return QuickCheckConfig(
      questions: (json['questions'] as List<dynamic>?)
              ?.map((q) => QuickCheckQuestion.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      riskLevels: (json['riskLevels'] as List<dynamic>?)
              ?.map((r) => RiskLevelConfig.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      scoringMethod: json['scoringMethod'] as String? ?? 'soft_saturation_cf',
      saturationK: (json['saturationK'] as num?)?.toDouble() ?? 0.35,
    );
  }

  Map<String, dynamic> toJson() => {
        'questions': questions.map((q) => q.toJson()).toList(),
        'riskLevels': riskLevels.map((r) => r.toJson()).toList(),
        'scoringMethod': scoringMethod,
        'saturationK': saturationK,
      };

  String toJsonString() => jsonEncode(toJson());

  static QuickCheckConfig fromJsonString(String s) =>
      QuickCheckConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);

  RiskLevelConfig? findRiskLevel(double totalScore, int tbTypeId) {
    return riskLevels.cast<RiskLevelConfig?>().firstWhere(
          (r) => r!.tbTypeId == tbTypeId && totalScore >= r.minScore && totalScore <= r.maxScore,
          orElse: () => null,
        );
  }

  static QuickCheckConfig fallback() {
    return QuickCheckConfig(
      questions: [
        QuickCheckQuestion(
          questionId: 1, symptomId: 1, symptomCode: 'COUGH_2W',
          symptomName: 'Persistent Cough', questionText: 'Persistent cough for 2+ weeks',
          sortOrder: 1, weight: 0.15, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 2, symptomId: 2, symptomCode: 'COUGH_BLOOD',
          symptomName: 'Coughing Up Blood', questionText: 'Coughing up blood',
          sortOrder: 2, weight: 0.20, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 3, symptomId: 3, symptomCode: 'CHEST_PAIN',
          symptomName: 'Chest Pain', questionText: 'Chest pain or tightness',
          sortOrder: 3, weight: 0.10, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 4, symptomId: 4, symptomCode: 'SHORT_BREATH',
          symptomName: 'Shortness of Breath', questionText: 'Shortness of breath',
          sortOrder: 4, weight: 0.10, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 5, symptomId: 5, symptomCode: 'WEIGHT_LOSS',
          symptomName: 'Weight Loss', questionText: 'Unexplained weight loss',
          sortOrder: 5, weight: 0.15, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 6, symptomId: 6, symptomCode: 'FEVER',
          symptomName: 'Prolonged Fever', questionText: 'Prolonged fever or chills',
          sortOrder: 6, weight: 0.10, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 7, symptomId: 7, symptomCode: 'NIGHT_SWEATS',
          symptomName: 'Night Sweats', questionText: 'Night sweats',
          sortOrder: 7, weight: 0.10, tbTypeId: 1,
        ),
        QuickCheckQuestion(
          questionId: 8, symptomId: 8, symptomCode: 'FATIGUE',
          symptomName: 'Fatigue & Weakness', questionText: 'Feeling weak or fatigued',
          sortOrder: 8, weight: 0.10, tbTypeId: 1,
        ),
      ],
      riskLevels: [
        RiskLevelConfig(id: 1, tbTypeId: 1, code: 'LOW', title: 'Low Risk', minScore: 0, maxScore: 30),
        RiskLevelConfig(id: 2, tbTypeId: 1, code: 'MEDIUM', title: 'Medium Risk', minScore: 31, maxScore: 60),
        RiskLevelConfig(id: 3, tbTypeId: 1, code: 'HIGH', title: 'High Risk', minScore: 61, maxScore: 100),
      ],
    );
  }
}

class QuickCheckQuestion {
  final int questionId;
  final int symptomId;
  final String symptomCode;
  final String symptomName;
  final String? symptomDescription;
  final String questionText;
  final int sortOrder;
  final bool isRequired;
  final double weight;
  final int tbTypeId;
  final String? tbTypeName;

  const QuickCheckQuestion({
    required this.questionId,
    required this.symptomId,
    required this.symptomCode,
    required this.symptomName,
    this.symptomDescription,
    required this.questionText,
    required this.sortOrder,
    this.isRequired = true,
    required this.weight,
    required this.tbTypeId,
    this.tbTypeName,
  });

  factory QuickCheckQuestion.fromJson(Map<String, dynamic> json) {
    return QuickCheckQuestion(
      questionId: (json['questionId'] as num).toInt(),
      symptomId: (json['symptomId'] as num).toInt(),
      symptomCode: json['symptomCode'] as String? ?? '',
      symptomName: json['symptomName'] as String? ?? '',
      symptomDescription: json['symptomDescription'] as String?,
      questionText: json['questionText'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isRequired: json['isRequired'] as bool? ?? true,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      tbTypeId: (json['tbTypeId'] as num?)?.toInt() ?? 0,
      tbTypeName: json['tbTypeName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'symptomId': symptomId,
        'symptomCode': symptomCode,
        'symptomName': symptomName,
        'symptomDescription': symptomDescription,
        'questionText': questionText,
        'sortOrder': sortOrder,
        'isRequired': isRequired,
        'weight': weight,
        'tbTypeId': tbTypeId,
        'tbTypeName': tbTypeName,
      };
}

class RiskLevelConfig {
  final int id;
  final int tbTypeId;
  final String code;
  final String title;
  final double minScore;
  final double maxScore;
  final String? description;
  final String? recommendation;

  const RiskLevelConfig({
    required this.id,
    required this.tbTypeId,
    required this.code,
    required this.title,
    required this.minScore,
    required this.maxScore,
    this.description,
    this.recommendation,
  });

  factory RiskLevelConfig.fromJson(Map<String, dynamic> json) {
    return RiskLevelConfig(
      id: (json['id'] as num).toInt(),
      tbTypeId: (json['tbTypeId'] as num).toInt(),
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      minScore: (json['minScore'] as num).toDouble(),
      maxScore: (json['maxScore'] as num).toDouble(),
      description: json['description'] as String?,
      recommendation: json['recommendation'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tbTypeId': tbTypeId,
        'code': code,
        'title': title,
        'minScore': minScore,
        'maxScore': maxScore,
        'description': description,
        'recommendation': recommendation,
      };
}
