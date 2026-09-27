import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'local_ai_service.dart';

class GeminiService {
  final String apiKey;
  final LocalAiService _localAiService = LocalAiService();
  late final GenerativeModel? _model;

  GeminiService({required this.apiKey}) {
    if (apiKey.trim().isNotEmpty) {
      _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    } else {
      _model = null;
      debugPrint('WARNING: Gemini API Key is empty. Cloud AI features will be disabled until a key is provided.');
    }
  }

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// Processes text input (e.g., lecture transcript)
  Future<String?> processText(String prompt) async {
    try {
      final localResponse = await _localAiService.generateText(prompt);
      if (localResponse != null) return localResponse;

      if (_model == null) {
        debugPrint('Cannot process text with Gemini: API key is not configured.');
        return null;
      }

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error processing text with Gemini: $e');
      return null;
    }
  }

  /// Processes multimodal input (images, PDFs as bytes)
  Future<String?> processMultimodal({
    required String prompt,
    required List<Uint8List> fileBytes,
    required String mimeType,
  }) async {
    try {
      if (_model == null) {
        debugPrint('Cannot process multimodal with Gemini: API key is not configured.');
        return null;
      }

      final content = [
        Content.multi([
          TextPart(prompt),
          ...fileBytes.map((bytes) => DataPart(mimeType, bytes)),
        ]),
      ];
      final response = await _model.generateContent(content);
      return response.text;
    } catch (e) {
      debugPrint('Error processing multimodal with Gemini: $e');
      return null;
    }
  }

  /// Specialized method to generate flashcards from content
  Future<String?> generateFlashcards(String contentText) async {
    final prompt =
        '''
    Analyze the following study material and generate a list of 5-10 flashcards.
    Return ONLY a JSON array of objects. Each object must have "question" and "answer" fields.
    Example: [{"question": "What is Flutter?", "answer": "A UI toolkit for building natively compiled apps."}]
    Material: $contentText
    ''';
    return processText(prompt);
  }

  /// Interactive chat with specific study context
  Future<String?> chatWithContext({
    required String userMessage,
    required String contextMaterial,
    List<Content>? history,
  }) async {
    try {
      if (_model == null) {
        debugPrint('Cannot start chat: Gemini API key is not configured.');
        return 'Gemini API key is not configured. Please supply GEMINI_API_KEY to enable AI chat.';
      }

      final chat = _model.startChat(history: history);
      final prompt =
          '''
      Context Material: $contextMaterial
      ---
      User says: "$userMessage"
      ---
      Instructions: Use the Context Material provided above to answer the user's message. 
      Be concise, helpful, and act like a friendly university tutor.
      ''';
      final response = await chat.sendMessage(Content.text(prompt));
      return response.text;
    } catch (e) {
      debugPrint('Error in contextual chat: $e');
      return null;
    }
  }

  /// Specific helper to extract assignments/deadlines into JSON
  Future<String?> extractDeadlines(String text) async {
    final prompt =
        '''
    Extract all assignment names and deadlines from the following text. 
    Return the result as a JSON list of objects with "title" and "dueDate" (ISO 8601) fields.
    Text: $text
    ''';
    return processText(prompt);
  }
}
