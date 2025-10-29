import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class MedicoPanelScreen extends StatefulWidget {
  const MedicoPanelScreen({super.key});

  @override
  State<MedicoPanelScreen> createState() => _MedicoPanelScreenState();
}

class _MedicoPanelScreenState extends State<MedicoPanelScreen> {
  final TextEditingController _doctorController = TextEditingController();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _loading = false;

  // Mapa de eventos por fecha (yyyy-MM-dd) -> lista de citas
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  @override
  void dispose() {
    _doctorController.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    final doctor = _doctorController.text.trim();
    setState(() => _loading = true);
    try {
      final year = _focusedDay.year;
      final month = _focusedDay.month;
      final citas = await SupabaseService.instance.getCitasConPacientePorMes(
        doctor: doctor.isEmpty ? null : doctor,
        year: year,
        month: month,
      );

      _eventsByDate.clear();
      for (final c in citas) {
        final fechaVal = c['fecha'];
        String fechaStr;
        if (fechaVal is String) {
          fechaStr = fechaVal;
        } else if (fechaVal is DateTime) {
          fechaStr = DateFormat('yyyy-MM-dd').format(fechaVal);
        } else {
          // Intentar convertir a string directamente
          fechaStr = fechaVal?.toString() ?? '';
          // Si viene con tiempo, quedarnos solo con la parte de la fecha
          if (fechaStr.contains('T')) {
            fechaStr = fechaStr.split('T').first;
          }
        }
        if (fechaStr.isEmpty) continue;
        _eventsByDate.putIfAbsent(fechaStr, () => []).add(c);
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _eventsByDate[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Médico'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _doctorController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del médico',
                      prefixIcon: Icon(Icons.medical_services),
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    onSubmitted: (_) => _loadMonth(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _loadMonth,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      calendarFormat: _calendarFormat,
                      eventLoader: _getEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        _loadMonth();
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildDayList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayList() {
    final day = _selectedDay ?? _focusedDay;
    final events = _getEventsForDay(day);
    if (events.isEmpty) {
      return const Center(child: Text('No hay citas para este día.'));
    }
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = events[index];
        final paciente = c['usuarios'];
        final pacienteNombre = paciente is Map
            ? '${(paciente['nombres'] ?? '').toString()} ${(paciente['apellidos'] ?? '').toString()}'
                  .trim()
            : '';
        return ListTile(
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.event_available, color: Colors.blue),
          title: Text('${c['tipo_cita'] ?? 'Cita'} - ${c['hora'] ?? ''}'),
          subtitle: Text(
            pacienteNombre.isEmpty
                ? 'Paciente ID: ${c['usuario_id']}'
                : pacienteNombre,
          ),
        );
      },
    );
  }
}
