import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// The sensitive contact fields for a service, stored in a **separate**
/// subcollection so Firestore rules can gate reads independently of the
/// service body itself.
///
/// Path: `servicios/{serviceId}/private/contact`
///
/// Rules only allow reads when the requester is admin OR the assigned técnico
/// AND the service is far enough along the lifecycle to warrant a real phone
/// (see `firestore.rules` → `/servicios/{sid}/private/{doc}`). The client
/// still applies [PhoneVisibility] on top for the UI mask, but the underlying
/// data is now protected by the rules engine, not by "please don't peek".
class ServicePrivateContact extends Equatable {
  final String telefonoCliente;
  final DateTime? createdAt;

  const ServicePrivateContact({
    required this.telefonoCliente,
    this.createdAt,
  });

  factory ServicePrivateContact.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return ServicePrivateContact(
      telefonoCliente: (data['telefonoCliente'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'telefonoCliente': telefonoCliente,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  @override
  List<Object?> get props => [telefonoCliente, createdAt];
}
