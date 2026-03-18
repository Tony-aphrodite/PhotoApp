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

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key});

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 160,
              floating: true,
              pinned: true,
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textTertiary,
                indicatorColor: AppTheme.primaryColor,
                tabs: const [
                  Tab(text: 'Asignados'),
                  Tab(text: 'En Progreso'),
                  Tab(text: 'Completados'),
                ],
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 60),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${user.nombre}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${user.calificacionPromedio?.toStringAsFixed(1) ?? '0.0'} (${user.totalResenas ?? 0} reseñas)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${user.serviciosCompletados ?? 0} servicios',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: StreamBuilder<List<ServiceModel>>(
          stream: context
              .read<ServiceRepository>()
              .getTechnicianServices(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allServices = snapshot.data ?? [];
            final assigned = allServices
                .where((s) => s.estado == AppConstants.statusAssigned)
                .toList();
            final inProgress = allServices
                .where((s) => s.estado == AppConstants.statusInProgress)
                .toList();
            final completed = allServices
                .where((s) =>
                    s.estado == AppConstants.statusCompleted ||
                    s.estado == AppConstants.statusPaid)
                .toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _ServiceList(
                  services: assigned,
                  emptyMessage: 'No tienes servicios asignados',
                  emptyIcon: Icons.assignment_outlined,
                ),
                _ServiceList(
                  services: inProgress,
                  emptyMessage: 'No tienes servicios en progreso',
                  emptyIcon: Icons.engineering_outlined,
                ),
                _ServiceList(
                  services: completed,
                  emptyMessage: 'Aún no has completado servicios',
                  emptyIcon: Icons.check_circle_outline,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<ServiceModel> services;
  final String emptyMessage;
  final IconData emptyIcon;

  const _ServiceList({
    required this.services,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceCard(
          service: service,
          onTap: () => context.push('/service/${service.id}'),
        );
      },
    );
  }
}
