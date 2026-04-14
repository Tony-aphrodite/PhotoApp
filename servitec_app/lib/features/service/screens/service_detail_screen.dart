import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/models/service_model.dart';
import '../../../data/repositories/service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class ServiceDetailScreen extends StatefulWidget {
  final String serviceId;

  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();
    final currentUser = authState.user;

    return StreamBuilder<ServiceModel>(
      stream: context.read<ServiceRepository>().streamService(widget.serviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundLight,
            body: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }

        final service = snapshot.data!;
        final isClient = currentUser.uid == service.clienteId;
        final isTechnician = currentUser.uid == service.tecnicoId;
        final isAdmin = currentUser.isAdmin;

        return Scaffold(
          backgroundColor: AppTheme.backgroundLight,
          body: CustomScrollView(
            slivers: [
              // Photo Gallery with SliverAppBar
              SliverAppBar(
                expandedHeight: service.fotos.isNotEmpty ? 280 : 0,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: service.fotos.isNotEmpty
                    ? Colors.white
                    : AppTheme.textPrimary,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: service.fotos.isNotEmpty
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                actions: [
                  if (service.tecnicoId != null || isClient)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: service.fotos.isNotEmpty
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppTheme.primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.chat_outlined,
                            color: service.fotos.isNotEmpty
                                ? Colors.white
                                : AppTheme.primaryColor,
                          ),
                          onPressed: () => context.push('/chat/${service.id}'),
                        ),
                      ),
                    ),
                ],
                flexibleSpace: service.fotos.isNotEmpty
                    ? FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: service.fotos.length,
                              onPageChanged: (i) =>
                                  setState(() => _currentPage = i),
                              itemBuilder: (context, index) {
                                return CachedNetworkImage(
                                  imageUrl: service.fotos[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (_, __) => Container(
                                    color: AppTheme.dividerColor,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Gradient overlay
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Page dots indicator
                            if (service.fotos.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    service.fotos.length,
                                    (i) => AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      width: _currentPage == i ? 24 : 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _currentPage == i
                                            ? Colors.white
                                            : Colors.white
                                                .withValues(alpha: 0.5),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Photo counter
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_currentPage + 1}/${service.fotos.length}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                title: service.fotos.isEmpty
                    ? Text(
                        'Detalle del Servicio',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      )
                    : null,
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Status Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    service.titulo,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                StatusBadge(
                                    status: service.estado, fontSize: 13),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${AppConstants.categoryIcons[service.categoria] ?? ''} ${AppConstants.categoryLabels[service.categoria] ?? service.categoria}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                if (service.urgencia == 'urgente') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flash_on,
                                            size: 14,
                                            color: AppTheme.errorColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          'URGENTE',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppTheme.errorColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.description_outlined,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Descripcion',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              service.descripcion,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Info Details Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.location_on_outlined,
                              label: 'Ubicacion',
                              value: service.ubicacionTexto,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                color: AppTheme.dividerColor,
                                height: 1,
                              ),
                            ),
                            _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fecha de solicitud',
                              value: DateFormat('dd/MM/yyyy HH:mm')
                                  .format(service.createdAt),
                            ),
                            if (service.estimacionCosto != null) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                child: Divider(
                                  color: AppTheme.dividerColor,
                                  height: 1,
                                ),
                              ),
                              _InfoRow(
                                icon: Icons.attach_money,
                                label: 'Costo estimado',
                                value:
                                    '\$${service.estimacionCosto!.toStringAsFixed(2)}',
                                valueColor: AppTheme.primaryColor,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Technician Card
                      if (service.tecnicoNombre != null) ...[
                        const SizedBox(height: 16),
                        _PremiumPersonCard(
                          title: 'Tecnico Asignado',
                          name: service.tecnicoNombre!,
                          subtitle: 'Tipo: ${service.tipoAsignacion}',
                          iconColor: AppTheme.primaryColor,
                          gradientColors: const [
                            Color(0xFF0D7377),
                            Color(0xFF14BDAC),
                          ],
                          onMessageTap: () {
                            context.push('/chat/${service.id}');
                          },
                        ),
                      ],

                      // Client Card
                      if (!isClient) ...[
                        const SizedBox(height: 16),
                        _PremiumPersonCard(
                          title: 'Cliente',
                          name: service.clienteNombre,
                          subtitle: service.clienteTelefono,
                          iconColor: AppTheme.secondaryColor,
                          gradientColors: const [
                            Color(0xFF14BDAC),
                            Color(0xFF69F0AE),
                          ],
                          onMessageTap: () => _openWhatsApp(
                            service.clienteTelefono,
                            service.titulo,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      if (isTechnician && service.isAssigned)
                        _GradientActionButton(
                          onPressed: () {
                            context
                                .read<ServiceRepository>()
                                .updateServiceStatus(
                                  service.id,
                                  AppConstants.statusInProgress,
                                );
                          },
                          icon: Icons.play_arrow_rounded,
                          label: 'Iniciar Servicio',
                          gradientColors: const [
                            Color(0xFF0D7377),
                            Color(0xFF14BDAC),
                          ],
                        ),

                      if (isTechnician && service.isInProgress) ...[
                        _GradientActionButton(
                          onPressed: () {
                            context
                                .read<ServiceRepository>()
                                .updateServiceStatus(
                                  service.id,
                                  AppConstants.statusCompleted,
                                );
                          },
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Marcar como Completado',
                          gradientColors: const [
                            Color(0xFF00C853),
                            Color(0xFF69F0AE),
                          ],
                        ),
                      ],

                      // Payment button
                      if (isClient &&
                          (service.isCompleted ||
                              service.estado ==
                                  AppConstants.statusPaymentPending))
                        _GradientActionButton(
                          onPressed: () =>
                              context.push('/payment/${service.id}'),
                          icon: Icons.payment_rounded,
                          label:
                              'Pagar \$${(service.costoFinal ?? service.estimacionCosto ?? 0).toStringAsFixed(2)}',
                          gradientColors: const [
                            Color(0xFF00C853),
                            Color(0xFF69F0AE),
                          ],
                        ),

                      // Review button
                      if (isClient &&
                          service.estado == AppConstants.statusPaid)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/review/${service.id}'),
                              icon: const Icon(Icons.star_outline_rounded),
                              label: Text(
                                'Calificar Servicio',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentColor,
                                side: BorderSide(
                                  color: AppTheme.accentColor
                                      .withValues(alpha: 0.4),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium),
                                ),
                              ),
                            ),
                          ),
                        ),

                      if (isAdmin && service.isPending)
                        _GradientActionButton(
                          onPressed: () =>
                              context.push('/admin/assign/${service.id}'),
                          icon: Icons.person_add_outlined,
                          label: 'Asignar Tecnico',
                          gradientColors: const [
                            Color(0xFF0D7377),
                            Color(0xFF14BDAC),
                          ],
                        ),

                      if ((isClient || isAdmin) &&
                          (service.isPending || service.isAssigned))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusLarge),
                                    ),
                                    title: Text(
                                      'Cancelar Servicio',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    content: Text(
                                      'Esta seguro de cancelar este servicio?',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx),
                                        child: Text(
                                          'No',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          context
                                              .read<ServiceRepository>()
                                              .updateServiceStatus(
                                                service.id,
                                                AppConstants.statusCancelled,
                                              );
                                          Navigator.pop(ctx);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.errorColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppTheme.radiusMedium),
                                          ),
                                        ),
                                        child: Text(
                                          'Si, cancelar',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.cancel_outlined,
                                  color: AppTheme.errorColor),
                              label: Text(
                                'Cancelar Servicio',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: const BorderSide(
                                    color: AppTheme.errorColor),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium),
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final List<Color> gradientColors;

  const _GradientActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumPersonCard extends StatelessWidget {
  final String title;
  final String name;
  final String subtitle;
  final Color iconColor;
  final List<Color> gradientColors;
  final VoidCallback onMessageTap;

  const _PremiumPersonCard({
    required this.title,
    required this.name,
    required this.subtitle,
    required this.iconColor,
    required this.gradientColors,
    required this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
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
                        name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.message_outlined,
                        color: Color(0xFF25D366)),
                    onPressed: onMessageTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
