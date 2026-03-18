import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String nombre;
  final String apellido;
  final String telefono;
  final String rol;
  final String? fotoPerfil;
  final bool activo;
  final DateTime createdAt;
  final GeoPoint? ubicacionDefecto;

  // Technician-specific fields
  final List<String>? especialidades;
  final double? calificacionPromedio;
  final int? totalResenas;
  final Map<String, double>? tarifasPorEspecialidad;
  final bool? disponible;
  final Map<String, Map<String, String>>? horarioDisponible;
  final int? serviciosCompletados;
  final DateTime? ultimaAsignacion;

  const UserModel({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.rol,
    this.fotoPerfil,
    this.activo = true,
    required this.createdAt,
    this.ubicacionDefecto,
    this.especialidades,
    this.calificacionPromedio,
    this.totalResenas,
    this.tarifasPorEspecialidad,
    this.disponible,
    this.horarioDisponible,
    this.serviciosCompletados,
    this.ultimaAsignacion,
  });

  bool get isClient => rol == 'cliente';
  bool get isTechnician => rol == 'tecnico';
  bool get isAdmin => rol == 'admin';

  String get fullName => '$nombre $apellido';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      nombre: data['nombre'] ?? '',
      apellido: data['apellido'] ?? '',
      telefono: data['telefono'] ?? '',
      rol: data['rol'] ?? 'cliente',
      fotoPerfil: data['fotoPerfil'],
      activo: data['activo'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ubicacionDefecto: data['ubicacionDefecto'] as GeoPoint?,
      especialidades: data['especialidades'] != null
          ? List<String>.from(data['especialidades'])
          : null,
      calificacionPromedio: (data['calificacionPromedio'] as num?)?.toDouble(),
      totalResenas: data['totalResenas'] as int?,
      tarifasPorEspecialidad: data['tarifasPorEspecialidad'] != null
          ? Map<String, double>.from(
              (data['tarifasPorEspecialidad'] as Map).map(
                (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : null,
      disponible: data['disponible'] as bool?,
      horarioDisponible: data['horarioDisponible'] != null
          ? (data['horarioDisponible'] as Map).map(
              (key, value) => MapEntry(
                key.toString(),
                Map<String, String>.from(value as Map),
              ),
            )
          : null,
      serviciosCompletados: data['serviciosCompletados'] as int?,
      ultimaAsignacion:
          (data['ultimaAsignacion'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'email': email,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'rol': rol,
      'activo': activo,
      'createdAt': Timestamp.fromDate(createdAt),
    };

    if (fotoPerfil != null) map['fotoPerfil'] = fotoPerfil;
    if (ubicacionDefecto != null) map['ubicacionDefecto'] = ubicacionDefecto;

    // Technician fields
    if (rol == 'tecnico') {
      map['especialidades'] = especialidades ?? [];
      map['calificacionPromedio'] = calificacionPromedio ?? 0.0;
      map['totalResenas'] = totalResenas ?? 0;
      map['tarifasPorEspecialidad'] = tarifasPorEspecialidad ?? {};
      map['disponible'] = disponible ?? true;
      map['horarioDisponible'] = horarioDisponible ?? {};
      map['serviciosCompletados'] = serviciosCompletados ?? 0;
      if (ultimaAsignacion != null) {
        map['ultimaAsignacion'] = Timestamp.fromDate(ultimaAsignacion!);
      }
    }

    return map;
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? nombre,
    String? apellido,
    String? telefono,
    String? rol,
    String? fotoPerfil,
    bool? activo,
    DateTime? createdAt,
    GeoPoint? ubicacionDefecto,
    List<String>? especialidades,
    double? calificacionPromedio,
    int? totalResenas,
    Map<String, double>? tarifasPorEspecialidad,
    bool? disponible,
    Map<String, Map<String, String>>? horarioDisponible,
    int? serviciosCompletados,
    DateTime? ultimaAsignacion,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      fotoPerfil: fotoPerfil ?? this.fotoPerfil,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      ubicacionDefecto: ubicacionDefecto ?? this.ubicacionDefecto,
      especialidades: especialidades ?? this.especialidades,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      totalResenas: totalResenas ?? this.totalResenas,
      tarifasPorEspecialidad:
          tarifasPorEspecialidad ?? this.tarifasPorEspecialidad,
      disponible: disponible ?? this.disponible,
      horarioDisponible: horarioDisponible ?? this.horarioDisponible,
      serviciosCompletados: serviciosCompletados ?? this.serviciosCompletados,
      ultimaAsignacion: ultimaAsignacion ?? this.ultimaAsignacion,
    );
  }

  @override
  List<Object?> get props => [
        uid, email, nombre, apellido, telefono, rol, fotoPerfil,
        activo, createdAt, ubicacionDefecto, especialidades,
        calificacionPromedio, totalResenas, tarifasPorEspecialidad,
        disponible, horarioDisponible, serviciosCompletados,
        ultimaAsignacion,
      ];
}
