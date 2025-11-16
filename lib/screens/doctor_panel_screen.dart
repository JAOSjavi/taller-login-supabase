import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../services/supabase_service.dart';
import '../services/ai_chat_service.dart';

/// Pantalla del Panel Médico con dos paneles:
/// - Panel Izquierdo: Lista de Citas en tiempo real
/// - Panel Derecho: Visor de PDF y Chat con IA
class DoctorPanelScreen extends StatefulWidget {
  const DoctorPanelScreen({super.key});

  @override
  State<DoctorPanelScreen> createState() => _DoctorPanelScreenState();
}

class _DoctorPanelScreenState extends State<DoctorPanelScreen> {
  // Estado de la lista de citas
  String? _doctorFiltro;
  Map<String, dynamic>? _citaSeleccionada;
  String? _usuarioIdSeleccionado;
  String? _pdfUrlSeleccionado;

  // Estado del visor PDF
  String? _signedPdfUrl;
  bool _cargandoPdf = false;
  String? _errorPdf;

  // Estado del chat con IA
  final List<Map<String, String>> _mensajesChat = [];
  final TextEditingController _mensajeController = TextEditingController();
  bool _cargandoChat = false;
  bool _pdfCargadoParaChat = false;
  String? _pdfBase64;

  // Controlador del visor PDF
  PdfViewerController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _pdfViewController = PdfViewerController();
    // Obtener el nombre del doctor actual si está disponible
    _cargarDoctorActual();
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _pdfViewController?.dispose();
    super.dispose();
  }

  Future<void> _cargarDoctorActual() async {
    // Intentar obtener el doctor desde la sesión o configuración
    // Por ahora, se puede filtrar manualmente
    setState(() {});
  }

  /// Carga el PDF de la cita seleccionada
  Future<void> _cargarPdfCita(String? pdfUrl, String usuarioId) async {
    if (pdfUrl == null || pdfUrl.isEmpty) {
      // Intentar obtener desde user_doc
      pdfUrl = await SupabaseService.instance.obtenerPdfUrlMasReciente(
        usuarioId,
      );
    }

    if (pdfUrl == null || pdfUrl.isEmpty) {
      setState(() {
        _errorPdf = 'No hay PDF disponible para esta cita';
        _signedPdfUrl = null;
        _pdfCargadoParaChat = false;
      });
      return;
    }

    setState(() {
      _cargandoPdf = true;
      _errorPdf = null;
    });

    try {
      // Generar signed URL
      final signedUrl = await SupabaseService.instance.generarSignedUrl(
        path: pdfUrl,
      );

      if (signedUrl == null) {
        throw Exception('No se pudo generar la URL del PDF');
      }

      // Descargar PDF y convertir a Base64 para el chat
      try {
        final base64 = await SupabaseService.instance.descargarPdfABase64(
          signedUrl,
        );
        setState(() {
          _pdfBase64 = base64;
          _pdfCargadoParaChat = true;
        });
      } catch (e) {
        print('Error al cargar PDF para chat: $e');
        // Continuar aunque falle la conversión a Base64
      }

      setState(() {
        _signedPdfUrl = signedUrl;
        _cargandoPdf = false;
      });
    } catch (e) {
      setState(() {
        _errorPdf = 'Error al cargar PDF: ${e.toString()}';
        _signedPdfUrl = null;
        _cargandoPdf = false;
      });
    }
  }

  /// Envía un mensaje al chat con IA
  Future<void> _enviarMensajeChat() async {
    final mensaje = _mensajeController.text.trim();
    if (mensaje.isEmpty || !_pdfCargadoParaChat || _pdfBase64 == null) {
      return;
    }

    setState(() {
      _mensajesChat.add({'tipo': 'usuario', 'mensaje': mensaje});
      _mensajeController.clear();
      _cargandoChat = true;
    });

    try {
      final respuesta = await AIChatService.instance.getClinicalInsight(
        pdfBase64Content: _pdfBase64!,
        userQuery: mensaje,
      );

      setState(() {
        _mensajesChat.add({'tipo': 'asistente', 'mensaje': respuesta});
      });
    } catch (e) {
      setState(() {
        _mensajesChat.add({
          'tipo': 'error',
          'mensaje': 'Error: ${e.toString()}',
        });
      });
    } finally {
      setState(() {
        _cargandoChat = false;
      });
    }
  }

  /// Selecciona una cita y carga su PDF
  void _seleccionarCita(Map<String, dynamic> cita) {
    final usuarioId = cita['usuario_id'] as String?;
    final pdfUrl = cita['pdf_url'] as String?;

    setState(() {
      _citaSeleccionada = cita;
      _usuarioIdSeleccionado = usuarioId;
      _pdfUrlSeleccionado = pdfUrl;
      _mensajesChat.clear();
      _pdfCargadoParaChat = false;
      _pdfBase64 = null;
    });

    if (usuarioId != null) {
      _cargarPdfCita(pdfUrl, usuarioId);
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
        actions: [
          // Filtro de doctor
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: 250,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Filtrar por doctor (opcional)',
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white70),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white70),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) {
                  setState(() {
                    _doctorFiltro = value.isEmpty ? null : value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // PANEL IZQUIERDO: Lista de Citas
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Citas Médicas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_doctorFiltro != null && _doctorFiltro!.isNotEmpty)
                          Chip(
                            label: Text('Doctor: $_doctorFiltro'),
                            onDeleted: () {
                              setState(() {
                                _doctorFiltro = null;
                              });
                            },
                          )
                        else
                          Chip(
                            label: const Text('Todas las citas'),
                            backgroundColor: Colors.green[100],
                          ),
                      ],
                    ),
                  ),
                  // Lista de citas en tiempo real
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: SupabaseService.instance.streamCitasMedico(
                        _doctorFiltro,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: TextStyle(color: Colors.red[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final citas = snapshot.data ?? [];

                        if (citas.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay citas para este doctor',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: citas.length,
                          itemBuilder: (context, index) {
                            final cita = citas[index];
                            final isSelected =
                                _citaSeleccionada?['id'] == cita['id'];
                            final paciente = cita['usuarios'];
                            final nombrePaciente = paciente is Map
                                ? '${paciente['nombres'] ?? ''} ${paciente['apellidos'] ?? ''}'
                                      .trim()
                                : 'Paciente ID: ${cita['usuario_id']}';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: isSelected ? 4 : 1,
                              color: isSelected
                                  ? Colors.blue[50]
                                  : Colors.white,
                              child: InkWell(
                                onTap: () => _seleccionarCita(cita),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: Colors.blue[600],
                                              size: 20,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatearFechaCorta(
                                                cita['fecha'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cita['tipo_cita'] ??
                                                  'Cita médica',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              nombrePaciente,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${cita['fecha']} ${cita['hora'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.blue[600],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // PANEL DERECHO: Visor PDF y Chat
          Expanded(
            flex: 3,
            child: _citaSeleccionada == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Selecciona una cita para ver la historia clínica',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Información de la cita seleccionada
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.blue[50],
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cita: ${_citaSeleccionada!['tipo_cita'] ?? 'N/A'} - '
                                'Fecha: ${_formatearFecha(_citaSeleccionada!['fecha'])} ${_citaSeleccionada!['hora'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tabs: PDF y Chat
                      DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(
                                  icon: Icon(Icons.picture_as_pdf),
                                  text: 'Historia Clínica',
                                ),
                                Tab(
                                  icon: Icon(Icons.chat),
                                  text: 'Chat con IA',
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  // Tab 1: Visor PDF
                                  _buildVisorPdf(),
                                  // Tab 2: Chat con IA
                                  _buildChatIA(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisorPdf() {
    if (_cargandoPdf) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando PDF...'),
          ],
        ),
      );
    }

    if (_errorPdf != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorPdf!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_usuarioIdSeleccionado != null) {
                  _cargarPdfCita(_pdfUrlSeleccionado, _usuarioIdSeleccionado!);
                }
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_signedPdfUrl == null) {
      return const Center(child: Text('No hay PDF disponible'));
    }

    return SfPdfViewer.network(_signedPdfUrl!, controller: _pdfViewController);
  }

  Widget _buildChatIA() {
    return Column(
      children: [
        // Mensajes del chat
        Expanded(
          child: _mensajesChat.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _pdfCargadoParaChat
                            ? Icons.chat_bubble_outline
                            : Icons.cloud_download,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pdfCargadoParaChat
                            ? 'Haz una pregunta sobre la historia clínica'
                            : 'Cargando PDF para el chat...',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mensajesChat.length,
                  itemBuilder: (context, index) {
                    final mensaje = _mensajesChat[index];
                    final isUsuario = mensaje['tipo'] == 'usuario';
                    final isError = mensaje['tipo'] == 'error';

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
                          maxWidth: MediaQuery.of(context).size.width * 0.6,
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

        // Indicador de carga
        if (_cargandoChat)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),

        // Input de mensaje
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
                    hintText:
                        'Escribe tu pregunta sobre la historia clínica...',
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
                  enabled: _pdfCargadoParaChat && !_cargandoChat,
                  onSubmitted: (_) => _enviarMensajeChat(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _pdfCargadoParaChat && !_cargandoChat
                    ? _enviarMensajeChat
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
