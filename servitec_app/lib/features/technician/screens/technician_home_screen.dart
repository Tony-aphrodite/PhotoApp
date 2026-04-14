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
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 210,
              floating: true,
              pinned: true,
              backgroundColor: const Color(0xFF0A2E36),
              surfaceTintColor: Colors.transparent,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textTertiary,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: 'Asignados'),
                      Tab(text: 'En Progreso'),
                      Tab(text: 'Completados'),
                    ],
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
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
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 70),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (user.nombre.isNotEmpty
                                            ? user.nombre[0]
                                            : 'T')
                                        .toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hola, ${user.nombre}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Panel de Tecnico',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.white.withValues(alpha: 0.6),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _HeaderStatChip(
                                icon: Icons.star_rounded,
                                iconColor: const Color(0xFFFFD54F),
                                label:
                                    '${user.calificacionPromedio?.toStringAsFixed(1) ?? '0.0'}',
                                sublabel:
                                    '(${user.totalResenas ?? 0} resenas)',
                              ),
                              const SizedBox(width: 12),
                              _HeaderStatChip(
                                icon: Icons.check_circle_rounded,
                                iconColor: const Color(0xFF69F0AE),
                                label:
                                    '${user.serviciosCompletados ?? 0}',
                                sublabel: 'completados',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
              return Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2.5,
                ),
              );
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
                  emptySubMessage:
                      'Los nuevos servicios apareceran aqui cuando te sean asignados',
                  emptyIcon: Icons.assignment_outlined,
                ),
                _ServiceList(
                  services: inProgress,
                  emptyMessage: 'No tienes servicios en progreso',
                  emptySubMessage:
                      'Acepta un servicio asignado para comenzar a trabajar',
                  emptyIcon: Icons.engineering_outlined,
                ),
                _ServiceList(
                  services: completed,
                  emptyMessage: 'Aun no has completado servicios',
                  emptySubMessage:
                      'Tu historial de servicios completados aparecera aqui',
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

class _HeaderStatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;

  const _HeaderStatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            sublabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceList extends StatefulWidget {
  final List<ServiceModel> services;
  final String emptyMessage;
  final String emptySubMessage;
  final IconData emptyIcon;

  const _ServiceList({
    required this.services,
    required this.emptyMessage,
    required this.emptySubMessage,
    required this.emptyIcon,
  });

  @override
  State<_ServiceList> createState() => _ServiceListState();
}

class _ServiceListState extends State<_ServiceList> {
  static const int _pageSize = 15;
  int _displayLimit = _pageSize;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (mounted && _displayLimit < widget.services.length) {
        setState(() => _displayLimit += _pageSize);
      }
    }
  }

  @override
  void didUpdateWidget(_ServiceList old) {
    super.didUpdateWidget(old);
    // Reset pagination when list changes (e.g. tab switch)
    if (old.services != widget.services) {
      _displayLimit = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.emptyIcon,
                  size: 38,
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.emptyMessage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.emptySubMessage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textTertiary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final displayed = widget.services.take(_displayLimit).toList();
    final hasMore = widget.services.length > _displayLimit;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: displayed.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayed.length) {
          final service = displayed[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 350 + (index * 60)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: ServiceCard(
              service: service,
              onTap: () => context.push('/service/${service.id}'),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
