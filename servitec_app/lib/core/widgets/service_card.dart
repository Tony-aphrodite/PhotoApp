import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../data/models/service_model.dart';
import '../../core/constants/app_constants.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback? onTap;
  final bool showTechnician;

  const ServiceCard({
    super.key,
    required this.service,
    this.onTap,
    this.showTechnician = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryEmoji = AppConstants.categoryIcons[service.categoria] ?? '📋';
    final categoryLabel = AppConstants.categoryLabels[service.categoria] ?? service.categoria;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Category + Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(categoryEmoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.titulo,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          categoryLabel,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(status: service.estado),
                ],
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                service.descripcion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Photos preview
              if (service.fotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: service.fotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: service.fotos[index],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 60,
                            height: 60,
                            color: AppTheme.dividerColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer: Location, Date, Cost
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      service.ubicacionTexto,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (service.estimacionCosto != null) ...[
                    Text(
                      '\$${service.estimacionCosto!.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Technician info + Date
              Row(
                children: [
                  if (showTechnician && service.tecnicoNombre != null) ...[
                    Icon(Icons.person_outline,
                        size: 16, color: AppTheme.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      service.tecnicoNombre!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                  ] else ...[
                    const Spacer(),
                  ],
                  if (service.urgencia == 'urgente') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'URGENTE',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    DateFormat('dd MMM, HH:mm').format(service.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
