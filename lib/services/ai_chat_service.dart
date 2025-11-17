import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// Servicio para interactuar con la API de Google Gemini de forma multimodal
/// Permite enviar consultas junto con PDFs codificados en Base64
class AIChatService {
  static AIChatService? _instance;
  static AIChatService get instance => _instance ??= AIChatService._();

  AIChatService._();

  String? _apiKey;

  Future<void> _initialize() async {
    if (_apiKey != null) return;

    await dotenv.load(fileName: ".env");
    _apiKey = dotenv.env['GEMINI_API_KEY'];

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('GEMINI_API_KEY no está configurada en el archivo .env');
    }
  }

  /// Obtiene insights clínicos de un PDF usando la API de Gemini
  /// Implementa reintentos automáticos con backoff exponencial para errores 503
  ///
  /// [pdfBase64Content]: Contenido del PDF codificado en Base64
  /// [userQuery]: Pregunta del doctor sobre el paciente
  /// [mimeType]: Tipo MIME del archivo (debe ser "application/pdf")
  /// [maxRetries]: Número máximo de reintentos (por defecto 3)
  ///
  /// Retorna la respuesta de la IA como String
  Future<String> getClinicalInsight({
    required String pdfBase64Content,
    required String userQuery,
    String mimeType = 'application/pdf',
    int maxRetries = 3,
  }) async {
    await _initialize();

    if (_apiKey == null) {
      throw Exception('API Key de Gemini no configurada');
    }

    // URL de la API de Gemini
    final apiUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-09-2025:generateContent?key=$_apiKey';

    // Construir el payload multimodal con estructura correcta
    // La instrucción del sistema debe estar en systemInstruction (nivel superior)
    // El array contents solo debe contener el mensaje del usuario y el PDF
    final payload = {
      'systemInstruction': {
        'parts': [
          {
            'text':
                'Eres un asistente médico experto. Responde preguntas únicamente basándote en la Historia Clínica (PDF) proporcionada. '
                'Sé preciso, profesional y conciso. Si la información no está disponible en el PDF, indica claramente que no puedes responder basándote en el documento proporcionado.',
          },
        ],
      },
      'contents': [
        {
          'parts': [
            // Parte 1: Pregunta del usuario
            {'text': userQuery},
            // Parte 2: PDF en Base64
            {
              'inlineData': {'mimeType': mimeType, 'data': pdfBase64Content},
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.3, // Baja temperatura para respuestas más precisas
        'topK': 40,
        'topP': 0.95,
        'maxOutputTokens': 2048,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
        },
      ],
    };

    // Reintentos con backoff exponencial
    Exception? lastException;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        // Realizar la petición POST
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        // Si es éxito, procesar respuesta
        if (response.statusCode == 200) {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;

          // Extraer el texto de la respuesta
          if (responseData.containsKey('candidates') &&
              (responseData['candidates'] as List).isNotEmpty) {
            final candidate =
                responseData['candidates'][0] as Map<String, dynamic>;
            if (candidate.containsKey('content')) {
              final content = candidate['content'] as Map<String, dynamic>;
              if (content.containsKey('parts') &&
                  (content['parts'] as List).isNotEmpty) {
                final part = content['parts'][0] as Map<String, dynamic>;
                if (part.containsKey('text')) {
                  return part['text'] as String;
                }
              }
            }
          }

          // Verificar si hay bloqueos de seguridad
          if (responseData.containsKey('promptFeedback')) {
            final feedback =
                responseData['promptFeedback'] as Map<String, dynamic>;
            if (feedback.containsKey('blockReason')) {
              throw Exception(
                'La consulta fue bloqueada por seguridad: ${feedback['blockReason']}',
              );
            }
          }

          throw Exception('No se pudo obtener una respuesta válida de la IA');
        }

        // Manejar errores 503 (servicio sobrecargado)
        if (response.statusCode == 503) {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorData['error'] as Map<String, dynamic>?;
          final status = error?['status'] as String?;

          if (status == 'UNAVAILABLE' || status == 'RESOURCE_EXHAUSTED') {
            // Si no es el último intento, esperar y reintentar
            if (attempt < maxRetries) {
              final waitTime = Duration(seconds: (2 * (attempt + 1)));
              print(
                'Servicio sobrecargado (503). Reintentando en ${waitTime.inSeconds} segundos... (Intento ${attempt + 1}/$maxRetries)',
              );
              await Future.delayed(waitTime);
              continue; // Reintentar
            } else {
              // Último intento fallido
              throw Exception(
                'El servicio de IA está temporalmente sobrecargado. Por favor, intenta de nuevo en unos minutos.',
              );
            }
          }
        }

        // Otros errores HTTP
        throw Exception(
          'Error en la API de Gemini: ${response.statusCode} - ${response.body}',
        );
      } catch (e) {
        lastException = e is Exception
            ? e
            : Exception('Error inesperado: ${e.toString()}');

        // Si no es un error 503 o es el último intento, lanzar el error
        if (attempt == maxRetries || !e.toString().contains('503')) {
          break;
        }
      }
    }

    // Si llegamos aquí, todos los reintentos fallaron
    throw lastException ??
        Exception(
          'Error al obtener insight clínico después de $maxRetries intentos',
        );
  }
}
