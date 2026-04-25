import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/riverpod_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    
    final tasksForDay = tasks.where((t) {
      if (_selectedDay == null) return false;
      return t.date == _selectedDay!.toIso8601String().substring(0, 10);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            ),
          ),
          const Divider(),
          Expanded(
            child: tasksForDay.isEmpty
                ? const Center(child: Text('Sem tarefas para esta data.'))
                : ListView.builder(
                    itemCount: tasksForDay.length,
                    itemBuilder: (ctx, i) {
                      final t = tasksForDay[i];
                      return ListTile(
                        leading: Icon(
                          t.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined,
                          color: t.status == 'concluida' ? Colors.green : Colors.grey,
                        ),
                        title: Text(t.title),
                        subtitle: Text(t.status),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
