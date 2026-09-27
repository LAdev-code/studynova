import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OnDeviceTextService {
  Future<String?> extractTextFromFile(String filePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await recognizer.processImage(inputImage);
      final text = recognizedText.text.trim();
      return text.isEmpty ? null : text;
    } finally {
      await recognizer.close();
    }
  }
}
