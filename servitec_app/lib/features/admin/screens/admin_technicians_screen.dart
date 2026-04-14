import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_repository.dart';

class AdminTechniciansScreen extends StatelessWidget {
  const AdminTechniciansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // --- Premium Header ---
          SliverAppBar(
            expandedHeight: 130,
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
                      'Tecnicos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestiona tu equipo de profesionales',
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

          // --- Technician List ---
          SliverToBoxAdapter(
            child: StreamBuilder<List<UserModel>>(
              stream: context.read<UserRepository>().getAllTechnicians(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  );
                }

                final technicians = snapshot.data ?? [];

                if (technicians.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.textTertiary
                                  .withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.engineering_outlined,
                                size: 48, color: AppTheme.textTertiary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay tecnicos registrados',
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

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final tech = technicians[index];
                    final isAvailable = tech.disponible ?? false;
                    final rating =
                        tech.calificacionPromedio?.toStringAsFixed(1) ??
                            '0.0';
                    final ratingVal = tech.calificacionPromedio ?? 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF0D7377),
                                    Color(0xFF14BDAC),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  tech.nombre.isNotEmpty
                                      ? tech.nombre[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tech.fullName,
                                          style:
                                              GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Availability dot
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? AppTheme.successColor
                                                  .withValues(alpha: 0.1)
                                              : AppTheme.textTertiary
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isAvailable
                                                    ? AppTheme.successColor
                                                    : AppTheme
                                                        .textTertiary,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAvailable
                                                  ? 'Activo'
                                                  : 'Inactivo',
                                              style: GoogleFonts
                                                  .plusJakartaSans(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isAvailable
                                                    ? AppTheme.successColor
                                                    : AppTheme
                                                        .textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  // Rating stars + services
                                  Row(
                                    children: [
                                      ...List.generate(5, (i) {
                                        if (i < ratingVal.floor()) {
                                          return const Icon(Icons.star_rounded,
                                              size: 14, color: Colors.amber);
                                        } else if (i < ratingVal.ceil() &&
                                            ratingVal % 1 >= 0.5) {
                                          return const Icon(
                                              Icons.star_half_rounded,
                                              size: 14,
                                              color: Colors.amber);
                                        }
                                        return Icon(
                                            Icons.star_outline_rounded,
                                            size: 14,
                                            color: Colors.amber
                                                .withValues(alpha: 0.4));
                                      }),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(Icons.handyman_rounded,
                                          size: 13,
                                          color: AppTheme.textTertiary),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${tech.serviciosCompletados ?? 0} servicios',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Specialty tags
                                  if (tech.especialidades != null) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: tech.especialidades!
                                          .take(4)
                                          .map((e) => Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                          0xFF0A6B6E)
                                                      .withValues(
                                                          alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                  border: Border.all(
                                                    color: const Color(
                                                            0xFF0A6B6E)
                                                        .withValues(
                                                            alpha: 0.15),
                                                  ),
                                                ),
                                                child: Text(
                                                  AppConstants
                                                          .categoryLabels[
                                                      e] ?? e,
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: const Color(
                                                        0xFF0A6B6E),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
