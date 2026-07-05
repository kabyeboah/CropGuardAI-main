/// Equivalent of Field.kt domain data class
class Field {
  final String id;
  final String name;
  final String cropType;
  final double sizeHectares;
  final int? plantingDate; // milliseconds since epoch
  final String userId;

  const Field({
    required this.id,
    required this.name,
    required this.cropType,
    required this.sizeHectares,
    this.plantingDate,
    this.userId = '',
  });

  int getHarvestDurationDays() {
    switch (cropType.toLowerCase()) {
      case 'maize':
        return 90;
      case 'tomato':
        return 70;
      case 'rice':
        return 120;
      case 'cassava':
        return 300;
      case 'yam':
        return 240;
      default:
        return 90;
    }
  }

  int? getDaysRemaining() {
    if (plantingDate == null) return null;
    final elapsed = (DateTime.now().millisecondsSinceEpoch - plantingDate!) ~/
        (24 * 60 * 60 * 1000);
    final remaining = getHarvestDurationDays() - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'cropType': cropType,
      'sizeHectares': sizeHectares,
      'plantingDate': plantingDate,
      'userId': userId,
    };
  }

  factory Field.fromMap(Map<String, dynamic> map) {
    return Field(
      id: map['id'] as String,
      name: map['name'] as String,
      cropType: map['cropType'] as String,
      sizeHectares: (map['sizeHectares'] as num).toDouble(),
      plantingDate: map['plantingDate'] as int?,
      userId: map['userId'] as String? ?? '',
    );
  }
}
