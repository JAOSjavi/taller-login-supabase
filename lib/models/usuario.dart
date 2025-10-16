class Usuario {
  final String id;
  final String nombres;
  final String apellidos;
  final String cedula;
  final String eps;
  final DateTime createdAt;

  Usuario({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.cedula,
    required this.eps,
    required this.createdAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] ?? '',
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      cedula: json['cedula'] ?? '',
      eps: json['eps'] ?? '',
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombres': nombres,
      'apellidos': apellidos,
      'cedula': cedula,
      'eps': eps,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get nombreCompleto => '$nombres $apellidos';
}
