import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:get/get.dart';
import '../services/supabase_service.dart';
import '../services/gemini_service.dart';
import '../controllers/theme_controller.dart';

class MedicoPanelScreen extends StatefulWidget {
  const MedicoPanelScreen({super.key});

  @override
  State<MedicoPanelScreen> createState() => _MedicoPanelScreenState();
}

class _MedicoPanelScreenState extends State<MedicoPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _doctorController = TextEditingController();

  // Calendario
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};
  int _totalCitas = 0;
  int _citasHoy = 0;
  int _citasSemana = 0;

  // Todas las citas
  List<Map<String, dynamic>> _todasLasCitas = [];
  bool _loadingTodasCitas = false;

  // Chatbot
  List<Map<String, dynamic>> _pacientes = [];
  Map<String, dynamic>? _pacienteSeleccionado;
  ChatSession? _chatSession;
  final List<Map<String, String>> _mensajes = [];
  final TextEditingController _mensajeController = TextEditingController();
  bool _chatLoading = false;
  bool _historiaCargada = false;
  bool _loadingPacientes = false;

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _selectedDay = DateTime.now();
    _loadMonth();
    _loadTodasLasCitas();
    _loadPacientes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _doctorController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  // ========== CALENDARIO ==========
  Future<void> _loadMonth() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final year = _focusedDay.year;
      final month = _focusedDay.month;

      final doctor = _doctorController.text.trim();
      final citas = await SupabaseService.instance.getCitasConPacientePorMes(
        doctor: doctor.isEmpty ? null : doctor,
        year: year,
        month: month,
      );

      _eventsByDate.clear();
      _totalCitas = citas.length;
      _citasHoy = 0;
      _citasSemana = 0;

      final hoy = DateTime.now();
      final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
      final finSemana = inicioSemana.add(const Duration(days: 6));

      for (final c in citas) {
        final fechaVal = c['fecha'];
        String fechaStr;
        DateTime? fechaDateTime;

        if (fechaVal is String) {
          fechaStr = fechaVal;
          try {
            fechaDateTime = DateTime.parse(fechaStr);
          } catch (_) {}
        } else if (fechaVal is DateTime) {
          fechaDateTime = fechaVal;
          fechaStr = DateFormat('yyyy-MM-dd').format(fechaDateTime);
        } else {
          fechaStr = fechaVal?.toString() ?? '';
          if (fechaStr.contains('T')) {
            fechaStr = fechaStr.split('T').first;
          }
          try {
            fechaDateTime = DateTime.parse(fechaStr);
          } catch (_) {}
        }

        if (fechaStr.isEmpty) continue;
        _eventsByDate.putIfAbsent(fechaStr, () => []).add(c);

        if (fechaDateTime != null) {
          final fechaSolo = DateTime(
            fechaDateTime.year,
            fechaDateTime.month,
            fechaDateTime.day,
          );
          final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);

          if (fechaSolo == hoySolo) {
            _citasHoy++;
          }

          if (fechaSolo.isAfter(
                inicioSemana.subtract(const Duration(days: 1)),
              ) &&
              fechaSolo.isBefore(finSemana.add(const Duration(days: 1)))) {
            _citasSemana++;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar citas: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _eventsByDate[key] ?? [];
  }

  int _getEventCountForDay(DateTime day) {
    return _getEventsForDay(day).length;
  }

  // ========== TODAS LAS CITAS ==========
  Future<void> _loadTodasLasCitas() async {
    setState(() {
      _loadingTodasCitas = true;
    });

    try {
      final doctor = _doctorController.text.trim();
      final citas = await SupabaseService.instance.getTodasLasCitas(
        doctor: doctor.isEmpty ? null : doctor,
      );

      setState(() {
        _todasLasCitas = citas;
      });
    } catch (e) {
      print('Error al cargar todas las citas: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingTodasCitas = false;
        });
      }
    }
  }

  // ========== CHATBOT ==========
  Future<void> _loadPacientes() async {
    setState(() {
      _loadingPacientes = true;
    });

    try {
      final pacientes = await SupabaseService.instance.getPacientesConCitas();
      setState(() {
        _pacientes = pacientes;
      });
    } catch (e) {
      print('Error al cargar pacientes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingPacientes = false;
        });
      }
    }
  }

  Future<void> _cargarHistoriaClinicaPaciente(String usuarioId) async {
    setState(() {
      _chatLoading = true;
      _historiaCargada = false;
      _mensajes.clear();
      _chatSession = null;
    });

    try {
      // Obtener todas las historias clínicas del paciente
      final historias = await SupabaseService.instance
          .getHistoriasClinicasPaciente(usuarioId);

      if (historias.isEmpty) {
        setState(() {
          _mensajes.add({
            'tipo': 'error',
            'mensaje':
                'No se encontraron historias clínicas para este paciente.',
          });
        });
        return;
      }

      // Combinar todas las historias clínicas
      String textoCompleto = '';
      for (final historia in historias) {
        final pdfUrl = historia['pdf_url'] as String?;
        if (pdfUrl != null && pdfUrl.isNotEmpty) {
          try {
            final textoHistoria = await GeminiService.instance
                .extraerTextoDePDF(pdfUrl);
            textoCompleto +=
                '\n\n=== Historia Clínica del ${DateFormat('dd/MM/yyyy').format(DateTime.parse(historia['fecha_subida']))} ===\n\n';
            textoCompleto += textoHistoria;
          } catch (e) {
            print('Error al extraer texto de PDF: $e');
          }
        }
      }

      if (textoCompleto.isEmpty) {
        setState(() {
          _mensajes.add({
            'tipo': 'error',
            'mensaje':
                'No se pudo extraer información de las historias clínicas.',
          });
        });
        return;
      }

      // Crear chatbot con todas las historias clínicas
      final chat = await GeminiService.instance.crearChatbotConHistoriaClinica(
        textoCompleto,
      );

      setState(() {
        _chatSession = chat;
        _historiaCargada = true;
        _mensajes.add({
          'tipo': 'sistema',
          'mensaje':
              'Historia clínica cargada. Puedes hacer preguntas sobre el paciente.',
        });
      });
    } catch (e) {
      setState(() {
        _mensajes.add({
          'tipo': 'error',
          'mensaje': 'Error al cargar la historia clínica: ${e.toString()}',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _chatLoading = false;
        });
      }
    }
  }

  Future<void> _enviarMensaje() async {
    final mensaje = _mensajeController.text.trim();
    if (mensaje.isEmpty || _chatSession == null) return;

    setState(() {
      _mensajes.add({'tipo': 'usuario', 'mensaje': mensaje});
      _mensajeController.clear();
      _chatLoading = true;
    });

    try {
      final respuesta = await GeminiService.instance.enviarMensaje(
        _chatSession!,
        mensaje,
      );

      setState(() {
        _mensajes.add({'tipo': 'asistente', 'mensaje': respuesta});
      });
    } catch (e) {
      setState(() {
        _mensajes.add({
          'tipo': 'error',
          'mensaje': 'Error al procesar la pregunta: ${e.toString()}',
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          _chatLoading = false;
        });
      }
    }
  }

  Future<void> _cerrarSesion() async {
    try {
      await SupabaseService.instance.cerrarSesion();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del Médico'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_month), text: 'Calendario'),
              Tab(icon: Icon(Icons.list), text: 'Todas las Citas'),
              Tab(icon: Icon(Icons.chat), text: 'Chatbot IA'),
            ],
          ),
        ),
        actions: [
          GetBuilder<ThemeController>(
            builder: (controller) => IconButton(
              icon: Icon(
                controller.isDarkMode.value
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () => controller.toggleTheme(),
              tooltip: controller.isDarkMode.value
                  ? 'Modo claro'
                  : 'Modo oscuro',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadMonth();
              } else if (_tabController.index == 1) {
                _loadTodasLasCitas();
              } else if (_tabController.index == 2) {
                _loadPacientes();
              }
            },
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _errorMessage != null && _tabController.index == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMonth,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarioTab(),
                _buildTodasLasCitasTab(),
                _buildChatbotTab(),
              ],
            ),
    );
  }

  // ========== TAB CALENDARIO ==========
  Widget _buildCalendarioTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sectionBackground = isDark
        ? const Color(0xFF2A2A2A)
        : Colors.blue[50];
    final fieldFillColor = isDark ? const Color(0xFF2F2F2F) : Colors.white;
    final cardBackground = theme.cardColor;
    final subtleShadow = BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
      blurRadius: 8,
      offset: const Offset(0, 3),
    );
    final headerBackground = isDark ? const Color(0xFF353535) : Colors.blue[50];
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        // Estadísticas
        Container(
          padding: const EdgeInsets.all(16),
          color: sectionBackground,
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total del Mes',
                  '$_totalCitas',
                  Icons.calendar_month,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Hoy',
                  '$_citasHoy',
                  Icons.today,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Esta Semana',
                  '$_citasSemana',
                  Icons.date_range,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),

        // Filtro de doctor
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Flexible(
                flex: 3,
                child: TextField(
                  controller: _doctorController,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por médico',
                    hintText: 'Dejar vacío para ver todas',
                    prefixIcon: const Icon(Icons.medical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: fieldFillColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: _doctorController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _doctorController.clear();
                              _loadMonth();
                              _loadTodasLasCitas();
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    _loadMonth();
                    _loadTodasLasCitas();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _loadMonth();
                          _loadTodasLasCitas();
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.search, size: 20),
                  label: const Text('Buscar', style: TextStyle(fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Calendario y lista - Layout vertical
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                // Calendario arriba
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [subtleShadow],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2035, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        calendarFormat: CalendarFormat.month,
                        eventLoader: _getEventsForDay,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          weekendTextStyle: TextStyle(
                            color: isDark ? Colors.red[200] : Colors.red[700],
                          ),
                          selectedDecoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          selectedTextStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          todayDecoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          todayTextStyle: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          markerDecoration: BoxDecoration(
                            color: Colors.green[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          formatButtonShowsNext: false,
                          leftChevronIcon: Icon(
                            Icons.chevron_left,
                            color: primaryColor,
                          ),
                          rightChevronIcon: Icon(
                            Icons.chevron_right,
                            color: primaryColor,
                          ),
                          titleTextStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.blue[800],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              return Positioned(
                                bottom: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    events.length > 3 ? 3 : events.length,
                                    (index) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[600],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Lista de citas abajo
                Container(
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [subtleShadow],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: headerBackground,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedDay != null
                                    ? 'Citas del ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
                                    : 'Seleccione un día en el calendario',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.blue[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectedDay != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_getEventCountForDay(_selectedDay!)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 300,
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : _buildDayList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========== TAB TODAS LAS CITAS ==========
  Widget _buildTodasLasCitasTab() {
    return Column(
      children: [
        // Filtro
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _doctorController,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por médico',
                    hintText: 'Dejar vacío para ver todas las citas',
                    prefixIcon: const Icon(Icons.medical_services),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2F2F2F)
                        : Colors.white,
                  ),
                  onSubmitted: (_) => _loadTodasLasCitas(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loadingTodasCitas ? null : _loadTodasLasCitas,
                icon: _loadingTodasCitas
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.search),
                label: const Text('Buscar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Lista de citas
        Expanded(
          child: _loadingTodasCitas
              ? const Center(child: CircularProgressIndicator())
              : _todasLasCitas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay citas disponibles',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _todasLasCitas.length,
                  itemBuilder: (context, index) {
                    final c = _todasLasCitas[index];
                    final paciente = c['usuarios'];
                    final pacienteNombre = paciente is Map
                        ? '${(paciente['nombres'] ?? '').toString()} ${(paciente['apellidos'] ?? '').toString()}'
                              .trim()
                        : '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          context.push('/detalle-cita-medico/${c['id']}');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.blue[600],
                                      size: 20,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatearFechaCorta(c['fecha']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['tipo_cita'] ?? 'Cita médica',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (pacienteNombre.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              pacienteNombre,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${c['fecha']} ${c['hora'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (c['doctor'] != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.medical_services,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            c['doctor'],
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ========== TAB CHATBOT ==========
  Widget _buildChatbotTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectorBackground = isDark
        ? const Color(0xFF2A2A2A)
        : Colors.blue[50];
    final dropdownFill = isDark ? const Color(0xFF2F2F2F) : Colors.white;
    final dropdownTextColor = isDark ? Colors.white : Colors.black87;
    final dropdownBorderColor = isDark
        ? const Color(0xFF444444)
        : Colors.grey[300]!;
    final infoBackground = isDark ? const Color(0xFF303030) : Colors.blue[100];
    final infoPrimaryText = isDark ? Colors.white : Colors.blue[800];
    final infoSecondaryText = isDark ? Colors.white70 : Colors.blue[700];
    final systemMessageBg = isDark ? const Color(0xFF1F2C34) : Colors.blue[50];
    final messageBg = isDark ? const Color(0xFF3A3A3A) : Colors.grey[200];
    final chatInputBg = isDark ? const Color(0xFF252525) : Colors.grey[100];
    final chatInputFieldBg = isDark ? const Color(0xFF303030) : Colors.white;

    return Column(
      children: [
        // Selector de paciente
        Container(
          padding: const EdgeInsets.all(16),
          color: selectorBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar Paciente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dropdownTextColor,
                ),
              ),
              const SizedBox(height: 12),
              _loadingPacientes
                  ? const Center(child: CircularProgressIndicator())
                  : _pacientes.isEmpty
                  ? Text(
                      'No hay pacientes disponibles',
                      style: TextStyle(color: dropdownTextColor),
                    )
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      value: _pacienteSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Paciente',
                        labelStyle: TextStyle(color: dropdownTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: dropdownBorderColor),
                        ),
                        filled: true,
                        fillColor: dropdownFill,
                      ),
                      dropdownColor: dropdownFill,
                      style: TextStyle(color: dropdownTextColor),
                      items: _pacientes.map((paciente) {
                        final nombre =
                            '${paciente['nombres'] ?? ''} ${paciente['apellidos'] ?? ''}';
                        final cedula = paciente['cedula'] ?? '';
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: paciente,
                          child: Text(
                            '$nombre - Cédula: $cedula',
                            style: TextStyle(color: dropdownTextColor),
                          ),
                        );
                      }).toList(),
                      onChanged: (paciente) {
                        setState(() {
                          _pacienteSeleccionado = paciente;
                          _historiaCargada = false;
                          _mensajes.clear();
                          _chatSession = null;
                        });
                        if (paciente != null) {
                          _cargarHistoriaClinicaPaciente(paciente['id']);
                        }
                      },
                    ),
            ],
          ),
        ),

        // Chat
        Expanded(
          child: _pacienteSeleccionado == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Selecciona un paciente para consultar su historia clínica',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Información del paciente
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: infoBackground,
                      child: Row(
                        children: [
                          Icon(Icons.person, color: infoPrimaryText),
                          const SizedBox(width: 8),
                          Text(
                            '${_pacienteSeleccionado!['nombres'] ?? ''} ${_pacienteSeleccionado!['apellidos'] ?? ''}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: infoPrimaryText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cédula: ${_pacienteSeleccionado!['cedula'] ?? ''}',
                            style: TextStyle(color: infoSecondaryText),
                          ),
                        ],
                      ),
                    ),

                    // Mensajes
                    Expanded(
                      child: _mensajes.isEmpty
                          ? Center(
                              child: _chatLoading
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 64,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _historiaCargada
                                              ? 'Haz una pregunta sobre el paciente'
                                              : 'Cargando historia clínica...',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _mensajes.length,
                              itemBuilder: (context, index) {
                                final mensaje = _mensajes[index];
                                final isUsuario = mensaje['tipo'] == 'usuario';
                                final isError = mensaje['tipo'] == 'error';
                                final isSistema = mensaje['tipo'] == 'sistema';

                                if (isSistema) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: systemMessageBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            mensaje['mensaje'] ?? '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: dropdownTextColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Align(
                                  alignment: isUsuario
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isError
                                          ? (isDark
                                                ? const Color(0xFF4E1F1F)
                                                : Colors.red[50])
                                          : isUsuario
                                          ? Colors.blue[600]
                                          : messageBg,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    child: Text(
                                      mensaje['mensaje'] ?? '',
                                      style: TextStyle(
                                        color: isUsuario || isError
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    if (_chatLoading && _mensajes.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: LinearProgressIndicator(),
                      ),

                    // Input de mensaje
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: chatInputBg,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _mensajeController,
                              decoration: InputDecoration(
                                hintText: 'Escribe tu pregunta...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF444444)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                filled: true,
                                fillColor: chatInputFieldBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              enabled: _historiaCargada && !_chatLoading,
                              onSubmitted: (_) => _enviarMensaje(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _historiaCargada && !_chatLoading
                                ? _enviarMensaje
                                : null,
                            icon: const Icon(Icons.send),
                            color: theme.colorScheme.primary,
                            style: IconButton.styleFrom(
                              backgroundColor: chatInputFieldBg,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // ========== WIDGETS AUXILIARES ==========
  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDayList() {
    final day = _selectedDay ?? _focusedDay;
    final events = _getEventsForDay(day);

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay citas para este día',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seleccione otro día en el calendario',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final c = events[index];
        final paciente = c['usuarios'];
        final pacienteNombre = paciente is Map
            ? '${(paciente['nombres'] ?? '').toString()} ${(paciente['apellidos'] ?? '').toString()}'
                  .trim()
            : '';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              context.push('/detalle-cita-medico/${c['id']}');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c['hora'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['tipo_cita'] ?? 'Cita médica',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pacienteNombre.isEmpty
                                    ? 'Paciente ID: ${c['usuario_id']}'
                                    : pacienteNombre,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (c['doctor'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.medical_services,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                c['doctor'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatearFechaCorta(dynamic fecha) {
    try {
      if (fecha is String) {
        final date = DateTime.parse(fecha);
        return DateFormat('dd/MM').format(date);
      } else if (fecha is DateTime) {
        return DateFormat('dd/MM').format(fecha);
      }
      return fecha.toString();
    } catch (e) {
      return fecha.toString();
    }
  }
}
