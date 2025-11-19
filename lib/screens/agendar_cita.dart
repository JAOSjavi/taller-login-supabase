import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import '../controllers/theme_controller.dart';

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
    final ThemeController themeController = Get.find<ThemeController>();
    
    return Obx(
      () {
        final isDark = themeController.isDarkMode.value;
        
        return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
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
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 48,
                      color: Colors.blue[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Agendar Nueva Cita',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete todos los campos para agendar su cita',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue[900] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Horarios de atención: 8:00 AM - 6:00 PM',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.blue[200] : Colors.blue[800],
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
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
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue[400]!,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Poppins',
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
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.blue[400]!,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontFamily: 'Poppins',
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Poppins',
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
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'Poppins',
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
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'Poppins',
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
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.blue[400]!,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontFamily: 'Poppins',
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
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF444444) : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[400]!,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2F2F2F) : Colors.white,
                    labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  child: Text(
                    _hora != null ? _hora!.format(context) : 'Seleccionar hora',
                    style: TextStyle(
                      color: _hora != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white54 : Colors.grey[600]),
                      fontFamily: 'Poppins',
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
                    color: _nombreArchivo != null
                        ? Colors.green
                        : (isDark ? const Color(0xFF444444) : Colors.grey[300]!),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _nombreArchivo != null
                      ? (isDark ? Colors.green[900] : Colors.green[50])
                      : (isDark ? const Color(0xFF2F2F2F) : Colors.white),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 32,
                      color: _nombreArchivo != null
                          ? Colors.green[600]
                          : Colors.grey[600],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nombreArchivo != null
                          ? 'Archivo seleccionado: $_nombreArchivo'
                          : 'Subir historia clínica (PDF)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _nombreArchivo != null
                            ? (isDark ? Colors.green[300] : Colors.green[700])
                            : (isDark ? Colors.white70 : Colors.grey[700]),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _seleccionarArchivo,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _nombreArchivo != null
                            ? 'Cambiar archivo'
                            : 'Seleccionar archivo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _nombreArchivo != null
                            ? Colors.orange[600]
                            : Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _seleccionarEjemplo,
                      icon: const Icon(Icons.library_books),
                      label: const Text('Elegir historia de ejemplo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[600],
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
      },
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
                onPressed: () => Navigator.of(context).pop('downloads'),
                child: const Text('Cargar desde Downloads'),
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

        if (opcion == 'downloads') {
          await _cargarDesdeDownloads();
          return;
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null) {
        final file = result.files.single;
        Uint8List? pickedBytes = file.bytes;
        if (pickedBytes == null && file.readStream != null) {
          final readStream = file.readStream;
          if (readStream != null) {
            final builder = BytesBuilder();
            await for (final chunk in readStream) {
              builder.add(chunk);
            }
            pickedBytes = builder.takeBytes();
          }
        }
        if (pickedBytes == null && file.path != null) {
          try {
            final filePath = file.path;
            if (filePath != null) {
              pickedBytes = await File(filePath).readAsBytes();
            }
          } catch (_) {}
        }
        setState(() {
          _archivoBytes = pickedBytes;
          _archivoPDF = null;
          _nombreArchivo = pickedBytes != null ? file.name : null;
        });
        if (_archivoBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo leer el archivo seleccionado'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  Future<void> _cargarDesdeDownloads() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Nombre del archivo que buscamos
      const nombreArchivo = 'historia clinica 1.pdf';

      // Lista de rutas posibles para Downloads en Android
      final rutasPosibles = <String>[];

      // Intentar obtener el directorio de Downloads usando path_provider
      try {
        if (Platform.isAndroid) {
          // Para Android, intentar diferentes métodos
          final directory = await getExternalStorageDirectory();
          if (directory != null) {
            try {
              // Obtener el directorio padre y luego ir a Download
              // En Android, el directorio externo suele estar en /storage/emulated/0/
              final parent = directory.parent;
              if (parent != null) {
                final grandParent = parent.parent;
                if (grandParent != null) {
                  final downloadsPath = '${grandParent.path}/Download';
                  rutasPosibles.add(downloadsPath);
                }
              }
            } catch (e) {
              print('Error al construir ruta desde directory: $e');
            }
          }

          // Rutas comunes en Android
          rutasPosibles.add('/storage/emulated/0/Download');
          rutasPosibles.add('/sdcard/Download');
          rutasPosibles.add('/storage/sdcard0/Download');
        } else if (Platform.isIOS) {
          // Para iOS, usar el directorio de documentos
          final directory = await getApplicationDocumentsDirectory();
          rutasPosibles.add(directory.path);
        }
      } catch (e) {
        print('Error al obtener directorio: $e');
      }

      File? archivoEncontrado;
      String? rutaEncontrada;

      // Buscar el archivo en las rutas posibles
      for (final ruta in rutasPosibles) {
        try {
          final archivo = File('$ruta/$nombreArchivo');
          if (await archivo.exists()) {
            archivoEncontrado = archivo;
            rutaEncontrada = ruta;
            break;
          }
        } catch (e) {
          print('Error al verificar ruta $ruta: $e');
        }
      }

      if (archivoEncontrado != null) {
        // Leer el archivo
        final bytes = await archivoEncontrado.readAsBytes();

        setState(() {
          _archivoBytes = bytes;
          _archivoPDF = archivoEncontrado;
          _nombreArchivo = nombreArchivo;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Archivo cargado: $nombreArchivo\nDesde: $rutaEncontrada',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Si no se encuentra, mostrar un mensaje con las rutas intentadas
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se encontró el archivo "$nombreArchivo" en Downloads.\n'
                'Rutas verificadas: ${rutasPosibles.join(", ")}\n'
                'Por favor, use "Buscar archivo" para seleccionarlo manualmente.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar desde Downloads: ${e.toString()}'),
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

  Future<void> _seleccionarEjemplo() async {
    try {
      final opcion = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Historias clínicas de ejemplo'),
          content: const Text('Seleccione una historia clínica de ejemplo'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('historia1'),
              child: const Text('Historia clínica 1'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('historia2'),
              child: const Text('Historia clínica 2'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('historia3'),
              child: const Text('Historia clínica 3'),
            ),
          ],
        ),
      );

      if (opcion != null) {
        await _cargarEjemplo(opcion);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar ejemplo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarEjemplo(String id) async {
    final urls = {
      'historia1':
          'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
      'historia2':
          'https://www.adobe.com/support/products/enterprise/knowledgecenter/media/c4611_sample_explain.pdf',
      'historia3': 'https://gahp.net/wp-content/uploads/2017/09/sample.pdf',
    };
    final nombres = {
      'historia1': 'historia_clinica_1.pdf',
      'historia2': 'historia_clinica_2.pdf',
      'historia3': 'historia_clinica_3.pdf',
    };

    final url = urls[id];
    final nombre = nombres[id];
    if (url == null || nombre == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        setState(() {
          _archivoBytes = resp.bodyBytes;
          _archivoPDF = null;
          _nombreArchivo = nombre;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Historia clínica de ejemplo seleccionada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('No se pudo descargar el ejemplo (${resp.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar ejemplo: ${e.toString()}'),
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

  Future<void> _confirmarCita() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

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

    if (_tipoCita == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un tipo de cita'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_doctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un doctor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_archivoBytes == null) {
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

      // Verificar que el usuario tiene todos los datos necesarios
      if (!usuarioData.containsKey('id')) {
        throw Exception(
          'El usuario no tiene un ID válido. Por favor, inicie sesión nuevamente.',
        );
      }

      // Crear fecha a partir de los campos de texto de forma segura
      final ano = int.tryParse(_ano ?? '');
      final mes = int.tryParse(_mes ?? '');
      final dia = int.tryParse(_dia ?? '');
      if (ano == null || mes == null || dia == null) {
        throw Exception('Fecha inválida, verifique día/mes/año');
      }
      final fecha = DateTime(ano, mes, dia);

      // Validar que la fecha no sea en el pasado
      final ahora = DateTime.now();
      if (fecha.isBefore(DateTime(ahora.year, ahora.month, ahora.day))) {
        throw Exception('No se pueden agendar citas en fechas pasadas');
      }

      // Validar horario de atención (8:00 AM - 6:00 PM)
      final horaSel = _hora;
      if (horaSel == null) {
        throw Exception('Por favor seleccione una hora');
      }
      final horaCita = horaSel.hour;
      if (horaCita < 8 || horaCita >= 18) {
        throw Exception('Los horarios de atención son de 8:00 AM a 6:00 PM');
      }

      // Verificar disponibilidad del doctor en esa fecha y hora
      final horaFormateada =
          '${horaSel.hour.toString().padLeft(2, '0')}:${horaSel.minute.toString().padLeft(2, '0')}';
      final doctorSel = _doctor;
      if (doctorSel == null || doctorSel.isEmpty) {
        throw Exception('Por favor seleccione un doctor');
      }
      final disponible = await SupabaseService.instance.verificarDisponibilidad(
        doctor: doctorSel,
        fecha: fecha,
        hora: horaFormateada,
      );

      if (!disponible) {
        throw Exception(
          'El doctor $doctorSel no está disponible en esa fecha y hora. Por favor seleccione otro horario.',
        );
      }

      // Subir archivo PDF
      final usuarioId = usuarioData['id'] as String?;
      if (usuarioId == null || usuarioId.isEmpty) {
        throw Exception('No se pudo obtener el ID del usuario');
      }

      // Usar el nombre original del archivo si está disponible, sino generar uno
      final nombreArchivoStorage =
          _nombreArchivo ??
          '${usuarioId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Nombre para el documento médico (usar el original si está disponible)
      final nombreArchivoDoc =
          _nombreArchivo ??
          'historia_clinica_${DateTime.now().millisecondsSinceEpoch}.pdf';

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
      } else if (_archivoBytes != null) {
        if (kIsWeb) {
          resultadoArchivo = await SupabaseService.instance.subirArchivoBytes(
            bytes: _archivoBytes!,
            nombreArchivo: nombreArchivoStorage,
          );
        } else {
          final tmpDir = await getTemporaryDirectory();
          final tmpFile = File('${tmpDir.path}/$nombreArchivoStorage');
          await tmpFile.writeAsBytes(_archivoBytes!, flush: true);
          resultadoArchivo = await SupabaseService.instance.subirArchivoPDF(
            archivo: tmpFile,
            nombreArchivo: nombreArchivoStorage,
          );
        }
      } else {
        throw Exception('No se encontró archivo válido para subir');
      }

      if (!resultadoArchivo['success']) {
        throw Exception(
          resultadoArchivo['message'] ?? 'Error desconocido al subir archivo',
        );
      }

      // Verificar que la URL existe
      final pdfUrl = resultadoArchivo['url'] as String?;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        throw Exception('No se pudo obtener la URL del archivo subido');
      }

      // Agendar cita
      final tipoSel = _tipoCita;
      if (tipoSel == null || tipoSel.isEmpty) {
        throw Exception('Por favor seleccione un tipo de cita');
      }

      final resultadoCita = await SupabaseService.instance.agendarCita(
        usuarioId: usuarioId,
        tipoCita: tipoSel,
        doctor: doctorSel,
        fecha: fecha,
        hora: horaFormateada,
        pdfUrl: pdfUrl,
        nombreArchivo: nombreArchivoDoc,
      );

      if (resultadoCita['success'] == true) {
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
        final errorMessage = resultadoCita['message'] as String?;
        throw Exception(errorMessage ?? 'Error desconocido al agendar la cita');
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
