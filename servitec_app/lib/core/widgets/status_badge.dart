import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double? fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize});

  static const Map<String, String> statusLabels = {
    'pendiente': 'Pendiente',
    'asignado': 'Asignado',
    'en_progreso': 'En Progreso',
    'completado': 'Completado',
    'cancelado': 'Cancelado',
    'pago_pendiente': 'Pago Pendiente',
    'pagado': 'Pagado',
  };

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColors[status] ?? Colors.grey;
    final label = statusLabels[status] ?? status;
    final size = fontSize ?? 12.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.9,
        vertical: size * 0.4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
