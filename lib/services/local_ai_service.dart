import 'package:flutter/foundation.dart';
import 'package:flutter_local_ai/flutter_local_ai.dart';

class LocalAiService {
  final FlutterLocalAi _engine = FlutterLocalAi();
  bool? _available;

  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      _available = await _engine.isAvailable();
    } catch (error) {
      debugPrint('Local AI unavailable: $error');
      _available = false;
    }
    return _available!;
  }

  Future<String?> generateText(String prompt) async {
    if (!await isAvailable()) return null;
    try {
      final response = await _engine.generateTextSimple(
        prompt: prompt,
        maxTokens: 512,
      );
      return response.trim().isEmpty ? null : response;
    } catch (error) {
      debugPrint('Gemini Nano generation failed: $error');
      return null;
    }
  }
}
