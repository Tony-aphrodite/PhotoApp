import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/admin_flag_model.dart';
import '../../../data/repositories/admin_flag_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

/// Moderation queue: every attempt to take a job off the platform, plus the
/// backend failures that need a human.
///
/// The data was already being captured by the Cloud Functions — the chat
/// filter has been recording every blocked phone number and WhatsApp link
/// since it shipped. Until now the only way to read it was the Firestore
/// console, which meant nobody read it.
///
/// Deliberately observational: no automatic sanctions. An admin can see what
/// happened, open the conversation, and mark the alert reviewed. Firestore
/// rules make the evidence itself immutable.
class AdminFlagsScreen extends StatefulWidget {
  const AdminFlagsScreen({super.key});

  @override
  State<AdminFlagsScreen> createState() => _AdminFlagsScreenState();
}

class _AdminFlagsScreenState extends State<AdminFlagsScreen> {
  /// null = todas
  String? _estadoFilter = AdminFlagModel.estadoPendiente;

  late Stream<List<AdminFlagModel>> _stream;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  // Rebuilt only when the filter changes — never inside build(), where every
  // rebuild would tear down the listener and re-read the whole queue.
  void _subscribe() {
    _stream = context
        .read<AdminFlagRepository>()
        .watch(estado: _estadoFilter);
  }

  void _onFilterChanged(String? estado) {
    if (estado == _estadoFilter) return;
    setState(() {
      _estadoFilter = estado;
      _subscribe();
    });
  }

  Future<void> _toggleRevisada(AdminFlagModel flag) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final messenger = ScaffoldMessenger.of(context);

    final nuevo = flag.isPendiente
        ? AdminFlagModel.estadoRevisada
        : AdminFlagModel.estadoPendiente;

    try {
      await context.read<AdminFlagRepository>().setEstado(
            flagId: flag.id,
            estado: nuevo,
            adminUid: authState.user.uid,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(nuevo == AdminFlagModel.estadoRevisada
              ? 'Alerta marcada como revisada.'
              : 'Alerta reabierta.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Alertas y Quejas',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterBar(selected: _estadoFilter, onChanged: _onFilterChanged),
          Expanded(
            child: StreamBuilder<List<AdminFlagModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor),
                  );
                }
                if (snapshot.hasError) {
                  return _Empty(
                    icon: Icons.error_outline_rounded,
                    title: 'No se pudieron cargar las alertas',
                    subtitle: '${snapshot.error}',
                  );
                }

                final flags = snapshot.data ?? const <AdminFlagModel>[];
                if (flags.isEmpty) {
                  return _Empty(
                    icon: Icons.verified_outlined,
                    title: _estadoFilter == AdminFlagModel.estadoPendiente
                        ? 'No hay alertas pendientes'
                        : 'No hay alertas',
                    subtitle:
                        'Aquí aparecen los intentos de contacto fuera de la app y los errores que requieren tu atención.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: flags.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _FlagCard(
                    flag: flags[i],
                    onToggle: () => _toggleRevisada(flags[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? selected;
  final void Function(String?) onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = <String?, String>{
      AdminFlagModel.estadoPendiente: 'Pendientes',
      AdminFlagModel.estadoRevisada: 'Revisadas',
      null: 'Todas',
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: options.entries.map((e) {
          final isSelected = e.key == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  e.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FlagCard extends StatelessWidget {
  final AdminFlagModel flag;
  final VoidCallback onToggle;

  const _FlagCard({required this.flag, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Moderation alerts are the commercially important ones — someone trying
    // to take the job off-platform. Backend failures are amber, not red.
    final accent = flag.isModeration
        ? AppTheme.errorColor
        : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.softShadow,
        border: flag.isPendiente
            ? Border(left: BorderSide(color: accent, width: 4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                flag.isModeration
                    ? Icons.report_gmailerrorred_rounded
                    : Icons.build_circle_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flag.tipoLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy · HH:mm').format(flag.createdAt),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _EstadoChip(estado: flag.estado),
            ],
          ),

          if (flag.isContactLeak) ...[
            const SizedBox(height: 12),
            _Row(label: 'Detectado', value: flag.motivoLabel),
            if (flag.offenderName != null)
              _Row(label: 'Lo intentó', value: flag.offenderName!),
            if (flag.originalText != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"${flag.originalText}"',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],

          if (flag.error != null) ...[
            const SizedBox(height: 10),
            Text(
              flag.error!,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (flag.categoria != null)
            _Row(label: 'Categoría', value: flag.categoria!),
          if (flag.periodo != null)
            _Row(label: 'Periodo', value: flag.periodo!),

          const SizedBox(height: 14),
          Row(
            children: [
              if (flag.servicioId != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push('/service/${flag.servicioId}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Servicio'),
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
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/chat/${flag.servicioId}'),
                    icon: const Icon(Icons.forum_outlined, size: 17),
                    label: const Text('Chat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FilledButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    flag.isPendiente
                        ? Icons.check_rounded
                        : Icons.undo_rounded,
                    size: 17,
                  ),
                  label: Text(flag.isPendiente ? 'Revisada' : 'Reabrir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: flag.isPendiente
                        ? AppTheme.successColor
                        : AppTheme.textTertiary,
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
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final revisada = estado == AdminFlagModel.estadoRevisada;
    final color = revisada ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        revisada ? 'Revisada' : 'Pendiente',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Empty({
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
