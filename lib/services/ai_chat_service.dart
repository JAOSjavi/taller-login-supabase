import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  ///
  /// [pdfBase64Content]: Contenido del PDF codificado en Base64
  /// [userQuery]: Pregunta del doctor sobre el paciente
  /// [mimeType]: Tipo MIME del archivo (debe ser "application/pdf")
  ///
  /// Retorna la respuesta de la IA como String
  Future<String> getClinicalInsight({
    required String pdfBase64Content,
    required String userQuery,
    String mimeType = 'application/pdf',
  }) async {
    try {
      await _initialize();

      if (_apiKey == null) {
        throw Exception('API Key de Gemini no configurada');
      }

      // URL de la API de Gemini
      final apiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$_apiKey';

      // Nota: Si el modelo gemini-2.5-flash-preview-09-2025 está disponible,
      // cambiar el modelo en la URL anterior

      // Construir el payload multimodal
      final payload = {
        'contents': [
          {
            'parts': [
              // Parte 1: System instruction
              {
                'text':
                    'Eres un asistente médico experto. Responde preguntas únicamente basándote en la Historia Clínica (PDF) proporcionada. '
                    'Sé preciso, profesional y conciso. Si la información no está disponible en el PDF, indica claramente que no puedes responder basándote en el documento proporcionado.',
              },
              // Parte 2: Pregunta del usuario
              {'text': userQuery},
              // Parte 3: PDF en Base64
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

      // Realizar la petición POST
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error en la API de Gemini: ${response.statusCode} - ${response.body}',
        );
      }

      // Parsear la respuesta
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      // Extraer el texto de la respuesta
      if (responseData.containsKey('candidates') &&
          (responseData['candidates'] as List).isNotEmpty) {
        final candidate = responseData['candidates'][0] as Map<String, dynamic>;
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
        final feedback = responseData['promptFeedback'] as Map<String, dynamic>;
        if (feedback.containsKey('blockReason')) {
          throw Exception(
            'La consulta fue bloqueada por seguridad: ${feedback['blockReason']}',
          );
        }
      }

      throw Exception('No se pudo obtener una respuesta válida de la IA');
    } catch (e) {
      throw Exception('Error al obtener insight clínico: ${e.toString()}');
    }
  }
}
