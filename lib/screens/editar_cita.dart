import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/supabase_service.dart';
import '../models/cita_medica.dart';

class EditarCitaScreen extends StatefulWidget {
  final String citaId;

  const EditarCitaScreen({super.key, required this.citaId});

  @override
  State<EditarCitaScreen> createState() => _EditarCitaScreenState();
}

class _EditarCitaScreenState extends State<EditarCitaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  String? _tipoCita;
  String? _doctor;
  DateTime? _fecha;
  TimeOfDay? _hora;
  File? _archivoPDF;
  String? _nombreArchivo;
  Uint8List? _archivoBytes;

  bool _isLoading = false;
  bool _cargandoCita = true;
  CitaMedica? _citaOriginal;

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
  void initState() {
    super.initState();
    _cargarCita();
  }

  Future<void> _cargarCita() async {
    try {
      final citasData = await SupabaseService.instance.getCitasUsuario(
        (await SupabaseService.instance.getUsuarioActual())!['id'],
      );

      final citaData = citasData.firstWhere(
        (cita) => cita['id'] == widget.citaId,
        orElse: () => throw Exception('Cita no encontrada'),
      );

      _citaOriginal = CitaMedica.fromJson(citaData);

      setState(() {
        _tipoCita = _citaOriginal!.tipoCita;
        _doctor = _citaOriginal!.doctor;
        _fecha = _citaOriginal!.fecha;
        _hora = TimeOfDay(
          hour: int.parse(_citaOriginal!.hora.split(':')[0]),
          minute: int.parse(_citaOriginal!.hora.split(':')[1]),
        );
        _cargandoCita = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cita: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        context.go('/mis-citas');
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _fecha) {
      setState(() {
        _fecha = picked;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 9, minute: 0),
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
        withData: kIsWeb,
      );

      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _archivoPDF = null;
            _archivoBytes = result.files.single.bytes;
            _nombreArchivo = result.files.single.name;
          } else {
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

  Future<void> _actualizarCita() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione una fecha'),
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

    setState(() {
      _isLoading = true;
    });

    try {
      String? pdfUrl = _citaOriginal!.pdfUrl;

      // Si se seleccionó un nuevo archivo, subirlo
      if (_archivoPDF != null ||
          _archivoBytes != null ||
          _nombreArchivo == 'historia_clinica_prueba.pdf') {
        final usuarioData = await SupabaseService.instance.getUsuarioActual();
        final nombreArchivo =
            '${usuarioData!['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';

        Map<String, dynamic> resultadoArchivo;

        // Si es PDF de prueba, crear URL ficticia
        if (_nombreArchivo == 'historia_clinica_prueba.pdf' &&
            _archivoPDF == null &&
            _archivoBytes == null) {
          resultadoArchivo = {
            'success': true,
            'url': 'https://ejemplo.com/pdf_prueba_editado.pdf',
            'message': 'PDF de prueba simulado',
          };
        } else if (kIsWeb && _archivoBytes != null) {
          resultadoArchivo = await SupabaseService.instance.subirArchivoBytes(
            bytes: _archivoBytes!,
            nombreArchivo: nombreArchivo,
          );
        } else {
          resultadoArchivo = await SupabaseService.instance.subirArchivoPDF(
            archivo: _archivoPDF!,
            nombreArchivo: nombreArchivo,
          );
        }

        if (!resultadoArchivo['success']) {
          throw Exception(resultadoArchivo['message']);
        }

        pdfUrl = resultadoArchivo['url'];
      }

      // Actualizar cita
      final resultado = await SupabaseService.instance.actualizarCita(
        citaId: widget.citaId,
        tipoCita: _tipoCita!,
        doctor: _doctor!,
        fecha: _fecha!,
        hora:
            '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}',
        pdfUrl: pdfUrl!,
      );

      if (resultado['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita actualizada exitosamente ✅'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/mis-citas');
        }
      } else {
        throw Exception(resultado['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar cita: ${e.toString()}'),
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

  @override
  Widget build(BuildContext context) {
    if (_cargandoCita) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Cargando...'),
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Editar Cita Médica'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/mis-citas'),
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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.edit_calendar,
                      size: 48,
                      color: Colors.orange[600],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Editar Cita Médica',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Modifique los datos de su cita médica',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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

              // Fecha
              InkWell(
                onTap: _seleccionarFecha,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de la cita',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _fecha != null
                        ? DateFormat('dd/MM/yyyy').format(_fecha!)
                        : 'Seleccionar fecha',
                    style: TextStyle(
                      color: _fecha != null ? Colors.black87 : Colors.grey[600],
                    ),
                  ),
                ),
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

              // Subir archivo PDF (opcional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: (_archivoPDF != null || _archivoBytes != null)
                        ? Colors.green
                        : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: (_archivoPDF != null || _archivoBytes != null)
                      ? Colors.green[50]
                      : Colors.white,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 32,
                      color: (_archivoPDF != null || _archivoBytes != null)
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (_archivoPDF != null || _archivoBytes != null)
                          ? 'Archivo seleccionado: $_nombreArchivo'
                          : 'Actualizar historia clínica (PDF) - Opcional',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: (_archivoPDF != null || _archivoBytes != null)
                            ? Colors.green[700]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Archivo actual: ${_citaOriginal!.pdfUrl.isNotEmpty ? "Adjunto" : "Ninguno"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _seleccionarArchivo,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        (_archivoPDF != null || _archivoBytes != null)
                            ? 'Cambiar archivo'
                            : 'Seleccionar archivo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (_archivoPDF != null || _archivoBytes != null)
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

              // Botón actualizar
              ElevatedButton(
                onPressed: _isLoading ? null : _actualizarCita,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
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
                        'Actualizar Cita',
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
}
