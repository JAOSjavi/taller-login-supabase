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

  @override
  void initState() {
    super.initState();
    _cargarCitas();
  }

  Future<void> _cargarCitas() async {
    setState(() {
      _isLoading = true;
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
      }
    } catch (e) {
      print('❌ Error al cargar citas: $e');

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

  void _editarCita(CitaMedica cita) {
    context.go('/editar-cita/${cita.id}');
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;
    final neutralText = isDark ? Colors.white70 : Colors.grey[600]!;
    final secondaryText = isDark ? Colors.white60 : Colors.grey[500]!;

    return Scaffold(
      backgroundColor: scaffoldBg,
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
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/agendar-cita'),
            tooltip: 'Agendar nueva cita',
          ),
        ],
      ),
      body: Column(
        children: [
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
                          color: neutralText,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes citas agendadas',
                          style: TextStyle(fontSize: 18, color: neutralText),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agenda tu primera cita médica',
                          style: TextStyle(fontSize: 14, color: secondaryText),
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: cardColor,
                          shadowColor: Colors.black.withOpacity(
                            isDark ? 0.4 : 0.1,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.3 : 0.1,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.2 : 0.05,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                ),
                              ],
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                        color: neutralText,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        cita.doctor,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
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
                                        color: neutralText,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        cita.fechaFormateada,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.access_time,
                                        size: 20,
                                        color: neutralText,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        cita.hora,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // PDF
                                  if (cita.pdfUrl.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF444444)
                                              : Colors.grey[300]!,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              isDark ? 0.2 : 0.05,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.picture_as_pdf,
                                            size: 20,
                                            color: Colors.red[400],
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
                                                    color: neutralText,
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
                                    ),
                                  if (cita.diagnostico != null &&
                                      cita.diagnostico!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1F2B22)
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF2D4A38)
                                              : (Colors.green[100] ??
                                                    Colors.green),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              isDark ? 0.2 : 0.08,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
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
                                            style: TextStyle(
                                              height: 1.4,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
