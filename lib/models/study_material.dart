import 'package:isar/isar.dart';

part 'study_material.g.dart';

@collection
class StudyMaterial {
  Id id = Isar.autoIncrement;

  late String title;
  late String content; // Transcribed text or summary
  
  @Index()
  late String subject;
  
  late DateTime createdAt;
  
  String? filePath; // Path to original PDF/Audio if available
  
  String type = 'note'; // 'note', 'summary', 'transcript'
}
