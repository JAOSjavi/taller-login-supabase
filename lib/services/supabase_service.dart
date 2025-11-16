import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_service.dart';
import '../models/usuario.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  late SupabaseClient _client;
  SupabaseClient get client => _client;

  Future<void> initialize() async {
    await dotenv.load(fileName: ".env");

    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

    _client = Supabase.instance.client;
  }

  // Obtener usuario actual
  Usuario? get currentUser => SessionService.instance.currentUser;

  // Verificar si hay sesión activa
  bool get isLoggedIn => SessionService.instance.isLoggedIn;

  // Registrar nuevo usuario
  Future<Map<String, dynamic>> registrarUsuario({
    required String nombres,
    required String apellidos,
    required String cedula,
    required String eps,
  }) async {
    try {
      // Verificar si la cédula ya existe
      final existingUser = await _client
          .from('usuarios')
          .select('cedula')
          .eq('cedula', cedula)
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'Ya existe un usuario registrado con esta cédula',
        };
      }

      // Insertar nuevo usuario
      final response = await _client
          .from('usuarios')
          .insert({
            'nombres': nombres,
            'apellidos': apellidos,
            'cedula': cedula,
            'eps': eps,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Usuario registrado exitosamente',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al registrar usuario: ${e.toString()}',
      };
    }
  }

  // Iniciar sesión con cédula y EPS
  Future<Map<String, dynamic>> iniciarSesion({
    required String cedula,
    required String eps,
  }) async {
    try {
      // Comprobación de Superusuario (sin tocar Supabase)
      final superCedula = dotenv.env['SUPERUSER_CEDULA'] ?? 'superadmin';
      final superEps = dotenv.env['SUPERUSER_EPS'] ?? 'admin';
      if (cedula.trim() == superCedula && eps.trim() == superEps) {
        final usuario = Usuario(
          id: 'superuser',
          nombres: 'Super',
          apellidos: 'Usuario',
          cedula: cedula.trim(),
          eps: 'N/A',
          createdAt: DateTime.now(),
        );
        await SessionService.instance.saveUser(usuario);
        await SessionService.instance.setSuperUser(true);
        return {
          'success': true,
          'message': 'Sesión iniciada como superusuario',
          'data': usuario.toJson(),
        };
      }

      // Buscar usuario por cédula y EPS
      final user = await _client
          .from('usuarios')
          .select('*')
          .eq('cedula', cedula)
          .eq('eps', eps)
          .maybeSingle();

      if (user == null) {
        return {
          'success': false,
          'message': 'Datos incorrectos o usuario no registrado',
        };
      }

      // Guardar usuario en sesión
      final usuario = Usuario.fromJson(user);
      await SessionService.instance.saveUser(usuario);
      await SessionService.instance.setSuperUser(false);

      return {
        'success': true,
        'message': 'Sesión iniciada correctamente',
        'data': user,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al iniciar sesión: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>?> getUsuarioActual() async {
    try {
      // Cargar usuario de la sesión
      await SessionService.instance.loadUser();
      final usuario = SessionService.instance.currentUser;

      if (usuario != null) {
        return usuario.toJson();
      }

      return null;
    } catch (e) {
      print('Error al obtener usuario actual: $e');
      return null;
    }
  }

  // Subir archivo PDF al bucket
  Future<Map<String, dynamic>> subirArchivoPDF({
    required File archivo,
    required String nombreArchivo,
  }) async {
    try {
      final bytes = await archivo.readAsBytes();

      final response = await _client.storage
          .from('bucket1')
          .uploadBinary(
            nombreArchivo,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );

      // Obtener URL pública
      final publicUrl = _client.storage
          .from('bucket1')
          .getPublicUrl(nombreArchivo);

      return {
        'success': true,
        'message': 'Archivo subido exitosamente',
        'url': publicUrl,
        'path': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al subir archivo: ${e.toString()}',
      };
    }
  }

  // Subir archivo PDF usando bytes (para Flutter Web)
  Future<Map<String, dynamic>> subirArchivoBytes({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    try {
      final response = await _client.storage
          .from('bucket1')
          .uploadBinary(
            nombreArchivo,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/pdf'),
          );

      // Obtener URL pública
      final publicUrl = _client.storage
          .from('bucket1')
          .getPublicUrl(nombreArchivo);

      return {
        'success': true,
        'message': 'Archivo subido exitosamente',
        'url': publicUrl,
        'path': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al subir archivo: ${e.toString()}',
      };
    }
  }

  // Crear documento médico en user_doc
  Future<Map<String, dynamic>> crearDocumentoMedico({
    required String usuarioId,
    required String nombreArchivo,
    required String pdfUrl,
    String tipoDocumento = 'historia_clinica',
    String? descripcion,
  }) async {
    try {
      final response = await _client
          .from('user_doc')
          .insert({
            'usuario_id': usuarioId,
            'nombre_archivo': nombreArchivo,
            'pdf_url': pdfUrl,
            'tipo_documento': tipoDocumento,
            'descripcion': descripcion,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Documento creado exitosamente',
        'data': response,
        'docId': response['id'],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al crear documento: ${e.toString()}',
      };
    }
  }

  // Obtener documento médico por ID
  Future<Map<String, dynamic>?> getDocumentoPorId(String docId) async {
    try {
      final response = await _client
          .from('user_doc')
          .select('*')
          .eq('id', docId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error al obtener documento: $e');
      return null;
    }
  }

  // Agendar cita médica (ahora con user_doc)
  Future<Map<String, dynamic>> agendarCita({
    required String usuarioId,
    required String tipoCita,
    required String doctor,
    required DateTime fecha,
    required String hora,
    required String pdfUrl,
    String? nombreArchivo,
  }) async {
    try {
      String? userDocId;

      // Si hay PDF, crear documento en user_doc primero
      if (pdfUrl.isNotEmpty && pdfUrl != 'https://ejemplo.com/pdf_prueba.pdf') {
        final nombreDoc =
            nombreArchivo ??
            'historia_clinica_${DateTime.now().millisecondsSinceEpoch}.pdf';

        final resultadoDoc = await crearDocumentoMedico(
          usuarioId: usuarioId,
          nombreArchivo: nombreDoc,
          pdfUrl: pdfUrl,
          tipoDocumento: 'historia_clinica',
        );

        if (!resultadoDoc['success']) {
          throw Exception(
            resultadoDoc['message'] ?? 'Error al crear documento',
          );
        }

        userDocId = resultadoDoc['docId'] as String?;
      }

      // Crear la cita con user_doc_id
      final response = await _client
          .from('citas_medicas')
          .insert({
            'usuario_id': usuarioId,
            'tipo_cita': tipoCita,
            'doctor': doctor,
            'fecha': fecha.toIso8601String().split('T')[0], // Solo la fecha
            'hora': hora,
            'pdf_url': pdfUrl, // Mantener por compatibilidad
            'user_doc_id': userDocId,
          })
          .select()
          .single();

      return {
        'success': true,
        'message': 'Cita agendada exitosamente',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al agendar cita: ${e.toString()}',
      };
    }
  }

  // Obtener citas del usuario
  Future<List<Map<String, dynamic>>> getCitasUsuario(String usuarioId) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .select('*')
          .eq('usuario_id', usuarioId)
          .order('fecha', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener citas: $e');
      return [];
    }
  }

  // Obtener citas de un médico en un rango de fechas (por nombre de doctor)
  Future<List<Map<String, dynamic>>> getCitasMedicoEnRango({
    required String doctor,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .select('*')
          .eq('doctor', doctor)
          .gte('fecha', desde.toIso8601String().split('T')[0])
          .lte('fecha', hasta.toIso8601String().split('T')[0])
          .order('fecha', ascending: true)
          .order('hora', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener citas del médico en rango: $e');
      return [];
    }
  }

  // Helper: obtener citas del médico por mes (año/mes)
  Future<List<Map<String, dynamic>>> getCitasMedicoPorMes({
    required String doctor,
    required int year,
    required int month,
  }) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    return getCitasMedicoEnRango(
      doctor: doctor,
      desde: firstDay,
      hasta: lastDay,
    );
  }

  // Obtener citas en un rango con datos de paciente (opcionalmente por doctor)
  Future<List<Map<String, dynamic>>> getCitasConPacienteEnRango({
    String? doctor,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    try {
      final hasDoctor = doctor != null && doctor.trim().isNotEmpty;
      final response = hasDoctor
          ? await _client
                .from('citas_medicas')
                .select(
                  'id, fecha, hora, tipo_cita, usuario_id, doctor, usuarios (nombres, apellidos)',
                )
                .eq('doctor', doctor!.trim())
                .gte('fecha', desde.toIso8601String().split('T')[0])
                .lte('fecha', hasta.toIso8601String().split('T')[0])
                .order('fecha', ascending: true)
                .order('hora', ascending: true)
          : await _client
                .from('citas_medicas')
                .select(
                  'id, fecha, hora, tipo_cita, usuario_id, doctor, usuarios (nombres, apellidos)',
                )
                .gte('fecha', desde.toIso8601String().split('T')[0])
                .lte('fecha', hasta.toIso8601String().split('T')[0])
                .order('fecha', ascending: true)
                .order('hora', ascending: true);

      final result = List<Map<String, dynamic>>.from(response);
      if (result.isNotEmpty) return result;

      // Fallback sin join por si hay restricciones RLS en 'usuarios'
      final responseFallback = hasDoctor
          ? await _client
                .from('citas_medicas')
                .select('*')
                .eq('doctor', doctor!.trim())
                .gte('fecha', desde.toIso8601String().split('T')[0])
                .lte('fecha', hasta.toIso8601String().split('T')[0])
                .order('fecha', ascending: true)
                .order('hora', ascending: true)
          : await _client
                .from('citas_medicas')
                .select('*')
                .gte('fecha', desde.toIso8601String().split('T')[0])
                .lte('fecha', hasta.toIso8601String().split('T')[0])
                .order('fecha', ascending: true)
                .order('hora', ascending: true);
      return List<Map<String, dynamic>>.from(responseFallback);
    } catch (e) {
      try {
        final hasDoctor = doctor != null && doctor.trim().isNotEmpty;
        final responseFallback = hasDoctor
            ? await _client
                  .from('citas_medicas')
                  .select('*')
                  .eq('doctor', doctor!.trim())
                  .gte('fecha', desde.toIso8601String().split('T')[0])
                  .lte('fecha', hasta.toIso8601String().split('T')[0])
                  .order('fecha', ascending: true)
                  .order('hora', ascending: true)
            : await _client
                  .from('citas_medicas')
                  .select('*')
                  .gte('fecha', desde.toIso8601String().split('T')[0])
                  .lte('fecha', hasta.toIso8601String().split('T')[0])
                  .order('fecha', ascending: true)
                  .order('hora', ascending: true);
        return List<Map<String, dynamic>>.from(responseFallback);
      } catch (e2) {
        print('Error al obtener citas (fallback): $e2');
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCitasConPacientePorMes({
    String? doctor,
    required int year,
    required int month,
  }) async {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    return getCitasConPacienteEnRango(
      doctor: doctor,
      desde: firstDay,
      hasta: lastDay,
    );
  }

  // Actualizar cita médica
  Future<Map<String, dynamic>> actualizarCita({
    required String citaId,
    required String tipoCita,
    required String doctor,
    required DateTime fecha,
    required String hora,
    required String pdfUrl,
  }) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .update({
            'tipo_cita': tipoCita,
            'doctor': doctor,
            'fecha': fecha.toIso8601String().split('T')[0],
            'hora': hora,
            'pdf_url': pdfUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', citaId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'Cita actualizada exitosamente',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al actualizar cita: ${e.toString()}',
      };
    }
  }

  // Cancelar cita médica
  Future<Map<String, dynamic>> cancelarCita(String citaId) async {
    try {
      print('🗑️ Intentando eliminar cita con ID: $citaId');

      // Verificar que la cita existe antes de eliminarla
      final citaExistente = await _client
          .from('citas_medicas')
          .select('*')
          .eq('id', citaId)
          .maybeSingle();

      if (citaExistente == null) {
        print('⚠️ La cita con ID $citaId no existe');
        return {
          'success': false,
          'message': 'La cita no existe o ya fue eliminada',
        };
      }

      print(
        '✅ Cita encontrada: ${citaExistente['tipo_cita']} - ${citaExistente['doctor']} - ${citaExistente['fecha']}',
      );

      // Intentar eliminar la cita con más información de debug
      final deleteResult = await _client
          .from('citas_medicas')
          .delete()
          .eq('id', citaId)
          .select();

      print('🗑️ Resultado de eliminación: $deleteResult');

      // Verificar que realmente se eliminó
      final citaVerificacion = await _client
          .from('citas_medicas')
          .select('id')
          .eq('id', citaId)
          .maybeSingle();

      if (citaVerificacion != null) {
        print('❌ ERROR: La cita aún existe después de intentar eliminarla');
        return {
          'success': false,
          'message': 'No se pudo eliminar la cita de la base de datos',
        };
      }

      print('✅ Cita eliminada exitosamente de la base de datos');

      return {'success': true, 'message': 'Cita cancelada exitosamente'};
    } catch (e) {
      print('❌ Error al cancelar cita: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Error al cancelar cita: ${e.toString()}',
      };
    }
  }

  // Función de prueba para verificar permisos de eliminación
  Future<Map<String, dynamic>> probarEliminacion(String citaId) async {
    try {
      print('🧪 Probando eliminación de cita con ID: $citaId');

      // Primero, obtener información completa de la cita
      final citaCompleta = await _client
          .from('citas_medicas')
          .select('*')
          .eq('id', citaId)
          .maybeSingle();

      if (citaCompleta == null) {
        return {
          'success': false,
          'message': 'No se encontró la cita con ID: $citaId',
        };
      }

      print('📋 Información de la cita:');
      print('   - ID: ${citaCompleta['id']}');
      print('   - Usuario ID: ${citaCompleta['usuario_id']}');
      print('   - Tipo: ${citaCompleta['tipo_cita']}');
      print('   - Doctor: ${citaCompleta['doctor']}');
      print('   - Fecha: ${citaCompleta['fecha']}');
      print('   - Hora: ${citaCompleta['hora']}');

      // Verificar el usuario actual
      final usuarioActual = await getUsuarioActual();
      if (usuarioActual == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener información del usuario actual',
        };
      }

      print('👤 Usuario actual:');
      print('   - ID: ${usuarioActual['id']}');
      print(
        '   - Nombre: ${usuarioActual['nombres']} ${usuarioActual['apellidos']}',
      );

      // Verificar si el usuario es el propietario de la cita
      if (citaCompleta['usuario_id'] != usuarioActual['id']) {
        return {
          'success': false,
          'message': 'No tienes permisos para eliminar esta cita (no es tuya)',
        };
      }

      print('✅ El usuario tiene permisos para eliminar esta cita');

      return {
        'success': true,
        'message': 'Prueba de permisos exitosa',
        'data': citaCompleta,
      };
    } catch (e) {
      print('❌ Error en prueba de eliminación: $e');
      return {'success': false, 'message': 'Error en prueba: ${e.toString()}'};
    }
  }

  // Obtener una cita específica por ID (con relación a user_doc)
  Future<Map<String, dynamic>?> getCitaPorId(String citaId) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .select('*, user_doc (*)')
          .eq('id', citaId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error al obtener cita: $e');
      return null;
    }
  }

  // Verificar disponibilidad de horario
  Future<bool> verificarDisponibilidad({
    required String doctor,
    required DateTime fecha,
    required String hora,
    String? citaIdExcluir, // Para excluir la cita actual al editar
  }) async {
    try {
      var query = _client
          .from('citas_medicas')
          .select('id')
          .eq('doctor', doctor)
          .eq('fecha', fecha.toIso8601String().split('T')[0])
          .eq('hora', hora);

      if (citaIdExcluir != null) {
        query = query.neq('id', citaIdExcluir);
      }

      final response = await query.maybeSingle();

      // Si no hay respuesta, el horario está disponible
      return response == null;
    } catch (e) {
      print('Error al verificar disponibilidad: $e');
      return false;
    }
  }

  // Obtener todas las citas médicas (sin filtro de fecha)
  Future<List<Map<String, dynamic>>> getTodasLasCitas({String? doctor}) async {
    try {
      final hasDoctor = doctor != null && doctor.trim().isNotEmpty;
      final response = hasDoctor
          ? await _client
                .from('citas_medicas')
                .select(
                  'id, fecha, hora, tipo_cita, usuario_id, doctor, usuarios (nombres, apellidos, cedula)',
                )
                .eq('doctor', doctor!.trim())
                .order('fecha', ascending: false)
                .order('hora', ascending: false)
          : await _client
                .from('citas_medicas')
                .select(
                  'id, fecha, hora, tipo_cita, usuario_id, doctor, usuarios (nombres, apellidos, cedula)',
                )
                .order('fecha', ascending: false)
                .order('hora', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener todas las citas: $e');
      // Fallback sin join
      try {
        final hasDoctor = doctor != null && doctor.trim().isNotEmpty;
        final responseFallback = hasDoctor
            ? await _client
                  .from('citas_medicas')
                  .select('*')
                  .eq('doctor', doctor!.trim())
                  .order('fecha', ascending: false)
                  .order('hora', ascending: false)
            : await _client
                  .from('citas_medicas')
                  .select('*')
                  .order('fecha', ascending: false)
                  .order('hora', ascending: false);
        return List<Map<String, dynamic>>.from(responseFallback);
      } catch (e2) {
        print('Error al obtener todas las citas (fallback): $e2');
        return [];
      }
    }
  }

  // Obtener todas las historias clínicas de un paciente
  Future<List<Map<String, dynamic>>> getHistoriasClinicasPaciente(
    String usuarioId,
  ) async {
    try {
      final response = await _client
          .from('user_doc')
          .select('*')
          .eq('usuario_id', usuarioId)
          .eq('tipo_documento', 'historia_clinica')
          .order('fecha_subida', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener historias clínicas del paciente: $e');
      return [];
    }
  }

  // Obtener todos los pacientes que tienen citas
  Future<List<Map<String, dynamic>>> getPacientesConCitas() async {
    try {
      final response = await _client
          .from('citas_medicas')
          .select('usuario_id, usuarios (id, nombres, apellidos, cedula)')
          .order('fecha', ascending: false);

      // Filtrar duplicados por usuario_id
      final Map<String, Map<String, dynamic>> pacientesUnicos = {};
      for (final item in response) {
        final usuarioId = item['usuario_id'] as String?;
        if (usuarioId != null) {
          final usuario = item['usuarios'];
          if (usuario is Map && !pacientesUnicos.containsKey(usuarioId)) {
            pacientesUnicos[usuarioId] = Map<String, dynamic>.from(usuario);
          }
        }
      }

      return pacientesUnicos.values.toList();
    } catch (e) {
      print('Error al obtener pacientes con citas: $e');
      // Fallback: obtener desde usuarios directamente
      try {
        final response = await _client
            .from('usuarios')
            .select('*')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (e2) {
        print('Error al obtener pacientes (fallback): $e2');
        return [];
      }
    }
  }

  // Cerrar sesión
  Future<void> cerrarSesion() async {
    try {
      await SessionService.instance.clearUser();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }

  // ========== FUNCIONES PARA PANEL MÉDICO ==========

  /// Obtiene un stream de citas médicas filtradas por doctor con información del paciente
  /// Utiliza Realtime de Supabase para actualizaciones en tiempo real
  /// Si doctor es null o vacío, retorna todas las citas
  Stream<List<Map<String, dynamic>>> streamCitasMedico(String? doctor) {
    try {
      Stream<List<Map<String, dynamic>>> stream;

      // Si hay filtro de doctor, aplicarlo
      if (doctor != null && doctor.trim().isNotEmpty) {
        stream = _client
            .from('citas_medicas')
            .stream(primaryKey: ['id'])
            .eq('doctor', doctor.trim())
            .order('fecha', ascending: false)
            .order('hora', ascending: false);
      } else {
        stream = _client
            .from('citas_medicas')
            .stream(primaryKey: ['id'])
            .order('fecha', ascending: false)
            .order('hora', ascending: false);
      }

      return stream.asyncMap((data) async {
        // Enriquecer con datos del paciente
        final List<Map<String, dynamic>> citasEnriquecidas = [];
        for (final cita in data) {
          try {
            final usuarioId = cita['usuario_id'] as String?;
            if (usuarioId != null) {
              final usuario = await _client
                  .from('usuarios')
                  .select('nombres, apellidos')
                  .eq('id', usuarioId)
                  .maybeSingle();
              if (usuario != null) {
                cita['usuarios'] = usuario;
              }
            }
            citasEnriquecidas.add(cita);
          } catch (e) {
            print('Error al enriquecer cita: $e');
            citasEnriquecidas.add(cita);
          }
        }
        return citasEnriquecidas;
      });
    } catch (e) {
      print('Error al crear stream de citas: $e');
      return Stream.value([]);
    }
  }

  /// Obtiene la URL del PDF más reciente de un paciente desde user_doc
  Future<String?> obtenerPdfUrlMasReciente(String usuarioId) async {
    try {
      final response = await _client
          .from('user_doc')
          .select('pdf_url')
          .eq('usuario_id', usuarioId)
          .order('fecha_subida', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['pdf_url'] != null) {
        return response['pdf_url'] as String;
      }
      return null;
    } catch (e) {
      print('Error al obtener PDF URL más reciente: $e');
      return null;
    }
  }

  /// Genera un signed URL para descargar un archivo desde Supabase Storage
  /// bucket: nombre del bucket (por defecto 'clinical_histories')
  /// path: ruta del archivo en el bucket
  /// expiresIn: tiempo de expiración en segundos (por defecto 3600 = 1 hora)
  Future<String?> generarSignedUrl({
    required String path,
    String bucket = 'clinical_histories',
    int expiresIn = 3600,
  }) async {
    // Extraer el path del archivo desde la URL completa si es necesario
    String filePath = path;
    if (path.contains('/storage/v1/object/public/')) {
      // Es una URL pública, extraer el path
      final uri = Uri.parse(path);
      filePath = uri.pathSegments.last;
    } else if (path.contains('/storage/v1/object/sign/')) {
      // Ya es un signed URL, retornarlo
      return path;
    }

    try {
      // Generar signed URL
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(filePath, expiresIn);

      return signedUrl;
    } catch (e) {
      print('Error al generar signed URL: $e');
      // Si falla, intentar usar la URL pública directamente
      try {
        final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
        return publicUrl;
      } catch (e2) {
        print('Error al obtener URL pública: $e2');
        return null;
      }
    }
  }

  /// Descarga un PDF desde una URL y lo convierte a Base64
  Future<String> descargarPdfABase64(String pdfUrl) async {
    try {
      // Si es una URL de Supabase Storage, intentar generar signed URL primero
      String urlFinal = pdfUrl;
      if (pdfUrl.contains('supabase') || pdfUrl.contains('storage')) {
        // Intentar obtener signed URL
        final signedUrl = await generarSignedUrl(path: pdfUrl);
        if (signedUrl != null) {
          urlFinal = signedUrl;
        }
      }

      // Descargar el PDF
      final response = await http.get(Uri.parse(urlFinal));
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar el PDF: ${response.statusCode}');
      }

      // Convertir a Base64
      final base64 = base64Encode(response.bodyBytes);
      return base64;
    } catch (e) {
      throw Exception('Error al descargar PDF y convertir a Base64: $e');
    }
  }
}
