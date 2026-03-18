import 'package:flutter/material.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
