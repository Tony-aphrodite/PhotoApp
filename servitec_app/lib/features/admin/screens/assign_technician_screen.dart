import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../../data/repositories/user_repository.dart';

class AssignTechnicianScreen extends StatelessWidget {
  final String serviceId;

  const AssignTechnicianScreen({super.key, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar Técnico'),
      ),
      body: FutureBuilder<ServiceModel>(
        future: context.read<ServiceRepository>().getService(serviceId),
        builder: (context, serviceSnapshot) {
          if (!serviceSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final service = serviceSnapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.titulo, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${AppConstants.categoryIcons[service.categoria] ?? ''} ${AppConstants.categoryLabels[service.categoria] ?? service.categoria}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.ubicacionTexto,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Técnicos Disponibles',
                  style: theme.textTheme.titleMedium,
                ),
              ),

              // Technician list
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: context
                      .read<UserRepository>()
                      .getAvailableTechnicians(
                          especialidad: service.categoria),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final technicians = snapshot.data ?? [];

                    if (technicians.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 64, color: AppTheme.textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              'No hay técnicos disponibles\npara ${AppConstants.categoryLabels[service.categoria]}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: technicians.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tech = technicians[index];
                        return _TechnicianCard(
                          technician: tech,
                          onAssign: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar Asignación'),
                                content: Text(
                                  '¿Asignar a ${tech.fullName} para este servicio?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, true),
                                    child: const Text('Asignar'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true && context.mounted) {
                              await context
                                  .read<ServiceRepository>()
                                  .assignTechnician(
                                    serviceId: serviceId,
                                    technicianId: tech.uid,
                                    technicianName: tech.fullName,
                                    assignmentType: AppConstants.assignmentAdmin,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Técnico ${tech.fullName} asignado',
                                    ),
                                    backgroundColor: AppTheme.successColor,
                                  ),
                                );
                                context.pop();
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final UserModel technician;
  final VoidCallback onAssign;

  const _TechnicianCard({
    required this.technician,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                technician.nombre.isNotEmpty
                    ? technician.nombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    technician.fullName,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${technician.calificacionPromedio?.toStringAsFixed(1) ?? '0.0'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' (${technician.totalResenas ?? 0})',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.handyman,
                          size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${technician.serviciosCompletados ?? 0} servicios',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (technician.especialidades != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: technician.especialidades!
                          .take(3)
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppConstants.categoryLabels[e] ?? e,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Assign button
            ElevatedButton(
              onPressed: onAssign,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );
  }
}
