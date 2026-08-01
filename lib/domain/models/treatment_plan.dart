class TreatmentPlan {
  final String id;
  final String userId;
  final int detectionId;
  final String cropType;
  final String diseaseName;
  final String step;
  final bool completed;
  final DateTime dueDate;
  final DateTime createdAt;

  const TreatmentPlan({
    required this.id,
    required this.userId,
    required this.detectionId,
    required this.cropType,
    required this.diseaseName,
    required this.step,
    required this.completed,
    required this.dueDate,
    required this.createdAt,
  });

  String get dueDateFormatted {
    return '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
  }

  TreatmentPlan copyWith({bool? completed}) {
    return TreatmentPlan(
      id: id,
      userId: userId,
      detectionId: detectionId,
      cropType: cropType,
      diseaseName: diseaseName,
      step: step,
      completed: completed ?? this.completed,
      dueDate: dueDate,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'detectionId': detectionId,
      'cropType': cropType,
      'diseaseName': diseaseName,
      'step': step,
      'completed': completed ? 1 : 0,
      'dueDateMs': dueDate.millisecondsSinceEpoch,
      'createdAtMs': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TreatmentPlan.fromMap(Map<String, dynamic> map) {
    return TreatmentPlan(
      id: map['id']?.toString() ?? '',
      userId: map['userId'] as String? ?? '',
      detectionId: map['detectionId'] as int? ?? 0,
      cropType: map['cropType'] as String? ?? '',
      diseaseName: map['diseaseName'] as String? ?? '',
      step: map['step'] as String? ?? '',
      completed: (map['completed'] as int? ?? 0) == 1,
      dueDate: DateTime.fromMillisecondsSinceEpoch(
        map['dueDateMs'] as int? ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['createdAtMs'] as int? ?? 0,
      ),
    );
  }
}

/// Represents a compiled set of treatment steps for a single disease & crop instance.
class TreatmentPlanGroup {
  final String groupId;
  final String cropType;
  final String diseaseName;
  final int detectionId;
  final DateTime createdAt;
  final List<TreatmentPlan> steps;

  const TreatmentPlanGroup({
    required this.groupId,
    required this.cropType,
    required this.diseaseName,
    required this.detectionId,
    required this.createdAt,
    required this.steps,
  });

  bool get isCompleted => steps.isNotEmpty && steps.every((s) => s.completed);
  int get completedStepsCount => steps.where((s) => s.completed).length;
  int get totalStepsCount => steps.length;
  double get progress =>
      totalStepsCount == 0 ? 0.0 : completedStepsCount / totalStepsCount;

  DateTime? get nextDueDate {
    final pending = steps.where((s) => !s.completed).toList();
    if (pending.isEmpty) return null;
    pending.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return pending.first.dueDate;
  }
}

