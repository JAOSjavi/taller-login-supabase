import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/gemini_service.dart';

class DetalleCitaMedicoScreen extends StatefulWidget {
  final String citaId;

  const DetalleCitaMedicoScreen({super.key, required this.citaId});

  @override
  State<DetalleCitaMedicoScreen> createState() =>
      _DetalleCitaMedicoScreenState();
}

class _DetalleCitaMedicoScreenState extends State<DetalleCitaMedicoScreen> {
  Map<String, dynamic>? _citaData;
  Map<String, dynamic>? _pacienteData;
  bool _loading = true;
  String? _error;

  // Chatbot
  ChatSession? _chatSession;
  final List<Map<String, String>> _mensajes = [];
  final TextEditingController _mensajeController = TextEditingController();
  final TextEditingController _diagnosticoController = TextEditingController();
  bool _chatLoading = false;
  bool _historiaCargada = false;
  bool _guardandoDiagnostico = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _diagnosticoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Obtener datos de la cita
      final cita = await SupabaseService.instance.getCitaPorId(widget.citaId);
      if (cita == null) {
        throw Exception('No se encontró la cita');
      }

      setState(() {
        _citaData = cita;
      });

      // Obtener datos del paciente
      final usuarioId = cita['usuario_id'] as String?;
      if (usuarioId != null) {
        // Obtener información del usuario desde Supabase
        final usuarios = await SupabaseService.instance.client
            .from('usuarios')
            .select('*')
            .eq('id', usuarioId)
            .maybeSingle();

        if (usuarios != null) {
          setState(() {
            _pacienteData = usuarios;
          });
        }
      }

      // Cargar historia clínica si existe
      // Primero intentar obtener desde user_doc, si no existe usar pdf_url (compatibilidad)
      String? pdfUrl;

      // Intentar obtener desde user_doc
      final userDoc = cita['user_doc'];
      if (userDoc != null && userDoc is Map) {
        pdfUrl = userDoc['pdf_url'] as String?;
      }

