import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:typed_data';
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

  // Obtener datos del usuario actual
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
          .uploadBinary(nombreArchivo, bytes);

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
          .uploadBinary(nombreArchivo, bytes);

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

  // Agendar cita médica
  Future<Map<String, dynamic>> agendarCita({
    required String usuarioId,
    required String tipoCita,
    required String doctor,
    required DateTime fecha,
    required String hora,
    required String pdfUrl,
  }) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .insert({
            'usuario_id': usuarioId,
            'tipo_cita': tipoCita,
            'doctor': doctor,
            'fecha': fecha.toIso8601String().split('T')[0], // Solo la fecha
            'hora': hora,
            'pdf_url': pdfUrl,
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
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener citas con paciente en rango: $e');
      return [];
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

  // Obtener una cita específica por ID
  Future<Map<String, dynamic>?> getCitaPorId(String citaId) async {
    try {
      final response = await _client
          .from('citas_medicas')
          .select('*')
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

  // Cerrar sesión
  Future<void> cerrarSesion() async {
    try {
      await SessionService.instance.clearUser();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }
}
