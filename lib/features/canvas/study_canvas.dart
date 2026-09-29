import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/database_service.dart';
import '../../models/flashcard.dart';

class StudyCanvas extends StatefulWidget {
  final DatabaseService databaseService;
  static final ValueNotifier<int?> materialFilter = ValueNotifier<int?>(null);

  const StudyCanvas({super.key, required this.databaseService});

  @override
  State<StudyCanvas> createState() => _StudyCanvasState();
}

class _StudyCanvasState extends State<StudyCanvas> {
  List<Flashcard> _flashcards = [];
  int _currentIndex = 0;
  String _selectedSubject = 'All';
  List<String> _subjects = ['All'];
  bool _isReviewMode = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    StudyCanvas.materialFilter.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    StudyCanvas.materialFilter.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    if (StudyCanvas.materialFilter.value != null) {
      _loadFlashcards();
    }
  }

  Future<void> _loadInitialData() async {
    await _loadSubjects();
    await _loadFlashcards();
  }

  Future<void> _loadSubjects() async {
    final subjects = await widget.databaseService.getAllSubjects();
    setState(() {
      _subjects = ['All', ...subjects];
      if (!_subjects.contains(_selectedSubject) && _selectedSubject != 'All') {
        _selectedSubject = 'All';
      }
    });
  }

  Future<String?> _showAddSubjectDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Subject name',
            hintText: 'e.g. Biology',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return null;
    final normalized = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    return normalized;
  }

  Future<void> _loadFlashcards() async {
    List<Flashcard> cards;
    final mFilter = StudyCanvas.materialFilter.value;
    
    if (mFilter != null) {
      cards = await widget.databaseService.getFlashcardsByMaterial(mFilter);
    } else if (_isReviewMode) {
      cards = await widget.databaseService.getDueFlashcards();
    } else {
      cards = await widget.databaseService.getFlashcardsBySubject(_selectedSubject);
    }

    setState(() {
      _flashcards = cards;
      if (_currentIndex >= _flashcards.length && _flashcards.isNotEmpty) {
        _currentIndex = _flashcards.length - 1;
      } else if (_flashcards.isEmpty) {
        _currentIndex = 0;
      }
    });
  }

  Future<void> _updateMastery(int quality) async {
    if (_flashcards.isEmpty) return;
    final card = _flashcards[_currentIndex];
    
    // Simplified SM-2 Algorithm
    // quality: 0 (forgot) to 5 (perfect)
    // We map our buttons: "Still Learning" (1) and "Mastered" (5)
    
    if (quality >= 3) {
      if (card.interval == 0) {
        card.interval = 1;
      } else if (card.interval == 1) {
        card.interval = 6;
      } else {
        card.interval = (card.interval * card.easeFactor).round();
      }
      card.easeFactor += (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    } else {
      card.interval = 1;
      card.easeFactor -= 0.2;
    }

    if (card.easeFactor < 1.3) card.easeFactor = 1.3;
    card.nextReviewDate = DateTime.now().add(Duration(days: card.interval));
    card.masteryLevel = quality / 5.0;
    card.lastReviewed = DateTime.now();
    
    await widget.databaseService.updateFlashcard(card);
    
    if (_currentIndex < _flashcards.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _loadFlashcards(); // Refresh list (due cards might disappear)
    }
  }

  Future<void> _deleteCurrentCard() async {
    if (_flashcards.isEmpty) return;
    final card = _flashcards[_currentIndex];
    await widget.databaseService.deleteFlashcard(card.id);
    await _loadInitialData();
  }

  Map<String, int> _getMasteryStats() {
    int high = 0;   // > 0.7
    int medium = 0; // 0.3 - 0.7
    int low = 0;    // < 0.3

    for (var card in _flashcards) {
      if (card.masteryLevel > 0.7) {
        high++;
      } else if (card.masteryLevel > 0.3) {
        medium++;
      } else {
        low++;
      }
    }
    return {'High': high, 'Medium': medium, 'Low': low};
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getMasteryStats();
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Canvas'),
        elevation: 0,
        actions: [
          if (StudyCanvas.materialFilter.value != null)
            IconButton(
              onPressed: () {
                StudyCanvas.materialFilter.value = null;
                _loadFlashcards();
              },
              tooltip: 'Clear Filter',
              icon: const Icon(Icons.filter_list_off),
            ),
          if (_flashcards.isNotEmpty)
            IconButton(
              onPressed: () => _showDeleteConfirmation(),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            if (_flashcards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Session Progress',
                          style: TextStyle(color: colorScheme.outline, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          '${_currentIndex + 1} / ${_flashcards.length}',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _flashcards.length,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Review Due'),
                    selected: _isReviewMode,
                    onSelected: StudyCanvas.materialFilter.value != null 
                      ? null 
                      : (val) {
                        setState(() {
                          _isReviewMode = val;
                          _currentIndex = 0;
                        });
                        _loadFlashcards();
                      },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _subjects.contains(_selectedSubject) ? _selectedSubject : 'All',
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      items: [
                        ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        const DropdownMenuItem(
                          value: '__add_new_subject__',
                          child: Row(
                            children: [
                              Icon(Icons.add_circle_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Add new subject'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _isReviewMode || StudyCanvas.materialFilter.value != null
                        ? null 
                        : (val) async {
                            if (val == null) return;
                            if (val == '__add_new_subject__') {
                              final newSubject = await _showAddSubjectDialog();
                              if (newSubject == null) return;
                              final normalized = newSubject.trim();
                              final exists = _subjects.any((subject) => subject.toLowerCase() == normalized.toLowerCase());
                              if (!exists) {
                                await widget.databaseService.saveSubject(normalized);
                                await _loadSubjects();
                              }
                              setState(() {
                                _selectedSubject = normalized;
                                _currentIndex = 0;
                              });
                              await _loadFlashcards();
                              return;
                            }
                            setState(() {
                              _selectedSubject = val;
                              _currentIndex = 0;
                            });
                            await _loadFlashcards();
                          },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 0,
                  color: colorScheme.primaryContainer.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.analytics_outlined, size: 20, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Mastery Overview',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 160,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                show: true,
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 10);
                                      switch (value.toInt()) {
                                        case 0: return const Text('HIGH', style: style);
                                        case 1: return const Text('MED', style: style);
                                        case 2: return const Text('LOW', style: style);
                                        default: return const Text('');
                                      }
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: stats['High']!.toDouble(), color: Colors.green.shade400, width: 22, borderRadius: BorderRadius.circular(4))]),
                                BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: stats['Medium']!.toDouble(), color: Colors.orange.shade400, width: 22, borderRadius: BorderRadius.circular(4))]),
                                BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: stats['Low']!.toDouble(), color: Colors.red.shade400, width: 22, borderRadius: BorderRadius.circular(4))]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_flashcards.isEmpty)
              Center(
                child: FadeIn(
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.style_outlined, size: 100, color: colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        _isReviewMode ? 'All caught up!' : 'No cards found',
                        style: TextStyle(color: colorScheme.outline, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isReviewMode ? 'You have no cards due for review.' : 'Add study materials to generate flashcards.',
                        style: TextStyle(color: colorScheme.outline.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  FadeInUp(
                    key: ValueKey(_flashcards[_currentIndex].id),
                    duration: const Duration(milliseconds: 400),
                    child: SizedBox(
                      height: 380,
                      width: MediaQuery.of(context).size.width * 0.88,
                      child: FlipCard(
                        front: _buildCard(_flashcards[_currentIndex].question, colorScheme.primaryContainer, true),
                        back: _buildCard(_flashcards[_currentIndex].answer, colorScheme.secondaryContainer, false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMasteryButton(
                            onPressed: () => _updateMastery(1),
                            icon: Icons.refresh,
                            label: 'Again',
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildMasteryButton(
                            onPressed: () => _updateMastery(5),
                            icon: Icons.check_circle_outline,
                            label: 'Good',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryButton({required VoidCallback onPressed, required IconData icon, required String label, required Color color}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Widget _buildCard(String text, Color color, bool isFront) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              isFront ? 'QUESTION' : 'ANSWER',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: isFront ? Colors.deepPurple : Colors.indigo,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: SingleChildScrollView(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 20,
            right: 20,
            child: Icon(Icons.touch_app_outlined, size: 20, color: Colors.black26),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flashcard'),
        content: const Text('Are you sure you want to delete this card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteCurrentCard();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
