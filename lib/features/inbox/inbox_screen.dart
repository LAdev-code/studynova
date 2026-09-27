import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:animate_do/animate_do.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:csv/csv.dart';
import '../../services/gemini_service.dart';
import '../../services/database_service.dart';
import '../../services/on_device_text_service.dart';
import '../../models/study_material.dart';
import '../../models/flashcard.dart';
import '../../models/event.dart';
import '../../features/canvas/study_canvas.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class InboxScreen extends StatefulWidget {
  final GeminiService geminiService;
  final DatabaseService databaseService;

  const InboxScreen({
    super.key,
    required this.geminiService,
    required this.databaseService,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isProcessing = false;
  final OnDeviceTextService _onDeviceTextService = OnDeviceTextService();
  // String? _resultText; // Removed unused field
  List<StudyMaterial> _recentMaterials = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRecentMaterials();
  }

  Future<void> _loadRecentMaterials({String query = ''}) async {
    List<StudyMaterial> materials;
    if (query.isEmpty) {
      materials = await widget.databaseService.getAllStudyMaterials();
    } else {
      materials = await widget.databaseService.searchStudyMaterials(query);
    }
    if (mounted) {
      setState(() {
        _recentMaterials = materials.reversed.toList();
      });
    }
  }

  Future<void> _processResponse(
    String? response,
    String title,
    String type,
  ) async {
    if (response != null) {
      final material = StudyMaterial()
        ..title = title
        ..content = response
        ..subject = 'General'
        ..createdAt = DateTime.now()
        ..type = type;

      await widget.databaseService.saveStudyMaterial(material);

      // Generate Flashcards
      final flashcardJson = await widget.geminiService.generateFlashcards(
        response,
      );
      if (flashcardJson != null) {
        try {
          final startIndex = flashcardJson.indexOf('[');
          final endIndex = flashcardJson.lastIndexOf(']') + 1;

          if (startIndex != -1 && endIndex != -1) {
            final jsonPart = flashcardJson.substring(startIndex, endIndex);
            final List<dynamic> decoded = jsonDecode(jsonPart);
            final flashcards = decoded
                .map(
                  (item) => Flashcard()
                    ..question = item['question']
                    ..answer = item['answer']
                    ..subject = 'General'
                    ..materialId = material.id,
                )
                .toList();
            await widget.databaseService.saveFlashcards(flashcards);
          }
        } catch (e) {
          debugPrint('Error parsing flashcards: $e');
        }
      }

      // Extract Deadlines
      final deadlinesJson = await widget.geminiService.extractDeadlines(
        response,
      );
      if (deadlinesJson != null && mounted) {
        _handleDeadlines(deadlinesJson);
      }

      await _loadRecentMaterials();
      if (mounted) {
        // setState(() => _resultText = 'Processed: $title'); // Removed unused field
      }
    }
  }

  void _handleDeadlines(String jsonStr) {
    try {
      final startIndex = jsonStr.indexOf('[');
      final endIndex = jsonStr.lastIndexOf(']') + 1;
      if (startIndex != -1 && endIndex != -1) {
        final List<dynamic> decoded = jsonDecode(
          jsonStr.substring(startIndex, endIndex),
        );
        if (decoded.isNotEmpty) {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Deadlines Detected'),
              content: Text(
                'AI found ${decoded.length} deadlines. Add them to your calendar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    for (var item in decoded) {
                      final event = Event()
                        ..title = item['title']
                        ..description = 'Auto-extracted from study material'
                        ..dateTime = DateTime.parse(item['dueDate'])
                        ..isCompleted = false;
                      await widget.databaseService.saveEvent(event);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Add All'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error parsing deadlines: $e');
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'docx', 'doc', 'csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _isProcessing = true);

      final file = result.files.first;
      String? response;

      if (file.extension == 'pdf' ||
          file.extension == 'ppt' ||
          file.extension == 'pptx') {
        response = await widget.geminiService.processMultimodal(
          prompt:
              'Summarize this study material extensively. Use Markdown formatting.',
          fileBytes: [file.bytes!],
          mimeType: file.extension == 'pdf'
              ? 'application/pdf'
              : 'application/vnd.ms-powerpoint',
        );
      } else if (file.extension == 'docx' || file.extension == 'doc') {
        final text = docxToText(file.bytes!);
        response = await widget.geminiService.processText(
          'Summarize this study material extensively. Use Markdown formatting.\n\nContent: $text',
        );
      } else if (file.extension == 'csv') {
        final csvString = utf8.decode(file.bytes!);
        final List<List<dynamic>> rows = const CsvToListConverter().convert(
          csvString,
        );
        final text = rows.map((row) => row.join(', ')).join('\n');
        response = await widget.geminiService.processText(
          'Analyze and summarize the data in this CSV study material. Use Markdown formatting.\n\nData: $text',
        );
      }

      if (mounted) {
        await _processResponse(response, file.name, 'summary');
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isProcessing = true);

      final bytes = await image.readAsBytes();
      final extractedText = await _onDeviceTextService.extractTextFromFile(
        image.path,
      );
      final response = extractedText != null
          ? await widget.geminiService.processText(
              'Extract text and concepts from this screenshot. Use Markdown formatting.\n\nText extracted on device:\n$extractedText',
            )
          : await widget.geminiService.processMultimodal(
              prompt:
                  'Extract text and concepts from this screenshot. Use Markdown formatting.',
              fileBytes: [bytes],
              mimeType: 'image/jpeg',
            );

      if (mounted) {
        await _processResponse(
          response,
          'Screenshot ${DateTime.now().toLocal().toString().substring(0, 16)}',
          'transcript',
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context)!.smartInbox), elevation: 0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInLeft(
                  child: Text(
                    S.of(context)!.uploadMaterials,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes, summaries...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) => _loadRecentMaterials(query: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildUploadCard(
                  title: 'Upload PDF',
                  subtitle: 'Slides & Docs',
                  icon: Icons.picture_as_pdf,
                  onTap: _isProcessing ? null : _pickFiles,
                  gradient: [Colors.red.shade400, Colors.orange.shade400],
                ),
                const SizedBox(width: 16),
                _buildUploadCard(
                  title: 'Screenshot',
                  subtitle: 'Extract Text',
                  icon: Icons.add_a_photo,
                  onTap: _isProcessing ? null : _pickImage,
                  gradient: [Colors.blue.shade400, Colors.indigo.shade400],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Materials',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_recentMaterials.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.sort, size: 18),
                    label: const Text('Filter'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isProcessing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Pulse(
                          infinite: true,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'AI is processing your file...',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : _recentMaterials.isEmpty
                ? Center(
                    child: FadeIn(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No materials yet',
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Upload a PDF or Image to start',
                            style: TextStyle(
                              color: colorScheme.outline.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadRecentMaterials,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: _recentMaterials.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _recentMaterials[index];
                        return FadeInUp(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          child: _buildMaterialListItem(item, index),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialListItem(StudyMaterial item, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: Key(item.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) async {
        final deletedItem = item;
        setState(() {
          _recentMaterials.removeAt(index);
        });
        await widget.databaseService.deleteStudyMaterial(deletedItem.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${deletedItem.title}" deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await widget.databaseService.saveStudyMaterial(deletedItem);
                  _loadRecentMaterials();
                },
              ),
            ),
          );
        }
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              item.type == 'summary'
                  ? Icons.description_outlined
                  : Icons.image_outlined,
              color: colorScheme.primary,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${item.createdAt.day}/${item.createdAt.month} • ${item.type.toUpperCase()}',
              style: TextStyle(color: colorScheme.outline, fontSize: 12),
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: colorScheme.outlineVariant,
          ),
          onTap: () => _showDetailBottomSheet(item),
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required List<Color> gradient,
  }) {
    return FadeInRight(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailBottomSheet(StudyMaterial item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: item.content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 16, height: 1.6),
                    h1: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                    h2: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  StudyCanvas.materialFilter.value = item.id;
                  MainNavigation.selectedIndexNotifier.value = 3; // Canvas tab
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.quiz),
                label: const Text('Practice Flashcards'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
