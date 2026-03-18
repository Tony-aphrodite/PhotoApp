import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/service_card.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.85),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Hola, ${user.nombre}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¿Qué servicio necesitas hoy?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Categorías', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppConstants.serviceCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final cat = AppConstants.serviceCategories[index];
                        final emoji = AppConstants.categoryIcons[cat] ?? '';
                        final label = AppConstants.categoryLabels[cat] ?? cat;
                        return GestureDetector(
                          onTap: () => context.push(
                            '/client/create-service',
                            extra: cat,
                          ),
                          child: Container(
                            width: 80,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.06),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: AppTheme.dividerColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: theme.textTheme.labelSmall,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recent Services
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mis Servicios', style: theme.textTheme.titleLarge),
                  TextButton(
                    onPressed: () => context.push('/client/services'),
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
            ),
          ),

          // Service list
          StreamBuilder<List<ServiceModel>>(
            stream: context
                .read<ServiceRepository>()
                .getClientServices(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final services = snapshot.data ?? [];

              if (services.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.handyman_outlined,
                          size: 64,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tienes servicios aún',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Solicita tu primer servicio',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final service = services[index];
                    return ServiceCard(
                      service: service,
                      showTechnician: true,
                      onTap: () => context.push(
                        '/client/service/${service.id}',
                      ),
                    );
                  },
                  childCount: services.length > 5 ? 5 : services.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/client/create-service'),
        icon: const Icon(Icons.add),
        label: const Text('Solicitar Servicio'),
      ),
    );
  }
}
