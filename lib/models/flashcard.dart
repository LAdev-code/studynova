import 'package:isar/isar.dart';

part 'flashcard.g.dart';

@collection
class Flashcard {
  Id id = Isar.autoIncrement;

  late String question;
  late String answer;
  
  @Index()
  late String subject;

  @Index()
  int? materialId; // Link to source material

  double masteryLevel = 0.0; // 0.0 to 1.0
  
  // SRS Fields
  int interval = 0; // In days
  double easeFactor = 2.5; 
  DateTime? nextReviewDate;
  
  DateTime? lastReviewed;
}
