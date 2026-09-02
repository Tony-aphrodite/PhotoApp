import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';
import '../../../data/repositories/review_repository.dart';

/// Every review on the platform, with the option to remove one.
///
/// Reviews carry only ids, so the técnico and cliente names are resolved here
/// and cached for the life of the screen — one read per distinct user, not
/// one per row per rebuild. Admin may read any user document by rules.
///
/// Deleting a review is enough: the `onReviewWritten` Cloud Function sees the
/// delete and recomputes the técnico's average. Nothing else to do here.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  late final Stream<List<ReviewModel>> _stream;
  final Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    _stream = context.read<ReviewRepository>().streamAll();
  }

  Future<String> _name(String uid) async {
    if (uid.isEmpty) return '—';
    final cached = _names[uid];
    if (cached != null) return cached;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final d = doc.data();
    final n = d == null
        ? uid
        : '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
    _names[uid] = n.isEmpty ? uid : n;
    return _names[uid]!;
  }

  Future<void> _delete(ReviewModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text('Eliminar reseña',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text(
          'Se eliminará de forma permanente y la calificación del técnico se recalculará automáticamente.',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ReviewRepository>().delete(r.id);
      messenger.showSnackBar(const SnackBar(
        content: Text('Reseña eliminada.'),
        backgroundColor: AppTheme.successColor,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo eliminar: $e'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Calificaciones',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final reviews = snapshot.data ?? const <ReviewModel>[];
          if (reviews.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay reseñas',
                style: GoogleFonts.plusJakartaSans(color: AppTheme.textTertiary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ReviewCard(
              review: reviews[i],
              nameOf: _name,
              onDelete: () => _delete(reviews[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final Future<String> Function(String uid) nameOf;
  final VoidCallback onDelete;

  const _ReviewCard({required this.review, required this.nameOf, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                    i < review.calificacion ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: Colors.amber,
                  )),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(review.createdAt),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textTertiary),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppTheme.errorColor,
                tooltip: 'Eliminar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (review.comentario.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comentario,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          FutureBuilder<List<String>>(
            future: Future.wait([nameOf(review.tecnicoId), nameOf(review.clienteId)]),
            builder: (context, snap) {
              final tec = snap.data?[0] ?? '…';
              final cli = snap.data?[1] ?? '…';
              return Text(
                'Técnico: $tec   ·   Cliente: $cli',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppTheme.textSecondary),
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/service/${review.servicioId}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ver servicio'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
