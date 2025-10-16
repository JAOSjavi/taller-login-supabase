class CitaMedica {
  final String id;
  final String usuarioId;
  final String tipoCita;
  final String doctor;
  final DateTime fecha;
  final String hora;
  final String pdfUrl;
  final DateTime createdAt;

  CitaMedica({
    required this.id,
    required this.usuarioId,
    required this.tipoCita,
    required this.doctor,
    required this.fecha,
    required this.hora,
    required this.pdfUrl,
    required this.createdAt,
  });

  factory CitaMedica.fromJson(Map<String, dynamic> json) {
    return CitaMedica(
      id: json['id'] ?? '',
      usuarioId: json['usuario_id'] ?? '',
      tipoCita: json['tipo_cita'] ?? '',
      doctor: json['doctor'] ?? '',
      fecha: DateTime.parse(json['fecha'] ?? DateTime.now().toIso8601String()),
      hora: json['hora'] ?? '',
      pdfUrl: json['pdf_url'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'tipo_cita': tipoCita,
      'doctor': doctor,
      'fecha': fecha.toIso8601String().split('T')[0],
      'hora': hora,
      'pdf_url': pdfUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get fechaFormateada {
    final meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }
}
