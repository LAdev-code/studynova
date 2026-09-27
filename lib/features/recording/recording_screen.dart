import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/services.dart';
import '../../services/gemini_service.dart';
import '../../services/database_service.dart';
import '../../models/study_material.dart';
import '../../models/flashcard.dart';

class RecordingScreen extends StatefulWidget {
  final GeminiService geminiService;
  final DatabaseService databaseService;

  const RecordingScreen({
    super.key,
    required this.geminiService,
    required this.databaseService,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessing = false;
  String? _errorMessage;
  
  Timer? _timer;
  Timer? _recordingTimer;
  int _recordDuration = 0;
  List<double> _amplitudes = [];

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        HapticFeedback.mediumImpact();
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/lecture_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 128000,
        );

        await _audioRecorder.start(config, path: path);
        setState(() {
          _isRecording = true;
          _isPaused = false;
          _isProcessing = false;
          _errorMessage = null;
          _amplitudes = [];
          _recordDuration = 0;
        });
        
        _startAmplitudeTimer();
        _startRecordingTimer();
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() => _errorMessage = 'Could not start recording. Please check microphone permissions.');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && !_isPaused) {
        setState(() => _recordDuration++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _startAmplitudeTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_isRecording && !_isPaused) {
        final amp = await _audioRecorder.getAmplitude();
        setState(() {
          // Normalize amp.current (-160 to 0) to 0.0 to 1.0, with a floor at 0.01 for visibility
          double normalized = ((amp.current + 160) / 160).clamp(0.01, 1.0);
          _amplitudes.add(normalized);
          if (_amplitudes.length > 40) _amplitudes.removeAt(0);
        });
      }
    });
  }

  Future<void> _pauseRecording() async {
    HapticFeedback.lightImpact();
    await _audioRecorder.pause();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    HapticFeedback.lightImpact();
    await _audioRecorder.resume();
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    HapticFeedback.heavyImpact();
    _timer?.cancel();
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isProcessing = true;
      _errorMessage = null;
    });

    if (path != null) {
      await _processAudio(path);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processAudio(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      final response = await widget.geminiService.processMultimodal(
        prompt: 'Transcribe this lecture audio and provide a detailed summary with key concepts. Use Markdown formatting.',
        fileBytes: [bytes],
        mimeType: 'audio/mp4',
      );

      if (response != null) {
        final material = StudyMaterial()
          ..title = 'Lecture ${DateTime.now().toLocal().toString().substring(0, 16)}'
          ..content = response
          ..subject = 'General'
          ..createdAt = DateTime.now()
          ..type = 'transcript'
          ..filePath = path;

        await widget.databaseService.saveStudyMaterial(material);

        // Extract Flashcards
        final flashcardJson = await widget.geminiService.generateFlashcards(response);
        if (flashcardJson != null) {
          try {
            final startIndex = flashcardJson.indexOf('[');
            final endIndex = flashcardJson.lastIndexOf(']') + 1;
            if (startIndex != -1 && endIndex != -1) {
              final List<dynamic> decoded = jsonDecode(flashcardJson.substring(startIndex, endIndex));
              final flashcards = decoded.map((item) => Flashcard()
                ..question = item['question']
                ..answer = item['answer']
                ..subject = 'General'
                ..materialId = material.id
              ).toList();
              await widget.databaseService.saveFlashcards(flashcards);
            }
          } catch (e) {
            debugPrint('Error parsing flashcards: $e');
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lecture processed and flashcards generated!')),
          );
        }
      } else {
        setState(() => _errorMessage = 'AI failed to process audio. Please check your internet connection.');
      }
    } catch (e) {
      debugPrint('Error processing audio: $e');
      setState(() => _errorMessage = 'An error occurred during processing.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecture Recorder'),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Spacer(),
            if (_isProcessing)
              Column(
                children: [
                  const SizedBox(height: 20),
                  ZoomIn(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Pulse(
                        infinite: true,
                        child: Icon(Icons.auto_awesome, size: 64, color: colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInUp(
                    child: Text(
                      'AI is analyzing your lecture...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Using Gemini 2.5 Flash for high speed', style: TextStyle(color: Colors.grey[600])),
                ],
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _startRecording,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
            else ...[
              if (_isRecording)
                Column(
                  children: [
                    Text(
                      _formatDuration(_recordDuration),
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w200, letterSpacing: 2),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: WaveformPainter(_amplitudes, colorScheme.primary),
                      ),
                    ),
                  ],
                )
              else
                FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    ),
                    child: Icon(Icons.mic, size: 100, color: colorScheme.primary),
                  ),
                ),
              const SizedBox(height: 48),
              Text(
                _isRecording ? (_isPaused ? 'Recording Paused' : 'Listening...') : 'Start Recording',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'AI will automatically summarize and create flashcards from your recording.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
            const Spacer(),
            if (!_isProcessing && _errorMessage == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRecording) ...[
                    _buildActionButton(
                      onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      label: _isPaused ? 'Resume' : 'Pause',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 32),
                  ],
                  _buildMainRecordButton(),
                ],
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          iconSize: 32,
          padding: const EdgeInsets.all(16),
          style: IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.1), foregroundColor: color),
          icon: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildMainRecordButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording ? Colors.red : colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: (_isRecording ? Colors.red : colorScheme.primary).withValues(alpha: 0.3),
                  blurRadius: 25,
                  spreadRadius: 8,
                )
              ],
            ),
            child: Icon(
              _isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording ? 'Stop' : 'Start',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isRecording ? Colors.red : colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter(this.amplitudes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final spacing = width / 50;

    for (var i = 0; i < amplitudes.length; i++) {
      final x = width - (amplitudes.length - i) * spacing;
      final barHeight = amplitudes[i] * height * 0.8;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
