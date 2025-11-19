import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/cita_medica.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  List<CitaMedica> _citas = [];
  bool _isLoading = true;
  String? _usuarioId;
  String? _errorMessage;
  bool _mostrarDebugInfo = false; // Para mostrar información de depuración

  @override
  void initState() {
    super.initState();
    _cargarCitas();
  }

  Future<void> _cargarCitas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usuarioData = await SupabaseService.instance.getUsuarioActual();
      if (usuarioData != null) {
        _usuarioId = usuarioData['id'];
        print('🔍 Cargando citas para usuario ID: ${_usuarioId}');

        final citasData = await SupabaseService.instance.getCitasUsuario(
          _usuarioId!,
        );

        print('📊 Citas obtenidas de la base de datos: ${citasData.length}');
        for (var cita in citasData) {
          print(
            '📅 Cita encontrada: ${cita['fecha']} - ${cita['hora']} - ${cita['doctor']}',
          );
        }

        setState(() {
          _citas = citasData.map((data) => CitaMedica.fromJson(data)).toList();
        });
      } else {
        setState(() {
          _errorMessage = 'No se pudo obtener la información del usuario';
        });
      }
    } catch (e) {
      print('❌ Error al cargar citas: $e');
      setState(() {
        _errorMessage = 'Error al cargar citas: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar citas: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelarCita(String citaId) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Está seguro de que desea cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Cancelando cita...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      try {
        print('🗑️ Cancelando cita con ID: $citaId');

        // Primero probar los permisos
        final pruebaPermisos = await SupabaseService.instance.probarEliminacion(
          citaId,
        );
        if (!pruebaPermisos['success']) {
          throw Exception(pruebaPermisos['message']);
        }

        // Si los permisos están bien, proceder con la eliminación
        final resultado = await SupabaseService.instance.cancelarCita(citaId);

        if (resultado['success']) {
          // Actualización inmediata de la lista local
          setState(() {
            _citas.removeWhere((cita) => cita.id == citaId);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Cita cancelada exitosamente'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Verificar que la cita se eliminó realmente de la base de datos
            print('🔄 Verificando eliminación de la cita...');
            await Future.delayed(const Duration(milliseconds: 500));
            await _cargarCitas();

            // Verificar que la cita ya no está en la lista
            final citaEliminada = _citas.any((cita) => cita.id == citaId);
            if (citaEliminada) {
              print('⚠️ La cita aún aparece en la lista después de eliminar');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '⚠️ La cita no se eliminó completamente. Intenta refrescar la página.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            } else {
              print('✅ Cita eliminada correctamente de la lista');
            }
          }
        } else {
          throw Exception(resultado['message']);
        }
      } catch (e) {
        print('❌ Error al cancelar cita: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al cancelar cita: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _limpiarDatosPrueba() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar Datos de Prueba'),
        content: const Text(
          '¿Está seguro de que desea eliminar todas las citas que contienen PDFs de prueba? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        // Filtrar citas que tienen PDFs de prueba
        final citasPrueba = _citas
            .where((cita) => cita.pdfUrl.contains('ejemplo.com'))
            .toList();

        for (var cita in citasPrueba) {
          await SupabaseService.instance.cancelarCita(cita.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Se eliminaron ${citasPrueba.length} citas de prueba',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _cargarCitas(); // Recargar la lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al eliminar citas de prueba: ${e.toString()}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _editarCita(CitaMedica cita) {
    context.go('/editar-cita/${cita.id}');
  }

  Future<void> _probarEliminacion() async {
    if (_citas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay citas para probar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final primeraCita = _citas.first;

    try {
      final resultado = await SupabaseService.instance.probarEliminacion(
        primeraCita.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado['message']),
            backgroundColor: resultado['success'] ? Colors.green : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en prueba: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getEstadoColor(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora).inDays;

    if (diferencia < 0) {
      return Colors.grey; // Pasada
    } else if (diferencia == 0) {
      return Colors.orange; // Hoy
    } else if (diferencia <= 7) {
      return Colors.red; // Próxima semana
    } else {
      return Colors.blue; // Futura
    }
  }

  String _getEstadoTexto(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora).inDays;

    if (diferencia < 0) {
      return 'Pasada';
    } else if (diferencia == 0) {
      return 'Hoy';
    } else if (diferencia == 1) {
      return 'Mañana';
    } else if (diferencia <= 7) {
      return 'Próxima semana';
    } else {
      return 'Programada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mis Citas Médicas'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bienvenida'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarCitas,
            tooltip: 'Refrescar citas',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              setState(() {
                _mostrarDebugInfo = !_mostrarDebugInfo;
              });
            },
            tooltip: 'Información de depuración',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/agendar-cita'),
            tooltip: 'Agendar nueva cita',
          ),
        ],
      ),
      body: Column(
        children: [
          // Información de depuración
          if (_mostrarDebugInfo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Información de Depuración',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('👤 Usuario ID: ${_usuarioId ?? "No disponible"}'),
                  Text('📊 Total de citas: ${_citas.length}'),
                  Text(
                    '🧪 Citas de prueba: ${_citas.where((cita) => cita.pdfUrl.contains('ejemplo.com')).length}',
                  ),
                  Text(
                    '🕒 Última actualización: ${DateTime.now().toString().substring(0, 19)}',
                  ),
                  if (_errorMessage != null)
                    Text(
                      '❌ Error: $_errorMessage',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _limpiarDatosPrueba,
                          icon: const Icon(Icons.cleaning_services, size: 16),
                          label: const Text(
                            'Limpiar Pruebas',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _probarEliminacion(),
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text(
                            'Probar Eliminación',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _citas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes citas agendadas',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agenda tu primera cita médica',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.go('/agendar-cita'),
                          icon: const Icon(Icons.add),
                          label: const Text('Agendar Cita'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarCitas,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _citas.length,
                      itemBuilder: (context, index) {
                        final cita = _citas[index];
                        final estadoColor = _getEstadoColor(cita.fecha);
                        final estadoTexto = _getEstadoTexto(cita.fecha);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header con estado
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: estadoColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: estadoColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        estadoTexto,
                                        style: TextStyle(
                                          color: estadoColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'editar':
                                            _editarCita(cita);
                                            break;
                                          case 'cancelar':
                                            _cancelarCita(cita.id);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'editar',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 20),
                                              SizedBox(width: 8),
                                              Text('Editar'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'cancelar',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cancel,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Cancelar',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // Tipo de cita
                                Row(
                                  children: [
                                    Icon(
                                      Icons.medical_services,
                                      size: 20,
                                      color: Colors.blue[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cita.tipoCita,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Doctor
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cita.doctor,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Fecha y hora
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cita.fechaFormateada,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(
                                      Icons.access_time,
                                      size: 20,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cita.hora,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // PDF
                                if (cita.pdfUrl.isNotEmpty)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf,
                                        size: 20,
                                        color: Colors.red[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Historia clínica adjunta',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            if (_mostrarDebugInfo)
                                              Text(
                                                'URL: ${cita.pdfUrl}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[500],
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          // Aquí podrías abrir el PDF en un visor
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Función de visualización de PDF próximamente',
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('Ver PDF'),
                                      ),
                                    ],
                                  ),
                                if (cita.diagnostico != null &&
                                    cita.diagnostico!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            Colors.green[100] ?? Colors.green,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.assignment_turned_in,
                                              size: 20,
                                              color: Colors.green[700],
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Diagnóstico del médico',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          cita.diagnostico!.trim(),
                                          style: const TextStyle(
                                            height: 1.4,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Información adicional de depuración
                                if (_mostrarDebugInfo) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '🔍 Info de Depuración:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${cita.id}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        Text(
                                          'Creada: ${cita.createdAt.toString().substring(0, 19)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                        Text(
                                          'PDF de prueba: ${cita.pdfUrl.contains('ejemplo.com') ? 'SÍ' : 'NO'}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                cita.pdfUrl.contains(
                                                  'ejemplo.com',
                                                )
                                                ? Colors.orange[700]
                                                : Colors.green[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
