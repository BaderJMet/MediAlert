import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'medication.dart';
import 'adherence_log.dart';
import 'ice_profile.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'medication_app.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      groupId INTEGER,
      name TEXT NOT NULL,
      dosage TEXT,
      frequency TEXT,
      duration INTEGER,
      date TEXT,
      status TEXT DEFAULT 'pending'
    )
    ''');

    await db.execute('''
      CREATE TABLE adherence_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicationName TEXT NOT NULL,
        dosage TEXT,
        scheduledDate TEXT NOT NULL,
        confirmedAt TEXT,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ice_profile (
        id INTEGER PRIMARY KEY,
        fullName TEXT,
        dateOfBirth TEXT,
        gender TEXT,
        address TEXT,
        bloodType TEXT,
        height TEXT,
        weight TEXT,
        chronicConditions TEXT,
        pastSurgeries TEXT,
        hospitalizations TEXT,
        currentMedications TEXT,
        medicationAllergies TEXT,
        foodAllergies TEXT,
        environmentalAllergies TEXT,
        smokingStatus TEXT,
        alcoholConsumption TEXT,
        exerciseHabits TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertMedication(Medication med) async {
    final db = await database;
    return db.insert('medications', {
      'groupId': med.groupId,
      'name': med.name,
      'dosage': med.dosage,
      'frequency': med.frequency,
      'duration': med.duration,
      'date': med.date?.toIso8601String(),
      'status': med.status.name,
    });
  }

  Future<void> updateMedication(int id, Medication med) async {
    final db = await database;
    await db.update(
      'medications',
      {
        'groupId': med.groupId,
        'name': med.name,
        'dosage': med.dosage,
        'frequency': med.frequency,
        'duration': med.duration,
        'date': med.date?.toIso8601String(),
        'status': med.status.name,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllMedications() async {
    final db = await database;
    return db.query('medications');
  }

  Future<void> updateMedicationStatus(int id, DoseStatus status) async {
    final db = await database;
    await db.update(
      'medications',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertAdherenceRecord(AdherenceRecord record) async {
    final db = await database;
    await db.insert('adherence_log', {
      'medicationName': record.medicationName,
      'dosage': record.dosage,
      'scheduledDate': record.scheduledDate.toIso8601String(),
      'confirmedAt': record.confirmedAt?.toIso8601String(),
      'status': record.status.name,
    });
  }

  Future<List<Map<String, dynamic>>> getAllAdherenceRecords() async {
    final db = await database;
    return db.query('adherence_log');
  }

  Future<void> saveIceProfile(IceProfile profile) async {
    final db = await database;
    await db.insert('ice_profile', {
      'id': 1,
      'fullName': profile.fullName,
      'dateOfBirth': profile.dateOfBirth?.toIso8601String(),
      'gender': profile.gender,
      'address': profile.address,
      'bloodType': profile.bloodType,
      'height': profile.height,
      'weight': profile.weight,
      'chronicConditions': profile.chronicConditions,
      'pastSurgeries': profile.pastSurgeries,
      'hospitalizations': profile.hospitalizations,
      'currentMedications': profile.currentMedications,
      'medicationAllergies': profile.medicationAllergies,
      'foodAllergies': profile.foodAllergies,
      'environmentalAllergies': profile.environmentalAllergies,
      'smokingStatus': profile.smokingStatus,
      'alcoholConsumption': profile.alcoholConsumption,
      'exerciseHabits': profile.exerciseHabits,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<IceProfile?> loadIceProfile() async {
    final db = await database;
    final results = await db.query(
      'ice_profile',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (results.isEmpty) return null;
    final row = results.first;
    return IceProfile(
      fullName: row['fullName'] as String? ?? '',
      dateOfBirth: row['dateOfBirth'] != null
          ? DateTime.parse(row['dateOfBirth'] as String)
          : null,
      gender: row['gender'] as String? ?? '',
      address: row['address'] as String? ?? '',
      bloodType: row['bloodType'] as String? ?? '',
      height: row['height'] as String? ?? '',
      weight: row['weight'] as String? ?? '',
      chronicConditions: row['chronicConditions'] as String? ?? '',
      pastSurgeries: row['pastSurgeries'] as String? ?? '',
      hospitalizations: row['hospitalizations'] as String? ?? '',
      currentMedications: row['currentMedications'] as String? ?? '',
      medicationAllergies: row['medicationAllergies'] as String? ?? '',
      foodAllergies: row['foodAllergies'] as String? ?? '',
      environmentalAllergies: row['environmentalAllergies'] as String? ?? '',
      smokingStatus: row['smokingStatus'] as String? ?? '',
      alcoholConsumption: row['alcoholConsumption'] as String? ?? '',
      exerciseHabits: row['exerciseHabits'] as String? ?? '',
    );
  }

  Future<void> insertEmergencyContact(EmergencyContact contact) async {
    final db = await database;
    await db.insert('emergency_contacts', {
      'name': contact.name,
      'phone': contact.phone,
    });
  }

  Future<void> deleteEmergencyContact(int id) async {
    final db = await database;
    await db.delete('emergency_contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<EmergencyContact>> loadEmergencyContacts() async {
    final db = await database;
    final results = await db.query('emergency_contacts');
    return results
        .map(
          (row) => EmergencyContact(
            name: row['name'] as String,
            phone: row['phone'] as String,
          ),
        )
        .toList();
  }
}
