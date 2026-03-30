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

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String? _statusFilter;
  String? _categoryFilter;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _displayLimit = 20;

  static const int _pageSize = 20;

  void _resetDisplayLimit() => setState(() => _displayLimit = _pageSize);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Configurar Tarifas',
                onPressed: () => context.push('/admin/tariffs'),
              ),
            ],
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1D29),
                      Color(0xFF2D3142),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Panel de Administración',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ServiTec Dashboard',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stats Row
          SliverToBoxAdapter(
            child: StreamBuilder<List<ServiceModel>>(
              stream: context.read<ServiceRepository>().getAllServices(),
              builder: (context, snapshot) {
                final services = snapshot.data ?? [];
                final pending = services
                    .where((s) => s.estado == AppConstants.statusPending)
                    .length;
                final active = services
                    .where((s) =>
                        s.estado == AppConstants.statusAssigned ||
                        s.estado == AppConstants.statusInProgress)
                    .length;
                final completed = services
                    .where((s) => s.estado == AppConstants.statusCompleted)
                    .length;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Pendientes',
                          value: pending.toString(),
                          color: AppTheme.warningColor,
                          icon: Icons.pending_actions,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Activos',
                          value: active.toString(),
                          color: AppTheme.infoColor,
                          icon: Icons.engineering,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Completados',
                          value: completed.toString(),
                          color: AppTheme.successColor,
                          icon: Icons.check_circle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todos',
                    isSelected: _statusFilter == null,
                    onTap: () { setState(() => _statusFilter = null); _resetDisplayLimit(); },
                  ),
                  _FilterChip(
                    label: 'Pendientes',
                    isSelected: _statusFilter == AppConstants.statusPending,
                    onTap: () => setState(
                        () => _statusFilter = AppConstants.statusPending),
                    color: AppTheme.warningColor,
                  ),
                  _FilterChip(
                    label: 'Asignados',
                    isSelected: _statusFilter == AppConstants.statusAssigned,
                    onTap: () => setState(
                        () => _statusFilter = AppConstants.statusAssigned),
                    color: AppTheme.infoColor,
                  ),
                  _FilterChip(
                    label: 'En Progreso',
                    isSelected: _statusFilter == AppConstants.statusInProgress,
                    onTap: () => setState(
                        () => _statusFilter = AppConstants.statusInProgress),
                    color: const Color(0xFF8E44AD),
                  ),
                  _FilterChip(
                    label: 'Completados',
                    isSelected: _statusFilter == AppConstants.statusCompleted,
                    onTap: () => setState(
                        () => _statusFilter = AppConstants.statusCompleted),
                    color: AppTheme.successColor,
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o título...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
            ),
          ),

          // Category filter
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas categorías',
                    isSelected: _categoryFilter == null,
                    onTap: () => setState(() => _categoryFilter = null),
                  ),
                  ...AppConstants.serviceCategories.map((cat) {
                    final emoji = AppConstants.categoryIcons[cat] ?? '';
                    final label = AppConstants.categoryLabels[cat] ?? cat;
                    return _FilterChip(
                      label: '$emoji $label',
                      isSelected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter = cat),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Service List
          StreamBuilder<List<ServiceModel>>(
            stream: context
                .read<ServiceRepository>()
                .getAllServices(statusFilter: _statusFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              var services = snapshot.data ?? [];

              // Apply category filter
              if (_categoryFilter != null) {
                services = services.where((s) => s.categoria == _categoryFilter).toList();
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                services = services.where((s) =>
                    s.clienteNombre.toLowerCase().contains(_searchQuery) ||
                    s.titulo.toLowerCase().contains(_searchQuery) ||
                    s.id.toLowerCase().contains(_searchQuery)).toList();
              }

              if (services.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'No hay servicios',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final displayed = services.take(_displayLimit).toList();
              final hasMore = services.length > _displayLimit;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index < displayed.length) {
                      final service = displayed[index];
                      return ServiceCard(
                        service: service,
                        showTechnician: true,
                        onTap: () =>
                            context.push('/service/${service.id}'),
                      );
                    }
                    // "Load More" button at end
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                            () => _displayLimit += _pageSize),
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                            'Cargar más (${services.length - _displayLimit} restantes)'),
                      ),
                    );
                  },
                  childCount: displayed.length + (hasMore ? 1 : 0),
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? chipColor : AppTheme.dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? chipColor : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
