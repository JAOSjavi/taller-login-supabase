import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static GeminiService? _instance;
  static GeminiService get instance => _instance ??= GeminiService._();

  GeminiService._();

  GenerativeModel? _model;
  GenerativeModel? _chatModel;

  Future<void> _initialize() async {
    if (_model != null && _chatModel != null) return;

    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.env['GEMINI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY no está configurada en el archivo .env');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash-preview-09-2025',
      apiKey: apiKey,
    );

    _chatModel = GenerativeModel(
      model: 'gemini-2.5-flash-preview-09-2025',
      apiKey: apiKey,
    );
  }

  /// Extrae texto de un PDF desde una URL
  Future<String> extraerTextoDePDF(String pdfUrl) async {
    try {
      await _initialize();

      if (_model == null) {
        throw Exception('Modelo de Gemini no inicializado');
      }

      // Descargar el PDF
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('No se pudo descargar el PDF: ${response.statusCode}');
      }

      final pdfBytes = response.bodyBytes;

      // Usar Gemini para leer el PDF
      final prompt =
          'Por favor, extrae y resume toda la información relevante de esta historia clínica. '
          'Incluye: datos del paciente, diagnósticos, tratamientos, medicamentos, alergias, '
          'antecedentes médicos, y cualquier otra información médica importante.';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('application/pdf', pdfBytes),
        ]),
      ];

      final result = await _model!.generateContent(content);
      final text = result.text;

      if (text == null || text.isEmpty) {
        throw Exception('No se pudo extraer texto del PDF');
      }

      return text;
    } catch (e) {
      throw Exception('Error al extraer texto del PDF: ${e.toString()}');
    }
  }

  /// Crea un chatbot con el contexto de la historia clínica
  Future<ChatSession> crearChatbotConHistoriaClinica(
    String historiaClinicaTexto,
  ) async {
    try {
      await _initialize();

      if (_chatModel == null) {
        throw Exception('Modelo de chat no inicializado');
      }

      // Crear el chat con el contexto inicial
      final chat = _chatModel!.startChat(
        history: [
          Content.model([
            TextPart(
              'Historia clínica del paciente:\n\n$historiaClinicaTexto\n\n'
              'Ahora puedes responder preguntas sobre este paciente basándote en su historia clínica. '
              'Sé preciso, profesional y conciso en tus respuestas.',
            ),
          ]),
        ],
      );

      return chat;
    } catch (e) {
      throw Exception('Error al crear chatbot: ${e.toString()}');
    }
  }

  /// Envía un mensaje al chatbot y obtiene la respuesta
  Future<String> enviarMensaje(ChatSession chat, String mensaje) async {
    try {
      final response = await chat.sendMessage(Content.text(mensaje));
      final text = response.text;

      if (text == null || text.isEmpty) {
        return 'Lo siento, no pude generar una respuesta. Por favor, intenta reformular tu pregunta.';
      }

      return text;
    } catch (e) {
      return 'Error al procesar la pregunta: ${e.toString()}';
    }
  }
}
