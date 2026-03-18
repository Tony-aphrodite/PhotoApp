import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';

class AdminTechniciansScreen extends StatelessWidget {
  const AdminTechniciansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Técnicos')),
      body: StreamBuilder<List<UserModel>>(
        stream: context.read<UserRepository>().getAllTechnicians(),
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
                  Icon(Icons.engineering_outlined,
                      size: 64, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'No hay técnicos registrados',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: technicians.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tech = technicians[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: Text(
                          tech.nombre.isNotEmpty
                              ? tech.nombre[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(tech.fullName,
                                    style: theme.textTheme.titleSmall),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: (tech.disponible ?? false)
                                        ? AppTheme.successColor
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  '${tech.calificacionPromedio?.toStringAsFixed(1) ?? "0.0"}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${tech.serviciosCompletados ?? 0} servicios',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (tech.especialidades != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                children: tech.especialidades!
                                    .take(4)
                                    .map((e) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            AppConstants.categoryLabels[e] ?? e,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.primaryColor),
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
