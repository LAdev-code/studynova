import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard.dart';
import '../models/study_material.dart';
import '../models/event.dart';

class DatabaseService {
  late Future<Isar> db;

  DatabaseService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    final dir = await getApplicationDocumentsDirectory();
    if (Isar.instanceNames.isEmpty) {
      return await Isar.open(
        [FlashcardSchema, StudyMaterialSchema, EventSchema],
        directory: dir.path,
      );
    }
    return Isar.getInstance()!;
  }

  // Flashcard methods
  Future<void> saveFlashcard(Flashcard flashcard) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.flashcards.put(flashcard);
    });
  }

  Future<void> saveFlashcards(List<Flashcard> flashcards) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.flashcards.putAll(flashcards);
    });
  }

  Future<List<Flashcard>> getFlashcardsBySubject(String subject) async {
    final isar = await db;
    if (subject == 'All') {
      return await isar.flashcards.where().findAll();
    }
    return await isar.flashcards.filter().subjectEqualTo(subject).findAll();
  }

  Future<List<Flashcard>> getFlashcardsByMaterial(Id materialId) async {
    final isar = await db;
    return await isar.flashcards.filter().materialIdEqualTo(materialId).findAll();
  }

  Future<List<Flashcard>> getDueFlashcards() async {
    final isar = await db;
    final now = DateTime.now();
    return await isar.flashcards.filter()
        .nextReviewDateLessThan(now)
        .or()
        .nextReviewDateIsNull()
        .findAll();
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.flashcards.put(flashcard);
    });
  }

  Future<void> deleteFlashcard(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.flashcards.delete(id);
    });
  }

  // StudyMaterial methods
  Future<void> saveStudyMaterial(StudyMaterial material) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.studyMaterials.put(material);
    });
  }

  Future<List<StudyMaterial>> getAllStudyMaterials() async {
    final isar = await db;
    return await isar.studyMaterials.where().findAll();
  }

  Future<List<StudyMaterial>> searchStudyMaterials(String query) async {
    final isar = await db;
    return await isar.studyMaterials.filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .findAll();
  }

  Future<void> deleteStudyMaterial(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.studyMaterials.delete(id);
    });
  }

  // Event methods
  Future<void> saveEvent(Event event) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.events.put(event);
    });
  }

  Future<void> updateEvent(Event event) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.events.put(event);
    });
  }

  Future<void> deleteEvent(Id id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.events.delete(id);
    });
  }

  Future<List<Event>> getEventsForDate(DateTime date) async {
    final isar = await db;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return await isar.events.filter()
        .dateTimeBetween(startOfDay, endOfDay)
        .findAll();
  }

  Future<List<String>> getAllSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final storedSubjects = prefs.getStringList('custom_subjects') ?? <String>[];

    final isar = await db;
    final materials = await isar.studyMaterials.where().findAll();
    final flashcards = await isar.flashcards.where().findAll();
    final events = await isar.events.where().findAll();

    final subjects = <String>{'General'};
    for (var subject in storedSubjects) {
      final cleaned = subject.trim();
      if (cleaned.isNotEmpty) subjects.add(cleaned);
    }
    for (var m in materials) {
      final subject = m.subject.trim();
      if (subject.isNotEmpty) subjects.add(subject);
    }
    for (var f in flashcards) {
      final subject = f.subject.trim();
      if (subject.isNotEmpty) subjects.add(subject);
    }
    for (var event in events) {
      final subject = (event.relatedSubject ?? '').trim();
      if (subject.isNotEmpty) subjects.add(subject);
    }
    return subjects.toList()..sort();
  }

  Future<void> saveSubject(String subject) async {
    final cleaned = subject.trim();
    if (cleaned.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList('custom_subjects') ?? <String>[];
    final next = <String>{...current, cleaned}.toList()..sort();
    await prefs.setStringList('custom_subjects', next);
  }
}
