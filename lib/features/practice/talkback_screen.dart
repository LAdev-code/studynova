import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/gemini_service.dart';
import '../../services/database_service.dart';
import '../../models/study_material.dart';

class TalkBackScreen extends StatefulWidget {
  final GeminiService geminiService;
  final DatabaseService databaseService;

  const TalkBackScreen({
    super.key,
    required this.geminiService,
    required this.databaseService,
  });

  @override
  State<TalkBackScreen> createState() => _TalkBackScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class _TalkBackScreenState extends State<TalkBackScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _isProcessing = false;
  final List<ChatMessage> _messages = [];
  List<StudyMaterial> _materials = [];
  StudyMaterial? _selectedMaterial;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _loadMaterials();
    _messages.add(ChatMessage(
      text: "Hello! I'm your AI Lecturer. Select a topic below to start learning!",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final materials = await widget.databaseService.getAllStudyMaterials();
    setState(() => _materials = materials);
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              setState(() {
                _isListening = false;
                _messages.add(ChatMessage(text: val.recognizedWords, isUser: true));
                _isProcessing = true;
              });
              _getAIResponse(val.recognizedWords);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _getAIResponse(String text) async {
    final response = await widget.geminiService.chatWithContext(
      userMessage: text,
      contextMaterial: _selectedMaterial?.content ?? "General study session",
    );
    
    if (response != null) {
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isProcessing = false;
      });
      await _tts.speak(response);
    } else {
      setState(() => _isProcessing = false);
    }
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isProcessing = true;
    });
    _getAIResponse(text);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI TalkBack'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMaterialPicker(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildChatBubble(message),
                );
              },
            ),
          ),
          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
              child: Row(
                children: [
                  FadeIn(
                    duration: const Duration(seconds: 1),
                    child: const Text('AI Tutor is thinking...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  Pulse(
                    infinite: true,
                    child: Icon(Icons.auto_awesome, size: 18, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMaterialPicker() {
    if (_materials.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _materials.length,
        itemBuilder: (context, index) {
          final item = _materials[index];
          final isSelected = _selectedMaterial?.id == item.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item.title),
              selected: isSelected,
              onSelected: (val) {
                setState(() => _selectedMaterial = val ? item : null);
                if (val) {
                  setState(() {
                    _messages.add(ChatMessage(
                      text: "Okay! Let's focus our discussion on: **${item.title}**. What part of it should we go over first?",
                      isUser: false,
                    ));
                  });
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TextField(
                  controller: _textController,
                  onSubmitted: _isProcessing ? null : _handleSubmitted,
                  decoration: InputDecoration(
                    hintText: _isListening ? "Listening..." : "Type your question...",
                    hintStyle: TextStyle(
                      color: _isListening ? colorScheme.primary : Colors.grey[600],
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, child) {
                if (value.text.trim().isNotEmpty) {
                  return ElasticIn(
                    child: IconButton.filled(
                      onPressed: _isProcessing ? null : () => _handleSubmitted(_textController.text),
                      icon: const Icon(Icons.send),
                      padding: const EdgeInsets.all(16),
                    ),
                  );
                }
                return ElasticIn(
                  child: GestureDetector(
                    onTap: _isProcessing ? null : _listen,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening ? Colors.red : colorScheme.primary).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: message.isUser 
              ? colorScheme.primary 
              : colorScheme.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(message.isUser ? 24 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: MarkdownBody(
          data: message.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(
              color: message.isUser ? Colors.white : Colors.black87,
              fontSize: 16,
              height: 1.5,
            ),
            strong: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
