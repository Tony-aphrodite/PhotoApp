import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/service_model.dart';
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

  static const Map<String, String> _categoryEmojis = {
    'electricidad': '\u26A1',
    'plomeria': '\uD83D\uDD27',
    'limpieza': '\uD83E\uDDF9',
    'pintura': '\uD83C\uDFA8',
    'carpinteria': '\uD83E\uDE9A',
    'cerrajeria': '\uD83D\uDD11',
    'aire_acondicionado': '\u2744\uFE0F',
    'electrodomesticos': '\uD83D\uDD0C',
    'jardineria': '\uD83C\uDF3F',
    'otro': '\uD83D\uDCCB',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _categoryEmojis[service.categoria] ?? '\uD83D\uDCCB';
    final formattedDate =
        DateFormat('dd MMM, HH:mm').format(service.createdAt);

    String? costText;
    final cost = service.estimacionCosto;
    if (cost != null) {
      costText = '\$${cost.toStringAsFixed(2)}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.softShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image or emoji header
            if (service.fotos.isNotEmpty)
              _buildHeroImage(service.fotos.first, service.estado)
            else
              _buildEmojiHeader(emoji, service.estado),

            // Content section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.titulo,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (service.urgencia == 'urgente') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'URGENTE',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.errorColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (service.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      service.descripcion,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Info row
                  Row(
                    children: [
                      if (service.ubicacionTexto.isNotEmpty) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            service.ubicacionTexto,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),

                  // Bottom row
                  if (costText != null ||
                      (showTechnician && service.tecnicoNombre != null)) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppTheme.dividerColor,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (costText != null)
                            Text(
                              costText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          const Spacer(),
                          if (showTechnician &&
                              service.tecnicoNombre != null) ...[
                            Icon(
                              Icons.person_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              service.tecnicoNombre!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(String imageUrl, String estado) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppTheme.dividerColor,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: AppTheme.dividerColor,
              child: const Icon(
                Icons.image_not_supported_outlined,
                color: AppTheme.textTertiary,
                size: 32,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: StatusBadge(status: estado),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiHeader(String emoji, String estado) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.06),
            AppTheme.secondaryColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: StatusBadge(status: estado),
          ),
        ],
      ),
    );
  }
}
