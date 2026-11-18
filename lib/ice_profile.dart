class EmergencyContact {
  String name;
  String phone;

  EmergencyContact({required this.name, required this.phone});
}

class IceProfile {
  // Personal Information
  String fullName;
  DateTime? dateOfBirth;
  String gender;
  String address;
  String bloodType;
  String height;
  String weight;

  // Medical History
  String chronicConditions;
  String pastSurgeries;
  String hospitalizations;

  // Medications & Allergies
  String currentMedications;
  String medicationAllergies;
  String foodAllergies;
  String environmentalAllergies;

  // Lifestyle Factors
  String smokingStatus;
  String alcoholConsumption;
  String exerciseHabits;

  // Emergency Contacts
  List<EmergencyContact> emergencyContacts;

  IceProfile({
    this.fullName = '',
    this.dateOfBirth,
    this.gender = '',
    this.bloodType = '',
    this.height = '',
    this.weight = '',
    this.address = '',
    this.chronicConditions = '',
    this.pastSurgeries = '',
    this.hospitalizations = '',
    this.currentMedications = '',
    this.medicationAllergies = '',
    this.foodAllergies = '',
    this.environmentalAllergies = '',
    this.smokingStatus = '',
    this.alcoholConsumption = '',
    this.exerciseHabits = '',
    List<EmergencyContact>? emergencyContacts,
  }) : emergencyContacts = emergencyContacts ?? [];
}
