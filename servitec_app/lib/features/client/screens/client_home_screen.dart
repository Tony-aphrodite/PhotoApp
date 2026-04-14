import 'dart:math' as math;
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

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;

  // Icon data for categories instead of emojis
  static const Map<String, IconData> _categoryIcons = {
    'electricidad': Icons.bolt_rounded,
    'plomeria': Icons.plumbing_rounded,
    'limpieza': Icons.cleaning_services_rounded,
    'pintura': Icons.format_paint_rounded,
    'carpinteria': Icons.carpenter_rounded,
    'cerrajeria': Icons.lock_rounded,
    'aire_acondicionado': Icons.ac_unit_rounded,
    'electrodomesticos': Icons.electrical_services_rounded,
    'jardineria': Icons.yard_rounded,
    'otro': Icons.handyman_rounded,
  };

  static const List<List<Color>> _categoryGradients = [
    [Color(0xFFFFB020), Color(0xFFFF6B35)],
    [Color(0xFF2979FF), Color(0xFF00B0FF)],
    [Color(0xFF00C853), Color(0xFF69F0AE)],
    [Color(0xFFAA00FF), Color(0xFFD500F9)],
    [Color(0xFF8D6E63), Color(0xFFBCAAA4)],
    [Color(0xFFFF1744), Color(0xFFFF8A80)],
    [Color(0xFF00BCD4), Color(0xFF84FFFF)],
    [Color(0xFFFF6D00), Color(0xFFFFAB40)],
    [Color(0xFF00C853), Color(0xFF76FF03)],
    [Color(0xFF546E7A), Color(0xFF90A4AE)],
  ];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // Premium Gradient SliverAppBar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0A2E36),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient background
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                  ),
                  // Subtle pattern overlay
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Transform.rotate(
                      angle: math.pi / 6,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF14BDAC),
                                    Color(0xFF0D7377),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF14BDAC)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  user.nombre.isNotEmpty
                                      ? user.nombre[0].toUpperCase()
                                      : 'U',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Que servicio necesitas hoy?',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Categories Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                'Categorias',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),

          // Category Carousel - Frosted glass cards with gradient icons
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: AppConstants.serviceCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final cat = AppConstants.serviceCategories[index];
                  final label = AppConstants.categoryLabels[cat] ?? cat;
                  final icon = _categoryIcons[cat] ?? Icons.handyman_rounded;
                  final gradColors = _categoryGradients[
                      index % _categoryGradients.length];

                  return AnimatedBuilder(
                    animation: _staggerController,
                    delay: index * 0.08,
                    child: GestureDetector(
                      onTap: () => context.push(
                        '/client/create-service',
                        extra: cat,
                      ),
                      child: Container(
                        width: 88,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    gradColors[0].withValues(alpha: 0.15),
                                    gradColors[1].withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                size: 22,
                                color: gradColors[0],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: -0.1,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // My Services Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis Servicios',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/client/services'),
                    child: Text(
                      'Ver todos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
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
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                );
              }

              final services = snapshot.data ?? [];

              if (services.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryColor.withValues(alpha: 0.08),
                                AppTheme.secondaryColor.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.handyman_outlined,
                            size: 40,
                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No tienes servicios aun',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Solicita tu primer servicio',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final displayCount = services.length > 5 ? 5 : services.length;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final service = services[index];
                    return AnimatedBuilder(
                      animation: _staggerController,
                      delay: 0.3 + index * 0.1,
                      child: ServiceCard(
                        service: service,
                        showTechnician: true,
                        onTap: () => context.push(
                          '/client/service/${service.id}',
                        ),
                      ),
                    );
                  },
                  childCount: displayCount,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // Floating gradient FAB with glow
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D7377), Color(0xFF14BDAC)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF14BDAC).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF0D7377).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/client/create-service'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: Text(
            'Solicitar Servicio',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stagger-animated wrapper that fades + slides children in.
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final double delay;
  final Widget child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder2(
      animation: animation,
      delay: delay,
      child: child,
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final double delay;
  final Widget child;

  const AnimatedBuilder2({
    super.key,
    required Animation<double> animation,
    required this.delay,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final progress = ((animation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(progress);

    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - curved)),
        child: child,
      ),
    );
  }
}
