import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Reference to the technician's FacturAPI organization + CSD lifecycle state.
///
/// Stored as a nested map under the user document (field key: `facturapi`).
/// Raw CSD material is NEVER stored on our servers — only the `organizationId`
/// returned by FacturAPI after we forward the .cer/.key/password to their
/// organization-credentials endpoint. See project_servitec_fiscal_model in memory.
class FacturapiRef extends Equatable {
  /// Waiting for the technician to upload their CSD.
  static const String statusPendingCsd = 'pending_csd';

  /// CSD not yet uploaded but within the grace window; technician can still work.
  static const String statusGracePeriod = 'grace_period';

  /// CSD uploaded, FacturAPI organization active, ready to issue CFDIs.
  static const String statusActive = 'active';

  /// Grace expired without a valid CSD, or admin-suspended.
  static const String statusSuspended = 'suspended';

  final String? organizationId;
  final DateTime? csdUploadedAt;
  final DateTime? csdExpiresAt;
  final String status;

  const FacturapiRef({
    this.organizationId,
    this.csdUploadedAt,
    this.csdExpiresAt,
    this.status = statusPendingCsd,
  });

  bool get isActive => status == statusActive;
  bool get isSuspended => status == statusSuspended;
  bool get canIssueCfdi => status == statusActive;
  bool get isInGrace => status == statusGracePeriod;

  factory FacturapiRef.fromMap(Map<String, dynamic> data) {
    return FacturapiRef(
      organizationId: data['organizationId'] as String?,
      csdUploadedAt: (data['csdUploadedAt'] as Timestamp?)?.toDate(),
      csdExpiresAt: (data['csdExpiresAt'] as Timestamp?)?.toDate(),
      status: data['status'] as String? ?? statusPendingCsd,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'status': status};
    if (organizationId != null) map['organizationId'] = organizationId;
    if (csdUploadedAt != null) {
      map['csdUploadedAt'] = Timestamp.fromDate(csdUploadedAt!);
    }
    if (csdExpiresAt != null) {
      map['csdExpiresAt'] = Timestamp.fromDate(csdExpiresAt!);
    }
    return map;
  }

  FacturapiRef copyWith({
    String? organizationId,
    DateTime? csdUploadedAt,
    DateTime? csdExpiresAt,
    String? status,
  }) =>
      FacturapiRef(
        organizationId: organizationId ?? this.organizationId,
        csdUploadedAt: csdUploadedAt ?? this.csdUploadedAt,
        csdExpiresAt: csdExpiresAt ?? this.csdExpiresAt,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [organizationId, csdUploadedAt, csdExpiresAt, status];
}
