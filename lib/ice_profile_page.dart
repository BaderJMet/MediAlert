import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'ice_profile.dart';
import 'database_helper.dart';

class IceProfilePage extends StatefulWidget {
  final IceProfile profile;
  const IceProfilePage({super.key, required this.profile});

  @override
  State<IceProfilePage> createState() => _IceProfilePageState();
}

class _IceProfilePageState extends State<IceProfilePage> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _chronicController = TextEditingController();
  final _surgeriesController = TextEditingController();
  final _hospitalizationsController = TextEditingController();
  final _currentMedsController = TextEditingController();
  final _medAllergiesController = TextEditingController();
  final _foodAllergiesController = TextEditingController();
  final _envAllergiesController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodType;
  String? _selectedSmoking;
  String? _selectedAlcohol;
  String? _selectedExercise;

  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _bloodTypeOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  final List<String> _smokingOptions = [
    'Non-smoker',
    'Former smoker',
    'Current smoker',
  ];
  final List<String> _alcoholOptions = [
    'None',
    'Occasional',
    'Moderate',
    'Heavy',
  ];
  final List<String> _exerciseOptions = [
    'Sedentary',
    'Light',
    'Moderate',
    'Active',
  ];

  final Map<String, bool> _expanded = {
    'personal': true,
    'medical': false,
    'allergies': false,
    'lifestyle': false,
    'contacts': false,
  };

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController.text = p.fullName;
    _addressController.text = p.address;
    _heightController.text = p.height;
    _weightController.text = p.weight;
    _chronicController.text = p.chronicConditions;
    _surgeriesController.text = p.pastSurgeries;
    _hospitalizationsController.text = p.hospitalizations;
    _currentMedsController.text = p.currentMedications;
    _medAllergiesController.text = p.medicationAllergies;
    _foodAllergiesController.text = p.foodAllergies;
    _envAllergiesController.text = p.environmentalAllergies;
    _selectedGender = p.gender.isEmpty ? null : p.gender;
    _selectedBloodType = p.bloodType.isEmpty ? null : p.bloodType;
    _selectedSmoking = p.smokingStatus.isEmpty ? null : p.smokingStatus;
    _selectedAlcohol = p.alcoholConsumption.isEmpty
        ? null
        : p.alcoholConsumption;
    _selectedExercise = p.exerciseHabits.isEmpty ? null : p.exerciseHabits;
  }

  @override
  void didUpdateWidget(covariant IceProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile != widget.profile) {
      final p = widget.profile;
      _nameController.text = p.fullName;
      _addressController.text = p.address;
      _heightController.text = p.height;
      _weightController.text = p.weight;
      _chronicController.text = p.chronicConditions;
      _surgeriesController.text = p.pastSurgeries;
      _hospitalizationsController.text = p.hospitalizations;
      _currentMedsController.text = p.currentMedications;
      _medAllergiesController.text = p.medicationAllergies;
      _foodAllergiesController.text = p.foodAllergies;
      _envAllergiesController.text = p.environmentalAllergies;

      _selectedGender = p.gender.isEmpty ? null : p.gender;
      _selectedBloodType = p.bloodType.isEmpty ? null : p.bloodType;
      _selectedSmoking = p.smokingStatus.isEmpty ? null : p.smokingStatus;
      _selectedAlcohol = p.alcoholConsumption.isEmpty
          ? null
          : p.alcoholConsumption;
      _selectedExercise = p.exerciseHabits.isEmpty ? null : p.exerciseHabits;
    }
  }

  Future<void> _saveProfile() async {
    final p = widget.profile;
    p.fullName = _nameController.text;
    p.address = _addressController.text;
    p.height = _heightController.text;
    p.weight = _weightController.text;
    p.chronicConditions = _chronicController.text;
    p.pastSurgeries = _surgeriesController.text;
    p.hospitalizations = _hospitalizationsController.text;
    p.currentMedications = _currentMedsController.text;
    p.medicationAllergies = _medAllergiesController.text;
    p.foodAllergies = _foodAllergiesController.text;
    p.environmentalAllergies = _envAllergiesController.text;
    p.gender = _selectedGender ?? '';
    p.bloodType = _selectedBloodType ?? '';
    p.smokingStatus = _selectedSmoking ?? '';
    p.alcoholConsumption = _selectedAlcohol ?? '';
    p.exerciseHabits = _selectedExercise ?? '';

    await DatabaseHelper.instance.saveIceProfile(p);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved!'),
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _addContact() async {
    if (_contactNameController.text.isNotEmpty &&
        _contactPhoneController.text.isNotEmpty) {
      final contact = EmergencyContact(
        name: _contactNameController.text,
        phone: _contactPhoneController.text,
      );

      await DatabaseHelper.instance.insertEmergencyContact(contact);

      setState(() {
        widget.profile.emergencyContacts.add(contact);
        _contactNameController.clear();
        _contactPhoneController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _buildSection(
          key: 'personal',
          icon: Icons.person_rounded,
          title: 'Personal Information',
          color: Colors.indigo,
          children: [
            _buildLabel('Full Name'),
            _buildTextField(
              _nameController,
              'e.g. John Smith',
              Icons.badge_rounded,
            ),
            const SizedBox(height: 16),
            _buildLabel('Date of Birth'),
            _buildDateOfBirth(),
            const SizedBox(height: 16),
            _buildLabel('Gender'),
            _buildDropdown(
              'Select gender',
              _genderOptions,
              _selectedGender,
              (val) => setState(() => _selectedGender = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Blood Type'),
            _buildDropdown(
              'Select blood type',
              _bloodTypeOptions,
              _selectedBloodType,
              (val) => setState(() => _selectedBloodType = val),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Height (cm)'),
                      _buildTextField(
                        _heightController,
                        'e.g. 175',
                        Icons.height_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Weight (kg)'),
                      _buildTextField(
                        _weightController,
                        'e.g. 70',
                        Icons.monitor_weight_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel('Address'),
            _buildTextField(
              _addressController,
              'e.g. 123 Main St',
              Icons.home_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSection(
          key: 'medical',
          icon: Icons.local_hospital_rounded,
          title: 'Medical History',
          color: Colors.red,
          children: [
            _buildLabel('Chronic Conditions'),
            _buildTextField(
              _chronicController,
              'e.g. Diabetes, Hypertension',
              Icons.monitor_heart_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildLabel('Past Surgeries'),
            _buildTextField(
              _surgeriesController,
              'e.g. Appendectomy 2018',
              Icons.medical_services_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildLabel('Hospitalizations'),
            _buildTextField(
              _hospitalizationsController,
              'e.g. Pneumonia 2020',
              Icons.local_hospital_rounded,
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSection(
          key: 'allergies',
          icon: Icons.medication_rounded,
          title: 'Medications & Allergies',
          color: Colors.orange,
          children: [
            _buildLabel('Current Medications'),
            _buildTextField(
              _currentMedsController,
              'e.g. Metformin 500mg',
              Icons.medication_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildLabel('Medication Allergies'),
            _buildTextField(
              _medAllergiesController,
              'e.g. Penicillin',
              Icons.warning_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildLabel('Food Allergies'),
            _buildTextField(
              _foodAllergiesController,
              'e.g. Peanuts, Shellfish',
              Icons.no_food_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildLabel('Environmental Allergies'),
            _buildTextField(
              _envAllergiesController,
              'e.g. Pollen, Dust',
              Icons.air_rounded,
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSection(
          key: 'lifestyle',
          icon: Icons.self_improvement_rounded,
          title: 'Lifestyle Factors',
          color: Colors.green,
          children: [
            _buildLabel('Smoking Status'),
            _buildDropdown(
              'Select smoking status',
              _smokingOptions,
              _selectedSmoking,
              (val) => setState(() => _selectedSmoking = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Alcohol Consumption'),
            _buildDropdown(
              'Select alcohol consumption',
              _alcoholOptions,
              _selectedAlcohol,
              (val) => setState(() => _selectedAlcohol = val),
            ),
            const SizedBox(height: 16),
            _buildLabel('Exercise Habits'),
            _buildDropdown(
              'Select exercise habits',
              _exerciseOptions,
              _selectedExercise,
              (val) => setState(() => _selectedExercise = val),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSection(
          key: 'contacts',
          icon: Icons.contacts_rounded,
          title: 'Emergency Contacts',
          color: Colors.teal,
          children: [
            ...widget.profile.emergencyContacts.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.teal.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            c.phone,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final contact = widget.profile.emergencyContacts[i];
                        final db = await DatabaseHelper.instance.database;

                        await db.delete(
                          'emergency_contacts',
                          where: 'name = ? AND phone = ?',
                          whereArgs: [contact.name, contact.phone],
                        );

                        setState(
                          () => widget.profile.emergencyContacts.removeAt(i),
                        );
                      },
                      icon: const Icon(
                        Icons.delete_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            _buildLabel('Contact Name'),
            _buildTextField(
              _contactNameController,
              'e.g. Sarah Smith',
              Icons.person_add_rounded,
            ),
            const SizedBox(height: 12),
            _buildLabel('Phone Number'),
            _buildTextField(
              _contactPhoneController,
              'e.g. +1234567890',
              Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addContact,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Contact'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Theme.of(context).cardColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text(
              'Save Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Theme.of(context).cardColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String key,
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    final isExpanded = _expanded[key] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded[key] = !isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.7), size: 20),
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    List<String> options,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.indigo.withOpacity(0.7),
          ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDateOfBirth() {
    final dob = widget.profile.dateOfBirth;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: dob ?? DateTime(1970),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => widget.profile.dateOfBirth = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_rounded,
              color: Colors.indigo.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              dob != null
                  ? DateFormat('MMMM d, yyyy').format(dob)
                  : 'Select date of birth',
              style: TextStyle(
                color: dob != null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
