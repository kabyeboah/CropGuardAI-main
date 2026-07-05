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
