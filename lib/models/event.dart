import 'package:isar/isar.dart';

part 'event.g.dart';

@collection
class Event {
  Id id = Isar.autoIncrement;

  late String title;
  late String description;
  
  late DateTime dateTime;
  
  bool isCompleted = false;
  
  String? relatedSubject;
}