      // Si no hay en user_doc, usar pdf_url directamente (para compatibilidad con datos antiguos)
      if ((pdfUrl == null || pdfUrl.isEmpty) && cita['pdf_url'] != null) {
        pdfUrl = cita['pdf_url'] as String?;
      }

      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        await _cargarHistoriaClinica(pdfUrl);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _cargarHistoriaClinica(String pdfUrl) async {
    try {
      setState(() {
        _chatLoading = true;
      });

      // Extraer texto del PDF usando Gemini
      final textoHistoria = await GeminiService.instance.extraerTextoDePDF(
        pdfUrl,
      );

      // Crear chatbot con la historia clínica
      final chat = await GeminiService.instance.crearChatbotConHistoriaClinica(
        textoHistoria,
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
      setState(() {
        _chatLoading = false;
      });
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
      setState(() {
        _chatLoading = false;
      });
    }
  }

  Future<void> _mostrarDialogoDiagnostico() async {
    if (_citaData == null) return;

    final diagnosticoActual = (_citaData!['diagnostico'] ?? '')
        .toString()
        .trim();
    _diagnosticoController.text = diagnosticoActual;

    await showDialog(
      context: context,
      barrierDismissible: !_guardandoDiagnostico,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                diagnosticoActual.isEmpty
                    ? 'Registrar diagnóstico'
                    : 'Actualizar diagnóstico',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: TextField(
                  controller: _diagnosticoController,
                  maxLines: 6,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Diagnóstico del paciente',
                    hintText: 'Escribe los hallazgos y recomendaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _guardandoDiagnostico
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: _guardandoDiagnostico
                      ? null
                      : () =>
                            _guardarDiagnostico(dialogContext, setStateDialog),
                  icon: _guardandoDiagnostico
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
                      : const Icon(Icons.save),
                  label: Text(
                    _guardandoDiagnostico ? 'Guardando...' : 'Guardar',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _guardarDiagnostico(
    BuildContext dialogContext,
    StateSetter setStateDialog,
  ) async {
    if (_citaData == null) return;

    final texto = _diagnosticoController.text.trim();

    setState(() {
      _guardandoDiagnostico = true;
    });
    setStateDialog(() {});

    final resultado = await SupabaseService.instance.actualizarDiagnosticoCita(
      citaId: _citaData!['id'].toString(),
      diagnostico: texto,
    );

    if (!mounted) return;

    setState(() {
      _guardandoDiagnostico = false;
      if (resultado['success'] == true) {
        _citaData!['diagnostico'] = texto.isEmpty ? null : texto;
      }
    });
    setStateDialog(() {});

    if (resultado['success'] == true) {
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnóstico guardado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final mensaje =
          resultado['message'] ??
          'No se pudo guardar el diagnóstico. Intenta de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Cita'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            )
          : _citaData == null
          ? const Center(child: Text('No se encontraron datos'))
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.info), text: 'Información'),
                      Tab(icon: Icon(Icons.assignment), text: 'Diagnóstico'),
                      Tab(icon: Icon(Icons.chat), text: 'Chatbot IA'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab de información
                        _buildInfoTab(),
                        // Diagnóstico
                        _buildDiagnosticoTab(),
                        // Tab de chatbot
                        _buildChatTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información de la Cita',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    'ID de Cita',
                    _citaData!['id']?.toString() ?? 'N/A',
                  ),
                  _buildInfoRow('Tipo', _citaData!['tipo_cita'] ?? 'N/A'),
                  _buildInfoRow('Doctor', _citaData!['doctor'] ?? 'N/A'),
                  _buildInfoRow('Fecha', _formatearFecha(_citaData!['fecha'])),
                  _buildInfoRow('Hora', _citaData!['hora'] ?? 'N/A'),
                  if (_citaData!['pdf_url'] != null &&
                      (_citaData!['pdf_url'] as String).isNotEmpty)
                    _buildInfoRow('Historia Clínica', 'Adjunta'),
                ],
              ),
            ),
          ),
          if (_pacienteData != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información del Paciente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Nombres',
                      _pacienteData!['nombres'] ?? 'N/A',
                    ),
                    _buildInfoRow(
                      'Apellidos',
                      _pacienteData!['apellidos'] ?? 'N/A',
                    ),
                    _buildInfoRow('Cédula', _pacienteData!['cedula'] ?? 'N/A'),
                    _buildInfoRow('EPS', _pacienteData!['eps'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticoCard() {
    final diagnostico = (_citaData?['diagnostico'] ?? '').toString().trim();
    final tieneDiagnostico = diagnostico.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.blue[600]),
                const SizedBox(width: 8),
                const Text(
                  'Diagnóstico del Paciente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Esta información será visible para el paciente en su historial de citas.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _guardandoDiagnostico
                    ? null
                    : _mostrarDialogoDiagnostico,
                icon: Icon(tieneDiagnostico ? Icons.edit : Icons.note_add),
                label: Text(
                  tieneDiagnostico
                      ? 'Editar diagnóstico'
                      : 'Agregar diagnóstico',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (tieneDiagnostico)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[100] ?? Colors.green),
                ),
                child: Text(
                  diagnostico,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aún no has registrado un diagnóstico para esta cita.',
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final pdfUrl = _citaData!['pdf_url'] as String?;

    if (pdfUrl == null || pdfUrl.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay historia clínica disponible',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (!_historiaCargada && !_chatLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_information, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Cargar historia clínica para activar el chatbot',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _cargarHistoriaClinica(pdfUrl),
              icon: const Icon(Icons.cloud_download),
              label: const Text('Cargar Historia Clínica'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _mensajes.isEmpty
              ? Center(
                  child: _chatLoading
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _historiaCargada
                                  ? 'Haz una pregunta sobre el paciente'
                                  : 'Cargando historia clínica...',
                              style: const TextStyle(color: Colors.grey),
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
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mensaje['mensaje'] ?? '',
                                style: const TextStyle(fontSize: 12),
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
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red[50]
                              : isUsuario
                              ? Colors.blue[600]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Text(
                          mensaje['mensaje'] ?? '',
                          style: TextStyle(
                            color: isUsuario || isError
                                ? Colors.white
                                : Colors.black87,
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    filled: true,
                    fillColor: Colors.white,
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
                color: Colors.blue[600],
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_buildDiagnosticoCard()],
      ),
    );
  }

  String _formatearFecha(dynamic fecha) {
    try {
      if (fecha is String) {
        final date = DateTime.parse(fecha);
        return DateFormat('dd/MM/yyyy').format(date);
      } else if (fecha is DateTime) {
        return DateFormat('dd/MM/yyyy').format(fecha);
      }
      return fecha.toString();
    } catch (e) {
      return fecha.toString();
    }
  }
}
