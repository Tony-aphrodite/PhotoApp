import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'facturapi_ref.dart';

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

  // Stripe Connect — reserved for future direct payout integration
  final String? stripeConnectAccountId;

  // FCM token for push notifications
  final String? fcmToken;

  // Technician fiscal / CFDI fields — Phase 2 (see project_servitec_fiscal_model)
  final String? rfc;
  final String? razonSocial;
  final String? regimenFiscal; // SAT code, e.g. "626" (RESICO), "612" (Actividad Empresarial)
  final String? codigoPostalFiscal;
  final FacturapiRef? facturapi;
  final DateTime? graciaExpiraAt;

  /// Timestamp when the user acknowledged the off-platform disclosure modal
  /// shown once on first authenticated launch. Null = has not seen it yet.
  final DateTime? disclosureAcceptedAt;

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
    this.stripeConnectAccountId,
    this.fcmToken,
    this.rfc,
    this.razonSocial,
    this.regimenFiscal,
    this.codigoPostalFiscal,
    this.facturapi,
    this.graciaExpiraAt,
    this.disclosureAcceptedAt,
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
      stripeConnectAccountId: data['stripeConnectAccountId'] as String?,
      fcmToken: data['fcmToken'] as String?,
      rfc: data['rfc'] as String?,
      razonSocial: data['razonSocial'] as String?,
      regimenFiscal: data['regimenFiscal'] as String?,
      codigoPostalFiscal: data['codigoPostalFiscal'] as String?,
      facturapi: data['facturapi'] != null
          ? FacturapiRef.fromMap(Map<String, dynamic>.from(data['facturapi'] as Map))
          : null,
      graciaExpiraAt: (data['graciaExpiraAt'] as Timestamp?)?.toDate(),
      disclosureAcceptedAt:
          (data['disclosureAcceptedAt'] as Timestamp?)?.toDate(),
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
      if (stripeConnectAccountId != null) {
        map['stripeConnectAccountId'] = stripeConnectAccountId;
      }
    }

    if (fcmToken != null) map['fcmToken'] = fcmToken;

    // Fiscal fields — both técnicos and clientes may have these:
    //   - Técnicos: required to emit CFDIs (they're the emisor).
    //   - Clientes: optional. If absent, CFDI receptor defaults to
    //     "público en general" (RFC XAXX010101000, régimen 616) in the
    //     Cloud Function that stamps the CFDI.
    if (rfc != null) map['rfc'] = rfc;
    if (razonSocial != null) map['razonSocial'] = razonSocial;
    if (regimenFiscal != null) map['regimenFiscal'] = regimenFiscal;
    if (codigoPostalFiscal != null) {
      map['codigoPostalFiscal'] = codigoPostalFiscal;
    }
    // FacturAPI org + grace period are técnico-only (they're the emisor
    // machinery).
    if (rol == 'tecnico') {
      if (facturapi != null) map['facturapi'] = facturapi!.toMap();
      if (graciaExpiraAt != null) {
        map['graciaExpiraAt'] = Timestamp.fromDate(graciaExpiraAt!);
      }
    }

    if (disclosureAcceptedAt != null) {
      map['disclosureAcceptedAt'] = Timestamp.fromDate(disclosureAcceptedAt!);
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
    String? stripeConnectAccountId,
    String? fcmToken,
    String? rfc,
    String? razonSocial,
    String? regimenFiscal,
    String? codigoPostalFiscal,
    FacturapiRef? facturapi,
    DateTime? graciaExpiraAt,
    DateTime? disclosureAcceptedAt,
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
      stripeConnectAccountId:
          stripeConnectAccountId ?? this.stripeConnectAccountId,
      fcmToken: fcmToken ?? this.fcmToken,
      rfc: rfc ?? this.rfc,
      razonSocial: razonSocial ?? this.razonSocial,
      regimenFiscal: regimenFiscal ?? this.regimenFiscal,
      codigoPostalFiscal: codigoPostalFiscal ?? this.codigoPostalFiscal,
      facturapi: facturapi ?? this.facturapi,
      graciaExpiraAt: graciaExpiraAt ?? this.graciaExpiraAt,
      disclosureAcceptedAt:
          disclosureAcceptedAt ?? this.disclosureAcceptedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid, email, nombre, apellido, telefono, rol, fotoPerfil,
        activo, createdAt, ubicacionDefecto, especialidades,
        calificacionPromedio, totalResenas, tarifasPorEspecialidad,
        disponible, horarioDisponible, serviciosCompletados,
        ultimaAsignacion, stripeConnectAccountId, fcmToken,
        rfc, razonSocial, regimenFiscal, codigoPostalFiscal,
        facturapi, graciaExpiraAt, disclosureAcceptedAt,
      ];
}
