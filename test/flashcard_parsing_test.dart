import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flashcard JSON parsing verification', () {
    const jsonString = '''
    [
      {"question": "What is Isar?", "answer": "A fast NoSQL database for Flutter."},
      {"question": "What is Gemini?", "answer": "An AI model by Google."}
    ]
    ''';

    final List<dynamic> decoded = jsonDecode(jsonString);
    expect(decoded.length, 2);
    expect(decoded[0]['question'], 'What is Isar?');
    expect(decoded[1]['answer'], 'An AI model by Google.');
  });

  test('Flashcard JSON parsing with extra text (Simulating AI noise)', () {
    const noisyJson = '''
    Here are the flashcards:
    [
      {"question": "Q1", "answer": "A1"}
    ]
    Hope this helps!
    ''';

    // Simplified extraction logic that we used in the screens
    final startIndex = noisyJson.indexOf('[');
    final endIndex = noisyJson.lastIndexOf(']') + 1;
    
    if (startIndex != -1 && endIndex != -1) {
      final jsonPart = noisyJson.substring(startIndex, endIndex);
      final List<dynamic> decoded = jsonDecode(jsonPart);
      expect(decoded.length, 1);
      expect(decoded[0]['question'], 'Q1');
    } else {
      fail('Could not find JSON array');
    }
  });
}
