import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ServiceDetailScreen extends StatelessWidget {
  final String serviceId;

  const ServiceDetailScreen({super.key, required this.serviceId});

  void _openWhatsApp(String phone, String serviceName) async {
    final message = Uri.encodeComponent(
      'Hola, te contacto por el servicio de ServiTec: $serviceName',
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final currentUser = authState.user;

    return StreamBuilder<ServiceModel>(
      stream: context.read<ServiceRepository>().streamService(serviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final service = snapshot.data!;
        final isClient = currentUser.uid == service.clienteId;
        final isTechnician = currentUser.uid == service.tecnicoId;
        final isAdmin = currentUser.isAdmin;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del Servicio'),
            actions: [
              if (service.tecnicoId != null || isClient)
                IconButton(
                  icon: const Icon(Icons.chat_outlined),
                  onPressed: () => context.push('/chat/${service.id}'),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photos
                if (service.fotos.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      itemCount: service.fotos.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: service.fotos[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) => Container(
                            color: AppTheme.dividerColor,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.titulo,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                          StatusBadge(status: service.estado, fontSize: 14),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Category + Urgency
                      Row(
                        children: [
                          Text(
                            '${AppConstants.categoryIcons[service.categoria] ?? ''} ${AppConstants.categoryLabels[service.categoria] ?? service.categoria}',
                            style: theme.textTheme.bodyLarge,
                          ),
                          if (service.urgencia == 'urgente') ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flash_on,
                                      size: 14, color: AppTheme.errorColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'URGENTE',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Description
                      Text('Descripción',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        service.descripcion,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info Cards
                      _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Ubicación',
                        value: service.ubicacionTexto,
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Fecha de solicitud',
                        value: DateFormat('dd/MM/yyyy HH:mm')
                            .format(service.createdAt),
                      ),
                      if (service.estimacionCosto != null) ...[
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.attach_money,
                          label: 'Costo estimado',
                          value:
                              '\$${service.estimacionCosto!.toStringAsFixed(2)}',
                          valueColor: AppTheme.primaryColor,
                        ),
                      ],

                      // Technician Info
                      if (service.tecnicoNombre != null) ...[
                        const SizedBox(height: 24),
                        Text('Técnico Asignado',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.person,
                                  color: AppTheme.primaryColor),
                            ),
                            title: Text(service.tecnicoNombre!),
                            subtitle: Text(
                              'Tipo: ${service.tipoAsignacion}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.message_outlined,
                                  color: Color(0xFF25D366)),
                              onPressed: () {
                                // TODO: Get technician phone from Firestore
                                // For now open chat
                                context.push('/chat/${service.id}');
                              },
                            ),
                          ),
                        ),
                      ],

                      // Client Info (for technician/admin)
                      if (!isClient) ...[
                        const SizedBox(height: 24),
                        Text('Cliente', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.secondaryColor.withValues(alpha: 0.1),
                              child: const Icon(Icons.person_outline,
                                  color: AppTheme.secondaryColor),
                            ),
                            title: Text(service.clienteNombre),
                            subtitle: Text(service.clienteTelefono),
                            trailing: IconButton(
                              icon: const Icon(Icons.message_outlined,
                                  color: Color(0xFF25D366)),
                              onPressed: () => _openWhatsApp(
                                service.clienteTelefono,
                                service.titulo,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Action Buttons
                      if (isTechnician && service.isAssigned)
                        ElevatedButton.icon(
                          onPressed: () {
                            context
                                .read<ServiceRepository>()
                                .updateServiceStatus(
                                  service.id,
                                  AppConstants.statusInProgress,
                                );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar Servicio'),
                        ),

                      if (isTechnician && service.isInProgress) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            context
                                .read<ServiceRepository>()
                                .updateServiceStatus(
                                  service.id,
                                  AppConstants.statusCompleted,
                                );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Marcar como Completado'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                          ),
                        ),
                      ],

                      // Payment button (client, when service is completed/payment pending)
                      if (isClient &&
                          (service.isCompleted ||
                              service.estado == AppConstants.statusPaymentPending))
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/payment/${service.id}'),
                          icon: const Icon(Icons.payment),
                          label: Text(
                            'Pagar \$${(service.costoFinal ?? service.estimacionCosto ?? 0).toStringAsFixed(2)}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),

                      // Review button (client, after payment)
                      if (isClient && service.estado == AppConstants.statusPaid)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.push('/review/${service.id}'),
                            icon: const Icon(Icons.star_outline),
                            label: const Text('Calificar Servicio'),
                          ),
                        ),

                      if (isAdmin && service.isPending)
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/admin/assign/${service.id}'),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Asignar Técnico'),
                        ),

                      if ((isClient || isAdmin) &&
                          (service.isPending || service.isAssigned))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Cancelar Servicio'),
                                  content: const Text(
                                      '¿Estás seguro de cancelar este servicio?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('No'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        context
                                            .read<ServiceRepository>()
                                            .updateServiceStatus(
                                              service.id,
                                              AppConstants.statusCancelled,
                                            );
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Sí, cancelar'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.cancel_outlined,
                                color: AppTheme.errorColor),
                            label: const Text('Cancelar Servicio'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side: const BorderSide(color: AppTheme.errorColor),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textTertiary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
