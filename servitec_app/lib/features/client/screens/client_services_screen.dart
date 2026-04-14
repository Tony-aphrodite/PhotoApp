import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/service_card.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ClientServicesScreen extends StatefulWidget {
  const ClientServicesScreen({super.key});

  @override
  State<ClientServicesScreen> createState() => _ClientServicesScreenState();
}

class _ClientServicesScreenState extends State<ClientServicesScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 10;
  int _displayLimit = _pageSize;
  final _scrollController = ScrollController();
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (mounted) setState(() => _displayLimit += _pageSize);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.backgroundLight,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis Servicios',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtle gradient accent line
                    Container(
                      width: 48,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<ServiceModel>>(
          stream:
              context.read<ServiceRepository>().getClientServices(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                  strokeWidth: 3,
                ),
              );
            }

            final allServices = snapshot.data ?? [];

            if (allServices.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration-style empty state
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.08),
                            AppTheme.secondaryColor.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.inbox_rounded,
                            size: 48,
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.35),
                          ),
                          Positioned(
                            bottom: 18,
                            right: 18,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.search_off_rounded,
                                size: 14,
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No tienes servicios',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tus solicitudes de servicio\napareceran aqui',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppTheme.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // CTA button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF14BDAC)
                                .withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              context.push('/client/create-service'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            child: Text(
                              'Solicitar Servicio',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final displayed = allServices.take(_displayLimit).toList();
            final hasMore = allServices.length > _displayLimit;

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: displayed.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < displayed.length) {
                  final service = displayed[index];
                  return _StaggeredListItem(
                    index: index,
                    animation: _animController,
                    child: ServiceCard(
                      service: service,
                      showTechnician: true,
                      onTap: () =>
                          context.push('/service/${service.id}'),
                    ),
                  );
                }
                // Loading indicator at bottom for infinite scroll
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StaggeredListItem extends AnimatedWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({
    required this.index,
    required Animation<double> animation,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final delay = (index * 0.08).clamp(0.0, 0.6);
    final progress =
        ((animation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(progress);

    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, 16 * (1 - curved)),
        child: child,
      ),
    );
  }
}
