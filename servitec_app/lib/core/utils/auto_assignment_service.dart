import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/user_model.dart';
import '../../data/models/service_model.dart';
import '../constants/app_constants.dart';

class AutoAssignmentService {
  final FirebaseFirestore _firestore;

  AutoAssignmentService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Find and assign the best technician for a service automatically
  /// Criteria: specialty match, availability, rating (desc), workload (asc), proximity
  Future<UserModel?> autoAssign(ServiceModel service) async {
    // 1. Get available technicians with matching specialty
    final techSnap = await _firestore
        .collection(AppConstants.usersCollection)
        .where('rol', isEqualTo: AppConstants.roleTechnician)
        .where('disponible', isEqualTo: true)
        .where('activo', isEqualTo: true)
        .where('especialidades', arrayContains: service.categoria)
        .get();

    if (techSnap.docs.isEmpty) return null;

    final technicians =
        techSnap.docs.map((d) => UserModel.fromFirestore(d)).toList();

    // 2. Get current workload (active services) for each technician
    final workloads = <String, int>{};
    for (final tech in technicians) {
      final activeSnap = await _firestore
          .collection(AppConstants.servicesCollection)
          .where('tecnicoId', isEqualTo: tech.uid)
          .where('estado', whereIn: [
            AppConstants.statusAssigned,
            AppConstants.statusInProgress,
          ])
          .get();
      workloads[tech.uid] = activeSnap.docs.length;
    }

    // 3. Score each technician
    final scored = technicians.map((tech) {
      double score = 0;

      // Rating (0-5, normalized to 0-40 points)
      score += (tech.calificacionPromedio ?? 0) * 8;

      // Workload penalty (fewer active = better, max 30 points)
      final workload = workloads[tech.uid] ?? 0;
      score += max(0, 30 - (workload * 10)).toDouble();

      // Proximity bonus (max 20 points)
      if (tech.ubicacionDefecto != null) {
        final distance = _calculateDistance(
          service.ubicacion.latitude,
          service.ubicacion.longitude,
          tech.ubicacionDefecto!.latitude,
          tech.ubicacionDefecto!.longitude,
        );
        score += max(0, 20 - distance).toDouble(); // 1 point per km closer
      }

      // Experience bonus (max 10 points)
      final completed = tech.serviciosCompletados ?? 0;
      score += min(10, completed).toDouble();

      return _ScoredTechnician(technician: tech, score: score);
    }).toList();

    // 4. Sort by score descending
    scored.sort((a, b) => b.score.compareTo(a.score));

    // 5. Assign the best technician
    final bestTech = scored.first.technician;

    await _firestore
        .collection(AppConstants.servicesCollection)
        .doc(service.id)
        .update({
      'tecnicoId': bestTech.uid,
      'tecnicoNombre': bestTech.fullName,
      'estado': AppConstants.statusAssigned,
      'tipoAsignacion': AppConstants.assignmentAutomatic,
      'asignadoAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    return bestTech;
  }

  /// Haversine distance in km
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;
}

class _ScoredTechnician {
  final UserModel technician;
  final double score;

  _ScoredTechnician({required this.technician, required this.score});
}
