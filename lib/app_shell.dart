import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'medication.dart';
import 'adherence_log.dart';
import 'history_page.dart';
import 'ice_profile.dart';
import 'ice_profile_page.dart';
import 'sos_page.dart';
import 'database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'health_report_page.dart';

class MedicationPage extends StatefulWidget {
  final void Function(bool) onThemeToggle;
  const MedicationPage({super.key, required this.onThemeToggle});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  int _navIndex = 0;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _isDarkMode = false;

  bool _notificationsEnabled = false;
  bool _notify1HourBefore = true;
  bool _notify30MinBefore = true;
  bool _notify5MinBefore = true;

  final List<AdherenceRecord> _adherenceLog = [];

  final Map<DateTime, List<Medication>> _events = {};

  final TextEditingController nameController = TextEditingController();
  final TextEditingController dosageController = TextEditingController();
  String _selectedFrequency = 'Daily';
  final List<String> _frequencyOptions = ['Daily', 'Every 2 Days', 'Weekly'];
  final TextEditingController durationController = TextEditingController();

  IceProfile _iceProfile = IceProfile();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadNotificationSettings();
    _loadFromDatabase();
    _requestExactAlarmPermissionOnFirstLaunch();
    _startMissedDoseChecker();
  }

  Future<void> _loadFromDatabase() async {
    final db = DatabaseHelper.instance;

    final loadedEvents = <DateTime, List<Medication>>{};
    final loadedAdherence = <AdherenceRecord>[];

    final meds = await db.getAllMedications();
    for (final row in meds) {
      final med = Medication(
        id: row['id'] as int,
        groupId: row['groupId'] as int?,
        name: row['name'] as String,
        dosage: row['dosage'] as String? ?? '',
        frequency: row['frequency'] as String? ?? '',
        duration: row['duration'] as int? ?? 1,
        date: row['date'] != null
            ? DateTime.parse(row['date'] as String)
            : null,
        status: DoseStatus.values.firstWhere(
          (e) => e.name == row['status'],
          orElse: () => DoseStatus.pending,
        ),
      );

      if (med.date != null) {
        final dayKey = _normalizeDate(med.date!);
        loadedEvents[dayKey] = (loadedEvents[dayKey] ?? [])..add(med);
      }

      await _scheduleNotificationsForMedication(med);
    }

    final records = await db.getAllAdherenceRecords();
    for (final row in records) {
      loadedAdherence.add(
        AdherenceRecord(
          medicationName: row['medicationName'] as String,
          dosage: row['dosage'] as String? ?? '',
          scheduledDate: DateTime.parse(row['scheduledDate'] as String),
          confirmedAt: row['confirmedAt'] != null
              ? DateTime.parse(row['confirmedAt'] as String)
              : null,
          status: DoseStatus.values.firstWhere(
            (e) => e.name == row['status'],
            orElse: () => DoseStatus.pending,
          ),
        ),
      );
    }

    final profile = await db.loadIceProfile();
    final contacts = await db.loadEmergencyContacts();

    if (!mounted) return;

    setState(() {
      _events
        ..clear()
        ..addAll(loadedEvents);

      _adherenceLog
        ..clear()
        ..addAll(loadedAdherence);

      if (profile != null) {
        _iceProfile = profile;
      } else {
        _iceProfile = IceProfile();
      }

      _iceProfile.emergencyContacts = contacts;
    });
  }

  Future<void> _requestExactAlarmPermissionOnFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('askedExactAlarmPermission') ?? false;

    if (hasAsked) return;

    await prefs.setBool('askedExactAlarmPermission', true);
    await NotificationService.instance.requestExactAlarmPermission();
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<Medication> _getEventsForDay(DateTime day) =>
      _events[_normalizeDate(day)] ?? [];

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
  }

  Future<void> _saveMedicationToDatabase(Medication medication) async {
    final id = await DatabaseHelper.instance.insertMedication(medication);
    medication.id = id;
  }

  Future<void> _deleteMedicationFromDatabase(Medication medication) async {
    if (medication.id == null) return;
    await DatabaseHelper.instance.deleteMedication(medication.id!);
  }

  Future<void> _markMedicationStatus(
    Medication medication,
    DoseStatus status,
  ) async {
    if (medication.id == null) return;
    await DatabaseHelper.instance.updateMedicationStatus(
      medication.id!,
      status,
    );
  }

  Future<void> _addAdherenceRecord(AdherenceRecord record) async {
    _adherenceLog.add(record);
    await DatabaseHelper.instance.insertAdherenceRecord(record);
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
      _notify1HourBefore = prefs.getBool('notify1HourBefore') ?? true;
      _notify30MinBefore = prefs.getBool('notify30MinBefore') ?? true;
      _notify5MinBefore = prefs.getBool('notify5MinBefore') ?? true;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('notify1HourBefore', _notify1HourBefore);
    await prefs.setBool('notify30MinBefore', _notify30MinBefore);
    await prefs.setBool('notify5MinBefore', _notify5MinBefore);
  }

  List<int> _notificationIdsForMedication(int medicationId) {
    return [
      medicationId * 10 + 1,
      medicationId * 10 + 2,
      medicationId * 10 + 3,
    ];
  }

  Future<void> _scheduleNotificationsForMedication(Medication med) async {
    if (!_notificationsEnabled ||
        med.id == null ||
        med.date == null ||
        med.status != DoseStatus.pending) {
      return;
    }
    final baseIds = _notificationIdsForMedication(med.id!);
    await NotificationService.instance.cancelMultiple(baseIds);

    final notificationTimes = <MapEntry<int, DateTime>>[];

    if (_notify1HourBefore) {
      notificationTimes.add(
        MapEntry(baseIds[0], med.date!.subtract(const Duration(hours: 1))),
      );
    }
    if (_notify30MinBefore) {
      notificationTimes.add(
        MapEntry(baseIds[1], med.date!.subtract(const Duration(minutes: 30))),
      );
    }
    if (_notify5MinBefore) {
      notificationTimes.add(
        MapEntry(baseIds[2], med.date!.subtract(const Duration(minutes: 5))),
      );
    }

    for (final entry in notificationTimes) {
      if (entry.value.isAfter(DateTime.now())) {
        await NotificationService.instance.scheduleMedicationReminder(
          id: entry.key,
          title: 'Medication Reminder',
          body:
              '${med.name} - ${med.dosage} at ${DateFormat('h:mm a').format(med.date!)}',
          scheduledTime: entry.value,
        );
      }
    }
  }

  Future<void> _cancelNotificationsForMedication(Medication med) async {
    if (med.id == null) return;
    await NotificationService.instance.cancelMultiple(
      _notificationIdsForMedication(med.id!),
    );
  }

  Future<void> _rescheduleAllMedicationNotifications() async {
    for (final meds in _events.values) {
      for (final med in meds) {
        await _scheduleNotificationsForMedication(med);
      }
    }
  }

  void _openAddEditBottomSheet({Medication? med, int? index}) {
    if (med != null) {
      nameController.text = med.name;
      dosageController.text = med.dosage;
      durationController.text = med.duration.toString();
    } else {
      nameController.clear();
      dosageController.clear();
      durationController.clear();
    }

    DateTime pickedDate = med?.date ?? _selectedDay ?? DateTime.now();
    String selectedFrequency = med?.frequency ?? _selectedFrequency;
    TimeOfDay pickedTime = med?.date != null
        ? TimeOfDay(hour: med!.date!.hour, minute: med.date!.minute)
        : TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      med == null ? 'Add Medication' : 'Edit Medication',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  nameController,
                  'Medication Name',
                  Icons.medication,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  dosageController,
                  'Dosage (e.g. 500mg)',
                  Icons.science_outlined,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedFrequency,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.indigo.withOpacity(0.7),
                      ),
                      items: _frequencyOptions
                          .map(
                            (f) => DropdownMenuItem(
                              value: f,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.loop,
                                    color: Colors.indigo.withOpacity(0.7),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(f, style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setSheetState(() => selectedFrequency = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  durationController,
                  'Number of Occurrences',
                  Icons.calendar_month,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final DateTime? chosen = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (chosen != null) {
                      setSheetState(() => pickedDate = chosen);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          color: Colors.indigo,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(pickedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_calendar_rounded,
                          color: Colors.indigo.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final TimeOfDay? chosen = await showTimePicker(
                      context: context,
                      initialTime: pickedTime,
                    );
                    if (chosen != null) {
                      setSheetState(() => pickedTime = chosen);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: Colors.indigo,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedTime.format(context),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_rounded,
                          color: Colors.indigo.withOpacity(0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty) return;
                          int interval = 1;
                          if (selectedFrequency == 'Every 2 Days') {
                            interval = 2;
                          }
                          if (selectedFrequency == 'Weekly') {
                            interval = 7;
                          }

                          if (med != null) {
                            final updatedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            final updatedMed = Medication(
                              id: med.id,
                              groupId: med.groupId,
                              name: nameController.text,
                              dosage: dosageController.text,
                              frequency: selectedFrequency,
                              duration:
                                  int.tryParse(durationController.text) ?? 1,
                              date: updatedDate,
                              status: med.status,
                            );

                            await _cancelNotificationsForMedication(med);

                            await DatabaseHelper.instance.updateMedication(
                              updatedMed.id!,
                              updatedMed,
                            );

                            await _scheduleNotificationsForMedication(
                              updatedMed,
                            );

                            setState(() {
                              for (final key in _events.keys) {
                                _events[key]?.removeWhere(
                                  (m) => m.id == med.id,
                                );
                              }

                              final newDayKey = _normalizeDate(updatedDate);
                              _events[newDayKey] = (_events[newDayKey] ?? [])
                                ..add(updatedMed);

                              _selectedDay = newDayKey;
                              _focusedDay = newDayKey;
                            });
                          } else {
                            final int newGroupId =
                                DateTime.now().millisecondsSinceEpoch;
                            final int occurrences =
                                int.tryParse(durationController.text) ?? 1;

                            for (int i = 0; i < occurrences; i++) {
                              final entryDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day + (i * interval),
                                pickedTime.hour,
                                pickedTime.minute,
                              );

                              final newMed = Medication(
                                groupId: newGroupId,
                                name: nameController.text,
                                dosage: dosageController.text,
                                frequency: selectedFrequency,
                                duration: occurrences,
                                date: entryDate,
                              );

                              await _saveMedicationToDatabase(newMed);
                              await _scheduleNotificationsForMedication(newMed);

                              setState(() {
                                final dayKey = _normalizeDate(entryDate);
                                _events[dayKey] = (_events[dayKey] ?? [])
                                  ..add(newMed);
                              });
                            }

                            setState(() {
                              _selectedDay = _normalizeDate(pickedDate);
                              _focusedDay = _normalizeDate(pickedDate);
                            });
                          }

                          Navigator.pop(context);
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Theme.of(context).cardColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          med == null ? 'Schedule Reminder' : 'Update',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.indigo.withOpacity(0.7), size: 20),
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomePage(),
          _buildSosPage(),
          _buildIcePage(),
          _buildSettingsPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEditBottomSheet(),
        backgroundColor: Colors.indigo,
        foregroundColor: Theme.of(context).cardColor,
        elevation: 4,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final titles = [
      'Medication Reminder',
      'Emergency SOS',
      'Medical Profile',
      'Settings',
    ];
    return AppBar(
      title: Text(titles[_navIndex]),
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Theme.of(context).cardColor,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      actions: _navIndex == 0
          ? [
              TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      height: MediaQuery.of(context).size.height * 0.75,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),

                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Medication History',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: HistoryPage(records: _adherenceLog)),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.history_rounded,
                  color: Colors.indigo,
                  size: 18,
                ),
                label: const Text(
                  'History',
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ]
          : _navIndex == 2
          ? [
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthReportPage(
                        profile: _iceProfile,
                        records: _adherenceLog,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.assessment_rounded,
                  color: Colors.indigo,
                  size: 18,
                ),
                label: const Text(
                  'Health Report',
                  style: TextStyle(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ]
          : null,
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      color: Theme.of(context).cardColor,
      surfaceTintColor: Theme.of(context).cardColor,
      elevation: 12,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_rounded, 'Medicine', 0),
            _navItem(Icons.sos_rounded, 'SOS', 1),
            const SizedBox(width: 64),
            _navItem(Icons.medical_information_rounded, 'Profile', 2),
            _navItem(Icons.settings_rounded, 'Settings', 3),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final active = _navIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _navIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.indigo.withOpacity(0.09) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active
                  ? Colors.indigo
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.indigo
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePage() {
    final events = _getEventsForDay(_selectedDay!);

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(child: _buildCalendar()),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        SliverToBoxAdapter(child: _buildHeader(events.length)),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (events.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildMedicationCard(events[index], index),
                childCount: events.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMedicationCard(Medication med, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication,
                  color: Colors.teal,
                  size: 22,
                ),
              ),
              title: Text(
                med.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${med.dosage} - ${med.frequency}\n'
                'Time: ${med.date != null ? DateFormat('h:mm a').format(med.date!) : 'No time'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              trailing: PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (val) async {
                  if (val == 'edit') {
                    _openAddEditBottomSheet(med: med, index: index);
                  } else {
                    await _cancelNotificationsForMedication(med);
                    await _deleteMedicationFromDatabase(med);

                    setState(() {
                      for (final key in _events.keys) {
                        _events[key]?.removeWhere((m) => m.id == med.id);
                      }
                    });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
            if (med.status == DoseStatus.pending)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final record = AdherenceRecord(
                            medicationName: med.name,
                            dosage: med.dosage,
                            scheduledDate: med.date ?? _selectedDay!,
                            confirmedAt: null,
                            status: DoseStatus.missed,
                          );

                          await _cancelNotificationsForMedication(med);
                          await _markMedicationStatus(med, DoseStatus.missed);

                          setState(() => med.status = DoseStatus.missed);
                          await _addAdherenceRecord(record);
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Missed'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final record = AdherenceRecord(
                            medicationName: med.name,
                            dosage: med.dosage,
                            scheduledDate: med.date ?? _selectedDay!,
                            confirmedAt: DateTime.now(),
                            status: DoseStatus.taken,
                          );

                          await _cancelNotificationsForMedication(med);
                          await _markMedicationStatus(med, DoseStatus.taken);

                          setState(() => med.status = DoseStatus.taken);
                          await _addAdherenceRecord(record);
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Confirm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Theme.of(context).cardColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: med.status == DoseStatus.taken
                        ? Colors.teal.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        med.status == DoseStatus.taken
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: med.status == DoseStatus.taken
                            ? Colors.teal
                            : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        med.status == DoseStatus.taken ? 'Taken' : 'Missed',
                        style: TextStyle(
                          color: med.status == DoseStatus.taken
                              ? Colors.teal
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2010, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: _onDaySelected,
        eventLoader: _getEventsForDay,
        calendarStyle: CalendarStyle(
          todayDecoration: const BoxDecoration(
            color: Color(0xFF7986CB),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: Colors.indigo,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(0xFF26A69A),
            shape: BoxShape.circle,
          ),
          markerMargin: const EdgeInsets.only(top: 1),
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.red.shade300),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    final dayNum = DateFormat('d').format(_selectedDay!);
    final dayName = DateFormat('EEEE').format(_selectedDay!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              dayNum,
              style: TextStyle(
                color: Theme.of(context).cardColor,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: count > 0
                  ? Colors.indigo.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.medication_rounded,
                  size: 14,
                  color: count > 0
                      ? Colors.indigo
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count ${count == 1 ? 'Reminder' : 'Reminders'}',
                  style: TextStyle(
                    color: count > 0
                        ? Colors.indigo
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders for this day',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap  +  to add a medication',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      children: [
        _settingsSection('Notifications', [
          _settingsTile(
            Icons.notifications_rounded,
            'Medication Reminders',
            'Enable or disable reminder notifications',
            hasSwitch: true,
            switchValue: _notificationsEnabled,
            onSwitchChanged: (val) async {
              if (val) {
                final granted = await NotificationService.instance
                    .requestExactAlarmPermission();

                if (!granted) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Exact alarm permission is required for precise reminders',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }
              setState(() => _notificationsEnabled = val);
              await _saveNotificationSettings();

              if (_notificationsEnabled) {
                await _rescheduleAllMedicationNotifications();
              } else {
                for (final meds in _events.values) {
                  for (final med in meds) {
                    await _cancelNotificationsForMedication(med);
                  }
                }
              }
            },
          ),
          if (_notificationsEnabled)
            CheckboxListTile(
              value: _notify5MinBefore,
              onChanged: (val) async {
                setState(() => _notify5MinBefore = val ?? false);
                await _saveNotificationSettings();
                await _rescheduleAllMedicationNotifications();
              },
              title: const Text('5 Minutes Before'),
              subtitle: const Text('Notify 5 minutes before medication time'),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: Colors.indigo,
            ),
          if (_notificationsEnabled)
            CheckboxListTile(
              value: _notify30MinBefore,
              onChanged: (val) async {
                setState(() => _notify30MinBefore = val ?? false);
                await _saveNotificationSettings();
                await _rescheduleAllMedicationNotifications();
              },
              title: const Text('30 Minutes Before'),
              subtitle: const Text('Notify 30 minutes before medication time'),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: Colors.indigo,
            ),
          if (_notificationsEnabled)
            CheckboxListTile(
              value: _notify1HourBefore,
              onChanged: (val) async {
                setState(() => _notify1HourBefore = val ?? false);
                await _saveNotificationSettings();
                await _rescheduleAllMedicationNotifications();
              },
              title: const Text('1 Hour Before'),
              subtitle: const Text('Notify 1 hour before medication time'),
              controlAffinity: ListTileControlAffinity.trailing,
              activeColor: Colors.indigo,
            ),
        ]),

        const SizedBox(height: 16),
        _settingsSection('Appearance', [
          _settingsTile(
            Icons.dark_mode_rounded,
            'Dark Mode',
            'Switch to dark theme',
            hasSwitch: true,
            switchValue: _isDarkMode,
            onSwitchChanged: (val) {
              setState(() => _isDarkMode = val);
              widget.onThemeToggle(val);
            },
          ),
          _settingsTile(Icons.language_rounded, 'Language', 'English'),
        ]),
        const SizedBox(height: 16),
        _settingsSection('About', [
          _settingsTile(Icons.info_outline_rounded, 'App Version', '1.0.0'),
          _settingsTile(
            Icons.people_rounded,
            'Our Team',
            'Bader Almetairi. \nAli Alhamood. \nAbdullah Alsharedah. \nQaem  Almanasif. \nHussam Almahri. \nAmmar Barayyan.',
          ),
        ]),
      ],
    );
  }

  Widget _settingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.surfaceVariant,
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title,
    String subtitle, {
    bool hasSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.indigo, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: hasSwitch
          ? Switch(
              value: switchValue,
              onChanged: onSwitchChanged,
              activeColor: Colors.indigo,
            )
          : null,
    );
  }

  void _startMissedDoseChecker() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (!mounted) return false;

      final now = DateTime.now();
      for (final meds in _events.values) {
        for (final med in meds) {
          if (med.status == DoseStatus.pending && med.date != null) {
            final cutoff = med.date!.add(const Duration(minutes: 30));
            if (now.isAfter(cutoff)) {
              final record = AdherenceRecord(
                medicationName: med.name,
                dosage: med.dosage,
                scheduledDate: med.date!,
                confirmedAt: null,
                status: DoseStatus.missed,
              );

              await _cancelNotificationsForMedication(med);
              await _markMedicationStatus(med, DoseStatus.missed);

              if (!mounted) return false;
              setState(() {
                med.status = DoseStatus.missed;
                _adherenceLog.add(record);
              });

              await DatabaseHelper.instance.insertAdherenceRecord(record);
            }
          }
        }
      }

      return true;
    });
  }

  Widget _buildSosPage() {
    return SosPage(profile: _iceProfile);
  }

  Widget _buildIcePage() {
    return IceProfilePage(profile: _iceProfile);
  }
}
