import 'medication.dart';

class AdherenceRecord {
  final String medicationName;
  final String dosage;
  final DateTime scheduledDate;
  final DateTime? confirmedAt;
  final DoseStatus status;

  AdherenceRecord({
    required this.medicationName,
    required this.dosage,
    required this.scheduledDate,
    this.confirmedAt,
    required this.status,
  });
}
