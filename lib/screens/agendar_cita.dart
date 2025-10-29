import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/supabase_service.dart';

class AgendarCitaScreen extends StatefulWidget {
  const AgendarCitaScreen({super.key});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  String? _tipoCita;
  String? _doctor;
  String? _dia;
  String? _mes;
  String? _ano;
  TimeOfDay? _hora;
  File? _archivoPDF;
  String? _nombreArchivo;
  Uint8List? _archivoBytes; // Para manejar archivos en web

  bool _isLoading = false;

  // Opciones predefinidas
  final List<String> _tiposCita = ['General', 'Optometría', 'Ecografía ocular'];

  final List<String> _doctores = [
    'Dr. Juan Pérez',
    'Dra. María López',
    'Dr. Carlos Gómez',
    'Dra. Ana Rodríguez',
    'Dr. Luis Martínez',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Agendar Cita Médica'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/bienvenida'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 48,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Agendar Nueva Cita',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete todos los campos para agendar su cita',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Horarios de atención: 8:00 AM - 6:00 PM',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Tipo de cita
              DropdownButtonFormField<String>(
                value: _tipoCita,
                decoration: InputDecoration(
                  labelText: 'Tipo de cita médica',
                  prefixIcon: const Icon(Icons.medical_services),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _tiposCita.map((String tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo,
                    child: Text(tipo),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _tipoCita = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor seleccione un tipo de cita';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Doctor
              DropdownButtonFormField<String>(
                value: _doctor,
                decoration: InputDecoration(
                  labelText: 'Seleccionar doctor',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _doctores.map((String doctor) {
                  return DropdownMenuItem<String>(
                    value: doctor,
                    child: Text(doctor),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _doctor = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor seleccione un doctor';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Fecha - Campos separados
              Row(
                children: [
                  // Día
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Día',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _dia = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Día requerido';
                        }
                        final dia = int.tryParse(value);
                        if (dia == null || dia < 1 || dia > 31) {
                          return 'Día inválido (1-31)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mes
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Mes',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _mes = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mes requerido';
                        }
                        final mes = int.tryParse(value);
                        if (mes == null || mes < 1 || mes > 12) {
                          return 'Mes inválido (1-12)';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Año
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _ano = value,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Año requerido';
                        }
                        final ano = int.tryParse(value);
                        if (ano == null || ano < DateTime.now().year) {
                          return 'Año inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hora
              InkWell(
                onTap: _seleccionarHora,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hora de la cita',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _hora != null ? _hora!.format(context) : 'Seleccionar hora',
                    style: TextStyle(
                      color: _hora != null ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Subir archivo PDF
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _archivoPDF != null
                        ? Colors.green
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _archivoPDF != null ? Colors.green[50] : Colors.white,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 32,
                      color: _archivoPDF != null
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _archivoPDF != null
                          ? 'Archivo seleccionado: $_nombreArchivo'
                          : 'Subir historia clínica (PDF)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _archivoPDF != null
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _seleccionarArchivo,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _archivoPDF != null
                            ? 'Cambiar archivo'
                            : 'Seleccionar archivo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _archivoPDF != null
                            ? Colors.orange[600]
                            : Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botón confirmar
              ElevatedButton(
                onPressed: _isLoading ? null : _confirmarCita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Confirmar Cita',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null && picked != _hora) {
      setState(() {
        _hora = picked;
      });
    }
  }

  Future<void> _seleccionarArchivo() async {
    try {
      // Mostrar opciones para el emulador
      if (!kIsWeb) {
        final opcion = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Seleccionar Archivo'),
            content: const Text('¿Cómo desea proceder?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop('picker'),
                child: const Text('Buscar archivo'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop('demo'),
                child: const Text('Usar PDF de prueba'),
              ),
            ],
          ),
        );

        if (opcion == 'demo') {
          _usarPDFDePrueba();
          return;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb, // Importante para obtener los bytes en web
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            // Para web, guardamos los bytes y el nombre
            _archivoPDF = null;
            _archivoBytes = result.files.single.bytes;
            _nombreArchivo = result.files.single.name;
          } else {
            // Para móvil, usamos File normalmente
            _archivoPDF = File(result.files.single.path!);
            _archivoBytes = null;
            _nombreArchivo = result.files.single.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar archivo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _usarPDFDePrueba() {
    setState(() {
      _nombreArchivo = 'historia_clinica_prueba.pdf';
      _archivoPDF = null;
      _archivoBytes = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ PDF de prueba seleccionado para testing'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _confirmarCita() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dia == null || _mes == null || _ano == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor complete todos los campos de fecha'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_hora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione una hora'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_archivoPDF == null &&
        _archivoBytes == null &&
        _nombreArchivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un archivo PDF'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener usuario actual
      final usuarioData = await SupabaseService.instance.getUsuarioActual();
      if (usuarioData == null) {
        throw Exception('No se pudo obtener la información del usuario');
      }

      // Crear fecha a partir de los campos
      final fecha = DateTime(
        int.parse(_ano!),
        int.parse(_mes!),
        int.parse(_dia!),
      );

      // Validar que la fecha no sea en el pasado
      final ahora = DateTime.now();
      if (fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day))) {
        throw Exception('No se pueden agendar citas en fechas pasadas');
      }

      // Validar horario de atención (8:00 AM - 6:00 PM)
      final horaCita = _hora!.hour;
      if (horaCita < 8 || horaCita >= 18) {
        throw Exception('Los horarios de atención son de 8:00 AM a 6:00 PM');
      }

      // Verificar disponibilidad del doctor en esa fecha y hora
      final horaFormateada =
          '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}';
      final disponible = await SupabaseService.instance.verificarDisponibilidad(
        doctor: _doctor!,
        fecha: fecha,
        hora: horaFormateada,
      );

      if (!disponible) {
        throw Exception(
          'El doctor ${_doctor!} no está disponible en esa fecha y hora. Por favor seleccione otro horario.',
        );
      }

      // Subir archivo PDF
      final nombreArchivo =
          '${usuarioData['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      Map<String, dynamic> resultadoArchivo;

      // Si es PDF de prueba, crear URL ficticia
      if (_nombreArchivo == 'historia_clinica_prueba.pdf' &&
          _archivoPDF == null &&
          _archivoBytes == null) {
        resultadoArchivo = {
          'success': true,
          'url': 'https://ejemplo.com/pdf_prueba.pdf',
          'message': 'PDF de prueba simulado',
        };
      } else if (kIsWeb && _archivoBytes != null) {
        // Para web, usar bytes directamente
        resultadoArchivo = await SupabaseService.instance.subirArchivoBytes(
          bytes: _archivoBytes!,
          nombreArchivo: nombreArchivo,
        );
      } else {
        // Para móvil, usar archivo
        resultadoArchivo = await SupabaseService.instance.subirArchivoPDF(
          archivo: _archivoPDF!,
          nombreArchivo: nombreArchivo,
        );
      }

      if (!resultadoArchivo['success']) {
        throw Exception(resultadoArchivo['message']);
      }

      // Agendar cita
      final resultadoCita = await SupabaseService.instance.agendarCita(
        usuarioId: usuarioData['id'],
        tipoCita: _tipoCita!,
        doctor: _doctor!,
        fecha: fecha,
        hora: horaFormateada,
        pdfUrl: resultadoArchivo['url'],
      );

      if (resultadoCita['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita médica agendada con éxito ✅'),
              backgroundColor: Colors.green,
            ),
          );

          // Redirigir a la pantalla de mis citas
          context.go('/mis-citas');
        }
      } else {
        throw Exception(resultadoCita['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al agendar cita: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
