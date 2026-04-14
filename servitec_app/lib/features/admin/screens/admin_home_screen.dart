import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // --- Premium Gradient SliverAppBar ---
          SliverAppBar(
            expandedHeight: 160,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.white),
                  tooltip: 'Configurar Tarifas',
                  onPressed: () => context.push('/admin/tariffs'),
                ),
              ),
            ],
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0A2E36),
                      Color(0xFF0D5C61),
                      Color(0xFF14BDAC),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Panel de Administracion',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ServiTec Dashboard',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Stats Row as Gradient Cards ---
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
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Pendientes',
                          value: pending.toString(),
                          icon: Icons.pending_actions_rounded,
                          gradientColors: const [
                            Color(0xFFFF9800),
                            Color(0xFFFFB74D),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Activos',
                          value: active.toString(),
                          icon: Icons.engineering_rounded,
                          gradientColors: const [
                            Color(0xFF2979FF),
                            Color(0xFF82B1FF),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Completados',
                          value: completed.toString(),
                          icon: Icons.check_circle_rounded,
                          gradientColors: const [
                            Color(0xFF00C853),
                            Color(0xFF69F0AE),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- Status Filter Chips ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      isSelected: _statusFilter == null,
                      onTap: () {
                        setState(() => _statusFilter = null);
                        _resetDisplayLimit();
                      },
                    ),
                    _FilterChip(
                      label: 'Pendientes',
                      isSelected:
                          _statusFilter == AppConstants.statusPending,
                      onTap: () {
                        setState(() =>
                            _statusFilter = AppConstants.statusPending);
                        _resetDisplayLimit();
                      },
                    ),
                    _FilterChip(
                      label: 'Asignados',
                      isSelected:
                          _statusFilter == AppConstants.statusAssigned,
                      onTap: () {
                        setState(() =>
                            _statusFilter = AppConstants.statusAssigned);
                        _resetDisplayLimit();
                      },
                    ),
                    _FilterChip(
                      label: 'En Progreso',
                      isSelected:
                          _statusFilter == AppConstants.statusInProgress,
                      onTap: () {
                        setState(() =>
                            _statusFilter = AppConstants.statusInProgress);
                        _resetDisplayLimit();
                      },
                    ),
                    _FilterChip(
                      label: 'Completados',
                      isSelected:
                          _statusFilter == AppConstants.statusCompleted,
                      onTap: () {
                        setState(() =>
                            _statusFilter = AppConstants.statusCompleted);
                        _resetDisplayLimit();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Search Bar ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente o titulo...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppTheme.textTertiary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppTheme.textTertiary),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v.toLowerCase());
                    _resetDisplayLimit();
                  },
                ),
              ),
            ),
          ),

          // --- Category Filter Chips ---
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todas categorias',
                    isSelected: _categoryFilter == null,
                    onTap: () {
                      setState(() => _categoryFilter = null);
                      _resetDisplayLimit();
                    },
                  ),
                  ...AppConstants.serviceCategories.map((cat) {
                    final emoji = AppConstants.categoryIcons[cat] ?? '';
                    final label = AppConstants.categoryLabels[cat] ?? cat;
                    return _FilterChip(
                      label: '$emoji $label',
                      isSelected: _categoryFilter == cat,
                      onTap: () {
                        setState(() => _categoryFilter = cat);
                        _resetDisplayLimit();
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

          // --- Service List ---
          StreamBuilder<List<ServiceModel>>(
            stream: context
                .read<ServiceRepository>()
                .getAllServices(statusFilter: _statusFilter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                );
              }

              var services = snapshot.data ?? [];

              // Apply category filter
              if (_categoryFilter != null) {
                services = services
                    .where((s) => s.categoria == _categoryFilter)
                    .toList();
              }

              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                services = services
                    .where((s) =>
                        s.clienteNombre
                            .toLowerCase()
                            .contains(_searchQuery) ||
                        s.titulo.toLowerCase().contains(_searchQuery) ||
                        s.id.toLowerCase().contains(_searchQuery))
                    .toList();
              }

              if (services.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.textTertiary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.inbox_outlined,
                              size: 48, color: AppTheme.textTertiary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay servicios',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: -0.3,
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
                    // "Load More" button
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0D7377),
                              Color(0xFF14BDAC),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14BDAC)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () =>
                                setState(() => _displayLimit += _pageSize),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.expand_more_rounded,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cargar mas (${services.length - _displayLimit} restantes)',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

// --- Gradient Stat Card ---
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: -0.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// --- Premium Filter Chip ---
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0A6B6E).withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0A6B6E)
                  : AppTheme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isSelected
                  ? const Color(0xFF0A6B6E)
                  : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
