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

  // Cerrar sesión
  Future<void> cerrarSesion() async {
    try {
      await SessionService.instance.clearUser();
    } catch (e) {
      print('Error al cerrar sesión: $e');
    }
  }
}
