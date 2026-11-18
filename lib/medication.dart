enum DoseStatus { pending, taken, missed }

class Medication {
  int? id;
  int? groupId;
  String name;
  String dosage;
  String frequency;
  int duration;
  DateTime? date;
  DoseStatus status;

  Medication({
    this.id,
    this.groupId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
    this.date,
    this.status = DoseStatus.pending,
  });
}
