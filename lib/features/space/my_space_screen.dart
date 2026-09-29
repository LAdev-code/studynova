import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:animate_do/animate_do.dart';
import '../../l10n/app_localizations.dart';
import '../../services/database_service.dart';
import '../settings/settings_screen.dart';
import '../../services/paywall_manager.dart';
import '../../ui/paywall_screen.dart';
import '../../models/event.dart';

class MySpaceScreen extends StatefulWidget {
  final DatabaseService databaseService;

  const MySpaceScreen({super.key, required this.databaseService});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents(_selectedDay!);
  }

  Future<void> _loadEvents(DateTime day) async {
    final events = await widget.databaseService.getEventsForDate(day);
    if (mounted) {
      setState(() => _selectedEvents = events);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final l10n = S.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mySpace),
        elevation: 0,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: PaywallManager.isProNotifier,
            builder: (context, isPro, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: ActionChip(
                  avatar: Icon(
                    isPro ? Icons.verified : Icons.auto_awesome,
                    size: 16,
                    color: isPro ? Colors.green : Colors.amber,
                  ),
                  label: Text(
                    isPro ? 'PRO' : 'UPGRADE',
                    style: TextStyle(
                      color: isPro ? Colors.green : Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isPro
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: isPro
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.amber.withValues(alpha: 0.2),
                  ),
                  onPressed: () {
                    if (isPro) {
                      PaywallScreen.showCustomerCenter();
                    } else {
                      PaywallScreen.show(context);
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PaywallManager.isProNotifier,
            builder: (context, isPro, child) {
              if (!isPro) return const SizedBox.shrink();
              return FadeInDown(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary, colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Premium Plan Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => PaywallScreen.showCustomerCenter(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Manage'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FadeInDown(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.twoWeeks,
                    availableCalendarFormats: const {
                      CalendarFormat.twoWeeks: '2 Weeks',
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _loadEvents(selectedDay);
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Study Schedule',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_selectedEvents.isNotEmpty)
                  Text(
                    '${_selectedEvents.where((e) => e.isCompleted).length}/${_selectedEvents.length} Done',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedEvents.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Center(
                            child: FadeIn(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.event_available_outlined,
                                    size: 56,
                                    color: colorScheme.outlineVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No study tasks for today',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.outline,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = _selectedEvents[index];
                      return FadeInRight(
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        child: _buildTaskItem(event, index),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(),
        label: const Text('Add Study Task'),
        icon: const Icon(Icons.add_task),
        elevation: 2,
      ),
    );
  }

  Widget _buildTaskItem(Event event, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: Key(event.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (direction) async {
        final deletedEvent = event;
        setState(() {
          _selectedEvents.removeAt(index);
        });
        await widget.databaseService.deleteEvent(deletedEvent.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task "${deletedEvent.title}" deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await widget.databaseService.saveEvent(deletedEvent);
                  if (mounted) {
                    _loadEvents(_selectedDay ?? DateTime.now());
                  }
                },
              ),
            ),
          );
        }
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          leading: GestureDetector(
            onTap: () async {
              setState(() {
                event.isCompleted = !event.isCompleted;
              });
              await widget.databaseService.updateEvent(event);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: event.isCompleted ? Colors.green : colorScheme.outline,
                  width: 2,
                ),
                color: event.isCompleted
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.transparent,
              ),
              child: Icon(
                Icons.check,
                size: 16,
                color: event.isCompleted ? Colors.green : Colors.transparent,
              ),
            ),
          ),
          title: Text(
            event.title,
            style: TextStyle(
              decoration: event.isCompleted ? TextDecoration.lineThrough : null,
              color: event.isCompleted
                  ? colorScheme.outline
                  : colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: event.relatedSubject != null || event.description.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (event.relatedSubject != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.relatedSubject!,
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (event.relatedSubject != null &&
                          event.description.isNotEmpty)
                        const SizedBox(width: 8),
                      if (event.description.isNotEmpty)
                        Expanded(
                          child: Text(
                            event.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.outline,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _showAddEventDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedSubject = 'General';
    List<String> subjects = await widget.databaseService.getAllSubjects();

    if (subjects.isNotEmpty && !subjects.contains('General')) {
      selectedSubject = subjects.first;
    }

    if (!mounted) return;

    return showDialog(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) {
        final keyboardInset = MediaQuery.of(dialogContext).viewInsets.bottom;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Add Study Task'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: keyboardInset > 0 ? keyboardInset : 0),
                child: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Task Title',
                          hintText: 'e.g., Read Physics Chapter 3',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Details (Optional)',
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: subjects.contains(selectedSubject)
                            ? selectedSubject
                            : (subjects.isNotEmpty ? subjects.first : 'General'),
                        decoration: const InputDecoration(labelText: 'Subject'),
                        items: [
                          ...subjects
                              .map((s) => DropdownMenuItem(value: s, child: Text(s))),
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
                        onChanged: (val) async {
                          if (val == null) return;
                          if (val == '__add_new_subject__') {
                            final subjectController = TextEditingController();
                            final newSubject = await showDialog<String>(
                              context: dialogContext,
                              builder: (context) => AlertDialog(
                                title: const Text('Add Subject'),
                                content: TextField(
                                  controller: subjectController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Subject name',
                                    hintText: 'e.g. Biology',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      final value = subjectController.text.trim();
                                      if (value.isNotEmpty) {
                                        Navigator.pop(context, value);
                                      }
                                    },
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );

                            if (newSubject == null || newSubject.trim().isEmpty) {
                              return;
                            }

                            final normalized = newSubject.trim().replaceAll(RegExp(r'\s+'), ' ');
                            if (!subjects.any((subject) =>
                                subject.toLowerCase() == normalized.toLowerCase())) {
                              await widget.databaseService.saveSubject(normalized);
                              subjects = [...subjects, normalized]..sort();
                            }
                            setDialogState(() => selectedSubject = normalized);
                            return;
                          }

                          setDialogState(() => selectedSubject = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    final event = Event()
                      ..title = titleController.text
                      ..description = descController.text
                      ..dateTime = _selectedDay ?? DateTime.now()
                      ..isCompleted = false
                      ..relatedSubject = selectedSubject;

                    await widget.databaseService.saveEvent(event);
                    if (mounted && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      _loadEvents(_selectedDay ?? DateTime.now());
                    }
                  }
                },
                child: const Text('Add Task'),
              ),
            ],
          ),
        );
      },
    );
  }
}
