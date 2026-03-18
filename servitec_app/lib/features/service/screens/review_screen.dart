import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/review_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ReviewScreen extends StatefulWidget {
  final String serviceId;

  const ReviewScreen({super.key, required this.serviceId});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _submitting = false;
  ServiceModel? _service;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    final service =
        await context.read<ServiceRepository>().getService(widget.serviceId);
    if (mounted) setState(() => _service = service);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_service == null || _service!.tecnicoId == null) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    setState(() => _submitting = true);

    try {
      final review = ReviewModel(
        id: '',
        servicioId: _service!.id,
        clienteId: authState.user.uid,
        tecnicoId: _service!.tecnicoId!,
        calificacion: _rating,
        comentario: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save review
      await FirebaseFirestore.instance
          .collection('resenas')
          .add(review.toFirestore());

      // Update technician rating
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('resenas')
          .where('tecnicoId', isEqualTo: _service!.tecnicoId)
          .get();

      double totalRating = 0;
      for (final doc in reviewsSnap.docs) {
        totalRating += (doc.data()['calificacion'] as num).toDouble();
      }
      final avgRating = totalRating / reviewsSnap.docs.length;

      await context.read<UserRepository>().updateTechnicianRating(
            _service!.tecnicoId!,
            newRating: avgRating,
            totalReviews: reviewsSnap.docs.length,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reseña enviada. ¡Gracias!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar Servicio')),
      body: _service == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Service info
                  Text(_service!.titulo, style: theme.textTheme.titleLarge),
                  if (_service!.tecnicoNombre != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Técnico: ${_service!.tecnicoNombre}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Star rating
                  Text('¿Cómo calificarías el servicio?',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () => setState(() => _rating = index + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            size: 48,
                            color: Colors.amber,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ratingLabel(_rating),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Comment
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      hintText: 'Cuéntanos sobre tu experiencia...',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Enviar Reseña'),
                  ),
                ],
              ),
            ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}
