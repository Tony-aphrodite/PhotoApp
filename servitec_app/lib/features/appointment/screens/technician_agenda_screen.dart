import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/appointment_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

/// The técnico's upcoming appointments, grouped by day.
///
/// Counterpart to [BookAppointmentScreen], which is where clients create these.
/// Past appointments are deliberately excluded — this is a "what's next" view,
/// not a history; completed work already shows in the Completados tab on the
/// home screen.
///
/// The card shows the client's name via the `clienteNombre` denormalized onto
/// the service document. It cannot come from `users/{clienteId}`: Firestore
/// rules let a técnico read their own profile and nothing else, so reading a
/// client's user document straight would be denied.
class TechnicianAgendaScreen extends StatefulWidget {
  const TechnicianAgendaScreen({super.key});

  @override
  State<TechnicianAgendaScreen> createState() => _TechnicianAgendaScreenState();
}

class _TechnicianAgendaScreenState extends State<TechnicianAgendaScreen> {
  /// servicioId → { titulo, clienteNombre, direccion }. Appointments repeat the
  /// same service often enough that refetching per rebuild would be wasteful.
  final Map<String, Map<String, dynamic>> _serviceCache = {};

  Future<Map<String, dynamic>?> _service(String servicioId) async {
    if (servicioId.isEmpty) return null;
    final cached = _serviceCache[servicioId];
    if (cached != null) return cached;

    final doc = await FirebaseFirestore.instance
        .collection('servicios')
        .doc(servicioId)
        .get();
    final data = doc.data();
    if (data != null) _serviceCache[servicioId] = data;
    return data;
  }

  Future<void> _setEstado(AppointmentModel cita, String estado) async {
    try {
      await FirebaseFirestore.instance
          .collection('citas')
          .doc(cita.id)
          .update({'estado': estado});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cita marcada como ${_estadoLabel(estado)}.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar la cita: $e')),
        );
      }
    }
  }

  static String _estadoLabel(String estado) {
    switch (estado) {
      case 'programada':
        return 'programada';
      case 'confirmada':
        return 'confirmada';
      case 'completada':
        return 'completada';
      case 'cancelada':
        return 'cancelada';
      case 'no_asistio':
        return 'no asistió';
      default:
        return estado;
    }
  }

  /// "Hoy" / "Mañana" / "Mon 12 Aug" — a date header a técnico can scan.
  ///
  /// The date part stays in the default locale: nothing in the app calls
  /// `initializeDateFormatting`, so asking for `'es'` here would throw
  /// LocaleDataException at runtime. BookAppointmentScreen formats its day
  /// strip the same unlocalized way, so the two screens agree.
  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return DateFormat('EEE d MMM').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const SizedBox();

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Mi Agenda',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('citas')
            .where('tecnicoId', isEqualTo: authState.user.uid)
            .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
            .orderBy('fechaHora')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return _AgendaEmpty(
              icon: Icons.error_outline_rounded,
              title: 'No se pudo cargar tu agenda',
              subtitle: '${snapshot.error}',
            );
          }

          final citas = (snapshot.data?.docs ?? [])
              .map(AppointmentModel.fromFirestore)
              .where((c) => c.estado != 'cancelada')
              .toList();

          if (citas.isEmpty) {
            return const _AgendaEmpty(
              icon: Icons.event_available_outlined,
              title: 'No tienes citas próximas',
              subtitle:
                  'Cuando un cliente agende contigo, la cita aparecerá aquí.',
            );
          }

          // Group by calendar day, preserving the query's chronological order.
          final byDay = <DateTime, List<AppointmentModel>>{};
          for (final cita in citas) {
            final day = DateTime(
              cita.fechaHora.year,
              cita.fechaHora.month,
              cita.fechaHora.day,
            );
            byDay.putIfAbsent(day, () => []).add(cita);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: byDay.length,
            itemBuilder: (context, index) {
              final day = byDay.keys.elementAt(index);
              final dayCitas = byDay[day]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: index == 0 ? 0 : 24, bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          _dayLabel(day),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${dayCitas.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayCitas.map(
                    (cita) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AgendaCard(
                        cita: cita,
                        loadService: () => _service(cita.servicioId),
                        onEstado: (estado) => _setEstado(cita, estado),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  final AppointmentModel cita;
  final Future<Map<String, dynamic>?> Function() loadService;
  final void Function(String estado) onEstado;

  const _AgendaCard({
    required this.cita,
    required this.loadService,
    required this.onEstado,
  });

  @override
  Widget build(BuildContext context) {
    final isTaller = cita.tipo == 'taller';
    final closed = cita.estado == 'completada' || cita.estado == 'no_asistio';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(cita.fechaHora),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '${cita.duracionMinutos} min',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: loadService(),
                  builder: (context, snapshot) {
                    final service = snapshot.data;
                    final titulo =
                        service?['titulo'] as String? ?? 'Servicio agendado';
                    final cliente = service?['clienteNombre'] as String?;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (cliente != null && cliente.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            cliente,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                icon: isTaller ? Icons.store_outlined : Icons.home_outlined,
                label: isTaller ? 'En taller' : 'A domicilio',
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: _estadoIcon(cita.estado),
                label: _TechnicianAgendaScreenState._estadoLabel(cita.estado),
                color: _estadoColor(cita.estado),
              ),
            ],
          ),
          if (cita.notas != null && cita.notas!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              cita.notas!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (cita.estado == 'programada')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onEstado('confirmada'),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirmar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              if (cita.estado == 'confirmada') ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onEstado('completada'),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Completada'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onEstado('no_asistio'),
                    icon: const Icon(Icons.person_off_outlined, size: 18),
                    label: const Text('No asistió'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
              if (closed)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/service/${cita.servicioId}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Ver servicio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: BorderSide(
                        color: AppTheme.textTertiary.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _estadoIcon(String estado) {
    switch (estado) {
      case 'confirmada':
        return Icons.event_available_rounded;
      case 'completada':
        return Icons.task_alt_rounded;
      case 'no_asistio':
        return Icons.person_off_outlined;
      default:
        return Icons.schedule_rounded;
    }
  }

  static Color _estadoColor(String estado) {
    switch (estado) {
      case 'confirmada':
        return AppTheme.primaryColor;
      case 'completada':
        return AppTheme.successColor;
      case 'no_asistio':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgendaEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AgendaEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
